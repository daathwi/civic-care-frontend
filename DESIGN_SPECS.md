# CivicCare Flutter Design Specs (Theme + Typography)

This document consolidates the Flutter app’s current design tokens and typography rules taken from:

- `lib/core/app_theme.dart`
- `lib/main.dart`
- `lib/widgets/adaptive_scaffold.dart`
- `lib/widgets/civic_ui.dart`

---

## 1) Brand & Color Theme

### Primary (brand accent)
- **Primary / Teal**: `#008080` (`0xFF008080`)
- **Primary Dark**: `#006666` (`0xFF006666`)
- **Primary Light (tint)**: `#E6F7F7` (`0xFFE6F7F7`)

### Surfaces
- **Scaffold / Grouped background**: `#F2F2F7` (`0xFFF2F2F7`)
- **Card background**: `#FFFFFF`

### Text
- **Text Primary**: `#000000`
- **Text Secondary** (iOS system gray): `#8E8E93` (`0xFF8E8E93`)
- **Text Muted (custom)**: `#72777F` (`0xFF72777F`)

### Borders / Dividers
- **Border / Separator**: `#E5E5EA` (`0xFFE5E5EA`)

### Semantic / Status colors
- **Success**: `#34C759` (`0xFF34C759`)
- **Warning**: `#FF9500` (`0xFFFF9500`)
- **Error**: `#FF3B30` (`0xFFFF3B30`)
- **Info**: `#007AFF` (`0xFF007AFF`)

### Voting colors (used in vote UI)
- **Upvote green**: `#059669` (`0xFF059669`)
- **Downvote red**: `#DC2626` (`0xFFDC2626`)

---

## 2) Typography Specs (Fonts + Key Sizes)

### App-wide font strategy
- `ThemeData.fontFamily`: **`SF Pro Display`** (intended iOS-like default)
- `ThemeData.textTheme`: `GoogleFonts.interTextTheme()` (fallback styling when SF Pro isn’t available)

### Fonts actually used in UI
- **Inter**: main body, lists, navigation labels, analytics tables where not overridden.
- **Outfit**: headings and “premium” UI labels (app titles, section headers, some dashboard titles, drawer headings).

### Explicit key sizes used in components

#### App bars
- **Mobile `AdaptiveScaffold` AppBar title**: Outfit `fontSize: 18`, `fontWeight: bold`
- **Desktop `AdaptiveScaffold` app title**: Outfit `fontSize: 20`, `fontWeight: bold`

`main.dart` (MaterialApp `appBarTheme`) sets:
- AppBar title text style: `fontSize: 17`, `fontWeight: w600`, `letterSpacing: -0.4`, color = `textPrimary`

#### Primary button (ElevatedButton)
Defined in `main.dart`:
- Button text: `fontSize: 17`, `fontWeight: w600`, `letterSpacing: -0.4`
- Button padding: vertical `16`
- Button corner radius: `buttonRadius = 16`

#### Mobile floating bottom navigation labels
- Selected/unselected nav label: **Inter**
  - Mobile nav label font: `fontSize: 10`, `fontWeight: w700` when selected, `w500` when not selected

#### Desktop sidebar navigation labels
- Desktop sidebar nav label font: **Inter**
  - `fontSize: 14`, `fontWeight: w700` when selected, otherwise `w500`

#### Drawer (mobile)
- Drawer “CivicCare” brand: **Outfit**
  - `fontSize: 22`, `fontWeight: bold`
- Drawer portal label (role): **Outfit**
  - `fontSize: 10`, `fontWeight: w700`, `letterSpacing: 1.5`
- Drawer item labels: **Outfit**
  - Typical item font: `fontSize: 15`, `fontWeight: w600`

#### Vote buttons (used in feeds / cards)
- Vote count label: **Inter**
  - `fontSize: 13`, `fontWeight: w600`

---

## 3) Layout Tokens (Radius, Shadows, Spacing)

### Corner radii
- **Card radius**: `24.0`
- **Button radius**: `16.0`
- **Input radius**: `12.0`

Used across:
- `AppTheme.cardDecoration()`
- `ElevatedButtonThemeData`
- `InputDecorationTheme`

### Card shadows (default)
- `BoxShadow`:
  - alpha: `0.03`
  - blur radius: `16`
  - offset: `(0, 4)`

---

## 4) Glassmorphism (Frosted Panels)

### Reusable glass widget
`AppTheme.glass()` uses:
- Default blur: `sigmaX = sigmaY = 20`
- Default overlay color: `0xB3FFFFFF` (70% white)
- Optional `borderRadius`

### Typical glass usage
- **Mobile floating bottom bar**:
  - blur: `30`
  - color: white with alpha `0.8`
  - borderRadius: `30`
  - height: `64`
- **Desktop sidebar**:
  - blur: `40`
  - color: white with alpha `0.7`

---

## 5) Core Component Styling

### Cards
`AppTheme.cardDecoration()`:
- background: `AppTheme.cardBg` (`Colors.white`)
- radius: `cardRadius` (24)
- shadow: default BoxShadow list

### Inputs
`AppTheme.inputDecoration()` and `main.dart` `inputDecorationTheme`:
- filled: `true`
- fillColor: `white`
- borderSide: none
- focused border:
  - width `2`
  - color `AppTheme.primary` (`#008080`)
- padding: horizontal `16`, vertical `12`

### Vote Buttons (`CivicVoteButton`, `CivicVoteCounts`)
- vote container:
  - borderRadius: `12`
  - border: `width 1`, color = vote color with alpha `0.25`
  - background: vote color with alpha `0.08`
- icons:
  - icon size: `18` in full vote button
  - count font: `Inter 13 w600`

### Offline Banner (`OfflineBanner`)
- background: `Colors.grey[800]`
- text: Inter `fontSize: 13`, `fontWeight: w600`, color = white

### Proximity Warning (`ProximityWarning`)
- background: `#FFF3E0` (`0xFFFFF3E0`)
- border:
  - color: warning (`#FF9500`)
  - width: `1.5`
- “Not at Site” title:
  - Outfit `fontSize: 15`, `fontWeight: w700`
- distance line:
  - Inter `fontSize: 12`

---

## 6) Dark Mode / Theming Notes

- The current design tokens are defined for a light UI (white surfaces + iOS-like grouped background).
- No explicit `ThemeData.brightness` or dark palette overrides were found in the central theme files.
- If you add dark mode, replicate:
  - primary remains teal
  - surface/scaffold changes away from `#F2F2F7`
  - cardBg becomes a dark neutral with reduced contrast

