import XCTest
import UIKit
@testable import FanMaker

/// Not an assertion - a measurement, kept because the number is the point.
///
/// FanMakerSDKWebViewController.viewDidLoad constructs FanMakerSDKWebView and
/// calls prepareUIView(), and both block on DispatchSemaphore.wait() around
/// network calls. Loading the view therefore stalls whatever thread it happens
/// on, which for a presented view controller is the main thread.
@available(iOS 13.0, *)
final class MainThreadBlockingProbe: XCTestCase {
    func testHowLongLoadingTheViewBlocksTheCallingThread() {
        let sdk = FanMakerSDK()
        sdk.initialize(apiKey: "blocking-probe-\(UUID().uuidString)")
        let controller = FanMakerSDKWebViewController(sdk: sdk)

        XCTAssertTrue(Thread.isMainThread, "XCTest runs this on the main thread, as UIKit would")

        let started = Date()
        _ = controller.view          // forces viewDidLoad
        let blocked = Date().timeIntervalSince(started)

        NSLog("BLOCKING PROBE: loading the view blocked the main thread for %.3f s", blocked)
        // No assertion on the duration - it depends entirely on the network.
        // The finding is that it is synchronous at all.
        XCTAssertNotNil(controller.viewIfLoaded)
    }
}
