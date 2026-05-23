# 🏢 Flutter Smart Workforce Management — Setup Guide

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | >= 3.19.0 | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart SDK | >= 3.3.0 | Bundled with Flutter |
| Android Studio | >= Flamingo | [developer.android.com](https://developer.android.com/studio) |
| Xcode | >= 15.0 | Mac App Store |
| CocoaPods | >= 1.14.0 | `sudo gem install cocoapods` |
| Java JDK | 17 | [adoptium.net](https://adoptium.net) |

---

## 1. Clone the Repository

```bash
git clone https://github.com/AvinashK123-A/flutter-smart-workforce-management.git
cd flutter-smart-workforce-management
```

---

## 2. Environment Configuration

```bash
# Copy environment template
cp .env.example .env

# Fill in your values in .env
nano .env
```

---

## 3. Firebase Setup

### Android
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create project or use existing
3. Add Android app with bundle ID: `com.avinash.workforce.management`
4. Download `google-services.json`
5. Replace: `android/app/google-services.json`

### iOS
1. Add iOS app with bundle ID: `com.avinash.workforce.management`
2. Download `GoogleService-Info.plist`
3. Replace: `ios/Runner/GoogleService-Info.plist`

---

## 4. Google Maps Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Enable: **Maps SDK for Android**, **Maps SDK for iOS**, **Places API**, **Geocoding API**
3. Create API keys (restrict to your bundle IDs)
4. Android: Update `android/app/google-services.json` or set `MAPS_API_KEY` in `.env`
5. iOS: Update `ios/Runner/Info.plist` → `GMSApiKey`

---

## 5. Android Setup

```bash
# Create debug keystore (for local development)
keytool -genkey -v \
  -keystore android/app/debug.keystore \
  -alias androiddebugkey \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -storepass android \
  -keypass android

# For release signing, create key.properties:
cat > android/key.properties << EOF
storeFile=release.keystore
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_KEY_PASSWORD
EOF
```

---

## 6. iOS Setup

```bash
# Install CocoaPods dependencies
cd ios
pod install --repo-update
cd ..
```

### iOS Entitlements (required for background location)
The app requires the **Background Location** capability. Ensure your provisioning profile includes:
- `com.apple.developer.associated-domains`
- `com.apple.developer.location.background` (if using UIBackgroundModes: location)

---

## 7. Flutter Setup

```bash
# Install Flutter dependencies
flutter pub get

# Generate code (Riverpod providers, Freezed models, Hive adapters)
flutter pub run build_runner build --delete-conflicting-outputs

# Verify setup
flutter doctor -v
```

---

## 8. Run the App

```bash
# Run in dev flavor (Android)
flutter run --flavor dev --target lib/main.dart

# Run in dev flavor (iOS)  
flutter run --flavor dev --target lib/main.dart -d iphone

# Run in QA flavor
flutter run --flavor qa --target lib/main.dart

# Production build — Android APK
flutter build apk \
  --flavor prod \
  --target lib/main.dart \
  --release \
  --obfuscate \
  --split-debug-info=build/debug-info

# Production build — iOS IPA
flutter build ipa \
  --flavor prod \
  --target lib/main.dart \
  --export-options-plist=ios/ExportOptions.plist

# Production build — Android App Bundle (for Play Store)
flutter build appbundle \
  --flavor prod \
  --target lib/main.dart \
  --release
```

---

## 9. Run Tests

```bash
# Unit tests
flutter test

# Unit tests with coverage
flutter test --coverage

# Generate HTML coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Widget tests
flutter test test/widget/

# Integration tests (requires device)
flutter test integration_test/
```

---

## 10. Build Flavors

| Flavor | App Name | Bundle ID Suffix | API URL |
|--------|----------|-----------------|---------|
| dev | Workforce Dev | .dev | dev-api.workforce.com |
| qa | Workforce QA | .qa | qa-api.workforce.com |
| uat | Workforce UAT | .uat | uat-api.workforce.com |
| prod | Workforce Manager | (none) | api.workforce.com |

---

## 11. Location Permissions (Runtime)

The app requires these permissions at runtime:

**Android:**
- `ACCESS_FINE_LOCATION` — GPS tracking
- `ACCESS_BACKGROUND_LOCATION` — Geofence monitoring (Android 10+)
- `FOREGROUND_SERVICE_LOCATION` — Background location service

**iOS:**
- "Always" location permission — Required for geofencing
- Motion & Fitness access — For commute detection

---

## 12. Project Structure

```
lib/
├── core/
│   ├── di/                  # Dependency injection (Riverpod providers)
│   ├── network/             # Dio client, interceptors
│   ├── router/              # GoRouter navigation
│   ├── theme/               # App theme, colors, typography
│   ├── constants/           # API constants, app constants
│   ├── error/               # Failure classes
│   └── utils/               # Extensions, helpers
├── features/
│   ├── attendance/          # Attendance check-in/out, history
│   ├── tracking/            # Live GPS tracking, geofence
│   ├── dashboard/           # Analytics dashboard
│   ├── tasks/               # Task assignment, management
│   ├── leave/               # Leave management
│   ├── reports/             # Report generation, export
│   └── auth/                # Login, session management
└── main.dart
```

---

## 13. CI/CD

GitHub Actions workflows are in `.github/workflows/flutter_ci.yml`.

Required GitHub Secrets:
- `ANDROID_KEYSTORE_BASE64` — Base64 release keystore
- `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`
- `GOOGLE_SERVICES_JSON` — Base64 google-services.json
- `GOOGLE_SERVICE_INFO_PLIST` — Base64 GoogleService-Info.plist
- `GOOGLE_MAPS_API_KEY` — Google Maps API key
- `IOS_P12_BASE64`, `IOS_P12_PASSWORD` — iOS distribution certificate
- `IOS_PROVISIONING_PROFILE_BASE64` — iOS provisioning profile
- `CODECOV_TOKEN` — Code coverage reporting

---

## 14. Troubleshooting

| Issue | Solution |
|-------|----------|
| `flutter doctor` shows Flutter not found | Add Flutter to PATH |
| `pod install` fails | Run `sudo gem install cocoapods && pod repo update` |
| Build fails: google-services.json missing | Replace placeholder with real Firebase config |
| Location not working in simulator | Use a real device for GPS/geofence testing |
| Background location rejected (iOS) | Ensure "Always" location permission granted, check UIBackgroundModes |
| Geofence not triggering | Minimum radius is 100m for reliable geofencing; test on physical device |
| `build_runner` errors | Delete `.dart_tool` folder and run again |

---

## 15. Support

- 📧 LinkedIn: [Avinash Reddy](https://www.linkedin.com/in/avinash-reddy-0826b0222/)
- 🐛 Issues: [GitHub Issues](https://github.com/AvinashK123-A/flutter-smart-workforce-management/issues)
- 📖 Wiki: [Project Wiki](https://github.com/AvinashK123-A/flutter-smart-workforce-management/wiki)
