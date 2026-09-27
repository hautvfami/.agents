---
name: flutter-getx-architecture
description: Build or refactor Flutter apps that use GetX with clear module boundaries, disciplined dependency injection, practical reactive state, and a strict API stack based on `retrofit`, `json_serializable`, and `result_dart`. Use when Codex needs to organize GetX features, split controllers and views, add bindings, standardize navigation and dependency setup, or stop GetX usage from spreading chaotically across the app.
---

# Flutter GetX Architecture

## Goal

Use GetX as a practical app architecture tool, not as an excuse to mix routing, state, UI, and data access in the same file.

This skill favors feature-based structure, route-level dependency injection, thin views, and controllers that coordinate state instead of owning the whole application.

## Workflow

### 1. Inspect the current GetX setup first

Read only the files needed to understand how GetX is currently used:

- `pubspec.yaml`
- app entry points such as `lib/main.dart`
- bootstrap files such as `app/bootstrap/`
- route definitions such as `app_pages.dart`, `app_routes.dart`, or `routes/`
- feature folders that contain `view`, `controller`, `binding`, or `service`
- base controller or base service abstractions if they exist

Use fast searches first:

```bash
rg -n "GetMaterialApp|GetPage|Bindings|BindingsBuilder|GetxController|GetView|GetWidget|Get\\.put|Get\\.lazyPut|Get\\.find|\\.obs|Obx\\(|GetBuilder\\(|GetxService"
```

Decide which case applies:

- If the app already has a clean feature structure, extend it instead of inventing a new layout.
- If `Get.put` and `Get.find` are scattered through views, move dependencies toward bindings and constructors where possible.
- If controllers own networking, persistence, mapping, and UI state together, split responsibilities before adding more features.

### 2. Keep bootstrap separate from feature and runtime code

Keep `main.dart` thin and move startup orchestration into `app/bootstrap/`.

Prefer bootstrap code for:

- binding initialization
- env and DI setup
- storage boot
- service startup
- deep link startup
- localization startup
- final app launch

Avoid letting feature code, controllers, or random services own app startup.

Also optimize bootstrap sequencing:

- only `await` work that is required before the next step can proceed
- keep truly dependent steps sequential
- group independent startup tasks with `Future.wait(...)`
- avoid blocking startup on results that are not needed immediately

### 3. Organize UI by feature, but allow a shared data layer

Prefer feature-based modules for GetX presentation code:

- feature folder
- controller
- view
- widgets

Bindings may live either:

- near the feature when the dependency graph is small and clearly local
- in a centralized app-level bindings layer when many routes share the same dependencies or when you want one place to inspect route composition

Prefer a shared data layer for remote API code when:

- the app has few API groups
- DTOs are reused across multiple features
- one backend contract serves many screens
- the generic envelope such as `ApiResponse<T>` is shared across the whole app

Keep feature-only code inside the feature. Move transport-level code to shared app data when reuse is real.

Repositories live in `app/data/repositories/` as a single app-wide rule.

Read [references/getx-module-blueprint.md](references/getx-module-blueprint.md) for the default module structure.

### 4. Use `Bindings` as the default dependency composition point

Prefer:

- route-level `Bindings`
- `Get.lazyPut` or equivalent GetX registration for controllers, GetX stores, and GetX-specific services
- `Get.putAsync` only for dependencies that truly require async initialization
- `GetxService` for app-wide long-lived services

Avoid:

- calling `Get.put` from widget build methods
- ad-hoc `Get.find` in many leaf widgets
- using GetX bindings as a general-purpose container for every dependency in the app

Each feature route should declare what it needs. Dependency graphs should be discoverable from bindings, not hidden in random widget trees.

Do not force bindings into feature folders if centralized bindings make route composition clearer.

Keep the DI boundary explicit:

- use GetX bindings for GetX controllers, GetX stores, and GetX-specific services
- use `get_it` for app infrastructure such as `Dio`, Retrofit APIs, env config, preferences wrappers, Drift databases and DAOs, repositories, and other non-GetX dependencies

Do not assume folder location defines DI ownership. A file under `app/services/` may still belong to `get_it` if it is not GetX-coupled.

### 5. Keep controllers focused on presentation orchestration

Controllers should usually:

- hold screen state
- call use-case, repository, or service methods
- expose reactive fields for the view
- translate user actions into app behavior

Controllers should usually not:

- render widget trees
- contain raw HTTP code
- parse JSON directly unless the app is very small
- become god objects that manage multiple unrelated screens

Async lifecycle hygiene:

- Do not use `unawaited` just to silence an intentionally fire-and-forget call
  from `onInit`, `onReady`, or similar lifecycle hooks. Call the method directly
  when the app intentionally does not await it.
- Do not extract a wrapper method whose only job is to call one other method.
  Keep the direct call at the lifecycle site unless the wrapper adds real
  branching, error mapping, cleanup, or reuse.

Read [references/getx-controller-rules.md](references/getx-controller-rules.md) for controller boundaries.

Apply the same visibility discipline across all handwritten Dart code:

- make fields, methods, helpers, and declarations private with `_` when they are not part of the intended external API
- expose narrow getters or explicit actions instead of public mutable internals
- remember that Dart privacy is library-scoped; do not add leading underscores to ordinary local variables or parameters
- when the project uses Dart 3.10 or newer, prefer dot shorthand for enums, constructors, and static members when the context type is obvious and readability improves
- do not force dot shorthand when the context is ambiguous or the explicit type communicates intent better

For state used across unrelated routes, promote only the shared reactive projection to app scope. A small `AppController` may expose auth/session and purchase-entitlement state, while `AuthService`, `PurchaseService`, repositories, APIs, and storage keep the underlying coordination and infrastructure responsibilities.

Read [references/dart-code-conventions.md](references/dart-code-conventions.md) for the full Dart/GetX code conventions, including private APIs, `final`/`const`, dependency resolution, `BuildContext` boundaries, typed data, state modeling, naming, imports, class modifiers, module exports, and app-wide state.

### 6. Enforce the API stack: `retrofit` + `json_serializable` + `result_dart`

For networked features, API access must use:

- `retrofit` for REST client declarations
- `json_serializable` for request and response model mapping
- `result_dart` for repository and app-facing success or failure flows
- generated `*.g.dart` and Retrofit client files via `build_runner`

Prefer this flow:

- controller calls repository
- repository calls shared Retrofit data source or API client
- Retrofit client returns DTO or a generic response envelope model
- `json_serializable` handles `fromJson` and `toJson`
- repository converts transport success or failure into `ResultDart<T, AppFailure>` or the project's equivalent typed failure contract

Avoid:

- raw `Dio` or `http` calls inside controllers
- manual `Map<String, dynamic>` parsing in controllers or views
- handwritten serializer boilerplate when `json_serializable` should own it
- mixing transport DTOs directly with unrelated UI state when a mapping boundary is needed
- naming a custom generic wrapper `Response<T>` because it conflicts with `dio.Response`
- throwing ad-hoc exceptions through controllers when a typed result would keep error handling explicit

Read [references/retrofit-json-serialization-rules.md](references/retrofit-json-serialization-rules.md) for the required structure and generation flow.

### 7. Choose local persistence deliberately: `shared_preferences` or `drift`

For local persistence, prefer only these two storage directions unless the user explicitly asks otherwise:

- `shared_preferences` for small, simple, stable key-value settings that need quick access
- `drift` for structured local data, relational data, larger datasets, offline caches, and data that needs typed queries or migrations

Prefer `shared_preferences` for:

- onboarding flags
- selected locale
- theme mode
- feature toggles
- tiny cached primitives

If the app already uses `get_it` or `injectable` for bootstrap dependencies, it is acceptable to pre-resolve the shared preferences wrapper there so app-level settings are ready before first use.

Prefer `drift` for:

- user-generated content
- cached profiles, feeds, drafts, history, or offline data
- structured records with relationships or indexes
- data that changes often or requires filtering, ordering, joins, transactions, or reactive queries
- persisted models whose schema will evolve and therefore require explicit migrations

Keep Drift below the repository boundary:

- define one app-level database such as `AppDatabase`
- keep tables and DAOs under `app/storage/drift/`
- register the database and DAOs through `get_it`, not GetX bindings
- let repositories coordinate remote APIs and local DAOs when offline/cache behavior is needed
- do not run raw Drift queries from controllers or views
- do not leak generated Drift rows, companions, or query objects into presentation code

Treat schema changes as versioned changes:

- bump `schemaVersion` whenever a shipped schema changes
- prefer `dart run drift_dev make-migrations` to generate migration helpers and tests
- keep migration code explicit and test upgrades from older schema versions
- never rely on destructive recreation for production user data unless the product explicitly permits data loss

Avoid:

- storing growing JSON blobs in `shared_preferences`
- treating `shared_preferences` like a mini database
- preloading too many preference keys at startup without a clear reason
- putting database access directly in GetX controllers
- mixing multiple DI styles without a clear composition boundary

Read [references/local-storage-rules.md](references/local-storage-rules.md) for the storage decision rules.

### 8. Generate asset access with `flutter_gen`

Do not hardcode asset paths in widgets, themes, or services.

Use:

- `flutter_gen_runner` for generated asset access
- generated classes such as `Assets.images.logo`, `Assets.icons.close`, or generated font helpers
- `pubspec.yaml` as the source of truth for asset declarations

Prefer:

- `Assets.images.logo.image()`
- `Assets.icons.close.svg()`
- `Assets.images.banner.path`

Avoid:

- `Image.asset('assets/images/logo.png')`
- raw string paths spread across the app
- duplicating asset path constants by hand

Read [references/flutter-gen-asset-rules.md](references/flutter-gen-asset-rules.md) for the setup and usage rules.

### 9. Manage app environment with `envied`

Use `envied` for environment configuration instead of hardcoding base URLs, API keys, or feature flags in source files.

Prefer:

- a generated env class under an app-level env folder
- `.env` or environment-specific env files as build inputs
- typed access such as `Env.apiBaseUrl`

Avoid:

- scattering `const String baseUrl = ...` across the app
- reading raw `.env` files directly in runtime code
- duplicating environment constants in multiple files

Read [references/envied-rules.md](references/envied-rules.md) for the setup and usage rules.

### 10. Use `worker_manager` only when background compute is justified

For CPU-intensive or repeated background work, consider `worker_manager`.

Prefer `worker_manager` when:

- the task is CPU-bound and risks blocking the UI thread
- the work is repeated enough that isolate reuse is worthwhile
- parsing, transformation, compression, encryption, or other heavy computation happens often

Do not introduce `worker_manager` when:

- the task is small
- the work happens rarely
- ordinary async code is already sufficient
- isolate management would add more complexity than value

Read [references/worker-manager-rules.md](references/worker-manager-rules.md) for the decision rules.

### 11. Handle deep links through an app-level `DeeplinkService`

Use a dedicated app-level `DeeplinkService` for deep links and navigation links.

Prefer:

- `app_links` as the incoming link source
- one `DeeplinkService` under `app/services/`
- early initialization so the first cold-start link is not missed
- handling only app-owned path prefixes such as `/a/*` or `/app/*`
- mapping incoming URIs into explicit navigation intents or route commands before handing them to navigation
- one `DeeplinkService.navigate(String url)` entrypoint for validation and routing

Avoid:

- parsing deep links directly inside views or controllers
- letting many features subscribe to `app_links` independently
- mixing Flutter's default deep link handling with plugin-based handling
- opening the app for arbitrary website paths that were not designed for app navigation

If using `app_links`, disable Flutter's default deep link handler:

- set `flutter_deeplinking_enabled` to `false` in `AndroidManifest.xml`
- set `FlutterDeepLinkingEnabled` to `false` in `Info.plist`

Read [references/deeplink-rules.md](references/deeplink-rules.md) for the service and platform rules.

### 12. Keep localization app-level with `app_en.arb` + `arb_translate`

Treat localization as an app-level concern.

Prefer:

- `app_en.arb` as the single human-written source of truth
- content writers writing English only in `app_en.arb`
- `arb_translate` generating the other locale ARB files
- `gen_l10n` generating the localization access classes used by the app

Avoid:

- editing translated ARB files manually unless there is a specific correction workflow
- hardcoding user-facing strings in Dart widgets
- letting each feature invent a separate localization mechanism

Read [references/localization-rules.md](references/localization-rules.md) for the localization workflow.

### 13. Choose reactivity deliberately

Use the simplest tool that matches the state shape.

Prefer:

- simple fields + `update()` with `GetBuilder` for localized rebuild regions
- `.obs` + `Obx` for truly reactive values that change independently
- `StateMixin` only when it genuinely clarifies async UI states

Avoid:

- making every field `.obs`
- wrapping large screens in one giant `Obx`
- nesting reactive builders without a clear reason

Read [references/getx-reactivity-rules.md](references/getx-reactivity-rules.md) for when to use `Obx`, `GetBuilder`, and workers.

### 14. Keep views thin and predictable

Views should usually:

- read controller state
- wire callbacks
- compose widgets
- delegate repeated sections to feature widgets or shared widgets

Views should usually not:

- fetch dependencies in many places
- run business logic inline
- contain duplicated loading, empty, or error handling everywhere

Prefer one controller per screen or tightly related flow. If a screen needs too many controller responsibilities, split the feature instead of stacking more reactive variables.

### 15. Keep navigation and side effects explicit

Use GetX navigation intentionally:

- define routes centrally
- use bindings to prepare dependencies before entering a screen
- keep navigation methods readable and close to feature intent

Do not hide important side effects behind generic helpers if that makes call sites impossible to reason about.

For app-wide effects such as auth session, connectivity, or local storage bootstrapping, prefer dedicated services.

### 16. Validate before finishing

Before wrapping up:

- confirm dependencies are registered in predictable places
- confirm `main.dart` stays thin and bootstrap logic lives under `app/bootstrap/`
- confirm bootstrap does not use unnecessary sequential `await` chains
- confirm GetX bindings only register GetX-facing objects
- confirm non-GetX infrastructure is resolved from `get_it` or the project's app-level DI container
- confirm controllers do not own too many responsibilities
- confirm non-API fields, methods, helpers, and declarations are private by default
- confirm controller methods and helpers used only inside their own file are private
- confirm stable references use `final` and obvious immutable Flutter values/widgets use `const`
- confirm dependencies are resolved at composition boundaries and injected rather than looked up deep in business code
- confirm required GetX dependencies are not hidden behind `Get.isRegistered → Get.find` defensive checks
- confirm missing required registration fails fast instead of silently skipping behavior
- confirm `BuildContext` does not leak into controllers, services, repositories, or DAOs
- confirm avoidable `dynamic`, unnecessary `late`, and exposed mutable collections are removed
- confirm dependencies flow View → Controller → Repository/Service → API/DAO/SDK without reverse imports
- confirm derived state is not duplicated as separately synchronized reactive fields
- confirm enum/sealed state is simpler than the boolean alternative and no Freezed/codegen was introduced just for simple state
- confirm names are precise but concise and do not repeat class/file context unnecessarily
- confirm controller and service methods use guard clauses / early returns to avoid unnecessary nesting
- confirm the implementation is no larger than necessary for the actual business logic
- remove speculative safe-checks for states already made impossible by types, bindings, or established invariants
- keep validation at real boundaries such as user input, API data, persisted legacy data, deep links, platform callbacks, and optional values
- review sequential `await` chains and use `Future.wait` when independent async work can safely run concurrently
- confirm short one-statement `if` guards remain compact when readability is clear
- confirm every unexpected caught exception is logged or reported with error and stack trace
- confirm error logs carry useful context such as `ClassName.methodName` and are not duplicated at every layer
- confirm meaningful UI blocks are extracted as widgets rather than large widget-returning helpers where appropriate
- confirm widget trees avoid unnecessary source-level wrapper depth when one clear widget can express the same visual box
- confirm simple flex/layout constraints use `Expanded`, `Flexible`, or other direct layout primitives before `LayoutBuilder`
- confirm `LayoutBuilder` is used only when incoming parent constraints actually affect composition
- confirm `IntrinsicHeight` / `IntrinsicWidth` are avoided unless intrinsic sizing is truly required
- confirm custom shadows are intentional, restrained, and do not create wide muddy color bleed
- confirm abstractions such as BaseRepository/BaseController/BaseService exist only when real repeated behavior justifies them
- confirm repeated class-internal logic stays in private methods until real reuse justifies extraction
- confirm reusable type-focused behavior uses extensions when that reads naturally
- confirm common date/time display formatting is centralized in `DateTime` extensions rather than repeated raw format strings
- confirm mixins are used only for genuine shared instance behavior and stay narrowly focused
- confirm imports are minimal and intentional module barrels export only stable public surfaces
- confirm public mutable state is intentional and not just exposed for convenience
- confirm dot shorthand is used where Dart >= 3.10 and the context type is obvious
- confirm truly cross-feature reactive state such as auth/session or purchase entitlement is not duplicated across feature controllers
- confirm app-wide state lives in a small app-level controller while SDK/API/storage coordination stays in services and repositories
- confirm API clients use `retrofit`
- confirm JSON models use `json_serializable`
- confirm repositories return explicit results instead of leaking transport exceptions upward
- confirm local storage choice matches data size and volatility
- confirm assets are accessed through generated APIs instead of raw strings
- confirm environment values come from `envied` instead of ad-hoc constants
- confirm `worker_manager` is used only for work heavy enough to justify isolate complexity
- confirm deep links are handled through one app-level service
- confirm Flutter's default deep link handler is disabled when using `app_links`
- confirm English text lives in `app_en.arb` as the source of truth
- confirm translated ARB files are generated through `arb_translate`
- confirm reactive rebuild scope is narrow enough
- confirm views are thinner than before
- remove unnecessary `Get.find`, `.obs`, or wrapper builders
- run the smallest useful validation set

Typical commands:

```bash
dart format <changed-files>
dart run build_runner build --delete-conflicting-outputs
dart analyze
flutter test
```

If full validation cannot run, report exactly what was and was not validated.

## Output Expectations

When using this skill, finish with a short summary that includes:

- which feature or route boundaries changed
- whether bindings and dependency injection were standardized
- whether controller responsibilities became clearer
- whether class and library public API surfaces were narrowed appropriately
- whether modern Dart dot shorthand was used where it improves readability
- whether truly app-wide reactive state was centralized without creating a god controller
- whether the API layer was normalized to `retrofit`, `json_serializable`, and `result_dart`
- whether local persistence was placed in `shared_preferences` or `drift` for the right reasons
- whether asset access was normalized to `flutter_gen`
- whether app configuration was normalized to `envied`
- whether background compute used `worker_manager` appropriately or was intentionally avoided
- whether deep links were centralized in `DeeplinkService`
- whether localization was normalized to `app_en.arb` plus `arb_translate`
- whether reactive usage was simplified or narrowed
- any remaining architectural debt

## Heuristics

- Feature scope first, global scope second.
- Bindings are the default composition root for GetX features.
- Controllers orchestrate; services and repositories execute.
- Private by default: expose only intentional APIs; keep internal fields and helpers library-private.
- Controller-internal logic stays private so dead code remains easy for analyzer and IDE tooling to detect.
- Prefer `final` by default and `const` where practical in Flutter UI.
- Resolve dependencies at composition boundaries; inject them into controllers and services.
- Required GetX registrations should fail fast; do not hide wiring bugs with routine `Get.isRegistered` checks.
- Prefer guard clauses and early returns over nested control flow.
- Prefer minimum sufficient code: fewer lines and branches when they solve the same problem just as clearly.
- Safety checks belong at real failure boundaries; do not bury business logic under speculative impossible-state handling.
- Independent async work should run concurrently with `Future.wait` when ordering and shared-state constraints do not require serialization.
- Keep short single-statement guards compact when they remain obvious.
- A caught unexpected exception must be observable: log/report `error` and `stackTrace` with useful call-site context.
- Keep `BuildContext` in the widget layer.
- Avoid `dynamic`, unnecessary `late`, and externally mutable internal collections.
- Preserve one-way dependencies: View → Controller → Repository/Service → API/DAO/SDK.
- Prefer derived getters over duplicated state.
- Use enum or a small sealed hierarchy only when it makes state simpler; do not add Freezed/codegen for simple state.
- Names should be precise and short enough to scan; do not repeat obvious class or file context.
- Prefer simple concrete code over premature base classes or generic abstractions.
- Keep Flutter widget trees shallow when wrappers add no distinct semantics or behavior; consolidate one visual box when it improves readability.
- Prefer Flutter's normal constraint system and flex primitives before layout-time builders or intrinsic measurement.
- `LayoutBuilder` is for genuine constraint-dependent composition; intrinsic sizing is a last resort, especially in repeated/deep trees.
- Shadows express hierarchy, not decoration by default; keep custom blur/spread/color restrained.
- Reuse should follow ownership: private method first, extension for type-focused behavior, mixin only for proven shared instance behavior.
- Common date/time presentation formatting belongs in focused `DateTime` extensions; one-off formats may stay local.
- Barrel files expose stable module APIs, not every implementation file.
- Use Dart dot shorthand when the context type is obvious and the project language version supports it.
- Global state is for cross-feature app-lifecycle state, not feature-local convenience.
- `AppController` may expose shared auth/session and entitlement state; underlying SDK and data coordination stays in services and repositories.
- API contracts use `retrofit`; JSON mapping uses `json_serializable`; repository flows use `result_dart`.
- Small stable keys use `shared_preferences`; structured or evolving local data uses `drift`.
- Assets use `flutter_gen`, not hardcoded paths.
- App environment uses `envied`, not duplicated constants.
- `worker_manager` is for heavy repeated compute, not default async work.
- Deep links flow through one `DeeplinkService`, not scattered listeners.
- English content lives in `app_en.arb`; other locales come from `arb_translate`.
- Use the smallest reactive surface that works.
- If GetX usage becomes invisible magic, the architecture is too implicit.
