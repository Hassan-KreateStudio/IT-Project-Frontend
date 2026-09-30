# Activity mapping

Phone derives these, then `syncActivity`. Backend stores the fields as-is.

- **Steps** — HealthKit step samples, unchanged.
- **Heart rate** — sample average BPM on the bout. `%` of max HR (`220 − age`) is only used on the phone to pick intensity.
- **Duration** — that day’s Apple Exercise Time (minutes Apple counted as at-least-brisk), Workout or not. Not derived from a step total.
- **Intensity** — `LIGHT` / `MODERATE` / `VIGOROUS` from HR% and/or step cadence (fast untracked walks still count).
- **Sedentary** — `max(0, 960 − durationMinutes)` (16 waking hours minus duration).
