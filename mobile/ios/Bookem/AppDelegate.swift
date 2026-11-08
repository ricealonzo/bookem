import HotwireNative
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureAppearance()
        configureHotwire()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    /// Solid top and tab bars, tinted Bookem green.
    private func configureAppearance() {
        UINavigationBar.appearance().scrollEdgeAppearance = .init()
        UITabBar.appearance().scrollEdgeAppearance = .init()
        UIView.appearance().tintColor = UIColor(named: "AccentColor")
    }

    private func configureHotwire() {
        // How to show each URL (modal or not, and so on). The copy inside the
        // app is used first; the server's copy replaces it once downloaded.
        Hotwire.loadPathConfiguration(from: [
            .file(Bundle.main.url(forResource: "path-configuration", withExtension: "json")!),
            .server(Bookem.rootURL.appendingPathComponent("configurations/ios_v1.json"))
        ])

        // Lets the Rails app tell that a page is opened inside the app.
        Hotwire.config.applicationUserAgentPrefix = "Bookem iOS;"

        Hotwire.config.backButtonDisplayMode = .minimal
        Hotwire.config.showDoneButtonOnModals = true
        Hotwire.config.hideTabBarWhenPushed = true
#if DEBUG
        Hotwire.config.debugLoggingEnabled = true
#endif
    }
}
