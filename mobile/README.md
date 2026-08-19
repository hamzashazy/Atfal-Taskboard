# Atfal Taskboard — Flutter app (Android & iOS)

Native mobile port of the Atfal Taskboard web app. Talks to the **same
Supabase backend** as the website (same RLS-guarded reads, same
token-validated `atfal_*` SQL functions), so web and app users share all
data and accounts.

## Screens

| Screen | Who | Mirrors web route |
|---|---|---|
| Dashboard | Signed-in users | `/` — stat tiles, city leaderboard, task × city matrix, activity feed |
| Sign in | — | `/login` |
| Request access | — | `/signup` — city heads without an account request one; an admin approves |
| City portal | City heads | `/city` — To Do / History / My Account (profile + password) tabs |
| Admin portal | Markaz admins | `/admin` — New Task / Review / All Tasks / Cities / Users / Signups tabs, WhatsApp share |

Sessions persist across app restarts (`shared_preferences`). The app opens
straight into a signed-in user's portal, and straight into the login screen
otherwise — the dashboard requires an account, same as every other screen.

## Code map

```
lib/
  main.dart              app shell, theme (emerald, matching the site), routes
  models.dart            data models (mirrors src/lib/types.ts)
  meta.dart              labels, palette, date formatting, overdue logic (mirrors src/lib/meta.ts)
  api.dart               Supabase client, RPC wrapper, session persistence (mirrors src/lib/{supabase,session,api}.ts)
  push.dart              FCM push notifications — token registration, foreground display (see setup below)
  firebase_options.dart  PLACEHOLDER — replace via `flutterfire configure` (see push setup below)
  widgets.dart           chips, cards, form styling, skeletons, empty states (mirrors Chips.tsx + globals.css)
  screens/
    dashboard_screen.dart
    login_screen.dart
    signup_screen.dart
    city_screen.dart
    admin_screen.dart
```

The Supabase URL/anon key are baked into `lib/api.dart` (the anon key is
public by design; RLS is the security boundary). `siteUrl` in the same file
is only used in the WhatsApp share message — update it if the Vercel URL
changes.

## Push notifications

`lib/push.dart` registers this device with the backend and shows foreground
notifications, but nothing actually sends until Firebase is set up — see
`supabase/functions/send-push/README.md` at the repo root for the full
walkthrough (create a Firebase project, run `flutterfire configure`, deploy
the Edge Function, set two secrets). Until then the app works completely
normally; push just silently stays off.

The app icon (`android/`, `ios/` launcher icons) is generated from
`assets/icon/icon.png` via `flutter_launcher_icons` — after changing that
image, regenerate with `dart run flutter_launcher_icons`.

## Run & build

```bash
flutter pub get
flutter run                      # on a connected device / emulator

flutter build apk --release      # Android APK (build/app/outputs/flutter-apk/)
flutter build appbundle          # Android App Bundle for Play Store
flutter build ipa                # iOS (requires macOS + Xcode)
```

For Play Store release, replace the default debug signing config in
`android/app/build.gradle.kts` with a real upload keystore. iOS builds must
be done on a Mac with an Apple Developer account configured in Xcode.
