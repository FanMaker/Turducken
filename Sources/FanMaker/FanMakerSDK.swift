import Foundation
import SwiftUI
import WebKit
import CoreLocation

// This is a wrapper for the UserDefaults class that allows us to namespace keys
// so that we don't have to worry about key collisions with other libraries or
// with multiple intanses of the SDK initialized at the same time.
public struct FanMakerSDKUserDefaults {
  private let sdk: FanMakerSDK
  init(sdk: FanMakerSDK) {
    self.sdk = sdk
  }
  private func namespacedKey(forKey: String) -> String {
    return "\(sdk.apiKey)_\(forKey)"
  }

  func set(_ value: Any?, forKey: String) {
    let namespacedKey = namespacedKey(forKey: forKey)
    UserDefaults.standard.set(value, forKey: namespacedKey)
  }

  func value(forKey: String) -> Any? {
    let namespacedKey = namespacedKey(forKey: forKey)
    return UserDefaults.standard.value(forKey: namespacedKey)
  }

  func get(forKey: String) -> Any? {
    return value(forKey: forKey)
  }

  func string(forKey: String) -> String? {
    return value(forKey: forKey) as? String
  }

  func data(forKey: String) -> Data? {
    let namespacedKey = namespacedKey(forKey: forKey)
    return UserDefaults.standard.data(forKey: namespacedKey)
  }
}

public class FanMakerSDK {
    public var firstLaunch : Bool = true
    public var finishedLaunching : Bool = false
    public var apiKey : String = ""
    public var userID : String = ""
    public var memberID : String = ""
    public var studentID : String = ""
    public var ticketmasterID : String = ""
    public var yinzid : String = ""
    public var pushToken : String = ""
    public var fanmakerIdentifierLexicon: [String: Any] = [:]
    public var fanmakerParametersLexicon: [String: Any] = [:]
    public var locationEnabled : Bool = true // As of 2.0.3, we are making location enabled by default to help some clients with location tracking setup
    public var loadingBackgroundColor : UIColor = UIColor.white
    public var loadingForegroundImage : UIImage? = nil
    public var useDarkLoadingScreen : Bool = false

    public let FanMakerSDKSessionToken : String = "FanMakerSDKSessionToken"
    public let FanMakerSDKJSONIdentifiers : String = "FanMakerSDKJSONIdentifiers"
    public let FanMakerSDKJSONParameters : String = "FanMakerSDKJSONParameters"

    public var deepLinkPath: String?
    public var baseURL : String?
    public var currentWebView : WKWebView? = nil

    public var beaconUniquenessThrottle : Int = 60
    private let locationManager : CLLocationManager = CLLocationManager()
    private let locationDelegate : FanMakerSDKLocationDelegate = FanMakerSDKLocationDelegate()

    public var userDefaults : FanMakerSDKUserDefaults? = nil

    public func updateBeaconUniquenessThrottle(_ thrtl: Int) {
        self.beaconUniquenessThrottle = thrtl
    }

    public func updateDeepLinkPath(_ path: String) {
        self.deepLinkPath = path
    }

    public func updateBaseUrl(_ baseString: String) {
        self.baseURL = baseString
    }

    // Used for "Deep Linking"
    public func handleUrl(_ url: URL) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)

        guard let host = components?.host, let path = components?.path else {
            return false
        }

        if host.lowercased() == "fanmaker" {
            self.deepLinkPath = path
            if((self.currentWebView != nil) && (self.baseURL != nil)) {
                let fullUrl = (self.baseURL ?? String("")) + path
                let url = URL(string: fullUrl)!
                let request = URLRequest(url: url)
                self.currentWebView?.load(request)
            }

            return true
        }

        return false
    }

    // Used for "Deep Linking"
    public func canHandleUrl(_ url: URL) -> Bool {
        // Parse the URL and check if it can be handled.
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)

        guard let host = components?.host else {
            return false
        }

        // we only accept links that are tailored for the SDK
        // like: clientapp://fanmaker/...
        if host.lowercased() == "fanmaker"{
            return true
        }

        return false
    }

    public init() {}

    public func initialize(apiKey : String) {
        self.apiKey = apiKey
        self.locationEnabled = true // As of 2.0.3, we are making location enabled by default to help some clients with location tracking setup
        self.userDefaults = FanMakerSDKUserDefaults(sdk: self)

        let defaults = self.userDefaults
        if defaults?.string(forKey: self.FanMakerSDKSessionToken) != nil && defaults?.string(forKey: self.FanMakerSDKSessionToken) != "" {
            if let json = defaults?.string(forKey: self.FanMakerSDKJSONIdentifiers) {
                self.setIdentifiers(fromJSON: json)
            }

        }
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishLaunching), name: UIApplication.didFinishLaunchingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
    }

    // Put anything in there that you want to happen when the the app is being terminated
    @objc private func appWillTerminate() {
        finishedLaunching = false
        firstLaunch = true
    }

    // Put anything in there that you want to happen when the app is launched
    @objc private func didFinishLaunching() {
        NSLog("FanMaker ###################################################################### didFinishLaunching")

        if locationEnabled {
            locationManager.delegate = locationDelegate
            self.sendLocationPing()
        }

        sendAppEvent("app_launch")
        finishedLaunching = true
    }

    // Put anything in there that you want to happen when the app enters the foreground
    @objc private func appWillEnterForeground() {
        let appAction = firstLaunch ? "app_launch" : "app_resume"

        // Based on the timing of our subscription, we may get a call to appWillEnterForeground
        // on the initail launch of the app. If we have already called didFinishLaunching, we
        // can safely ignore this call.
        if firstLaunch && finishedLaunching {
            firstLaunch = false
            return
        }

        NSLog("FanMaker ###################################################################### appWillEnterForeground")

        if locationEnabled {
            locationManager.delegate = locationDelegate
            self.sendLocationPing()
        }

        sendAppEvent(appAction)
    }

    public func sendLocationPing() {
        NSLog("FanMaker Start Auto Checkin. Location Enabled: \(self.locationEnabled)")
        if self.locationEnabled {
            locationManager.delegate = locationDelegate
            let defaults = self.userDefaults
            if let token = defaults?.string(forKey: self.FanMakerSDKSessionToken) {
                locationDelegate.checkAuthorizationAndRequestLocation(locationManager) { result in
                    switch result {
                    case .success(let coordinates):
                        let body: [String: Any] = [
                            "latitude": coordinates["lat"]!,
                            "longitude": coordinates["lng"]!
                        ]
                        NSLog("FanMaker sendLocationPing posting AUTO CHECKIN #################################################################")
                        FanMakerSDKHttp.post(sdk: self, path: "events/auto_checkin", body: body) { result in }
                    case .failure(let error):
                        NSLog("FanMaker sendLocationPing failed with error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    public func sendAppEvent(_ action : String) {
        let defaults = self.userDefaults
        if let token = defaults?.string(forKey: self.FanMakerSDKSessionToken) {
            let body: [String: Any] = [
                "context": action
            ]

            FanMakerSDKHttp.post(sdk: self, path: "users/log_impression", body: body) { result in }
        }
    }

    public func isInitialized() -> Bool {
        return apiKey != ""
    }

    public func setUserID(_ value : String) {
        self.userID = value
    }

    public func setMemberID(_ value : String) {
        self.memberID = value
    }

    public func setStudentID(_ value : String) {
        self.studentID = value
    }

    public func setTicketmasterID(_ value : String) {
        self.ticketmasterID = value
    }

    public func setYinzid(_ value : String) {
        self.yinzid = value
    }

    public func setPushNotificationToken(_ value : String) {
        self.pushToken = value
    }

    public func setFanMakerIdentifiers(dictionary: [String: Any] = [:]) -> [String: Any] {
        var idLexicon = (self.fanmakerIdentifierLexicon as? [String: Any]) ?? [:]

        for key in dictionary.keys {
            idLexicon[key] = dictionary[key]
        }

        self.fanmakerIdentifierLexicon = idLexicon

        return self.fanmakerIdentifierLexicon as? [String: Any] ?? [:]
    }

    public func fanMakerParameters(dictionary: [String: Any] = [:]) -> [String: Any] {
        var idLexicon = (self.fanmakerParametersLexicon as? [String: Any]) ?? [:]

        for key in dictionary.keys {
            idLexicon[key] = dictionary[key]
        }

        self.fanmakerParametersLexicon = idLexicon

        return self.fanmakerParametersLexicon as? [String: Any] ?? [:]
    }

    public func enableLocationTracking() {
        self.locationEnabled = true
    }

    public func disableLocationTracking() {
        self.locationEnabled = false
    }

    public func enableDarkLoadingScreen() {
        self.useDarkLoadingScreen = true
    }

    public func setLoadingBackgroundColor(_ bgColor : UIColor) {
        self.loadingBackgroundColor = bgColor
    }

    public func setLoadingForegroundImage(_ fgImage : UIImage) {
        self.loadingForegroundImage = fgImage
    }

    // allows us to dynamically access properties of the SDK like `sdk.valueForKey("apiKey")`
    public func valueForKey(forKey key: String) -> String {
        // Use Mirror to reflect on self
        let mirror = Mirror(reflecting: self)
        var returnString = ""

        // Iterate over each child in the mirrored properties
        for child in mirror.children {
            // Check if the child's label matches the key
            if child.label == key {
                // Use String(describing:) to safely convert the value to a String
                returnString = String(describing: child.value)
            }

            // Check if the property is a dictionary of [String: Any]
            if let dictionary = child.value as? [String: Any],
               let dictionaryValue = dictionary[key] {
                // Convert the value from the dictionary to a String using String(describing:)
                returnString = String(describing: dictionaryValue)
            }
        }

        if returnString != "" {
            let escapedVal = returnString.replacingOccurrences(of: "\"", with: "\\\"")
            // Create the JavaScript string, ensuring the value is properly quoted
            let jsString = "FanMakerSDKDebugData(\"\(escapedVal)\")"
            return jsString
        }

        // Return nil if no property with the given key is found
        return "FanMakerSDKDebugData(\"Property Not Found\")"
    }

    public func sdkOpenUrl(scheme : String) {
        if let url = URL(string: scheme) {
            if #available(iOS 10, *) {
                UIApplication.shared.open(url, options: [:],
                completionHandler: {
                    (success) in
                        print("Open \(scheme): \(success)")
                })
            } else {
                let success = UIApplication.shared.openURL(url)
                print("Open \(scheme): \(success)")
            }
        }
    }

    public func setIdentifiers(fromJSON json : String) {
        let data : Data? = json.data(using: .utf8)
        do {
            let identifiers = try JSONDecoder().decode(FanMakerSDKIdentifiers.self, from: data!)
            if identifiers.user_id != nil { self.setUserID(identifiers.user_id!) }
            if identifiers.member_id != nil { self.setMemberID(identifiers.member_id!) }
            if identifiers.student_id != nil { self.setStudentID(identifiers.student_id!) }
            if identifiers.ticketmaster_id != nil { self.setTicketmasterID(identifiers.ticketmaster_id!) }
            if identifiers.yinzid != nil { self.setYinzid(identifiers.yinzid!) }
            if identifiers.push_token != nil { self.setPushNotificationToken(identifiers.push_token!) }
            if identifiers.fanmaker_identifiers != nil { self.setFanMakerIdentifiers(dictionary: identifiers.fanmaker_identifiers!) }
        } catch { }
    }
}
