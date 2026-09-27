# GetX Module Blueprint

## Core Principle

Structure GetX apps by feature at the presentation layer, while allowing the remote data layer to be centralized when API contracts are shared.

## Recommended Layout

Prefer this hybrid structure:

```text
assets/
docs/
lib/
  app/
    bootstrap/
      bootstrap.dart
      app.dart
    routes/
      app_pages.dart
      app_routes.dart
    gen/
      assets.gen.dart
    env/
      env.dart
      env.g.dart
    l10n/
      app_en.arb
      app_vi.arb
      app_ar.arb
      l10n.dart
      l10n_wrapper.dart
    di/
      injector.dart
    helpers/
      helpers.dart
      date_helpers.dart
      parse_helpers.dart
      validation_helpers.dart
    design_system/
      foundations/
        foundations.dart
        colors.dart
        typography.dart
        spacing.dart
        radius.dart
        elevations.dart
        theme/
          theme.dart
          app_theme.dart
          app_text_theme.dart
          app_theme_extensions.dart
      components/
        components.dart
        buttons/
          buttons.dart
          primary_button.dart
          secondary_button.dart
        inputs/
          inputs.dart
          app_text_field.dart
          search_bar.dart
          app_checkbox.dart
          app_radio.dart
          app_dropdown.dart
        feedback/
          feedback.dart
          app_dialog.dart
          app_snackbar.dart
          app_bottom_sheet.dart
          skeleton.dart
        surfaces/
          surfaces.dart
          rounded_container.dart
          app_card.dart
          avatar.dart
    bindings/
      bindings.dart
      initial_binding.dart
      login_binding.dart
      profile_binding.dart
    data/
      client/
        api_client.dart
      failures/
        app_failure.dart
      models/
        api_response.dart
        response_meta.dart
      datasources/
        auth_api.dart
        profile_api.dart
      repositories/
        auth_repository.dart
        profile_repository.dart
    storage/
      preferences/
        app_preferences.dart
      drift/
        app_database.dart
        app_database.g.dart
        tables/
          users.dart
          cached_items.dart
        daos/
          user_dao.dart
          cache_dao.dart
        migrations/
          migrations.dart
    workers/
      image_worker.dart
      parsing_worker.dart
    services/
      deeplink_service.dart
      auth_service.dart
      purchase_service.dart
      storage_service.dart
  features/
    login/
      controllers/
        login_controller.dart
      views/
        login_view.dart
      widgets/
        login_form.dart
    profile/
      controllers/
        profile_controller.dart
      views/
        profile_view.dart
      widgets/
        profile_header.dart
l10n.yaml
pubspec.yaml
Makefile
```

The exact names can vary, but keep the responsibilities stable.

## Placement Rules

Put code in `features/` when:

- it serves one user flow
- its wording is feature-specific
- its controller is route-scoped

Put code in shared app layers when:

- it is long-lived across many features
- its API is not feature-specific
- it supports app boot or global concerns
- transport contracts are reused by multiple screens or modules
- the backend surface is still small enough that per-feature API folders would add noise
- route dependency setup is easier to understand from a centralized bindings directory

Examples of app-wide layers:

- app bootstrap
- auth session
- local storage
- analytics
- theme preference
- API client
- app theme and design system
- environment configuration
- cross-cutting services
- localization
- pure helpers

## File Organization Rule

Keep file boundaries small and intentional.

Prefer:

- one primary class per file
- extracted feature widgets under the feature's `widgets/` folder
- controllers, services, repositories, and models each in their own files

Avoid:

- many unrelated classes in one file
- leaving extracted `StatelessWidget` or `StatefulWidget` classes inside a page file after they clearly became standalone widgets
- very large UI files that mix page structure with many internal widget classes

Heuristics:

- if a UI file grows beyond roughly `300` lines, review whether it should be split
- if a file contains several meaningful classes, split them unless they are tiny helpers tightly bound to one owner
- when a page extracts dedicated widgets, move them into `widgets/` rather than stacking many classes in the page file
- keep `main.dart` thin and move startup orchestration into `app/bootstrap/`

## Barrel File Rule

Use barrel files across the project for directories that contain a coherent group of related files.

Examples:

- `app/bootstrap/bootstrap.dart`
- `app/data/models/models.dart`
- `app/data/datasources/datasources.dart`
- `app/data/repositories/repositories.dart`
- `app/bindings/bindings.dart`
- `app/helpers/helpers.dart`
- `features/login/login.dart`
- `features/login/controllers/controllers.dart`
- `features/login/views/views.dart`
- `features/login/widgets/widgets.dart`
- `app/design_system/components/components.dart`
- `app/design_system/components/buttons/buttons.dart`
- `app/design_system/foundations/foundations.dart`
- `app/storage/drift/drift.dart`

Purpose:

- keep imports concise
- make module boundaries clearer
- expose a small public surface for each folder
- improve encapsulation and project organization

Rules:

- create a barrel file only when a folder has at least two related files and is likely to grow further as a module
- do not create a barrel file for a folder that currently contains only one file
- prefer importing the barrel from outside the module
- avoid giant top-level barrels that export unrelated parts of the whole app
- avoid circular exports or deeply chained barrel hierarchies that hide ownership
- use feature-level barrels such as `login.dart` to expose the public surface of a feature cleanly
- use subfolder barrels such as `controllers.dart`, `views.dart`, `widgets.dart`, `models.dart`, and `repositories.dart` when those folders contain multiple related files
- keep barrel boundaries intentional: a barrel should represent one module boundary, not a random collection of files

Good example:

- `models/` contains DTO files and exposes them via `models.dart`
- `widgets/` grows from one file to multiple related widgets, then adds `widgets.dart`

Weak example:

- one global `app.dart` exporting nearly everything in the codebase
- a folder with one file plus an unnecessary barrel that only re-exports that same file

## Binding Role

Each feature binding should:

- register the controller
- register GetX stores used by that route if the project has them
- register GetX-specific services only when they truly belong to GetX lifecycle
- resolve non-GetX dependencies from the app-level injector

A binding should not become a second controller.

## DI Boundary Rule

Prefer this split:

- `app/di/` for `get_it` or the app-level injector
- `app/bindings/` for GetX bindings only

Put these in `get_it`:

- `Dio`
- Retrofit APIs
- repositories
- env configuration
- shared preferences wrappers
- Drift `AppDatabase` and DAOs
- repositories that coordinate remote APIs and local Drift persistence
- non-GetX services

Put these in GetX bindings:

- `GetxController`
- GetX store abstractions if the project uses them
- `GetxService` or route-scoped GetX service objects

Do not use GetX bindings as a replacement for the entire app's DI container.

Folder placement does not decide DI ownership. Registration follows lifecycle and framework coupling, not the folder name.

## Bootstrap Rule

Keep startup orchestration centralized.

Prefer:

- `main.dart` only for selecting the app entrypoint and calling bootstrap
- `app/bootstrap/bootstrap.dart` for initialization flow
- `app/bootstrap/app.dart` for the root widget or app shell

Bootstrap is the right place for:

- `WidgetsFlutterBinding.ensureInitialized()`
- env initialization
- `get_it` setup
- storage boot
- service startup
- deep link startup
- localization startup
- final `runApp(...)`

Avoid scattering startup steps across `main.dart`, random services, and feature code.

Optimize bootstrap for startup time:

- only `await` steps that are truly required before the app can continue
- keep genuinely sequential dependencies sequential
- group independent startup tasks with `Future.wait(...)`
- do not block app launch on work whose result is not needed immediately

Good examples:

- env setup before constructing dependent services
- `Future.wait` for independent preference, Drift, and service warmup steps when those tasks truly require eager startup
- fire-and-forget analytics or non-critical prefetch after the app is already running

Weak example:

- long chains of sequential `await` calls where later tasks do not actually depend on earlier results

## Binding Placement Rule

Prefer centralized bindings under `app/bindings/` when:

- the app has a small or medium number of routes
- many routes depend on the same repositories or services
- you want route setup and dependency composition visible in one place

Prefer feature-local bindings when:

- the feature is large and self-contained
- the route graph is modularized by feature
- keeping the binding near the controller improves local development speed

Either way, keep the route-to-binding relationship explicit in `GetPage` registration.

## API Layer Rule

For remote APIs, prefer this split:

- `app/data/models/` for DTOs annotated with `@JsonSerializable()`
- `app/data/models/api_response.dart` for the shared generic envelope when the backend wraps payloads
- `app/data/failures/` for typed failures used with `result_dart`
- `app/data/datasources/` for `@RestApi()` Retrofit clients
- `app/data/repositories/` for all repository implementations
- `app/storage/preferences/` for small key-value settings
- `app/storage/drift/` for `AppDatabase`, tables, DAOs, migrations, and structured local data
- keep Drift below repositories; controllers and views should not import generated Drift rows, companions, or query builders
- `app/gen/` or `lib/gen/` for generated asset access such as `assets.gen.dart`
- `app/env/` for typed environment configuration generated by `envied`
- `app/l10n/` plus `l10n.yaml` for app-level localization
- `app/helpers/` for pure formatters, parsers, validators, and small stateless helper functions
- `app/design_system/` for app-wide foundations and base UI components
- `app/workers/` for isolate-backed compute tasks when worker reuse is justified
- feature folders for controllers, views, bindings, and feature-only widgets

Do not place raw API calls in controllers.

Keep repository placement consistent across the app: repositories live under `app/data/repositories/`, not inside feature folders.

Read [package-recommendations.md](package-recommendations.md) when deciding which third-party packages should be part of the project baseline.

## Helpers Rule

Keep helpers small, pure, and explicit.

Prefer `app/helpers/` for:

- formatters
- parsers
- validators
- small stateless conversion helpers
- pure utility functions with clear input and output

Avoid putting these in helpers:

- business workflows
- services with lifecycle or dependencies
- stateful objects
- navigation orchestration
- generic "misc" dumping-ground code

If logic belongs clearly to a model, repository, service, widget, or controller, keep it there instead of pushing it into helpers.

## Design System Rule

Keep the design system as an app-level concern.

Prefer `app/design_system/` for:

- foundation tokens such as colors, typography, spacing, radius, and elevations
- `ThemeData`, `TextTheme`, and `ThemeExtension` setup
- base components such as buttons, inputs, dialogs, snackbars, bottom sheets, avatars, cards, and skeleton states

Feature folders should consume design-system foundations and base components, not redefine their own parallel UI kit.

If a component is clearly part of the app's base UI language, create it in `app/design_system/components/` first and then consume it from features.

Do not let multiple features each build their own version of the same base button, input, dialog, search bar, avatar, or container pattern and only unify them later.

At the same time, keep the design system clean:

- promote components only when they are generic, reusable, and stable enough to become part of the foundation
- keep feature wording, business logic, and unstable one-off widgets out of the design system
- do not turn `app/design_system/` into a dumping ground for every reusable widget

## Services Rule

Keep `app/services/` as a semantic folder for cross-cutting services.

Examples:

- auth session coordination
- analytics wrapper
- app lifecycle coordination
- sync orchestration
- SDK wrappers
- deep link intake and routing coordination
- in-app purchase coordination

Do not assume everything in `app/services/` must be registered the same way.

Use this rule instead:

- if the service extends or depends on GetX lifecycle semantics, register it through GetX bindings
- if the service is plain app infrastructure, register it through `get_it`

Folder placement and DI ownership are related but not identical concerns.

For deep links, prefer one app-level `DeeplinkService` that receives URIs from `app_links`, parses them, and forwards explicit navigation intents into the app.

For purchases, prefer one app-level `PurchaseService` that coordinates store connection, purchase events, entitlement refresh, restore flow, and communication with the rest of the app.

Read [purchase-rules.md](purchase-rules.md) when the project needs in-app purchase architecture or implementation guidance.

## Environment Rule

Keep environment configuration as an app-level concern.

Prefer `app/env/` for:

- the `envied` annotated env definition
- generated typed environment access
- switching between env files in build workflows

Feature folders and services should consume typed env values, not read raw env files directly.

## Localization Rule

Keep localization as an app-level concern.

Prefer:

- `app/l10n/app_en.arb` as the source of truth
- content writers editing English only
- `arb_translate` generating the other locale ARB files
- `gen_l10n` generating the localization access classes used by widgets
- one thin wrapper such as `L10n.tr` for app-wide localization access

Feature folders should consume the app's localization wrapper, not define their own localization flow or call generated accessors directly everywhere.

Do not treat translated ARB files as the primary editing surface.

## Deep Link Rule

Keep deep link intake centralized.

Prefer:

- `app/services/deeplink_service.dart`
- one subscription point for incoming links
- route parsing or intent mapping in the service layer
- navigation handoff to the app's routing layer after parsing
- a public `DeeplinkService.navigate(String url)` method as the main routing entrypoint

Do not let each feature open its own deep link stream subscription.

If using `app_links`, instantiate it early enough to catch the first cold-start link and disable Flutter's default deep link handler in mobile platform configuration.

## Route Rule

Prefer each major screen or flow to have:

- one `GetPage`
- one binding
- one main controller
- subwidgets below the view

If multiple pages share a controller only because the architecture is tangled, split them.
