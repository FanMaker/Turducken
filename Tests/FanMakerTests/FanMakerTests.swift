    import XCTest
    @testable import FanMaker

    final class FanMakerTests: XCTestCase {
        func testFanMakerSiteDetails() {
            let json : String = "{\"status\": 200, \"message\": \"Success\", \"data\": { \"canonical_url\": \"example_url\" }}"
            let data = json.data(using: .utf8)
            let decoder = JSONDecoder()

            do {
                let httpResponse : FanMakerSDKSiteDetailsResponse = try decoder.decode(FanMakerSDKSiteDetailsResponse.self, from: data!)
                XCTAssertEqual(httpResponse.data.canonical_url, "example_url")
            } catch let(error) {
                XCTAssertEqual(error.localizedDescription, "NO ERROR")
            }
        }
    }
