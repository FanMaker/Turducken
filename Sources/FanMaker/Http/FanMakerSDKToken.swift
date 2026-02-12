//
//  FanMakerSDKToken.swift
//
//  Universal token type detection, expiration checking, and OAuth refresh support.
//

import Foundation

// MARK: - OAuth Token Data Model

/// Represents the parsed JSON payload of an OAuth access token from Doorkeeper.
/// `expires_at` is optional because standard Doorkeeper responses don't include it;
/// when missing it is computed from `created_at + expires_in`.
public struct FanMakerSDKOAuthToken: Codable {
    public let access_token: String
    public let refresh_token: String
    public let expires_in: Int
    public let created_at: Int

    /// May be provided directly (e.g. from ApiTokenGenerator) or computed.
    private let _expires_at: Int?

    public var expires_at: Int {
        return _expires_at ?? (created_at + expires_in)
    }

    enum CodingKeys: String, CodingKey {
        case access_token, refresh_token, expires_in, created_at
        case _expires_at = "expires_at"
    }

    /// Returns a JSON string representation suitable for storing back in UserDefaults
    /// or sending as a header value. Always includes `expires_at` (computed if needed).
    public func toJSONString() -> String? {
        // Build a dictionary so we always include expires_at in the output,
        // even if it was computed from created_at + expires_in.
        let dict: [String: Any] = [
            "access_token": access_token,
            "refresh_token": refresh_token,
            "expires_in": expires_in,
            "expires_at": expires_at,
            "created_at": created_at
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Token Type Enum

/// Represents the two possible token types the SDK may encounter.
public enum FanMakerSDKTokenType {
    /// A plain API token string (e.g., "a8df7897dfaiod7faehrl")
    case apiToken(String)
    /// An OAuth token parsed from a JSON string
    case oauthToken(FanMakerSDKOAuthToken)
}

// MARK: - Token Resolver

/// Utility for detecting token types, checking expiration, building header values,
/// and refreshing expired OAuth tokens via Doorkeeper.
///
/// Refresh requests are coalesced: if multiple callers request a refresh at the same time,
/// only one network request is made and the result is shared with all waiting callers.
public class FanMakerSDKTokenResolver {

    /// Buffer in seconds before `expires_at` to consider the token expired,
    /// avoiding edge-case races where the token expires mid-flight.
    private static let expirationBufferSeconds: TimeInterval = 30

    // MARK: - Refresh Coalescing State

    /// Lock protecting the refresh queue state.
    private static let refreshLock = NSLock()
    /// Whether a refresh network request is currently in-flight.
    private static var isRefreshing = false
    /// Queued completions waiting for the in-flight refresh to finish.
    private static var pendingRefreshCompletions: [(Result<FanMakerSDKOAuthToken, FanMakerSDKHttpError>) -> Void] = []

    // MARK: - Token Type Detection

    /// Attempts to parse the token string as an OAuth JSON payload.
    /// Falls back to `.apiToken` if JSON decoding fails.
    public static func resolve(_ tokenString: String) -> FanMakerSDKTokenType {
        guard let data = tokenString.data(using: .utf8) else {
            NSLog("FanMaker ######################################################################## Token Type: API Token")
            return .apiToken(tokenString)
        }

        do {
            let oauthToken = try JSONDecoder().decode(FanMakerSDKOAuthToken.self, from: data)
            NSLog("FanMaker ######################################################################## Token Type: OAuth Access Token (expired: \(isExpired(oauthToken) ? "YES" : "NO"))")
            return .oauthToken(oauthToken)
        } catch {
            NSLog("FanMaker ######################################################################## Token Type: API Token")
            return .apiToken(tokenString)
        }
    }

    // MARK: - Expiration Check

    /// Returns `true` if the OAuth token has expired (or will expire within the buffer window).
    public static func isExpired(_ token: FanMakerSDKOAuthToken) -> Bool {
        let expiresAtDate = Date(timeIntervalSince1970: TimeInterval(token.expires_at))
        let bufferedExpiration = expiresAtDate.addingTimeInterval(-expirationBufferSeconds)
        return Date() >= bufferedExpiration
    }

    // MARK: - Header Value Builders

    /// Returns the value for the `Authorization` header.
    /// - For OAuth tokens: `"Bearer <access_token>"` (checks if `Bearer` is already present)
    /// - For API tokens: the raw token string as-is
    public static func authorizationHeaderValue(for tokenType: FanMakerSDKTokenType) -> String {
        switch tokenType {
        case .apiToken(let token):
            return token
        case .oauthToken(let oauthToken):
            let accessToken = oauthToken.access_token
            if accessToken.lowercased().hasPrefix("bearer ") {
                return accessToken
            }
            return "Bearer \(accessToken)"
        }
    }

    /// Returns the value for the `X-FanMaker-SessionToken` header.
    /// - For OAuth tokens: the full original JSON string (receiver will JSON decode it)
    /// - For API tokens: the raw token string as-is
    public static func sessionTokenHeaderValue(for tokenType: FanMakerSDKTokenType, rawTokenString: String) -> String {
        switch tokenType {
        case .apiToken(let token):
            return token
        case .oauthToken(let oauthToken):
            // Prefer re-encoding the token to ensure consistency after a refresh,
            // but fall back to the raw string if encoding fails.
            return oauthToken.toJSONString() ?? rawTokenString
        }
    }

    // MARK: - Token Refresh (Coalesced)

    /// Enqueues a refresh request. If a refresh is already in-flight, the completion
    /// is queued and will be called with the result of the in-flight request.
    /// Only one network request is made regardless of how many callers need a refresh.
    private static func enqueueRefresh(
        _ token: FanMakerSDKOAuthToken,
        apiBase: String,
        completion: @escaping (Result<FanMakerSDKOAuthToken, FanMakerSDKHttpError>) -> Void
    ) {
        refreshLock.lock()

        if isRefreshing {
            // A refresh is already in-flight -- just queue up and wait
            let queueSize = pendingRefreshCompletions.count + 1
            NSLog("FanMaker ######################################################################## Refresh already in-flight, queuing caller (\(queueSize) waiting)")
            pendingRefreshCompletions.append(completion)
            refreshLock.unlock()
            return
        }

        // We're the first -- mark as refreshing and go
        isRefreshing = true
        refreshLock.unlock()

        executeRefresh(token, apiBase: apiBase) { result in
            // Grab all pending completions and reset state
            refreshLock.lock()
            let waitingCompletions = pendingRefreshCompletions
            pendingRefreshCompletions = []
            isRefreshing = false
            refreshLock.unlock()

            let totalCallers = waitingCompletions.count + 1
            NSLog("FanMaker ######################################################################## Refresh complete, notifying \(totalCallers) caller(s)")

            // Notify the original caller
            completion(result)
            // Notify all queued callers with the same result
            for waiting in waitingCompletions {
                waiting(result)
            }
        }
    }

    /// Executes the actual network request to refresh the OAuth token.
    /// Only called by `enqueueRefresh` -- never directly.
    private static func executeRefresh(
        _ token: FanMakerSDKOAuthToken,
        apiBase: String,
        completion: @escaping (Result<FanMakerSDKOAuthToken, FanMakerSDKHttpError>) -> Void
    ) {
        let urlString = "\(apiBase)/oauth/token"
        guard let url = URL(string: urlString) else {
            completion(.failure(FanMakerSDKHttpError(code: .badUrl, message: urlString)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": token.refresh_token
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(FanMakerSDKHttpError(code: .badData, message: "Failed to serialize refresh token request body")))
            return
        }

        NSLog("FanMaker ######################################################################## Refresh starting: POST \(urlString)")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                NSLog("FanMaker ######################################################################## Refresh ERROR (network): \(error.localizedDescription)")
                completion(.failure(FanMakerSDKHttpError(code: .tokenRefreshFailed, message: "Token refresh network error: \(error.localizedDescription)")))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                NSLog("FanMaker ######################################################################## Refresh ERROR: no response or data")
                completion(.failure(FanMakerSDKHttpError(code: .tokenRefreshFailed, message: "Invalid response from token refresh")))
                return
            }

            // Always dump the raw response body so we can debug decode issues
            let rawBody = String(data: data, encoding: .utf8) ?? "(could not decode body as UTF-8)"
            NSLog("FanMaker ######################################################################## Refresh response HTTP \(httpResponse.statusCode)")
            NSLog("FanMaker ######################################################################## Refresh response body: \(rawBody)")

            guard httpResponse.statusCode == 200 else {
                var errorMessage = "Token refresh failed with HTTP \(httpResponse.statusCode)"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let doorkeeperError = json["error"] as? String {
                    errorMessage += ": \(doorkeeperError)"
                    if let description = json["error_description"] as? String {
                        errorMessage += " - \(description)"
                    }
                }
                NSLog("FanMaker ######################################################################## Refresh ERROR: \(errorMessage)")
                completion(.failure(FanMakerSDKHttpError(code: .tokenRefreshFailed, message: errorMessage)))
                return
            }

            do {
                let newToken = try JSONDecoder().decode(FanMakerSDKOAuthToken.self, from: data)
                NSLog("FanMaker ######################################################################## Refresh SUCCESS - new token expires_at: \(newToken.expires_at)")
                completion(.success(newToken))
            } catch {
                NSLog("FanMaker ######################################################################## Refresh ERROR (decode): \(error.localizedDescription)")
                NSLog("FanMaker ######################################################################## Refresh ERROR (decode detail): \(error)")
                completion(.failure(FanMakerSDKHttpError(code: .tokenRefreshFailed, message: "Failed to decode refreshed token: \(error.localizedDescription)")))
            }
        }.resume()
    }

    // MARK: - High-Level Token Resolution

    /// Resolves the token type, checks expiration for OAuth tokens, refreshes if needed,
    /// and returns a valid token type ready to use for headers.
    ///
    /// - Parameters:
    ///   - tokenString: The raw token string from UserDefaults
    ///   - apiBase: The base URL for the API (e.g., "http://api3.fanmaker.work:3002")
    ///   - onRefreshed: Called with the new JSON string when a token is refreshed,
    ///                  so the caller can persist it back to storage
    ///   - completion: Called with the valid token type or an error
    public static func getValidToken(
        tokenString: String,
        apiBase: String,
        onRefreshed: @escaping (String) -> Void,
        completion: @escaping (Result<FanMakerSDKTokenType, FanMakerSDKHttpError>) -> Void
    ) {
        let tokenType = resolve(tokenString)

        switch tokenType {
        case .apiToken:
            completion(.success(tokenType))

        case .oauthToken(let oauthToken):
            if !isExpired(oauthToken) {
                completion(.success(tokenType))
            } else {
                // Token is expired -- enqueue refresh (coalesced with other callers)
                enqueueRefresh(oauthToken, apiBase: apiBase) { result in
                    switch result {
                    case .success(let newToken):
                        // Notify caller so they can persist the new token
                        if let newJsonString = newToken.toJSONString() {
                            onRefreshed(newJsonString)
                        }
                        completion(.success(.oauthToken(newToken)))

                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }
}
