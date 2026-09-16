//
//  File.swift
//
//
//  Created by Érik Escobedo on 28/05/21.
//

import Foundation
import UIKit
import SwiftUI
import WebKit

/// Forwards only the first result it is given and drops any that follow.
///
/// The token and auto-login steps each have a deadline as well as a completion, so
/// both can plausibly fire. Whichever arrives first wins.
private final class FanMakerSDKSingleShot<T> {
    private let lock = NSLock()
    private var hasFired = false
    private let body: (T) -> Void

    init(_ body: @escaping (T) -> Void) {
        self.body = body
    }

    func fire(_ value: T) {
        lock.lock()
        let alreadyFired = hasFired
        hasFired = true
        lock.unlock()

        guard !alreadyFired else { return }
        body(value)
    }
}

@available(iOS 13.0, *)
public struct FanMakerSDKWebView : UIViewRepresentable {
    public var webView : WKWebView
    let sdk: FanMakerSDK

    /// How long to wait for the session token to resolve before loading with what we have.
    private static let tokenResolutionTimeout: TimeInterval = 10.0
    /// How long to wait for auto-login before loading without its token.
    private static let autoLoginTimeout: TimeInterval = 5.0

    public init(sdk: FanMakerSDK, configuration: WKWebViewConfiguration) {
        self.sdk = sdk
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.sdk.currentWebView = self.webView
    }

    // MARK: - Loading

    /// Builds the request and loads it, without blocking the calling thread.
    ///
    /// `completion` reports whether a request was loaded, and runs on the main thread.
    /// This is the path the SDK itself uses; prefer it over `prepareUIView()`.
    public func prepareUIView(completion: @escaping (Bool) -> Void) {
        resolveUrlString { urlString in
            resolveRequestInputs(urlString: urlString) { inputs in
                // Headers are assembled on the main queue because they read state the
                // web bridge writes there, and `webView.load` is main-thread-only.
                DispatchQueue.main.async {
                    guard let inputs = inputs, let request = self.makeRequest(from: inputs) else {
                        completion(false)
                        return
                    }
                    self.webView.load(request)
                    completion(true)
                }
            }
        }
    }

    /// Blocking form, kept for hosts that call it directly.
    ///
    /// Stalls the calling thread until the site URL, auto-login and session token
    /// have all settled — on the main thread that is a visible freeze. Prefer
    /// `prepareUIView(completion:)`.
    public func prepareUIView() {
        let semaphore = DispatchSemaphore(value: 0)
        var built: URLRequest? = nil

        // Deliberately not routed through `prepareUIView(completion:)`: that one
        // finishes on the main queue, which would deadlock a main-thread caller
        // waiting here. Nothing below ever touches the main queue.
        resolveUrlString { urlString in
            self.resolveRequestInputs(urlString: urlString) { inputs in
                built = inputs.flatMap { self.makeRequest(from: $0) }
                semaphore.signal()
            }
        }
        semaphore.wait()

        if let built = built {
            self.webView.load(built)
        }
    }

    /// Resolves the site URL for this session, folding in any pending deep-link path.
    ///
    /// Never blocks. The completion runs on whichever thread the HTTP layer answers on.
    private func resolveUrlString(completion: @escaping (String) -> Void) {
        let instanceSdk = self.sdk
        let path = "site_details/sdk"

        FanMakerSDKHttp.get(sdk: instanceSdk, path: path, model: FanMakerSDKInfoResponse.self) { result in
            switch(result) {
            case .success(let response):
                let baseURL = response.data.url
                instanceSdk.updateBaseUrl(baseURL)

                var urlString: String
                if let deepLinkPath = instanceSdk.deepLinkPath, !deepLinkPath.isEmpty,
                   let composed = fanMakerComposeURL(baseURL: baseURL, deepLinkPath: deepLinkPath)?.absoluteString {
                    urlString = composed
                    instanceSdk.updateDeepLinkPath("")
                } else {
                    urlString = baseURL
                }

                if let beaconUniquenessThrottle = Int(response.data.beacons.uniqueness_throttle) {
                    instanceSdk.updateBeaconUniquenessThrottle(beaconUniquenessThrottle)
                }
                NSLog("FanMaker Info: Beacon Uniqueness Throttle settled to \(instanceSdk.beaconUniquenessThrottle) seconds")
                completion(urlString)
            case .failure(let error):
                NSLog("FanMaker Info: Error getting site details: \(error.localizedDescription)")
                completion("https://admin.fanmaker.com/500")
            }
        }
    }

    /// The pieces of a request that can only be known after the network answers.
    private struct ResolvedRequestInputs {
        let url: URL
        /// `nil` when the fan has no stored session token.
        let tokenType: FanMakerSDKTokenType?
        let rawTokenString: String
    }

    /// Runs auto-login and resolves the session token. Never blocks.
    ///
    /// Deliberately stops short of building the request: `applyHeaders` reads mutable
    /// state off the `sdk` object that the web bridge writes on the main thread, so
    /// the caller decides where that read happens.
    private func resolveRequestInputs(urlString: String,
                                      completion: @escaping (ResolvedRequestInputs?) -> Void) {
        let loginFinished = FanMakerSDKSingleShot<Void> { _ in
            guard let url = URL(string: urlString) else {
                NSLog("FanMaker Error: could not build a URL from \(urlString)")
                completion(nil)
                return
            }

            guard let token = self.sdk.sessionToken else {
                completion(ResolvedRequestInputs(url: url, tokenType: nil, rawTokenString: ""))
                return
            }

            self.resolveToken(token) { tokenType, rawTokenString in
                completion(ResolvedRequestInputs(url: url,
                                                 tokenType: tokenType,
                                                 rawTokenString: rawTokenString))
            }
        }

        // Auto-login sets `fanmakerUserToken`, which becomes a header below, so it has
        // to settle first. Its deadline matches the one the blocking version used.
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.autoLoginTimeout) {
            loginFinished.fire(())
        }
        sdk.loginUserFromParams { _ in
            loginFinished.fire(())
        }
    }

    /// Turns resolved inputs into the request to load. Reads `sdk` state, so it runs
    /// wherever the caller is willing to read that state.
    private func makeRequest(from inputs: ResolvedRequestInputs) -> URLRequest? {
        var request = URLRequest(url: inputs.url)

        if let tokenType = inputs.tokenType {
            let sessionHeaderValue = FanMakerSDKTokenResolver.sessionTokenHeaderValue(
                for: tokenType,
                rawTokenString: inputs.rawTokenString
            )
            let authHeaderValue = FanMakerSDKTokenResolver.authorizationHeaderValue(for: tokenType)

            request.setValue(sessionHeaderValue, forHTTPHeaderField: "X-FanMaker-SessionToken")
            request.setValue(authHeaderValue, forHTTPHeaderField: "Authorization")
        }

        return applyHeaders(to: request)
    }

    /// Resolves the stored token, refreshing an expired OAuth token first.
    ///
    /// Falls back to treating the raw string as an API token if resolution fails or
    /// outruns its deadline, matching what the blocking version did on timeout.
    private func resolveToken(_ token: String,
                              completion: @escaping (FanMakerSDKTokenType, String) -> Void) {
        let resolved = FanMakerSDKSingleShot<(FanMakerSDKTokenType, String)> { completion($0.0, $0.1) }
        // `onRefreshed` can land before `completion`, so the refreshed string is held
        // outside both and read when whichever one fires first gets there.
        let rawString = FanMakerSDKAtomicString(token)

        DispatchQueue.global().asyncAfter(deadline: .now() + Self.tokenResolutionTimeout) {
            resolved.fire((.apiToken(token), rawString.value))
        }

        FanMakerSDKTokenResolver.getValidToken(
            tokenString: token,
            apiBase: FanMakerSDKHttpRequest.apiBase,
            onRefreshed: { newTokenString in
                rawString.value = newTokenString
                self.sdk.updateSessionToken(newTokenString)
            },
            completion: { result in
                if case .success(let validType) = result {
                    resolved.fire((validType, rawString.value))
                } else {
                    resolved.fire((.apiToken(token), rawString.value))
                }
            }
        )
    }

    /// Applies every header the webview carries apart from the session token pair.
    ///
    /// Answers `nil` if any of the JSON-encoded headers cannot be serialised.
    private func applyHeaders(to request: URLRequest) -> URLRequest? {
        var request = request

        request.setValue(self.sdk.apiKey, forHTTPHeaderField: "X-FanMaker-Token")
        request.setValue(self.sdk.memberID, forHTTPHeaderField: "X-Member-ID")
        request.setValue(self.sdk.studentID, forHTTPHeaderField: "X-Student-ID")
        request.setValue(self.sdk.ticketmasterID, forHTTPHeaderField: "X-Ticketmaster-ID")
        request.setValue(self.sdk.yinzid, forHTTPHeaderField: "X-Yinzid")
        request.setValue(self.sdk.pushToken, forHTTPHeaderField: "X-PushNotification-Token")

        // ------------------------------------------------------------ >>> FanMaker Identifiers
        let jsonFanmakerIdentifiers: Data
        do {
            jsonFanmakerIdentifiers = try JSONSerialization.data(withJSONObject: self.sdk.fanmakerIdentifierLexicon)
        } catch {
            NSLog("FanMaker Error converting identifiers dictionary to JSON: \(error)")
            return nil
        }

        // Convert the JSON data to a string
        let jsonString = String(data: jsonFanmakerIdentifiers, encoding: .utf8)
        // Set the JSON string as the value for the HTTP header field
        request.setValue(jsonString, forHTTPHeaderField: "X-Fanmaker-Identifiers")
        // ------------------------------------------------------------ <<< FanMaker Identifiers

        // ------------------------------------------------------------ >>> FanMaker Parameters
        let jsonFanmakerParameters: Data
        do {
            jsonFanmakerParameters = try JSONSerialization.data(withJSONObject: self.sdk.fanmakerParametersLexicon)
        } catch {
            NSLog("FanMaker Error converting parameters dictionary to JSON: \(error)")
            return nil
        }

        // Convert the JSON data to a string
        let jsonParamString = String(data: jsonFanmakerParameters, encoding: .utf8)
        // Set the JSON string as the value for the HTTP header field
        request.setValue(jsonParamString, forHTTPHeaderField: "X-Fanmaker-Parameters")
        // ------------------------------------------------------------ <<< FanMaker Parameters

        // ------------------------------------------------------------ >>> FanMaker User Token
        let jsonFanmakerUserToken: Data
        do {
            jsonFanmakerUserToken = try JSONSerialization.data(withJSONObject: self.sdk.fanmakerUserToken)
        } catch {
            NSLog("FanMaker Error converting user token dictionary to JSON: \(error)")
            return nil
        }

        // Convert the JSON data to a string
        let jsonUserTokenString = String(data: jsonFanmakerUserToken, encoding: .utf8)
        // Set the JSON string as the value for the HTTP header field
        request.setValue(jsonUserTokenString, forHTTPHeaderField: "X-FanMaker-User-Token")
        // ------------------------------------------------------------ <<< FanMaker User Token

        // SDK Exclusive Token
        request.setValue("4.0.3", forHTTPHeaderField: "X-FanMaker-SDK-Version")

        // Theme preference: "dark" if dark loading screen is enabled, "light" otherwise
        let theme = self.sdk.useDarkLoadingScreen ? "dark" : "light"
        request.setValue(theme, forHTTPHeaderField: "X-Fanmaker-Theme")

        return request
    }

    public func makeUIView(context: Context) -> some UIView {
        prepareUIView { _ in }
        return self.webView
    }

    public func updateUIView(_ uiView: UIViewType, context: Context) {
        //
    }
}

/// A string that a refresh callback and a completion callback can touch from
/// different threads.
private final class FanMakerSDKAtomicString {
    private let lock = NSLock()
    private var storage: String

    init(_ value: String) {
        self.storage = value
    }

    var value: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
        set {
            lock.lock()
            storage = newValue
            lock.unlock()
        }
    }
}
