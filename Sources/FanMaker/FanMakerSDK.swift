import Foundation
import SwiftUI
import WebKit
import CoreLocation

public let FanMakerSDKSessionToken : String = "FanMakerSDKSessionToken"
public let FanMakerSDKJSONIdentifiers : String = "FanMakerSDKJSONIdentifiers"

public class FanMakerSDK {
    public static var apiKey : String = ""
    public static var userID : String = ""
    public static var memberID : String = ""
    public static var studentID : String = ""
    public static var ticketmasterID : String = ""
    public static var yinzid : String = ""
    public static var pushToken : String = ""
    public static var fanmakerIdentifierLexicon: [String: Any] = [:]
    public static var locationEnabled : Bool = false
    public static var loadingBackgroundColor : UIColor = UIColor.white
    public static var loadingForegroundImage : UIImage? = nil

    public static var deepLinkPath: String?
    public static var baseURL : String?
    public static var currentWebView : WKWebView? = nil

    public static var beaconUniquenessThrottle : Int = 60
    private static let locationManager : CLLocationManager = CLLocationManager()
    private static let locationDelegate : FanMakerSDKLocationDelegate = FanMakerSDKLocationDelegate()

    // Used for "Deep Linking"
    public static func handleUrl(_ url: URL) -> Bool {
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
    public static func canHandleUrl(_ url: URL) -> Bool {
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

    public static func initialize(apiKey : String) {
        self.apiKey = apiKey
        self.locationEnabled = false

        let defaults : UserDefaults = UserDefaults.standard
        if defaults.string(forKey: FanMakerSDKSessionToken) != nil {
            if let json = defaults.string(forKey: FanMakerSDKJSONIdentifiers) {
                FanMakerSDK.setIdentifiers(fromJSON: json)
            }

            NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        }
    }

    // Put anything in there that you want to happen when the app enters the foreground
    @objc private static func appWillEnterForeground() {
        if locationEnabled {
            locationManager.delegate = locationDelegate
            self.sendLocationPing()
        }
    }

    public static func sendLocationPing() {
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

    public static func isInitialized() -> Bool {
        return apiKey != ""
    }

    public static func setUserID(_ value : String) {
        self.userID = value
    }

    public static func setMemberID(_ value : String) {
        self.memberID = value
    }

    public static func setStudentID(_ value : String) {
        self.studentID = value
    }

    public static func setTicketmasterID(_ value : String) {
        self.ticketmasterID = value
    }

    public static func setYinzid(_ value : String) {
        self.yinzid = value
    }

    public static func setPushNotificationToken(_ value : String) {
        self.pushToken = value
    }

    public static func setFanMakerIdentifiers(dictionary: [String: Any] = [:]) -> [String: Any] {
        var idLexicon = (self.fanmakerIdentifierLexicon as? [String: Any]) ?? [:]

        for key in dictionary.keys {
            idLexicon[key] = dictionary[key]
        }

        self.fanmakerIdentifierLexicon = idLexicon

        return self.fanmakerIdentifierLexicon as? [String: Any] ?? [:]
    }

    public static func enableLocationTracking() {
        self.locationEnabled = true
    }

    public static func disableLocationTracking() {
        self.locationEnabled = false
    }

    public static func setLoadingBackgroundColor(_ bgColor : UIColor) {
        self.loadingBackgroundColor = bgColor
    }

    public static func setLoadingForegroundImage(_ fgImage : UIImage) {
        self.loadingForegroundImage = fgImage
    }


    public static func sdkOpenUrl(scheme : String) {
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

    public static func setIdentifiers(fromJSON json : String) {
        let data : Data? = json.data(using: .utf8)
        do {
            let identifiers = try JSONDecoder().decode(FanMakerSDKIdentifiers.self, from: data!)
            if identifiers.user_id != nil { FanMakerSDK.setUserID(identifiers.user_id!) }
            if identifiers.member_id != nil { FanMakerSDK.setMemberID(identifiers.member_id!) }
            if identifiers.student_id != nil { FanMakerSDK.setStudentID(identifiers.student_id!) }
            if identifiers.ticketmaster_id != nil { FanMakerSDK.setTicketmasterID(identifiers.ticketmaster_id!) }
            if identifiers.yinzid != nil { FanMakerSDK.setYinzid(identifiers.yinzid!) }
            if identifiers.push_token != nil { FanMakerSDK.setPushNotificationToken(identifiers.push_token!) }
            if identifiers.fanmaker_identifiers != nil { FanMakerSDK.setFanMakerIdentifiers(dictionary: identifiers.fanmaker_identifiers!) }
        } catch { }
    }
}
