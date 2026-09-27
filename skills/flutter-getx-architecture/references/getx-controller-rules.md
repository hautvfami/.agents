# GetX Controller Rules

## Core Principle

A `GetxController` is a presentation coordinator, not the entire application.

## Controller Responsibilities

Good controller responsibilities:

- expose UI state
- trigger loading and refreshing
- handle user intent such as submit, retry, select, filter, or navigate
- map repository results into screen state
- own disposable workers or listeners related to the screen

Bad controller responsibilities:

- raw API implementation
- database setup
- route registration
- JSON model definitions
- giant cross-feature business workflows

## Visibility Rule

Keep controller internals private by default.

Prefer:

- private fields such as `_isSubmitting`
- private reactive fields such as `_profile`
- private helper methods such as `_loadProfile()` or `_mapError()`
- read-only getters for state that views need
- explicit public actions for mutations that callers are allowed to trigger

Example:

```dart
class ProfileController extends GetxController {
  final ProfileRepository _repository;

  ProfileController(this._repository);

  final _isSubmitting = false.obs;
  final _profile = Rxn<UserProfile>();

  bool get isSubmitting => _isSubmitting.value;
  UserProfile? get profile => _profile.value;

  Future<void> refresh() => _loadProfile();

  Future<void> _loadProfile() async {
    // Internal implementation.
  }
}
```

If a field, method, getter, setter, mapper, validator, or helper is only used inside the controller file, prefix it with `_`. Internal controller logic should stay private unless another file genuinely needs to call it.

Dart privacy is library-scoped rather than class-scoped. With the repository convention of keeping one primary class per file, this still prevents unrelated files from depending on controller internals.

Do not add leading underscores to ordinary local variables or parameters. They are already locally scoped.

This reduces accidental external mutation, keeps the public API intentional, and makes unused internal code easier to identify. It also allows analyzer and IDE tooling to surface dead private members more reliably after refactors.

## App-Level Controller Rule

Use an app-level controller only for small reactive state that truly belongs to the application lifecycle and is consumed across unrelated routes.

A typical placement is:

```text
app/
  controllers/
    app_controller.dart
```

Good `AppController` responsibilities:

- expose current authentication or session snapshot
- expose purchase entitlement or premium-access snapshot
- subscribe to app-level service or repository state
- provide small app-wide refresh or synchronization actions
- keep shared reactive state consistent when routes change

Keep underlying work outside the controller:

- `AuthService` owns auth SDK or session coordination
- `PurchaseService` owns store SDK, purchase stream, restore, and completion logic
- repositories own API and persistence coordination
- Drift and other storage remain below repositories or storage services

Prefer this dependency direction:

```text
AuthService / PurchaseService / repositories
                ↓
          AppController
                ↓
   feature controllers and views
```

Register `AppController` once from the initial binding and keep it alive for the app lifecycle.

Do not:

- create one app controller merely to avoid passing dependencies
- move feature-local loading, forms, filters, pagination, or tab state into global scope
- let every feature add unrelated fields to `AppController`
- duplicate auth or entitlement state independently in multiple feature controllers
- put raw SDK, HTTP, or database implementation inside `AppController`

Global state should reduce duplication and inconsistent snapshots, not create a god object.

## Dependency And Context Rule

Controllers receive repositories and services through constructor injection.

Do not resolve ordinary dependencies with `Get.find()` or `getIt()` inside controller methods.

Do not accept or retain `BuildContext` in a controller. UI context belongs to widgets.

Keep dependency flow one-way:

```text
View
  ↓
Controller
  ↓
Repository / App Service
  ↓
API / DAO / SDK
```

Repositories and lower layers must not import or call controllers.

## Derived State Rule

Do not create a reactive field when the value can be derived cheaply and reliably from an existing source of truth.

Prefer:

```dart
User? get currentUser => _currentUser.value;
bool get isLoggedIn => currentUser != null;
```

over keeping a separate `RxBool isLoggedIn` that must be synchronized manually.

## Size Rules

Warning signs that a controller is too large:

- many unrelated `.obs` fields
- methods for multiple tabs or screens that barely relate
- validation, networking, caching, and UI mapping in one file
- the view becomes just `controller.doEverything()`
- very long methods that mix many steps and branches

If this happens:

1. split repository or service logic out first
2. split feature sections into smaller widgets
3. split the flow into multiple controllers only if the screen boundaries are real

As a practical rule, if one controller method becomes long enough that it is hard to scan quickly, treat that as a signal to extract helpers or move responsibilities down a layer.

## Lifecycle Rules

Use lifecycle hooks intentionally:

- `onInit` for initial setup
- `onReady` for behavior that depends on first render or navigation completion
- `onClose` for cleanup

Do not dump every startup action into `onInit` if some work should happen lazily.

## Async State

Controllers should expose async state in a way the view can read clearly.

For simple flows, a small status enum is usually enough.

Avoid several booleans that describe the same state machine, such as `isLoading`, `hasError`, `isEmpty`, and `isSuccess`, when those values can contradict each other.

Use a small `sealed` hierarchy only when different states need different payloads and the hierarchy remains obvious in one file.

Do not introduce Freezed, union code generation, or another state framework merely to model a few simple controller states.

Prefer the simplest state representation that prevents invalid combinations and remains easy to read.

## Function Signature Rule

Prefer functions with explicit input and output contracts.

Prefer shapes such as:

```dart
Future<UserProfile> getProfile({required String id})
```

or:

```dart
ResultDart<UserProfile, AppFailure> mapProfile(ApiResponse<ProfileDto> response)
```

Avoid vague helper methods with unclear inputs, hidden side effects, or ambiguous return values.

Named parameters are usually preferable when a function has more than one meaningful input.

Keep names precise but concise. Do not repeat context already supplied by the controller or file name.

Prefer `_load()` inside `ProfileController` when there is only one obvious load operation. Use `_loadProfile()` only when the longer name actually disambiguates it from another operation.

Avoid names such as `loadProfileControllerProfileData()`, `fetchLoadUserData()`, or other combinations that repeat class context or stack synonyms.

Use predicate-style boolean names such as `isLoading`, `hasPremium`, `canPurchase`, and `shouldRefresh`.

## Modern Dart Syntax Rule

When the project language version is Dart 3.10 or newer, prefer dot shorthand when the context type is obvious and the shorter expression remains immediately readable.

Examples:

```dart
Row(
  mainAxisAlignment: .spaceBetween,
  crossAxisAlignment: .center,
)

Text(
  title,
  textAlign: .center,
  overflow: .ellipsis,
)

final Duration debounce = .milliseconds(300);
```

Do not force dot shorthand where the context type is ambiguous or where writing the type explicitly better communicates intent.

Read [dart-code-conventions.md](dart-code-conventions.md) for the full project-wide rules.
