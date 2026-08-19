# send-push

Sends push notifications via Firebase Cloud Messaging. Called from inside
Postgres (`atfal_notify()` in `007_push_notifications.sql`) whenever a task
is assigned, submitted, approved, or returned — never called directly by
the app.

## One-time setup

1. **Create a Firebase project** at console.firebase.google.com (free —
   the "Spark" plan is enough). Add an Android app and an iOS app to it
   using these exact package/bundle IDs:
   - Android: `com.atfaltech.atfal_taskboard`
   - iOS: `com.atfaltech.atfalTaskboard`

2. **Get the two platform config files** from the Firebase console and drop
   them in:
   - `mobile/android/app/google-services.json`
   - `mobile/ios/Runner/GoogleService-Info.plist`

3. **Generate `firebase_options.dart`** — easiest way is the FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   cd mobile
   flutterfire configure
   ```
   This overwrites the placeholder `mobile/lib/firebase_options.dart` with
   your project's real values and adds the native config automatically.

4. **Generate a service account key** — Firebase console → Project
   Settings → Service Accounts → "Generate new private key". This
   downloads a JSON file. Set its *entire contents* as an Edge Function
   secret (from the repo root):
   ```bash
   supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat path/to/the-key.json)"
   ```

5. **Deploy this function**:
   ```bash
   supabase functions deploy send-push
   ```

6. **Let Postgres call it** — in the SQL editor, store your project's
   `service_role` key (Project Settings → API → service_role) in Vault:
   ```sql
   select vault.create_secret('<service_role key>', 'supabase_service_role_key');
   ```

Until steps 4–6 are done, everything else in the app works normally —
`atfal_notify()` just silently skips sending (same fail-open pattern as the
approval email).
