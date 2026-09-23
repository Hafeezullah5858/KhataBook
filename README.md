# KhataBook v1.0.0

KhataBook is a Flutter business accounting, khata, car daily-rent and driver-earnings app for PKR users.

## Included in v1.0.0
- Dashboard with income, expense and profit
- Multiple businesses
- Personal/business khata contacts (customers, suppliers, drivers)
- Cars with driver and daily rent
- Ride-hailing platform earnings (inDrive, Yango, Ola/Uber and custom platforms)
- Fuel, maintenance and other expenses
- Cash, Bank, Easypaisa and JazzCash payment methods
- Monthly platform report
- Local device persistence

## GitHub APK build
`.github/workflows/android_build.yml` safely generates the Android wrapper only when the `android/` folder is missing, removes Flutter's generated default `widget_test.dart`, runs formatting/analyze/tests, and builds a release APK. The APK is available from the workflow's **Artifacts** section.

## Production hardening still required
This source is not presented as fully Play Store verified. Before public launch, complete authenticated cloud backup, encryption/security hardening, server-side rules, audit trail, Firebase App Check/Crashlytics, release signing/Play App Signing, migration tests, and real Android-device testing.
