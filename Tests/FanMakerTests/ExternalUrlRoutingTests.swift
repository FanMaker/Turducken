import XCTest
@testable import FanMaker

/// The allowlist behind FanMaker/app#1885: `site_details/sdk` returns
/// `allowed_domains`, and a push destination whose host is not on it belongs in
/// the system browser rather than the SDK webview.
///
/// Two questions are asked of that list, and they fail in opposite directions
/// on purpose. `canHandleUrl` decides whether to admit a destination handed to
/// us from outside, so not knowing must mean no. `isExternalWebURL` decides
/// whether to throw out a link a page we already trust asked us to follow, so
/// not knowing must mean carry on.
final class ExternalUrlRoutingTests: XCTestCase {

    private func sdk(allowing domains: [String] = [], base: String? = nil) -> FanMakerSDK {
        let sdk = FanMakerSDK()
        sdk.initialize(apiKey: "external-url-\(UUID().uuidString)")
        if let base = base { sdk.updateBaseUrl(base) }
        sdk.updateAllowedDomains(domains)
        return sdk
    }

    // MARK: - Admitting a destination from outside (fails closed)

    func testAFirstPartyPushDestinationIsAccepted() {
        let subject = sdk(allowing: ["pipboy.fanmaker.com"], base: "https://pipboy.fanmaker.com")
        XCTAssertTrue(subject.canHandleUrl(URL(string: "https://pipboy.fanmaker.com/store")!))
    }

    func testTheSiteOwnBaseHostIsFirstPartyEvenIfTheListOmitsIt() {
        let subject = sdk(allowing: [], base: "https://pipboy.fanmaker.com")
        XCTAssertTrue(subject.canHandleUrl(URL(string: "https://pipboy.fanmaker.com/rewards")!))
    }

    func testAThirdPartyDestinationIsRefused() {
        let subject = sdk(allowing: ["pipboy.fanmaker.com"], base: "https://pipboy.fanmaker.com")
        XCTAssertFalse(subject.canHandleUrl(URL(string: "https://evil.example.com/x")!))
    }

    func testALookalikeSuffixIsRefused() {
        let subject = sdk(allowing: ["pipboy.fanmaker.com"], base: "https://pipboy.fanmaker.com")
        XCTAssertFalse(subject.canHandleUrl(URL(string: "https://pipboy.fanmaker.com.evil.test/x")!),
                       "host matching must be exact, not a suffix check")
    }

    func testWithNoAllowlistYetAThirdPartyDestinationIsStillRefused() {
        // Fails closed: before site_details answers we know of no first-party
        // hosts, and admitting an unknown destination is the unsafe direction.
        let subject = sdk(allowing: [], base: nil)
        XCTAssertFalse(subject.canHandleUrl(URL(string: "https://evil.example.com/x")!))
    }

    func testTheLegacyMagicHostStillWorks() {
        let subject = sdk(allowing: [], base: nil)
        XCTAssertTrue(subject.canHandleUrl(URL(string: "clientapp://fanmaker/store")!),
                      "integrations shaping links this way must keep working")
    }

    func testHostMatchingIgnoresCase() {
        let subject = sdk(allowing: ["PipBoy.FanMaker.com"], base: nil)
        XCTAssertTrue(subject.canHandleUrl(URL(string: "https://pipboy.fanmaker.com/store")!))
    }

    func testDomainsArrivingAsFullUrlsAreNormalisedToHosts() {
        let subject = sdk(allowing: ["https://pipboy.fanmaker.com/some/path"], base: nil)
        XCTAssertEqual(subject.allowedDomains, ["pipboy.fanmaker.com"])
    }

    // MARK: - Ejecting a link from a page we trust (fails open)

    func testAThirdPartyLinkIsExternal() {
        let subject = sdk(allowing: ["pipboy.fanmaker.com"], base: "https://pipboy.fanmaker.com")
        XCTAssertTrue(subject.isExternalWebURL(URL(string: "https://tickets.example.com/buy")!))
    }

    func testAFirstPartyLinkIsNotExternal() {
        let subject = sdk(allowing: ["apollo.fanmaker.com"], base: "https://pipboy.fanmaker.com")
        XCTAssertFalse(subject.isExternalWebURL(URL(string: "https://apollo.fanmaker.com/x")!))
    }

    func testNothingIsExternalBeforeTheAllowlistIsKnown() {
        // Fails open. The window between launch and site_details/sdk answering
        // would otherwise eject every link, including our own.
        let subject = sdk(allowing: [], base: nil)
        XCTAssertFalse(subject.isExternalWebURL(URL(string: "https://pipboy.fanmaker.com/store")!))
    }

    func testCustomSchemesAreNotTreatedAsExternalWebLinks() {
        let subject = sdk(allowing: ["pipboy.fanmaker.com"], base: "https://pipboy.fanmaker.com")
        XCTAssertFalse(subject.isExternalWebURL(URL(string: "mailto:someone@example.com")!))
        XCTAssertFalse(subject.isExternalWebURL(URL(string: "tel:5551234")!))
    }

    // MARK: - openPath

    func testOpenPathQueuesABarePath() {
        let subject = sdk()
        XCTAssertTrue(subject.openPath("/store"))
        XCTAssertEqual(subject.deepLinkPath, "/store")
    }

    func testOpenPathAddsTheLeadingSlash() {
        let subject = sdk()
        XCTAssertTrue(subject.openPath("store"))
        XCTAssertEqual(subject.deepLinkPath, "/store")
    }

    func testOpenPathRefusesAProtocolRelativeUrl() {
        // "//evil.test/x" starts with a slash so it reads as a path, but it
        // parses as an authority - accepting it would let a caller point the
        // webview at a host of their choosing.
        let subject = sdk()
        XCTAssertFalse(subject.openPath("//evil.test/x"))
        XCTAssertNil(subject.deepLinkPath)
    }

    func testOpenPathRefusesAnythingCarryingAScheme() {
        let subject = sdk()
        XCTAssertFalse(subject.openPath("https://evil.test/x"))
        XCTAssertNil(subject.deepLinkPath)
    }

    func testOpenPathRefusesAnEmptyPath() {
        let subject = sdk()
        XCTAssertFalse(subject.openPath("   "))
        XCTAssertNil(subject.deepLinkPath)
    }
}
