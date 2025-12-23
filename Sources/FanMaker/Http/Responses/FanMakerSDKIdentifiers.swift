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

        if let identifiersData = try container.decodeIfPresent(Data.self, forKey: .fanmaker_identifiers) {
            fanmaker_identifiers = try JSONSerialization.jsonObject(with: identifiersData, options: []) as? [String: Any]
        } else {
            fanmaker_identifiers = nil
        }
    }
}
