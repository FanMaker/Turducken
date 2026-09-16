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
    public var loadingBackgroundColor : UIColor = UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1.00)
    public var loadingForegroundImage : UIImage? = nil
    public var useDarkLoadingScreen : Bool = true

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

    public let FanMakerSDKSessionToken : String = "FanMakerSDKSessionToken"
    public let FanMakerSDKJSONIdentifiers : String = "FanMakerSDKJSONIdentifiers"
    public let FanMakerSDKJSONParameters : String = "FanMakerSDKJSONParameters"
    public let FanMakerSDKAllowedDomains : String = "FanMakerSDKAllowedDomains"

    public var deepLinkPath: String?
    public var baseURL : String?
    // First-party hosts (lowercased) the app may open inside the SDK webview.
    // Populated from the `site_details/sdk` response and persisted so it is
    // available immediately on a cold-start push tap. See FanMaker/app#1885.
    public var allowedDomains : [String] = []
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

    // Store the first-party host allowlist (from site_details/sdk) and persist
    // it so a cold-start push tap can classify links before the next fetch.
    public func updateAllowedDomains(_ domains: [String]) {
        self.allowedDomains = domains.compactMap { normalizeHost($0) }
        self.userDefaults?.set(self.allowedDomains, forKey: self.FanMakerSDKAllowedDomains)
    }

    // Normalize a stored domain or URL down to a bare lowercased host.
    private func normalizeHost(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("://"), let host = URL(string: trimmed)?.host {
            return host.lowercased()
        }
        // Bare host possibly with a trailing path — keep the host segment only.
        return trimmed.split(separator: "/").first.map { $0.lowercased() }
    }

    // True when `url` is a web link the app should hand to the system browser
    // rather than route into the in-app webview: an http(s) URL whose host is
    // not in the first-party allowlist (nor the currently loaded base host).
    // Custom-scheme URLs and relative paths return false (handled elsewhere).
    public func isExternalWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        guard let host = url.host?.lowercased() else { return false }

        var allowed = allowedDomains
        if let base = baseURL, let baseHost = URL(string: base)?.host?.lowercased() {
            allowed.append(baseHost)
        }

        // Fails OPEN when we know of no first-party hosts yet, which is the
        // window between launch and site_details/sdk answering. Treating
        // everything as external there would eject links we own, and this call
        // decides whether to throw out a link a page we already trust asked us
        // to follow - so not knowing has to mean "carry on as before".
        if allowed.isEmpty { return false }

        return !allowed.contains(host)
    }

    /// True when `host` is somewhere the SDK is willing to load inside its own
    /// webview: the site's own host, or one its `allowed_domains` names.
    ///
    /// Fails CLOSED, the opposite of `isExternalWebURL`, and the asymmetry is
    /// deliberate. This decides whether to admit a destination handed to us
    /// from outside - a push payload, a universal link - where not knowing has
    /// to mean no.
    private func isFirstPartyHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        if allowedDomains.contains(host) { return true }
        if let base = baseURL, let baseHost = URL(string: base)?.host?.lowercased() {
            return baseHost == host
        }
        return false
    }

    // Used for "Deep Linking"
    public func handleUrl(_ url: URL) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)

        guard let host = components?.host, let path = components?.path else {
            return false
        }

        guard canHandleUrl(url) else {
            NSLog("FanMaker will not route \(url.absoluteString): not a first-party destination")
            return false
        }

        self.deepLinkPath = path

        if let baseURL = self.baseURL,
           let webView = self.currentWebView,
           let composed = fanMakerComposeURL(baseURL: baseURL, deepLinkPath: path) {
            webView.load(URLRequest(url: composed))
        }

        return true
    }

    /// Queues `path` as the next destination inside the FanMaker webview, with
    /// no hostname convention at all - `openPath("/store")` is enough.
    ///
    /// The escape hatch for a host that knows a link is ours and should not have
    /// to encode that as a magic hostname, and for push payloads carrying a bare
    /// path. Mirrors the Android SDK's call of the same name.
    @discardableResult
    public func openPath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            NSLog("FanMaker openPath called with an empty path; ignoring")
            return false
        }

        // A path must not carry a destination of its own. "//host/x" is
        // protocol-relative rather than a path - it parses as an authority - so
        // accepting it would let a caller point the webview at a host of their
        // choosing. Same for anything with an explicit scheme; that is
        // handleUrl's job, and it checks the host.
        let components = URLComponents(string: trimmed)
        if trimmed.hasPrefix("//") || components?.scheme != nil || components?.host != nil {
            NSLog("FanMaker openPath expects a path such as /store, got something carrying a host or scheme: \(trimmed) (use handleUrl for a full URL)")
            return false
        }

        self.deepLinkPath = trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
        return true
    }

    // Used for "Deep Linking"
    public func canHandleUrl(_ url: URL) -> Bool {
        // Parse the URL and check if it can be handled.
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)

        guard let host = components?.host else {
            return false
        }

        // Legacy form: any scheme whose host is literally fanmaker, as in
        // clientapp://fanmaker/... Kept working so existing integrations that
        // shape their links this way do not have to change.
        if host.lowercased() == "fanmaker" || host.lowercased() == "fanmaker.com" {
            return true
        }

        // A first-party web link - the site's own host or one of its allowed
        // domains. This is the shape a push notification's destination actually
        // arrives in, and it used to be rejected out of hand, so a link reached
        // NUX only if whoever composed it happened to use the magic hostname.
        let scheme = components?.scheme?.lowercased()
        if scheme == "http" || scheme == "https" {
            return isFirstPartyHost(host)
        }

        return false
    }

    public init() {}

    public func initialize(apiKey : String) {
        self.apiKey = apiKey
        self.locationEnabled = true // As of 2.0.3, we are making location enabled by default to help some clients with location tracking setup
        self.userDefaults = FanMakerSDKUserDefaults(sdk: self)

        // Identifiers are restored whether or not a session token is present.
        //
        // They used to be restored only alongside a live token, which had it
        // backwards: identifiers are the *input* to authentication, not a
        // product of it. loginUserFromParams posts them to
        // /site/auth/auto_login and FanMakerSDKWebView calls it on every open,
        // so gating them on an existing token suppressed the exact flow that
        // obtains one - a returning fan whose token had gone could not be
        // auto-logged in from identifiers already sitting on the device.
        //
        // Ending a session is now an explicit act: see logout().
        let defaults = self.userDefaults
        if let json = defaults?.string(forKey: self.FanMakerSDKJSONIdentifiers), !json.isEmpty {
            self.setIdentifiers(fromJSON: json)
        }

        // Restore the persisted first-party host allowlist so a cold-start push
        // tap can classify external links before site_details/sdk responds.
        if let storedDomains = defaults?.value(forKey: self.FanMakerSDKAllowedDomains) as? [String] {
            self.allowedDomains = storedDomains
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

    /// Blocking form, kept for hosts that call it directly.
    ///
    /// Stalls the calling thread for up to 5 seconds — on the main thread that is a
    /// visible freeze. Prefer `loginUserFromParams(completion:)`.
    public func loginUserFromParams() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        loginUserFromParams { result in
            success = result
            semaphore.signal()
        }

        // Wait for the request to complete
        _ = semaphore.wait(timeout: .now() + 5.0)
        return success
    }

    /// Logs the fan in from whatever identifiers are set, without blocking.
    ///
    /// `completion` runs on whichever thread the HTTP layer answers on, and reports
    /// whether a user token was obtained. Answers `false` immediately when there are
    /// no identifiers to send.
    public func loginUserFromParams(completion: @escaping (Bool) -> Void) {
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
            completion(false)
            return
        }

        // Make the API request
        FanMakerSDKHttp.post(sdk: self, path: "/site/auth/auto_login", body: identifiers, useSiteApiToken: true) { result in
            print("FanMaker ----------------------------------------- >> Auto Login Attempt")
            var success = false
            switch result {
            case .success(let response):
                print("FanMaker Status: \(response.status)")
                print("FanMaker Message: \(response.message)")
                if response.status == 200 {
                    // If the response data is a dictionary, set it as the user token
                    if let tokenData = response.data as? [String: Any] {
                        self.fanmakerUserToken = tokenData
                        success = true
                        print("FanMaker \u{2713} Auto login successful - token set")
                    } else {
                        print("FanMaker \u{2717} Auto login failed - invalid token data format")
                    }
                } else {
                    print("FanMaker \u{2717} Auto login failed - non-200 status")
                }
            case .failure(let error):
                print("FanMaker \u{2717} Auto login failed with error: \(error)")
            }
            print("FanMaker ----------------------------------------- << Auto Login Attempt")

            completion(success)
        }
    }

    public func isInitialized() -> Bool {
        return apiKey != ""
    }

    public func setUserID(_ value : String) {
        self.userID = value
        persistIdentifiers()
    }

    public func setMemberID(_ value : String) {
        self.memberID = value
        persistIdentifiers()
    }

    public func setStudentID(_ value : String) {
        self.studentID = value
        persistIdentifiers()
    }

    public func setTicketmasterID(_ value : String) {
        self.ticketmasterID = value
        persistIdentifiers()
    }

    public func setYinzid(_ value : String) {
        self.yinzid = value
        persistIdentifiers()
    }

    public func setPushNotificationToken(_ value : String) {
        self.pushToken = value
        persistIdentifiers()
    }

    public func setFanMakerIdentifiers(dictionary: [String: Any] = [:]) -> [String: Any] {
        var idLexicon = (self.fanmakerIdentifierLexicon as? [String: Any]) ?? [:]

        for key in dictionary.keys {
            idLexicon[key] = dictionary[key]
        }

        self.fanmakerIdentifierLexicon = idLexicon
        persistIdentifiers()

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

    public func disableDarkLoadingScreen() {
        self.useDarkLoadingScreen = false
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
            if identifiers.fanmaker_identifiers != nil { _ = self.setFanMakerIdentifiers(dictionary: identifiers.fanmaker_identifiers!) }
        } catch {
            // This used to be silent, which is how a decoding bug in
            // fanmaker_identifiers went unnoticed while dropping every
            // identifier alongside it.
            NSLog("FanMaker could not read identifiers: \(error)")
        }
    }

    // MARK: - Session Token Persistence

    /// The current session token, read from UserDefaults.
    public var sessionToken: String? {
        return self.userDefaults?.string(forKey: self.FanMakerSDKSessionToken)
    }

    /// Updates the session token stored in UserDefaults.
    /// Called by the token resolver after a successful OAuth token refresh.
    public func updateSessionToken(_ tokenString: String) {
        self.userDefaults?.set(tokenString, forKey: self.FanMakerSDKSessionToken)
    }

    // MARK: - Presenting the FanMaker UI

    /// The screen this instance currently has on display, if any. Weak, so a
    /// screen the host tore down itself cannot keep this instance believing it
    /// is still showing something.
    private weak var presentedScreen: FanMakerSDKWebViewController?

    /// How `present()` puts the FanMaker UI on screen when no style is passed
    /// to the call itself.
    ///
    /// Defaults to `.sheet`, and that default matters: NUX does not draw a
    /// close button on its login page, so a fan who opens the UI and does not
    /// want to sign in has no way out of a full screen presentation. A sheet
    /// means iOS provides the way out - a grabber and swipe to dismiss - and
    /// the fan is never trapped by content that has no close control of its
    /// own.
    public var presentationStyle: FanMakerSDKPresentationStyle = .sheet

    /// Whether this instance currently has a FanMaker screen on display.
    public var isPresenting: Bool {
        guard let screen = presentedScreen else { return false }
        // Deliberately not checking that the view is in a window: a screen that
        // is still animating in is presented as far as a second present() call
        // is concerned, and that is the case worth refusing.
        return !screen.isBeingDismissed
            && (screen.presentingViewController != nil || screen.parent != nil)
    }

    /// Puts the FanMaker UI on screen, full screen, without the host having to
    /// build or place anything.
    ///
    /// A host previously had to construct a view controller, decide how to
    /// present it, and wire up dismissing it, which is most of the setup that
    /// integrations get wrong. This is the counterpart of what the Android SDK
    /// already does with its own activity: hand over one call and let the SDK
    /// own the screen for its whole life, closing included.
    ///
    /// Presented full screen deliberately. NUX draws its own close affordance
    /// and its own branding, so SDK chrome on top would give a fan two close
    /// buttons, and a partial-height sheet would break the full-bleed
    /// presentation the integration checklist asks for.
    ///
    /// Returns false when there was nowhere to present from, or when this
    /// instance already has a screen up - the same one-screen-per-instance rule
    /// the Android SDK applies per key, so a double tap cannot stack two
    /// copies a fan then has to dismiss twice.
    ///
    /// Hosts that need to own presentation themselves can keep doing so:
    /// construct `FanMakerSDKWebViewController`, or use
    /// `FanMakerSDKWebViewControllerRepresentable` in SwiftUI, exactly as
    /// before. Nothing here is required.
    /// - Parameter style: how to present, just this once. Omit it to use
    ///   `presentationStyle`, which is `.sheet` unless you have changed it.
    @available(iOS 13.0, *)
    @discardableResult
    public func present(
        style: FanMakerSDKPresentationStyle? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) -> Bool {
        if !Thread.isMainThread {
            var result = false
            DispatchQueue.main.sync {
                result = self.present(style: style, animated: animated, completion: completion)
            }
            return result
        }

        if !isInitialized() {
            NSLog("FanMaker cannot present: initialize(apiKey:) has not been called yet")
            return false
        }

        if isPresenting {
            NSLog("FanMaker is already presenting a screen for this instance; ignoring the request")
            return false
        }

        guard let host = FanMakerSDK.topmostViewController() else {
            NSLog("FanMaker cannot present: no visible view controller to present from")
            return false
        }

        return present(from: host, style: style, animated: animated, completion: completion)
    }

    /// Puts the FanMaker UI on screen from a view controller you name.
    ///
    /// `present()` finds the topmost controller itself, which is what most
    /// hosts want. This is for the cases where that guess is wrong - an app
    /// driving several scenes, or one that wants the UI to come from a specific
    /// place in its hierarchy.
    /// - Parameter style: how to present, just this once. Omit it to use
    ///   `presentationStyle`, which is `.sheet` unless you have changed it.
    @available(iOS 13.0, *)
    @discardableResult
    public func present(
        from host: UIViewController,
        style: FanMakerSDKPresentationStyle? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) -> Bool {
        if !Thread.isMainThread {
            var result = false
            DispatchQueue.main.sync {
                result = self.present(from: host, style: style, animated: animated, completion: completion)
            }
            return result
        }

        if !isInitialized() {
            NSLog("FanMaker cannot present: initialize(apiKey:) has not been called yet")
            return false
        }

        if isPresenting {
            NSLog("FanMaker is already presenting a screen for this instance; ignoring the request")
            return false
        }

        let screen = FanMakerSDKWebViewController(sdk: self)
        apply(style ?? presentationStyle, to: screen)
        presentedScreen = screen

        // Only when the SDK is doing the presenting: a host that presents the
        // controller itself owns its own presentation controller delegate, and
        // taking that over would break their dismissal handling.
        screen.presentationController?.delegate = screen

        host.present(screen, animated: animated, completion: completion)
        return true
    }

    @available(iOS 13.0, *)
    private func apply(_ style: FanMakerSDKPresentationStyle, to screen: UIViewController) {
        switch style {
        case .sheet:
            screen.modalPresentationStyle = .pageSheet
            if #available(iOS 15.0, *), let sheet = screen.sheetPresentationController {
                // One detent, at full height. The point is the grabber and the
                // swipe, not a half-height card - the content is a full site
                // and wants the room.
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
            // On iOS 13 and 14 .pageSheet is already a swipe-dismissable card,
            // which is the behaviour that matters here even without detents.
        case .fullScreen:
            screen.modalPresentationStyle = .fullScreen
        }
    }

    /// Closes a screen this instance put on display with `present()`.
    ///
    /// Only needed by a host that wants to close the UI from its own code;
    /// web content triggering the close action already unwinds itself.
    @available(iOS 13.0, *)
    public func dismiss(animated: Bool = true) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.dismiss(animated: animated) }
            return
        }
        presentedScreen?.dismissSelf(animated: animated)
        presentedScreen = nil
    }

    /// The view controller a new screen should be presented from: the deepest
    /// thing already on display, so the FanMaker UI lands on top of whatever
    /// the fan is currently looking at rather than underneath it.
    @available(iOS 13.0, *)
    private static func topmostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        // Prefer the active scene's key window. UIWindowScene.keyWindow is
        // iOS 15 and up, and this package supports iOS 13, so the key window is
        // found by asking the windows themselves.
        let orderedWindows =
            scenes.filter { $0.activationState == .foregroundActive }.flatMap { $0.windows }
            + scenes.flatMap { $0.windows }

        let root = orderedWindows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? orderedWindows.first(where: { !$0.isHidden })?.rootViewController

        guard var candidate = root else { return nil }

        // Walk past anything already presented, and into containers, so we do
        // not try to present from a controller that is not actually visible.
        while true {
            if let presented = candidate.presentedViewController, !presented.isBeingDismissed {
                candidate = presented
            } else if let navigation = candidate as? UINavigationController,
                      let top = navigation.visibleViewController {
                candidate = top
            } else if let tabs = candidate as? UITabBarController,
                      let selected = tabs.selectedViewController {
                candidate = selected
            } else {
                return candidate
            }
        }
    }

    // MARK: - Identifier Persistence

    /// Writes the current identifier set to the same UserDefaults blob the web
    /// bridge writes, so there is one persisted representation and one restore
    /// path rather than two schemes that can disagree.
    ///
    /// Identifiers supplied by a host used to be memory-only: only the ones
    /// arriving from the web bridge were persisted, so a host that set them
    /// once at login silently stopped sending them from the next cold start.
    private func persistIdentifiers() {
        guard let defaults = self.userDefaults else { return }

        var payload: [String: Any] = [:]
        if !self.userID.isEmpty { payload["user_id"] = self.userID }
        if !self.memberID.isEmpty { payload["member_id"] = self.memberID }
        if !self.studentID.isEmpty { payload["student_id"] = self.studentID }
        if !self.ticketmasterID.isEmpty { payload["ticketmaster_id"] = self.ticketmasterID }
        if !self.yinzid.isEmpty { payload["yinzid"] = self.yinzid }
        if !self.pushToken.isEmpty { payload["push_token"] = self.pushToken }
        if !self.fanmakerIdentifierLexicon.isEmpty {
            payload["fanmaker_identifiers"] = self.fanmakerIdentifierLexicon
        }

        if payload.isEmpty {
            defaults.set("", forKey: self.FanMakerSDKJSONIdentifiers)
            return
        }

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            NSLog("FanMaker could not persist identifiers; leaving the stored copy alone")
            return
        }

        defaults.set(json, forKey: self.FanMakerSDKJSONIdentifiers)
    }

    // MARK: - Ending a Session

    /// Forgets the fan completely: every identifier, the session token, and the
    /// auto-login user token. This is what a host should call on sign-out.
    ///
    /// Clearing identifiers alone is not a sign-out. The session token is what
    /// authenticates the fan, so leaving it behind means the next person to
    /// open the webview arrives logged in as the previous one, whatever the
    /// identifiers say.
    public func logout() {
        clearIdentifiers()
        clearSessionToken()
        NSLog("FanMaker logged out: identifiers and session token cleared")
    }

    /// Forgets the session token and the auto-login user token, leaving
    /// identifiers in place so the next open can re-authenticate the same fan.
    public func clearSessionToken() {
        self.userDefaults?.set("", forKey: self.FanMakerSDKSessionToken)
        self.fanmakerUserToken = [:]
    }

    /// Forgets every identifier, in memory and on disk.
    ///
    /// This does not end the session - see logout(), which is almost certainly
    /// what a sign-out path wants.
    public func clearIdentifiers() {
        self.userID = ""
        self.memberID = ""
        self.studentID = ""
        self.ticketmasterID = ""
        self.yinzid = ""
        self.pushToken = ""
        self.fanmakerIdentifierLexicon = [:]
        self.userDefaults?.set("", forKey: self.FanMakerSDKJSONIdentifiers)
    }
}
