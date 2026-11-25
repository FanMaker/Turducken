import XCTest
@testable import FanMaker

/// 4.1.0 review fixes that keep 4.0 hosts working.
final class ReviewFixesTests: XCTestCase {

    // Links: only a new-window request leaves for Safari (4.0 dropped those);
    // a same-window tap stays in the webview, as in 4.0.
    func testOnlyANewWindowOffFirstPartyGoesToTheBrowser() {
        XCTAssertTrue(FanMakerSDK.ejectsToBrowser(opensANewWindow: true, offFirstParty: true))
        XCTAssertFalse(FanMakerSDK.ejectsToBrowser(opensANewWindow: false, offFirstParty: true),
                       "a same-window store or partner link keeps the in-app session")
        XCTAssertFalse(FanMakerSDK.ejectsToBrowser(opensANewWindow: true, offFirstParty: false))
    }

    // logout() before iOS 17: cookies on our exact hosts only, never the
    // client's parent domain that the host app's own web views use.
    func testLogoutTakesOnlyOurOwnCookies() {
        let hosts = ["rewards.wild.com"]
        XCTAssertTrue(FanMakerSDK.isOwnCookieDomain("rewards.wild.com", ownHosts: hosts))
        XCTAssertTrue(FanMakerSDK.isOwnCookieDomain(".rewards.wild.com", ownHosts: hosts))
        XCTAssertTrue(FanMakerSDK.isOwnCookieDomain(".fanmaker.com", ownHosts: hosts))
        XCTAssertTrue(FanMakerSDK.isOwnCookieDomain("seatgeek.fanmaker.com", ownHosts: hosts))
        XCTAssertFalse(FanMakerSDK.isOwnCookieDomain(".wild.com", ownHosts: hosts), "the host app's own cookies")
        XCTAssertFalse(FanMakerSDK.isOwnCookieDomain("www.wild.com", ownHosts: hosts))
    }

    // Whole data records go only for fanmaker.com; the client's registrable
    // domain ("wild.com") is shared with the host app.
    func testOnlyFanmakersOwnRecordIsRemovedWhole() {
        XCTAssertTrue(FanMakerSDK.isOwnWebDataRecord("fanmaker.com", ownHosts: []))
        XCTAssertFalse(FanMakerSDK.isOwnWebDataRecord("wild.com", ownHosts: []))
    }
}
