import XCTest
import UIKit
@testable import FanMaker

/// Covers the SDK putting its own screen up and taking it down again.
///
/// A host can present the FanMaker UI modally, push it onto a navigation
/// stack, or embed it as a child, and each needs a different call to undo.
/// Real hierarchies are built here rather than mocked, because the thing being
/// tested is precisely how the controller reads its own containment.
@available(iOS 13.0, *)
final class PresentationTests: XCTestCase {
    private var window: UIWindow!
    private var sdk: FanMakerSDK!

    override func setUp() {
        super.setUp()
        sdk = FanMakerSDK()
        sdk.initialize(apiKey: "presentation-tests-\(UUID().uuidString)")

        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        sdk = nil
        super.tearDown()
    }

    private func screen() -> FanMakerSDKWebViewController {
        return FanMakerSDKWebViewController(sdk: sdk)
    }

    // MARK: - dismissSelf, per containment shape

    /// Records whether UIKit's own dismiss was asked for, so the branch taken
    /// can be checked without needing a scene for the transition to complete
    /// in - see the note at the bottom of this file.
    private final class SpyController: FanMakerSDKWebViewController {
        var dismissCalls = 0
        override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
            dismissCalls += 1
            super.dismiss(animated: flag, completion: completion)
        }
    }

    func testDismissesItselfWhenPresentedModally() {
        let host = window.rootViewController!
        let subject = SpyController(sdk: sdk)
        host.present(subject, animated: false, completion: nil)
        XCTAssertNotNil(subject.presentingViewController, "precondition: UIKit recorded the presentation")

        subject.dismissSelf(animated: false)

        XCTAssertEqual(subject.dismissCalls, 1,
                       "a modally presented screen should unwind its own presentation")
        XCTAssertNil(subject.parent, "and should not have tried to detach as a child instead")
    }

    func testAPushedScreenPopsRatherThanDismissing() {
        // The three shapes need three different calls, so confirm the wrong one
        // is not also fired.
        let navigation = UINavigationController(rootViewController: UIViewController())
        window.rootViewController = navigation
        let subject = SpyController(sdk: sdk)
        navigation.pushViewController(subject, animated: false)

        subject.dismissSelf(animated: false)

        XCTAssertEqual(subject.dismissCalls, 0, "popping is not dismissing")
        XCTAssertEqual(navigation.viewControllers.count, 1)
    }

    func testPopsItselfWhenPushedOnANavigationStack() {
        let navigation = UINavigationController(rootViewController: UIViewController())
        window.rootViewController = navigation
        let subject = screen()
        navigation.pushViewController(subject, animated: false)
        XCTAssertEqual(navigation.viewControllers.count, 2)

        subject.dismissSelf(animated: false)

        XCTAssertEqual(navigation.viewControllers.count, 1,
                       "a pushed screen should pop rather than try to dismiss")
        XCTAssertFalse(navigation.viewControllers.contains(subject))
    }

    func testRemovesItselfWhenEmbeddedAsAChild() {
        let host = window.rootViewController!
        let subject = screen()
        host.addChild(subject)
        subject.view.frame = host.view.bounds
        host.view.addSubview(subject.view)
        subject.didMove(toParent: host)
        XCTAssertNotNil(subject.parent)

        subject.dismissSelf(animated: false)

        XCTAssertNil(subject.parent, "an embedded screen should detach from its parent")
        XCTAssertFalse(host.view.subviews.contains(subject.view))
    }

    func testAnUncontainedScreenIsLeftAloneRatherThanCrashing() {
        // A host could make the SDK a window's root. There is nothing to
        // unwind there, and the important thing is that asking does not trap.
        let subject = screen()
        subject.dismissSelf(animated: false)
        XCTAssertNil(subject.presentingViewController)
    }

    // MARK: - present()

    func testPresentPutsAScreenUpWithNoHostWiring() {
        XCTAssertFalse(sdk.isPresenting)

        XCTAssertTrue(sdk.present(from: window.rootViewController!, animated: false))

        XCTAssertTrue(sdk.isPresenting)
        XCTAssertTrue(window.rootViewController?.presentedViewController is FanMakerSDKWebViewController,
                      "the host should not have had to build or place anything")
    }

    func testPresentsASheetByDefaultSoAFanIsNeverTrapped() {
        // This default is load-bearing. NUX draws no close button on its login
        // page, so a fan who opens the UI and does not want to sign in has no
        // way out of a full screen presentation - verified on a device. A sheet
        // means iOS supplies the way out.
        sdk.present(from: window.rootViewController!, animated: false)

        let shown = window.rootViewController?.presentedViewController
        XCTAssertEqual(shown?.modalPresentationStyle, .pageSheet)
        XCTAssertTrue(shown?.isModalInPresentation == false,
                      "an interactive dismissal must not be blocked")
    }

    @available(iOS 15.0, *)
    func testTheSheetIsFullHeightWithAGrabber() {
        // Full height because the content is a whole site, and a grabber
        // because that is the affordance the fan needs.
        sdk.present(from: window.rootViewController!, animated: false)

        let sheet = window.rootViewController?.presentedViewController?.sheetPresentationController
        XCTAssertNotNil(sheet)
        XCTAssertEqual(sheet?.detents, [.large()])
        XCTAssertEqual(sheet?.prefersGrabberVisible, true)
    }

    func testFullScreenIsAvailableAsAnOptIn() {
        sdk.presentationStyle = .fullScreen
        sdk.present(from: window.rootViewController!, animated: false)

        let shown = window.rootViewController?.presentedViewController
        XCTAssertEqual(shown?.modalPresentationStyle, .fullScreen)
    }

    // MARK: - the per-call style, which overrides the instance default

    func testFullScreenCanBePassedToTheCall() {
        sdk.present(from: window.rootViewController!, style: .fullScreen, animated: false)

        XCTAssertEqual(window.rootViewController?.presentedViewController?.modalPresentationStyle,
                       .fullScreen)
    }

    func testSheetCanBePassedToTheCallExplicitly() {
        sdk.present(from: window.rootViewController!, style: .sheet, animated: false)

        XCTAssertEqual(window.rootViewController?.presentedViewController?.modalPresentationStyle,
                       .pageSheet)
    }

    func testTheCallOverridesAnInstanceDefaultOfFullScreen() {
        // Asking for a sheet must win even when the instance was set the other
        // way, or the parameter is not really an override.
        sdk.presentationStyle = .fullScreen

        sdk.present(from: window.rootViewController!, style: .sheet, animated: false)

        XCTAssertEqual(window.rootViewController?.presentedViewController?.modalPresentationStyle,
                       .pageSheet)
    }

    func testOmittingTheStyleFallsBackToTheInstanceDefault() {
        sdk.presentationStyle = .fullScreen

        sdk.present(from: window.rootViewController!, animated: false)

        XCTAssertEqual(window.rootViewController?.presentedViewController?.modalPresentationStyle,
                       .fullScreen,
                       "omitting the parameter should defer to the instance, not hardcode a sheet")
    }

    func testSwipingTheSheetAwayStillTellsAHostTheUiClosed() {
        // A swipe never reaches the web content's close action, so without this
        // a host tracking state would be left believing the UI was still up.
        sdk.present(from: window.rootViewController!, animated: false)
        let screen = window.rootViewController?.presentedViewController as? FanMakerSDKWebViewController
        XCTAssertNotNil(screen)

        let notified = expectation(description: "close notification")
        let token = NotificationCenter.default.addObserver(
            forName: FanMakerSDK.closeSdk, object: sdk, queue: .main
        ) { note in
            let params = note.userInfo?["params"] as? [String: Any]
            XCTAssertEqual(params?["source"] as? String, "swipe")
            notified.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        // What UIKit calls when a fan completes the swipe.
        screen?.presentationControllerDidDismiss(screen!.presentationController!)

        wait(for: [notified], timeout: 5)
    }

    func testASecondPresentIsRefusedRatherThanStackingACopy() {
        let host = window.rootViewController!
        XCTAssertTrue(sdk.present(from: host, animated: false))

        XCTAssertFalse(sdk.present(from: host, animated: false),
                       "a double tap must not leave a fan two screens to dismiss")
    }

    func testPresentIsRefusedBeforeInitialize() {
        let uninitialized = FanMakerSDK()
        XCTAssertFalse(uninitialized.present(from: window.rootViewController!, animated: false),
                       "there is no site to show before an api key is set")
    }

    func testDismissTakesDownWhatPresentPutUp() {
        sdk.present(from: window.rootViewController!, animated: false)
        XCTAssertTrue(sdk.isPresenting)

        sdk.dismiss(animated: false)

        XCTAssertFalse(sdk.isPresenting, "the SDK should be able to close what it opened")
    }

    func testPresentingAgainWorksOnceTheFirstScreenIsGone() {
        let host = window.rootViewController!
        XCTAssertTrue(sdk.present(from: host, animated: false))
        sdk.dismiss(animated: false)

        XCTAssertTrue(sdk.present(from: host, animated: false),
                      "the one-screen rule must not block a later, legitimate open")
    }

    // MARK: -
    //
    // Two things are deliberately not covered here, because this is a logic
    // test bundle with no host application: UIApplication.connectedScenes is
    // empty, so the topmost-controller discovery that plain present() relies on
    // finds no window, and UIKit never completes a modal transition, so nothing
    // ever reaches a window. Those are exercised by running the sample app on a
    // simulator instead.
}

/// Guards the call shapes that existed before the style parameter, so adding it
/// stays a source-compatible change for anyone already calling present().
@available(iOS 13.0, *)
final class PresentationCallShapeCompatTests: XCTestCase {
    func testTheOlderCallShapesStillCompile() {
        let sdk = FanMakerSDK()
        sdk.initialize(apiKey: "call-shapes-\(UUID().uuidString)")
        let host = UIViewController()

        // No assertions: this is a compile-time guarantee. Each of these was a
        // valid call before `style:` existed and must remain one.
        if false {
            _ = sdk.present()
            _ = sdk.present(animated: false)
            _ = sdk.present(animated: false, completion: {})
            _ = sdk.present(from: host)
            _ = sdk.present(from: host, animated: false)
            _ = sdk.present(from: host, animated: false, completion: {})
            sdk.dismiss()
            sdk.dismiss(animated: false)
        }
        XCTAssertTrue(true)
    }
}
