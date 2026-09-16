# Fanmaker Swift SDK for iOS App Development

## About

The Fanmaker Swift SDK provides iOS developers with a way of inserting the Fanmaker UI in another app. The view can be displayed as part of a navigation stack, a modal or even a subview in an app's layout.

## Successful Implementation Checklist

Please follow this checklist to ensure the Fanmaker SDK is implemented correctly.
The items below are **required for certification**.

- [ ] **Fanmaker is opened with [`sdk.present()`](https://github.com/FanMaker/Turducken?tab=readme-ov-file#displaying-fanmaker-ui)**
  - This satisfies the display and exit items below on its own: the SDK presents a
    full-height sheet and closes itself
  - Presenting the view controller yourself is still supported, but is no longer the
    recommended integration — see [presenting it yourself](https://github.com/FanMaker/Turducken?tab=readme-ov-file#presenting-it-yourself-legacy)
- [ ] **No primary app UI visible**
  - No wrapper, header, or logos from the primary app present  
    (Client branding is displayed prominently *inside* the SDK)
  - No primary app navigation visible when opening the Fanmaker SDK to avoid confusion or menu stacking
- [ ] **Exit behavior implemented**
  - Handled for you by `sdk.present()` — iOS supplies the swipe-down, and the SDK
    closes itself on the close action
  - If you present it yourself: swipe-down gesture for sheets **or**
    [close action handled](https://github.com/FanMaker/Turducken?tab=readme-ov-file#handling-sdk-close-actions)
- [ ] **Background GPS permissions**
  - [Implemented](https://github.com/FanMaker/Turducken/tree/main?tab=readme-ov-file#location-tracking)
  - Functioning as expected
- [ ] **Background Bluetooth permissions**
  - [Implemented](https://github.com/FanMaker/Turducken/tree/main?tab=readme-ov-file#beacons-tracking)
  - Functioning as expected
- [ ] **Push notification token**
  - Token for each user is passed to Fanmaker
  - [Implemented](https://github.com/Fanmaker/Turducken/tree/main?tab=readme-ov-file#passing-a-push-notification-token)
- [ ] **Deep link handling**
  - [Implemented](https://github.com/Fanmaker/Turducken/tree/main?tab=readme-ov-file#deep-linking--universal-links)
  - Functioning as expected

Additional features—such as
[logged-in user handling](https://github.com/Fanmaker/Turducken/tree/main?tab=readme-ov-file#passing-identifiers) or
[privacy permissions](https://github.com/Fanmaker/Turducken/tree/main?tab=readme-ov-file#privacy-permissions-optional)

The checklist above represents the **minimum required for a certified integration**.

## Usage

First add the Fanmaker SDK to your project as a Swift Package:

![xcode1](https://user-images.githubusercontent.com/298020/120363801-2f743e00-c2d2-11eb-89fb-3fd273072d16.png)

![xcode2](https://user-images.githubusercontent.com/298020/120363926-4c107600-c2d2-11eb-8374-0b7e9cfc21a4.png)

### Sample App
A sample iOS app utilizing the SDK is available here (https://github.com/FanMaker/TurduckenSampleApp)

### Initialization

To initialize the SDK you need to pass your `<SDK_KEY>` into the Fanmaker SDK initializer. You need to call this code in your `AppDelegate` class as part of your `application didFinishLaunchingWithOptions` callback function. Configuration is a little different depending on what "Life Cycle" are you using.

#### For UIKit

If you are using `UIKit` then you should already have and `AppDelegate` class living in `AppDelegate.swift`, so you just need to add Fanmaker SDK initialization code to that file under the right callback function:

```
import UIKit
import FanMaker

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var fanmakerSDK1: FanMakerSDK!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        . . .

        // FANMAKER SDK INITIALIZATION CODE
        let fanmakerSDK1 = FanMakerSDK()
        fanmakerSDK1.initialize(apiKey: "<SDK_KEY>")
        AppDelegate.fanmakerSDK1 = fanmakerSDK1

        . . .

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
      . . .
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
      . . .
    }


}
```

#### For SwiftUI

When using `SwiftUI` Life Cycle, no `AppDelegate` class is created automatically so you need to create one of your own:

```
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

```
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

That is the whole integration. The SDK finds the topmost view controller, presents
the Fanmaker UI as a full-height sheet, and closes it again when the fan is done.
There is no view controller to construct, no presentation style to choose, no
`isShowing` state to keep in sync, and no dismissal to wire up.

#### Presentation options

| Style | What the fan gets | When to use it |
| --- | --- | --- |
| `.sheet` **(default)** | Full-height sheet with a grabber. iOS supplies swipe-to-dismiss. | Almost always. The fan always has a way out, whatever the content does. |
| `.fullScreen` | Edge to edge. The only way out is a close control drawn by the content itself. | Only where you know the content draws one — and never for a flow that can land on the login page. |

**Why `.sheet` is the default.** iOS supplies the way out — a grabber and a
swipe-down — and that matters more than it sounds: **Fanmaker's own login page does
not draw a close button**. A fan who opens the UI full screen and decides not to
sign in has no way out at all. The sheet uses a single full-height detent, so the
content still gets the whole screen; the only thing you give up is the last few
points at the top.

**Choosing a style.** Pass one to the call, or set a default on the instance:

```swift
// Per call — wins over the instance setting
AppDelegate.fanmakerSDK1.present(style: .sheet)
AppDelegate.fanmakerSDK1.present(style: .fullScreen)

// Per instance — used by every present() that does not pass a style
AppDelegate.fanmakerSDK1.presentationStyle = .fullScreen
AppDelegate.fanmakerSDK1.present()            // full screen

// Omitting the parameter never hardcodes a sheet; it defers to the instance
AppDelegate.fanmakerSDK1.present()
```

Precedence is: **style passed to the call** → **`presentationStyle` on the
instance** → **`.sheet`**.

On iOS 13 and 14 there are no sheet detents, so `.sheet` presents as a standard
`.pageSheet` card. It is still swipe-dismissable, which is the part that matters.

#### Closing

The SDK closes its own screen. You do not need to do anything.

- Web content triggering the close action closes the sheet.
- A fan swiping the sheet away closes it, and the SDK posts its close notification
  with `params: ["source": "swipe"]` so you can still react.
- Setting `FanMakerSDK.onClose` takes precedence, if you would rather handle closing
  yourself. See [Handling SDK Close Actions](#handling-sdk-close-actions).

#### The rest of the API

```swift
@discardableResult
func present(style: FanMakerSDKPresentationStyle? = nil,
             animated: Bool = true,
             completion: (() -> Void)? = nil) -> Bool

@discardableResult
func present(from host: UIViewController,
             style: FanMakerSDKPresentationStyle? = nil,
             animated: Bool = true,
             completion: (() -> Void)? = nil) -> Bool

func dismiss(animated: Bool = true)

var presentationStyle: FanMakerSDKPresentationStyle   // default .sheet
var isPresenting: Bool { get }
```

- **`present(from:)`** presents from a view controller you name, rather than the
  topmost one. Useful for an app driving several scenes, or one that wants the UI
  to come from a specific place in its hierarchy.
- **`dismiss()`** closes a screen `present()` put up, for closing from your own
  code. Web content triggering close, and a fan swiping the sheet away, both
  already unwind on their own.
- **`isPresenting`** is whether this instance currently has a screen on display.

Both `present` methods return whether they presented anything. They return `false`
when the SDK has not been initialized, when there is no visible view controller to
present from, or when this instance already has a screen up — a second `present()`
is refused rather than stacking a copy the fan then has to dismiss twice.

### Presenting it yourself (legacy)

> **Still fully supported, but no longer recommended.** New integrations should use
> `sdk.present()` above. This path is the source of most integration problems we
> see — it asks every host to solve presentation, hierarchy traversal, close
> handling and dismissal for themselves, and each one solves it slightly
> differently. We intend to keep it working for existing integrations, and to move
> new ones onto the SDK-owned path. Expect it to be formally deprecated in a future
> release; it will not be removed without notice and a migration path.

Create an instance of `FanMakerSDKWebViewController` (a `UIViewController` subclass)
and use it as you find convenient. The SDK also provides
`FanMakerSDKWebViewControllerRepresentable`, which conforms to
`UIViewControllerRepresentable`:

```swift
import SwiftUI
import FanMaker

struct ContentView : View {
    @State private var isShowingFanMakerUI : Bool = false

    var body : some View {
        Button("Show FanMaker UI", action: { isShowingFanMakerUI = true })
            .sheet(isPresented: $isShowingFanMakerUI) {
                FanMakerSDKWebViewControllerRepresentable(sdk: AppDelegate.fanmakerSDK1)
            }
    }
}
```

Two things to be aware of if you take this path:

**The SDK still closes its own screen.** When web content triggers the close action
and you have not set `onClose`, the SDK dismisses itself — handling all three ways
you might have put it there: presented modally, pushed onto a navigation stack, or
embedded as a child view controller. Earlier releases did nothing here, so if you
wrote your own dismissal you can now delete it, or keep `onClose` set to retain
control.

**SwiftUI `.sheet(isPresented:)` and self-closing do not mix cleanly.** When the SDK
dismisses itself out of a sheet that SwiftUI owns, your `isPresented` binding can
stay `true` — SwiftUI still believes the sheet is up, which quietly blocks the next
open. Either set `onClose` and flip the binding yourself, or use `sdk.present()`,
where SwiftUI never holds the flag. This is the clearest case for moving over.

**Loading no longer blocks the thread that presents it.** Resolving the site URL,
running auto-login and refreshing the session token all happen off the main thread,
and the SDK's loading screen is up while they do. Earlier releases did this work
behind `DispatchSemaphore.wait()` inside `viewDidLoad`, so presenting the SDK froze
the app for as long as those calls took — 350 ms on a good connection, longer on a
venue network, and unbounded if the site-details call never answered. Nothing is
required of you; a host that presents `FanMakerSDKWebViewController` simply stops
paying that freeze.

If you drive the lower-level `FanMakerSDKWebView` yourself, note that
`prepareUIView()` still blocks by contract, because it is public and existing
integrations call it. Prefer `prepareUIView(completion:)`, whose completion runs on
the main thread once the request has been loaded. The same applies to
`loginUserFromParams()`, which now has a non-blocking `loginUserFromParams(completion:)`
counterpart. Constructing `FanMakerSDKWebView` no longer performs a network call at
all, so a SwiftUI host embedding it directly will briefly see an empty webview where
it previously saw a stalled interface.

### Handling SDK Close Actions

> **Optional as of this release.** The SDK closes its own screen, so you no longer
> have to handle the close action to give a fan a way out. Set `onClose` only if you
> want to run your own logic on close, or need to dismiss a container of your own —
> setting it means the SDK stops closing its own screen and hands that job to you.

The Fanmaker SDK provides two ways to observe or handle the SDK UI being closed:

#### Option 1: Closure-Based Callback (Single Listener)

For simple use cases where you only need one callback handler, you can use the `onClose` closure property:

```swift
import SwiftUI
import FanMaker

struct ContentView : View {
    @State private var isShowingFanMakerUI : Bool = false

    var body : some View {
        Button("Show FanMaker UI", action: {
            // Set up the close callback before showing the UI
            AppDelegate.fanmakerSDK1.onClose = { params in
                print("FanMaker SDK closed with params: \(params)")
                // Handle the close action here
                // For example, update UI state or perform cleanup
                self.isShowingFanMakerUI = false
            }

            isShowingFanMakerUI = true
        })
        .sheet(isPresented: $isShowingFanMakerUI) {
            FanMakerSDKWebViewControllerRepresentable(sdk: AppDelegate.fanmakerSDK1)
            Button("Hide FanMakerUI", action: { isShowingFanMakerUI = false })
        }
    }
}
```

#### Option 2: NotificationCenter (Multiple Listeners)

For more complex scenarios where multiple parts of your app need to respond to SDK close events, use NotificationCenter:

```swift
import SwiftUI
import FanMaker

class MyViewModel: ObservableObject {
    @Published var fanMakerClosed = false

    init() {
        // Set up notification observer
        NotificationCenter.default.addObserver(
            forName: FanMakerSDK.closeSdk,
            object: AppDelegate.fanmakerSDK1,
            queue: .main
        ) { [weak self] notification in
            if let params = notification.userInfo?["params"] as? [String: Any] {
                print("FanMaker SDK closed with params: \(params)")
                // Handle the close action
                self?.fanMakerClosed = true
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

**Note**: The `params` dictionary contains any parameters passed from the web view when the close action is triggered.

### Handling Arbitrary Actions

The Fanmaker SDK supports dynamic action handling, allowing you to respond to any action sent from the web view without requiring SDK updates. This enables the SDK to trigger custom behaviors in your application based on actions defined by Fanmaker dynamically.

#### Option 1: Closure-Based Callback (Single Listener)

Register handlers for specific actions using the `onAction(_:handler:)` method:

```swift
import SwiftUI
import FanMaker

struct ContentView : View {
    var body : some View {
        // Register handler for "reload" action
        AppDelegate.fanmakerSDK1.onAction("reload") { params in
            print("Received reload action with params: \(params)")
            // Handle reload logic here
            if let force = params["force"] as? Bool, force {
                // Force reload app state
                reloadAppState()
            }
        }

        // Register handler for "updateTheme" action
        AppDelegate.fanmakerSDK1.onAction("updateTheme") { params in
            if let theme = params["theme"] as? String {
                // Update app theme
                updateAppTheme(theme)
            }
        }

        // Register handler for any custom action
        AppDelegate.fanmakerSDK1.onAction("customAction") { params in
            // Handle your custom action
            handleCustomAction(params: params)
        }
    }
}
```

#### Option 2: NotificationCenter (Multiple Listeners)

Listen for actions via NotificationCenter for scenarios where multiple parts of your app need to respond:

```swift
import SwiftUI
import FanMaker

class MyViewModel: ObservableObject {
    init() {
        // Listen for "reload" action
        NotificationCenter.default.addObserver(
            forName: FanMakerSDK.actionNotificationName("reload"),
            object: AppDelegate.fanmakerSDK1,
            queue: .main
        ) { [weak self] notification in
            guard let params = notification.userInfo?["params"] as? [String: Any],
                  let action = notification.userInfo?["action"] as? String else {
                return
            }
            print("Received \(action) action with params: \(params)")
            // Handle reload action
            self?.handleReloadAction(params: params)
        }

        // Listen for "updateTheme" action
        NotificationCenter.default.addObserver(
            forName: FanMakerSDK.actionNotificationName("updateTheme"),
            object: AppDelegate.fanmakerSDK1,
            queue: .main
        ) { [weak self] notification in
            guard let params = notification.userInfo?["params"] as? [String: Any] else {
                return
            }
            // Handle theme update
            self?.handleThemeUpdate(params: params)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

#### Option 3: SwiftUI View with `.onReceive()` Modifier

For SwiftUI views, you can use the `.onReceive()` modifier to listen for actions directly in your view:

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
                    // Handle success parameter
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
1. Check for a registered handler via `onAction(_:handler:)`
2. Call the handler if one exists
3. Post a notification with the action name (e.g., `FanMakerSDKAction_reload`)
4. Include both `params` and `action` in the notification's `userInfo`

**Note**: The `params` dictionary contains any parameters passed from the web view. Actions are handled dynamically, so you can add new actions without updating the SDK code.

#### Personalization options

When you present the `FanMakerSDKWebViewController` instance it will take a couple of seconds to load the content to display to the user. In the meanwhile, a system spinner will show to indicate the user the UI is actually loading. You can override this default spinner with a custom image or animation.

You can personalize the loading screen's loading animation by calling the following method before presenting the `FanMakerSDKWebViewController`. The prefered place to call this function is right after calling `AppDelegate.fanmakerSDK1.initialize`

<!-- AppDelegate.fanmakerSDK1.setLoadingBackgroundColor(_ bgColor : UIColor) -->
```
AppDelegate.fanmakerSDK1.setLoadingForegroundImage(_ fgImage : UIImage)
```

**Note**: `AppDelegate.fanmakerSDK1.setLoadingForegroundImage(_ fgImage : UIImage)` can take both a static or an animated `UIImage` as an argument.

The Sample App has a working example commented out in the `RegionList.swift` file, but here are some instructions to aid in creating a custom loading animation.

**Note** Your images should be **square in dimension**, otherwise the SDK will force the dimensions into a square, potentially distoring your animation.

You will need to break your gif into a PNG sequence, a still image for each "frame" of the animation. Once you have this sequence import all PNGs to the `Assets.xcassets` catalog of your iOS application.

<img width="1160" alt="Screenshot 2023-10-12 at 4 51 37 PM" src="https://github.com/FanMaker/Turducken/assets/3985921/e121b16e-63f2-4a40-9109-eefd3aa83dab">

Then you will need some code to create the animation from your static PNGS:
```
var images: [UIImage] = []

// Start your sequence at 0 and end with the number of images you have.
for index in 0...89 {
    // We expect the images to be in the Assets.xcassets catelog. Number your images like so: `<YOUR IMAGE NAME>-0`
    if let image = UIImage(named: "<YOUR IMAGE NAME>-\(index)") {
        images.append(image)
    }
}

// Use `compactMap` to filter out any nil values from the array
let nonNilImages = images.compactMap { $0 }

// Check if there are any images before creating the animated image
if !nonNilImages.isEmpty {
    // You can adjust the duration to speed up or slow down your animation
    let gifImage = UIImage.animatedImage(with: nonNilImages, duration: 1.0)

    // Unwrap the optional before passing it to FanMakerSDK
    if let unwrappedGifImage = gifImage {
        // If all has gone well, we can now pass the animated image to FanMakerSDK
        AppDelegate.fanmakerSDK1.setLoadingForegroundImage(unwrappedGifImage)
    }
}
```

### Deep Linking / Universal Links
If you wish to link to something within the Fanmaker SDK, you need to setup your application to accept URL Scheme or Universal Links, or know the resource you are trying to access.

An example of using a URL scheme to open app links:

<img width="1424" alt="Screenshot 2024-05-23 at 3 42 02 PM" src="https://github.com/FanMaker/Turducken/assets/3985921/071cecb0-7c32-4f5e-b2f5-669be6c62249">

Navigate to your project's Info tab in Xcode and scroll down to URL Types and hit the (+) button. From there add the bundle identifier for your application (which can be located in the Signing & Capabilities tab), and add the URL Schemes you wish to use. No other setting should be necessary.

From the example, you'll be able to open your application with your chosen URL Scheme, like `turducken://open`

Next you'll need to modify your application to be able to handle the link using `.onOpenURL`:

```
import SwiftUI
import FanMaker

struct ContentView : View {
    @State private var isShowingFanMakerUI : Bool = false

    var body : some View {
        Button("Show FanMaker UI", action: { isShowingFanMakerUI = true })
        .sheet(isPresented: $isShowingFanMakerUI) {
            // FanMakerUI Display
            FanMakerSDKWebViewControllerRepresentable(sdk: AppDelegate.fanmakerSDK1)
            Button("Hide FanMakerUI", action: { isShowingFanMakerUI = false })
        }
        .onOpenURL { url in
            if AppDelegate.fanmakerSDK1.canHandleUrl(url) {
                if AppDelegate.fanmakerSDK1.handleUrl(url) {
                    print("FanMaker handled the URL, opening the FanMaker UI")
                    self.isShowingFanMakerUI = true
                } else {
                    print("FanMaker failed to handle the URL")
                }

            } else {
                print("FanMaker cannot handle the URL")
            }
        }
    }
}
```

In the example above the `.onOpenURL` method is used to catch the URL used to open the application and so it can be handeled accordingly. The Fanmaker SDK provides 2 methods for determining if a link can be handeled by Fanmaker:
1) `AppDelegate.fanmakerSDK1.canHandleUrl(<URL>)`
2) `AppDelegate.fanmakerSDK1.handleUrl(<URL>)`

**NOTE**: the `FanMakerSDK` expects links to start with `FanMaker` (case insensitive) after the schema used to open the applicaiton. Like so:
```
turducken://FanMaker/...(rest of path)
```

So a link that might be used to open the prize store to a specific prize might look like this:
```
turducken://FanMaker/store/items/1234
```

The `AppDelegate.fanmakerSDK1.canHandleUrl(<URL>)` determines if the url can be used by the Fanmaker SDK, enforcing the `FanMaker` (case insensitive) prefix in the requested URL. Which will return a `Bool`
The `AppDelegate.fanmakerSDK1.handleUrl(<URL>)` will setup the necessary connections within the `FanMakerSDK` so that when the WebView is next viewed, it will navigate to the appropriate place.

**Note**: it is recommended that you trigger your sheet to display the `FanMakerUI` after a link has been handeled. On subsequent loads of the webview, the standard path will be used instead. Fanmaker can help you format your links to sections of the SDK approprately. When passing a deeplink/universal link to the Fanmaker SDK, this simply tells the SDK that when it is opened next to navigate to the desired route. If multiple links are passed without opening the SDK, then only the latest link will be shown to the user.

**Multiple FanMakerSDK intances**:
If your application initializes multiple instances of the Fanmaker SDK, you will be responsible for checking the scheme or web url to determine which instance to pass the url to:
```
@State private var isShowingFanMakerUI : Bool = false
@State private var isShowingFanMakerUI2 : Bool = false
...
}.onOpenURL { url in
    if AppDelegate.fanmakerSDK1.canHandleUrl(url) {
        let url_components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if url_components?.scheme == "turducken" {
            if AppDelegate.fanmakerSDK1.handleUrl(url) {
                print("FanMaker handled the URL, opening the FanMaker UI")
                self.isShowingFanMakerUI = true
            } else {
                print("FanMaker failed to handle the URL")
            }
        }

        if url_components?.scheme == "turducken2" {
            if AppDelegate.fanmakerSDK2.handleUrl(url) {
                print("FanMaker2 handled the URL, opening the FanMaker2 UI")
                self.isShowingFanMakerUI2 = true
            } else {
                print("FanMaker2 failed to handle the URL")
            }
        }

    } else {
        print("FanMaker cannot handle the URL")
    }
}
```

### Passing Identifiers

Fanmaker UI usually requires users to input their Fanmaker's Credentials. However, you can make use of up to four different custom identifiers to allow a given user to automatically login when they first open Fanmaker UI.

```
import SwiftUI
import FanMaker

struct ContentView : View {
    @State private var isShowingFanMakerUI : Bool = false

    var body : some View {
        // FanMakerUI initialization
        let fanMakerUI = FanMakerSDKWebViewController(sdk: AppDelegate.fanmakerSDK1)

        Button("Show FanMaker UI", action: {
            // **Note**: Identifiers availability depends on your FanMaker program.
            AppDelegate.fanmakerSDK1.setMemberID("<memberid>")
            AppDelegate.fanmakerSDK1.setStudentID("<studentid>")
            AppDelegate.fanmakerSDK1.setTicketmasterID("<ticketmasterid>")
            AppDelegate.fanmakerSDK1.setYinzid("<yinzid>")

            // Location Tracking is enabled by default in the FanMaker SDK. You can disable it by calling:
            AppDelegate.fanmakerSDK1.disableLocationTracking()

            // If your Host application disables location tracking, it will need to be manually enabled again before it can be used:
            AppDelegate.fanmakerSDK1.enableLocationTracking()

            // Make sure to setup any custom identifier before actually displaying the FanMaker UI
            isShowingFanMakerUI = true
        })
            .sheet(isPresented: $isShowingFanMakerUI) {
                // FanMakerUI Display
                fanMakerUI.view
                Button("Hide FanMakerUI", action: { isShowingFanMakerUI = false })
            }
    }
}
```

**Note**: All of these identifiers, along with the Fanmaker's User ID, are automatically defined when a user successfully logins and become accessible via the following public variables:

```
AppDelegate.fanmakerSDK1.userID
AppDelegate.fanmakerSDK1.memberID
AppDelegate.fanmakerSDK1.studentID
AppDelegate.fanmakerSDK1.ticketmasterID
AppDelegate.fanmakerSDK1.yinzid
```

### Passing a Push Notification Token
In addition to user identifiers, the Fanmaker SDK allows you to provide a Push Notification Token. This token enables Fanmaker to send push notifications directly to users of your application.

Once you’ve obtained a valid push notification token from APNs, pass it to the Fanmaker SDK before presenting the Fanmaker UI. The SDK will associate the token with the current user session.

```
import SwiftUI
import FanMaker

struct ContentView : View {
    @State private var isShowingFanMakerUI : Bool = false

    var body : some View {
        // FanMakerUI initialization
        let fanMakerUI = FanMakerSDKWebViewController(sdk: AppDelegate.fanmakerSDK1)

        Button("Show FanMaker UI", action: {
            AppDelegate.fanmakerSDK1.setPushNotificationToken("<pushToken>")
            isShowingFanMakerUI = true
        })
            .sheet(isPresented: $isShowingFanMakerUI) {
                fanMakerUI.view
                Button("Hide FanMakerUI", action: { isShowingFanMakerUI = false })
            }
    }
}
```

### Passing Custom Identifiers
It is also possible to pass arbitrary identifiers through the use of a dictionary. This would be done in the same place as you would pass a standard custom identifier above, so please reference that section for more details.

```
...
Button("Show FanMaker UI", action: {
    ...
    AppDelegate.fanmakerSDK1.setMemberID("<memberid>")

    let arbitraryIdentifiers: [String: Any] = [
        "nfl_oidc": "1234-nfl-oidc"
    ]

    AppDelegate.fanmakerSDK1.setFanMakerIdentifiers(dictionary: arbitraryIdentifiers)

    ...
})
...

```

### Privacy Permissions (Optional)
It is possible to pass optional privacy permission details to the Fanmaker SDK where we will record the settings for the user in our system. To pass this information to Fanmaker, please use the following protocols. Note: it is the same way you would pass Custom Identifiers above, but with specific keys.

The specific privacy opt in/out keys are as follows:
1. `privacy_advertising`
2. `privacy_analytics`
3. `privacy_functional`
4. `privacy_all`

*NOTE: all privacy permissions are optional. Do not pass privacy settings that you do not have user data for*

```
...
Button("Show FanMaker UI", action: {
    ...
    AppDelegate.fanmakerSDK1.setMemberID("<memberid>")

    let arbitraryIdentifiers: [String: Any] = [
        # This is an example of a Custom Identifer you may pass
        "nfl_oidc": "1234-nfl-oidc",

        # These are the opt in/out settings
        "privacy_advertising": false,
        "privacy_analytics": true,
        "privacy_functional": true,
        "privacy_all": false,
    ]

    AppDelegate.fanmakerSDK1.setFanMakerIdentifiers(dictionary: arbitraryIdentifiers)

    ...
})
...

```

### Passing Custom Parameters
Similar to passing custom identifiers, you can also pass custom parameters to the SDK. Here is how to do so and some of the options.

```
...
Button("Show FanMaker UI", action: {
    ...
    AppDelegate.fanmakerSDK1.setMemberID("<memberid>")

    let customParameters: [String: Any] = [
        "hide_menu": true, // used to hide the menu in the SDK. Note, you will need to pass hide_menu: false, when you want to show the menu again.
        "viewport_width": 512, // used to inform FanMaker how wide the viewing area is
        "viewport_height": 1024 // used to inform FanMaker how tall the viewing area is
    ]

    AppDelegate.fanmakerSDK1.fanMakerParameters(dictionary: customParameters)

    ...
})
...

```

*`Note`: a value of `true` indicates that the user has opted in to a privacy permission, `false` indicates that a user has opted out.*

### Location Tracking

Fanmaker UI asks for user's permission to track their location the first time it loads. By default the Fanmaker SDK will have location tracking enabled for features like Auto Checkin. However, location tracking can be enabled/disabled by calling the following static functions:

```
// To manually disable location tracking
AppDelegate.fanmakerSDK1.disableLocationTracking()

// To manually enable location tracking back
AppDelegate.fanmakerSDK1.enableLocationTracking()
```

### Auto Checkin
The FanMakerSDK can auto checkin users to events without them opening the FanMakerSDK itself. Once the user has successfully logged into the FanMakerSDK and granted location permissions, on subsequent opens of your application, the FanmakerSDK will automatically attempt to automatically checkin the user to events within range. Location Tracking is enabled by default in the Fanmaker SDK, if you have disabled it with `AppDelegate.fanmakerSDK1.disableLocationTracking()` you can enable it again with:
```
AppDelegate.fanmakerSDK1.enableLocationTracking()
```

### Beacons Tracking

The FanMakerSDK allows beacon tracking by implementing the protocol `FanMakerSDKBeaconsManagerDelegate`. This protocol can be implemented in a `UIViewController` subclass (for classic development using a storyboard) class as well as an `ObservableObject` (for SwiftUI development).

Then, you need to declare an instance of `FanMakerSDKBeaconsManager` and assign your delegate to it.

```
class FanMakerViewModel : NSObject, FanMakerSDKBeaconsManagerDelegate {
    private let beaconsManager1 : FanMakerSDKBeaconsManager

    init() {
        beaconsManager1 = FanMakerSDKBeaconsManager(sdk: AppDelegate.fanmakerSDK1)

        super.init()
        beaconsManager1.delegate = self
    }
}
```

`FanMakerSDKBeaconsManagerDelegate` protocol requires the following functions to be implemented:

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didChangeAuthorization status: FanMakerSDKBeaconsAuthorizationStatus) -> Void
```
This function is used to handle the current `FanMakerSDKBeaconsAuthorizationStatus` of your app. The possible enum values are:
```
.notDetermined
.restricted
.denied
.authorizedAlways
.authorizedWhenInUse
```
Calling `beaconsManager1.requestAuthorization()` will prompt the user to get permissions when necessary and call this function when user gives or denies permission to use iOS Location tracking.

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didReceiveBeaconRegions regions: [FanMakerSDKBeaconRegion]) -> Void
```
In order to actually start tracking beacons, you need to call `beaconsManager1.fetchBeaconRegions()`. Be sure you have the right permissions before calling this or it won't work. Once beacons are retrieved from Fanmaker servers, `didReceiveBeacons` will be called.

**NOTE**: In order to fetch beacons from the API and start tracking them, user needs to be logged into the Fanmaker UI before calling this function.


```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didEnterRegion region: FanMakerSDKBeaconRegion) -> Void
```
This function will get called whenever a user walks into a scanned beacon region.

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didExitRegion region: FanMakerSDKBeaconRegion) -> Void
```
This function will get called whenever a user walks out of a scanned beacon region.

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didUpdateBeaconRangeActionsHistory queue: [FanMakerSDKBeaconRangeAction]) -> Void
```
This function will get called whenever a user gets a valid beacon signal, which happens approximately once per minute while the user stays in a beacon's range. The time interval is customizable via the API

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didUpdateBeaconRangeActionsSendList queue: [FanMakerSDKBeaconRangeAction]) -> Void
```
This function will get called whenever a valid beacon signal fails to get posted to the Fanmaker servers. This may happen because of weak or failing internet connection, temporarily server errors, etc. The SDK will retry to send this queue every minute and, once it get posted successfully, this queue will be emptied and this function will be called with an empty array.

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didFailWithError error: FanMakerSDKBeaconsError) -> Void
```
This function will be called whenever something goes wrong.
Possible enum values for `FanMakerSDKBeaconsError` are:
```
.userSessionNotFound
.serverError
.unknown
```

**Multiple FanMakerSDK intances**:
When you have multiple instances of the FanMakerSDK initialized, you can scan for beacons with one, the other, or all of them.

Make sure to initialize a beacons manager for each instance:
```
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

You'll then want to request authorization with all instances:
```
beaconsManager1.requestAuthorization()
beaconsManager2.requestAuthorization()
```

The FanMakerSDK has location tracking on by default. Location tracking in needed to scan for bluetooth beacons. Here is how you can enable or disable location tracking to block or allow scanning for bluetooth beacons

To Disable location tracking:
```
AppDelegate.fanmakerSDK1.disableLocationTracking()
AppDelegate.fanmakerSDK2.disableLocationTracking()
```

To Enable location tracking:
```
AppDelegate.fanmakerSDK1.enableLocationTracking()
AppDelegate.fanmakerSDK2.enableLocationTracking()
```

#### Checking your beacon setup

Every stage of beacon tracking writes an `NSLog` line prefixed `FanMaker (Beacons):`,
so you can confirm a setup from Xcode's console or `Console.app` without instrumenting
anything. Filter on that prefix and you should see, in order:

```
FanMaker (Beacons): Monitoring for beacon region UUID: 2686F39C-… Major: 1
FanMaker (Beacons): ENTER region 1705 'Kyle Field - NE Tower' (UUID: 2686f39c-… Major 1) via didDetermineState
FanMaker (Beacons): RANGING STARTED for region 1705 'Kyle Field - NE Tower' (…). Beacon sightings will be logged as they arrive.
FanMaker (Beacons): RANGED beacon 2686F39C-… major 1 minor 0 [rssi -72, proximity near, accuracy 1.4] - recording
FanMaker (Beacons): ENTER recorded for region 1705 'Kyle Field - NE Tower'
FanMaker (Beacons): 1 beacon range actions successfully posted
```

Reading the gaps is usually enough to place the problem:

| You see | Meaning |
| --- | --- |
| No `Monitoring for beacon region` lines | `startScanning` was never reached. Check authorization, and that your host calls the SDK at all — this is the most common integration miss. |
| `Monitoring…` but no `ENTER` | The device is not inside any configured region. Check the UUID, major and minor against the region set up for your site. |
| `ENTER` but no `RANGING STARTED` | The region is missing a major value, so no ranging constraint can be built. |
| `RANGING STARTED` but no `RANGED` | The radio is listening and hearing nothing. Usually the beacon is off, out of range, or advertising a different UUID. |
| `RANGED … holding off until the 60s uniqueness throttle clears` | Working as intended. The beacon is being seen; repeat sightings are suppressed for the site's uniqueness throttle. Each beacon announces its first sighting regardless, so you always get confirmation. |
| `RANGED … recording` but no `beacon range actions successfully posted` | The sightings are being captured but not reaching us. Look at connectivity and the session token. |

Ranging does not depend on the network or on your delegate. It starts the moment a
region is entered and stops the moment it is exited, so a failed request or an unset
`FanMakerSDKBeaconsManagerDelegate` cannot cost you the sightings for a visit.
Earlier releases gated both on a successful `beacon_region_actions` request *and* a
non-nil delegate, which meant an integration that never assigned one recorded nothing
at all while appearing correctly configured.

### Recomended Entitlements

Bluetooth (required for beacons)
```
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Enabling blutooth access will allow you to earn points when you come in contact with bluetooth beacons that may be located at the location of an event you are attending. You may also receive exclusive offers and additional point earning opportunities based on your contact with bluetooth beacons always</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>Enabling blutooth access will allow you to earn points when you come in contact with bluetooth beacons that may be located at the location of an event you are attending. You may also receive exclusive offers and additional point earning opportunities based on your contact with bluetooth beacons</string>
```

Location (required)
```
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>By sharing your location you can automatically earn points for checking in to certain events. You may also receive exclusive offers and additional point earning opportunities based on your location</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>By sharing your location you can automatically earn points for checking in to certain events. You may also receive exclusive offers and additional point earning opportunities based on your location or when you come in contact with bluetooth beacons</string>

<key>NSLocationUsageDescription</key>
<string>By sharing your location you can earn points for checking in to certain events. You may also receive exclusive offers and additional point earning opportunities based on your location</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>By sharing your location you can earn points for checking in to certain events. You may also receive exclusive offers and additional point earning opportunities based on your location</string>
```
## :warning: BREAKING CHANGES IN 2.0 :warning:
Version 2.0 of the FanMakerSDK has changed from static to instanced based initializtion. This means that you will need to modify your implementation to avoid service interruptions in this version. Previous versions of the SDK are no longer available for instalation. Support for SDK versions 1.x will be depreciated on December 20th, 2024, afterwords non version 2.0 + will cease to function.

The benefits of SDK 2.0 are [described in detail on our blog](https://blog.fanmaker.com/sdk-2-0-background-check-ins-app-rewards-and-support-for-multiple-programs/).

## Upgrading to 2.0 from 1.x

### Step 1:
Previously the Fanmaker SDK was initialized like this:
```
FanMakerSDK.initialize(apiKey: "<SDK_KEY>")
```

Now, with the instanced based initialization, you'll need to keep track of the instance of the SDK like so:

```
let fanmakerSDK1 = FanMakerSDK()
fanmakerSDK1.initialize(apiKey: "<SDK_KEY_1>")
AppDelegate.fanmakerSDK1 = fanmakerSDK1
```

This way you can initialize multiple, independent versions of the Fanmaker SDK. Using the `AppDelegate` allows the SDK impementation to be available throughout your application.


### Step 2:
When you are preparing your sheet to present the `FanMakerSDKWebViewConrollerRepresentable`, you will now also need to pass the SDK instance you initialized in Step 1.
```
...
}.sheet(isPresented: $showFanMakerUI) {
    FanMakerSDKWebViewControllerRepresentable(sdk: AppDelegate.fanmakerSDK1)
}
```

### Step 3:
If you are passing any values to the FanMakerSDK using one of our methods like `setMemberID`, `setTicketmasterID`, or `setFanMakerIdentifiers`, then be sure to specify which SDK instance you are passing the values to:

```
AppDelegate.fanmakerSDK1.setMemberID("123456")
AppDelegate.fanmakerSDK1.setTicketmasterID("7890123")

let fanmakerIdentifiers1: [String: Any] = [
    "airship_channel_id": "7870978-airship-a0af9d780a9s7f07f"
]
AppDelegate.fanmakerSDK1.setFanMakerIdentifiers(dictionary: fanmakerIdentifiers1)
```

### Step 4:
If you are using bluetooth beacons through the Fanmaker SDK, you will need to update your implementation.

Where you are initializing the `FanMakerSDKBeaconsManager`, you will now need to pass the instance of the SDK you are using:
```
beaconsManager1 = FanMakerSDKBeaconsManager(sdk: AppDelegate.fanmakerSDK1)
```
Then set the delegate as normal:
```
beaconsManager1.delegate = self
```

You will need to requestAuthorization for every instance of the SDK you are planning on using beacons with:
```
beaconsManager1.requestAuthorization()
```
