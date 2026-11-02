# IT-ILMS mobile

Flutter app (Android first) for the IT-ILMS learning system. It is a second client of the same backend: every call goes through the API gateway, and all authorization is enforced by the services, so the menu only hides what a role cannot use.

## What it covers

Students: dashboard, courses and lessons, progress, live classes (LiveKit), tests and assignments, fees, certificates, placements, files, ID card, announcements, notifications, account.
Admin, coordinator and trainer: students, batches with sessions and attendance, live classes, dashboard summary.
Not on mobile: secure (camera or lock-down) tests, which stay on the desktop app; setup screens (admissions, fee plans, question bank, branding, users), which stay on the web app.

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<PC-LAN-IP>:8080
```

The default `http://10.0.2.2:8080` reaches the PC from the Android emulator only. A real phone needs the PC's LAN address, and the LiveKit server URL returned by the backend must be reachable from the phone too.

## Build

```bash
flutter build apk --debug      # build/app/outputs/flutter-apk/app-debug.apk
flutter build appbundle        # Play Store bundle
```

- Needs JDK 17 (point Flutter at it with `flutter config --jdk-dir`).
- If Gradle downloads time out on an IPv6-only network, fetch the Gradle zip with `curl` into `$GRADLE_USER_HOME/wrapper/dists/...` and run the build with `JAVA_TOOL_OPTIONS=-Djava.net.preferIPv6Addresses=true` set for that shell only.
- Plain `http` is allowed in debug builds only; a release build needs an `https` gateway.

## Release signing

Create a keystore once and keep it out of Git (`key.properties` and `*.jks` are ignored):

```bash
keytool -genkey -v -keystore ~/itilms-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then add `android/key.properties`:

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=C:/path/to/itilms-upload.jks
```

Without that file a release build is signed with the debug key, which is fine for trying it, not for the Play Store.

## Layout

`lib/core` (API client, env, downloads), `lib/auth` (session, models), `lib/screens` (one file per feature), `lib/widgets` (shared loading, error and empty states), `lib/nav_items.dart` (role-wise menu, mirrors the web `nav-items.ts`).
