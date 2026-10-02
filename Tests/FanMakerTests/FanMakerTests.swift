import XCTest
@testable import FanMaker

final class FanMakerTests: XCTestCase {
    func testFanMakerSiteDetails() throws {
        // This fixture had only canonical_url, from before the response type
        // gained sdk_url and site_features, so decoding had been failing and
        // the test reported it by comparing an error message to "NO ERROR".
        let json = """
        {
          "status": 200,
          "message": "Success",
          "data": {
            "canonical_url": "example_url",
            "sdk_url": "https://example.nux.fanmaker.com",
            "site_features": {
              "beacons": { "beaconUniquenessThrottle": "60" }
            }
          }
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try JSONDecoder().decode(FanMakerSDKSiteDetailsResponse.self, from: data)

        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.data.canonical_url, "example_url")
        XCTAssertEqual(response.data.sdk_url, "https://example.nux.fanmaker.com")
        XCTAssertEqual(response.data.site_features.beacons.beaconUniquenessThrottle, "60")
    }

    func testSiteDetailsDecodingFailsLoudlyWhenAFieldIsMissing() throws {
        // Guards against the fixture drifting out of step with the type again:
        // a missing required field must surface as a decoding error.
        let json = """
        { "status": 200, "message": "Success", "data": { "canonical_url": "example_url" } }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        XCTAssertThrowsError(try JSONDecoder().decode(FanMakerSDKSiteDetailsResponse.self, from: data))
    }
}
