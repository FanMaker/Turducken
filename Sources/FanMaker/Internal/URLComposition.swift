//
//  URLComposition.swift
//
//  Helper for composing the FanMaker SDK web URL from a configured
//  base URL plus a deep-link path.
//
//  This exists because the SDK was originally composing the final
//  URL via naive string concatenation (`baseURL + path`). That breaks
//  whenever the configured base URL has a query string — for example
//  a site whose `sdk_configuration` URL is
//  `https://example.com/?utm_source=x` — because the deep-link path
//  ends up appended to the query string instead of becoming a real
//  path component, producing malformed URLs the WKWebView resolves
//  back to root.
//
//  Behavior intentionally mirrors the Android SDK's
//  `Uri.parse(baseUrl).buildUpon().appendEncodedPath(...)` call site,
//  with one simplification: when the configured base URL already has
//  a path component, the deep-link path REPLACES it. This matches
//  what callers actually want (deep links are absolute paths into the
//  SDK web app, not relative ones), and it removes the ambiguity of
//  whether to append or join slashes.
//

import Foundation

/// Compose a final URL from the SDK's configured base URL and a deep-link path,
/// preserving the base URL's query string and replacing its path component.
///
/// - Parameters:
///   - baseURL: The configured SDK base URL (may contain a query string,
///     e.g. UTM parameters).
///   - deepLinkPath: The path portion to navigate to, with or without a
///     leading slash. An empty string is allowed and yields the base URL
///     with its path cleared.
/// - Returns: The composed URL, or `nil` if the inputs cannot be parsed.
internal func fanMakerComposeURL(baseURL: String, deepLinkPath: String) -> URL? {
    guard var components = URLComponents(string: baseURL) else {
        // Fallback for inputs `URLComponents` rejects — preserves the
        // pre-fix behavior rather than swallowing the navigation.
        return URL(string: baseURL + deepLinkPath)
    }

    // Normalize the path so callers can pass "debug" or "/debug" and
    // get the same result. An empty path stays empty.
    let normalized: String
    if deepLinkPath.isEmpty {
        normalized = ""
    } else if deepLinkPath.hasPrefix("/") {
        normalized = deepLinkPath
    } else {
        normalized = "/" + deepLinkPath
    }

    // Replace (not append) the existing path component. Deep links are
    // absolute paths into the SDK web app; any path baked into the
    // configured base URL is incidental and should not affect routing.
    components.path = normalized

    return components.url
}
