# Sheikh Ahmed (الشيخ أحمد) — Project Tracking

_Last updated: 2026-09-11_

## 1. Overview

**Sheikh Ahmed** is an Arabic-first Islamic companion app for daily worship: prayer times and adhan, the Holy Quran (printed Mus'haf, 21 reciters, tafsir, tajweed, word-by-word audio, memorization mode), live Quran radio, azkar and duas, tasbeeh, a worship tracker, a weekly good-deed mission, Ramadan mode, Qibla and a zakat calculator. The UI is Arabic by default with full English support and dark mode.

| Item | Value |
|---|---|
| Framework | Flutter 3.47.2 / Dart 3.13.2 (Xcode 26.4, CocoaPods 1.16.2) |
| Main packages | flutter_riverpod, easy_localization, just_audio + audio_service, flutter_local_notifications, adhan_dart, geolocator, flutter_qiblah, record, hive, shared_preferences, url_launcher |
| Version | 1.14.0 (build 30) |
| Android applicationId | `com.manassa.sheikhahmed` |
| iOS bundle ID | `com.manassa.sheikhahmed` |
| Apple Developer team | Ahmed Maher — `23U33PV5JV` (automatic signing) |
| Devices | iPhone + iPad, iOS 15.0+ |
| Developer contact | sheikhahmed.app@gmail.com |
| Privacy policy | https://claude.ai/code/artifact/4b210bce-5156-442e-a2ad-16548d043579 (same link as Google Play) |

## 2. Status

| Track | Status |
|---|---|
| Android | ✅ Live on Google Play — https://play.google.com/store/apps/details?id=com.manassa.sheikhahmed |
| iOS code readiness | ✅ Changes done; `flutter analyze` clean (second pass 2026-09-11: permission timing, share links, desktop/web folders removed — owner runs the app next) |
| App Store Connect setup | 🟡 In progress (owner: Ahmed — App ID, app record, listing texts, screenshots) |
| iOS review | ⬜ Not submitted |
| Screenshots | ✅ Prepared by the owner |
| Facebook launch post | ⬜ After iOS approval |

## 3. iOS release checklist

### A. Code & Xcode project (Claude)

- [x] Bundle ID set to `com.manassa.sheikhahmed`; automatic signing with team `23U33PV5JV`
- [x] Podfile platform aligned with the Runner target and Flutter engine (iOS 15.0; it was 16.0)
- [x] App Transport Security exception for `radiojar.com` — the Cairo and Saudi radio streams redirect to plain `http://`
- [x] `ITSAppUsesNonExemptEncryption = false` (no export-compliance question per build)
- [x] Permission prompts in English (base) and Arabic (`ar.lproj/InfoPlist.strings`); `CFBundleLocalizations` = ar, en; Arabic name «الشيخ أحمد» under the icon on Arabic devices
- [x] `UNUserNotificationCenter` delegate set in `AppDelegate` (flutter_local_notifications iOS requirement)
- [x] iOS 64-pending-notification limit: `NotificationWindow` keeps a full week of adhans and 2 days of reminders (max 63). Before, iOS dropped every adhan notification whenever reminders were on
- [x] Adhan notification sound on iOS: 29-second IMA4 `.caf` clips of all 4 voices (`ios/Runner/Sounds/`), verified 29.0 s with `afinfo`; silent in the foreground where the in-app player plays the full adhan
- [x] "Stop adhan" bar now also shows for the in-app player (the only adhan player on iOS)
- [x] Downloaded surah audio now plays on iOS (passed as a `file://` URI instead of a bare path)
- [x] Downloaded content (surah audio, Mus'haf fonts and pages) excluded from iCloud backup
- [x] Home "Azkar widget" tile hidden on iOS (the widget is Android-only)
- [x] Privacy policy and Contact us rows added to the More tab (App Review Guideline 5.1.1)
- [x] Radio: 5 stations moved from `backup.qurango.net` (18/50 requests failed) to `qurango.net` (50/50 OK); one automatic retry on a transient stream failure
- [x] "Custom" calculation method hidden (it has no settings, so Fajr/Isha came out wrong)
- [x] Dark mode on/off label translated (it was hard-coded Arabic)
- [x] Project rules added to `.claude/CLAUDE.md`; `test/` folder removed at the owner's request
- [x] `flutter analyze` clean (no issues)
- [x] Unsigned iOS release build compiles (`flutter build ios --release --no-codesign` → Runner.app, 28.3 MB) — before the second pass below; the owner runs the app after it
- [x] Second pass (2026-09-11): notification permission asked on the first frame over the home screen instead of before `runApp` (the prompt used to sit over an empty screen); share message carries the Google Play link on Android and, on iOS, only the App Store link once known (Guideline 2.3.10, no other platforms named); widget snapshot skipped on iOS; `linux/`, `macos/`, `web/`, `windows/` template folders deleted
- [ ] Signed App Store archive and upload (`flutter build ipa`) — once the App ID and App Store Connect record exist

### B. Apple Developer & App Store Connect (Ahmed)

- [ ] Register explicit App ID `com.manassa.sheikhahmed` under team Ahmed Maher (no extra capabilities)
- [ ] Create the app: iOS, primary language Arabic, bundle ID above, SKU e.g. `sheikhahmed-ios`
- [ ] App Information: name, subtitle, category (Primary: Lifestyle, Secondary: Reference), content rights, age rating
- [ ] Pricing and Availability: Free
- [ ] App Privacy: "Data Not Collected" + privacy policy URL
- [ ] Support URL (required — see open questions)
- [ ] Version 1.14.0 page: screenshots (iPhone 6.9" and iPad 13"), description, keywords, promotional text — texts in `app_store_listing.md`
- [ ] App Review Information: contact details + review notes from `app_store_listing.md`
- [ ] Upload build → select it on the version page → Submit for Review

### C. Device QA before submitting (TestFlight build)

- [ ] First launch: notification permission prompt; app opens in Arabic
- [ ] Adhan notification with the adhan sound while the app is closed; full adhan in-app while open; Stop bar works
- [ ] Radio: all 7 stations, including Cairo and Saudi (radiojar); background + lock-screen controls
- [ ] Download a surah, switch to airplane mode, play it
- [ ] Qibla compass; location prompt in Arabic and in English
- [ ] Memorization mode: record and play back
- [ ] More tab: privacy policy and contact links open
- [ ] iPad: portrait and landscape pass over every tab

## 4. Decisions log

| Date | Decision | Reason |
|---|---|---|
| 2026-09-11 | iOS bundle ID `com.manassa.sheikhahmed` | Same identity as the Android app |
| 2026-09-11 | Publish under team Ahmed Maher (`23U33PV5JV`) | Owner's choice |
| 2026-09-11 | Support iPhone and iPad | Owner's choice; needs iPad screenshots and QA |
| 2026-09-11 | Only code changes before launch; anything needing App Store Connect, Firebase or other services waits until after launch | Owner wants to ship now |
| 2026-09-11 | No tests in the project; `test/` deleted; rule recorded in `.claude/CLAUDE.md` | Owner's rule |
| 2026-09-11 | Radio streams served from `qurango.net` | Backup host failed 36% of requests |
| 2026-09-11 | Notification permission requested on the first frame, not in `main()` | The system prompt appeared over an empty screen before the app had drawn anything |
| 2026-09-11 | Share message: Google Play link on Android; on iOS only the App Store link, added once the Apple ID exists | App Review Guideline 2.3.10 — no other mobile platforms named in an iOS app |
| 2026-09-11 | `linux/`, `macos/`, `web/`, `windows/` deleted | Mobile-only project; the folders were untouched Flutter templates |
| 2026-09-11 | Claude reviews and fixes code only; the owner runs the app and prepares screenshots | Owner's instruction |

## 5. Known iOS limitations (not blockers)

- The home-screen azkar widget exists only on Android.
- With the app closed, iOS plays a 29-second adhan clip (iOS caps notification sounds at 30 s); the full adhan plays when the app is open.
- Non-adhan reminders are scheduled 2 days ahead on iOS; every app open extends the window.
- The app opens in Arabic regardless of device language (English is in More → App language).

## 6. Post-launch backlog

- [ ] Time-Sensitive Notifications capability so the adhan can break through Focus (needs the capability on the App ID)
- [ ] iOS home-screen widget (WidgetKit)
- [ ] Set `AppLinks.appStore` (`lib/core/links/app_links.dart`) to `https://apps.apple.com/app/id<Apple ID>` once App Store Connect assigns the Apple ID — the share message then includes it on both platforms
- [ ] Remove the unused `hive` / `hive_flutter` dependencies (nothing imports them)
- [ ] Persist Quran favorites (currently reset on restart)
- [ ] Remove remaining Arabic text/digits from the English UI (surah list subtitle, tracker weekdays, Qibla digits)
- [ ] Ramadan missions 6–8 never appear; three duplicated hadith in the daily quotes
- [ ] Update `play_store_listing.md` (it still says 6 reciters and 4 azkar categories)
- [ ] Host the privacy policy and a support page on a domain the project owns
- [ ] Background refresh to extend the notification window without opening the app

## 7. Facebook launch post (after iOS approval)

- [ ] Draft the post (features, both store links, screenshots)
- Google Play: https://play.google.com/store/apps/details?id=com.manassa.sheikhahmed
- App Store: _pending approval_

## 8. Open questions

- **Support URL**: App Store Connect requires one. Options: the privacy policy page (if it shows the contact email), or a Facebook page for the app.
- **App name availability**: "الشيخ أحمد" / "Sheikh Ahmed" must be unused on the App Store.

## 9. Handoff — continuing in a new chat

**Where things stand (2026-09-11, second pass):** all iOS code changes in section 3A are done — `flutter analyze` clean. The first pass (committed on `ios/app-store-release`) was verified with an unsigned release build and the built bundle was checked (bundle ID, version 1.14.0 (30), iOS 15.0, iPhone + iPad, the four 29-second `.caf` sounds, English and Arabic `InfoPlist.strings`). The second pass (permission timing, share links, widget snapshot skipped on iOS, desktop/web folders deleted — see the change log) is **not committed yet**; the owner runs the app themselves next, then the App Store Connect fields are filled in together. Working rules from the owner: Claude reads and fixes code only — no running the app, no simulators, no screenshots, no builds unless asked; the owner has the screenshots ready.

**Next steps, in order**

1. **Owner:** register the App ID `com.manassa.sheikhahmed` (team Ahmed Maher) and create the App Store Connect app (iOS, primary language Arabic). Decide the Support URL (a Facebook page for the app, or the privacy-policy link).
2. **Claude — signed build:** `flutter build ipa --release`. Signing is automatic with team `23U33PV5JV`, and Flutter passes `-allowProvisioningUpdates`, so Xcode creates the distribution profile itself (none existed locally on 2026-09-11).
3. **Claude — upload, only after the owner confirms:**
   `xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive -exportOptionsPlist ios/ExportOptions.plist -exportPath build/ios/upload -allowProvisioningUpdates`
   (`ios/ExportOptions.plist` uploads straight to App Store Connect with the account signed in to Xcode.) Alternative: Xcode → Window → Organizer → Distribute App → App Store Connect.
4. **Screenshots** — already prepared by the owner (iPhone 6.9" 1320 × 2868 and iPad 13" 2064 × 2752). Claude does not run simulators or capture screenshots.
5. Fill the version page from `app_store_listing.md` together with the owner, run the TestFlight QA list (section 3C), then submit for review.
6. **After approval:** add the App Store link to this file, then write the Facebook launch post in Arabic about the project and its features (use section 10).

**Constraints**

- No tests (`.claude/CLAUDE.md`).
- Before launch, only code changes. Improvements that need App Store Connect capabilities, Firebase or other external services wait until after launch (backlog in section 6).
- Confirm with the owner before any upload or other outward-facing action.

## 10. Feature inventory (verified against the code, 2026-09-11)

- **App shell:** 5 tabs — Home, Quran, Radio, Tracker, More. Opens in Arabic on first launch whatever the device language. Quran, radio and adhan audio keep playing in the background with lock-screen controls.
- **Quran reading:**
  - Printed 604-page Madani Mus'haf with the King Fahd Complex per-page fonts (QCF v1, downloaded as pages open); the default layout in the Arabic UI. Surah banners, basmala, juz/hizb/sajda header, pinch-zoom to 4x.
  - Text layout (Scheherazade New by default, or Amiri Quran; size 16–40; bold) — the only layout in the English UI, with the Saheeh International translation under each ayah.
  - Tapping a verse opens a menu: bookmark (3 colours: Memorised, Reviewing, Needs work), play from here, tafsir (Al-Muyassar, Arabic), tajweed rules (15 rules, per-verse sheet), word-by-word audio.
  - Search: surah names on the device; verse text through api.quran.com (3+ letters, top 40 results).
  - Go to: page 1–604, 30 juz, 240 hizb quarters. "Continue reading" (a fresh install starts at Al-Kahf 18:1). Favorites exist but are not saved across restarts.
  - Offline: anything opened stays on the device; "download the whole Mus'haf" fetches 114 surah texts and 604 printed pages (about 75 MB).
- **Reciters (21):** Mishary Rashid Alafasy, Abdulrahman Al-Sudais, Saud Al-Shuraim, Abdulbasit Abdulsamad, Mahmoud Khalil Al-Husary, Mohamed Siddiq Al-Minshawi, Maher Al Muaiqly, Saad Al Ghamdi, Abu Bakr Ash-Shatri, Ahmad Al Ajmi, Nasser Al Qatami, Hani Ar-Rifai, Yasser Ad-Dossari, Fares Abbad, Muhammad Ayyoub, Ali Al Hudhaify, Muhammad Jibreel, Abdullah Basfar, Abdullah Al Matroud, Salah Bukhatir, Abdullah Al Juhany. Whole surahs from mp3quran.net, single ayahs from everyayah.com; auto-advance to the next surah; per-surah and "download all" (resumable) downloads.
- **Memorization mode:** one hidden ayah at a time; record yourself (temp file, never uploaded), play your recording, play the reciter, reveal, previous/next, jump to ayah. No scoring or saved progress.
- **Radio (7):** General broadcast (mix), Quran Radio Cairo (98.2 FM, radiojar), Sheikh Saud Al-Shuraim, Sheikh Ali Al-Huthaifi, Sheikh Mahmoud Khalil Al-Hussary, Sheikh Mohammed Siddiq Al-Minshawi (qurango.net), Saudi Quran Radio (radiojar).
- **Prayer times:** calculated on the device. 13 selectable methods (adhan_dart's "Custom" is hidden) — Egyptian General Authority (default), Muslim World League, Karachi, Umm al-Qura, Dubai, Qatar, Kuwait, Moonsighting Committee, Singapore, Turkiye, Tehran, ISNA, Morocco — and the Shafi'i (default) and Hanafi madhabs. Location from GPS or 9 preset cities (Cairo default, Mecca, Medina, Istanbul, Riyadh, Amman, Jakarta, London, New York). Next-prayer countdown, sunrise, midnight, last third of the night. Hijri date from api.aladhan.com (cached per day).
- **Imsakiya and Ramadan:** monthly imsakiya all year. In Ramadan the home header switches to a night-sky design with countdowns to Maghrib and Imsak, a last-ten-nights message, fasting-day progress, taraweeh (Isha + 30 min) and qiyam (last third) times.
- **Adhan:** 4 voices — Makkah Haram, Madinah Haram, Egyptian (Sheikh Mohamed Rifaat's Cairo recording, bundled, default) and Turkish — with previews and an on/off switch (on by default). Android plays the full adhan from a native service with the app closed; iOS shows a notification with a 29-second clip and plays the full adhan in-app when it is open.
- **Azkar:** 8 categories, 113 items — Morning 22, Evening 21, Sleep 13, After prayer 12, Ruqyah 27, Waking 4, Food 9, Adhan 5. Tap counters and daily progress that resets at midnight; Quran passages are fetched once and cached.
- **Duas:** 68 in 10 groups — Forgiveness 8, Repentance 6, Provision 8, Worry and hardship 8, Health and healing 6, Guidance 7, Protection 7, Ease and knowledge 6, Family and parents 6, The hereafter 6. Arabic only.
- **Tasbeeh:** 8 phrases; targets 33 / 100 / 500 / 1000 / no limit; haptics; saved counts and a lifetime total.
- **Worship tracker:** the 5 prayers, a Saturday–Friday week strip, streak; daily wird rows (Quran reading, morning azkar x/22, evening azkar x/21, night prayer up to 8 rak'ahs); a celebration dialog when the wird is complete.
- **Weekly mission:** 52 missions in a fixed weekly order plus 8 Ramadan missions; mark as done.
- **Ayah/Hadith of the day:** 58 entries (39 ayat, 19 hadith), with sharing.
- **Zakat calculator:** cash, gold grams, gold price per gram (typed in), debts; nisab 85 g of gold; 2.5%.
- **Qibla:** live compass (flutter_qiblah), "facing the Qibla" within ±3° with a haptic, a bearing number and a calibration hint.
- **Notifications:** adhan at the 5 prayers; morning azkar (Fajr + 15 min), midday check-in (Dhuhr + 15), evening azkar (Asr + 15), daily wird (Isha + 20), ayah/hadith 08:00, surah of the day 09:00, dhikr at 9, 11, 13, 15, 17, 19 and 21, weekly mission on Saturday 09:00. Two switches only: adhan, and everything else.
- **More tab:** app language, zakat, Qibla, share app (text only), location, calculation method, adhan switch, adhan voice, azkar notifications switch, dark mode, privacy policy, contact us. Android also shows exact-alarm and "appear on top" rows when those permissions are missing.
- **Android-only:** home-screen azkar widget (next prayer, the 5 times, Hijri date, weekly mission, rotating dhikr); full-length adhan alarm service; exact-alarm and overlay permission prompts; per-kind notification channels.
- **External services:** api.alquran.cloud (text, translation, tafsir), api.quran.com (search, tajweed, words, page layout), quran.com fonts, audio.qurancdn.com (word audio), mp3quran.net (surah audio), everyayah.com (ayah audio), qurango.net and radiojar.com (radio), cdn.aladhan.com (adhan audio), api.aladhan.com (Hijri date). No analytics, ads, accounts or crash reporting.

## 11. Other issues found (not fixed yet)

- Quran favorites reset when the app restarts.
- The English UI still shows some Arabic: the surah list subtitle («مكية/مدنية · N آية»), tracker weekday letters, Arabic-Indic digits in the Quran lists, azkar, tracker and Qibla, and the daily quote / surah-of-the-day texts.
- Ramadan missions 6–8 never appear, and "Qiyam in the last ten" only shows on days 29–30.
- Three hadith are duplicated in the daily quotes.
- The header's Hijri date (aladhan API) and Ramadan detection (on-device Umm al-Qura table) can disagree by a day.
- Tapping a notification only opens the app; the Home bell icon just opens the More tab.
- The azkar notifications switch description doesn't mention the dhikr and surah-of-the-day reminders it also controls.
- Location defaults to Cairo with no first-run prompt (the notification permission now comes after the first frame — fixed 2026-09-11).
- Unused code and strings: the text page mode, a second whole-Mus'haf downloader, the Hijri offset, the Sha'ban countdown, about 24 unused strings.

## 12. How the iOS adhan clips were made

Source files: `android/app/src/main/res/raw/<rawResource>.mp3`.

1. `afconvert -f WAVE -d LEI16@22050 -c 1 -q 127 <in>.mp3 full.wav`
2. Python (standard `wave` module): skip leading silence (keep 0.15 s before the first sample above 2% of full scale), keep 29.0 s, peak-normalise to about −1 dBFS, 2.5 s cosine fade-out.
3. `afconvert -f caff -d ima4 clip.wav ios/Runner/Sounds/<rawResource>.caf`, and confirm `afinfo` reports under 30 s.
4. Add the file to the Runner target's Copy Bundle Resources (the `Sounds` group in `project.pbxproj`). The file name must match `AdhanVoice.iosNotificationSound` (`rawResource` + `.caf`).

## 13. Change log

### 2026-09-11 — second pass before upload (uncommitted)

- Notification permission: `lib/main.dart` no longer requests it during plugin initialisation; new `lib/core/adhan/notification_permission.dart` asks on the first frame from `lib/core/adhan/adhan_watcher.dart`, which then schedules. The resume handler's 12-hour guard is stamped before the prompt so its inactive→resumed transition doesn't trigger a second reschedule.
- Share message: `lib/core/share/share_app.dart`, `lib/core/links/app_links.dart` (`googlePlay`, `appStore` = null until the Apple ID exists), `share.android` / `share.iphone` strings in `assets/translations/ar.json`, `en.json`.
- `lib/core/widget/widget_data_service.dart`: `publish()` returns early where the Android widget channel is unsupported (iOS).
- Deleted `linux/`, `macos/`, `web/`, `windows/` (72 untouched template files); `flutter pub get` and `flutter analyze` clean afterwards.

### 2026-09-11 — iOS readiness

- iOS project: `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Podfile`; new `ios/Runner/en.lproj/InfoPlist.strings`, `ios/Runner/ar.lproj/InfoPlist.strings`, `ios/Runner/Sounds/*.caf`
- Adhan and notifications: `lib/core/adhan/adhan_scheduler.dart`, `adhan_providers.dart`, `adhan_audio.dart`, `adhan_playing_providers.dart`
- Audio and radio: `lib/core/audio/quran_audio_handler.dart`, `lib/core/audio/quran_stations.dart`
- Storage: new `lib/core/storage/backup_exclusion.dart`; `lib/core/quran/audio_download_service.dart`, `mushaf_font_service.dart`, `mushaf_page_service.dart`
- UI: `lib/core/widget/azkar_widget_channel.dart`, `lib/features/home/presentation/home_screen.dart`, `lib/features/settings/presentation/settings_screen.dart`, new `lib/core/links/app_links.dart`, `assets/translations/en.json`, `ar.json`
- Dependencies: added `url_launcher`; removed test-only dev dependencies
- Project: removed `test/`; added `.claude/CLAUDE.md`, `project_tracking.md`, `app_store_listing.md`, `ios/ExportOptions.plist` (App Store upload settings)
