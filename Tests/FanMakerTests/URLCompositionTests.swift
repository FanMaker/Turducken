import XCTest
@testable import FanMaker

final class URLCompositionTests: XCTestCase {
    // The motivating real-world case: a site whose configured base URL
    // bakes in UTM parameters as a query string. Naive concatenation
    // produces `host/?utm_source=x...campaign=y/debug` (path appended to
    // the query string, which the SPA resolves to root). The helper must
    // place `/debug` as a real path component and preserve the query.
    func test_baseWithQuery_pathPreservesQuery() {
        let url = fanMakerComposeURL(
            baseURL: "https://www.loiltyrewards.com/?utm_source=x&utm_campaign=y",
            deepLinkPath: "/debug"
        )
        XCTAssertEqual(url?.absoluteString,
                       "https://www.loiltyrewards.com/debug?utm_source=x&utm_campaign=y")
    }

    func test_baseWithoutQuery_simpleAppend() {
        let url = fanMakerComposeURL(
            baseURL: "https://www.loiltyrewards.com",
            deepLinkPath: "/activity"
        )
        XCTAssertEqual(url?.absoluteString,
                       "https://www.loiltyrewards.com/activity")
    }

    func test_pathWithoutLeadingSlash_normalized() {
        let url = fanMakerComposeURL(
            baseURL: "https://www.loiltyrewards.com",
            deepLinkPath: "activity"
        )
        XCTAssertEqual(url?.absoluteString,
                       "https://www.loiltyrewards.com/activity")
    }

    func test_baseWithTrailingSlash_noDoubleSlash() {
        let url = fanMakerComposeURL(
            baseURL: "https://www.loiltyrewards.com/",
            deepLinkPath: "/debug"
        )
        XCTAssertEqual(url?.absoluteString,
                       "https://www.loiltyrewards.com/debug")
    }

    func test_baseWithExistingPath_pathReplaced() {
        let url = fanMakerComposeURL(
            baseURL: "https://www.loiltyrewards.com/legacy?utm_source=x",
            deepLinkPath: "/debug"
        )
        XCTAssertEqual(url?.absoluteString,
                       "https://www.loiltyrewards.com/debug?utm_source=x")
    }


    // A deep link's own query is part of the destination - a push's
    // ?utm=push, a prize id. The whole input used to be set as the path,
    // which percent-encoded the "?" into a page that does not exist.
    func test_deepLinkQuery_keptAsQuery() {
        let url = fanMakerComposeURL(
            baseURL: "https://www.loiltyrewards.com",
            deepLinkPath: "/store?utm=push"
        )
        XCTAssertEqual(url?.absoluteString,
                       "https://www.loiltyrewards.com/store?utm=push")
    }

    func test_baseQueryAndDeepLinkQuery_bothKept() {
        let url = fanMakerComposeURL(
            baseURL: "https://www.loiltyrewards.com/?utm_source=x",
            deepLinkPath: "store?prize=42"
        )
        XCTAssertEqual(url?.absoluteString,
                       "https://www.loiltyrewards.com/store?utm_source=x&prize=42")
    }

    // Setting an already-encoded path through `path` encoded the % again.
    func test_encodedPath_notEncodedTwice() {
        let url = fanMakerComposeURL(
            baseURL: "https://www.loiltyrewards.com",
            deepLinkPath: "/prize/big%20prize"
        )
        XCTAssertEqual(url?.absoluteString,
                       "https://www.loiltyrewards.com/prize/big%20prize")
    }

    // handleUrl used to keep only the path, dropping the query before the
    // composer ever saw it. With nothing open, the destination is queued.
    func test_handleUrl_queuesTheQueryToo() {
        let sdk = FanMakerSDK()
        sdk.initialize(apiKey: "query-\(UUID().uuidString)")
        XCTAssertTrue(sdk.handleUrl(URL(string: "turducken://fanmaker/rewards?utm=push")!))
        XCTAssertEqual(sdk.deepLinkPath, "/rewards?utm=push")
    }
}
