import XCTest
@testable import FanMaker

/// Covers identifiers surviving process death, and what ending a session
/// actually clears.
///
/// FanMakerSDKUserDefaults namespaces its keys by api key inside
/// UserDefaults.standard, so a fresh FanMakerSDK initialized with the same api
/// key is a faithful stand-in for the next launch of the app.
final class IdentifierPersistenceTests: XCTestCase {
    private var apiKey: String = ""

    override func setUp() {
        super.setUp()
        // Unique per test, so tests cannot see each other's stored state.
        apiKey = "persistence-tests-\(UUID().uuidString)"
    }

    override func tearDown() {
        relaunch().logout()
        super.tearDown()
    }

    /// A new instance on the same api key: what the next cold start sees.
    private func relaunch() -> FanMakerSDK {
        let sdk = FanMakerSDK()
        sdk.initialize(apiKey: apiKey)
        return sdk
    }

    func testHostSuppliedIdentifiersSurviveARelaunch() {
        let first = relaunch()
        first.setMemberID("fan-a-member")
        first.setYinzid("fan-a-yinz")
        first.setPushNotificationToken("fan-a-push")
        _ = first.setFanMakerIdentifiers(dictionary: ["seat": "12F"])

        let next = relaunch()
        XCTAssertEqual(next.memberID, "fan-a-member")
        XCTAssertEqual(next.yinzid, "fan-a-yinz")
        XCTAssertEqual(next.pushToken, "fan-a-push")
        XCTAssertEqual(next.fanmakerIdentifierLexicon["seat"] as? String, "12F")
    }

    func testIdentifiersComeBackWithoutASessionToken() {
        // The behaviour that changed. Identifiers are the input to auto-login -
        // loginUserFromParams posts them to /site/auth/auto_login - so
        // restoring them only when a token already existed suppressed the very
        // flow that obtains one.
        let first = relaunch()
        first.setMemberID("returning-fan")
        XCTAssertNil(first.sessionToken, "no session token in this scenario")

        let next = relaunch()
        XCTAssertEqual(next.memberID, "returning-fan",
                       "a returning fan with no token still needs their identifiers to auto-login")
    }

    func testLogoutForgetsTheFanEntirely() {
        let first = relaunch()
        first.setMemberID("fan-a-member")
        _ = first.setFanMakerIdentifiers(dictionary: ["seat": "12F"])
        first.updateSessionToken("fan-a-session-token")
        first.fanmakerUserToken = ["id": 4242]

        first.logout()

        XCTAssertTrue(first.memberID.isEmpty)
        XCTAssertTrue(first.fanmakerIdentifierLexicon.isEmpty)
        XCTAssertTrue(first.fanmakerUserToken.isEmpty)
        XCTAssertTrue((first.sessionToken ?? "").isEmpty)

        let next = relaunch()
        XCTAssertTrue(next.memberID.isEmpty, "a signed-out fan must not come back on the next launch")
        XCTAssertTrue(next.fanmakerIdentifierLexicon.isEmpty)
        XCTAssertTrue((next.sessionToken ?? "").isEmpty)
    }

    func testClearingIdentifiersIsDeliberatelyNotASignOut() {
        // Kept explicit: if this ever starts clearing the token too, that is a
        // behaviour change a reader should be forced to notice.
        let sdk = relaunch()
        sdk.setMemberID("fan-a-member")
        sdk.updateSessionToken("fan-a-session-token")

        sdk.clearIdentifiers()

        XCTAssertTrue(sdk.memberID.isEmpty)
        XCTAssertEqual(sdk.sessionToken, "fan-a-session-token",
                       "clearIdentifiers must leave the session alone; logout is the sign-out")
    }

    func testClearingTheSessionKeepsWhatAutoLoginNeeds() {
        let sdk = relaunch()
        sdk.setMemberID("fan-a-member")
        sdk.updateSessionToken("fan-a-session-token")
        sdk.fanmakerUserToken = ["id": 4242]

        sdk.clearSessionToken()

        XCTAssertTrue((sdk.sessionToken ?? "").isEmpty)
        XCTAssertTrue(sdk.fanmakerUserToken.isEmpty)
        XCTAssertEqual(sdk.memberID, "fan-a-member",
                       "identifiers are the input to re-authentication and must survive")
    }

    func testAValueSetThisLaunchWinsOverAStoredOne() {
        let first = relaunch()
        first.setMemberID("stored-member")

        let next = relaunch()
        next.setMemberID("fresh-member")

        let afterThat = relaunch()
        XCTAssertEqual(afterThat.memberID, "fresh-member")
    }

    func testArbitraryIdentifiersDoNotTakeEverythingElseDownWithThem() {
        // fanmaker_identifiers was decoded as Data, which JSONDecoder reads as
        // a base64 string - so a nested object threw a type mismatch, and the
        // empty catch in setIdentifiers(fromJSON:) dropped *every* identifier
        // rather than just that one. Decoded directly here so a regression
        // points at the decoding rather than at persistence.
        let json = """
        {
          "member_id": "fan-a-member",
          "yinzid": "fan-a-yinz",
          "fanmaker_identifiers": { "seat": "12F", "tier": 3, "vip": true }
        }
        """

        let decoded = try? JSONDecoder().decode(
            FanMakerSDKIdentifiers.self,
            from: json.data(using: .utf8)!
        )

        XCTAssertNotNil(decoded, "a blob containing fanmaker_identifiers must decode at all")
        XCTAssertEqual(decoded?.member_id, "fan-a-member")
        XCTAssertEqual(decoded?.yinzid, "fan-a-yinz")
        XCTAssertEqual(decoded?.fanmaker_identifiers?["seat"] as? String, "12F")
        XCTAssertEqual(decoded?.fanmaker_identifiers?["tier"] as? Int, 3)
        XCTAssertEqual(decoded?.fanmaker_identifiers?["vip"] as? Bool, true)
    }

    func testPersistedPayloadOmitsEmptyFields() {
        // Otherwise the stored blob accumulates empty strings that later read
        // back as "set but blank" and defeat the isEmpty checks auto-login uses.
        let sdk = relaunch()
        sdk.setMemberID("only-a-member")

        let stored = sdk.userDefaults?.string(forKey: sdk.FanMakerSDKJSONIdentifiers) ?? ""
        XCTAssertTrue(stored.contains("member_id"))
        XCTAssertFalse(stored.contains("yinzid"))
        XCTAssertFalse(stored.contains("push_token"))
    }
}
