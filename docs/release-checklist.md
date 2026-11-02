# Release checklist

How to send a build to TestFlight, and later the App Store. Kept short on purpose: run it top to bottom every time.

## Once, before the first upload (needs the paid Apple Developer Program)

1. **Join the Apple Developer Program** (£79 a year) with the Apple ID the app will be published under.
2. **Sign in to Xcode** with that Apple ID (Xcode, Settings, Accounts). You type the password yourself.
3. **Set the team.** Put the team ID in `Configs/Signing.local.xcconfig` as `DEVELOPMENT_TEAM = ...`, then run `./Scripts/gen-project.sh`. Xcode's automatic signing registers the app IDs, the App Group and the Time Sensitive Notifications capability.
4. **Create the app in App Store Connect** with the bundle ID `com.liamdaly.missioncontrol`, the name from `docs/store/app-store-listing.md`, and the primary language English (UK).
5. **Fill in "Test Information"** from `docs/store/testflight.md`, once the contact email and dates are set.
6. **Before anyone outside the family tests it:**
   - send each tester the notice in `docs/store/testflight.md`;
   - write a short data protection impact assessment;
   - check whether the ICO fee is due, since TestFlight shares testers' details with us;
   - get the regulatory adviser's view in `docs/regulatory/mhra-qualification-note.md`.

## Every upload

1. **Bump the build number.** Raise `CURRENT_PROJECT_VERSION` in `project.yml` by one (App Store Connect refuses a number it has seen). For a new version, also raise `MARKETING_VERSION`. Then run `./Scripts/gen-project.sh`.
2. **Run every check:**
   - `swift format lint --strict --recursive Package.swift Sources Tests Apps`
   - `swiftlint lint --strict`
   - `swift test`
   - `python3 -I Scripts/content-lint.py`
   - `python3 -I Scripts/claims-lint.py`
   - `python3 -I -m unittest discover -s Scripts -p 'test_*.py'`
   - the iPhone app tests and the watch tests, as in `.github/workflows/ci.yml`
3. **Read the safety and regulatory documents again:**
   - `docs/safety/hazard-log.md`: every control still in place?
   - `docs/regulatory/intended-purpose.md`: does anything new go beyond it?
   - the NHS sources: are they still current?
4. **Archive and upload.** In Xcode, choose "Any iOS Device" and use Product, Archive. Then in the Organizer, choose Distribute App, App Store Connect, Upload. The watch app and the widget go inside the same archive.
5. **In App Store Connect,** add the build to the test group once it has finished processing. The export compliance question is already answered by the app's Info.plist (`ITSAppUsesNonExemptEncryption` is NO: the app only uses Apple's own encryption).

## Before the App Store (not TestFlight)

- Run the content lint with `--release`, which needs a midwife's sign-off on every clinical item.
- Sign-off from the clinical safety officer on the hazard log.
- An in-app "Report a safety concern" route, the privacy policy online, and the support URL.
- The answers in `docs/store/app-store-listing.md`, including the medical device declaration.
