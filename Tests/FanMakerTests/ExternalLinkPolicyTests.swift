import XCTest
import WebKit
@testable import FanMaker

/// The taps that must stay in the SDK webview, driven through the real
/// navigation policy. Each one was sent to Safari by the first version of the
/// rule, and each one breaks a sign-in or checkout if it is.
@available(iOS 13.0, *)
final class ExternalLinkPolicyTests: XCTestCase {

    private final class Frame: WKFrameInfo {
        private let main: Bool
        init(main: Bool) { self.main = main; super.init() }
        override var isMainFrame: Bool { main }
    }

    private final class Tap: WKNavigationAction {
        private let stubRequest: URLRequest
        private let stubType: WKNavigationType
        private let stubTarget: WKFrameInfo?
        init(_ url: String, type: WKNavigationType = .linkActivated, target: WKFrameInfo? = Frame(main: true)) {
            stubRequest = URLRequest(url: URL(string: url)!)
            stubType = type
            stubTarget = target
            super.init()
        }
        override var request: URLRequest { stubRequest }
        override var navigationType: WKNavigationType { stubType }
        override var targetFrame: WKFrameInfo? { stubTarget }
    }

    /// A webview showing `page`, which is what the policy reads as the tap's source.
    private final class Page: WKWebView {
        private let shown: URL?
        init(_ page: String) {
            shown = URL(string: page)
            super.init(frame: .zero, configuration: WKWebViewConfiguration())
        }
        required init?(coder: NSCoder) { fatalError("unused") }
        override var url: URL? { shown }
    }

    private func decide(_ tap: Tap, on page: String) -> WKNavigationActionPolicy? {
        let sdk = FanMakerSDK()
        sdk.initialize(apiKey: "link-policy-\(UUID().uuidString)")
        sdk.updateBaseUrl("https://www.loiltyrewards.com")
        sdk.updateAllowedDomains(["www.loiltyrewards.com", "oilers.nux.fanmaker.com"])
        let controller = FanMakerSDKWebViewController(sdk: sdk)
        var decided: WKNavigationActionPolicy?
        controller.webView(Page(page), decidePolicyFor: tap) { decided = $0 }
        return decided
    }

    func testTheSSOEntryTapStaysInTheWebview() {
        // NUX renders "Sign in with Ticketmaster" as a plain link to our broker,
        // which is in no site's allowlist.
        XCTAssertEqual(decide(Tap("https://tmauth.fanmaker.com/tmauth/start?state=oilers"),
                              on: "https://www.loiltyrewards.com/login"), .allow)
    }

    func testATapOnTheProvidersOwnPageStaysInTheWebview() {
        // Mid-SSO the webview is on Ticketmaster's login page; its links have to work there.
        XCTAssertEqual(decide(Tap("https://auth.ticketmaster.com/forgot-password"),
                              on: "https://auth.ticketmaster.com/as/authorization.oauth2"), .allow)
    }

    func testATapInsideAnEmbeddedFrameStaysInTheWebview() {
        XCTAssertEqual(decide(Tap("https://partner.example.com/x", target: Frame(main: false)),
                              on: "https://www.loiltyrewards.com/home"), .allow)
    }

    func testARedirectIsNeverEjected() {
        XCTAssertEqual(decide(Tap("https://partner.example.com/x", type: .other),
                              on: "https://www.loiltyrewards.com/home"), .allow)
    }
}
