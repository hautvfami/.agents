---
name: flutter-design-practical
description: Build or refactor Flutter UI with a practical design-system-first workflow. Use when Codex needs to create screens, standardize spacing and border radius, define tokens, improve visual consistency, or move ad-hoc UI values into `ThemeData`, `ColorScheme`, `TextTheme`, and `ThemeExtension`.
---

# Flutter Design Practical

## Goal

Build Flutter UI that is visually consistent, scalable, and easy to maintain.

This skill favors a token-first design system over one-off styling. It is intended for real product work, not Dribbble-only mockups.

It should also avoid the visual patterns that make Flutter UI look obviously AI-generated: too many decorative containers, inconsistent spacing, arbitrary radii, noisy shadows, and fake complexity with little information value.

## Workflow

### 1. Inspect the current UI architecture first

Read only the files needed to understand where design decisions currently live:

- `pubspec.yaml`
- app entry points such as `lib/main.dart`
- theme files such as `lib/theme/`, `lib/core/theme/`, `lib/design_system/`
- shared widgets such as `lib/widgets/`, `lib/shared/`, `lib/core/widgets/`
- the specific screen or component being changed

Use fast searches first:

```bash
rg -n "ThemeData|ColorScheme|TextTheme|ThemeExtension|BorderRadius|EdgeInsets|SizedBox\\(|Container\\(|BoxDecoration\\(|copyWith\\("
```

Decide which case applies:

- If the app already has tokens, extend them instead of creating a second system.
- If the app has scattered hardcoded values, normalize only the area needed for the task unless the user asks for a broader refactor.
- If the app has no design foundation, create a minimal one that can grow.

### 2. Define or normalize the design tokens before editing screens

Start with these foundations:

- spacing
- radius
- color roles
- typography
- elevation and borders
- component sizes where repeated

Keep raw numbers out of feature widgets as much as possible.

Prefer:

- `AppSpacing.md`
- `AppRadius.lg`
- `theme.colorScheme.primary`
- `theme.textTheme.titleMedium`

Avoid:

- `EdgeInsets.all(13)`
- `BorderRadius.circular(7)`
- random hex colors inside widgets
- screen-specific typography constants duplicated across files

Read [references/design-system-rules.md](references/design-system-rules.md) for the default scales and constraints.

Keep the design system at app level, typically under `app/design_system/`, so foundations and base components live outside feature folders.

If a component is clearly part of the app's base UI language, create it in the design system first and then consume it from features. Do not duplicate the same base pattern in feature code and promote it later as an afterthought.

### 3. Apply a practical spacing and radius system

Use an 8pt spacing rhythm as the default layout language. Use 4dp only for tight micro-adjustments.

This means:

- common layout gaps should usually be `8, 16, 24, 32`
- `4` is acceptable for tiny internal adjustments, not as the dominant rhythm of the UI
- avoid random values such as `6, 10, 12, 14, 18, 20, 22` unless the current app already depends on them and a migration is out of scope
- border radius should come from a small approved set, not arbitrary values

For the default approved scales, read [references/design-system-rules.md](references/design-system-rules.md).

### 4. Build UI from semantic roles, not raw styles

Colors should map to roles:

- background
- surface
- surfaceContainer
- primary
- secondary
- outline or border
- error
- success or warning if the product needs them

Typography should map to intent:

- display
- headline
- title
- body
- label

Do not create a new text style every time a screen needs emphasis. Reuse and slightly adapt the shared text system.

### 5. Avoid AI-looking UI patterns

Use these constraints by default:

- avoid "container hell": do not nest more than two decorative `Container` layers without a strong reason
- also avoid wrapper hell: when `ConstrainedBox` + `DecoratedBox` + `Padding` + `Center` only describe one visual box, consider one `Container` with `constraints`, `decoration`, `padding`, and `alignment`
- keep separate wrappers when they represent meaningful semantics, interaction, animation, clipping, scrolling, or repaint boundaries
- optimize source readability and layout intent first; do not assume fewer wrapper widgets automatically means a significant runtime performance win
- prefer `SizedBox`, `Padding`, `Divider`, and layout widgets over wrapping everything in `BoxDecoration`
- prefer semantic widgets such as `Card`, `CircleAvatar`, `AppBar`, `TextButton`, and `IconButton`
- if semantic widgets are not enough, create base components in `app/design_system/components/` instead of rebuilding raw boxes everywhere
- only promote components to the design system when they are generic, reusable, and stable enough to serve multiple screens
- nested rounded surfaces must use concentric radii: inner radius should usually equal outer radius minus the surrounding padding
- prefer content density over decorative frames
- remove unnecessary borders, shadows, and visual chrome
- add shadows only when they communicate elevation or separation; prefer border/surface contrast first
- keep custom shadows narrow and restrained: low visual intensity, modest blur, little or no spread, and no large colored glow unless the visual direction explicitly requires it

Read [references/design-system-rules.md](references/design-system-rules.md) for the detailed constraints.

### 6. Use Flutter-native theming as the source of truth

Prefer this order:

1. `ColorScheme`
2. `TextTheme`
3. `ThemeExtension` for custom tokens
4. design-system base components and shared widgets that consume those tokens

Keep feature widgets thin. If multiple screens repeat the same card, input, pill, section header, or empty state pattern, extract it.

If that repeated pattern is part of the app's design language, move it into `app/design_system/components/` before spreading it further across features.

Read [references/flutter-theme-blueprint.md](references/flutter-theme-blueprint.md) when the app needs a clean token structure.

### 7. Choose layout primitives with cost awareness

Prefer Flutter's normal constraint system before introducing layout-time measurement.

Inside `Row`, `Column`, or `Flex`, prefer `Expanded`, `Flexible`, `Spacer`, `Align`, `SizedBox`, and `AspectRatio` when they express the requirement directly.

Use `LayoutBuilder` only when the subtree genuinely needs incoming parent constraints, such as choosing a compact versus wide composition.

Treat `IntrinsicHeight` and `IntrinsicWidth` as expensive fallback tools because they may require an additional intrinsic layout pass.

Avoid intrinsic measurement in repeated list/grid items or deep subtrees unless it is genuinely required and the cost is acceptable.

Do not replace a simple flex layout with manual width calculations merely because they look more explicit.

Read [references/design-system-rules.md](references/design-system-rules.md) for detailed layout-cost rules.

### 8. Design for real usage, not isolated screens

When building or refactoring a screen:

- check density and touch targets
- check empty, loading, error, and long-text states
- check Android back behavior and app bar hierarchy
- check RTL friendliness when using directional spacing or alignment
- check tablet or large-width behavior if the layout obviously stretches
- check text and background contrast
- avoid neon, cyber, or overly loud gradients unless that is the app's explicit visual direction

Prefer mobile-first layouts that scale upward. Do not over-engineer desktop-style breakpoints unless the product needs them.

### 9. Validate before finishing

Before wrapping up:

- remove arbitrary values if a token can represent them
- confirm spacing uses the approved scale
- confirm radius uses the approved scale
- confirm colors come from roles, not ad-hoc values
- confirm typography hierarchy is consistent
- confirm the screen does not rely on container stacking for visual structure
- confirm simple flex constraints were not replaced by unnecessary `LayoutBuilder` calculations
- confirm `IntrinsicHeight` / `IntrinsicWidth` are used only when intrinsic sizing is genuinely required
- confirm common single-box layout concerns were not split across unnecessary `ConstrainedBox` / `DecoratedBox` / `Padding` / `Center` layers
- confirm custom shadows do not bleed excessively into nearby surfaces or create a muddy / tinted appearance
- confirm semantic Flutter widgets or design-system base components are used where appropriate
- confirm feature-specific widgets were not promoted into the design system prematurely
- confirm shadows and borders are minimal and intentional
- confirm code was split into clean stateless subwidgets where complexity grew
- run the smallest useful validation set

Typical commands:

```bash
dart format <changed-files>
dart analyze
flutter test
```

If all checks cannot run, report exactly what was and was not validated.

## Output Expectations

When using this skill, finish with a short summary that includes:

- whether a token system was created or extended
- which screens or components were standardized
- whether spacing and radius rules were normalized
- whether theme primitives were improved
- whether noisy or AI-looking UI patterns were removed
- any remaining UI debt or follow-up refactors

## Heuristics

- Make the smallest system change that improves long-term consistency.
- Prefer one strong visual language over many local exceptions.
- Use semantic names for tokens, not page-specific names.
- Keep design decisions centralized and usage local.
- Prefer professional restraint over decorative excess.
- If a designer handoff conflicts with maintainability, preserve the intent while aligning it to the token system.
