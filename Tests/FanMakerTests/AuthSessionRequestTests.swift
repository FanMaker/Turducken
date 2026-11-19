import XCTest
@testable import FanMaker

/// Which pages may start a sign-in in ASWebAuthenticationSession, and for
/// where. The session's result is a sign-in link the webview follows, so a
/// request accepted from the wrong page could sign a fan in as someone else.
final class AuthSessionRequestTests: XCTestCase {

    private let tmStart = "https://tmauth.fanmaker.com/tmauth/start?state=oilersfanmakermobile.ios"

    private func request(_ value: Any, from host: String?) -> FanMakerSDK.AuthSessionRequest? {
        let sdk = FanMakerSDK()
        sdk.initialize(apiKey: "auth-session-\(UUID().uuidString)")
        sdk.updateBaseUrl("https://www.loiltyrewards.com")
        sdk.updateAllowedDomains(["www.loiltyrewards.com"])
        return sdk.authSessionRequest(value, fromHost: host)
    }

    func testOurPageCanStartATicketmasterSignIn() {
        let accepted = request(["url": tmStart, "callbackScheme": "oilers"], from: "www.loiltyrewards.com")
        XCTAssertEqual(accepted, .init(url: URL(string: tmStart)!, callbackScheme: "oilers"))
        // NUX on a fanmaker.com host counts too.
        XCTAssertNotNil(request(["url": tmStart, "callbackScheme": "oilers"], from: "oilers.nux.fanmaker.com"))
    }

    func testAPageWeDontOwnCannotStartOne() {
        XCTAssertNil(request(["url": tmStart, "callbackScheme": "oilers"], from: "auth.ticketmaster.com"))
        XCTAssertNil(request(["url": tmStart, "callbackScheme": "oilers"], from: nil))
    }

    func testTheSignInHasToStartOnOneOfOurHostsOverHttps() {
        XCTAssertNil(request(["url": "https://evil.example.com/start", "callbackScheme": "oilers"], from: "www.loiltyrewards.com"))
        XCTAssertNil(request(["url": "http://tmauth.fanmaker.com/tmauth/start", "callbackScheme": "oilers"], from: "www.loiltyrewards.com"))
    }

    func testTheCallbackHasToBeAnAppScheme() {
        for scheme in ["https", "javascript", "not a scheme", "", "1oilers"] {
            XCTAssertNil(request(["url": tmStart, "callbackScheme": scheme], from: "www.loiltyrewards.com"), scheme)
        }
        XCTAssertEqual(request(["url": tmStart, "callbackScheme": "Oilers"], from: "www.loiltyrewards.com")?.callbackScheme, "oilers")
    }

    func testAMalformedMessageIsRefused() {
        XCTAssertNil(request(tmStart, from: "www.loiltyrewards.com"))
        XCTAssertNil(request(["url": tmStart], from: "www.loiltyrewards.com"))
    }
}
