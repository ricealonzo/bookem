package com.ricealonzo.bookem

import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomTab

// The tab bar along the bottom. Each tab has its own NavigatorHost in
// activity_main.xml, so each keeps its own stack of screens.

private val explore = HotwireBottomTab(
    title = "Explore",
    iconResId = R.drawable.ic_tab_explore,
    configuration = NavigatorConfiguration(
        name = "explore",
        navigatorHostId = R.id.explore_navigator_host,
        startLocation = Bookem.ROOT_URL
    )
)

private val bookings = HotwireBottomTab(
    title = "Bookings",
    iconResId = R.drawable.ic_tab_bookings,
    configuration = NavigatorConfiguration(
        name = "bookings",
        navigatorHostId = R.id.bookings_navigator_host,
        startLocation = "${Bookem.ROOT_URL}/bookings"
    )
)

private val account = HotwireBottomTab(
    title = "Account",
    iconResId = R.drawable.ic_tab_account,
    configuration = NavigatorConfiguration(
        name = "account",
        navigatorHostId = R.id.account_navigator_host,
        startLocation = "${Bookem.ROOT_URL}/account"
    )
)

val mainTabs = listOf(explore, bookings, account)
