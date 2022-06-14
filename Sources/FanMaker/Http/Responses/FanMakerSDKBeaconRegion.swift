//
//  FanMakerSDKBeaconRegion.swift
//  Turducken
//
//  Created by Érik Escobedo on 10/06/22.
//

import Foundation
import CoreLocation

public struct FanMakerSDKBeaconRegion : Decodable {
    public let id : Int
    public let name : String
    public let uuid : String
    public let major : String
    public let minor : String
    public let active : Bool
    
    public func constraint() -> CLBeaconIdentityConstraint? {
        if let parsedUUID = UUID(uuidString: uuid), let parsedMajor = CLBeaconMajorValue(major) {
            return CLBeaconIdentityConstraint(uuid: parsedUUID, major: parsedMajor)
        } else {
            return nil
        }
    }
}

public struct FanMakerSDKBeaconRegionsResponse : FanMakerSDKHttpResponse {
    public let status : Int
    public let message : String
    public let data : [FanMakerSDKBeaconRegion]
}

extension String.StringInterpolation {
    mutating func appendInterpolation(_ region: FanMakerSDKBeaconRegion) {
        appendInterpolation("UUID: \(region.uuid) Major \(region.major)")
    }
}
