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

    func testPresentUsesFullScreenRatherThanASheet() {
        // A partial-height sheet would break the full-bleed presentation the
        // integration checklist asks for, and NUX draws its own chrome.
        sdk.present(from: window.rootViewController!, animated: false)

        let shown = window.rootViewController?.presentedViewController
        XCTAssertEqual(shown?.modalPresentationStyle, .fullScreen)
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
