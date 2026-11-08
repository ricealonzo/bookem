package com.ricealonzo.bookem

/**
 * Where the app loads Bookem from. Every screen is a page from this server.
 */
object Bookem {
    const val PRODUCTION = "https://bookem-4pho.onrender.com"

    /** `bin/dev` on your computer, as the Android emulator sees it. */
    const val LOCAL = "http://10.0.2.2:3000"

    /** Change to LOCAL to try the app against your own server. */
    const val ROOT_URL = PRODUCTION
}
