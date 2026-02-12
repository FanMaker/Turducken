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

@available(iOS 13.0, *)
public struct FanMakerSDKWebView : UIViewRepresentable {
    public var webView : WKWebView
    private var urlString : String = ""
    let sdk: FanMakerSDK

    public init(sdk: FanMakerSDK, configuration: WKWebViewConfiguration) {
        let instanceSdk = sdk
        self.sdk = sdk
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.sdk.currentWebView = self.webView

        let path = "site_details/sdk"

        let semaphore = DispatchSemaphore(value: 0)
        var urlString : String = ""
        DispatchQueue.global().async {
            FanMakerSDKHttp.get(sdk: instanceSdk, path: path, model: FanMakerSDKInfoResponse.self) { result in
                switch(result) {
                case .success(let response):
                    urlString = response.data.url
                    instanceSdk.updateBaseUrl(urlString)
                    if var deepLinkPath = instanceSdk.deepLinkPath, !deepLinkPath.isEmpty {
                        urlString += deepLinkPath
                        instanceSdk.updateDeepLinkPath("")
                    }

                    if let beaconUniquenessThrottle = Int(response.data.beacons.uniqueness_throttle) {
                        instanceSdk.updateBeaconUniquenessThrottle(beaconUniquenessThrottle)
                    }
                    NSLog("FanMaker Info: Beacon Uniqueness Throttle settled to \(instanceSdk.beaconUniquenessThrottle) seconds")
                case .failure(let error):
                    NSLog("FanMaker Info: Error getting site details: \(error.localizedDescription)")
                    urlString = "https://admin.fanmaker.com/500"
                }
                semaphore.signal()
            }
        }
        semaphore.wait()

        self.urlString = urlString
    }

    public func prepareUIView() {
        // Perform login before preparing the webview
        _ = sdk.loginUserFromParams()

        var urlString = self.urlString
        let url : URL? = URL(string: urlString)

        var request : URLRequest = URLRequest(url: url!)

        if let token = self.sdk.sessionToken {
            // Resolve token type and refresh OAuth tokens if expired
            let semaphore = DispatchSemaphore(value: 0)
            var resolvedTokenType: FanMakerSDKTokenType = .apiToken(token)
            var resolvedRawString: String = token

            FanMakerSDKTokenResolver.getValidToken(
                tokenString: token,
                apiBase: FanMakerSDKHttpRequest.apiBase,
                onRefreshed: { newTokenString in
                    resolvedRawString = newTokenString
                    self.sdk.updateSessionToken(newTokenString)
                },
                completion: { result in
                    if case .success(let validType) = result {
                        resolvedTokenType = validType
                    }
                    semaphore.signal()
                }
            )
            _ = semaphore.wait(timeout: .now() + 10.0)

            let sessionHeaderValue = FanMakerSDKTokenResolver.sessionTokenHeaderValue(
                for: resolvedTokenType,
                rawTokenString: resolvedRawString
            )
            let authHeaderValue = FanMakerSDKTokenResolver.authorizationHeaderValue(for: resolvedTokenType)

            request.setValue(sessionHeaderValue, forHTTPHeaderField: "X-FanMaker-SessionToken")
            request.setValue(authHeaderValue, forHTTPHeaderField: "Authorization")
        }

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
            return
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
            return
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
            return
        }

        // Convert the JSON data to a string
        let jsonUserTokenString = String(data: jsonFanmakerUserToken, encoding: .utf8)
        // Set the JSON string as the value for the HTTP header field
        request.setValue(jsonUserTokenString, forHTTPHeaderField: "X-FanMaker-User-Token")
        // ------------------------------------------------------------ <<< FanMaker User Token

        // SDK Exclusive Token
        request.setValue("4.0.0", forHTTPHeaderField: "X-FanMaker-SDK-Version")

        // Theme preference: "dark" if dark loading screen is enabled, "light" otherwise
        let theme = self.sdk.useDarkLoadingScreen ? "dark" : "light"
        request.setValue(theme, forHTTPHeaderField: "X-Fanmaker-Theme")

        self.webView.load(request)
    }

    public func makeUIView(context: Context) -> some UIView {
        prepareUIView()
        return self.webView
    }

    public func updateUIView(_ uiView: UIViewType, context: Context) {
        //
    }
}
