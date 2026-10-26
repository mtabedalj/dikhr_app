# Dikhr agent brief (read this + notes/FEATURES.md before starting)

## What this is
Dikhr is a from-scratch SwiftUI reimplementation of the iOS app Athkar (original at
`/Applications/Athkar.app/Wrapper/athkar.app` — read-only reference). Workspace:
`/Users/mabedalj/athkari_app/Dikhr`. Data conversion helpers in `../scripts/`.
Original RE evidence: `../notes/FEATURES.md`, `../notes/class_inventory.txt`.

## Project layout (Xcode uses synchronized groups: new files under these folders
are picked up by the build automatically — DO NOT touch the .pbxproj)
- `Dikhr/` — iOS app target sources
  - `App/` — app entry, tabs, AppIntents
  - `Data/` — stores (SettingsStore, AthkarStore, QuranDatabase 3, TafseerDatabase, StreaksStore, AlarmScheduler, LocationController)
  - `Features/{Home,Athkar,Counter,Quran,Qibla,Audio,Settings}/`
  - `Prayer/` — PrayerTimesEngine (moved to DikhrCore), AlarmScheduler, PrayerFocusManager
  - `Resources/` — JSON data + fonts (UthmanicHafs_V22_Bold.ttf "KFGQPCHAFSUthmanicScript-Bold", Scheherazade-Regular.ttf "Scheherazade-Regular") + Audio/ (recitations, keyed by entry.Audio names, extensionless: "25s" → "25s.mp3")
  - `DikhrInfo.plist` — partial app Info.plist merge base (owned by main session)
- `DikhrCore/` — shared with widget/watch/focus targets: PrayerTimesEngine.swift, Models.swift, SharedStores.swift (DikhrShared app-group defaults + CounterStore), SharedIntents.swift (IncrementCounterIntent + DikhrMethodLoader), Resources/prayer_methods.json
- `DikhrWidget/` — WidgetKit bundle (next prayer + interactive counter)
- `DikhrFocusShield/Monitor/Action/` — prayer focus extensions
- `DikhrWatch/` — watchOS companion

## Conventions
- Arabic-first RTL UI (the app applies layoutDirection from settings.lang — Arabic default).
- Palette: teal #018F9E = interactive accent; Quran green #00946a reserved for mushaf/verses.
  QuranPalette.paper/darkGreen helpers. Fonts: `.quranUthmani`, `.athkarBody` (Scheherazade 21).
- Persistence: UserDefaults keys prefix-free; cross-target state via `DikhrShared` app group
  ("group.dev.dikhr.app.shared"), never via .standard in core code.
- Test hooks: launch env vars (see memory note) — DIKHTML_* is a typo'd alias, keep supported.
- **Do NOT edit**: any *.pbxproj, DikhrInfo.plist, WidgetInfo.plist, existing files in Data/ or App/
  owned by others, Resources/ folder naming. New feature code goes in NEW files under
  `Dikhr/Features/<YourArea>/` (+ `DikhrCore/` only if another target needs it).
- **Do NOT run xcodebuild** — the main session builds and integrates. Do not launch simulators.
- Content from the original bundle: read plists/json via `python3` snippets you write into a
  scratch dir under `/Users/mabedalj/athkari_app/scripts/tmp/`, then bake data by writing JSON
  into `Dikhr/Dikhr/Resources/<name>.json` (unique filenames per agent to avoid collisions).
- Localization style: Arabic strings inline (matching the original), like existing files.

## Wiring you must REQUEST in your report (main session integrates)
- If your feature needs: a Settings row, a Home card, a tab, an entry point from another
  feature, or an Info.plist key — state exactly what/where in your final report and DON'T edit.