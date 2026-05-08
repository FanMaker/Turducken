### 4.0.3 - 2026-05-07
#### Changed
- `FanMakerSDKWebViewController.init(sdk:)` is now `public`, allowing UIKit host apps to instantiate and present the controller directly without going through `FanMakerSDKWebViewControllerRepresentable`. SwiftUI hosts continue to use the Representable as before.

#### Fixed
- Deep-link paths now compose correctly when the configured base URL has a query string (e.g. UTM parameters). Previously a path like `/activity` was concatenated naively onto a base URL like `https://example.com/?utm_source=x`, producing a malformed URL where the path ended up appended to the query string. The SDK now uses `URLComponents` to parse the base URL and replace its path component, preserving query items.
- The deep-link live-navigation branch in `FanMakerSDK.handleUrl(_:)` no longer force-unwraps the composed `URL`; a malformed result skips the navigation instead of crashing.

### 1.1
- Fixes to beacons detection and pinging.
- Beacon Uniqueness throttling is now customizable via API.
- NOTE: `BeaconRangeActionsQueue` was divided into two queues: `BeaconRangeActionsHistory` and `BeaconRangeActionsSendList`.
- REMOVED: `didUpdateBeaconRangeActionsQueue` callback is no longer available.
- New `didUpdateBeaconRangeActionsHistory` and `didUpdateBeaconRangeActionsSendList` are now available.

### 1.0.1
SDK was sending the wrong SDK version to the servers
### 1.0
Introducing `FanMakerSDKBeaconsManager` and `FanMakerSDKBeaconsManagerDelegate` to handle FanMaker's Beacons tracking features.

### 0.1.7
Identifiers are now set on users login (via FanMakerSDK UI) and accessible via public variables.
