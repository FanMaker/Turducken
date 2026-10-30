//
//  File.swift
//  
//
//  Created by Érik Escobedo on 02/12/21.
//

import Foundation

public struct FanMakerSDKIdentifiers: Decodable, @unchecked Sendable {
    public let user_id: String?
    public let member_id: String?
    public let student_id: String?
    public let ticketmaster_id: String?
    public let yinzid: String?
    public let push_token: String?
    public let fanmaker_identifiers: [String: Any]?

    private enum CodingKeys: String, CodingKey {
        case user_id
        case member_id
        case student_id
        case ticketmaster_id
        case yinzid
        case push_token
        case fanmaker_identifiers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user_id = try container.decodeIfPresent(String.self, forKey: .user_id)
        member_id = try container.decodeIfPresent(String.self, forKey: .member_id)
        student_id = try container.decodeIfPresent(String.self, forKey: .student_id)
        ticketmaster_id = try container.decodeIfPresent(String.self, forKey: .ticketmaster_id)
        yinzid = try container.decodeIfPresent(String.self, forKey: .yinzid)
        push_token = try container.decodeIfPresent(String.self, forKey: .push_token)

        // fanmaker_identifiers is a nested JSON object. Decoding it as Data
        // asked JSONDecoder for a base64 string, so it threw a type mismatch
        // whenever the field was present - and setIdentifiers(fromJSON:)
        // swallowed that, dropping *every* identifier rather than just this
        // one. Read it as a dynamic-keyed container instead, the same way the
        // other responses in this package read their free-form dictionaries.
        if let nested = try? container.nestedContainer(keyedBy: DynamicCodingKeys.self,
                                                       forKey: .fanmaker_identifiers) {
            var dict: [String: Any] = [:]
            for key in nested.allKeys {
                if let value = try? nested.decode(String.self, forKey: key) {
                    dict[key.stringValue] = value
                } else if let value = try? nested.decode(Int.self, forKey: key) {
                    dict[key.stringValue] = value
                } else if let value = try? nested.decode(Double.self, forKey: key) {
                    dict[key.stringValue] = value
                } else if let value = try? nested.decode(Bool.self, forKey: key) {
                    dict[key.stringValue] = value
                }
            }
            fanmaker_identifiers = dict
        } else {
            fanmaker_identifiers = nil
        }
    }
}

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
