import Foundation
import UIKit
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
    public var fanmakerUserToken: [String: Any] = [:]
    public var locationEnabled : Bool = true // As of 2.0.3, we are making location enabled by default to help some clients with location tracking setup
    public var loadingBackgroundColor : UIColor = UIColor.white
    public var loadingForegroundImage : UIImage? = nil
    public var useDarkLoadingScreen : Bool = false

    public var userLoginDebounce : Bool = false

    // Closure-based callback for close action (single listener)
    // Usage: sdk.onClose = { params in ... }
    public var onClose: (([String: Any]) -> Void)?

    // NotificationCenter notification name for close action (supports multiple listeners)
    public static let closeSdk = Notification.Name("FanMakerSDKClose")
    
    // Dictionary of action handlers for dynamic action support
    // Usage: sdk.onAction("reload") { params in ... }
    private var actionHandlers: [String: (([String: Any]) -> Void)] = [:]
    
    // Register a handler for a specific action
    // Usage: sdk.onAction("reload") { params in print("Reloading with params: \(params)") }
    public func onAction(_ actionName: String, handler: @escaping ([String: Any]) -> Void) {
        actionHandlers[actionName] = handler
    }
    
    // Remove a handler for a specific action
    public func removeActionHandler(_ actionName: String) {
        actionHandlers.removeValue(forKey: actionName)
    }
    
    // Get handler for a specific action (internal use)
    internal func getActionHandler(_ actionName: String) -> (([String: Any]) -> Void)? {
        return actionHandlers[actionName]
    }
    
    // Generate notification name for a specific action
    // Usage: NotificationCenter.default.addObserver(..., name: FanMakerSDK.actionNotificationName("reload"), ...)
    public static func actionNotificationName(_ actionName: String) -> Notification.Name {
        return Notification.Name("FanMakerSDKAction_\(actionName)")
    }

    // NOTE: This will be used if we use the OAuth Methods
    // private var publicOauthToken: String?
    // private var publicOauthTokenExpiration: Date?
    // private var siteOauthToken: String?
    // private var siteOauthTokenExpiration: Date?

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

        // NOTE: this will be used if we switch to the OAuth method of access tokens for API3
        // Get OAuth token during initialization
        // self.getValidOAuthToken { [weak self] result in
        //     switch result {
        //     case .success(let token):
        //         self?.publicOauthToken = token
        //         // Set token expiration to 1 hour from now
        //         self?.publicOauthTokenExpiration = Date().addingTimeInterval(3600)

        //     case .failure(let error):
        //         print("Failed to get OAuth token: \(error.localizedDescription)")
        //     }
        // }

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

    public func loginUserFromParams() -> Bool {
        // Create a dictionary with all user identifiers
        var identifiers: [String: Any] = [:]

        // Add all the individual identifiers if they exist
        if !self.userID.isEmpty { identifiers["user_id"] = self.userID }
        if !self.memberID.isEmpty { identifiers["member_id"] = self.memberID }
        if !self.studentID.isEmpty { identifiers["student_id"] = self.studentID }
        if !self.ticketmasterID.isEmpty { identifiers["ticketmaster_id"] = self.ticketmasterID }
        if !self.yinzid.isEmpty { identifiers["yinzid"] = self.yinzid }

        // Add the fanmaker identifiers lexicon
        if !self.fanmakerIdentifierLexicon.isEmpty {
            identifiers["fanmaker_identifiers"] = self.fanmakerIdentifierLexicon
        }

        // Return early if there are no identifiers to send
        if identifiers.isEmpty {
            return false
        }

        // Create a semaphore to make the request synchronous
        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        // Make the API request
        FanMakerSDKHttp.post(sdk: self, path: "/site/auth/auto_login", body: identifiers, useSiteApiToken: true) { result in
            switch result {
            case .success(let response):
                if response.status == 200 {
                    // If the response data is a dictionary, set it as the user token
                    if let tokenData = response.data as? [String: Any] {
                        self.fanmakerUserToken = tokenData
                        success = true
                    }
                }
            case .failure(let error):
                print("Login failed with error: \(error)")
            }
            
            semaphore.signal()
        }

        // Wait for the request to complete
        _ = semaphore.wait(timeout: .now() + 5.0)
        return success
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
    public func jsonValueForKey(forKey key: String) -> String {
        // Use Mirror to reflect on self
        let mirror = Mirror(reflecting: self)
        var returnString = ""

        // Iterate over each child in the mirrored properties
        for child in mirror.children {
            // Check if the child's label matches the key
            if child.label == key {
                // If the value is a dictionary, return it directly
                if let dictionary = child.value as? [String: Any] {
                    if let jsonData = try? JSONSerialization.data(withJSONObject: dictionary),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        // Escape all quotes except the first and last
                        let escapedJson = jsonString.replacingOccurrences(of: "\"", with: "\\\"")
                        let jsString = "FanmakerSDKCallback(\"\(escapedJson)\")"
                        return jsString
                    }
                }
                // For non-dictionary values, use String(describing:)
                returnString = String(describing: child.value)
            }

            // Check if the property is a dictionary of [String: Any]
            if let dictionary = child.value as? [String: Any],
               let dictionaryValue = dictionary[key] {
                // If the dictionary value is itself a dictionary, return it directly
                if let nestedDict = dictionaryValue as? [String: Any],
                   let jsonData = try? JSONSerialization.data(withJSONObject: nestedDict),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    // Escape all quotes except the first and last
                    let escapedJson = jsonString.replacingOccurrences(of: "\"", with: "\\\"")
                    let jsString = "FanmakerSDKCallback(\"\(escapedJson)\")"
                    return jsString
                }
                // For non-dictionary values, use String(describing:)
                returnString = String(describing: dictionaryValue)
            }
        }

        // For non-dictionary values, return them directly
        if returnString != "" {
            let escapedValue = returnString.replacingOccurrences(of: "\"", with: "\\\"")
            return "FanmakerSDKCallback(\"{ \\\"value\\\": \(escapedValue) }\")"
        }

        // Return empty JSON object if no property with the given key is found
        return "{}"
    }

    public func sdkOpenUrl(scheme : String) {
        if let url = URL(string: scheme) {
            UIApplication.shared.open(url, options: [:]) { success in
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

    // ------------------------------------------------------------------------------------------------------------------------------------
    // OAuth Methods
    // NOTE: I started writing some methods for OAuth and then we decided to not implment it for the time being.
    // If we revisit this, we need to have the client provide us with a oauth client id and then we need to fetch access tokens
    // for both public and the site when the SDK is initialized. At the time of writing, the public exchange works but the site
    // exchange hasn't been impemented.
    // ------------------------------------------------------------------------------------------------------------------------------------

    // Helper method to get a valid OAuth token
    // public func getValidOAuthToken(completion: @escaping (Result<String, Error>) -> Void) {
    //     // Check if we have a valid token
    //     if let token = publicOauthToken,
    //        let expiration = publicOauthTokenExpiration,
    //        expiration > Date() {
    //         completion(.success(token))
    //         return
    //     }

    //     // If token is expired or doesn't exist, request a new one
    //     requestOAuthToken { [weak self] result in
    //         switch result {
    //         case .success(let response):
    //             if let accessToken = response["access_token"] as? String,
    //                let createdAt = response["created_at"] as? TimeInterval,
    //                let expiresIn = response["expires_in"] as? TimeInterval {
    //                 self?.publicOauthToken = accessToken
    //                 // Convert Unix timestamp to Date and add expiration duration
    //                 let expirationDate = Date(timeIntervalSince1970: createdAt).addingTimeInterval(expiresIn)
    //                 self?.publicOauthTokenExpiration = expirationDate
    //                 completion(.success(accessToken))
    //             } else {
    //                 let errorResponse: [String: Any] = [
    //                     "error": "Required fields missing from response",
    //                     "error_code": -1,
    //                     "error_type": "invalid_response",
    //                     "details": "Response must contain access_token, created_at, and expires_in"
    //                 ]
    //                 completion(.failure(NSError(domain: "FanMakerSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: errorResponse])))
    //             }
    //         case .failure(let error):
    //             completion(.failure(error))
    //         }
    //     }
    // }

    // NOTE: This works to fetch a public OAuth Access token if we have a client id.
    // TODO: if we implement OAuth for API3, make the client give us the OAuth application client id
    // so that we don't have to bake into the SDK somewhere
    // public func requestOAuthToken(completion: @escaping (Result<[String: Any], Error>) -> Void) {
    //     let clientId = FanMakerConfig.clientId
    //     guard !clientId.isEmpty else {
    //         let errorResponse: [String: Any] = [
    //             "error": "Client ID not configured",
    //             "error_code": -1,
    //             "error_type": "configuration_error"
    //         ]
    //         completion(.failure(NSError(domain: "FanMakerSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: errorResponse])))
    //         return
    //     }

    //     // Create the request URL
    //     guard let url = URL(string: "\(FanMakerSDKHttpRequest.apiBase)/oauth/token") else {
    //         let errorResponse: [String: Any] = [
    //             "error": "Invalid URL",
    //             "error_code": -1,
    //             "error_type": "invalid_url"
    //         ]
    //         completion(.failure(NSError(domain: "FanMakerSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: errorResponse])))
    //         return
    //     }

    //     // Create the request body
    //     let body: [String: String] = [
    //         "grant_type": "client_credentials",
    //         "client_id": clientId
    //     ]

    //     // Create the request
    //     var request = URLRequest(url: url)
    //     request.httpMethod = "POST"
    //     request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    //     request.setValue("application/json", forHTTPHeaderField: "Accept")

    //     // Add the request body
    //     do {
    //         request.httpBody = try JSONSerialization.data(withJSONObject: body)
    //     } catch {
    //         let errorResponse: [String: Any] = [
    //             "error": "Failed to serialize request body",
    //             "error_code": -1,
    //             "error_type": "serialization_error",
    //             "details": error.localizedDescription
    //         ]
    //         completion(.failure(NSError(domain: "FanMakerSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: errorResponse])))
    //         return
    //     }

    //     // Make the request
    //     let task = URLSession.shared.dataTask(with: request) { data, response, error in
    //         if let error = error {
    //             let errorResponse: [String: Any] = [
    //                 "error": "Network request failed",
    //                 "error_code": -1,
    //                 "error_type": "network_error",
    //                 "details": error.localizedDescription
    //             ]
    //             completion(.failure(NSError(domain: "FanMakerSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: errorResponse])))
    //             return
    //         }

    //         guard let data = data else {
    //             let errorResponse: [String: Any] = [
    //                 "error": "No data received",
    //                 "error_code": -1,
    //                 "error_type": "no_data"
    //             ]
    //             completion(.failure(NSError(domain: "FanMakerSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: errorResponse])))
    //             return
    //         }

    //         do {
    //             if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
    //                 completion(.success(json))
    //             } else {
    //                 let errorResponse: [String: Any] = [
    //                     "error": "Invalid response format",
    //                     "error_code": -1,
    //                     "error_type": "invalid_format"
    //                 ]
    //                 completion(.failure(NSError(domain: "FanMakerSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: errorResponse])))
    //             }
    //         } catch {
    //             let errorResponse: [String: Any] = [
    //                 "error": "Failed to parse response",
    //                 "error_code": -1,
    //                 "error_type": "parsing_error",
    //                 "details": error.localizedDescription
    //             ]
    //             completion(.failure(NSError(domain: "FanMakerSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: errorResponse])))
    //         }
    //     }

    //     task.resume()
    // }
}
