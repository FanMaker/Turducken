//
//  File.swift
//
//
//  Created by Érik Escobedo on 28/05/21.
//

import Foundation
import AuthenticationServices
import CoreLocation
import WebKit
import SwiftUI

@available(iOS 13.0, *)
open class FanMakerSDKWebViewController : UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    let sdk: FanMakerSDK

    public init(sdk: FanMakerSDK) {
        self.sdk = sdk
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var fanmaker : FanMakerSDKWebView? = nil
    private let locationManager : CLLocationManager = CLLocationManager()
    private let locationDelegate : FanMakerSDKLocationDelegate = FanMakerSDKLocationDelegate()
    private var authSession : ASWebAuthenticationSession?

    open override func viewDidLoad() {
        super.viewDidLoad()

        let userController : WKUserContentController = WKUserContentController()
        userController.add(self, name: "fanmaker")
        // The Android SDK's call, so a page asks for a sign-in the same way on
        // both platforms and checks for this object rather than an SDK version.
        userController.addUserScript(WKUserScript(
            source: "window.fanmakerAuthSession = { postMessage: function (json) { window.webkit.messageHandlers.fanmaker.postMessage({ authSession: JSON.parse(json) }); } };",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userController

        self.fanmaker = FanMakerSDKWebView(sdk: self.sdk, configuration: configuration)
        self.fanmaker?.webView.navigationDelegate = self

        self.view = UIView(frame: self.view!.bounds)
        self.view.backgroundColor = self.sdk.loadingBackgroundColor
        if !self.sdk.useDarkLoadingScreen {
            self.view.backgroundColor = UIColor.white
        }

        if let fgImage = self.sdk.loadingForegroundImage {
            let bounds = self.view!.bounds
            let x = bounds.width / 4
            let y = bounds.height / 2 - x * 3 / 2
            let loadingAnimation = UIImageView(frame: CGRect(x: x, y: y, width: 2 * x, height: 2 * x))
            loadingAnimation.image = fgImage
            self.view.addSubview(loadingAnimation)
        } else {

            let spinner = UIActivityIndicatorView(style: .large)
            spinner.color = self.sdk.useDarkLoadingScreen ? .white : .gray
            spinner.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.startAnimating()
            self.view.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
            ])
        }

        // Started only once the loading screen is up. Site details, auto-login and
        // token resolution all happen off the main thread; `webView(_:didFinish:)`
        // swaps the webview in when the page lands.
        self.fanmaker?.prepareUIView { loaded in
            if !loaded {
                NSLog("FanMaker Error: could not build the webview request - the loading screen will stay up")
            }
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        self.view = self.fanmaker!.webView

        // After a logout() before iOS 17: clear the page's own web storage, the
        // one piece WebKit can't remove per host from outside, then reload so
        // the page starts signed out. Only on one of our hosts.
        if self.sdk.clearsWebStorageOnNextLoad, !self.sdk.isExternalWebURL(webView.url ?? URL(string: "about:blank")!),
           let scheme = webView.url?.scheme, scheme == "https" {
            self.sdk.clearsWebStorageOnNextLoad = false
            webView.evaluateJavaScript("try { localStorage.clear(); sessionStorage.clear(); } catch (e) {}") { _, _ in
                webView.reload()
            }
        }
    }

    /// Sends links that leave first-party territory to the system browser
    /// instead of loading them in the SDK's webview.
    ///
    /// This used to be the host app's job: the SDK exposed `isExternalWebURL`
    /// and left every integration to call it, which is the sort of setup that
    /// gets skipped and then reported as a broken link. A partner or ticketing
    /// page loaded inside the SDK webview has no browser chrome, no way back,
    /// and none of the fan's existing session.
    ///
    /// Deliberately narrow about what counts, because SSO and checkout run
    /// *through* third-party pages and have to come back:
    /// - only a request for a new window (`target="_blank"`, `window.open`),
    ///   which 4.0 silently dropped. A same-window tap stays in the webview as
    ///   in 4.0: store checkouts, ticketing and sponsor pages NUX opens in
    ///   place keep the fan's in-app session. Never a redirect or a form post;
    /// - only from one of our own pages - once SSO has put the webview on the
    ///   provider's login page, that page's own links ("forgot password") have
    ///   to work in place, or the fan is handed a browser mid-sign-in.
    /// Our `*.fanmaker.com` hosts count as ours, which is what keeps the SSO
    /// entry tap itself (tmauth, nfl, seatgeek.fanmaker.com) in the webview.
    /// `isExternalWebURL` also fails open before `site_details/sdk` has
    /// answered, so nothing is ejected while the allowlist is still unknown.
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let opensANewWindow = navigationAction.targetFrame == nil

        guard FanMakerSDK.ejectsToBrowser(opensANewWindow: opensANewWindow,
                                          offFirstParty: self.sdk.shouldOpenInBrowser(url, from: webView.url)) else {
            decisionHandler(.allow)
            return
        }

        NSLog("FanMaker handing \(url.absoluteString) to the system browser: not a first-party host")
        decisionHandler(.cancel)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "fanmaker", let body = message.body as? Dictionary<String, Any> {
            let defaults = self.sdk.userDefaults

            body.forEach { key, value in
                switch(key) {
                case "sdkOpenUrl":
                    if let urlString = value as? String {
                        self.sdk.sdkOpenUrl(scheme: urlString)
                    }
                case "authSession":
                    self.startAuthSession(value, from: message.frameInfo)
                case "setToken":
                    if let token = value as? String {
                        defaults?.set(token, forKey: self.sdk.FanMakerSDKSessionToken)
                    }
                    var dict: [String: Any] = [:]
                    print("FanMaker ---------------------------------------------------------- Set Session Token Received")
                case "setIdentifiers":
                    if let token = value as? String {
                        self.sdk.setIdentifiers(fromJSON: token)
                        defaults?.set(token, forKey: self.sdk.FanMakerSDKJSONIdentifiers)
                    }
                case "requestLocationAuthorization":
                    locationManager.requestWhenInUseAuthorization()
                    locationManager.delegate = locationDelegate
                    locationManager.requestLocation()
                case "updateLocation":
                    if self.sdk.locationEnabled && CLLocationManager.locationServicesEnabled() {
                        locationManager.delegate = locationDelegate
                        locationDelegate.checkAuthorizationAndRequestLocation(locationManager) { result in
                            switch result {
                            case .success(let coordinates):
                                let cords = "{\"lat\":\(coordinates["lat"]!), \"lng\":\(coordinates["lng"]!)}"

                                NSLog("FanMaker Location Received ###############################################################")
                                self.fanmaker!.webView.evaluateJavaScript("FanMakerReceiveLocation(\(cords))")
                            case .failure(let error):
                                NSLog("FanMaker Location Could Not Be Determined #########################################################")
                                self.fanmaker!.webView.evaluateJavaScript("FanMakerReceiveLocationAuthorization(false)")
                            }
                        }
                    } else {
                        // This branch used to only log. JS saw pure silence and
                        // waited out NUX's whole retry cycle - five attempts at
                        // ten second intervals, ~50s - before falling back to
                        // navigator.geolocation. Answering false turns that
                        // hang into an immediate, correct answer; NUX already
                        // handles authorized == false, and the failure branch
                        // just above reports it the same way.
                        let reason = !self.sdk.locationEnabled
                            ? "location tracking is disabled on the SDK instance"
                            : "CLLocationManager.locationServicesEnabled() is false"
                        NSLog("FanMaker cannot provide a location: \(reason)")
                        self.fanmaker!.webView.evaluateJavaScript("FanMakerReceiveLocationAuthorization(false)")
                    }
                case "returnSDKInformation":
                    if let value = value as? String {
                        switch value {
                            case "locationServicesEnabled":
                                var authorizationStatus: CLAuthorizationStatus
                                if #available(iOS 14.0, *) {
                                    authorizationStatus = locationManager.authorizationStatus
                                } else {
                                    authorizationStatus = CLLocationManager.authorizationStatus()
                                }

                                var val = "Unknown"
                                switch authorizationStatus {
                                    case .authorizedAlways, .authorizedWhenInUse:
                                        if authorizationStatus == .authorizedAlways {
                                            val = "Always"
                                        } else {
                                            val = "When In Use"
                                        }
                                    case .denied, .restricted, .notDetermined:
                                        if authorizationStatus == .denied {
                                            val = "Denied"
                                        } else if authorizationStatus == .restricted {
                                            val = "Restricted"
                                        } else {
                                            val = "Not Determined"
                                        }
                                    @unknown default:
                                        val = "Unknown"
                                }

                                fanmaker!.webView.evaluateJavaScript("FanMakerSDKDebugData(\"\(val)\")")
                            case "locationEnabled":
                                var val = self.sdk.valueForKey(forKey: "locationEnabled")
                                fanmaker!.webView.evaluateJavaScript(val)
                            case "identifiers":
                                var val = self.sdk.valueForKey(forKey: "fanmakerIdentifierLexicon")
                                fanmaker!.webView.evaluateJavaScript(val)
                            case "userToken":
                                var val = self.sdk.valueForKey(forKey: "fanmakerUserToken")
                                fanmaker!.webView.evaluateJavaScript(val)
                            case "params":
                                var val = self.sdk.valueForKey(forKey: "fanmakerParametersLexicon")
                                fanmaker!.webView.evaluateJavaScript(val)
                            default:
                                var val = self.sdk.valueForKey(forKey: value)
                                fanmaker!.webView.evaluateJavaScript(val)
                                break
                        }
                    }
                case "action":
                    // Handle dynamic actions
                    if let actionValue = value as? String {
                        // Fetch "params" from the body
                        let params = body["params"] as? [String: Any] ?? [:]

                        // Check for registered handler first
                        if let handler = self.sdk.getActionHandler(actionValue) {
                            handler(params)
                        }
                        // Special handling for "close" action (backward compatibility)
                        else if actionValue == "close" {
                            // Same rule as Android: an integrator's own handler
                            // wins, and when there isn't one the SDK closes its
                            // own screen rather than leaving it on top of the
                            // host app with nothing listening. Before this,
                            // nothing on iOS dismissed anything - every
                            // integration had to wire that up itself, and the
                            // ones that did not left fans stuck on the page.
                            // Only a screen present() put up: a host that shows
                            // the SDK itself (4.0, README "Option 2") closes it
                            // from the closeSdk notification below, and a second
                            // dismiss here unwound one screen too far.
                            if let onClose = self.sdk.onClose {
                                onClose(params)
                            } else if self.sdk.didPresent(self) {
                                self.dismissSelf()
                            }
                        }

                        // Post notification for all actions (supports multiple listeners)
                        // This allows clients to listen via NotificationCenter without registering handlers
                        NotificationCenter.default.post(
                            name: FanMakerSDK.actionNotificationName(actionValue),
                            object: self.sdk,
                            userInfo: ["params": params, "action": actionValue]
                        )

                        // Also post the legacy closeSdk notification for backward compatibility
                        if actionValue == "close" {
                            NotificationCenter.default.post(
                                name: FanMakerSDK.closeSdk,
                                object: self.sdk,
                                userInfo: ["params": params]
                            )
                        }
                    } else {
                        print("FanMaker Action Value: \(value)")
                        // Fetch "params" from the body
                        if let params = body["params"] as? [String: Any] {
                            print("FanMaker Params: \(params)")
                        }
                    }
                case "fetchJSONValue":
                    if let value = value as? String {
                        switch value {
                            case "sessionToken":
                                let sessionToken = self.sdk.sessionToken ?? ""
                                let escapedToken = sessionToken.replacingOccurrences(of: "\"", with: "\\\"")
                                fanmaker!.webView.evaluateJavaScript("FanmakerSDKCallback(\"\(escapedToken)\")")
                            case "locationServicesEnabled":
                                var authorizationStatus: CLAuthorizationStatus
                                if #available(iOS 14.0, *) {
                                    authorizationStatus = locationManager.authorizationStatus
                                } else {
                                    authorizationStatus = CLLocationManager.authorizationStatus()
                                }

                                var val = "Unknown"
                                switch authorizationStatus {
                                    case .authorizedAlways, .authorizedWhenInUse:
                                        if authorizationStatus == .authorizedAlways {
                                            val = "Always"
                                        } else {
                                            val = "When In Use"
                                        }
                                    case .denied, .restricted, .notDetermined:
                                        if authorizationStatus == .denied {
                                            val = "Denied"
                                        } else if authorizationStatus == .restricted {
                                            val = "Restricted"
                                        } else {
                                            val = "Not Determined"
                                        }
                                    @unknown default:
                                        val = "Unknown"
                                }

                                let escapedValue = val.replacingOccurrences(of: "\"", with: "\\\"")
                                fanmaker!.webView.evaluateJavaScript("FanmakerSDKCallback(\"{ \\\"value\\\": \\\"\(escapedValue)\\\" }\")")
                            case "locationEnabled":
                                var val = self.sdk.jsonValueForKey(forKey: "locationEnabled")
                                fanmaker!.webView.evaluateJavaScript(val)
                            case "identifiers":
                                var val = self.sdk.jsonValueForKey(forKey: "fanmakerIdentifierLexicon")
                                fanmaker!.webView.evaluateJavaScript(val)
                            case "params":
                                var val = self.sdk.jsonValueForKey(forKey: "fanmakerParametersLexicon")
                                fanmaker!.webView.evaluateJavaScript(val)
                            case "userToken":
                                var val = self.sdk.jsonValueForKey(forKey: "fanmakerUserToken")
                                fanmaker!.webView.evaluateJavaScript(val)
                            default:
                                var val = self.sdk.jsonValueForKey(forKey: value)
                                fanmaker!.webView.evaluateJavaScript(val)
                                break
                        }
                    }
                default:
                    break;
                }
            }
        }
    }
}

/// How the SDK puts the FanMaker UI on screen.
public enum FanMakerSDKPresentationStyle {
    /// A sheet at full height, with iOS's grabber and swipe to dismiss.
    ///
    /// The default, and the safe one: NUX draws no close button on its login
    /// page, so a full screen presentation leaves a fan who does not want to
    /// sign in with no way out.
    case sheet

    /// Edge to edge, with no way out other than a close control in the content
    /// itself. Only appropriate where the content is known to draw one.
    case fullScreen
}

@available(iOS 13.0, *)
extension FanMakerSDKWebViewController: UIAdaptivePresentationControllerDelegate {
    /// A fan swiping the sheet away never goes through the web content's close
    /// action, so nothing would otherwise tell a host the UI had gone.
    ///
    /// This posts the close notification but deliberately does not invoke
    /// `onClose`: that closure is a request to *perform* a dismissal, and the
    /// dismissal has already happened here - calling it could send a host off
    /// to dismiss a container of their own that is still meant to be up.
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        NotificationCenter.default.post(
            name: FanMakerSDK.closeSdk,
            object: self.sdk,
            userInfo: ["params": ["source": "swipe"]]
        )
    }
}

@available(iOS 13.0, *)
extension FanMakerSDKWebViewController {
    /// Closes this screen, whichever way the host put it on screen.
    ///
    /// A host can present the SDK modally, push it onto a navigation stack, or
    /// embed it as a child view controller, and each needs a different call to
    /// undo. Rather than assume one, this asks the controller how it is
    /// contained and unwinds that.
    ///
    /// Called when web content triggers the close action and the integrator has
    /// not set `FanMakerSDK.onClose`.
    public func dismissSelf(animated: Bool = true) {
        // Always on the main thread; this can arrive from a WKScriptMessage.
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.dismissSelf(animated: animated) }
            return
        }

        if isBeingDismissed { return }

        if presentingViewController != nil {
            dismiss(animated: animated)
            return
        }

        if let navigation = navigationController, navigation.viewControllers.count > 1 {
            navigation.popViewController(animated: animated)
            return
        }

        if parent != nil {
            willMove(toParent: nil)
            view.removeFromSuperview()
            removeFromParent()
            return
        }

        // Nothing owns this controller in a way we can unwind - a host that
        // installed it as a window's root, for instance. Say so rather than
        // failing silently, since from a fan's point of view the close button
        // did nothing.
        NSLog("FanMaker: close requested but this screen is not presented, pushed or embedded, so the SDK cannot dismiss it. Set FanMakerSDK.onClose to handle closing yourself.")
    }

    /// Runs a sign-in in ASWebAuthenticationSession instead of this webview, for
    /// providers that cannot work inside one: passkeys are bound to the
    /// provider's own domain, and some identity providers refuse embedded
    /// webviews outright. The session hands back the link the sign-in ends on,
    /// which loads here like any deep link. FanMaker/NUX#907.
    private func startAuthSession(_ value: Any, from frame: WKFrameInfo) {
        guard frame.isMainFrame,
              let request = sdk.authSessionRequest(value, fromHost: frame.securityOrigin.host) else {
            NSLog("FanMaker refused an authSession request from \(frame.securityOrigin.host): \(value)")
            reportAuthSession("refused")
            return
        }
        guard authSession == nil else {
            // Answer, so the page resets its button instead of waiting forever.
            // "cancelled" leaves the open sign-in alone (the page does nothing).
            NSLog("FanMaker ignored an authSession request: one is already open")
            reportAuthSession("cancelled")
            return
        }

        let session = ASWebAuthenticationSession(url: request.url, callbackURLScheme: request.callbackScheme) { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.authSession = nil
                if let callbackURL = callbackURL, self.sdk.handleUrl(callbackURL) { return }
                let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                // An sso_login key signs whoever holds it in, so it stays out of logs.
                let returned = callbackURL?.absoluteString.replacingOccurrences(
                    of: "/sso_login/[^/?#]+", with: "/sso_login/…", options: .regularExpression)
                NSLog("FanMaker authSession ended without a sign-in: \(returned ?? error?.localizedDescription ?? "no result")")
                self.reportAuthSession(cancelled ? "cancelled" : "failed")
            }
        }
        session.presentationContextProvider = self
        // Private by default, so a sign-in neither uses nor changes the fan's
        // own Safari session. Ticketmaster's flow signs the fan out of
        // Ticketmaster before signing in; shared, that signed them out of Safari
        // on every FanMaker login. Passkeys still work, and iOS skips its "wants
        // to use ... to sign in" prompt for a private session.
        // Shared only when the page asks: SeatGeek's sign-in has to reuse the
        // one the host app made in Safari's session (FanMaker/NUX#1023). iOS
        // shows its "wants to use ... to sign in" prompt for that one.
        session.prefersEphemeralWebBrowserSession = !request.shared
        authSession = session
        NSLog("FanMaker opening \(request.url.absoluteString) in an authentication session")
        if !session.start() {
            authSession = nil
            reportAuthSession("failed")
        }
    }

    /// Tells the page a sign-in it asked for ended without one, so it can reset
    /// its button. A page that does not listen is left alone.
    private func reportAuthSession(_ status: String) {
        fanmaker?.webView.evaluateJavaScript("window.FanMakerReceiveAuthSession && window.FanMakerReceiveAuthSession(\"\(status)\")")
    }
}

@available(iOS 13.0, *)
extension FanMakerSDKWebViewController: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }
}

@available(iOS 13.0, *)
public struct FanMakerSDKWebViewControllerRepresentable : UIViewControllerRepresentable {
    let sdk: FanMakerSDK

    public init(sdk: FanMakerSDK) {
        self.sdk = sdk
    }

    public func makeUIViewController(context: Context) -> some UIViewController {
        return FanMakerSDKWebViewController(sdk: sdk)
    }

    public func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {

    }
}

