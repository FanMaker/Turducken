//
//  File.swift
//
//
//  Created by Érik Escobedo on 28/05/21.
//

import Foundation
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
                    print(error.localizedDescription)
                    urlString = "https://admin.fanmaker.com/500"
                }
                semaphore.signal()
            }
        }
        semaphore.wait()

        self.urlString = urlString
    }

    public func prepareUIView() {
        let url : URL? = URL(string: self.urlString)
        var request : URLRequest = URLRequest(url: url!)
        let defaults = self.sdk.userDefaults

        if let token = defaults?.string(forKey: self.sdk.FanMakerSDKSessionToken) {
            request.setValue(token, forHTTPHeaderField: "X-FanMaker-SessionToken")
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
            print("Error converting identifiers dictionary to JSON: \(error)")
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
            print("Error converting parameters dictionary to JSON: \(error)")
            return
        }

        // Convert the JSON data to a string
        let jsonParamString = String(data: jsonFanmakerParameters, encoding: .utf8)
        // Set the JSON string as the value for the HTTP header field
        request.setValue(jsonParamString, forHTTPHeaderField: "X-Fanmaker-Parameters")
        // ------------------------------------------------------------ <<< FanMaker Parameters

        // SDK Exclusive Token
        request.setValue("2.0.1", forHTTPHeaderField: "X-FanMaker-SDK-Version")

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
