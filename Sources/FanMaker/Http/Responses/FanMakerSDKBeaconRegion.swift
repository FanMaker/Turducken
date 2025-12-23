//
//  FanMakerSDKBeaconRegion.swift
//  Turducken
//
//  Created by Érik Escobedo on 10/06/22.
//

import Foundation
import CoreLocation

public struct FanMakerSDKBeaconRegion : Decodable, Sendable {
    public let id : Int
    public let name : String
    public let uuid : String
    public let major : String
    public let minor : String
    public let active : Bool
    
    @available(iOS 13.0, *)
    public func constraint() -> CLBeaconIdentityConstraint? {
        if let parsedUUID = UUID(uuidString: uuid), let parsedMajor = CLBeaconMajorValue(major) {
            return CLBeaconIdentityConstraint(uuid: parsedUUID, major: parsedMajor)
        } else {
            return nil
        }
    }
}

public struct FanMakerSDKBeaconRegionsResponse : FanMakerSDKHttpResponse, @unchecked Sendable {
    public let status : Int
    public let message : String
    public let config : [String: Any]?
    public let data : [FanMakerSDKBeaconRegion]
    
    private enum CodingKeys: String, CodingKey {
        case status
        case message
        case config
        case data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(Int.self, forKey: .status)
        message = try container.decode(String.self, forKey: .message)
        data = try container.decode([FanMakerSDKBeaconRegion].self, forKey: .data)
        
        // Handle the config dictionary which is [String: Any]
        if container.contains(.config) {
            // Try to decode as a nested container and build the dictionary manually
            if let configContainer = try? container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .config) {
                var dict: [String: Any] = [:]
                
                for key in configContainer.allKeys {
                    if let value = try? configContainer.decode(String.self, forKey: key) {
                        dict[key.stringValue] = value
                    } else if let value = try? configContainer.decode(Int.self, forKey: key) {
                        dict[key.stringValue] = value
                    } else if let value = try? configContainer.decode(Double.self, forKey: key) {
                        dict[key.stringValue] = value
                    } else if let value = try? configContainer.decode(Bool.self, forKey: key) {
                        dict[key.stringValue] = value
                    }
                }
                
                config = dict.isEmpty ? nil : dict
            } else {
                config = nil
            }
        } else {
            config = nil
        }
    }
}

// Helper for dynamic dictionary keys
private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

extension String.StringInterpolation {
    mutating func appendInterpolation(_ region: FanMakerSDKBeaconRegion) {
        appendInterpolation("UUID: \(region.uuid) Major \(region.major)")
    }
}
