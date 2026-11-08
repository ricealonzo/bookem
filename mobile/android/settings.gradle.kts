// Google's copy of Maven Central comes first: the Kotlin compiler jar on
// Maven Central redirects to GitHub, which sometimes times out on CI.
val mavenCentralMirror = "https://maven-central.storage-download.googleapis.com/maven2/"

pluginManagement {
    repositories {
        google()
        maven("https://maven-central.storage-download.googleapis.com/maven2/")
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version ("0.10.0")
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        maven(mavenCentralMirror)
        mavenCentral()
    }
}

rootProject.name = "Bookem"
include(":app")
