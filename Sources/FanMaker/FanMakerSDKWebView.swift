//
//  File.swift
//
//
//  Created by Érik Escobedo on 28/05/21.
//

import Foundation
import SwiftUI
import WebKit
// import FanMakerSDKCacheState

@available(iOS 13.0, *)

public final class FanMakerSDKCacheState {
    public var cacheFilePath: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("cachedResponses")
    }

    public var inMemoryCache: [String: CachedURLResponse] {
        didSet {
            if let cachedResponsesData = try? NSKeyedArchiver.archivedData(withRootObject: inMemoryCache, requiringSecureCoding: false) {
                try? cachedResponsesData.write(to: cacheFilePath)
            }
        }
    }

    public init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cPath = documentsDirectory.appendingPathComponent("cachedResponses")
        // Try to read the archived data from the file system
        if let data = try? Data(contentsOf: cPath),
           let unarchivedCache = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: CachedURLResponse] {
            self.inMemoryCache = unarchivedCache
        } else {
            self.inMemoryCache = [:]
        }
    }
}

public struct FanMakerSDKWebView : UIViewRepresentable {
    public var webView : WKWebView
    // private var state: FanMakerSDKCacheState

    private var state : FanMakerSDKCacheState = FanMakerSDKCacheState()

    private var urlString : String = ""

    public init(configuration: WKWebViewConfiguration) {
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.state = FanMakerSDKCacheState()

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

    public func getCachedResponse(for request: URLRequest) -> CachedURLResponse? {
        // print("------------------------------------------------------------------------------------ >>> CHECKING THE CACHE FOR DATA")
        guard let cacheKey = request.url?.absoluteString else {
            return nil
        }

        // print("------------------------------------------------------------------------------------ >>> CHECKED THE CACHE FOR DATA")
        // print(cacheKey)
        // print("----------------------------------")
        // print(self.state.inMemoryCache[cacheKey])
        // print("------------------------------------------------------------------------------------ <<< CHECKED THE CACHE FOR DATA")
        return self.state.inMemoryCache[cacheKey]
    }

    public func fetchFreshContent(for request: URLRequest, completion: @escaping (Data) -> Void) {
        // print("------------------------------------------------------------------------------------ >>> Fetching Fresh Content")
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                // Handle the error
                return
            }

            // print("------------------------------------------------------------------------------------ >>> FRESH DATA RECEIVED")
            // print(data)
            // print("----")
            // print(request.url!.absoluteString)
            // print("------------------------------------------------------------------------------------ <<< FRESH DATA RECEIVED")
            // Process the fresh data as needed

            // Update the cache in the shared state
            self.state.inMemoryCache[request.url!.absoluteString] = CachedURLResponse(response: response!, data: data)

            completion(data)
        }.resume()
    }

    public func prepareUIView() {
        // print("------------------------------------------------------------------------------------ >>> 0 PREPAREING THE VIEW")

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
        request.setValue("1.8.0", forHTTPHeaderField: "X-FanMaker-SDK-Version")

        // if let cachedResponse = getCachedResponse(for: request) {
        //     let mimeType = cachedResponse.response.mimeType ?? "application/octet-stream"
        //     let encoding = cachedResponse.response.textEncodingName ?? "UTF-8"
        //     var uurl = url ?? URL(string: "https://admin.fanmaker.com/500")!
        //     self.webView.load(cachedResponse.data, mimeType: mimeType, characterEncodingName: encoding, baseURL: uurl)
        // }

        // print("------------------------------------------------------------------------------------ >>> REQUEST HEADERS")
        if let allHeaders = request.allHTTPHeaderFields {
            for (field, value) in allHeaders {
                print("\(field): \(value)")
            }
        }
        // print("------------------------------------------------------------------------------------ <<< REQUEST HEADERS")

        fetchFreshContent(for: request) { freshData in
            let urlString = url?.absoluteString ?? "https://admin.fanmaker.com/500"
            guard let uurl = URL(string: urlString) else {
                print("Error: URL string is invalid.")
                return
            }

            // Load the data into the webView
            DispatchQueue.main.async {
                self.webView.load(freshData, mimeType: "application/octet-stream", characterEncodingName: "UTF-8", baseURL: uurl)
            }
        }
    }

    public func makeUIView(context: Context) -> some UIView {
        prepareUIView()
        return self.webView
    }

    public func updateUIView(_ uiView: UIViewType, context: Context) {
        //
    }
}
