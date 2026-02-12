//
//  File.swift
//
//
//  Created by Érik Escobedo on 24/05/21.
//

import Foundation

public struct FanMakerSDKHttpRequest {
    let sdk: FanMakerSDK
    public static let apiBase : String = "https://api3.fanmaker.com"
    // public static let apiBase : String = "http://api3.fanmaker.work:3002"
    public static let host : String = "\(apiBase)/api/v3"
    public let urlString : String
    private var request : URLRequest? = nil

    init(sdk: FanMakerSDK, path: String) {
        self.sdk = sdk
        self.urlString = "\(FanMakerSDKHttpRequest.host)/\(path)"

        if let url = URL(string: urlString) {
            self.request = URLRequest(url: url)
        }
    }

    func request<HttpResponse : FanMakerSDKHttpResponse>(method: String, body: Any, model: HttpResponse.Type, onCompletion: @escaping (Result<HttpResponse, FanMakerSDKHttpError>) -> Void) {
        request(method: method, body: body, useSiteApiToken: false, model: model, onCompletion: onCompletion)
    }
    
    func request<HttpResponse : FanMakerSDKHttpResponse>(method: String, body: Any, useSiteApiToken: Bool, model: HttpResponse.Type, onCompletion: @escaping (Result<HttpResponse, FanMakerSDKHttpError>) -> Void) {

        guard var request = self.request else {
            onCompletion(.failure(FanMakerSDKHttpError(code: .badUrl, message: self.urlString)))
            return
        }

        request.setValue("4.0.0", forHTTPHeaderField: "X-FanMaker-SDK-Version")
        request.setValue("sdk", forHTTPHeaderField: "X-FanMaker-Mode")

        switch method {
        case "GET":
            request.httpMethod = "GET"
            request.setValue(self.sdk.apiKey, forHTTPHeaderField: "X-FanMaker-Token")
            request.setValue(self.sdk.apiKey, forHTTPHeaderField: "Authorization")
            self.executeRequest(request, method: method, model: model, onCompletion: onCompletion)

        case "POST":
            request.httpMethod = "POST"
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            } catch let jsonError as NSError {
                onCompletion(.failure(FanMakerSDKHttpError(code: .badData, message: jsonError.localizedDescription)))
                return
            }
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if useSiteApiToken {
                // Use site API token in Authorization header
                request.setValue(self.sdk.apiKey, forHTTPHeaderField: "X-FanMaker-Token")
                request.setValue(self.sdk.apiKey, forHTTPHeaderField: "Authorization")
                self.executeRequest(request, method: method, model: model, onCompletion: onCompletion)
            } else {
                // Default behavior: use session token if available, otherwise API key
                let defaults = self.sdk.userDefaults
                if let userToken = defaults?.string(forKey: self.sdk.FanMakerSDKSessionToken) {
                    // Resolve token type and handle OAuth refresh if needed
                    FanMakerSDKTokenResolver.getValidToken(
                        tokenString: userToken,
                        apiBase: FanMakerSDKHttpRequest.apiBase,
                        onRefreshed: { newTokenString in
                            // Persist the refreshed token back to UserDefaults
                            self.sdk.updateSessionToken(newTokenString)
                        },
                        completion: { tokenResult in
                            switch tokenResult {
                            case .success(let validTokenType):
                                let sessionHeaderValue = FanMakerSDKTokenResolver.sessionTokenHeaderValue(
                                    for: validTokenType,
                                    rawTokenString: userToken
                                )
                                let authHeaderValue = FanMakerSDKTokenResolver.authorizationHeaderValue(for: validTokenType)

                                request.setValue(sessionHeaderValue, forHTTPHeaderField: "X-FanMaker-SessionToken")
                                request.setValue(authHeaderValue, forHTTPHeaderField: "Authorization")
                                self.executeRequest(request, method: method, model: model, onCompletion: onCompletion)

                            case .failure(let error):
                                onCompletion(.failure(error))
                            }
                        }
                    )
                } else {
                    request.setValue(self.sdk.apiKey, forHTTPHeaderField: "X-FanMaker-Token")
                    request.setValue(self.sdk.apiKey, forHTTPHeaderField: "Authorization")
                    self.executeRequest(request, method: method, model: model, onCompletion: onCompletion)
                }
            }

        default:
            onCompletion(.failure(FanMakerSDKHttpError(code: .badHttpMethod, message: method)))
        }
    }

    /// Executes the URLSession data task and handles the response parsing.
    /// Extracted from `request()` so it can be called after async token resolution.
    private func executeRequest<HttpResponse : FanMakerSDKHttpResponse>(_ request: URLRequest, method: String, model: HttpResponse.Type, onCompletion: @escaping (Result<HttpResponse, FanMakerSDKHttpError>) -> Void) {
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                onCompletion(.failure(FanMakerSDKHttpError(code: .unknown, message: "Unknow error")))
                return
            }

            guard let httpResponse : HTTPURLResponse = response as? HTTPURLResponse, let data = data else {
                onCompletion(.failure(FanMakerSDKHttpError(code: .badResponse, message: "Invalid HTTP Response")))
                return
            }

            if httpResponse.statusCode == 200 {
                do {
                    switch method {
                    case "GET":
                        let jsonResponse = try JSONDecoder().decode(model.self, from: data)
                        if jsonResponse.status == 200 {
                            onCompletion(.success(jsonResponse))
                        } else {
                            onCompletion(.failure(FanMakerSDKHttpError(httpCode: jsonResponse.status, message: jsonResponse.message)))
                        }
                    case "POST":
                        if data.count <= 1 {
                            let response = FanMakerSDKPostResponse(status: 200, message: "", data: "")
                            onCompletion(.success(response as! HttpResponse))
                        } else {
                            do {
                                // First try to decode as JSON
                                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let status = json["status"] as? Int,
                                   let message = json["message"] as? String {
                                    
                                    // Create response with flexible data type
                                    let response = FanMakerSDKPostResponse(
                                        status: status,
                                        message: message,
                                        data: json["data"] ?? ""
                                    )
                                    onCompletion(.success(response as! HttpResponse))
                                } else {
                                    // Fall back to standard decoding
                                    let jsonResponse = try JSONDecoder().decode(model.self, from: data)
                                    if jsonResponse.status >= 200 && jsonResponse.status < 300 {
                                        onCompletion(.success(jsonResponse))
                                    } else {
                                        onCompletion(.failure(FanMakerSDKHttpError(httpCode: jsonResponse.status, message: jsonResponse.message)))
                                    }
                                }
                            } catch let jsonError as NSError {
                                onCompletion(.failure(FanMakerSDKHttpError(code: .badResponse, message: jsonError.localizedDescription)))
                            }
                        }
                    default:
                        onCompletion(.failure(FanMakerSDKHttpError(code: .badHttpMethod, message: method)))
                    }

                } catch let jsonError as NSError {
                    onCompletion(.failure(FanMakerSDKHttpError(code: .badResponse, message: jsonError.localizedDescription)))
                }
            } else {
                onCompletion(.failure(FanMakerSDKHttpError(httpCode: httpResponse.statusCode)))
            }
        }.resume()
    }
}
