# FanMaker Swift SDK for iOS App Development

## About

The FanMaker Swift SDK provides iOS developers with a way of inserting the FanMaker UI in another app. The view can be displayed as part of a navigation stack, a modal or even a subview in an app's layout.

## Usage

First add the FanMaker SDK to your project as a Swift Package:

![xcode1](https://user-images.githubusercontent.com/298020/120363801-2f743e00-c2d2-11eb-89fb-3fd273072d16.png)

![xcode2](https://user-images.githubusercontent.com/298020/120363926-4c107600-c2d2-11eb-8374-0b7e9cfc21a4.png)

### Sample App
A sample iOS app utilizing the SDK is available here (https://github.com/FanMaker/TurduckenSampleApp)

### Initialization

To initialize the SDK you need to pass your `<SDK_KEY>` into the FanMaker SDK initializer. You need to call this code in your `AppDelegate` class as part of your `application didFinishLaunchingWithOptions` callback function. Configuration is a little different depending on what "Life Cycle" are you using.

#### For UIKit

If you are using `UIKit` then you should already have and `AppDelegate` class living in `AppDelegate.swift`, so you just need to add FanMaker SDK initialization code to that file under the right callback function:

```
import UIKit
import FanMaker

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        . . .

        // FANMAKER SDK INITIALIZATION CODE
        FanMakerSDK.initialize(apiKey: "<SDK_KEY>")

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
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FanMakerSDK.initialize(apiKey: "<SDK_KEY>")

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

### Displaying FanMaker UI

In order to show FanMaker UI in your app, create an instance of `FanMakerSDKWebViewController` (`UIViewController` subclass) and use it as you find convenient.

FanMaker SDK also provides a `FanMakerSDKWebViewControllerRepresentable` wrapper which complies with `UIViewControllerRepresentable` protocol. For example, the following code is used to show it as a sheet modal when users press a button (which we recomend):

```
import SwiftUI
import FanMaker

struct ContentView : View {
    @State private var isShowingFanMakerUI : Bool = false

    var body : some View {
        Button("Show FanMaker UI", action: { isShowingFanMakerUI = true })
            .sheet(isPresented: $isShowingFanMakerUI) {
                // FanMakerUI Display
                FanMakerSDKWebViewControllerRepresentable()
                Button("Hide FanMakerUI", action: { isShowingFanMakerUI = false })
            }
    }
}
```

#### Personalization options

When you present the `FanMakerSDKWebViewController` instance it will take a couple of seconds to load the content to display to the user. In the meanwhile, a white screen with a loading animation will show to indicate the user the UI is actually loading.

You can personalize both the loading screen's background color and loading animation by calling the following methods before presenting the `FanMakerSDKWebViewController`. The prefered place to call these functions is right after calling `FanMakerSDK.initialize`

```
FanMakerSDK.setLoadingBackgroundColor(_ bgColor : UIColor)
FanMakerSDK.setLoadingForegroundImage(_ fgImage : UIImage)
```

**Note**: `FanMakerSDK.setLoadingForegroundImage(_ fgImage : UIImage)` can take both a static or an animated `UIImage` as an argument.

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
        FanMakerSDK.setLoadingForegroundImage(unwrappedGifImage)
    }
}
```

### Deep Linking / Universal Links
If you wish to link to something within the FanMaker SDK, you need to setup your application to accept URL Scheme or Universal Links, or know the resource you are trying to access.

An example of using a URL scheme to open app links:

<img width="1424" alt="Screenshot 2024-05-23 at 3 42 02 PM" src="https://github.com/FanMaker/Turducken/assets/3985921/071cecb0-7c32-4f5e-b2f5-669be6c62249">

Navigate to your project's Info tab in Xcode and scroll down to URL Types and hit the (+) button. From there add the bundle identifier for your application (which can be located in the Signing & Capabilities tab), and add the URL Schemes you wish to use. No other setting should be necessary.

From the example, you'll be able to open your application with your URL Scheme, like `turducken://open`

Next you'll need to modify your application to be able to handle the link:

```
import SwiftUI
import FanMaker

struct ContentView : View {
    @State private var isShowingFanMakerUI : Bool = false

    var body : some View {
        Button("Show FanMaker UI", action: { isShowingFanMakerUI = true })
        .sheet(isPresented: $isShowingFanMakerUI) {
            // FanMakerUI Display
            FanMakerSDKWebViewControllerRepresentable()
            Button("Hide FanMakerUI", action: { isShowingFanMakerUI = false })
        }
        .onOpenURL { url in
            if FanMakerSDK.canHandleUrl(url) {
                if FanMakerSDK.handleUrl(url) {
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

In the example above the `.onOpenURL` method is used to catch the URL used to open the application and so it can be handeled accordingly. The FanMaker SDK provides 2 methods for determining if a link can be handeled by FanMaker:
1) `FanMakerSDK.canHandleUrl(<URL>)`
2) `FanMakerSDK.handleUrl(<URL>)`

**NOTE**: the `FanMakerSDK` expects links to start with `FanMaker` (case insensitive) after the schema used to open the applicaiton. Like so:
```
turducken://FanMaker/...(rest of path)
```

So a link that might be used to open the prize store to a specific prize might look like this:
```
turducken://FanMaker/store/items/1234
```

The `FanMakerSDK.canHandleUrl(<URL>)` determines if the url can be used by the FanMaker SDK, enforcing the `FanMaker` (case insensitive) prefix in the requested URL. Which will return a `Bool`
The `FanMakerSDK.handleUrl(<URL>)` will setup the necessary connections within the `FanMakerSDK` so that when the WebView is next viewed, it will navigate to the appropriate place.

**Note**: it is recommended that you trigger your sheet to display the `FanMakerUI` after a link has been handeled. On subsequent loads of the webview, the standard path will be used instead. FanMaker can help you format your links to sections of the SDK approprately.

### Passing Identifiers

FanMaker UI usually requires users to input their FanMaker's Credentials. However, you can make use of up to four different custom identifiers to allow a given user to automatically login when they first open FanMaker UI.

```
import SwiftUI
import FanMaker

struct ContentView : View {
    @State private var isShowingFanMakerUI : Bool = false

    var body : some View {
        // FanMakerUI initialization
        let fanMakerUI = FanMakerSDKWebViewController()

        Button("Show FanMaker UI", action: {
            // **Note**: Identifiers availability depends on your FanMaker program.
            FanMakerSDK.setMemberID("<memberid>")
            FanMakerSDK.setStudentID("<studentid>")
            FanMakerSDK.setTicketmasterID("<ticketmasterid>")
            FanMakerSDK.setYinzid("<yinzid>")
            FanMakerSDK.setPushNotificationToken("<pushToken>")

            // Enable Location Tracking (Permissions should be previously asked by your app)
            FanMakerSDK.enableLocationTracking()

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

**Note**: All of these identifiers, along with the FanMaker's User ID, are automatically defined when a user successfully logins and become accessible via the following public variables:

```
FanMakerSDK.userID
FanMakerSDK.memberID
FanMakerSDK.studentID
FanMakerSDK.ticketmasterID
FanMakerSDK.yinzid
```

### Passing Custom Identifiers
It is also possible to pass arbitrary identifiers through the use of a dictionary. This would be done in the same place as you would pass a standard custom identifier above, so please reference that section for more details.

```
...
Button("Show FanMaker UI", action: {
    ...
    FanMakerSDK.setMemberID("<memberid>")

    let arbitraryIdentifiers: [String: Any] = [
        "nfl_oidc": "1234-nfl-oidc"
    ]

    FanMakerSDK.setFanMakerIdentifiers(dictionary: arbitraryIdentifiers)

    ...
})
...

```

### Privacy Permissions (Optional)
It is possible to pass optional privacy permission details to the FanMaker SDK where we will record the settings for the user in our system. To pass this information to FanMaker, please use the following protocols. Note: it is the same way you would pass Custom Identifiers above, but with specific keys.

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
    FanMakerSDK.setMemberID("<memberid>")

    let arbitraryIdentifiers: [String: Any] = [
        # This is an example of a Custom Identifer you may pass
        "nfl_oidc": "1234-nfl-oidc",

        # These are the opt in/out settings
        "privacy_advertising": false,
        "privacy_analytics": true,
        "privacy_functional": true,
        "privacy_all": false,
    ]

    FanMakerSDK.setFanMakerIdentifiers(dictionary: arbitraryIdentifiers)

    ...
})
...

```
*`Note`: a value of `true` indicates that the user has opted in to a privacy permission, `false` indicates that a user has opted out.*

### Location Tracking

FanMaker UI asks for user's permission to track their location the first time it loads. However, location tracking can be enabled/disabled by calling the following static functions:

```
// To manually disable location tracking
FanMakerSDK.disableLocationTracking()

// To manually enable location tracking back
FanMakerSDK.enableLocationTracking()
```

### Beacons Tracking

FanMaker SDK allows beacon tracking by implementing the protocol `FanMakerSDKBeaconsManagerDelegate`. This protocol can be implemented in a `UIViewController` subclass (for classic development using a storyboard) class as well as an `ObservableObject` (for SwiftUI development).

Then, you need to declare an instance of `FanMakerSDKBeaconsManager` and assign your delegate to it.

```
class FanMakerViewModel : NSObject, FanMakerSDKBeaconsManagerDelegate {
    private let beaconsManager : FanMakerSDKBeaconsManager

    init() {
        beaconsManager = FanMakerBeaconsManager()

        super.init()
        beaconsManager.delegate = self
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
Calling `beaconsManager.requestAuthorization()` will prompt the user to get permissions when necessary and call this function when user gives or denies permission to use iOS Location tracking.

```
func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didReceiveBeaconRegions regions: [FanMakerSDKBeaconRegion]) -> Void
```
In order to actually start tracking beacons, you need to call `beaconsManager.fetchBeaconRegions()`. Be sure you have the right permissions before calling this or it won't work. Once beacons are retrieved from FanMaker servers, `didReceiveBeacons` will be called.

**NOTE**: In order to fetch beacons from the API and start tracking them, user needs to be logged into the FanMaker UI before calling this function.


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
This function will get called whenever a valid beacon signal fails to get posted to the FanMaker servers. This may happen because of weak or failing internet connection, temporarily server errors, etc. The SDK will retry to send this queue every minute and, once it get posted successfully, this queue will be emptied and this function will be called with an empty array.

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
