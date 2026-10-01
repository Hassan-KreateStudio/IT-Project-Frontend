# Activity mapping

Phone derives these, then `syncActivity`. Backend stores the fields as-is.

- **Steps** — HealthKit step samples, unchanged.
- **Heart rate** — sample average BPM on the bout. `%` of max HR (`220 − age`) is only used on the phone to pick intensity.
- **Duration** — that day’s Apple Exercise Time (minutes Apple counted as at-least-brisk), Workout or not. Not derived from a step total.
- **Intensity** — `LIGHT` / `MODERATE` / `VIGOROUS` from HR% and/or step cadence (fast untracked walks still count).
- **Sedentary** — `max(0, 960 − durationMinutes)` (16 waking hours minus duration).

## First-time patient (this session only)

1. Sign in. Today shows **Allow Health**. Do not pull Health yet.
2. After grant: last **7 days** of activity into a **local graph** (`Person → Day → Activity`). SwiftData/SQLite with nodes and edges — not Neo4j on device, not GraphQLite. Then `syncActivity` for those days.
3. **Required glucose** for today. No Skip. Sheet until there is a mg/dL. Attach `Day → Glucose` and `addGlucose`.
4. **Today** — this calendar day only: steps, exercise minutes, the reading, plus a short line from on-device reading of the graph (today vs the week, glucose next to today’s movement). Do **not** show backend alert codes (`HIGH_SEDENTARY`, `LOW_ACTIVITY`, `HIGH_GLUCOSE`, `LOW_GLUCOSE`).
5. **Trends** — vertical swipe. One card = one graph (7-day steps, exercise time, sedentary). Card color = how sharp that trend is, from the same on-device read. Glucose is **one point on today**, not a fake 7-day line. After those cards, a **General** card: the week + today’s reading + the link.

Official query-time alerts can still exist on Render for the caregiver. The patient’s first screens do not use them.
