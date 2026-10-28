# Athkar — Feature Map (from REA static analysis)

Target: `/Applications/Athkar.app/Wrapper/athkar.app` (iOS app running on macOS via Apple Silicon wrapper)
Main binary: `athkar` — Mach-O arm64, 38.5 MB, Swift/Storyboard app (NSMainStoryboardFile = Main)
Analysis date: 2026-10-23. Route: REA CLI static analysis (plists, Localizable.strings, sqlite, class inventory). Hopper deep-dive pending (first-run license dialog blocks the provider).

## Evidence sources used
- REA `inspect-sqlite-database` on Quran.sqlite (sha256 dba01c0c…) and tafseer.sqlite (sha256 522afe61…)
- Info.plist, RemoteConfigDefaults.plist, PlugIns/*.appex/Info.plist
- en.lproj/Localizable.strings (4,628 keys), content plists (structure dumped in notes/)
- Class-name inventory from binary strings → notes/class_inventory.txt (970 names)

## Main tab/sections (from Info.plist shortcuts + storyboard scenes + strings)
1. **Home / Prayer Times dashboard** — prayers card, next-prayer countdown, hijri date, ramadan card, friday page, adhan display. Scenes: `prayerTimesCard.nib`, `prayerHeader.nib`, `ramadanDateCard.nib`, `fridayPage.nib`
2. **Qibla compass** — `qiblaPage.nib`, `CompassDirectionManager`, `CLLocationManager` (location strings: "prayer times and Qibla direction")
3. **Athkar pages** — `athkarList.plist` categories: Page1–8/Page31 (morning, evening, sleep, after-prayer, etc.), `RoqiaQuran`, `RoqiaSuna` (ruqya), `Tasbee7`, `AkherAyateen`. Entries: {Title, Athkar (rich HTML with `<div class='quran'>`), Count, Audio}. Extra content: `Content.plist` → Daily (32 daily athkar articles), FAQ (20), Quiz (38 questions), allahNames (99 names w/ Details). `mixList.plist` → Mix (124 random athkar), ShortMix. `smallList.plist` → Morning/Evening/ShortMix/mainUI strings. `Khatmah.plist` — khatmah portion texts. Audio: ~90 bundled recitations (mp3/m4a/aac, numbered files) + `AthkarListeningView` audio-player mode + `AudioVisualizerView`, downloads (`AudioDownloadView`, `AdsDownloadsManager`)
4. **Counter (tasbih/misbaha)** — stopwatch icon, incremental counter, `AddCounterView` (custom counters `backupCounters.plist`), **Voice Counter** (speech recognition: "Recite the thikr aloud and the counter will count automatically"), Live Activity widget counter (Refresh Live Activity), Counter Delay setting
5. **My Athkar (custom)** — user-authored athkar, rich-text editor (bundled RichEditorView: `rich_editor.html/js`, jquery, toolbar pngs), Notes Core Data store (`Notes.momd`, `Notes.storyboardc`), `MyData.plist` (MyAthkar/News/favorites), markdown/rich text, favorites (`favorites.plist`, `backupFavorites.plist`)
6. **Quran reader** — `Quran.sqlite` (tables: ayah {id,surah_id,number,text,page,search_text}, surah {id,name,page,count,type,position}, juz, hizb, rube, pages). `tafseer.sqlite` single table `tafseer_mouaser` {id,jozz,page,sura_no,sura_name_ar,line_start,line_end,aya_no,aya_text,aya_tafseer}. Tajweed support (`tajweed-ayah-bounds.json`), bookmarks (`BookmarkView`, `BookmarkVerticalView`), Quran audio (`Quran audio invite is active`), khatmah tracking (`AppQuranLastPageView`, `Khatmah Portion` string), `AyaWTafseerView`, Metal shaders (`default.metallib`), printed-Quran pages view (`المصحف المطبوع Printed Quran`), Lottie covers (`DuoQuranCover.json`, dark variant), search (`search_text` column). `Ayaat.json` (verse collections), `HeaderAudioSchedule.json`, `TimeMoments.json` (timed verse moments).
7. **Prayer times engine** — `moreList.plist` → 24 calculation methods (ummAlQura, MWL, ISNA, Egypt…, with fajr/isha angles, ishaInterval) → matches **Adhan Swift library** shape. `MainCities.json` + 57 GPX city presets (Mecca, Cairo, Baghdad, Amsterdam…). Qiyam/last-third time display, Duha prayer, sunrise elapsed display, prohibited prayer times.
8. **Alarms/notifications** — per-prayer alarms (before/after athan offsets, custom sounds, snooze, Fajr alarm w/ lock-screen test), Iqama notifications (offset minutes after athan), alarms permissions flow (`AlarmIntroView`, `AlarmFAQView`, `AlarmStatusSnippetView`), athan audio downloads (`AthanAssetsManager`, "Re-download Athan")
9. **Streaks/check-in** — "Track your prayers, athkar and nawafil": Prayer Streak, Athkar Streak, Quran Streak (`CheckinService`, `CheckinStore`), Daily Tasks widget
10. **Prayer Focus (Screen Time)** — `PrayerFocusMonitor.appex` (DeviceActivity monitor), `PrayerFocusShield.appex` + `PrayerFocusAction.appex` (ManagedSettings shield + action) — blocks apps during prayer
11. **Widgets (WidgetKit, `athkarWidgetExtension.appex`)** — Prayer Times Widget ("Show next prayer time and the time remaining or all prayers"), Prayer Countdown Widget, Prayer Style Widget (user photo background, transparent wallpaper blend), Athkar/Ayaat widget (`AyaatWidgetView`), Counter widget, Date-only widget variant, Watch widgets (`WatchWidgets`, Watch/ dir)
12. **Shortcuts/App Intents** — `Metadata.appintents`, `RandomAthkar App Intent`, `MyAthkarAppEnum`, `Listen to X athkar` intents, home-screen quick actions (counter, random athkar, prayer times, my athkar)
13. **Audio player** — `AudioManager`, `AudioPlayerView`, playlists, `HeaderAudioSchedule.json` (scheduled header audio)
14. **Themes/appearance** — alternate app icons (many `AppIcon-N` variants, `AppIconView`), light/dark (`light.css`/`dark.css`), theme setting (`الثيم Theme`), font-size accessibility boost when enabled, `AppColorViewModel`, `ColorProvider`
15. **Settings** — prayer times source/adjustments, hijri date adjustment (RemoteConfig `hijriDateAdjustment`), hide translation/transliteration, athkar counter delay, alarm prefs, athan sounds, app language (supports en/ar/de/es/fr/tr + more .lproj)
16. **Monetization** — non-consumable/subscription IAP (`athkar2025.storekit` product **Jar99**), "Pro" gating strings, ads (`AdsBannerView`, `AdsService`, Google Ads on-device conversion framework)
17. **Backend/Firebase** — Analytics, Crashlytics, Messaging (push), RemoteConfig (defaults: athkarNewsVersion, hijriDateAdjustment), `APIService`, `AuthService`, `Reviews.json` (in-app review), News feed (athkarNews), backup files (`BackupFileListView`, export/import), WhatsApp channel link
18. **Extras** — islamic_figures.json (events/figures), Condolence cards (`CondolenceCardView`, `CardCanvasView`, cards reorder), Duha, `assert.js`, Lottie animations, video backgrounds (`forest.mp4`), `islamic_figures`, `Reviews.json`, `zayed.jpg`/`faresRAK.bin` (custom fonts?), FairPlay SC_Info (streaming audio assets)

## Dikhr reimplementation plan (from-scratch, clean-room)

### Status board (2026-10-24) — Dikhr vs Athkar
| # | Feature | Status |
|---|---------|--------|
| 1 | Home / prayer times dashboard (countdown, 6 times, qiyam, hijri, ramadan) | ✅ core done (ramadan card pending) |
| 2 | Qibla compass | ✅ |
| 3 | Athkar pages (13 categories, audio, counts, favorites) | ✅ |
| 4 | Tasbih counter (touch, presets, targets, custom) | ✅ |
| 5 | Voice counter (speech) | ✅ code (needs hardware mic test) |
| 6 | My Athkar (أذكاري) custom dhikr + editor | ✅ (simple editor; original's rich-text notes pending) |
| 7 | Quran: mushaf justified Uthmanic flow, markers, bookmarks, last-read, search, tafsir | ✅ mushaf + tafsir list mode |
| 8 | Prayer times engine: 24 methods | ✅ (Hanafi asr pending) |
| 9 | Alarms/athan/iqama notifications | ✅ (custom athan sounds pending) |
| 10 | Streaks/check-in | ✅ |
| 11 | Prayer Focus (DeviceActivity+Shield+Action) | ✅ code (needs signed device to exercise) |
| 12 | Widgets: next-prayer + interactive counter | ✅ (photo style pending) |
| 13 | Live Activity counter (Dynamic Island) | ✅ code (needs entitlement/device verify) |
| 14 | App Intents + Quick actions + dikhr:// deep links | ✅ |
| 15 | Khatmah (ورد الختمة) daily portions | ✅ |
| 16 | Daily articles / FAQ / Quiz / Islamic figures | ✅ |
| 17 | News feed | ✅ local structure (RemoteConfig backend pending) |
| 18 | Backup export/import | ✅ |
| 19 | IAP Pro subscription (Jar99→DikhrPro) + PayPage | ✅ code (needs StoreKit config+device) |
| 20 | Review prompts | ✅ |
| 21 | Themes (6 accents) + 8 alternate icons | ✅ |
| 22 | Watch companion (counter + prayers) | ✅ |
| 23 | Location auto-detect with real city naming | ✅ |
| 24 | Firebase (Analytics/Crashlytics/Messaging/RemoteConfig) | ⬜ pending (needs config + SDK) |
| 25 | Broadcast/WhatsApp channel, backupCounters sync | ⬜ pending |
Only reuse: OFL-licensed fonts present in bundle, public-domain content (Quran text, classical athkar texts, city coordinates, calculation-method parameters). Everything else (code, UI design, assets, audio, tafsir text, Lottie files) is re-created or omitted-with-slot; copyrighted audio/tafseer are NOT copied — feature slots remain with user-supplied or licensed assets.

Phase structure:
1. Core app skeleton (SwiftUI, RTL-first), athkar data layer + athkar pages browser w/ counts & favorites
2. Tasbih counter (touch + voice counters, custom counters, persistent) + Live Activity later
3. Prayer times (Adhan algorithms implemented locally: Umm al-Qura/MWL/ISNA/etc.), qibla compass, alarms/iqama notifications
4. Quran reader (Quran.sqlite-compatible schema), bookmarks, khatmah, search
5. Streaks/check-in, settings, themes/icons, My Athkar editor (simple first)
6. Extensions: widgets, App Intents, Prayer Focus (DeviceActivity/ManagedSettings), Watch app
7. IAP (Pro) + Firebase wiring as integrations
## UI-parity crawl loop (branch parity/ui-loop, 2026-10-26/27)
Method: live screencapture of the installed Athkar app's window + AppleScript
(System Events) coordinate clicks to walk its UI autonomously; each divergence
fixed by subagents and committed.

- Brand أذكار home: night-sky starfield header, QR verse banner, gear/search/
  bookmark round buttons, hijri medallion framed by today's Fajr/Isha, filter
  chips (المنوعة/الصلاة/القبلة/المفضلة/العداد), gold live next-prayer countdown,
  المصحف shortcut, worship-progress ring, pastel two-column category grid.
- Full المنوعة grid: wide comprehensive-athkar row, summary/sick/ease/verse-
  tafsir rows, verbatim hadith ticker (6 authentics from the original binary),
  gold-crown Pro divider + locked rows (dates/loved ones/kids/umrah/hajj/cards/
  booklet/widget duas).
- الصلاة chip page: black minimal night-prayer screen (live HH:MM:SS clock,
  right-edge interval progress bar, PREVIOUS prayer top block + next-prayer
  bottom block w/ 12h م/ص suffixes, gold seconds countdown, hijri yyyy-mm-dd +
  city footer, glowing moon + back chevron).
- القبلة pages: no-compass fallback = dark MKMapView + gray location circle +
  green geodesic ray 300 km along the qibla bearing + verbatim disclaimer +
  عرض اتجاه إلى ماكة recenter bar; compass path preserved.
- المفضلة page: black screen + verbatim empty-state.
- المتابعة والعداد chip page: tracker ring + 4 streak tiles (current/best) +
  compact counter (CounterStore's increment path, haptics, 3s reset).
Branch: parity/ui-loop (58cdb5c..d696305, 7 commits) — ahead of main.
