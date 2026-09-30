# Brand UI — IT Project

Reference for the iPhone app. Structure and iconography follow the Health Mate–style screens. Color and type do **not**. Voice is closer to Cash App’s *card fan*: black stage, white type, a few loud pigments that change per surface. Product is still activity + glucose + caregiver — not BMI, weight, or blood pressure.

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

- Mint / teal / “wellness app” greens. Green-black ink. A lime-only identity.
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

Take the **card fan**, not the chrome.

- True **black stage**. White type. Fat rounded tiles.
- **A fan of loud pigments**, not one lime forever. Magenta, acid yellow-green, ice white, iridescent teal can sit next to each other — different cards, different color.
- Dynamic: a screen can go full-bleed black, full-bleed flare, or quiet canvas. Home stays quiet. Role / goal / alert can shout.
- Huge numerals. Leftover space. Playful geometry without cartoon mascots.

Leave behind Cash App’s `#00D632`, lime status bar, `$` mark, and “everything is green.” Leave behind Loft’s Space Grotesk + Inter. This is a health graph product with its own pigment.

---

## Color palette

Use these names in `Assets.xcassets/Colors/` and `Shared/Theme.swift`. Hex is sRGB.

### Stage (dark)

| Token | Hex | Use |
|---|---|---|
| `Ink` | `#0A0A0A` | Black stage, primary text on light, tab selected |
| `Night` | `#161616` | Elevated black (icon circles, chips on dark) |
| `Dusk` | `#2A2A2A` | Dividers on dark surfaces |

Ink is **neutral black**. No green undertone.

### Fan (bright)

| Token | Hex | Use |
|---|---|---|
| `Flare` | `#FF3DAB` | Identity accent. Primary CTA, patient card, selected tab, “you” |
| `Acid` | `#D8FF3C` | Second shout. Caregiver card, success, “synced”. Never the whole app |
| `Aurora` | `#3DFFE7` | Charts only (the iridescent card). Never large fills |

Flare is the brand. Acid is a *card in the fan*, not Cash App green.

### Surfaces

| Token | Hex | Use |
|---|---|---|
| `Canvas` | `#F6F4F0` | Light app background (warm, not mint) |
| `Card` | `#FFFFFF` | Measurement cards, sheets, inputs |
| `Hairline` | `#E6E2DC` | Card borders, separators |
| `Mist` | `#EFECE6` | Chip fills, icon button backgrounds |

### Semantic (bright, not pastel)

| Token | Hex | Use |
|---|---|---|
| `Alert` | `#FF4D3A` | High glucose, destructive |
| `Warn` | `#FFB020` | High sedentary, caution status dot |
| `Info` | `#4D7CFF` | Low glucose, informational |
| `Mute` | `#6E6E6E` | Secondary text, timestamps, tab idle |

### Pairing rules

1. **Idle chrome:** Canvas + Card + Ink text + Mute captions. No Flare until something is active.
2. **Primary button:** Flare fill + Ink label. Not Acid fill + white. Not Cash App green.
3. **Role / fan cards:** each tile a *different* fan color. Never two of the same shout stacked.
4. **Banner / full-bleed:** Ink stage + white type, **or** one fan color dipped full-screen. Not forest + lime.
5. **Alerts:** one semantic color as a **dot or left rail**, not a whole card fill.
6. Do not put Flare and Acid on the same component. Aurora never as a fill.

---

## Typography

**Display:** Bricolage Grotesque (ExtraBold / SemiBold). Ink-trapped, a little weird, strong. Titles and metric numbers.

**Text:** Outfit (Regular / Medium / Bold). Rounder geometric body. Not Inter, not Satoshi, not Space Grotesk.

Files live in `Fonts/`. Register in `Info.plist` `UIAppFonts`. Use `AppFont` in `Shared/Theme.swift` — do not call `.system`.

| Role | Font | Weight | Size | Tracking |
|---|---|---|---|---|
| Large title (`Home`, `Who are you?`) | Bricolage Grotesque | ExtraBold | 40 | -0.8 |
| Screen title (sheets) | Outfit | Medium | 13 | 1.2 (uppercase) |
| Section (`Latest Measurements`) | Bricolage Grotesque | ExtraBold | 24 | -0.4 |
| Card title | Bricolage Grotesque | SemiBold | 22 | -0.4 |
| Metric number (`2,496`) | Bricolage Grotesque | ExtraBold | 44 | -1.0 |
| Metric unit (`steps`, `mg/dL`) | Outfit | Medium | 15 | 0 |
| Body | Outfit | Regular | 16 | 0 |
| Caption / time | Outfit | Regular | 13 | 0 |
| Button | Outfit | Bold | 17 | 0 |
| Tab label | Outfit | Medium | 10 | 0.2 |
| Status chip | Outfit | Medium | 12 | 0 |

Titles never go Outfit. Outfit is the quiet layer under the shout.

---

## Iconography

**Mark:** a flare health cross with an acid sparkline and aurora nodes. `BrandMark` in `Shared/BrandMark.swift`. App icon is the same on ink, in `Assets.xcassets/AppIcon.appiconset/`. Login shows the mark; light screens use the tiled (black square) version.

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

Tab bar: four items — **Home**, **Dashboard**, **Watch**, **Profile**. Selected = Ink icon + Flare indicator (small), not Health Mate’s purple, not Cash App lime.

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
- Copying Cash App green `#00D632`, their lime status bar, or their logo.
- Clash Display, Satoshi, Space Grotesk, Inter, or San Francisco as the brand voice.
- Light gray primary buttons.
- More than four tabs.
- A Watch app UI in this repo.
