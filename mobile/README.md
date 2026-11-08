# Bookem iOS and Android apps

Both apps are built with [Hotwire Native](https://native.hotwired.dev): a native shell (tab bar, top bar, back button, modals) around the Rails site. Every screen is a page from `https://bookem-4pho.onrender.com`, so most changes ship by deploying Rails, with no store update.

| | iOS | Android |
| --- | --- | --- |
| Folder | `mobile/ios` | `mobile/android` |
| Language | Swift | Kotlin |
| Needs | A Mac with Xcode, and `brew install xcodegen` | Android Studio (runs on Ubuntu, Mac or Windows) |
| App id | `com.ricealonzo.bookem` | `com.ricealonzo.bookem` |
| Store account | Apple Developer Program, $99 a year | Google Play Console, $25 once |

GitHub Actions builds both apps on every change (`.github/workflows/mobile.yml`), so you'll know the code compiles before you open it.

## Run the iOS app

```bash
brew install xcodegen
cd mobile/ios
xcodegen generate      # makes Bookem.xcodeproj from project.yml
open Bookem.xcodeproj
```

Pick an iPhone simulator at the top of Xcode and press Run (⌘R). To use your own laptop's server, set `rootURL = local` in `Bookem/Bookem.swift` and run `bin/dev`.

The Xcode project is generated, so change `project.yml` (not the project's settings screen) and run `xcodegen generate` again.

## Run the Android app

Open the `mobile/android` folder in Android Studio and press Run. To use your own laptop's server, set `ROOT_URL = LOCAL` in `Bookem.kt`. The emulator reaches your laptop at `10.0.2.2`. Debug builds allow plain `http://` for this (`app/src/debug/AndroidManifest.xml`); release builds stay HTTPS-only.

If Android Studio asks about the Gradle wrapper, let it create one, or run `gradle wrapper --gradle-version 9.2.0` in `mobile/android`.

## Getting into the App Store

1. **Join the Apple Developer Program** as an individual. It's $99 a year, and approval can take a day or two.
2. In `project.yml`, set `DEVELOPMENT_TEAM` to your Team ID (Xcode › Settings › Accounts), then run `xcodegen generate`.
3. In **App Store Connect**, create the app with the bundle id `com.ricealonzo.bookem`. If "Bookem" is taken, try something like "Bookem: Book Local Spots".
4. Fill in the listing:
   - Privacy policy URL: `https://YOUR-SITE/privacy`
   - Support URL: `https://YOUR-SITE/account`, or a contact page
   - Category: Lifestyle or Business
   - App Privacy answers: name, email and phone are collected for app functionality and linked to the user. Payments are handled by Stripe.
   - Screenshots: take them in the largest iPhone simulator (⌘S saves one).
5. **Give the reviewers a demo account** (a guest and a host login) in the review notes, and make sure the server is on. Apple can't review an app it can't sign in to.
6. In the notes, explain that payments are deposits for in-person appointments. Apple's guideline 3.1.3(e) says those must be paid outside in-app purchase, which is why the app uses Stripe.
7. In Xcode: set the scheme to "Any iOS Device", then Product › Archive › Distribute App › App Store Connect.
8. Test it with **TestFlight** on your own phone, then submit for review.

**Expect possible pushback under guideline 4.2 (Minimum Functionality).** Apple rejects apps that feel like a website in a frame. Bookem has a native tab bar, top bar and modals. Push notifications for booking requests (planned as step 5) are the strongest addition if Apple asks for more.

## Getting into Google Play

1. **Create a Play Console account** ($25 once) and verify your identity.
2. In Android Studio: Build › Generate Signed App Bundle. Create an **upload key** and keep the `.jks` file and its passwords somewhere safe, outside the repo. Losing it makes updates painful.
3. Create the app in Play Console. You'll need:
   - Store listing: a 512×512 icon, a 1024×500 feature graphic and phone screenshots
   - Privacy policy URL: `https://YOUR-SITE/privacy`
   - Data safety form: name, email and phone collected for app functionality; payments handled by Stripe
   - Content rating questionnaire, and target audience (adults)
4. **New personal accounts must run a closed test first:** at least 12 testers, opted in for 14 days in a row, before you can apply for production. Start it as early as possible. Your pilot shops, their regulars and friends with Android phones all count.
5. Upload the `.aab` to the closed testing track, share the opt-in link, wait the 14 days, then apply for production access.

For every update, raise `versionCode` in `app/build.gradle.kts` (Android) and `CURRENT_PROJECT_VERSION` in `project.yml` (iOS).
