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
}
