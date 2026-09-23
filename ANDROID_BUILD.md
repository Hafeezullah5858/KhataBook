# Android build
This source project is intended to be opened/generated with Flutter stable.
From the project directory run:

flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release

If the Android platform folder is missing in your local Flutter environment, run `flutter create .` once before the build; it generates the standard Android wrapper without changing lib/ or pubspec.yaml.
