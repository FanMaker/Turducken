//
//  FanMakerSDKBeaconsManager.swift
//  Turducken
//
//  Created by Érik Escobedo on 09/06/22.
//

import Foundation
import CoreLocation

public enum FanMakerSDKBeaconsAuthorizationStatus : Int32, @unchecked Sendable {
    case notDetermined = 0
    case restricted = 1
    case denied = 2

    @available(iOS 8.0, *)
    case authorizedAlways = 3

    @available(iOS 8.0, *)
    case authorizedWhenInUse = 4
}

public struct FanMakerSDKBeaconRangeAction : Codable {
    public var uuid : String
    public var major : Int
    public var minor : Int
    public var proximity : String
    public var rssi : Int
    public var accuracy : Double
    public var seenAt : Date

    public func toParams() -> [String : String] {
        return [
            "uuid" : uuid,
            "major" : String(major),
            "minor" : String(minor),
            "proximity" : proximity,
            "rssi" : String(rssi),
            "accuracy": String(accuracy),
            "seen_at": ISO8601DateFormatter().string(from: seenAt)
        ]
    }
}

extension FanMakerSDKBeaconRangeAction {
    init(beacon: CLBeacon) {
        self.uuid = beacon.uuid.uuidString
        self.major = Int(truncating: beacon.major)
        self.minor = Int(truncating: beacon.minor)
        self.rssi = beacon.rssi
        self.accuracy = beacon.accuracy
        self.seenAt = Date()

        switch(beacon.proximity) {
        case .unknown:
            self.proximity = "unknown"
        case .immediate:
            self.proximity = "immediate"
        case .near:
            self.proximity = "near"
        case .far:
            self.proximity = "far"
        @unknown default:
            self.proximity = "unknown"
        }
    }
}

open class FanMakerSDKBeaconsManager : NSObject, CLLocationManagerDelegate {
    let sdk: FanMakerSDK

    weak open var delegate: FanMakerSDKBeaconsManagerDelegate?
    var locationManager : CLLocationManager
    var cachedRegions : [FanMakerSDKBeaconRegion] = []
    private let cachedRegionsQueue = DispatchQueue(label: "com.fanmaker.FanMakerSDK.cachedRegionsQueue")

    private let FanMakerSDKBeaconRangeActionsHistory = "FanMakerSDKBeaconRangeActionsHistory"
    private let FanMakerSDKBeaconRangeActionsSendList = "FanMakerSDKBeaconRangeActionsSendList"
    private var timer : Timer?

    public init(sdk: FanMakerSDK) {
        self.sdk = sdk
        self.locationManager = CLLocationManager()
        super.init()
        self.locationManager.delegate = self
    }

    private func getQueue(from key: String) -> [FanMakerSDKBeaconRangeAction] {
        let defaults = self.sdk.userDefaults
        guard let data = defaults?.data(forKey: key) else {
            return []
        }
        return (try? PropertyListDecoder().decode([FanMakerSDKBeaconRangeAction].self, from: data)) ?? []
    }

    public func rangeActionsHistory() -> [FanMakerSDKBeaconRangeAction] {
        return getQueue(from: FanMakerSDKBeaconRangeActionsHistory)
    }

    public func rangeActionsSendList() -> [FanMakerSDKBeaconRangeAction] {
        return getQueue(from: FanMakerSDKBeaconRangeActionsSendList)
    }

    open func requestAuthorization() {
        self.locationManager.requestAlwaysAuthorization()
        var status = CLLocationManager.authorizationStatus()
    }

    open func fetchBeaconRegions() {
        guard isUserLogged() else { return fail(with: .userSessionNotFound) }

        DispatchQueue.global().async {
            FanMakerSDKHttp.get(sdk: self.sdk, path: "site_details/sdk", model: FanMakerSDKInfoResponse.self) { result in
                switch(result) {
                case .success(let response):
                    if let beaconUniquenessThrottle = Int(response.data.beacons.uniqueness_throttle) {
                        self.sdk.beaconUniquenessThrottle = beaconUniquenessThrottle
                    }
                    NSLog("FanMaker Info: Beacon Uniqueness Throttle settled to \(self.sdk.beaconUniquenessThrottle) seconds")
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
        }

        DispatchQueue.global().async {
            FanMakerSDKHttp.get(sdk: self.sdk, path: "beacon_regions", model: FanMakerSDKBeaconRegionsResponse.self) { result in
                switch(result) {
                case .success(let response):
                    // self.cachedRegions = response.data
                    self.update(rangeActionsHistory: [])

                    if let delegate = self.delegate {
                        delegate.beaconsManager(self, didReceiveBeaconRegions: response.data)
                    }
                case .failure(let error):
                    NSLog(error.localizedDescription)
                }
            }
        }

        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
        timer = Timer.scheduledTimer(withTimeInterval: Double(60), repeats: true) { timer in
            self.postBeaconRangeActions([])
        }
    }

    open func startScanning(_ regions: [FanMakerSDKBeaconRegion]) {
        stopScanning()

        cachedRegionsQueue.async {
            self.cachedRegions = regions
        }
        for region in regions {
            if let uuid = UUID(uuidString: region.uuid) {
                var beaconRegion : CLBeaconRegion
                if let major = CLBeaconMajorValue(region.major) {
                    log("Monitoring for beacon region UUID: \(uuid) Major: \(major)")
                    beaconRegion = CLBeaconRegion(uuid: uuid, major: major, identifier: "\(region.uuid)::\(region.major)")
                } else {
                    log("Monitoring for beacon region UUID: \(uuid)")
                    beaconRegion = CLBeaconRegion(uuid: uuid, identifier: region.uuid)
                }

                locationManager.startMonitoring(for: beaconRegion)
            }
        }
    }

    open func stopScanning() {
        for region in locationManager.monitoredRegions {
            // The region was found using getCachedRegion, so stop monitoring for it
            if getCachedRegion(from: region.identifier) != nil {
                locationManager.stopMonitoring(for: region)
            }
        }

        cachedRegionsQueue.async {
            self.cachedRegions.removeAll()
        }
    }

    open func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if let delegate = self.delegate {
            delegate.beaconsManager(self, didChangeAuthorization: FanMakerSDKBeaconsAuthorizationStatus.init(rawValue: status.rawValue)!)
        }
    }

    open func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let fmRegion = getCachedRegion(from: region.identifier) else {
            log("NON-FanMaker beacon region. Halting FanMaker didEnterRegion for UUID: \(region.identifier)")
            return
        }

        do {
            try postRegionAction(region_identifier: region.identifier, action: "enter") { delegate, fmRegion in
                delegate.beaconsManager(self, didEnterRegion: fmRegion)
                self.log("Start ranging beacons for FanMaker Region \(fmRegion)")

                if let constraint = fmRegion.constraint() {
                    manager.startRangingBeacons(satisfying: constraint)
                } else {
                    self.log("ERROR: Cannot start raging for FanMaker Region because constraint is nil. FanMaker Region: \(fmRegion)")
                }
            }
        } catch {
            log("\(error)")
        }
    }

    open func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        // Check if the exited region is one we initialized
        guard let fmRegion = getCachedRegion(from: region.identifier) else {
            log("NON-FanMaker beacon region. Halting FanMaker didExitRegion for UUID: \(region.identifier)")
            return
        }

        do {
            try postRegionAction(region_identifier: region.identifier, action: "exit") { delegate, fmRegion in
                delegate.beaconsManager(self, didExitRegion: fmRegion)
                self.log("Stop ranging beacons for FanMaker Region \(fmRegion)")

                if let constraint = fmRegion.constraint() {
                    manager.stopRangingBeacons(satisfying: constraint)
                } else {
                    self.log("ERROR: Cannot stop ranging for FanMaker Region because constraint is nil. FanMaker Region: \(fmRegion)")
                }
            }
        } catch {
            log("\(error)")
        }
    }

    open func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        var queue = rangeActionsHistory()
        var newActions : [FanMakerSDKBeaconRangeAction] = []

        for beacon in beacons {
            let beaconRangeAction = FanMakerSDKBeaconRangeAction(beacon: beacon)
            if shouldAppend(beaconRangeAction, to: queue) {
                queue.append(beaconRangeAction)
                newActions.append(beaconRangeAction)
            }
        }

        if !newActions.isEmpty {
            cachedRegionsQueue.async {
                self.update(rangeActionsHistory: queue)
                self.postBeaconRangeActions(newActions)
            }
        }
    }

    private func getCachedRegion(from identifier: String) -> FanMakerSDKBeaconRegion? {
        let pieces = identifier.components(separatedBy: "::")
        guard pieces.count >= 1 else { return nil }

        let uuid = pieces[0]
        let major: String
        if pieces.count >= 2 { major = pieces[1] }
        else { major = "" }

        return cachedRegions.first(where: { $0.uuid == uuid && $0.major == major })
    }

    private func isUserLogged() -> Bool {
        let defaults = self.sdk.userDefaults

        if let token = defaults?.string(forKey: self.sdk.FanMakerSDKSessionToken) {
            return token != ""
        } else {
            return false
        }
    }

    private func fail(with error: FanMakerSDKBeaconsError) -> Void {
        if error == .userSessionNotFound {
            stopScanning()
        }

        if let delegate = self.delegate {
            delegate.beaconsManager(self, didFailWithError: error)
        }
    }

    private func log(_ message: Any) {
        NSLog("FanMaker (Beacons): \(message)")
    }

    private func postRegionAction(region_identifier: String, action: String, onCompletion: @escaping (FanMakerSDKBeaconsManagerDelegate, FanMakerSDKBeaconRegion) -> Void) {
        guard let fmRegion = getCachedRegion(from: region_identifier) else {
            log("\(action.uppercased()) NON-FanMaker beacon region. Halting FanMaker postRegionAction for UUID: \(region_identifier)")
            return
        }

        let body : [String : String] = [
            "beacon_region_id" : String(fmRegion.id),
            "action_type": action
        ]

        FanMakerSDKHttp.post(sdk: self.sdk, path: "beacon_region_actions", body: body) { result in
            if let delegate = self.delegate {
                switch(result) {
                case .success:
                    onCompletion(delegate, fmRegion)
                case .failure(let error):
                    delegate.beaconsManager(self, didFailWithError: .serverError)
                    self.log("Server error POSTing \(action.uppercased()) FanMaker Beacon")
                    self.log("UUID: \(fmRegion.uuid)")
                }
            }
        }
    }

    private func update(rangeActionsHistory queue: [FanMakerSDKBeaconRangeAction]) {
        let newQueue = update(queueName: FanMakerSDKBeaconRangeActionsHistory, queueContent: queue)
        if let delegate = self.delegate {
            delegate.beaconsManager(self, didUpdateBeaconRangeActionsHistory: newQueue)
        }
    }

    private func update(rangeActionsSendList queue: [FanMakerSDKBeaconRangeAction]) {
        let newQueue = update(queueName: FanMakerSDKBeaconRangeActionsSendList, queueContent: queue)
        if let delegate = self.delegate {
            delegate.beaconsManager(self, didUpdateBeaconRangeActionsSendList: newQueue)
        }
    }

    private func update(queueName: String, queueContent beacons: [FanMakerSDKBeaconRangeAction]) -> [FanMakerSDKBeaconRangeAction] {
        let beacons : [FanMakerSDKBeaconRangeAction] = beacons.suffix(1000)
        let encodedBeacons = try? PropertyListEncoder().encode(beacons.suffix(1000))
        let defaults = self.sdk.userDefaults
        defaults?.set(encodedBeacons, forKey: queueName)

        return beacons
    }

    private func postBeaconRangeActions(_ actions: [FanMakerSDKBeaconRangeAction]) {
        let queue = rangeActionsSendList() + actions
        if (queue.isEmpty) { return }

        let body : [String : [[String : String]]] = ["beacons" : queue.map { $0.toParams() }]
        FanMakerSDKHttp.post(sdk: self.sdk, path: "beacon_range_actions", body: body) { result in
            switch(result) {
            case .success:
                self.update(rangeActionsSendList: [])
                self.log("\(actions.count) beacon range actions successfully posted")
            case .failure:
                self.update(rangeActionsSendList: queue)
                self.log("\(actions.count) beacon range actions added to the send list")
            }
        }
    }

    private func shouldAppend(_ beaconRangeAction: FanMakerSDKBeaconRangeAction, to queue: [FanMakerSDKBeaconRangeAction]) -> Bool {
        guard let lastAction = queue.filter({ queueAction in
            queueAction.uuid == beaconRangeAction.uuid &&
                queueAction.major == beaconRangeAction.major &&
                queueAction.minor == beaconRangeAction.minor
        }).last else { return true }

        return Date().timeIntervalSince(lastAction.seenAt) >= Double(self.sdk.beaconUniquenessThrottle)
    }
}
