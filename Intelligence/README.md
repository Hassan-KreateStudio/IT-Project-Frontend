# Intelligence

On-device model reads the **local week graph** and returns copy + Trends tones. Not rules. Not TensorFlow. Not a model in our binary. Sync to Render does not include this.

Requires **iOS 26**, Apple Intelligence capable device, `SystemLanguageModel.default.availability == .available`. Check every call.

## Pipeline

1. SwiftData graph is already written (`Person → Day → Activity`). Glucose is not stored on the phone; the dashboard returns it.
2. Walk this week into **raw JSON** (dates, steps, duration, intensity, sedentary). No averages, no “this is high.”
3. `LanguageModelSession` (`import FoundationModels`) gets that JSON plus instructions: only use the graph, no diagnosis, Graph Health voice.
4. Constrained decode into `WeekTake` (`@Generable`). Screens read `WeekTake` only.
5. Persist `WeekTake` on today’s `Day`. Do not call the model again on every swipe.

Run **once** after that day’s activity is in the local graph. Run again only if today’s activity row actually changed.

## What the model returns

Not a single sentence. A struct:

- **todayCopy** — Today’s take: a short block (a few sentences is fine), tying this day’s movement to this day’s glucose.
- **general** — Last Trends card: the week + today’s reading + the link between them.
- **tones** — `quiet` / `watch` / `loud` for steps, exercise, sedentary, glucose. These color the Trends graph cards.

Optional later: a `Tool` whose `call` reads SwiftData, if we want the viva line that the model queries the graph. Seven days fit in the prompt; dumping JSON is enough.

## Out of scope

Backend alert codes. Caregiver dashboard. Uploading `WeekTake` or the SwiftData store.
