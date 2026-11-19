import XCTest
import WebKit
@testable import FanMaker

/// logout() is the sign-out. Fanmaker's pages and sign-in providers keep their
/// own state in the SDK's web view - cookies, local storage - so clearing the
/// SDK's tokens alone could still open the next person's webview as the
/// previous fan. The host app's own web content is not ours to clear.
final class LogoutWebDataTests: XCTestCase {
    private func cookie(_ name: String, domain: String) throws -> HTTPCookie {
        try XCTUnwrap(HTTPCookie(properties: [
            .domain: domain, .path: "/", .name: name, .value: "1",
            .secure: "TRUE", .expires: Date().addingTimeInterval(3600)
        ]))
    }

    private func set(_ cookie: HTTPCookie, in store: WKWebsiteDataStore) {
        let done = expectation(description: "cookie set")
        store.httpCookieStore.setCookie(cookie) { done.fulfill() }
        wait(for: [done], timeout: 5)
    }

    private func cookieNames(in store: WKWebsiteDataStore) -> [String] {
        var names: [String] = []
        let done = expectation(description: "cookies read")
        store.httpCookieStore.getAllCookies { cookies in
            names = cookies.map(\.name)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return names
    }

    private func logout() {
        let sdk = FanMakerSDK()
        sdk.initialize(apiKey: "logout-web-data-\(UUID().uuidString)")
        let done = expectation(description: "logged out")
        sdk.logout { done.fulfill() }
        wait(for: [done], timeout: 10)
    }

    func testTheSDKsWebViewKeepsItsDataInItsOwnStore() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("own store needs iOS 17") }
        let view = FanMakerSDKWebView(sdk: FanMakerSDK(), configuration: WKWebViewConfiguration())

        XCTAssertEqual(view.webView.configuration.websiteDataStore.identifier, FanMakerSDK.webDataStoreID)
    }

    func testLogoutClearsTheSDKsWebDataAndLeavesTheHostAppsAlone() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("own store needs iOS 17") }
        set(try cookie("fm_previous_fan", domain: "www.example-host.com"), in: FanMakerSDK.webDataStore)
        set(try cookie("host_app_session", domain: "www.example-host.com"), in: .default())

        logout()

        XCTAssertFalse(cookieNames(in: FanMakerSDK.webDataStore).contains("fm_previous_fan"),
                       "logout() must clear the SDK's web data")
        XCTAssertTrue(cookieNames(in: .default()).contains("host_app_session"),
                      "logout() must leave the host app's own web data alone")
    }

    /// Before iOS 17 the SDK shares the host's store, and logout() clears only
    /// the records for our own hosts. WebKit names a record by its registrable
    /// domain.
    func testBeforeIOS17OnlyOurOwnDomainsAreCleared() {
        let ours = ["www.loiltyrewards.com", "tmauth.fanmaker.com"]

        XCTAssertTrue(FanMakerSDK.isOwnWebDataRecord("loiltyrewards.com", ownHosts: ours))
        XCTAssertTrue(FanMakerSDK.isOwnWebDataRecord("fanmaker.com", ownHosts: ours))
        XCTAssertFalse(FanMakerSDK.isOwnWebDataRecord("example-host.com", ownHosts: ours))
        XCTAssertFalse(FanMakerSDK.isOwnWebDataRecord("rewards.com", ownHosts: ours),
                       "a suffix that isn't a whole domain label is not ours")
    }
}
