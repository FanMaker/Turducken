//
//  File.swift
//  
//
//  Created by Érik Escobedo on 24/05/21.
//

import Foundation

public struct FanMakerSDKHttp {
    public static func get<HttpResponse : FanMakerSDKHttpResponse>(path: String, model: HttpResponse.Type, onCompletion: @escaping (Result<HttpResponse, FanMakerSDKHttpError>) -> Void) {
        
        let request = FanMakerSDKHttpRequest(path: path)
        request.request(method: "GET", body: [:], model: model.self, onCompletion: onCompletion)
    }
    
    public static func post(path: String, body: Any, onCompletion: @escaping (Result<FanMakerSDKPostResponse, FanMakerSDKHttpError>) -> Void) {
        
        let request = FanMakerSDKHttpRequest(path: path)
        request.request(method: "POST", body: body, model: FanMakerSDKPostResponse.self, onCompletion: onCompletion)
    }
}
