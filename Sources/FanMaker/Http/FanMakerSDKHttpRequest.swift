//
//  File.swift
//
//
//  Created by Érik Escobedo on 24/05/21.
//

import Foundation

public struct FanMakerSDKHttpRequest {
    let sdk: FanMakerSDK
    // public static let apiBase = String = "https://api3.fanmaker.com"
    public static let apiBase : String = "http://api3.fanmaker.work:3002"
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

        guard var request = self.request else {
            onCompletion(.failure(FanMakerSDKHttpError(code: .badUrl, message: self.urlString)))
            return
        }

        request.setValue("2.1.0", forHTTPHeaderField: "X-FanMaker-SDK-Version")
        request.setValue("sdk", forHTTPHeaderField: "X-FanMaker-Mode")
        do {
            switch method {
            case "GET":
                request.httpMethod = "GET"
                request.setValue(self.sdk.apiKey, forHTTPHeaderField: "X-FanMaker-Token")
                request.setValue(self.sdk.apiKey, forHTTPHeaderField: "Authorization")
            case "POST":
                request.httpMethod = "POST"
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let defaults = self.sdk.userDefaults
                if let userToken = defaults?.string(forKey: self.sdk.FanMakerSDKSessionToken) {
                    request.setValue(userToken, forHTTPHeaderField: "X-FanMaker-SessionToken")
                    request.setValue(userToken, forHTTPHeaderField: "Authorization")
                } else {
                    request.setValue(self.sdk.apiKey, forHTTPHeaderField: "X-FanMaker-Token")
                    request.setValue(self.sdk.apiKey, forHTTPHeaderField: "Authorization")
                }
            default:
                onCompletion(.failure(FanMakerSDKHttpError(code: .badHttpMethod, message: method)))
            }
        } catch let jsonError as NSError {
            onCompletion(.failure(FanMakerSDKHttpError(code: .badData, message: jsonError.localizedDescription)))
        }

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
