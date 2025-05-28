//
//  File.swift
//
//
//  Created by Érik Escobedo on 21/05/21.
//

import Foundation

public protocol FanMakerSDKHttpResponse : Decodable {
    associatedtype FanMakerSDKHttpResponseData
    var status : Int { get }
    var message : String { get }
    var data : FanMakerSDKHttpResponseData { get }
}

public struct FanMakerSDKPostResponse : FanMakerSDKHttpResponse {
    public typealias FanMakerSDKHttpResponseData = Any

    public let status : Int
    public let message : String
    public let data : Any

    public init(status: Int, message: String, data: Any) {
        self.status = status
        self.message = message
        self.data = data
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case message
        case data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(Int.self, forKey: .status)
        message = try container.decode(String.self, forKey: .message)

        // Try to decode data as a string first
        if let str = try? container.decode(String.self, forKey: .data) {
            data = str
        } else {
            // If not a string, try to decode as a dictionary
            let dataContainer = try container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .data)
            var dict: [String: Any] = [:]

            for key in dataContainer.allKeys {
                if let value = try? dataContainer.decode(String.self, forKey: key) {
                    dict[key.stringValue] = value
                } else if let value = try? dataContainer.decode(Int.self, forKey: key) {
                    dict[key.stringValue] = value
                } else if let value = try? dataContainer.decode(Double.self, forKey: key) {
                    dict[key.stringValue] = value
                } else if let value = try? dataContainer.decode(Bool.self, forKey: key) {
                    dict[key.stringValue] = value
                } else if let value = try? dataContainer.decode([String].self, forKey: key) {
                    dict[key.stringValue] = value
                } else if let value = try? dataContainer.decode([Int].self, forKey: key) {
                    dict[key.stringValue] = value
                } else if let value = try? dataContainer.decode([Double].self, forKey: key) {
                    dict[key.stringValue] = value
                } else if let value = try? dataContainer.decode([Bool].self, forKey: key) {
                    dict[key.stringValue] = value
                }
            }

            data = dict.isEmpty ? "" : dict
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

    static var allKeys: [DynamicCodingKeys] {
        return []
    }
}
