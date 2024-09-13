//
//  File.swift
//
//
//  Created by Érik Escobedo on 28/05/21.
//

import Foundation
import CoreLocation
import WebKit
import SwiftUI

@available(iOS 13.0, *)
open class FanMakerSDKWebViewController : UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    let sdk: FanMakerSDK

    init(sdk: FanMakerSDK) {
        self.sdk = sdk
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var fanmaker : FanMakerSDKWebView? = nil
    private let locationManager : CLLocationManager = CLLocationManager()
    private let locationDelegate : FanMakerSDKLocationDelegate = FanMakerSDKLocationDelegate()

    open override func viewDidLoad() {
        super.viewDidLoad()

        let userController : WKUserContentController = WKUserContentController()
        userController.add(self, name: "fanmaker")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userController

        self.fanmaker = FanMakerSDKWebView(sdk: self.sdk, configuration: configuration)
        self.fanmaker?.prepareUIView()
        self.fanmaker?.webView.navigationDelegate = self

        self.view = UIView(frame: self.view!.bounds)
        self.view.backgroundColor = self.sdk.loadingBackgroundColor

        let bounds = self.view!.bounds
        let x = bounds.width / 4
        let y = bounds.height / 2 - x * 3 / 2

        let loadingAnimation = UIImageView(frame: CGRect(x: x, y: y, width: 2 * x, height: 2 * x))

        if let fgImage = self.sdk.loadingForegroundImage {
            loadingAnimation.image = fgImage
        } else {
            if self.sdk.useDarkLoadingScreen {
                var images : [UIImage] = []
                for index in 0...21 {
                    if let path = Bundle.module.path(forResource: "fanmaker-sdk-dark-loading-\(index)", ofType: "png") {
                        if let image = UIImage(contentsOfFile: path) {
                            images.append(image)
                        }
                    }
                }
                loadingAnimation.image = UIImage.animatedImage(with: images, duration: 1.0)
                self.view.backgroundColor = UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1.00)
            }
            else {
                var images : [UIImage] = []
                for index in 0...29 {
                    if let path = Bundle.module.path(forResource: "fanmaker-sdk-loading-\(index)", ofType: "png") {
                        if let image = UIImage(contentsOfFile: path) {
                            images.append(image)
                        }
                    }
                }
                loadingAnimation.image = UIImage.animatedImage(with: images, duration: 1.0)
            }
        }

        self.view.addSubview(loadingAnimation)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        self.view = self.fanmaker!.webView
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "fanmaker", let body = message.body as? Dictionary<String, String> {
            let defaults = self.sdk.userDefaults

            body.forEach { key, value in
                switch(key) {
                case "sdkOpenUrl":
                    self.sdk.sdkOpenUrl(scheme: value)
                case "setToken":
                    defaults?.set(value, forKey: self.sdk.FanMakerSDKSessionToken)
                case "setIdentifiers":
                    self.sdk.setIdentifiers(fromJSON: value)
                    defaults?.set(value, forKey: self.sdk.FanMakerSDKJSONIdentifiers)
                case "requestLocationAuthorization":
                    locationManager.requestWhenInUseAuthorization()
                    locationManager.delegate = locationDelegate
                    locationManager.requestLocation()
                case "updateLocation":
                    if self.sdk.locationEnabled && CLLocationManager.locationServicesEnabled() {
                        var authorizationStatus : CLAuthorizationStatus
                        if #available(iOS 14.0, *) {
                            authorizationStatus = locationManager.authorizationStatus
                        } else {
                            authorizationStatus = CLLocationManager.authorizationStatus()
                        }

                        switch authorizationStatus {
                        case .notDetermined, .restricted, .denied:
                            print("Access Denied")
                            fanmaker!.webView.evaluateJavaScript("FanMakerReceiveLocationAuthorization(false)")
                        case .authorizedAlways, .authorizedWhenInUse:
                            fanmaker!.webView.evaluateJavaScript("FanMakerReceiveLocation(\(locationDelegate.coords()))")
                        @unknown default:
                            print("Unknown error")
                        }
                    } else {
                        print("CLLocationManager.locationServices are DISABLED")
                    }
                default:
                    break;
                }
            }
        }
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

