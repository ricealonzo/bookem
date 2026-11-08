import HotwireNative
import UIKit

/// Sets up the window with the tab bar, and handles pages that fail to load.
final class SceneController: UIResponder {
    var window: UIWindow?

    private lazy var tabBarController = HotwireTabBarController(
        navigatorDelegate: self,
        lazyLoadTabs: true
    )
}

extension SceneController: UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        tabBarController.load(HotwireTab.all)
    }
}

// Hotwire's default NavigatorDelegate behavior is what Bookem wants: accept
// every visit, and show the built-in error screen with a Retry button when a
// page fails to load (offline, or the server waking up). Override methods
// here later, for example to open a native screen for a path.
extension SceneController: NavigatorDelegate {}
