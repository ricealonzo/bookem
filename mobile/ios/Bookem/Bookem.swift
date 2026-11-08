import Foundation

/// Where the app loads Bookem from.
///
/// The app is a native shell around the Rails site: every screen is a page
/// from this server. Point it at your laptop while developing.
enum Bookem {
    static let production = URL(string: "https://bookem-4pho.onrender.com")!

    /// `bin/dev` on your Mac. The iOS Simulator can reach it as localhost.
    static let local = URL(string: "http://localhost:3000")!

    /// Change to `local` to try the app against your own server.
    static let rootURL = production
}
