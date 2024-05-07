import Foundation
import SwiftUI
import WebKit
import CoreLocation

public class FanMakerSDK {
    public var apiKey : String = ""
    public var userID : String = ""
    public var memberID : String = ""
    public var studentID : String = ""
    public var ticketmasterID : String = ""
    public var yinzid : String = ""
    public var pushToken : String = ""
    public var fanmakerIdentifierLexicon: [String: Any] = [:]
    public var locationEnabled : Bool = false
    public var loadingBackgroundColor : UIColor = UIColor.white
    public var loadingForegroundImage : UIImage? = nil

    public let FanMakerSDKSessionToken : String = "FanMakerSDKSessionToken"
    public let FanMakerSDKJSONIdentifiers : String = "FanMakerSDKJSONIdentifiers"

    public var deepLinkPath: String?
    public var baseURL : String?
    public var currentWebView : WKWebView? = nil

    public var beaconUniquenessThrottle : Int = 60
    private let locationManager : CLLocationManager = CLLocationManager()
    private let locationDelegate : FanMakerSDKLocationDelegate = FanMakerSDKLocationDelegate()


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
        self.locationEnabled = false

        let defaults : UserDefaults = UserDefaults.standard
        if defaults.string(forKey: self.FanMakerSDKSessionToken) != nil {
            if let json = defaults.string(forKey: self.FanMakerSDKJSONIdentifiers) {
                self.setIdentifiers(fromJSON: json)
            }

            NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        }
    }

    // Put anything in there that you want to happen when the app enters the foreground
    @objc private func appWillEnterForeground() {
        if locationEnabled {
            locationManager.delegate = locationDelegate
            self.sendLocationPing()
        }
    }

    public func sendLocationPing() {
        print("GPS Coordinates: \(locationDelegate.checkAuthorizationAndReturnCoordinates(locationManager))")
        let coords = locationDelegate.checkAuthorizationAndReturnCoordinates(locationManager)

        if let coords = coords as? [String: Any],
        let lat = coords["lat"],
        let lng = coords["lng"] {
            let body: [String: Any] = [
                "latitude": lat,
                "longitude": lng
            ]

            FanMakerSDKHttp.post(path: "events/auto_checkin", body: body) { result in }
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

    public func enableLocationTracking() {
        self.locationEnabled = true
    }

    public func disableLocationTracking() {
        self.locationEnabled = false
    }

    public func setLoadingBackgroundColor(_ bgColor : UIColor) {
        self.loadingBackgroundColor = bgColor
    }

    public func setLoadingForegroundImage(_ fgImage : UIImage) {
        self.loadingForegroundImage = fgImage
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
