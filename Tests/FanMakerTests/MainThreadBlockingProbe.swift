import XCTest
import UIKit
import WebKit
@testable import FanMaker

/// `FanMakerSDKWebViewController.viewDidLoad` used to construct `FanMakerSDKWebView`
/// and call `prepareUIView()`, both of which blocked on `DispatchSemaphore.wait()`
/// around network calls. Loading the view stalled whatever thread it happened on,
/// which for a presented view controller is the main thread — 1.078 s measured here
/// against an unroutable key, 845 ms in a real host app.
///
/// Site details, auto-login and token resolution now run off the main thread and the
/// webview swaps in from `webView(_:didFinish:)`, so `viewDidLoad` only has the
/// loading screen to build.
@available(iOS 13.0, *)
final class MainThreadBlockingProbe: XCTestCase {

    /// The regression guard. An unroutable key still costs a real (fast-failing)
    /// round trip, so if any of it were back on the critical path this would blow
    /// well past the budget.
    func testLoadingTheViewDoesNotBlockTheMainThread() {
        let sdk = FanMakerSDK()
        sdk.initialize(apiKey: "blocking-probe-\(UUID().uuidString)")
        let controller = FanMakerSDKWebViewController(sdk: sdk)

        XCTAssertTrue(Thread.isMainThread, "XCTest runs this on the main thread, as UIKit would")

        let started = Date()
        _ = controller.view          // forces viewDidLoad
        let blocked = Date().timeIntervalSince(started)

        NSLog("BLOCKING PROBE: loading the view blocked the main thread for %.3f s", blocked)
        XCTAssertLessThan(blocked, 0.1,
                          "viewDidLoad should only build the loading screen; network work belongs off the main thread")
        XCTAssertNotNil(controller.viewIfLoaded)
    }

    /// `prepareUIView()` is public and some hosts call it directly, so it still
    /// blocks by contract.
    ///
    /// It deliberately does not delegate to `prepareUIView(completion:)`, which
    /// finishes on the main queue — a main-thread caller waiting on that would
    /// deadlock. **If this test hangs rather than fails, that is the regression.**
    func testLegacyBlockingPrepareStillReturnsOnTheMainThread() {
        let sdk = FanMakerSDK()
        sdk.initialize(apiKey: "blocking-probe-legacy-\(UUID().uuidString)")
        let webView = FanMakerSDKWebView(sdk: sdk, configuration: .init())

        XCTAssertTrue(Thread.isMainThread)

        let started = Date()
        webView.prepareUIView()
        let blocked = Date().timeIntervalSince(started)

        NSLog("BLOCKING PROBE: legacy prepareUIView() blocked for %.3f s", blocked)
        XCTAssertGreaterThan(blocked, 0.0, "the legacy form is synchronous by contract")
    }

    /// Constructing the view no longer performs a network call.
    ///
    /// The first `WKWebView` anywhere in a process costs a few hundred ms to spin up
    /// WebKit's content process, so that is paid by an explicit warm-up here and
    /// logged. Both numbers are printed: whichever test runs first in the process
    /// sees the real cold figure, the rest see single-digit ms.
    func testConstructingTheWebViewDoesNotHitTheNetwork() {
        let sdk = FanMakerSDK()
        sdk.initialize(apiKey: "blocking-probe-init-\(UUID().uuidString)")

        let warmUpStarted = Date()
        _ = WKWebView(frame: .zero, configuration: .init())
        let webKitStartup = Date().timeIntervalSince(warmUpStarted)

        let started = Date()
        _ = FanMakerSDKWebView(sdk: sdk, configuration: .init())
        let blocked = Date().timeIntervalSince(started)

        NSLog("BLOCKING PROBE: bare WKWebView init %.3f s, then FanMakerSDKWebView.init %.3f s",
              webKitStartup, blocked)
        XCTAssertLessThan(blocked, 0.1, "site_details resolution moved out of the initialiser")
    }
}
