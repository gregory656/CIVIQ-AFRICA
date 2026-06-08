# SIVIQ Firebase App Distribution

This project uses Firebase App Distribution for Android tester installs.

## Firebase Details

- Firebase project ID: `siviq-68850`
- Firebase project name: `SIVIQ`
- Android package name: `com.siviq.africa`
- Android Firebase app ID: `1:156183317916:android:3300a249ab4a965e1c4c59`
- Tester group alias: `siviq-team`
- Firebase login account on this machine: `gregorystephen2006@gmail.com`

Do not put Google passwords in commands, scripts, or this file. Firebase CLI uses browser login/token auth.

## Tester Group

The Firebase App Distribution group `siviq-team` exists and has 4 testers:

```text
gregorysteve656@gmail.com
lenox11458@gmail.com
janetkutai@gmail.com
khayadistephen@gmail.com
```

There is also an accidental empty group alias `siviq-team-1`. Ignore it or delete it from Firebase Console later.

## Build And Upload

Run these from the Flutter project root:

```bash
flutter pub get
flutter build apk --release
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app 1:156183317916:android:3300a249ab4a965e1c4c59 \
  --groups siviq-team \
  --project siviq-68850 \
  --release-notes "SIVIQ internal Android test build"
```

On Windows PowerShell, this is the same command:

```powershell
flutter pub get
flutter build apk --release
firebase appdistribution:distribute build\app\outputs\flutter-apk\app-release.apk `
  --app 1:156183317916:android:3300a249ab4a965e1c4c59 `
  --groups siviq-team `
  --project siviq-68850 `
  --release-notes "SIVIQ internal Android test build"
```

## Copy The Install Link

After the upload finishes:

1. Open `https://console.firebase.google.com/project/siviq-68850/appdistribution`.
2. Select the Android app.
3. Open the newest release.
4. Copy the tester/release link from the release page.
5. Send that link to the team by WhatsApp or email.

Firebase will also email the testers automatically when the release is distributed to `siviq-team`.

## Current Status From This Setup Attempt

- `android/app/google-services.json` is present.
- The JSON matches package `com.siviq.africa`.
- The JSON matches Firebase app ID `1:156183317916:android:3300a249ab4a965e1c4c59`.
- Firebase CLI is logged in as `gregorystephen2006@gmail.com`.
- Firebase project `siviq-68850` is accessible.
- Tester group `siviq-team` exists with 4 testers.
- Release build got stuck locally in Gradle/Flutter/Kotlin and did not produce `app-release.apk`.
- A large existing debug APK exists at `build/app/outputs/flutter-apk/app-debug.apk`.
- Uploading that debug APK through Firebase CLI failed with `ECONNRESET`, likely because the APK is large and the network reset during upload.

## If Release Build Hangs Again

Stop Gradle daemons:

```powershell
cd android
.\gradlew.bat --stop
cd ..
```

Then retry:

```powershell
flutter clean
flutter pub get
flutter build apk --release
```

If upload fails because of connection reset, retry the upload on a stronger connection:

```powershell
firebase appdistribution:distribute build\app\outputs\flutter-apk\app-release.apk `
  --app 1:156183317916:android:3300a249ab4a965e1c4c59 `
  --groups siviq-team `
  --project siviq-68850 `
  --release-notes "SIVIQ internal Android test build"
```

## Emergency Debug Upload

Only use this if you need a quick internal test and a release APK is not available:

```powershell
firebase appdistribution:distribute build\app\outputs\flutter-apk\app-debug.apk `
  --app 1:156183317916:android:3300a249ab4a965e1c4c59 `
  --groups siviq-team `
  --project siviq-68850 `
  --release-notes "SIVIQ internal Android debug test build"
```

Debug APKs are larger and not production-style builds. Prefer the release APK whenever the build completes.
