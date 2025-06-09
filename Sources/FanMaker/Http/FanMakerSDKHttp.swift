//
//  File.swift
//
//
//  Created by Érik Escobedo on 24/05/21.
//

import Foundation

public struct FanMakerSDKHttp {
    public static func get<HttpResponse : FanMakerSDKHttpResponse>(sdk: FanMakerSDK, path: String, model: HttpResponse.Type, onCompletion: @escaping (Result<HttpResponse, FanMakerSDKHttpError>) -> Void) {

        let request = FanMakerSDKHttpRequest(sdk: sdk, path: path)
        request.request(method: "GET", body: [:], model: model.self, onCompletion: onCompletion)
    }

    public static func post(sdk: FanMakerSDK, path: String, body: Any, onCompletion: @escaping (Result<FanMakerSDKPostResponse, FanMakerSDKHttpError>) -> Void) {

        let request = FanMakerSDKHttpRequest(sdk: sdk, path: path)
        request.request(method: "POST", body: body, model: FanMakerSDKPostResponse.self, onCompletion: onCompletion)
    }
    
    public static func post(sdk: FanMakerSDK, path: String, body: Any, useSiteApiToken: Bool, onCompletion: @escaping (Result<FanMakerSDKPostResponse, FanMakerSDKHttpError>) -> Void) {

        let request = FanMakerSDKHttpRequest(sdk: sdk, path: path)
        request.request(method: "POST", body: body, useSiteApiToken: useSiteApiToken, model: FanMakerSDKPostResponse.self, onCompletion: onCompletion)
    }
}
