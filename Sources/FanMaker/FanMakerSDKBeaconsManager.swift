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
    public var posted : Bool

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
        self.posted = false
        
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
    
    weak open var delegate: FanMakerSDKBeaconsManagerDelegate?
    var locationManager : CLLocationManager
    var cachedRegions : [FanMakerSDKBeaconRegion] = []
    
    private let FanMakerSDKBeaconRangeActionsQueue = "FanMakerSDKBeaconRangeActionsQueue"
    private let throttling = 60
    private var timer : Timer?
    
    override public init() {
        self.locationManager = CLLocationManager()
        super.init()
        self.locationManager.delegate = self
    }
    
    public func currentBeaconRangeActionsQueue() -> [FanMakerSDKBeaconRangeAction] {
        guard let data = UserDefaults.standard.data(forKey: FanMakerSDKBeaconRangeActionsQueue) else { return [] }
        return (try? PropertyListDecoder().decode([FanMakerSDKBeaconRangeAction].self, from: data)) ?? []
    }
    
    open func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    open func fetchBeaconRegions() {
        guard isUserLogged() else { return fail(with: .userSessionNotFound) }

        DispatchQueue.global().async {
            FanMakerSDKHttp.get(path: "beacon_regions", model: FanMakerSDKBeaconRegionsResponse.self) { result in
                switch(result) {
                case .success(let response):
                    self.cachedRegions = response.data
                    if let delegate = self.delegate {
                        delegate.beaconsManager(self, didReceiveBeaconRegions: self.cachedRegions)
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
        timer = Timer.scheduledTimer(withTimeInterval: Double(throttling), repeats: true) { timer in
            self.postBeaconRangeActionsQueue()
        }
    }
    
    open func startScanning(_ regions: [FanMakerSDKBeaconRegion]) {
        stopScanning()
        for region in regions {
            if let uuid = UUID(uuidString: region.uuid) {
                var beaconRegion : CLBeaconRegion
                if let major = CLBeaconMajorValue(region.major) {
                    log("Monitoring for beacon region UUID: \(uuid) Major: \(major)")
                    beaconRegion = CLBeaconRegion(uuid: uuid, major: major, identifier: region.uuid)
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
            locationManager.stopMonitoring(for: region)
        }
    }
    
    open func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if let delegate = self.delegate {
            delegate.beaconsManager(self, didChangeAuthorization: FanMakerSDKBeaconsAuthorizationStatus.init(rawValue: status.rawValue)!)
        }
    }
    
    open func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        postRegionAction(region_identifier: region.identifier, action: "enter") { delegate, fmRegion in
            delegate.beaconsManager(self, didEnterRegion: fmRegion)
            self.log("Start ranging beacons for Region \(fmRegion)")
            manager.startRangingBeacons(satisfying: fmRegion.constraint()!)
        }
    }
    
    open func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        postRegionAction(region_identifier: region.identifier, action: "exit") { delegate, fmRegion in
            delegate.beaconsManager(self, didExitRegion: fmRegion)
            self.log("Stop ranging beacons for Region \(fmRegion)")
            manager.stopRangingBeacons(satisfying: fmRegion.constraint()!)
        }
    }
    
    open func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        
        var queue = currentBeaconRangeActionsQueue()
        for beacon in beacons {
            let beaconRangeAction = FanMakerSDKBeaconRangeAction(beacon: beacon)
            if shouldAppend(beaconRangeAction, to: queue) {
                queue.append(beaconRangeAction)
            }
        }
        
        if queue.count > currentBeaconRangeActionsQueue().count {
            update(beaconRangeActionsQueue: queue)
        }
    }
    
    private func getCachedRegion(from identifier: String) -> FanMakerSDKBeaconRegion? {
        return cachedRegions.first(where: { $0.uuid == identifier })
    }
    
    private func isUserLogged() -> Bool {
        let defaults = UserDefaults.standard

        if let token = defaults.string(forKey: FanMakerSDKSessionToken) {
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
            log("\(action.uppercased()) NON-FanMaker beacon region")
            log("UUID: \(region_identifier)")
            return
        }
        
        let body : [String : String] = [
            "beacon_region_id" : String(fmRegion.id),
            "action_type": action
        ]
        
        FanMakerSDKHttp.post(path: "beacon_region_actions", body: body) { result in
            if let delegate = self.delegate {
                switch(result) {
                case .success:
                    onCompletion(delegate, fmRegion)
                case .failure:
                    delegate.beaconsManager(self, didFailWithError: .serverError)
                    self.log("Server error POSTing \(action.uppercased()) FanMaker Beacon")
                    self.log("UUID: \(fmRegion.uuid)")
                }
            }
        }
    }

    private func update(beaconRangeActionsQueue queue: [FanMakerSDKBeaconRangeAction]) {
        let queue : [FanMakerSDKBeaconRangeAction] = queue.suffix(1000)
        
        UserDefaults.standard.set(try? PropertyListEncoder().encode(queue), forKey: FanMakerSDKBeaconRangeActionsQueue)
        
        if let delegate = self.delegate {
            delegate.beaconsManager(self, didUpdateBeaconRangeActionsQueue: queue)
        }
    }
    
    private func postBeaconRangeActionsQueue() {
        let queue = currentBeaconRangeActionsQueue()
        if (queue.isEmpty) { return }
        
        var foundPending : Bool = false
        var first : [FanMakerSDKBeaconRangeAction] = []
        var middle : [FanMakerSDKBeaconRangeAction] = []
        var last : [FanMakerSDKBeaconRangeAction] = []
        
        for action in queue {
            if foundPending {
                if middle.count < 10 {
                    middle.append(action)
                } else {
                    last.append(action)
                }
            } else {
                if action.posted {
                    first.append(action)
                } else {
                    foundPending = true
                    middle.append(action)
                }
            }
        }
        if middle.isEmpty { return }
        
        let body : [String : [[String : String]]] = ["beacons" : middle.map { $0.toParams() }]
    
        FanMakerSDKHttp.post(path: "beacon_range_actions", body: body) { result in
            switch(result) {
            case .success:
                middle = middle.map {
                    var action = $0
                    action.posted = true
                    return action
                }
                
                let newQueue = first + middle + last
                self.update(beaconRangeActionsQueue: newQueue)
            case .failure:
                self.log("Network error")
            }
        }
    }
    
    private func shouldAppend(_ beaconRangeAction: FanMakerSDKBeaconRangeAction, to queue: [FanMakerSDKBeaconRangeAction]) -> Bool {
        
        guard let lastAction = queue.filter({ queueAction in
            queueAction.uuid == beaconRangeAction.uuid && queueAction.minor == beaconRangeAction.minor
        }).last else { return true }
        
        return Date().timeIntervalSince(lastAction.seenAt) >= Double(throttling)
    }
}
