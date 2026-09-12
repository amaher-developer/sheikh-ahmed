# Project rules — Sheikh Ahmed (Flutter)

- **No tests.** Do not write tests of any kind (widget, unit or integration) and do not create a `test/` folder. Verify changes with `flutter analyze`, builds and running the app instead, and do not add test-only code such as `@visibleForTesting` hooks.
- **Project tracking.** Keep `project_tracking.md` at the repository root up to date, written in English. It is the source of truth for status, decisions, backlog and the handoff between chats — read it first when starting work.
- **Communication.** The owner writes in Egyptian Arabic, so reply in Arabic. Project documents stay in English.

## Current work

First App Store release. The first submission (1.14.0, build 31) was rejected by App Review; the fix is being worked out with the owner on `main` (the `ios/app-store-release` branch is merged and no longer used; `pubspec.yaml` is 1.16.1+36: the Android-only commit set 1.16.1+35 and the build number was bumped for the iOS resubmission). The Android app is already live on Google Play. Continue from `project_tracking.md` → "Handoff — continuing in a new chat". Store texts are in `app_store_listing.md`. Confirm with the owner before uploading a build, committing, or taking any other outward-facing action.
