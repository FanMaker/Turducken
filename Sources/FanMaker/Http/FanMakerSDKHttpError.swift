//
//  File.swift
//  
//
//  Created by Érik Escobedo on 24/05/21.
//

import Foundation

public struct FanMakerSDKHttpError : LocalizedError, Sendable {
    public enum ErrorCode : Int, Sendable {
        case badUrl = 1
        case badHttpMethod = 2
        case badData = 3
        case badResponse = 4
        case unknown = 5
        case tokenRefreshFailed = 6
        case success = 200
        case forbidden = 401
        case notFound = 404
        case serverError = 500
    }
    
    public let code : ErrorCode
    public let httpCode : Int?
    public let message : String
    
    public init(code: ErrorCode, message: String) {
        self.code = code
        self.httpCode = nil
        self.message = message
    }
    
    public init(httpCode: Int, message: String = "") {
        self.code = ErrorCode(rawValue: httpCode) ?? .unknown
        self.httpCode = httpCode
        self.message = message
    }
    
    public var errorDescription: String? {
        return message
    }
}

extension FanMakerSDKHttpError {
    init(httpCode : Int) {
        self.httpCode = httpCode
        self.code = ErrorCode(rawValue: httpCode) ?? .unknown
        
        switch(self.code) {
        case .notFound:
            self.message = "Not Found"
        case .forbidden:
            self.message = "Forbidden"
        case .serverError:
            self.message = "Server Error"
        default:
            self.message = "Unknown Error"
        }
    }
    

}
