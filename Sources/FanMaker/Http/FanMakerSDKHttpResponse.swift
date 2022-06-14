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
    public let status : Int
    public let message : String
    public let data : String
}
