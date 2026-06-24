# Betty iOS — Design System Spec

Audience: the engineer implementing the SwiftUI theme layer in `ios/`. Source of truth for every
visual token is the web app (`app/assets/css/global.css` plus scoped component styles); this doc
translates those tokens 1:1 into SwiftUI. Keep the visual identity faithful — Betty's look is
"indigo editorial sport": deep indigo surfaces, cream text, hot-orange CTAs, acid-green positives,
heavy (800/900) uppercase display type with tight tracking, near-square 2pt corner radii.

Tech constraints (fixed elsewhere, repeated for context): SwiftUI, iOS 17, Swift 6.2,
`@Observable`, no third-party deps, XcodeGen project in `ios/`.

---

## 1. Color palette

### 1.1 Core brand colors (theme-independent)

These never change between light and dark theme on the web — keep them constant on iOS.

| Token (Swift name)   | Hex / value | Web var      | Usage |
|----------------------|-------------|--------------|-------|
| `bettyOrange`        | `#FF5A3A`   | `--orange`   | Primary CTA, active tab underline, live badge, "YOU" badge, urgent borders |
| `bettyYellow`        | `#FFD84A`   | `--yellow`   | 2nd-place accent, semi-correct bet points, "ended" badge background |
| `bettyInk`           | `#0D0E15`   | `--ink`      | Near-black; text on yellow/green badges, dark button bg, hover darkening mix |
| `bettyIndigo`        | `#434F8E`   | `--indigo` (dark-theme value) | Brand indigo; light-theme logo tint, light-theme positive accent |
| `legacyGreen`        | `#78CC14`   | `.button--action` | Legacy action buttons only (avoid in new UI) |
| `alertRed`           | `#F44336`   | `.button--danger`, notification badge dot | Destructive buttons, unread-dot |
| `dropdownDanger`     | `#D8412F`   | `.dropdown__item--danger` | Destructive menu items on white surfaces |

### 1.2 Semantic colors (adaptive: dark theme is the DEFAULT)

Web dark-theme value first (this is what users see by default), light-theme value second
(from `:root.theme-light` in `global.css`).

| Token (Swift name)    | Dark (default)              | Light                       | Web var | Usage |
|-----------------------|-----------------------------|-----------------------------|---------|-------|
| `background`          | `#434F8E`                   | `#FFFAEB`                   | `--page-bg` / `--indigo` | Screen background, header bar |
| `surface`             | `#1F2752`                   | `#FFFFFF`                   | `--indigo-dark` | Cards, modals, game tiles, leaderboard, hero card |
| `surfaceDeep`         | `#141938`                   | `#F1EAD4`                   | `--indigo-deep` | Inset panels (countdown, banners, auth pitch) |
| `surfaceSoft`         | `#FFF5E4`                   | `#1F2752`                   | `--cream-soft` | Cream quote cards (rare) |
| `textPrimary`         | `#FFFAEB`                   | `#141938`                   | `--cream` / `--page-text` | Headings, scores, primary copy |
| `textSecondary`       | `rgba(255,250,235,0.78)`    | `rgba(20,25,56,0.82)`       | `--muted-strong` | Sub-labels, ledes, secondary numerals |
| `textMuted`           | `rgba(255,250,235,0.50)`    | `rgba(20,25,56,0.55)`       | `--muted` | Kickers at rest, dividers ("–"), placeholders |
| `textBody`            | `#CDD1E5`                   | `#525874`                   | `--body-muted` | Long-form paragraph copy |
| `accentPositive`      | `#9BFF3D`                   | `#434F8E`                   | `--green` | Winner score, bet-done border, success kickers. NOTE: light theme remaps green to indigo — keep this. |
| `overlay04`           | `white @ 4%`                | `#141938 @ 4%`              | `--surface-overlay-04` | Row hover/pressed tint |
| `overlay06`           | `white @ 6%`                | `#141938 @ 6%`              | `--surface-overlay-06` | Input bg, hairline borders |
| `overlay08`           | `white @ 8%`                | `#141938 @ 8%`              | `--surface-overlay-08` | Section rule lines, logo rings, count pills |
| `overlay10`           | `white @ 10%`               | `#141938 @ 10%`             | `--surface-overlay-10` | Input borders, avatar rings, progress track |

### 1.3 Derived / fixed-alpha tints

| Token | Value | Usage |
|-------|-------|-------|
| `orangeTint12` | `#FF5A3A @ 12%` | "You" row background (leaderboard, bet list) |
| `orangeTint15` | `#FF5A3A @ 15%` | Small score chip bg, checked checkbox bg |
| `orangeTint18` | `#FF5A3A @ 18%` | "You" row pressed, active toggle/tab-count bg |
| `modalBackdrop` | `rgba(10,14,35,0.82)` | Modal scrim (pair with blur; web: `backdrop-filter: blur(10px)`) |
| `scrimGradient` | `#141938 @ 0% → 82%` vertical | Image-card bottom overlays |
| `pillDark` | `rgba(20,25,56,0.78)` | "PUBLIC"/count badges over images (web adds blur(4)) |
| `surfaceWhite` | `#FFFFFF` (both themes) | Profile dropdown/menu, legacy `Card`, avatar-initial bg |

On white `surfaceWhite` menus the web hardcodes: title `#1F2752`, secondary `#6B7090`,
hairline `#EEF0F5`, hover `#F4F5FA`, danger `#D8412F` (hover bg `#FDF0EE`). Keep as fixed
constants in a `Theme.Menu` namespace — they do not adapt.

### 1.4 SwiftUI implementation

Define all colors **in code**, not the asset catalog, because Betty's theme is app-controlled
(default dark, user-toggled), not system-controlled (see §4). Pattern:

```swift
// ios/Betty/Theme/Palette.swift
import SwiftUI

extension Color {
  init(hex: UInt32, alpha: Double = 1) {
    self.init(.sRGB,
      red:   Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8)  & 0xFF) / 255,
      blue:  Double(hex & 0xFF) / 255,
      opacity: alpha)
  }
}

enum Palette {
  // brand (constant)
  static let orange  = Color(hex: 0xFF5A3A)
  static let yellow  = Color(hex: 0xFFD84A)
  static let ink     = Color(hex: 0x0D0E15)
  static let indigo  = Color(hex: 0x434F8E)
  static let alertRed = Color(hex: 0xF44336)
  // ...
}

struct ThemeColors {       // one instance per theme
  let background, surface, surfaceDeep, textPrimary, textSecondary,
      textMuted, textBody, accentPositive,
      overlay04, overlay06, overlay08, overlay10: Color

  static let dark = ThemeColors(
    background: Palette.indigo,
    surface: Color(hex: 0x1F2752),
    surfaceDeep: Color(hex: 0x141938),
    textPrimary: Color(hex: 0xFFFAEB),
    textSecondary: Color(hex: 0xFFFAEB, alpha: 0.78),
    textMuted: Color(hex: 0xFFFAEB, alpha: 0.50),
    textBody: Color(hex: 0xCDD1E5),
    accentPositive: Color(hex: 0x9BFF3D),
    overlay04: Color.white.opacity(0.04), /* 06/08/10 likewise */ ...)

  static let light = ThemeColors(
    background: Color(hex: 0xFFFAEB),
    surface: .white,
    surfaceDeep: Color(hex: 0xF1EAD4),
    textPrimary: Color(hex: 0x141938),
    textSecondary: Color(hex: 0x141938, alpha: 0.82),
    textMuted: Color(hex: 0x141938, alpha: 0.55),
    textBody: Color(hex: 0x525874),
    accentPositive: Palette.indigo,
    overlay04: Color(hex: 0x141938, alpha: 0.04), ...)
}
```

Views read colors via the theme environment (§4): `theme.colors.surface` etc. Never use
`Color(.systemBackground)` / `.primary` — Betty surfaces are branded, not system.

---

## 2. Typography

### 2.1 Facts from the web app

- The dashboard/app proper renders in the **system font stack** (`-apple-system, ...`) — Inter is
  only loaded on the marketing landing page (`useHead` in `app/pages/index.vue`). On iOS the
  faithful translation is **SF Pro (system font), no custom font shipped**.
- Identity lives in the weights: 800 (heavy) and 900 (black) everywhere for display text, with
  uppercase + wide tracking for labels ("kickers") and tight negative tracking for big numerals.
- Scores always use tabular numerals (`font-variant-numeric: tabular-nums`).

### 2.2 Type scale (pt = web px)

| Token | Size/weight | Tracking | Case | Web source |
|-------|-------------|----------|------|------------|
| `displayXL` | 64 / .black | -0.02em (≈ -1.3) | UPPER | hero titles `clamp(48..132px)`; clamp on iOS to 48–72 by Dynamic Type/width |
| `displayL`  | 40 / .black | -0.01em | as-is | `.section-head__title`, card-header title |
| `title1`    | 32 / .black | -0.01em | as-is | modal title (`clamp(24..32)`), `.page-title` 41px → use 34 on phone |
| `title2`    | 28 / .black | -0.02em | as-is | group-card title, game score numeral |
| `title3`    | 22 / .black | -0.02em | as-is | leaderboard place numeral |
| `headline`  | 17 / .heavy | -0.005em | as-is | stacked-row names |
| `body`      | 15 / .semibold | 0 | as-is | leaderboard names, body copy (regular for paragraphs) |
| `subhead`   | 14 / .bold | 0 | as-is | bet rows, dropdown names, ledes (13–14) |
| `caption`   | 12 / .heavy | +1.6 | UPPER | nav links, tabs, team names (+0.6, not upper-wide) |
| `kicker`    | 11 / .heavy | +1.6 | UPPER | section kickers, badges, button labels (+1.4) |
| `micro`     | 10 / .heavy | +1.2–1.4 | UPPER | "YOU" badge, countdown units, tab counts |
| `scoreXL`   | 56 / .black, monospacedDigit | -0.02em | — | bet modal score input |
| `score`     | 28 / .black, monospacedDigit | -0.02em | — | game tile score |
| `scoreRow`  | 26 / .black, monospacedDigit | -0.02em | — | leaderboard points |

Line heights: display 0.9–1.05 (use `.lineSpacing` ≈ 0 and tight `kerning`; SwiftUI can't go
below intrinsic line height — acceptable), body 1.4–1.55.

### 2.3 SwiftUI helpers

```swift
// ios/Betty/Theme/Typography.swift
extension Font {
  static func betty(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight)
  }
  static let bettyDisplayL = betty(40, .black)
  static let bettyTitle2   = betty(28, .black)
  static let bettyKicker   = betty(11, .heavy)
  static let bettyScore    = Font.system(size: 28, weight: .black).monospacedDigit()
  // ... rest of the scale
}

struct Kicker: ViewModifier {   // the single most reused style in the app
  var color: Color
  func body(content: Content) -> some View {
    content.font(.bettyKicker).kerning(1.6).textCase(.uppercase).foregroundStyle(color)
  }
}
extension View {
  func kicker(_ color: Color) -> some View { modifier(Kicker(color: color)) }
}
```

Apply `.kerning(-0.56)` (i.e. `size * -0.02`) on display/score styles. Use fixed sizes (the web
is fixed-px); optionally wrap with `@ScaledMetric(relativeTo: .title)` later — not required v1.

---

## 3. Spacing, radius, shadows, motion

### 3.1 Spacing scale (pt)

Web uses a loose 2/4-pt rhythm. Canonical tokens:

```swift
enum Space {
  static let xxs: CGFloat = 4   // 2–4 px hairline gaps
  static let xs:  CGFloat = 8
  static let s:   CGFloat = 12  // 10–12: card body padding, row gaps
  static let m:   CGFloat = 16  // 14–16: game tile padding (14/16), screen edge
  static let l:   CGFloat = 22  // 20–24: leaderboard row h-padding, card body 22
  static let xl:  CGFloat = 28  // modal h-padding 28
  static let xxl: CGFloat = 40  // 36–40: hero padding, section spacing
  static let huge: CGFloat = 56 // landing sections
}
```

Screen edge inset: 16 (web `.container` = 90% width). Grid gap between cards: 20.

### 3.2 Corner radii

| Token | Value | Usage |
|-------|-------|-------|
| `Radius.sharp` | **2** | THE Betty radius: buttons, cards, game tiles, badges, inputs, modals, chips. Near-square corners are a core identity trait — do not "iOS-ify" to 10–16. |
| `Radius.legacy` | 5 | Legacy white `Card` only |
| `Radius.pill` | `Capsule()` | tab-count pill (web 999px) |
| circle | `Circle()` | avatars, team logos, icon buttons, live blob |

### 3.3 Shadows (CSS → SwiftUI approximation: radius ≈ blur/2, keep y)

| Token | SwiftUI | Web source |
|-------|---------|-----------|
| `Shadow.card` | `.shadow(color: .black.opacity(0.3), radius: 5, y: 5)` | legacy card `0 5px 10px -7px` |
| `Shadow.lift` | `.shadow(color: Color(hex:0x141938).opacity(0.55), radius: 14, y: 12)` | group-card hover `0 18px 40px -22px` — use for pressed/featured cards |
| `Shadow.menu` | `.shadow(color: Color(hex:0x141938).opacity(0.18), radius: 12, y: 8)` | white dropdown |
| `Shadow.modal` | `.shadow(color: .black.opacity(0.6), radius: 30, y: 24)` + 1pt `overlay06` border | bet modal |

Dark-on-dark shadows read subtly; the 1pt `overlay06` ring on modals/inputs matters more than
the shadow itself.

### 3.4 Motion

- Standard transitions: `.easeInOut(duration: 0.15)` (hovers/presses) and `0.2–0.3` (page fade).
- Modal pop: web `scale 0.94→1 + translateY(8→0), 0.22s, overshoot bezier(0.2,0.9,0.3,1.15)` →
  `.spring(response: 0.25, dampingFraction: 0.75)` on scale+offset; backdrop fades `0.25s` with
  `.ultraThinMaterial`-free custom blur: `modalBackdrop` color + `.background(.thinMaterial)` is
  acceptable, or just the 82% scrim (blur optional).
- Live pulse: 8pt orange circle, ring scaling 1→~2.2 with opacity 0.7→0 over 2s,
  `.repeatForever(autoreverses: false)` (web `pulse-orange`).
- Button press: scale 0.98 / brightness +5% (replaces web hover `translateY(-1px) + brightness(1.05)`).
- Card press: `translateY(-3)` hover → use `scaleEffect(0.99)` pressed.

---

## 4. Light/dark behavior

**The web's theme is app-controlled, not system-controlled.** Dark indigo is the default for
everyone; light is an explicit user toggle in the profile/settings modal, persisted in
`localStorage["betty-theme"] = "light" | "dark"` (`app/components/UpdateProfileModal.vue`,
read at boot in `app/layouts/default.vue`). Replicate exactly:

- `@Observable @MainActor final class ThemeStore` with `var mode: ThemeMode` (`.dark` default,
  `.light`), persisted to `UserDefaults` key `"betty-theme"`. (No "system" option — the web has
  none. Easy to add later.)
- `var colors: ThemeColors { mode == .light ? .light : .dark }`.
- Inject once at the root: `.environment(themeStore)`; views read
  `@Environment(ThemeStore.self)`.
- Also set `.preferredColorScheme(themeStore.mode == .light ? .light : .dark)` at the root so
  system chrome (keyboard, alerts, status bar) matches; status bar is light-content on indigo.
- Do NOT rely on asset-catalog Any/Dark variants — they follow the system, which is wrong here.
- The light theme is a token swap, not a different design: same layout, same orange/yellow/ink,
  green→indigo remap (§1.2). White-surface menu constants (§1.3) are identical in both themes.

---

## 5. Component recipes

All components sit on `Radius.sharp` (2pt) unless noted. "Kicker" = §2.3 modifier.

### 5.1 Buttons — `BettyButtonStyle(variant:)`

| Variant | Background | Text | Label font | Padding | Notes |
|---------|-----------|------|-----------|---------|-------|
| `.primary` (orange) | `bettyOrange` | `#FFF` | 13–14 / .heavy, kerning 1.0–1.4, UPPER | v16–18, h22 | Main CTA ("PLACE BET", "NEW GROUP"). Block variant: `maxWidth: .infinity`, 17pt |
| `.outline` | clear | `textPrimary` | 14 / .bold, kerning 0.5, UPPER | v18, h24 | 1pt border `textPrimary @ 25%` (pressed 50%) |
| `.ghost` | clear | `textPrimary` | 14 / .semibold | v10, h16 | nav-level actions |
| `.dark` | `bettyInk` | `textPrimary(dark)` cream | 17 / .heavy, kerning 1, UPPER | v18, h32 | landing CTA |
| `.destructive` | `alertRed` | white | as primary | as primary | legacy `.button--danger` |

Disabled: `.opacity(0.4)`. Loading: replace label with `ProgressView` tinted white.
Pressed: `scaleEffect(0.98)` + `brightness(0.05)`, animation `.easeOut(0.15)`.

### 5.2 Cards

- **Surface card** (group card, hero, empty states): `colors.surface` bg, radius 2,
  body padding 22–24, optional 16:9 image header (`aspectRatio(16/9, .fill)`) with
  `scrimGradient` overlay and overlaid badges. Title `title2` (28/.black). CTA row at bottom:
  kicker in `bettyOrange`. Pressed: `Shadow.lift` + slight scale.
- **Inset panel** (countdown, feedback banner): `colors.surfaceDeep` bg, radius 2, **3pt left
  accent bar** in `accentPositive` (use `overlay` + `HStack` or `.background` with leading
  rectangle) — signature element, keep it.
- **Legacy white card**: white bg, radius 5, `Shadow.card`, body padding 10 (used by older
  screens; prefer surface card in new UI).

### 5.3 Game tile (`Game.vue`)

`colors.surface` bg, radius 2, padding 14–16, 1pt border: transparent default,
`accentPositive` when user's bet is placed, `bettyOrange` when urgent/missing.
Top row: kicker line (`textMuted`, 11/.heavy/+1.4/UPPER) — date/status left, awarded points
right (`textSecondary`; win → `accentPositive`). Middle: two teams (56pt circular logos with
2pt `overlay08` ring on `overlay06` fill; names 12/.heavy/+0.6/UPPER centered, truncated)
flanking the score — 28/.black monospacedDigit with 18pt `textSecondary` "–" divider.
User's own bet chip: `orangeTint15` bg, `bettyOrange` 11/.heavy text, radius 2, padding 3×8.
LIVE badge: pulsing 8pt orange blob + "LIVE" 11/.heavy/+1.4 orange. Finished games: 45% opacity.

### 5.4 List rows

- **Leaderboard row** (`Leaderboard.vue`): grid [place 56 | avatar 48 | name 1fr | points],
  padding v14 h22, bg `colors.surface`, 2pt gaps between rows (use `VStack(spacing: 2)` on a
  surface container, radius 2, clipped). Place numeral 22/.black `textSecondary`
  (1st → `bettyOrange`, 2nd → `bettyYellow`, 3rd → `textSecondary`); winner's points value
  → `accentPositive`. Points: 26/.black monospaced + "PTS" 11/.heavy `textSecondary`.
  **Current-user row**: `orangeTint12` bg + **3pt orange leading bar** (inset, signature) +
  "YOU" badge: `bettyOrange` bg, white 10/.heavy/+1.4 text, padding 3×7, radius 2.
- **Bet row** (BetModal): name 14/.bold left, score 14/.heavy monospaced right, points label
  11/.heavy — `textSecondary` default, `bettyYellow` semi-correct, `accentPositive` exact.
  Same "you" treatment as above.
- **Stacked row** (tournament group stack): name 17/.heavy, chevron `textSecondary` → orange
  on press, hairline separators `overlay04`.

### 5.5 Badges & chips

| Badge | Style |
|-------|-------|
| `you` | orange bg / white text, micro type, radius 2 |
| `live` | orange text + pulsing blob (no bg) |
| `ended` | `bettyYellow` bg / `bettyInk` text, kicker type, radius 2 |
| `public` (over images) | `pillDark` bg / white text, kicker type, radius 2; dot in `#9BFF3D` |
| `countPill` | `overlay08` bg / `textSecondary`, 10/.heavy/+1.2, Capsule; active: `orangeTint18` / orange |
| notification dot | 12pt `alertRed` circle, top-trailing of bell icon |

### 5.6 Avatars (`UserBadge.vue`)

Circle, ring = 5pt `overlay10` (hover/active → `textMuted`). Sizes: small 32, default 42,
medium 64, large 124. Image fills; fallback = white circle with initial (14–54pt by size,
`.semibold`, color `#333`). Implement `AvatarView(size: AvatarSize, url: URL?, name: String)`.

### 5.7 Tabs / segmented controls

Underline tabs (dashboard, bet modal): label 12/.heavy/+1.6/UPPER, `textMuted` → `textPrimary`
active, **3pt `bettyOrange` underline** (radius 2, `matchedGeometryEffect` for slide), 1pt
`overlay06` bottom rule across the bar. Toggle pills (grouping switch): container `overlay04`
radius 2 padding 3; active segment `orangeTint18` bg + orange text, 11/.heavy/+1.4/UPPER.

### 5.8 Inputs

Score input (bet modal): `overlay06` fill, 1pt `overlay10` border (focus → `bettyOrange`,
fill → `overlay08`), radius 2, centered 56/.black monospaced text, `.keyboardType(.numberPad)`,
label above 11/.heavy/+1.6 `textSecondary`. Generic text fields on dark surfaces follow the
same recipe at `body` size. Checkbox: 18pt, radius 2, `overlay06` fill + 1.5pt `white@20%`
border; checked: `orangeTint15` fill + orange border + orange checkmark.

### 5.9 Progress bars

6pt height track `overlay10`; segments: left `accentPositive`, right `bettyYellow`,
center (draw) `white @ 35%`. Used in bet-history split bars.

### 5.10 Navigation / header

Web header: fixed `colors.background` bar (the indigo itself — header is NOT a different
color), wordmark logo left at 36–55px tall, orange "NEW GROUP" button + avatar right; active
nav item gets the 3pt orange underline. iOS: hide the system nav bar's default styling — use
`.toolbarBackground(theme.colors.background)`, wordmark as a `ToolbarItem(placement: .principal
or .topBarLeading)` at ~28–32pt height, trailing orange capsule-less mini CTA + avatar button.
Profile menu: white `surfaceWhite` menu (use a custom popover styled per §1.3, or `Menu` with
system styling as v1 fallback).

---

## 6. Branding assets

Inventory of `public/` (verified visually):

| File | Content | iOS use |
|------|---------|---------|
| `android-chrome-512x512.png` | **Betty mascot** — orange-haired character with round glasses on a sky-blue circle, 512×512 RGBA (transparent corners) | **App icon source** (see below) |
| `apple-touch-icon.png` | Same mascot, 180×180 | reference only |
| `logo.svg` | "Betty" script **wordmark**, white fill `#FFFFFF`, 129×87, has a Sketch drop-shadow filter | **In-app logo source** (vector path also exists inline in `app/components/Logo.vue` rendered with `currentColor`) |
| `logo.png` | Same wordmark, white, 129×87 gray+alpha PNG | direct fallback raster |
| `icon.png` | 512×512 **legacy mountain logo** (teal/navy triangles) — old branding | **Do not use** |

### 6.1 App icon

- **Source: `public/android-chrome-512x512.png`** (the mascot is the brand mark used for all
  web favicons/touch icons).
- iOS requires a single 1024×1024 **opaque** PNG (no alpha) for `AppIcon.appiconset`
  (iOS 17 single-size). The source is 512×512 with transparent corners, so generate:
  composite the mascot centered at ~92% scale onto a solid **cream `#FFFAEB`** square
  (Betty's paper color; the indigo `#434F8E` square is the approved alternative if the
  cream/skin contrast looks weak on device), export 1024×1024, strip alpha.
- One-time generation (no third-party tools): `sips -z 1024 1024 android-chrome-512x512.png`
  then flatten via a 10-line CoreGraphics swift script, or do both in Preview. Commit the result
  as `ios/Betty/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024, RGB, no alpha) +
  standard `Contents.json` (`"platform": "ios", "size": "1024x1024"`). Upscaling 512→1024 is
  acceptable: flat vector-style art.

### 6.2 In-app logo (wordmark)

- The header logo is the white script wordmark tinted by theme: cream `#FFFAEB` on dark,
  brand indigo `#434F8E` on light (exactly what `Logo.vue` does with `currentColor`).
- Implement as a **template image**: export `logo.svg` (drop the shadow filter) to PNG at 2x/3x
  (≥ 258×174); `logo.png` itself works as the 2x for a 32pt-tall logo if no SVG tooling is
  handy. Asset `BettyWordmark`, `"template-rendering-intent": "template"`, then:
  `Image("BettyWordmark").renderingMode(.template).foregroundStyle(theme.mode == .light ?
  Palette.indigo : theme.colors.textPrimary)`. Height 28–32pt in the nav bar (web: 55px desktop,
  36px mobile).
- The mascot (`android-chrome-512x512.png`) may also ship as asset `BettyMascot` for the
  login/empty states (web landing uses an animated mascot video), but it is optional v1.

---

## 7. File layout in `ios/`

```
ios/Betty/Theme/
  Palette.swift        // hex init + brand constants (§1.1, §1.3 fixed values)
  ThemeColors.swift    // semantic struct + .dark/.light (§1.2)
  ThemeStore.swift     // @Observable mode store, UserDefaults "betty-theme" (§4)
  Typography.swift     // Font extensions + Kicker modifier (§2)
  Layout.swift         // Space, Radius, Shadow enums (§3)
  Styles/
    BettyButtonStyle.swift
    CardModifiers.swift     // surfaceCard, insetPanel(accent:), leftAccentBar
    BadgeViews.swift        // YouBadge, LiveBadge, EndedBadge, CountPill
    AvatarView.swift
    UnderlineTabs.swift
    ScoreText.swift         // monospacedDigit score helpers
    ProgressSplitBar.swift
```

Everything is `MainActor` by project default (`SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`);
`ThemeColors`/`Palette`/`Space`/`Radius` are `Sendable` value types — annotate `nonisolated`
where needed for use in nonisolated contexts.

Theme unit tests (Swift Testing, `BettyTests`): assert hex round-trips, dark/light token
values match this spec, `ThemeStore` default is `.dark` and persists to `"betty-theme"`.
