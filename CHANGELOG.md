### Unreleased
#### Added
- `FanMakerSDK.present(style:animated:completion:)`, `present(from:style:...)`, `dismiss()` and `isPresenting`. The SDK now puts its own screen on display and takes it down again, so a host no longer has to build, place or dismiss a view controller. Presents as a sheet by default, which matters: the login page draws no close control of its own, so a full-screen presentation leaves a fan who does not want to sign in with no way out. `.fullScreen` is available as an opt-in.
- `FanMakerSDK.logout()`, `clearSessionToken()` and `clearIdentifiers()`. There was previously no way to end a session; process death was the only reset.
- `prepareUIView(completion:)` and `loginUserFromParams(completion:)`, non-blocking counterparts of the existing calls.
- Beacon tracking now logs every stage - region entry and exit, ranging start and stop, and each beacon sighting with its rssi, proximity and accuracy - under the existing `FanMaker (Beacons): ` prefix. Every beacon announces its first sighting even when the uniqueness throttle suppresses the recording, so a 60s throttle no longer means a minute of silence while an integrator is trying to confirm their setup. The README documents the expected sequence and how to read the gaps in it.

#### Fixed
- Presenting the SDK no longer freezes the host app. Site details, auto-login and session-token resolution ran behind `DispatchSemaphore.wait()` in `viewDidLoad`, stalling the main thread for the duration - 350ms measured on a device against a healthy network, and unbounded when the site-details call did not answer, because that wait had no timeout. They now run off the main thread while the SDK's loading screen is up.
- Beacon ranging no longer depends on the network or on a delegate. `postRegionAction` started ranging only from the success branch of its request, nested inside `if let delegate = self.delegate`. A failed enter request meant a fan at the beacon was never ranged; a failed exit request meant ranging never stopped; and an integration that never assigned a delegate recorded nothing at all while appearing correctly configured. Ranging now starts on entry and stops on exit, before the request is issued.
- A fan already inside a beacon region when scanning starts is now counted. `startMonitoring` only reports boundary crossings, so the common case - a fan already at their seat opening the app - produced nothing until iOS re-evaluated region state on its own schedule. Observed as a ~2 minute delay on a live device, and unbounded in principle.
- Identifiers set by a host are now persisted and restored, not just the ones arriving from the web bridge.
- `fanmaker_identifiers` was decoded as `Data`, which `JSONDecoder` reads as base64, but the field is a nested object. It threw whenever present and a bare `catch` dropped every identifier in the payload, not just the arbitrary ones.
- The webview now answers the location-authorization request when authorization is missing, instead of leaving it to time out.

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
