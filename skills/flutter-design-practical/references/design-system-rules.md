# Design System Rules

## Core Principle

Use an 8pt spacing rhythm as the default layout language. Use 4dp only for tight micro-adjustments.

This keeps the UI calm, professional, and predictable while avoiding the random spacing that often makes AI-generated interfaces look fake.

## Spacing Scale

Default spacing scale:

- `0`
- `4`
- `8`
- `16`
- `24`
- `32`
- `40`
- `48`
- `64`

Practical usage:

- `4`: tiny internal adjustment only
- `8`, `16`: default component padding and stack gaps
- `24`: section padding, card interior spacing
- `32`, `40`, `48`, `64`: page-level spacing and large empty space

Rules:

- Treat the spacing scale as the default vocabulary, not a mathematical law.
- Prefer `8`, `16`, `24`, and `32` as the dominant rhythm when they fit the design.
- Use values outside the default scale when a real component constraint, platform convention, visual alignment requirement, or existing design system justifies them.
- Do not create random one-off values merely to tune a screen by eye.
- If the same exception repeats or carries semantic meaning, consider promoting it into the project's token set.
- Prefer a small coherent spacing vocabulary over rigid adherence to one universal scale.

## Border Radius Scale

Approved radius scale:

- `0`
- `4`
- `8`
- `12`
- `16`
- `24`
- `999`

Practical usage:

- `4`: dense chips, tiny tags, compact fields
- `8`: default buttons, inputs, cards in compact systems
- `12`: modern default for cards, sheets, inputs in consumer apps
- `16`: large cards, prominent containers, bottom sheets
- `24`: highly rounded panels
- `999`: pill, capsule, avatar masks

Rules:

- Treat the radius scale as a preferred project vocabulary, not an absolute restriction.
- Pick one or two dominant radii for primary surfaces and reuse them consistently.
- Values outside the default scale are acceptable when the design specification or component geometry has a concrete reason.
- If an exception repeats, consider adding it as an intentional token rather than scattering the raw value.
- If boxes are visually nested, keep radii visually concentric; exact arithmetic may be adjusted when the design requires optical correction.

## Border and Elevation

Approved border widths:

- `1`
- `2`

Use `1` by default. Use `2` only when contrast or emphasis needs it.

Elevation rules:

- prefer subtle elevation
- use border plus surface contrast before adding heavy shadows
- keep the number of shadow presets small
- do not use large hand-made shadows by default
- prefer `Material` elevation or extremely soft shadows only when hierarchy truly needs them
- if using `BoxShadow`, keep it extremely restrained: small blur, no exaggerated spread, very low alpha
- do not add shadow merely because a surface has a `BoxDecoration`
- shadow should communicate elevation, floating hierarchy, or separation that color/border/spacing cannot express well enough
- avoid large colored shadows and wide blur/spread combinations that bleed into adjacent content and make the UI look muddy or visually stained
- prefer a small reusable shadow scale or Material elevation over unique shadow recipes per screen

## Component Heights

Recommended interactive heights:

- `32`: dense controls only
- `40`: compact but usable
- `48`: default tap target
- `56`: prominent CTA or input

Rules:

- Keep touch targets at or above `44`, preferably `48`
- Avoid visually tiny controls even if the content technically fits

## Icon Sizes

Approved icon sizes:

- `16`
- `20`
- `24`
- `32`

Use `24` as the default action icon size.

## Typography

Recommended mobile text scale:

- `12`: helper or caption
- `14`: secondary body, label
- `16`: default body
- `20`: section title
- `24`: screen title
- `32`: large display

Rules:

- Keep body text readable before making it stylish
- Use consistent line height, usually around `1.3` to `1.5`
- Avoid many near-duplicate sizes such as `15`, `17`, `19`, `23`
- prioritize clarity and reading comfort over display-like decoration

## Color System

Use semantic roles instead of raw color names:

- `primary`
- `onPrimary`
- `secondary`
- `background`
- `surface`
- `surfaceContainer`
- `outline`
- `error`
- `warning`
- `success`

Rules:

- Avoid hardcoding hex values in leaf widgets
- Use role-based colors so light and dark themes remain possible
- Favor contrast and hierarchy over decoration
- avoid neon, cyber, and loud gradient treatments unless they are core to the product direction
- ensure text and background contrast remains accessible

## Layout Rules

- Default screen horizontal padding is usually `16`
- Use `24` when the layout needs more breathing room or on tablet-width containers
- Keep lists and forms aligned to the same horizontal rhythm
- A screen should usually have one dominant visual rhythm, not many unrelated ones
- prioritize content over framing; remove borders and background panels that do not improve comprehension

## Layout Cost Rules

Use the cheapest clear layout primitive that expresses the intended constraints.

Prefer first:

- `Expanded` to fill remaining space in `Row`, `Column`, or `Flex`
- `Flexible` when the child may shrink or use less than the available space
- `Spacer` for proportional empty flex space
- `Align` for alignment
- `SizedBox` for explicit size or gaps
- `AspectRatio` for fixed aspect relationships

### LayoutBuilder

Use `LayoutBuilder` when the child composition genuinely depends on incoming parent constraints.

Typical good use:

- compact vs wide layout threshold
- constraint-driven component composition

Avoid using it simply to compute widths that `Expanded` or `Flexible` would resolve naturally.

Keep work inside its builder focused on layout decisions.

### IntrinsicHeight / IntrinsicWidth

Avoid intrinsic sizing where possible.

Intrinsic measurement may add an additional layout pass and can become expensive as tree depth or repeated children grow.

Before using `IntrinsicHeight` or `IntrinsicWidth`, try:

- normal parent constraints
- `Expanded`
- `Flexible`
- `CrossAxisAlignment.stretch`
- `Align`
- fixed dimensions when the design actually has them
- `AspectRatio`

Be especially cautious with intrinsic widgets inside lists, grids, or repeated cells.

Use DevTools layout/performance profiling when intrinsic sizing or constraint-driven rebuilds are suspected of contributing to jank.

## Image Sizing Rules

Avoid decoding very large raster images when they are displayed only as small thumbnails or compact cards.

Prefer appropriately sized source variants from an image CDN/backend when available.

For Flutter image APIs, consider `cacheWidth` / `cacheHeight` when the source image is substantially larger than the actual rendered size.

Do not undersize the decode target when the image must later zoom, animate to a much larger surface, or render sharply at a larger responsive size.

Treat image decode sizing as a memory optimization with visual requirements, not as a value to apply mechanically.

## Component Composition Rules

- Avoid "container hell": do not stack more than two decorative `Container` layers without a specific visual reason.
- Avoid wrapper hell as well: if `ConstrainedBox`, `DecoratedBox`, `Padding`, and `Center` all describe one visual box, consider a single `Container` with `constraints`, `decoration`, `padding`, and `alignment`.
- Do not flatten wrappers that carry distinct semantics or behavior such as interaction, animation, scrolling, clipping, safe-area handling, or repaint isolation.
- Prefer the shallowest source tree that still makes layout behavior obvious. Treat this primarily as a readability and maintainability rule, not a promise of automatic rendering-speed improvement.
- Prefer `Padding`, `SizedBox`, `Divider`, `Row`, `Column`, and slivers for structure.
- Prefer semantic Flutter widgets such as `Card`, `CircleAvatar`, `AppBar`, `ListTile`, `TextButton`, and `IconButton`.
- If app-wide visual consistency is required, build base components in the design system and consume those instead of rebuilding styled containers in feature code.
- Split complex UI sections into `StatelessWidget` components so the screen remains readable and maintainable.

## Decision Rules

When unsure:

1. pick the nearest approved token
2. prefer consistency over local perfection
3. add a new token only if the value repeats or carries semantic meaning
