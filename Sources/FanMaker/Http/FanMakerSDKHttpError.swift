//
//  File.swift
//  
//
//  Created by Érik Escobedo on 24/05/21.
//

import Foundation

public struct FanMakerSDKHttpError : LocalizedError {
    public enum ErrorCode : Int {
        case badUrl
        case badHttpMethod
        case badData
        case success = 200
        case forbidden = 401
        case notFound = 404
        case serverError = 500
        case emptyResponse
        case badResponse
        case unknown
    }
    
    public let code : ErrorCode
    public let message : String
    
    public var errorDescription: String? {
        return "Error #\(code): \(message)"
    }
}

extension FanMakerSDKHttpError {
    init(httpCode : Int) {
        self.code = ErrorCode(rawValue: httpCode)!
        
        switch(self.code) {
        case .notFound:
            self.message = "Not Found"
        default:
            self.message = "Unknow Error"
            break
        }
    }
    
    init(httpCode : Int, message : String) {
        self.code = ErrorCode(rawValue: httpCode)!
        self.message = message
    }
}
