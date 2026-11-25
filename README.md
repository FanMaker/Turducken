# Fanmaker Swift SDK for iOS App Development

## About

The Fanmaker Swift SDK lets an iOS app show the Fanmaker UI inside the app. One call,
`sdk.present()`, puts it on screen as a sheet and takes it down again. If your app needs to
place the UI itself, you can still show the view controller in a navigation stack, a modal
or a subview.

## What's New in 4.1.0

4.1.0 is a drop-in upgrade from 4.0.x. No public API was removed or renamed, and an
existing integration builds without changes.

### Upgrading from 4.0.x

Do these when you upgrade:

1. **Call `logout()` when a fan signs out of your app.** Identifiers you set
   (`setMemberID`, `setFanMakerIdentifiers` and the rest) are now saved on the device and
   restored after a relaunch while the fan still has a Fanmaker session. The first
   identifier you set in a launch replaces the restored ones, so a new fan never carries
   the last fan's IDs (a push token doesn't count). `logout()` also clears the SDK web
   view's cookies and stored website data, and leaves your own web views alone. See
   [Signing a Fan Out](#signing-a-fan-out).
2. **Closing is unchanged unless you switch to `present()`.** When the Fanmaker UI asks to
   close and you have not set `onClose`, the SDK closes a screen that `present()` put up.
   A screen you present, push or embed yourself is still yours to close, from `onClose` or
   a `FanMakerSDK.closeSdk` observer, as in 4.0.

   See [Handling SDK Close Actions](#handling-sdk-close-actions).

We recommend:

3. **Open the Fanmaker UI with `sdk.present()`.** The SDK presents its own screen as a
   full-height sheet and closes it again. Presenting `FanMakerSDKWebViewController`
   yourself still works. See [Displaying Fanmaker UI](#displaying-fanmaker-ui).
4. **Pass push destinations to `handleUrl(_:)` as they arrive.** It now accepts `https://`
   links to your program's sites, and the new `openPath(_:)` takes a bare path. See
   [Deep Linking / Universal Links](#deep-linking--universal-links).

Changes you may notice:

- A link on a Fanmaker page that leads outside your program's sites now opens in the system
  browser instead of inside the SDK. See
  [Links and Sign-ins Inside the SDK](#links-and-sign-ins-inside-the-sdk).
- The requests that load the Fanmaker UI now include your app's display name, version and
  bundle identifier, and the device's iOS version and model.
- On iOS 17 and later the Fanmaker UI keeps its cookies and site data apart from your app's
  own web views, so a fan may need to sign in to the Fanmaker UI once after the update.

Works better, with no change from you:

- Sign-ins that can't run in a webview, such as Ticketmaster's passkey sign-in, now run in
  a system sign-in sheet without the fan leaving your app.
- Deep links keep their query string.
- A deep link into an already open Fanmaker UI keeps the fan signed in.
- A fan who is already inside a beacon region when scanning starts is now counted.
- Beacon ranging continues when a request to Fanmaker fails, and every stage is logged.
  See [Checking your beacon setup](#checking-your-beacon-setup).
- Fixed a rare crash, or a missed beacon region entry, when the region list was refreshed.
- When location is turned off or unavailable, the Fanmaker UI is told at once instead of
  waiting.

## Successful Implementation Checklist

Please follow this checklist to ensure the Fanmaker SDK is implemented correctly.
The items below are **required for certification**.

- [ ] **Fanmaker opens in a full-height sheet or full-screen modal**
  - [`sdk.present()`](#displaying-fanmaker-ui) does this for you, and is the recommended way
  - If you [present it yourself](#presenting-it-yourself-legacy), use a full-height sheet
    or a full-screen modal
- [ ] **No primary app UI visible**
  - No wrapper, header, or logos from the primary app present
    (Client branding is displayed prominently *inside* the SDK)
  - No primary app navigation visible when opening the Fanmaker SDK to avoid confusion or menu stacking
- [ ] **Exit behavior implemented**
  - Handled for you by `sdk.present()`: iOS supplies the swipe-down, and the SDK closes
    itself on the close action
  - If you present it yourself: swipe-down gesture for sheets **or**
    [close action handled](#handling-sdk-close-actions)
- [ ] **Background GPS permissions**
  - [Implemented](#location-tracking)
  - Functioning as expected
- [ ] **Background Bluetooth permissions**
  - [Implemented](#beacons-tracking)
  - Functioning as expected
- [ ] **Push notification token**
  - Token for each user is passed to Fanmaker
  - [Implemented](#passing-a-push-notification-token)
- [ ] **Deep link handling**
  - [Implemented](#deep-linking--universal-links)
  - Functioning as expected
- [ ] **Sign-out handled** *(required only if your app has its own sign-in)*
  - [`logout()`](#signing-a-fan-out) called whenever a fan signs out of your app
  - The next fan's identifiers set only after they sign in

Additional features, such as [logged-in user handling](#passing-identifiers) and
[privacy permissions](#privacy-permissions-optional), are optional.

The checklist above represents the **minimum required for a certified integration**.

## Usage

First add the Fanmaker SDK to your project as a Swift Package, using
`https://github.com/FanMaker/Turducken`:

![xcode1](https://user-images.githubusercontent.com/298020/120363801-2f743e00-c2d2-11eb-89fb-3fd273072d16.png)

![xcode2](https://user-images.githubusercontent.com/298020/120363926-4c107600-c2d2-11eb-8374-0b7e9cfc21a4.png)

### Sample App
A sample iOS app using the SDK is available at https://github.com/FanMaker/TurduckenSampleApp.

### Initialization

To initialize the SDK, pass your `<SDK_KEY>` to the Fanmaker SDK initializer. Do this in
your `AppDelegate`, in `application(_:didFinishLaunchingWithOptions:)`. The setup differs
slightly depending on which app life cycle you use.

#### For UIKit

If you use `UIKit`, you already have an `AppDelegate` class in `AppDelegate.swift`. Add the
Fanmaker SDK initialization to it:

```swift
import UIKit
import FanMaker

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var fanmakerSDK1: FanMakerSDK!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Your existing launch code

        // Fanmaker SDK initialization code
        let fanmakerSDK1 = FanMakerSDK()
        fanmakerSDK1.initialize(apiKey: "<SDK_KEY>")
        AppDelegate.fanmakerSDK1 = fanmakerSDK1

        return true
    }

    // Your existing UISceneSession lifecycle methods
}
```

#### For SwiftUI

With the `SwiftUI` life cycle, no `AppDelegate` class is created for you, so create one:

```swift
// AppDelegate.swift

import SwiftUI
import FanMaker

class AppDelegate: NSObject, UIApplicationDelegate {

    static var fanmakerSDK1: FanMakerSDK!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let fanmakerSDK1 = FanMakerSDK()
        fanmakerSDK1.initialize(apiKey: "<SDK_KEY>")
        AppDelegate.fanmakerSDK1 = fanmakerSDK1

        return true
    }
}
```

and then add the `AppDelegate` class to your `@main` file:

```swift
// MyApp.swift

import SwiftUI

@main
struct MyApp: App {
    // Include your AppDelegate class here
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Displaying Fanmaker UI

```swift
AppDelegate.fanmakerSDK1.present()
```

The SDK finds the topmost view controller, presents the Fanmaker UI as a full-height sheet,
and closes it again when the fan is done. You don't build a view controller, keep an
`isShowing` flag in sync, or wire up dismissal.

#### Presentation options

| Style | What the fan gets | When to use it |
| --- | --- | --- |
| `.sheet` **(default)** | Full-height sheet with a grabber. iOS supplies swipe-to-dismiss. | Almost always. The fan always has a way out, whatever the content does. |
| `.fullScreen` | Edge to edge. The only way out is a close control drawn by the content itself. | Only where you know the content draws one, and never for a flow that can land on the login page. |

**Why `.sheet` is the default.** **Fanmaker's login page does not draw a close button.** A
fan who opens the UI full screen and decides not to sign in has no way out. A sheet gives
them one: iOS supplies the grabber and the swipe-down. The sheet uses a single full-height
detent, so the content still gets almost the whole screen.

**Choosing a style.** Pass one to the call, or set a default on the instance:

```swift
// Per call: wins over the instance setting
AppDelegate.fanmakerSDK1.present(style: .fullScreen)

// Per instance: used by every present() that doesn't pass a style
AppDelegate.fanmakerSDK1.presentationStyle = .fullScreen
AppDelegate.fanmakerSDK1.present()
```

The style passed to the call wins, then `presentationStyle` on the instance, then `.sheet`.

On iOS 13 and 14 there are no sheet detents, so `.sheet` presents as a standard `.pageSheet`
card. It can still be swiped away.

#### Closing

The SDK closes its own screen:

- When the Fanmaker UI asks to close, the SDK closes the sheet and posts
  `FanMakerSDK.closeSdk`.
- When the fan swipes the sheet away, the SDK posts `FanMakerSDK.closeSdk` with
  `params: ["source": "swipe"]` so you can still react. `onClose` is not called for a swipe.
- If you set `onClose`, or register an `onAction("close")` handler, the SDK calls it instead
  of closing the screen, and closing is up to you. See
  [Handling SDK Close Actions](#handling-sdk-close-actions).

#### More presentation calls

- **`present(from:)`** presents from a view controller you name instead of the topmost one,
  for an app with several scenes or one that wants the UI to come from a specific place in
  its hierarchy. It takes the same `style:`, `animated:` and `completion:` arguments as
  `present()`.
- **`dismiss(animated:)`** closes a screen that `present()` put up, from your own code.
- **`isPresenting`** is `true` while this instance has a screen on display.

`present()` and `present(from:)` return `false` and show nothing when `initialize(apiKey:)`
has not been called, when there is no visible view controller to present from (`present()`
only), or when this
instance already has a screen up. A second `present()` is refused rather than stacking a
copy the fan then has to dismiss twice. You can ignore the return value.

```swift
import UIKit
import FanMaker

class MyViewController: UIViewController {
    func showFanmaker() {
        AppDelegate.fanmakerSDK1.present(from: self, style: .sheet, animated: true) {
            print("Fanmaker UI is on screen")
        }
    }

    func hideFanmaker() {
        if AppDelegate.fanmakerSDK1.isPresenting {
            AppDelegate.fanmakerSDK1.dismiss(animated: true)
        }
    }
}
```

### Presenting it yourself (legacy)

> **Still supported, but no longer recommended.** New integrations should use
> `sdk.present()`. Presenting the view controller yourself means handling presentation,
> closing and dismissal in your own code. We expect to deprecate this path in a future
> release, and will not remove it without notice and a migration path.

Create a `FanMakerSDKWebViewController` (a `UIViewController` subclass) and present it as you
see fit:

- **UIKit apps**: create `FanMakerSDKWebViewController(sdk:)` and present it with UIKit's
  `present(_:animated:)`.
- **SwiftUI apps**: use `FanMakerSDKWebViewControllerRepresentable`, which conforms to
  `UIViewControllerRepresentable`, inside `.sheet` or `.fullScreenCover`.

> :warning: Do **not** wrap `FanMakerSDKWebViewControllerRepresentable` in a
> `UIHostingController` to present it from a UIKit app. In that setup the controller may
> never load, and a queued deep link is never used. UIKit apps should create
> `FanMakerSDKWebViewController` directly, or use `sdk.present()`.

#### UIKit

```swift
import UIKit
import FanMaker

class MyViewController: UIViewController {
    @objc func showFanMakerUI() {
        let fanMakerUI = FanMakerSDKWebViewController(sdk: AppDelegate.fanmakerSDK1)
        present(fanMakerUI, animated: true)
    }
}
```

#### SwiftUI

```swift
import SwiftUI
import FanMaker

struct ContentView : View {
    @State private var isShowingFanMakerUI : Bool = false

    var body : some View {
        Button("Show Fanmaker UI") {
            // Close the sheet through the binding, so SwiftUI knows it is gone
            AppDelegate.fanmakerSDK1.onClose = { _ in isShowingFanMakerUI = false }
            isShowingFanMakerUI = true
        }
        .sheet(isPresented: $isShowingFanMakerUI) {
            FanMakerSDKWebViewControllerRepresentable(sdk: AppDelegate.fanmakerSDK1)
        }
    }
}
```

A screen you present, push or embed yourself is yours to close: the SDK only closes a
screen that `present()` put up. With SwiftUI's `.sheet(isPresented:)`, set `onClose` as in
the sample above to reset your binding.

### Handling SDK Close Actions

> **Optional with `present()`.** The SDK closes a screen that `present()` put up, so you
> don't need to handle the close action to give a fan a way out. Set `onClose` only to run
> your own logic on close. Once it is set, the SDK leaves closing to you. A screen you show
> yourself always needs `onClose` or a `FanMakerSDK.closeSdk` observer to close.

When the Fanmaker UI asks to close, the SDK uses the first of these that applies:

1. A handler you registered with `onAction("close")` (see
   [Handling Arbitrary Actions](#handling-arbitrary-actions)).
2. `onClose`, if set.
3. Otherwise, it closes its own screen, if `present()` put it up.

Whichever one runs, the SDK then posts `FanMakerSDK.closeSdk`.

#### Option 1: Closure-Based Callback (Single Listener)

For a single handler, set the `onClose` closure property:

```swift
AppDelegate.fanmakerSDK1.onClose = { params in
    print("Fanmaker closed with params: \(params)")
    // With onClose set, the SDK leaves closing to you
    AppDelegate.fanmakerSDK1.dismiss()
}

AppDelegate.fanmakerSDK1.present()
```

`onClose` is not called when the fan swipes the sheet away. Use the notification below to
hear about both.

#### Option 2: NotificationCenter (Multiple Listeners)

When several parts of your app need to react to the SDK closing, observe the notification:

```swift
import Foundation
import FanMaker

class MyViewModel {
    private var closeObserver: NSObjectProtocol?

    init() {
        closeObserver = NotificationCenter.default.addObserver(
            forName: FanMakerSDK.closeSdk,
            object: AppDelegate.fanmakerSDK1,
            queue: .main
        ) { notification in
            if let params = notification.userInfo?["params"] as? [String: Any] {
                print("Fanmaker closed with params: \(params)")
            }
        }
    }

    deinit {
        if let closeObserver = closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
    }
}
```

**Note**: `params` contains any parameters the Fanmaker UI passed with the close action.
When the fan swiped a sheet opened with `present()` away, it is `["source": "swipe"]`.

### Handling Arbitrary Actions

The Fanmaker UI can send named actions to your app, so Fanmaker can trigger behavior in your
app without an SDK update.

#### Option 1: Closure-Based Callback (Single Listener)

Register a handler for an action with `onAction(_:handler:)`, for example right after
`initialize(apiKey:)`:

```swift
AppDelegate.fanmakerSDK1.onAction("reload") { params in
    print("Received reload action with params: \(params)")
    if let force = params["force"] as? Bool, force {
        // Reload your app's state
    }
}

AppDelegate.fanmakerSDK1.onAction("updateTheme") { params in
    if let theme = params["theme"] as? String {
        print("Switch the app theme to \(theme)")
    }
}
```

Registering a handler for an action replaces any earlier handler for that action. A handler
for `close` replaces the SDK's own close handling, the same way `onClose` does.

#### Option 2: NotificationCenter (Multiple Listeners)

Observe an action's notification when several parts of your app need to respond:

```swift
import Foundation
import FanMaker

class MyViewModel {
    private var reloadObserver: NSObjectProtocol?

    init() {
        reloadObserver = NotificationCenter.default.addObserver(
            forName: FanMakerSDK.actionNotificationName("reload"),
            object: AppDelegate.fanmakerSDK1,
            queue: .main
        ) { notification in
            guard let params = notification.userInfo?["params"] as? [String: Any],
                  let action = notification.userInfo?["action"] as? String else {
                return
            }
            print("Received \(action) action with params: \(params)")
        }
    }

    deinit {
        if let reloadObserver = reloadObserver {
            NotificationCenter.default.removeObserver(reloadObserver)
        }
    }
}
```

#### Option 3: SwiftUI View with `.onReceive()` Modifier

In a SwiftUI view, you can listen for actions with the `.onReceive()` modifier:

```swift
import SwiftUI
import FanMaker

struct ContentView : View {
    var body : some View {
        VStack {
            // Your view content
        }
        .onReceive(NotificationCenter.default.publisher(for: FanMakerSDK.actionNotificationName("customAction"), object: AppDelegate.fanmakerSDK1)) { notification in
            // Access the action name
            if let action = notification.userInfo?["action"] as? String {
                print("Action triggered: \(action)")  // Prints: "Action triggered: customAction"
            }

            // Access the parameters
            if let params = notification.userInfo?["params"] as? [String: Any] {
                print("Parameters: \(params)")  // Prints: ["success": true, ...]

                // Use specific parameters
                if let success = params["success"] as? Bool {
                    print("Success: \(success)")
                }
            }
        }
    }
}
```

#### Removing Action Handlers

To remove a registered handler:

```swift
// Remove handler for a specific action
AppDelegate.fanmakerSDK1.removeActionHandler("reload")
```

#### How Actions Work

The SDK will:
1. Check for a handler registered with `onAction(_:handler:)`
2. Call the handler if one exists
3. Post a notification with the action name (e.g., `FanMakerSDKAction_reload`)
4. Include both `params` and `action` in the notification's `userInfo`

**Note**: `params` contains any parameters the Fanmaker UI passed with the action. Actions
are handled dynamically, so Fanmaker can add new actions without an SDK update.

### Personalization Options

While the Fanmaker UI loads, the SDK shows a loading screen with a system spinner. You can
replace the spinner with your own image or animation. Call this before presenting the
Fanmaker UI; right after `initialize(apiKey:)` is a good place:

```swift
AppDelegate.fanmakerSDK1.setLoadingForegroundImage(UIImage(named: "<YOUR IMAGE NAME>")!)
```

`setLoadingForegroundImage(_:)` takes a static or an animated `UIImage`.

The Sample App has a working example commented out in the `RegionList.swift` file. The
steps below help you build a custom loading animation.

**Note**: Your images should be **square**. Otherwise the SDK forces them into a square,
which can distort your animation.

Break your gif into a PNG sequence, one still image for each frame of the animation, and
import all the PNGs into the `Assets.xcassets` catalog of your iOS app.

<img width="1160" alt="Screenshot 2023-10-12 at 4 51 37 PM" src="https://github.com/FanMaker/Turducken/assets/3985921/e121b16e-63f2-4a40-9109-eefd3aa83dab">

Then build the animation from the PNGs:

```swift
var images: [UIImage] = []

// Number your images <YOUR IMAGE NAME>-0, <YOUR IMAGE NAME>-1, and so on.
// Start at 0 and end at the number of images you have.
for index in 0...89 {
    if let image = UIImage(named: "<YOUR IMAGE NAME>-\(index)") {
        images.append(image)
    }
}

// Adjust the duration to speed up or slow down your animation
if let animation = UIImage.animatedImage(with: images, duration: 1.0) {
    AppDelegate.fanmakerSDK1.setLoadingForegroundImage(animation)
}
```

### Links and Sign-ins Inside the SDK

The SDK decides which links stay inside its webview and which open in the system browser.
Nothing is required from your app.

**Links to other sites.** When a fan taps a link on a Fanmaker page that leads outside your
program's sites, the SDK opens it in the system browser. Partner and ticketing pages need
their own browser controls and the fan's existing sessions, and have no way back when
loaded inside the SDK.

Only a tap, or a request for a new window, that replaces the whole Fanmaker page is sent
out. Redirects, form posts and taps inside embedded frames stay in the webview. So do taps
on a sign-in or payment provider's own pages, so those flows can finish and come back.
Fanmaker's own hosts always stay in the webview. Until the SDK has learned your program's
sites (the first time the Fanmaker UI loads on the device), nothing is sent out.

`isExternalWebURL(_:)` is public if you want the same answer for a URL of your own.

**Sign-ins that can't run in a webview.** Some sign-ins don't work in an embedded webview:
Ticketmaster's passkeys only work on ticketmaster.com, and some identity providers refuse
embedded webviews. For these, the Fanmaker page asks the SDK to run the sign-in in an
`ASWebAuthenticationSession` sheet. The sheet uses a private browser session, so it neither
uses nor changes the fan's own Safari sign-ins. Passkeys work there, and when the sign-in
finishes the fan is back in the Fanmaker UI.

SeatGeek sign-ins are the exception: they use the shared Safari session, so a fan your app
already signed in to SeatGeek through the system browser is signed in to Fanmaker with that
same account, without signing in again. iOS asks the fan once to allow the sign-in. Only Fanmaker's own pages can start one. Your
app needs no change and registers nothing for this.

### Deep Linking / Universal Links

To open a specific place in the Fanmaker UI from a link, a push notification or your own
code, hand the destination to the SDK and then present it.

#### Accepting links in your app

To receive links, set up your app to accept a URL scheme or universal links. An example of
using a URL scheme to open app links:

<img width="1424" alt="Screenshot 2024-05-23 at 3 42 02 PM" src="https://github.com/FanMaker/Turducken/assets/3985921/071cecb0-7c32-4f5e-b2f5-669be6c62249">

In Xcode, open your project's Info tab, scroll down to URL Types and press the (+) button.
Add your app's bundle identifier (from the Signing & Capabilities tab) and the URL schemes
you want to use. No other setting is needed.

With the example above, your app opens for links like `turducken://open`.

Then pass incoming URLs to the SDK, for example with `.onOpenURL`:

```swift
import SwiftUI
import FanMaker

struct ContentView : View {
    var body : some View {
        Text("My App")
            .onOpenURL { url in
                if AppDelegate.fanmakerSDK1.handleUrl(url) {
                    AppDelegate.fanmakerSDK1.present()
                }
                // false: not a Fanmaker link, so handle it as your app normally would
            }
    }
}
```

In UIKit, do the same wherever your app receives URLs, such as
`scene(_:openURLContexts:)`. For a push notification, pass the destination URL from its
payload the same way.

#### Which links the SDK accepts

`handleUrl(_:)` returns `true` and takes the destination when the URL is one of:

- **Any scheme with the host `fanmaker`** (case-insensitive), for example
  `turducken://fanmaker/store/items/1234`. Everything after the host is the destination.
- **An `https://` link to a site Fanmaker has set up for your program**, such as a link in a
  push notification. The SDK learns these sites from Fanmaker the first time the Fanmaker
  UI loads on the device, and remembers them across launches. Until then, `handleUrl(_:)`
  returns `false` for `https://` links; use the `fanmaker` form or `openPath(_:)`.

The query string is kept: `turducken://fanmaker/store?utm_source=push` opens
`/store?utm_source=push`. Any other URL returns `false`. `canHandleUrl(_:)` answers the same
question without taking the destination; you don't need to call it before `handleUrl(_:)`.

If the Fanmaker UI is on screen, `handleUrl(_:)` navigates it straight away. Otherwise the
destination is used the next time the Fanmaker UI opens, once. If several links arrive
before it opens, only the latest is used.

Fanmaker can help you format links to sections of the Fanmaker UI.

#### Opening a path directly

When you already know a destination belongs to Fanmaker, for example a push payload that
carries a bare path, use `openPath(_:)`. It needs no URL scheme or host:

```swift
if AppDelegate.fanmakerSDK1.openPath("/store/items/1234") {
    AppDelegate.fanmakerSDK1.present()
}
```

`openPath(_:)` queues the path for the next time the Fanmaker UI opens; it does not
navigate a Fanmaker screen that is already up. It returns `false` for an empty string or
for anything with a scheme or host. Pass full URLs to `handleUrl(_:)`.

#### Multiple `FanMakerSDK` instances

If your app initializes more than one instance of the Fanmaker SDK, decide which instance a
URL belongs to, for example by its scheme:

```swift
import SwiftUI
import FanMaker

struct ContentView : View {
    var body : some View {
        Text("My App")
            .onOpenURL { url in
                let sdk: FanMakerSDK = url.scheme == "turducken2" ? AppDelegate.fanmakerSDK2 : AppDelegate.fanmakerSDK1
                if sdk.handleUrl(url) {
                    sdk.present()
                }
            }
    }
}
```

### Passing Identifiers

The Fanmaker UI normally asks fans to sign in with their Fanmaker credentials. If your app
already knows who the fan is, pass up to four identifiers so the fan is signed in
automatically when the Fanmaker UI opens. Set them before calling `present()`:

```swift
// Which identifiers are available depends on your Fanmaker program.
AppDelegate.fanmakerSDK1.setMemberID("<memberid>")
AppDelegate.fanmakerSDK1.setStudentID("<studentid>")
AppDelegate.fanmakerSDK1.setTicketmasterID("<ticketmasterid>")
AppDelegate.fanmakerSDK1.setYinzid("<yinzid>")

AppDelegate.fanmakerSDK1.present()
```

Identifiers are saved on the device and sent each time the Fanmaker UI opens, including
after your app is relaunched, so you only need to set them again when they change. When the
fan signs out of your app, call [`logout()`](#signing-a-fan-out).

**Note**: When a fan signs in through the Fanmaker UI, these identifiers and the fan's
Fanmaker user ID are filled in automatically, and you can read them from these properties:

```swift
let userID = AppDelegate.fanmakerSDK1.userID
let memberID = AppDelegate.fanmakerSDK1.memberID
let studentID = AppDelegate.fanmakerSDK1.studentID
let ticketmasterID = AppDelegate.fanmakerSDK1.ticketmasterID
let yinzid = AppDelegate.fanmakerSDK1.yinzid
```

### Passing a Push Notification Token
You can also pass the fan's push notification token, so Fanmaker can send push
notifications to users of your app.

Once you have a valid push notification token from APNs, pass it to the Fanmaker SDK. Like
identifiers, it is saved on the device and sent each time the Fanmaker UI opens.

```swift
AppDelegate.fanmakerSDK1.setPushNotificationToken("<pushToken>")
```

### Passing Custom Identifiers
You can also pass arbitrary identifiers as a dictionary. Set them the same way, and at the
same time, as the identifiers above.

```swift
let arbitraryIdentifiers: [String: Any] = [
    "nfl_oidc": "1234-nfl-oidc"
]

_ = AppDelegate.fanmakerSDK1.setFanMakerIdentifiers(dictionary: arbitraryIdentifiers)
```

New keys are merged into the ones already set, and saved on the device like the other
identifiers. Use strings, numbers or booleans as values; other value types are not restored
after a relaunch.

### Privacy Permissions (Optional)
You can pass a fan's privacy settings to the Fanmaker SDK, and Fanmaker records them for the
fan. Pass them the same way as Custom Identifiers above, with these keys:

1. `privacy_advertising`
2. `privacy_analytics`
3. `privacy_functional`
4. `privacy_all`

`true` means the fan has opted in to that permission, and `false` means they have opted
out.

*NOTE: all privacy permissions are optional. Do not pass privacy settings that you do not have user data for.*

```swift
let arbitraryIdentifiers: [String: Any] = [
    // An example of a custom identifier you may pass
    "nfl_oidc": "1234-nfl-oidc",

    // The opt in/out settings
    "privacy_advertising": false,
    "privacy_analytics": true,
    "privacy_functional": true,
    "privacy_all": false
]

_ = AppDelegate.fanmakerSDK1.setFanMakerIdentifiers(dictionary: arbitraryIdentifiers)
```

### Passing Custom Parameters
Like custom identifiers, you can pass custom parameters to the SDK. Here is how, with some
of the options:

```swift
let customParameters: [String: Any] = [
    "hide_menu": true, // hides the menu in the SDK; pass false to show it again
    "viewport_width": 512, // tells Fanmaker how wide the viewing area is
    "viewport_height": 1024 // tells Fanmaker how tall the viewing area is
]

_ = AppDelegate.fanmakerSDK1.fanMakerParameters(dictionary: customParameters)
```

Unlike identifiers, parameters are not saved on the device. Set them again after each
launch.

### Signing a Fan Out

When a fan signs out of your app, call `logout()`:

```swift
AppDelegate.fanmakerSDK1.logout()
```

**When to call it:** every time a fan signs out of your app, including when one fan signs
out so another can sign in on the same device. Identifiers and the Fanmaker session survive
app restarts, so without `logout()` the next person to open the Fanmaker UI on that device
is signed in as the previous fan.

**When you don't need to:** when a fan logs out *inside* the Fanmaker UI, the SDK ends the
Fanmaker session itself.

**Switching fans:** call `logout()` when the first fan signs out, and set the next fan's
identifiers only once they have signed in to your app. Don't rely on new identifiers
replacing the old fan on their own: if the new fan has no Fanmaker account yet, the previous
fan's session would still be there.

`logout()` clears, in memory and on the device, every identifier (including custom
identifiers and the push notification token) and the fan's Fanmaker session token. It also
clears the cookies and stored website data of the SDK's web view, so neither Fanmaker's pages
nor a sign-in provider such as Ticketmaster can sign the next person in as the previous fan. It
does not close a Fanmaker screen that is on display, and does not clear custom parameters.

On iOS 17 and later the SDK's web view keeps its website data in a store of its own, so
`logout()` never touches your app's own web views. Before iOS 17 every `WKWebView` in an app
shares one store, so `logout()` clears only the data for Fanmaker's own sites there. To act
once everything is cleared, pass a completion, which runs on the main thread:

```swift
AppDelegate.fanmakerSDK1.logout {
    // the Fanmaker session and all web data are gone
}
```

Use `logout()` for sign-out, not `clearIdentifiers()`. The session, not the identifiers, is
what keeps a fan signed in to Fanmaker, so clearing only the identifiers leaves the next
person to open the Fanmaker UI signed in as the previous fan. Two narrower calls are
available:

- `clearIdentifiers()` clears the identifiers and keeps the session.
- `clearSessionToken()` clears the session and keeps the identifiers, so the next open signs
  the same fan in again from them.

### Location Tracking

The Fanmaker UI asks for the fan's permission to use their location the first time it
loads. Location tracking is on by default in the Fanmaker SDK, for features like Auto
Checkin. To turn it off, or back on:

```swift
// To turn location tracking off
AppDelegate.fanmakerSDK1.disableLocationTracking()

// To turn location tracking back on
AppDelegate.fanmakerSDK1.enableLocationTracking()
```

The setting is not saved, and `initialize(apiKey:)` turns tracking back on. To keep it off,
call `disableLocationTracking()` after `initialize(apiKey:)` on every launch. It does not
affect beacon scanning; see [Beacons Tracking](#beacons-tracking).

### Auto Checkin
The Fanmaker SDK can check fans in to events without them opening the Fanmaker UI. Once a
fan has signed in through the Fanmaker UI and granted location permission, the SDK tries to
check them in to events in range each time your app launches or returns to the foreground.
Location tracking is on by default. If you turned it off with
`AppDelegate.fanmakerSDK1.disableLocationTracking()`, turn it back on with:

```swift
AppDelegate.fanmakerSDK1.enableLocationTracking()
```

### Beacons Tracking

The Fanmaker SDK tracks beacons through a `FanMakerSDKBeaconsManager` and a delegate that
implements `FanMakerSDKBeaconsManagerDelegate`. Any `NSObject` subclass can be the delegate,
such as a view controller or a view model.

The delegate is required: the region list only reaches your app through it, and your app
starts scanning from it. The sequence is:

1. Once the fan has signed in to Fanmaker, call `requestAuthorization()`.
2. When `didChangeAuthorization` reports `.authorizedAlways` or `.authorizedWhenInUse`, call
   `fetchBeaconRegions()`.
3. When `didReceiveBeaconRegions` delivers the regions, call `startScanning(_:)` with them.

```swift
import FanMaker

class FanMakerViewModel : NSObject, FanMakerSDKBeaconsManagerDelegate {
    private let beaconsManager1 : FanMakerSDKBeaconsManager

    override init() {
        beaconsManager1 = FanMakerSDKBeaconsManager(sdk: AppDelegate.fanmakerSDK1)

        super.init()
        beaconsManager1.delegate = self
    }

    // Call once the fan has signed in to Fanmaker
    func startBeacons() {
        beaconsManager1.requestAuthorization()
    }

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didChangeAuthorization status: FanMakerSDKBeaconsAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.fetchBeaconRegions()
        }
    }

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didReceiveBeaconRegions regions: [FanMakerSDKBeaconRegion]) {
        manager.startScanning(regions)
    }

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didEnterRegion region: FanMakerSDKBeaconRegion) {}
    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didExitRegion region: FanMakerSDKBeaconRegion) {}
    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didUpdateBeaconRangeActionsHistory queue: [FanMakerSDKBeaconRangeAction]) {}
    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didUpdateBeaconRangeActionsSendList queue: [FanMakerSDKBeaconRangeAction]) {}
    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didFailWithError error: FanMakerSDKBeaconsError) {}
}
```

Keep a strong reference to both the beacons manager and your delegate for as long as you
want to track beacons. The manager holds its delegate weakly.

`FanMakerSDKBeaconsManagerDelegate` requires the following functions:

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didChangeAuthorization status: FanMakerSDKBeaconsAuthorizationStatus) -> Void
```
Reports your app's current `FanMakerSDKBeaconsAuthorizationStatus`. The possible values are:
```
.notDetermined
.restricted
.denied
.authorizedAlways
.authorizedWhenInUse
```
Calling `beaconsManager1.requestAuthorization()` asks the fan for location permission when
needed, and this function is called when the fan grants or denies it.

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didReceiveBeaconRegions regions: [FanMakerSDKBeaconRegion]) -> Void
```
Called with your program's beacon regions after you call `beaconsManager1.fetchBeaconRegions()`.
Call `manager.startScanning(regions)` here; tracking starts only then. Make sure you have
location permission before fetching, or scanning won't work.

**NOTE**: The fan must be signed in to the Fanmaker UI before you call
`fetchBeaconRegions()`. Otherwise `didFailWithError` is called with `.userSessionNotFound`.

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didEnterRegion region: FanMakerSDKBeaconRegion) -> Void
```
Called when the fan walks into a scanned beacon region, or is already inside one when
scanning starts, once Fanmaker has recorded the entry.

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didExitRegion region: FanMakerSDKBeaconRegion) -> Void
```
Called when the fan walks out of a scanned beacon region, once Fanmaker has recorded the
exit.

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didUpdateBeaconRangeActionsHistory queue: [FanMakerSDKBeaconRangeAction]) -> Void
```
Called when the fan gets a valid beacon signal, which happens about once per minute while
the fan stays in a beacon's range. Fanmaker sets the interval for your program.

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didUpdateBeaconRangeActionsSendList queue: [FanMakerSDKBeaconRangeAction]) -> Void
```
Called when valid beacon signals could not be sent to Fanmaker, for example because of a
weak connection or a temporary server error. The SDK retries every minute. Once they are
sent, the queue is emptied and this function is called with an empty array.

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didFailWithError error: FanMakerSDKBeaconsError) -> Void
```
Called when something goes wrong. The possible `FanMakerSDKBeaconsError` values are:
```
.userSessionNotFound
.serverError
.unknown
```

To stop monitoring beacon regions, call `beaconsManager1.stopScanning()`. Beacon scanning needs the fan's
location permission, which `requestAuthorization()` asks for. `disableLocationTracking()`
does not stop beacon scanning.

**Multiple `FanMakerSDK` instances**:
When you have more than one instance of the Fanmaker SDK initialized, you can scan for
beacons with one, the other, or all of them.

Create a beacons manager for each instance:

```swift
private let beaconsManager1 : FanMakerSDKBeaconsManager
private let beaconsManager2 : FanMakerSDKBeaconsManager

override init() {
    beaconsManager1 = FanMakerSDKBeaconsManager(sdk: AppDelegate.fanmakerSDK1)
    beaconsManager2 = FanMakerSDKBeaconsManager(sdk: AppDelegate.fanmakerSDK2)

    super.init()
    beaconsManager1.delegate = self
    beaconsManager2.delegate = self
}
```

Then request authorization with each of them:

```swift
beaconsManager1.requestAuthorization()
beaconsManager2.requestAuthorization()
```

The delegate functions pass the `manager` they come from, so `manager.fetchBeaconRegions()`
and `manager.startScanning(regions)` work for every instance.

#### Checking your beacon setup

Every stage of beacon tracking writes an `NSLog` line starting with `FanMaker (Beacons):`,
so you can check your setup from Xcode's console or `Console.app`. Filter on that prefix and
you should see, in order:

```
FanMaker (Beacons): Monitoring for beacon region UUID: E2C56DB5-… Major: 1
FanMaker (Beacons): Already inside FanMaker beacon region at scan start: e2c56db5-…::1
FanMaker (Beacons): ENTER region 12 'North Gate' (UUID: e2c56db5-… Major 1) via didDetermineState
FanMaker (Beacons): RANGING STARTED for region 12 'North Gate' (…). Beacon sightings will be logged as they arrive.
FanMaker (Beacons): RANGED beacon E2C56DB5-… major 1 minor 0 [rssi -72, proximity near, accuracy 1.4] - recording
FanMaker (Beacons): ENTER recorded for region 12 'North Gate'
FanMaker (Beacons): 1 beacon range actions successfully posted
```

A fan who walks into the region after scanning starts gets `via didEnterRegion` instead,
without the `Already inside` line.

The first missing line usually tells you where the problem is:

| You see | Meaning |
| --- | --- |
| No `Monitoring for beacon region` lines | `startScanning(_:)` was never called. Check that location permission was granted, that `fetchBeaconRegions()` ran after the fan signed in, and that your `didReceiveBeaconRegions` calls `manager.startScanning(regions)`. |
| `Monitoring…` but no `ENTER` | The device is not inside any configured region. Check the UUID and major against the regions set up for your program. |
| `ENTER` but no `RANGING STARTED` | The region has no major value, so the SDK can't range it. |
| `RANGING STARTED` but no `RANGED` | The device is listening and hearing nothing. Usually the beacon is off, out of range, or advertising a different UUID. |
| `RANGED … holding off until the 60s uniqueness throttle clears` | Working as intended. The beacon is being seen, and repeat sightings are held back for the interval Fanmaker set for your program. Each beacon logs its first sighting regardless, so you always get confirmation. |
| `RANGED … recording` but no `beacon range actions successfully posted` | Sightings are being captured but not reaching Fanmaker. Check connectivity and that the fan is still signed in. |

Once a region is entered, ranging runs whether or not the request to Fanmaker succeeds, and
stops when the region is exited.

### Recommended Info.plist Entries

Bluetooth (required for beacons)
```
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Enabling Bluetooth access will allow you to earn points when you come in contact with Bluetooth beacons that may be located at the location of an event you are attending. You may also receive exclusive offers and additional point earning opportunities based on your contact with Bluetooth beacons always</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>Enabling Bluetooth access will allow you to earn points when you come in contact with Bluetooth beacons that may be located at the location of an event you are attending. You may also receive exclusive offers and additional point earning opportunities based on your contact with Bluetooth beacons</string>
```

Location (required)
```
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>By sharing your location you can automatically earn points for checking in to certain events. You may also receive exclusive offers and additional point earning opportunities based on your location</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>By sharing your location you can automatically earn points for checking in to certain events. You may also receive exclusive offers and additional point earning opportunities based on your location or when you come in contact with Bluetooth beacons</string>

<key>NSLocationUsageDescription</key>
<string>By sharing your location you can earn points for checking in to certain events. You may also receive exclusive offers and additional point earning opportunities based on your location</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>By sharing your location you can earn points for checking in to certain events. You may also receive exclusive offers and additional point earning opportunities based on your location</string>
```

## :warning: BREAKING CHANGES IN 2.0 :warning:
Version 2.0 of the Fanmaker SDK changed from static to instance-based initialization. This
means that you will need to modify your implementation to avoid service interruptions in
this version. Previous versions of the SDK are no longer available for installation.
Support for SDK versions 1.x will be deprecated on December 20th, 2024; after that, versions
before 2.0 will cease to function.

The benefits of SDK 2.0 are [described in detail on our blog](https://blog.fanmaker.com/sdk-2-0-background-check-ins-app-rewards-and-support-for-multiple-programs/).

## Upgrading to 2.0 from 1.x

### Step 1:
Previously the Fanmaker SDK was initialized like this:
```
FanMakerSDK.initialize(apiKey: "<SDK_KEY>")
```

Now, with instance-based initialization, you need to keep track of the instance of the SDK:

```swift
let fanmakerSDK1 = FanMakerSDK()
fanmakerSDK1.initialize(apiKey: "<SDK_KEY_1>")
AppDelegate.fanmakerSDK1 = fanmakerSDK1
```

This way you can initialize multiple, independent instances of the Fanmaker SDK. Keeping
the instance on the `AppDelegate` makes it available throughout your app.


### Step 2:
When you prepare your sheet to present `FanMakerSDKWebViewControllerRepresentable`, you now
also need to pass the SDK instance you initialized in Step 1.
```
...
}.sheet(isPresented: $showFanMakerUI) {
    FanMakerSDKWebViewControllerRepresentable(sdk: AppDelegate.fanmakerSDK1)
}
```

### Step 3:
If you pass any values to the Fanmaker SDK using methods like `setMemberID`,
`setTicketmasterID`, or `setFanMakerIdentifiers`, specify which SDK instance you are passing
the values to:

```swift
AppDelegate.fanmakerSDK1.setMemberID("123456")
AppDelegate.fanmakerSDK1.setTicketmasterID("7890123")

let fanmakerIdentifiers1: [String: Any] = [
    "airship_channel_id": "7870978-airship-a0af9d780a9s7f07f"
]
_ = AppDelegate.fanmakerSDK1.setFanMakerIdentifiers(dictionary: fanmakerIdentifiers1)
```

### Step 4:
If you use Bluetooth beacons through the Fanmaker SDK, you need to update your
implementation.

Where you initialize the `FanMakerSDKBeaconsManager`, you now need to pass the instance of
the SDK you are using:
```
beaconsManager1 = FanMakerSDKBeaconsManager(sdk: AppDelegate.fanmakerSDK1)
```
Then set the delegate as normal:
```
beaconsManager1.delegate = self
```

You need to call `requestAuthorization()` for every instance of the SDK you plan to use
beacons with:
```
beaconsManager1.requestAuthorization()
```
