import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.ricealonzo.bookem"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.ricealonzo.bookem"
        minSdk = 28
        targetSdk = 35
        // Raise versionCode by 1 for every upload to Google Play.
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        named("main") { java { srcDirs("src/main/kotlin") } }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(17)
    }
}

dependencies {
    // Hotwire Native: https://native.hotwired.dev
    implementation("dev.hotwire:core:1.4.1")
    implementation("dev.hotwire:navigation-fragments:1.4.1")

    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.constraintlayout:constraintlayout:2.2.1")
}
