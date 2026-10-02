import XCTest
import CoreLocation
@testable import FanMaker

/// Covers the de-duplication rule that having two ways into a region requires.
///
/// `startMonitoring` only reports boundary crossings, so a fan already inside a
/// region when scanning starts was never told about it. Asking for the initial
/// state fixes that, but it means an arrival can now be reported twice - once
/// by `didDetermineState(.inside)` and once by `didEnterRegion` - for a fan
/// standing near a boundary. `postRegionAction` has no de-duplication of its
/// own, so without a guard that posts a duplicate enter and starts ranging
/// twice.
final class BeaconRegionStateTests: XCTestCase {
    private func manager() -> FanMakerSDKBeaconsManager {
        let sdk = FanMakerSDK()
        sdk.initialize(apiKey: "region-state-tests")
        return FanMakerSDKBeaconsManager(sdk: sdk)
    }

    func testNothingIsInsideToBeginWith() {
        XCTAssertTrue(manager().currentlyInsideRegionIdentifiers.isEmpty)
    }

    func testFirstEntryIsRecordedAndASecondIsRefused() {
        let subject = manager()
        let region = "2686f39c-bada-4658-854a-a62e7e5e8b8d::1"

        XCTAssertTrue(subject.markInside(region), "the first arrival should be acted on")
        XCTAssertFalse(subject.markInside(region), "a second arrival for the same region should be refused")
        XCTAssertEqual(subject.currentlyInsideRegionIdentifiers, [region])
    }

    func testLeavingAndComingBackWorks() {
        let subject = manager()
        let region = "2686f39c-bada-4658-854a-a62e7e5e8b8d::1"

        XCTAssertTrue(subject.markInside(region))
        XCTAssertTrue(subject.forgetInside(region), "the exit should clear inside-ness")
        XCTAssertTrue(subject.currentlyInsideRegionIdentifiers.isEmpty)
        XCTAssertTrue(subject.markInside(region), "re-entering afterwards should be acted on again")
    }

    func testAnExitWeWereNeverInsideForIsRefused() {
        // Otherwise a stray exit posts an action with no matching enter.
        XCTAssertFalse(manager().forgetInside("never-entered::1"))
    }

    func testRegionsAreTrackedIndependently() {
        let subject = manager()
        let tower = "2686f39c-bada-4658-854a-a62e7e5e8b8d::1"
        let concourse = "2686f39c-bada-4658-854a-a62e7e5e8b8d::2"

        XCTAssertTrue(subject.markInside(tower))
        XCTAssertTrue(subject.markInside(concourse), "a different region is a different arrival")
        XCTAssertEqual(subject.currentlyInsideRegionIdentifiers, [tower, concourse])

        XCTAssertTrue(subject.forgetInside(tower))
        XCTAssertEqual(subject.currentlyInsideRegionIdentifiers, [concourse],
                       "leaving one region should not clear the other")
    }

    func testStopScanningForgetsEverything() {
        let subject = manager()
        subject.markInside("2686f39c-bada-4658-854a-a62e7e5e8b8d::1")
        subject.markInside("2686f39c-bada-4658-854a-a62e7e5e8b8d::2")

        subject.stopScanning()

        XCTAssertTrue(subject.currentlyInsideRegionIdentifiers.isEmpty,
                      "a fresh scan must not inherit stale inside-ness, or the first real entry is swallowed")
    }

    func testRegionsAreCachedBeforeMonitoringBegins() {
        // startScanning asks CoreLocation for each region's current state right
        // after it starts monitoring, and the answer is only recognised as ours
        // if the region is already cached. Populating the cache asynchronously
        // left a window where that answer arrived first and was discarded.
        let subject = manager()
        let json = """
        [{
          "id": 1705,
          "name": "Kyle Field - NE Tower",
          "uuid": "2686f39c-bada-4658-854a-a62e7e5e8b8d",
          "major": "1",
          "minor": "0",
          "active": true
        }]
        """
        let regions = try! JSONDecoder().decode(
            [FanMakerSDKBeaconRegion].self,
            from: json.data(using: .utf8)!
        )

        subject.startScanning(regions)

        XCTAssertEqual(subject.cachedRegions.count, 1,
                       "the cache must be populated by the time startScanning returns")
        XCTAssertEqual(subject.cachedRegions.first?.uuid, "2686f39c-bada-4658-854a-a62e7e5e8b8d")
    }

    func testStateForAnUnknownRegionIsIgnored() {
        // Another part of a host app may monitor its own regions through a
        // shared location manager; those must not be treated as ours.
        let subject = manager()
        let foreign = CLBeaconRegion(
            uuid: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            identifier: "someone-elses-region"
        )

        subject.locationManager(CLLocationManager(), didDetermineState: .inside, for: foreign)

        XCTAssertTrue(subject.currentlyInsideRegionIdentifiers.isEmpty,
                      "a region we never cached is not ours to enter")
    }
}
