package com.ricealonzo.bookem

import android.app.Application
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.logging.HotwireLogLevel
import dev.hotwire.core.turbo.config.PathConfiguration

class BookemApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Lets the Rails app tell that a page is opened inside the app.
        Hotwire.config.applicationUserAgentPrefix = "Bookem Android;"

        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG
        Hotwire.config.logger.logLevel = if (BuildConfig.DEBUG) HotwireLogLevel.DEBUG else HotwireLogLevel.NONE

        // How to show each URL. The copy inside the app is used first; the
        // server's copy replaces it once downloaded.
        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                assetFilePath = "json/path-configuration.json",
                remoteFileUrl = "${Bookem.ROOT_URL}/configurations/android_v1.json"
            )
        )
    }
}
