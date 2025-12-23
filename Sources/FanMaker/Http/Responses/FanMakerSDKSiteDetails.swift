//
//  File.swift
// 
//
//  Created by Érik Escobedo on 24/05/21.
//

import Foundation

public struct FanMakerSDKBeacons : Decodable, Sendable {
    public let beaconUniquenessThrottle : String
}

public struct FanMakerSDKSiteFeatures : Decodable, Sendable {
    public let beacons : FanMakerSDKBeacons
}

public struct FanMakerSDKSiteDetails : Decodable, Sendable {
    public let canonical_url : String
    public let sdk_url : String
    public let site_features : FanMakerSDKSiteFeatures
}

public struct FanMakerSDKSiteDetailsResponse : FanMakerSDKHttpResponse, @unchecked Sendable {
    public let status : Int
    public let message : String
    public let config : [String: Any]?
    public let data : FanMakerSDKSiteDetails
    
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
        data = try container.decode(FanMakerSDKSiteDetails.self, forKey: .data)
        
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

public struct FanMakerSDKInfoBeacons : Decodable, Sendable {
    public let uniqueness_throttle : String
}

public struct FanMakerSDKInfo : Decodable, Sendable {
    public let url : String
    public let beacons : FanMakerSDKInfoBeacons
}

public struct FanMakerSDKInfoResponse : FanMakerSDKHttpResponse, @unchecked Sendable {
    public let status : Int
    public let message : String
    public let config : [String: Any]?
    public let data : FanMakerSDKInfo
    
    private enum InfoCodingKeys: String, CodingKey {
        case status
        case message
        case config
        case data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: InfoCodingKeys.self)
        status = try container.decode(Int.self, forKey: .status)
        message = try container.decode(String.self, forKey: .message)
        data = try container.decode(FanMakerSDKInfo.self, forKey: .data)
        
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
