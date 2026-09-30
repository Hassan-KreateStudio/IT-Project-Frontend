# Brand UI — IT Project

Reference for the iPhone app. Structure and iconography follow the Health Mate–style screens. Color and type do **not**. Voice is closer to Cash App: one loud accent on a dark primary, big numbers, high contrast. Product is still activity + glucose + caregiver — not BMI, weight, or blood pressure.

Watch → HealthKit on the phone → this app → GraphQL. The brand never lives on the Watch.

---

## What we take from the inspiration

**Keep (structure + iconography)**

- Top bar: large title on the left, 1–2 circular icon buttons on the right (bell, plus, gear).
- Optional full-width **banner card** under the title (rounded ~20pt, short headline + one sentence + text button).
- Section label, then a **stack of white measurement cards**.
- Card anatomy: metric name, **huge value**, small status (dot + words), sparkline or spark dots, time + chevron on the right.
- Bottom **tab bar**, four items, outline icons idle, filled when selected.
- Profile: initials avatar, name, one summary chip, list sections.
- Modal sheets for notifications (X, small caps title, grouped rows).
- One **full-bleed task screen** (step-goal style) for a single decision — big number in a circle, one accent field.

**Leave behind**

- Mint / teal / “wellness app” greens.
- Light-green gradient heart banners as the brand.
- Generic marketing body copy as the home hero.
- Extra tabs we do not have (generic “Devices store”).
- System-default gray on gray with no punch.

**Nuance we do keep from those screens**

- Cards sit on a slightly cool off-white, not pure `#FFFFFF` chrome.
- Status is a **dot + short phrase**, not a screaming banner for every metric.
- Sparklines are thin and quiet; the number is the hero.
- One surface can be fully dipped in a single color (the step-goal screen). That is the Cash App move.

---

## What we take from Cash App

- **Dark primary, electric secondary.** Black-green ink for chrome and type. A *bright* lime for action, money-in-the-account energy, success.
- Huge numerals. Tight tracking on titles. Lots of leftover space.
- One accent at a time. Do not mint + lime + teal + blue on one card.
- Dynamic: home is quiet cards; a goal or alert can go **full-screen accent**.
- Playful geometry (circles, fat rounding) without cartoon illustration.

We do **not** copy Cash App’s `#00D632` or their wordmark. Same *attitude*, different pigment so it stays a health graph product.

---

## Color palette

Use these names in `Assets.xcassets/Colors/` and `Shared/Theme.swift`. Hex is sRGB.

### Primary (dark)

| Token | Hex | Use |
|---|---|---|
| `Ink` | `#07110E` | Primary text, tab selected, key buttons, sheet handles |
| `Forest` | `#102920` | Top bars on dark screens, avatar fill, selected chip fill |
| `Pine` | `#1B3D31` | Secondary dark (dividers on dark surfaces, icon circles on dark) |

Ink is almost black with a green undertone. That is the “darker primary.”

### Secondary (bright)

| Token | Hex | Use |
|---|---|---|
| `Volt` | `#C6F34A` | Primary CTA, selected tab accent, success, “synced”, positive sparkline |
| `Pulse` | `#3DFF9A` | Charts only (glucose/activity line). Never large fills. |

Volt is the Cash App–level punch. Pulse is the *nuance* (a second, cooler bright) so charts are not flat yellow-green.

### Surfaces

| Token | Hex | Use |
|---|---|---|
| `Canvas` | `#F3F5F1` | App background (Health Mate’s soft field, less mint) |
| `Card` | `#FFFFFF` | Measurement cards, sheets, inputs |
| `Hairline` | `#DDE3DC` | Card borders, separators |
| `Mist` | `#E8EEE6` | Chip fills, icon button backgrounds |

### Semantic (bright, not pastel)

| Token | Hex | Use |
|---|---|---|
| `Alert` | `#FF4D3A` | High glucose, destructive |
| `Warn` | `#FFB020` | High sedentary, caution status dot |
| `Info` | `#4D7CFF` | Low glucose, informational (Health Mate’s blue *i*) |
| `Mute` | `#5C6B64` | Secondary text, timestamps, tab idle |

### Pairing rules

1. **Idle chrome:** Canvas + Card + Ink text + Mute captions. No Volt until something is active.
2. **Primary button:** Forest fill + Volt label, **or** Volt fill + Ink label. Never Volt fill + white (too close to Cash App clone and fails contrast on lime).
3. **Banner:** Forest (or Ink) fill, Volt for the icon/link — not a mint gradient.
4. **Full-bleed task:** Forest or Ink background, Volt circle, Canvas/Volt type. One color field, like the teal step-goal screen, but dark + lime.
5. **Alerts:** one semantic color as a **dot or left rail**, not a whole card fill.
6. Do not put Volt and Pulse on the same component.

---

## Typography

**Display:** Clash Display (Bold / Semibold). Geometric, wide, tight. Titles and metric numbers — the Cash App punch. Never SF.

**Text:** Satoshi (Regular / Medium / Bold). Body, captions, buttons, field labels. Still geometric, not a system default.

Files live in `Fonts/`. Register in `Info.plist` `UIAppFonts`. Use `AppFont` in `Shared/Theme.swift` — do not call `.system`.

| Role | Font | Weight | Size | Tracking |
|---|---|---|---|---|
| Large title (`Home`, `Who are you?`) | Clash Display | Bold | 40 | -1.2 |
| Screen title (sheets) | Satoshi | Medium | 13 | 1.2 (uppercase) |
| Section (`Latest Measurements`) | Clash Display | Semibold | 24 | -0.6 |
| Card title | Clash Display | Semibold | 22 | -0.6 |
| Metric number (`2,496`) | Clash Display | Bold | 44 | -1.4 |
| Metric unit (`steps`, `mg/dL`) | Satoshi | Medium | 15 | 0 |
| Body | Satoshi | Regular | 16 | 0 |
| Caption / time | Satoshi | Regular | 13 | 0 |
| Button | Satoshi | Bold | 17 | 0 |
| Tab label | Satoshi | Medium | 10 | 0.2 |
| Status chip | Satoshi | Medium | 12 | 0 |

Metric numbers stay Clash Display, not Rounded SF. Titles never go Satoshi — Satoshi is the quiet layer under the shout.

---

## Iconography

SF Symbols, **Regular**, hierarchical, point size **22** in the nav, **24** in the tab bar, **16** inline on cards.

| Action | Symbol |
|---|---|
| Notifications | `bell` / `bell.fill` |
| Add glucose | `plus` |
| Settings | `gearshape` |
| Home | `house` / `house.fill` |
| Dashboard | `square.grid.2x2` / `.fill` |
| Watch / HealthKit | `applewatch` |
| Profile | `person` / `person.fill` |
| Info | `info.circle.fill` |
| Close sheet | `xmark` |
| Card disclosure | `chevron.right` |

Status dots: 8pt circle, semantic color, 6pt from the label. No emoji. No custom illustrated mascots on v1.

Tab bar: four items — **Home**, **Dashboard**, **Watch**, **Profile**. Selected = Forest icon + Volt indicator (small), not Health Mate’s purple.

---

## Layout tokens

| Token | Value |
|---|---|
| Screen inset | 20 |
| Card radius | 20 |
| Chip radius | 12 |
| Icon button | 36 circle, Mist fill, Ink symbol |
| Card padding | 16 |
| Stack gap | 12 |
| Tab bar | system height, Canvas background, Hairline top |

---

## Screen → folder

| UI | Folder |
|---|---|
| Login / register | `Auth/` |
| Home (latest activity + glucose cards, alerts banner) | `App/` or a `Home/` if it grows; data from Activity + Glucose + Analysis alerts |
| Dashboard (trends) | `Analysis/` |
| Watch / last sync | `HealthKit/` + `Activity/` |
| Profile, caregiver link | `Auth/` + `Caregiver/` |
| Add reading | `Glucose/` |
| Theme | `Shared/Theme.swift` + `Assets.xcassets/Colors/` |

---

## Voice

Short. Direct. Like Cash App copy, not a clinic pamphlet.

- “2,496 steps” not “You have accomplished 2,496 steps today.”
- “Glucose 110 mg/dL” not “Your latest synthetic glucose measurement.”
- Alerts stay the backend codes’ meaning: high sedentary, low activity, high/low glucose — one line.

---

## Out of bounds

- Mint gradients, teal washes, stock “heart health” illustration.
- Copying Cash App green `#00D632` or their logo.
- San Francisco or any system UI font as the brand voice.
- Light gray primary buttons.
- More than four tabs.
- A Watch app UI in this repo.
