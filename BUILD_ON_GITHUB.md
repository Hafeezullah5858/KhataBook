# KhataBook — GitHub Android Build

This project is prepared for a GitHub Actions Android APK build.

The workflow creates the standard Flutter Android project on the GitHub runner, then runs flutter pub get, flutter analyze, flutter test, and flutter build apk --release.

The generated APK is published in the workflow run under Artifacts as `KhataBook-release-apk`.

This is a build-ready development release, not a claim of Play Store production verification. Before public financial-data launch, complete authenticated cloud backup, encryption/security hardening, audit trail, Firebase App Check/Crashlytics, release signing/Play App Signing, migration testing, and real-device testing.
