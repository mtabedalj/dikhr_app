# Firebase setup for Dikhr

The Firebase SDK (v12, SPM) is wired in and builds. It activates only when YOU
add your own config plist — Athkar's plist is intentionally NOT reused (it would
route Dikhr's analytics into that developer's Firebase project).

## Activate (10 minutes)
1. console.firebase.google.com → create project (e.g. "dikhr-app").
2. Add an Apple app with bundle id **dev.dikhr.app**.
3. Download `GoogleService-Info.plist` and copy it to `Dikhr/Dikhr/` (same folder as
   `DikhrInfo.plist`) — never commit real keys; this repo has only a template
   (Dikhr/GoogleService-Info.TEMPLATE.plist).
4. Rebuild/reinstall: the log (subsystem `dev.dikhr`, category `firebase`) then says
   "Firebase configured".

## What lights up
- **Analytics** — app-wide; screen_view events per tab (AnalyticsService.screen in RootTabView).
- **Crashlytics** — crash reports with collection enabled.
- **RemoteConfig → News (الأخبار)** — keys:
  - `dikhrNewsVersion` (Int) — bump to invalidate existing items
  - `dikhrNews` (String) — JSON array of NewsItem (fields per Features/Content/NewsStore.swift)
  The app fetches (min interval 1 h) on each activation and calls NewsStore.applyRemoteVersion.
- **Messaging (FCM)** — token delegate wired; actual push needs APNs + your Apple dev setup.

## Verify without Firebase
All paths are `#if canImport` guarded; with no plist the app logs
"skipping configuration" and everything (News empty state) keeps working.