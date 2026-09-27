# Package Recommendations

## Core Principle

Use a small, intentional package set.

Do not add packages just because they are popular. Add them when they clearly reduce implementation cost, improve consistency, or solve a real cross-project problem.

Prefer packages with:

- strong adoption
- active maintenance
- clear platform support
- simple and explicit APIs
- a role that fits the architecture

## Recommended From The Start

These are reasonable baseline packages for many Flutter apps in this architecture.

### `google_fonts`

Use for app typography when the project needs a non-default type system.

Why:

- easy integration with `TextTheme`
- supports HTTP fetching, caching, and asset bundling
- works well with app-level theme setup

Use it through the design system and app theme, not ad-hoc in random widgets.
### `cached_network_image`

### `animate_do`

Use for simple, readable entrance and attention animations.

Why:

- lightweight widget-based animation API
- zero external dependencies
- good fit for small motion layers without building custom animation code every time

Use it with restraint. Do not animate everything.

### `shimmer`

Use for loading placeholders and skeleton states.

Why:

- widely adopted
- simple API
- fits well with app-level skeleton components in the design system

Prefer wrapping it behind app-level skeleton widgets instead of scattering raw shimmer code everywhere.

## Common Packages To Add When Needed

### `drift` + `drift_flutter`

Use when the app needs structured local persistence beyond small key-value settings.

Pair them with:

- `drift_dev` in `dev_dependencies` for code generation and migration tooling
- `build_runner` in `dev_dependencies`
- an app-level `AppDatabase` registered through `get_it`
- tables and DAOs under `app/storage/drift/`

Good fit for:

- offline caches
- user-generated structured data
- drafts and history
- relational data
- typed local queries
- transactions
- schema migrations

Keep Drift APIs below repositories. GetX controllers should not query the database directly or depend on generated Drift row / companion types.

When a shipped schema changes, increment `schemaVersion` and prefer `dart run drift_dev make-migrations` plus generated migration tests.


### `share_plus`

Use when the app needs platform share flows for text, links, or files.

Good fit for:

- sharing referral links
- sharing exported content
- sharing product or article links

### `device_info_plus`

Use when the app genuinely needs device metadata.

Good fit for:

- diagnostics
- support logs
- analytics enrichment
- environment-specific troubleshooting

Do not add it if the app never reads device information.

### `path_provider`

Use when the app needs platform file-system locations.

Good fit for:

- temporary files
- cached exports
- document storage
- downloaded files

This is often needed once the app handles files, exports, or offline assets.

## Additional Good Candidates

These are often useful, but should still be added only when the project needs them.

### `flutter_svg`

Use when the design system or assets rely on SVG icons or illustrations.

This pairs well with an asset strategy that prefers:

- `svg` for vector assets
- `webp` for raster assets

### `package_info_plus`

Use when the app needs version/build metadata for settings, logs, support, or diagnostics.

### `url_launcher`

Use when the app needs to open external URLs, email links, phone links, or store pages.

### `connectivity_plus`

Use when the app truly needs network-type awareness.

Do not confuse connectivity state with guaranteed internet access.

## Architecture Guidance

Package placement should follow responsibility:

- typography, shimmer, and UI animation packages usually surface through the design system
- platform integration packages usually surface through services or storage layers
- file-system packages usually sit behind storage or export services

Do not expose package APIs everywhere in the app if one wrapper or component can centralize them.

## Decision Rule

When unsure:

1. ask whether the package solves a real repeated problem
2. prefer the smallest package that cleanly fits the architecture
3. avoid adding heavy or overlapping packages too early
4. centralize usage behind app layers when possible
5. if the package is not needed yet, do not add it yet
