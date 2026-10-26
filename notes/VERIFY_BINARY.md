# Binary verification verdicts (Dikhr vs Athkar)

Route: REA/Hopper persistent session (evidence raw: notes/verify_raw/). Target sha256 5a1bebe7…, arm64, 138,893 procedures / 27,151 strings. Procedure-name search returns 0 across all patterns — the release binary is symbol-stripped (Swift names survive only as reflection metadata strings in __TEXT,const); behavioral verification therefore runs through string keys + shipped data + resource contracts.

## 1. Khatmah — DIVERGE → FIXED (plan-system rework landed)
Original evidence (46 khatmah strings):
- It is a **Quran khatmah plan system**, not athkar rotation: "Daily wird day number", "Daily wird starting surah, ayah and page", "Daily wird starting juz", "KhatmahPlanListView — plan name / plan daily reading amount / custom plan daily reading amount / duration unit for 3–10 days / start-from-beginning / start-from-specific-wird / when-to-start (اليوم/غدًا/بعد غد)".
- "KhatmahTimerView — undo completed wird button"; "completedKhatmahs.v1"; "khatmah_backup_v1"; "KhatmahDuaa"/"khatmahDuaa" (dua upon completion — the 43 Khatmah.plist texts ARE the completion/duaa set, NOT portions); notification: "setKhatmahNotificationTime", "com.athkarApp.Alerts.Khatmah".
- History: "Your completed khatmah will be kept in history when you start a new plan."
Dikhr today: KhatmahStore = daily rotation over the 43 athkar — WRONG model.
Fix: plan-based Quran khatmah (portion Quran pages via QuranDatabase by daily amount + start date + اسم الخطة), wirds list w/ pages/ayat/juz labels, KhatmahTimerView with per-wird completion + undo, plans history (completedKhatmahs.khatmahs.v1), completion dua picker (Khatmah.plist texts), notification with settable time.

## 2. Streaks — DIVERGE → FIXED (nawafil + best streaks landed)
Original evidence (19 strings): FOUR streaks — الصلوات/الأذكار/القرآن/**النوافل** ("streakNawafil", "مداومة النوافل Nawafil Streak") and **current + best** ("dailyTasks_X_currentStreak" / "dailyTasks_X_bestStreak" for all four; "Longest streak of all prayers completed").
Dikhr today: three streaks, no best tracking.
Fix: add nawafil streak (voluntary prayer check-in row), persist bestStreak alongside current for all four, surface best in the streaks detail page.

## 3. TimeMoments — MATCH (structural), engine already byte-derived
Engine was built from the original's own 42-rule TimeMoments.json (anchors/offsets/cap/conditions) — verified. Duha anchor = rule "duha": sunrise+20 min.

## 4. Duha — DIVERGE → FIXED (DuhaJourneyView landed, card wired)
Original evidence (26 strings): Duha is an interactive **journey** — "DuhaJourneyView" with 5 stations (station n title/subtitle/bullet, station 2 carries a hadith + source: Muslim 856), completion state + undo ("Duha completion supports undo", "Undo Duha completion"), and a duha notification ("PrayerActionResultView — duha notification").
Dikhr today: a passive DuhaCard (time only).
Fix: add DuhaJourneyView (stations flow + completions persisted per day + undo + optional duha notification), keep the card as its entry point.

## 5. Prayer anchors — MATCH (previously verified: duha sunrise+20, iqama guard, dhuhr +1 min within 2-min reference window).
## 6. Athan sounds / live activity / header audio — MATCH (verified in prior round from bundle contracts).

## Fix queue (priority order)
1. Khatmah plan-system rework (largest; rewrite KhatmahStore + KhatmahView; keep dual mode: athkar-khatmah portions from the 43 wirds is the "khatmah dua" set)
2. Streaks: +nawafil, +best tracking, detail page surfaces
3. DuhaJourneyView with stations + undo + notification