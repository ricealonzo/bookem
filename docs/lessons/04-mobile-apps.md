# Lesson 4: iOS and Android apps with Hotwire Native

**Branch:** `mobile-apps` (built on top of `niche-presets`)
**Why it matters:** Business owners live on their phones. An app in the App Store and Google Play makes Bookem look like a real product, and "shipped a Rails app to both app stores" is a rare line on a junior developer's resume.

## The big idea: one app, three places

Writing a separate iPhone app in Swift and Android app in Kotlin means building every screen three times (web, iOS, Android). **Hotwire Native** takes a different approach:

```
┌─────────────── Native (Swift / Kotlin) ───────────────┐
│  top bar with title and back button                    │
│ ┌────────────────────────────────────────────────────┐ │
│ │                                                    │ │
│ │     a page from your Rails app, in a web view      │ │
│ │     (the same HTML and CSS as the website)         │ │
│ │                                                    │ │
│ └────────────────────────────────────────────────────┘ │
│   Explore      Bookings      Account     ← tab bar     │
└────────────────────────────────────────────────────────┘
```

The phone draws the native parts (tab bar, top bar, back swipe, modals) and Rails draws the content. When you fix a bug in Rails and deploy, both apps get the fix at once, with no app store review. 37signals runs Basecamp and HEY this way.

The trick that makes it feel native is **Turbo**. Bookem already uses it on the web. In the app, each link tap becomes a new native screen pushed onto the stack, instead of the web view loading a new page.

## What changed, file by file

### 1. Rails knows when it's inside the app

`ApplicationController#native_app?` checks the **user agent**, the line of text every browser sends to describe itself. Hotwire Native adds `Hotwire Native iOS;` or `Hotwire Native Android;`, and our apps also add `Bookem iOS;` / `Bookem Android;` (`applicationUserAgentPrefix`).

`helper_method :native_app?` makes it usable in views too. The layout uses it to:

- hide the web header and footer, because the app has its own tab bar
- shorten `<title>`, because Hotwire shows the page title in the native top bar ("Privacy", not "Privacy | Bookem")

### 2. Path configuration: how each URL is shown

`ConfigurationsController` serves `/configurations/ios_v1.json` and `/configurations/android_v1.json`. These are rules the apps follow:

```json
{ "patterns": ["/new$", "/edit$", "/users/sign_in$"],
  "properties": { "context": "modal", "pull_to_refresh_enabled": false } }
```

"Any URL ending in `/new` slides up as a modal." Forms feel native, and when the form redirects after saving, the modal closes by itself.

Each app ships a **copy** of these rules (`mobile/ios/Bookem/path-configuration.json` and `mobile/android/app/src/main/assets/json/path-configuration.json`) for the first launch, then downloads the server's version. You can change how the app behaves by deploying Rails, without resubmitting to the stores. `spec/requests/mobile_app_spec.rb` checks that the copies match the server, so they can't drift apart.

Android rules also need `"uri": "hotwire://fragment/web"`, which names the native screen that shows web pages. iOS doesn't need it.

### 3. The iOS app (`mobile/ios`)

| File | What it does |
| --- | --- |
| `Bookem.swift` | The server URL. Switch to `local` to test against `bin/dev` |
| `AppDelegate.swift` | Runs once at launch: loads the path configuration, sets the user agent prefix and look |
| `SceneController.swift` | Creates the window and the `HotwireTabBarController` |
| `Tabs.swift` | The three tabs: title, SF Symbol icon, and start URL |
| `project.yml` | XcodeGen spec: bundle id, iOS version, permissions text, the Hotwire Native package |

**Why XcodeGen?** An `.xcodeproj` is a huge machine-written file that's painful to review and merge. `project.yml` is about 60 readable lines, and `xcodegen generate` builds the project from it. The generated project is in `.gitignore`.

`NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` are the sentences iOS shows when the photo upload on the location form asks for permission. Without them, the app crashes the moment a host taps "Choose file".

### 4. The Android app (`mobile/android`)

| File | What it does |
| --- | --- |
| `Bookem.kt` | The server URL (`10.0.2.2` is your laptop, as the emulator sees it) |
| `BookemApplication.kt` | Runs once at launch: path configuration, user agent prefix, logging |
| `MainActivity.kt` | Sets up the bottom tab bar with `HotwireBottomNavigationController` |
| `MainTabs.kt` | The three tabs; each has its own `NavigatorHost` so each keeps its own back stack |
| `res/layout/activity_main.xml` | One `NavigatorHost` per tab, plus the `BottomNavigationView` |
| `app/build.gradle.kts` | App id, SDK levels, and the `dev.hotwire` libraries |

`app/src/debug/AndroidManifest.xml` allows plain `http://` **only in debug builds**, so you can test against your laptop while release builds stay HTTPS-only. Android merges this file into the main manifest when it builds a debug app.

### 5. The new Rails pages

- **`/account`**: the Account tab. Everything that lives in the web header, as a list.
- **`/privacy`**: both stores require a privacy policy URL. It lists what Bookem collects, who sees it, and how to delete your account. It's a starting draft, not legal advice: read it and adjust it to how you actually run things.
- **Account deletion** already existed on the profile page. Apple requires apps that let you create an account to also let you delete it in the app (guideline 5.1.1(v)).

### 6. CI that builds phone apps: `.github/workflows/mobile.yml`

Your laptop can't build an iPhone app without a Mac, but GitHub can. The `ios` job runs on a macOS machine: it installs XcodeGen, generates the project, builds for the simulator, then launches the app and takes a screenshot. The `android` job builds a debug `.apk` on Linux. Both run only when files under `mobile/` change.

## Try it

**Android (works on your Ubuntu laptop):** install Android Studio, open `mobile/android`, create an emulator (Device Manager › a Pixel phone), and press Run.

**iOS (needs a Mac):** `brew install xcodegen`, then `cd mobile/ios && xcodegen generate && open Bookem.xcodeproj`, pick an iPhone simulator, and press Run.

Things to check on a real phone before submitting:
- Sign in, sign out, and sign up from the Account tab
- Request a booking, and pay a test deposit (Stripe's page opens and comes back)
- Upload a location photo (the permission prompt appears)
- "Delete my account" on Edit profile shows its confirmation

## Check your understanding

1. How does the Rails app know a request came from the iPhone app?
2. You want `/payouts` to open as a modal. Where do you change that, and do you need an app store update?
3. Why does each Android tab need its own `NavigatorHost`?
4. Why is the Xcode project generated instead of committed?

## How to talk about it in an interview

> "I shipped iOS and Android apps for my Rails booking platform with Hotwire Native. The server drives navigation through path configuration, so screens and modal behavior change with a Rails deploy, not a store release. I generate the Xcode project from a spec with XcodeGen, and CI builds both apps and runs the iOS one in a simulator on every change."
