import HotwireNative
import UIKit

/// The tab bar along the bottom of the app. Each tab keeps its own stack of
/// screens, so going back in one tab doesn't affect the others.
extension HotwireTab {
    static let all: [HotwireTab] = [.explore, .bookings, .account]

    static let explore = HotwireTab(
        title: "Explore",
        image: .init(systemName: "map")!,
        url: Bookem.rootURL
    )

    static let bookings = HotwireTab(
        title: "Bookings",
        image: .init(systemName: "calendar")!,
        url: Bookem.rootURL.appendingPathComponent("bookings")
    )

    static let account = HotwireTab(
        title: "Account",
        image: .init(systemName: "person.crop.circle")!,
        url: Bookem.rootURL.appendingPathComponent("account")
    )
}
