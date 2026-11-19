import XCTest
import CoreLocation
@testable import FanMaker

/// Ranging is a local radio operation, and it used to be gated on two things that
/// have nothing to do with the radio: a successful `beacon_region_actions` POST,
/// and a non-nil delegate. Both gates lived in one place - the whole body of
/// `postRegionAction`'s completion sat inside `if let delegate = self.delegate`,
/// and the ranging call sat inside its `.success` branch.
///
/// The consequences were a fan at the beacon never being ranged when the POST
/// failed, ranging never stopping when the exit POST failed, and an integration
/// that never set a delegate getting no ranging at all however healthy the network.
/// The last one is the quiet one: `delegate` is `weak`, so it can also simply go
/// away mid-session.
@available(iOS 13.0, *)
final class BeaconRangingIndependenceTests: XCTestCase {

    /// Records what CoreLocation was asked to do, since the real calls need
    /// hardware and permissions a test bundle does not have.
    private final class RangingSpy: CLLocationManager {
        var started: [CLBeaconIdentityConstraint] = []
        var stopped: [CLBeaconIdentityConstraint] = []

        override func startRangingBeacons(satisfying constraint: CLBeaconIdentityConstraint) {
            started.append(constraint)
        }

        override func stopRangingBeacons(satisfying constraint: CLBeaconIdentityConstraint) {
            stopped.append(constraint)
        }
    }

    private let uuid = "2686f39c-bada-4658-854a-a62e7e5e8b8d"

    private func subjectScanningOurRegion() -> FanMakerSDKBeaconsManager {
        let sdk = FanMakerSDK()
        sdk.initialize(apiKey: "ranging-independence-\(UUID().uuidString)")
        let subject = FanMakerSDKBeaconsManager(sdk: sdk)

        let json = """
        [{
          "id": 1705,
          "name": "Kyle Field - NE Tower",
          "uuid": "\(uuid)",
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
        return subject
    }

    private func ourRegion() -> CLBeaconRegion {
        return CLBeaconRegion(
            uuid: UUID(uuidString: uuid)!,
            major: 1,
            identifier: "\(uuid)::1"
        )
    }

    func testRangingStartsWithNoDelegateSet() {
        let subject = subjectScanningOurRegion()
        let spy = RangingSpy()
        XCTAssertNil(subject.delegate, "the case under test is an integration that never set one")

        subject.locationManager(spy, didDetermineState: .inside, for: ourRegion())

        XCTAssertEqual(spy.started.count, 1,
                       "ranging must not depend on a delegate being set")
        XCTAssertEqual(spy.started.first?.uuid, UUID(uuidString: uuid))
        XCTAssertEqual(spy.started.first?.major, 1)
    }

    /// Ranging starts before the POST is even issued, so a failing or slow network
    /// cannot cost the visit its range actions.
    func testRangingStartsWithoutWaitingForTheRegionPost() {
        let subject = subjectScanningOurRegion()
        let spy = RangingSpy()

        subject.locationManager(spy, didEnterRegion: ourRegion())

        XCTAssertEqual(spy.started.count, 1,
                       "the call is synchronous with the entry, not with the POST's completion")
    }

    func testRangingStopsOnExitWithNoDelegateSet() {
        let subject = subjectScanningOurRegion()
        let spy = RangingSpy()

        subject.locationManager(spy, didEnterRegion: ourRegion())
        subject.locationManager(spy, didExitRegion: ourRegion())

        XCTAssertEqual(spy.stopped.count, 1,
                       "a failed exit POST used to leave the radio ranging a region the fan had left")
    }

    func testADuplicateEntryStillOnlyRangesOnce() {
        let subject = subjectScanningOurRegion()
        let spy = RangingSpy()

        subject.locationManager(spy, didDetermineState: .inside, for: ourRegion())
        subject.locationManager(spy, didEnterRegion: ourRegion())

        XCTAssertEqual(spy.started.count, 1,
                       "moving ranging earlier must not defeat the de-duplication guard")
    }

    func testAnExitWeWereNeverInsideForDoesNotStopRanging() {
        let subject = subjectScanningOurRegion()
        let spy = RangingSpy()

        subject.locationManager(spy, didExitRegion: ourRegion())

        XCTAssertTrue(spy.stopped.isEmpty)
    }

    // MARK: - The sighting log integrators read

    func testFirstSightingIsAnnouncedThenSuppressed() {
        let subject = subjectScanningOurRegion()
        let action = FanMakerSDKBeaconRangeAction(
            uuid: uuid, major: 1, minor: 0,
            proximity: "far", rssi: -96, accuracy: -1, seenAt: Date()
        )

        XCTAssertTrue(subject.markRanged(action), "the first sighting is worth a line even when throttled")
        XCTAssertFalse(subject.markRanged(action), "later sightings of the same beacon are not")
    }

    func testBeaconsAreTrackedIndependently() {
        let subject = subjectScanningOurRegion()
        let first = FanMakerSDKBeaconRangeAction(
            uuid: uuid, major: 1, minor: 0,
            proximity: "far", rssi: -96, accuracy: -1, seenAt: Date()
        )
        let second = FanMakerSDKBeaconRangeAction(
            uuid: uuid, major: 1, minor: 7,
            proximity: "near", rssi: -60, accuracy: 1.2, seenAt: Date()
        )

        XCTAssertTrue(subject.markRanged(first))
        XCTAssertTrue(subject.markRanged(second), "a different minor is a different beacon")
    }

    func testStopScanningForgetsRangedBeaconsSoTheNextSessionAnnouncesThemAgain() {
        let subject = subjectScanningOurRegion()
        let action = FanMakerSDKBeaconRangeAction(
            uuid: uuid, major: 1, minor: 0,
            proximity: "far", rssi: -96, accuracy: -1, seenAt: Date()
        )

        XCTAssertTrue(subject.markRanged(action))
        subject.stopScanning()
        XCTAssertTrue(subject.markRanged(action), "a fresh scan should re-announce what it can see")
    }

    func testTheSightingLineCarriesWhatAnIntegratorNeeds() {
        let subject = subjectScanningOurRegion()
        let line = subject.describe(FanMakerSDKBeaconRangeAction(
            uuid: uuid, major: 1, minor: 0,
            proximity: "far", rssi: -96, accuracy: -1, seenAt: Date()
        ))

        // The identity triple is what an integrator checks against their beacon's
        // configuration; the signal fields are how they tell "wrong beacon" from
        // "right beacon, too far away".
        XCTAssertTrue(line.contains(uuid), "the UUID identifies which beacon was seen")
        XCTAssertTrue(line.contains("major 1"))
        XCTAssertTrue(line.contains("minor 0"))
        XCTAssertTrue(line.contains("rssi -96"))
        XCTAssertTrue(line.contains("proximity far"))
    }
}
