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

    public init(configuration: WKWebViewConfiguration) {
        self.webView = WKWebView(frame: .zero, configuration: configuration)

        let path = "site_details/info"

        let semaphore = DispatchSemaphore(value: 0)
        var urlString : String = ""
        DispatchQueue.global().async {
            FanMakerSDKHttp.get(path: path, model: FanMakerSDKSiteDetailsResponse.self) { result in
                switch(result) {
                case .success(let response):
                    urlString = response.data.sdk_url
                    if let beaconUniquenessThrottle = Int(response.data.site_features.beacons.beaconUniquenessThrottle) {
                        FanMakerSDK.beaconUniquenessThrottle = beaconUniquenessThrottle
                    }
                    NSLog("FanMaker Info: Beacon Uniqueness Throttle settled to \(FanMakerSDK.beaconUniquenessThrottle) seconds")
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
        let defaults : UserDefaults = UserDefaults.standard
        if let token = defaults.string(forKey: FanMakerSDKSessionToken) {
            request.setValue(token, forHTTPHeaderField: "X-FanMaker-SessionToken")
        }
        request.setValue(FanMakerSDK.apiKey, forHTTPHeaderField: "X-FanMaker-Token")
        request.setValue(FanMakerSDK.memberID, forHTTPHeaderField: "X-Member-ID")
        request.setValue(FanMakerSDK.studentID, forHTTPHeaderField: "X-Student-ID")
        request.setValue(FanMakerSDK.ticketmasterID, forHTTPHeaderField: "X-Ticketmaster-ID")
        request.setValue(FanMakerSDK.yinzid, forHTTPHeaderField: "X-Yinzid")
        request.setValue(FanMakerSDK.pushToken, forHTTPHeaderField: "X-PushNotification-Token")

        let jsonFanmakerIdentifiers: Data
        do {
            jsonFanmakerIdentifiers = try JSONSerialization.data(withJSONObject: FanMakerSDK.fanmakerIdentifierLexicon)
        } catch {
            print("Error converting dictionary to JSON: \(error)")
            return
        }

        // Convert the JSON data to a string
        let jsonString = String(data: jsonFanmakerIdentifiers, encoding: .utf8)
        // Set the JSON string as the value for the HTTP header field
        request.setValue(jsonString, forHTTPHeaderField: "X-Fanmaker-Identifiers")

        // SDK Exclusive Token
        request.setValue("1.2.3", forHTTPHeaderField: "X-FanMaker-SDK-Version")

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
