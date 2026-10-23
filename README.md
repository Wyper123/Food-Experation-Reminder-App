# Food Reminder

A Flutter app for Android that tracks the food in your kitchen and reminds you before it expires: what to use first, what has expired, and what to buy next.

Accounts use Firebase Authentication. Everything else (food, grocery list, household, reminders) is stored in SQLite on the phone, so the app keeps working offline once you are signed in.

## Features

**Accounts**
- Sign up and log in with email and password, or with **Continue with Google**.
- **Forgot password?** sends a reset link by email (sent by Firebase).
- Stays signed in between launches; change password from Profile.
- A failed sign-up removes the half-created online account, so no orphan accounts are left behind.

**Dashboard**
- Counters for *Expiring soon*, *Expired* and *Total stored*; tap one to open the inventory filtered to it.
- A **Use first** list of food that is expired or expires within 3 days, with quick actions: mark consumed or discarded (with Undo), or add to the grocery list.

**Inventory**
- Search, filter by storage (Fridge, Freezer, Pantry, Cabinet) and status (Use soon, Expired, Used up), and sort by expiration date, name or date added.
- Add and edit food with validation: expiration can't be before purchase, and purchase and opening dates can't be in the future.
- Categories are typed freely, with suggestions from built-in categories and ones you have used before.
- **Scan date via camera:** on-device text recognition (Google ML Kit, works offline) reads expiry dates such as `EXP 12/05/26`, `BEST BEFORE 05 DEC 2026` or `DEC 2026`. It prefers dates next to EXP, BB or USE BY, skips MFG and PKD dates, and asks you to confirm.
- Food detail view with status updates (available, consumed, discarded) and delete.

**Grocery list**
- Add, edit, tick and delete items, grouped by priority, each with an optional category.
- **Move to inventory:** a review screen pre-fills an estimated expiry date from a shelf-life table (by category and storage). Quantities like `2 L` or `500g` are split into amount and unit. Everything moves in one database transaction.

**Reminders**
- Phone notifications before expiry (choose 0–7 days ahead and the time of day), on the expiry day, and optionally the day after.
- Rescheduled automatically whenever food or settings change, and restored after the phone restarts.
- An in-app alerts inbox, plus a test-notification button.

**Household**
- Each new account gets a personal kitchen. Others join with an invite code (for example `FRESH-7KQ2MX`), which can be shared through the phone's share sheet.
- Admins can rename the household, create a new invite code, change members' roles (Admin, Roommate, Family Member) and remove members.
- Members can leave. A household is never left without an admin.

**Profile and settings**
- Theme: System, Light or Dark.
- Default storage for new food, reminder settings, CSV export of the inventory (opens in Excel or Google Sheets), and profile editing.

**Design**
- Material 3 with shimmer skeletons while data loads.
- Text and icon colours meet WCAG AA contrast (4.5:1) in both light and dark themes, enforced by a test.
- Layouts are checked at a 360dp phone width.

## Limitations

- **Food data lives on one phone.** Accounts are online, but inventory, groceries and households are stored locally. Signing in on another phone, or after reinstalling, starts with an empty kitchen there. Household sharing only works between accounts on the same phone.
- **No automatic backup.** Use *Profile → Export inventory* to keep a CSV copy.
- **No email verification** at sign-up.
- **Reminders may arrive a few minutes late.** They use Android's battery-friendly scheduling, which needs no "exact alarm" permission.
- **Camera scanning reads Latin-script text only.**
- **Built and tested for Android.** iOS is not configured or tested.

## Download

Every push to `main` builds a signed release APK on GitHub:

1. Open the repository's **Actions** tab, then the latest **Build release APK** run. You must be signed in to GitHub to download.
2. Download **food-reminder-main-release-apk** under *Artifacts*, unzip it, and install `app-release.apk` on the phone (allow installing from this source if asked).

All builds are signed with the same key, so a new APK installs over the old one and keeps the data.

The tag `v1.0.0` marks the earlier, fully local version, which kept accounts in SQLite instead of Firebase.

## Tech stack

| Area | Packages / services |
|---|---|
| UI | Flutter 3.47 (Material 3), `google_fonts`, `shimmer`, `flutter_svg` |
| State | `provider` (ChangeNotifier controllers) |
| Local data | `sqflite` (schema version 2 with migrations), `shared_preferences` |
| Accounts | Firebase Authentication through its **REST API**, `google_sign_in` |
| Reminders | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Scanning | `camera`, `image_picker`, `google_mlkit_text_recognition` |
| Other | `share_plus`, `intl`, `uuid` |

**Why the REST API rather than the `firebase_auth` SDK:** on Wi-Fi networks with broken IPv6, the Firebase Android SDK waited for minutes and never connected. Dart's own HTTP client falls back to IPv4 the way a browser does, so login works on those networks too.

## Project structure

```
lib/
├── main.dart                 # startup; shows an error screen instead of freezing
├── app.dart                  # provider wiring; controllers follow the session
├── core/                     # theme, colours, validators, shared widgets, parsers
├── data/
│   ├── local/                # DatabaseHelper (schema + migrations), DAOs, preferences
│   └── models/
└── features/
    ├── auth/                 # REST auth service, session, login/register, reset
    ├── dashboard/
    ├── food_inventory/       # inventory, add/edit, detail, camera scan, date parser
    ├── grocery_list/         # list, edit dialog, move-to-inventory review
    ├── household/
    ├── navigation/           # bottom-tab shell
    ├── notifications/        # alerts inbox, reminder planner/scheduler/sync
    └── profile/
```

Screens read from controllers; controllers talk to DAO interfaces (SQLite implementations in `data/local/daos`). Each DAO has a matching interface, so tests can substitute in-memory or fake versions.

## Getting started

**Requirements:** Flutter 3.47 (Dart 3.13) and an Android phone or emulator. The app does not run in a web browser.

```bash
flutter pub get
flutter run            # with a phone connected (USB or wireless debugging)
flutter test           # unit and widget tests; no internet needed
```

The tests use an in-memory SQLite database (`sqflite_common_ffi`) and an offline stand-in for Firebase (`test/test_helpers.dart`).

### Firebase

`android/app/google-services.json` (project `food-reminder-16bfe`) is included. To use your own Firebase project:

1. Create a project, enable **Email/Password** and **Google** sign-in, and register the Android app `com.giancoronel.foodreminder` with your signing key's SHA-1 and SHA-256.
2. Replace `android/app/google-services.json` with your project's file.
3. Put the same project's web API key in `lib/core/constants/firebase_config.dart`.

### Signing

Debug and release builds are signed with one permanent upload key, read from:
- `android/key.properties` on a developer machine (git-ignored; it holds `storeFile`, `storePassword`, `keyAlias` and `keyPassword`), or
- environment variables from GitHub secrets in CI.

Without either, builds fall back to the standard debug key. They still run, but cannot update an installed copy signed with the permanent key.

### Releases (GitHub Actions)

`.github/workflows/build-release-apk.yml` runs on pushes to `main` and `v2`: it runs `flutter test`, then builds the release APK. Signing needs these repository secrets:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the keystore file, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_KEY_ALIAS` | key alias |

Release builds shrink code with R8 but don't obfuscate it (see `android/app/proguard-rules.pro`). Several plugins call Android code by name, and renaming broke them.

### Notes for Windows developers

- **Windows Smart App Control** can block Flutter's release compiler (`gen_snapshot`), so local `flutter build apk --release` fails. Debug builds work; use the GitHub Actions build for release APKs.
- Regenerate the launcher icons from `assets/icon/` with Flutter's own Dart: `dart run flutter_launcher_icons`.
