import XCTest
@testable import FanMaker

/// The device-registration headers carry host-app names, which can be anything.
/// NUX's server.mjs JSON-parses every X- header, so the encoding has to survive
/// a real JSON parser and stay ASCII on the wire.
final class EnrichmentHeaderTests: XCTestCase {
    func testAnyNameRoundTripsThroughJSONAndStaysASCII() throws {
        for name in ["Rewards", "Montréal Canadiens", "Fans 🎟", #"Say "hi" \ bye"#, "line\nbreak"] {
            let encoded = asciiJSONString(name)
            XCTAssertTrue(encoded.unicodeScalars.allSatisfy { $0.isASCII }, "not ASCII: \(encoded)")
            let decoded = try JSONSerialization.jsonObject(with: Data(encoded.utf8), options: .fragmentsAllowed)
            XCTAssertEqual(decoded as? String, name)
        }
    }
}
