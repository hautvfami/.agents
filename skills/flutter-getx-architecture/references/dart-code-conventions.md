# Dart Code Conventions

## Core Principle

Keep public APIs intentionally small, use modern Dart syntax when it improves clarity, and promote state to app scope only when that state genuinely belongs to the whole application.

These rules apply across controllers, services, repositories, models, widgets, helpers, and other handwritten Dart code.

## Private By Default

If a field, method, getter, setter, helper class, or top-level declaration is not part of the intended external API, make it private with a leading underscore.

Prefer:

```dart
class ProfileController extends GetxController {
  final ProfileRepository _repository;

  ProfileController(this._repository);

  final _isLoading = false.obs;
  final _profile = Rxn<UserProfile>();

  bool get isLoading => _isLoading.value;
  UserProfile? get profile => _profile.value;

  Future<void> refresh() async {
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Internal implementation.
  }
}
```

Avoid exposing mutable internals merely because another class might want to reach into them later.

Prefer a narrow public surface made of:

- state that consumers truly need to read
- explicit actions that consumers are allowed to trigger
- immutable or read-only projections when mutation should remain internal

Dart privacy is library-scoped, not class-scoped. With the repository convention of keeping one primary class per file, a leading underscore still prevents unrelated files and libraries from depending on internal implementation details.

Do not prefix local variables, parameters, or local functions with `_` just to make them look private. Local identifiers are already scoped locally. Use `_`, `__`, and similar names only for intentionally unused callback parameters.

## Public API Rule

Treat every public member as an intentional contract.

Before leaving a declaration public, ask:

1. does another file or module genuinely need this?
2. should callers be allowed to mutate it directly?
3. would a getter or explicit method communicate intent better?
4. will making it public encourage unrelated classes to couple to this implementation?

If the answer is no, make it private.

Prefer:

```dart
final _selectedId = RxnString();

String? get selectedId => _selectedId.value;

void select(String id) {
  _selectedId.value = id;
}
```

over:

```dart
final selectedId = RxnString();
```

when external code should not freely mutate the observable.

## Dot Shorthand Rule

When the project language version is Dart 3.10 or newer, prefer dot shorthand where the context type is obvious and the shorter form remains immediately readable.

Good examples:

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

final ScrollController controller = .new();
final Duration debounce = .milliseconds(300);
```

Prefer dot shorthand especially for:

- enum values in typed parameters
- constructors where the expected type is explicit
- static members where the context type is unambiguous

Do not force dot shorthand when:

- the project is below Dart 3.10
- the context type is not obvious
- the shorthand fails because the surrounding type is a supertype that does not declare the referenced member
- spelling out the type makes domain intent clearer
- the expression becomes harder to search or understand

The goal is less visual noise, not maximum abbreviation.

## Type Inference Rule

Use type inference when the right-hand side makes the type obvious.

Prefer:

```dart
final repository = getIt<ProfileRepository>();
final items = <UserProfile>[];
```

Use an explicit type when it improves the API contract, enables dot shorthand clearly, documents a non-obvious abstraction, or prevents accidental widening.

Do not remove useful types solely to make code shorter.

## App-Wide State Rule

Promote state to app scope when multiple unrelated routes or features need the same live state and the state follows the application lifecycle rather than a screen lifecycle.

Typical app-wide state includes:

- authenticated user / session snapshot
- authentication status
- purchase entitlement snapshot
- owned products or premium access
- app-wide connectivity or maintenance state when the product genuinely depends on it
- other small cross-feature state that must remain consistent across routes

A small app-level GetX controller is an appropriate owner for this shared reactive presentation state.

Prefer:

```text
AuthService / PurchaseService / repositories
                ↓
          AppController
                ↓
      multiple feature controllers / views
```

Infrastructure and SDK coordination remain in services and repositories. `AppController` exposes the small derived state surface that the UI needs globally.

## AppController Rule

If the application has meaningful cross-feature reactive state, prefer one app-level controller such as:

```text
app/
  controllers/
    app_controller.dart
```

Register it once from the initial app binding and keep it alive for the app lifecycle.

Typical responsibilities:

- expose current auth/session state
- expose current purchase entitlement state
- subscribe to app-level service or repository streams
- provide small app-wide actions such as refreshing session or entitlement state
- make shared reactive state consistent across routes

It should not:

- contain raw HTTP calls
- contain store SDK implementation
- contain database queries
- absorb feature-local form or screen state
- become a dumping ground for every observable in the application
- replace repositories or app services

Global does not mean everything belongs in one controller.

If an app-wide concern becomes large and independently complex, keep its infrastructure in a dedicated service and expose only the shared presentation projection through `AppController`, or split the app-level state deliberately when that produces clearer boundaries.

## Feature State Rule

Keep state feature-local when it belongs to one route or tightly related flow.

Examples:

- form input
- selected tab
- local filters
- page loading state
- temporary search state
- route-specific pagination

Do not move state into `AppController` merely because two widgets on the same screen need it.

## Access Rule

Do not scatter `Get.find<AppController>()` throughout deep leaf widgets.

Prefer:

- resolving the app controller at a clear feature or view boundary
- constructor parameters for reusable leaf widgets when practical
- `GetView`, bindings, or another consistent GetX access pattern already used by the project

Shared state should be globally owned, not globally accessed without discipline.

## Validation Checklist

Before finishing Dart or Flutter changes:

- check that non-API members are private
- check that public mutable state is truly intended to be mutable externally
- remove public helpers that are only used internally
- do not add leading underscores to ordinary local variables or parameters
- use dot shorthand where Dart >= 3.10 and the context is obvious
- do not use dot shorthand where it obscures the type
- check whether cross-feature reactive state is duplicated across controllers
- move truly app-wide reactive state to the app-level controller
- keep SDK, API, storage, and domain coordination out of `AppController`
- keep feature-local state out of global scope
