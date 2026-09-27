# Dart Code Conventions

## Core Principle

Prefer code that is easy to trace, hard to misuse, and small in public surface.

These rules apply across controllers, services, repositories, models, widgets, helpers, and other handwritten Dart code.

The priority order is:

1. clear ownership and dependency direction
2. small intentional APIs
3. simple state models
4. immutable or narrowly mutable data
5. concise readable naming
6. modern Dart syntax when it reduces noise without hiding meaning

Do not add abstractions, code generation, or framework layers merely to satisfy style.

## Private By Default

If a field, method, getter, setter, helper class, or top-level declaration is not part of the intended external API, make it private with a leading underscore.

This rule is especially important for GetX controllers because much controller logic is often internal to one class and one file.

Prefer:

```dart
class ProfileController extends GetxController {
  final ProfileRepository _repository;

  ProfileController(this._repository);

  final _isLoading = false.obs;
  final _profile = Rxn<UserProfile>();

  bool get isLoading => _isLoading.value;
  UserProfile? get profile => _profile.value;

  Future<void> refresh() => _load();

  Future<void> _load() async {
    final result = await _repository.profile();

    result.fold(
      _handleFailure,
      _applyProfile,
    );
  }

  void _applyProfile(UserProfile profile) {
    _profile.value = profile;
  }

  void _handleFailure(AppFailure failure) {
    // Internal mapping.
  }
}
```

If `_load`, `_applyProfile`, or `_handleFailure` are never called outside the controller, they should not be public.

This has two benefits:

- unrelated code cannot depend on controller internals
- IDE and analyzer tooling can more reliably identify unused private declarations

Dart privacy is library-scoped rather than class-scoped. With the repository convention of keeping one primary class per file, a leading underscore still provides the intended isolation from unrelated files.

Do not prefix ordinary local variables or parameters with `_`. They are already locally scoped. Use `_`, `__`, and similar names only for intentionally unused callback parameters.

## Public API Rule

Treat every public member as an intentional contract.

Before leaving a declaration public, ask:

1. does another file or module genuinely need this?
2. should callers be allowed to mutate it directly?
3. would a getter or explicit action communicate intent better?
4. will making it public create a dependency that becomes difficult to remove later?

If the answer is no, make it private.

Prefer:

```dart
final _selectedId = RxnString();

String? get selectedId => _selectedId.value;

void select(String id) {
  _selectedId.value = id;
}
```

over exposing the mutable `Rx` directly when external mutation is not part of the intended API.

## Final By Default

Prefer `final` for fields and local variables when the reference does not need reassignment.

Prefer:

```dart
final repository = getIt<ProfileRepository>();
final items = <UserProfile>[];
```

Use mutable variables only when reassignment is part of the actual logic.

For class fields, prefer `final` dependencies and collaborators unless their identity genuinely changes during the object lifetime.

Do not use `final` mechanically where mutation is the point, but require a reason before introducing reassignable state.

## Const In Flutter UI

Use `const` whenever practical for immutable widget subtrees and constant values.

Prefer:

```dart
const SizedBox(height: 12);
const Icon(Icons.close);
const EdgeInsets.symmetric(horizontal: 16);
```

Use `const` constructors for widgets when all arguments are compile-time constants.

Do not distort otherwise clear code merely to force `const`, but avoid missing obvious constant expressions in hot UI paths.

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

final Duration debounce = .milliseconds(300);
```

Prefer dot shorthand for:

- enum values in typed parameters
- constructors where the expected type is explicit
- static members where the context type is unambiguous

Do not force it when:

- the project language version is below Dart 3.10
- the context type is not obvious
- the explicit type communicates important domain intent
- the shorthand makes searching or debugging harder

The goal is less visual noise, not maximum abbreviation.

## Dependency Resolution Rule

Resolve dependencies at composition boundaries, not deep inside business logic.

Prefer:

- GetX bindings for GetX controllers and GetX-specific lifecycle objects
- `get_it` during bootstrap or composition for infrastructure
- constructor injection for repositories, services, and controllers

Prefer:

```dart
class ProfileController extends GetxController {
  ProfileController(this._repository);

  final ProfileRepository _repository;
}
```

Avoid:

```dart
class ProfileController extends GetxController {
  final _repository = getIt<ProfileRepository>();
}
```

and avoid scattering `Get.find()` through methods or leaf widgets.

Dependency lookup should be visible near object construction so the dependency graph remains traceable.

## GetX Registration Rule

For required GetX dependencies, prefer fail-fast lookup.

Use:

```dart
final appController = Get.find<AppController>();
```

Do not routinely guard required dependencies with:

```dart
if (Get.isRegistered<AppController>()) {
  final appController = Get.find<AppController>();
}
```

or:

```dart
if (!Get.isRegistered<AppController>()) return;
```

when the dependency is part of the required binding contract.

If a required dependency was not registered, that is a wiring bug. Let the lookup fail close to the cause instead of silently skipping behavior and allowing the app to continue in an invalid state.

Use `Get.isRegistered<T>()` only when registration is genuinely optional or when the code intentionally needs to inspect registration state, such as:

- conditional setup
- test setup or cleanup
- lifecycle-specific teardown
- optional integrations that are explicitly modeled as optional

Do not use `isRegistered → find` as defensive boilerplate.

Bindings should guarantee required dependencies before the route or controller needs them.

## BuildContext Boundary Rule

Do not pass `BuildContext` into controllers, services, repositories, DAOs, or infrastructure objects.

`BuildContext` belongs to the widget layer.

If non-widget code needs to request navigation, dialogs, snackbars, or other UI effects:

- keep the decision in presentation code
- expose a typed state or event
- use the project's intentional GetX presentation mechanism when appropriate

Repositories and services should never need Flutter widget context.

## Mutable Collection Rule

Do not expose mutable internal collections when callers should only read them.

Avoid:

```dart
List<User> get users => _users;
```

when callers can mutate the internal list.

Prefer a read-only or copied view appropriate to the use case:

```dart
List<User> get users => List.unmodifiable(_users);
```

For reactive collections, expose only the smallest public API needed and keep mutation methods on the owner when possible.

Do not copy large collections repeatedly in hot paths without reason; choose a read-only strategy appropriate to performance needs.

## Late Rule

Avoid `late` when constructor injection, direct initialization, or a nullable type expresses the lifecycle more safely.

Use `late` only when object lifecycle genuinely guarantees initialization before first read.

Too much `late` often hides unclear ownership or initialization order.

Prefer:

- `required` constructor parameters
- direct field initialization
- nullable fields when absence is a legitimate state

Do not use `late` merely to silence initialization design problems.

## Dynamic Boundary Rule

Avoid `dynamic` when the type can be known.

Keep `dynamic` and `Map<String, dynamic>` near unavoidable boundaries such as raw JSON decoding, then convert immediately to typed DTOs or domain models.

Do not let untyped values flow into:

- controllers
- repositories' public APIs
- app services
- reusable widgets

Prefer explicit types that allow analyzer and IDE tooling to detect mistakes.

## Dependency Direction Rule

Keep dependencies moving in one direction:

```text
View
  ↓
Controller
  ↓
Repository / App Service
  ↓
API / DAO / SDK
```

Rules:

- lower layers do not import controllers or views
- repositories do not navigate
- DAOs do not know features
- services do not depend on widget classes
- controllers orchestrate; repositories and services execute
- APIs and storage implementations stay below repositories

Do not create circular dependencies between app layers.

## App-Wide State Rule

Promote state to app scope only when multiple unrelated routes need the same live state and the state follows the application lifecycle rather than one screen lifecycle.

Typical app-wide state:

- authenticated user or session
- authentication status
- purchase entitlement
- premium access
- owned products
- small cross-feature connectivity or maintenance state when genuinely app-wide

Prefer:

```text
AuthService / PurchaseService / repositories
                ↓
          AppController
                ↓
      multiple routes / features
```

`AppController` owns only the small reactive projection needed by the UI.

Infrastructure remains elsewhere:

- `AuthService` owns auth SDK and session coordination
- `PurchaseService` owns store SDK and purchase lifecycle
- repositories own API and persistence coordination
- Drift stays below repositories / storage infrastructure

Do not put route-local forms, filters, pagination, tab state, or screen loading state in `AppController`.

## Enum And Sealed State Rule

Use `enum` or a small `sealed` hierarchy when it makes a finite state easier to understand than multiple booleans.

Prefer an enum for simple status:

```dart
enum LoadStatus {
  idle,
  loading,
  success,
  failure,
}
```

Use a sealed hierarchy only when different states need different payloads and the hierarchy remains small and obvious:

```dart
sealed class ProfileState {
  const ProfileState();
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

final class ProfileReady extends ProfileState {
  const ProfileReady(this.profile);

  final UserProfile profile;
}

final class ProfileFailed extends ProfileState {
  const ProfileFailed(this.failure);

  final AppFailure failure;
}
```

Do not introduce Freezed, unions code generation, or a large state framework merely to model a few simple states.

Do not create a sealed hierarchy if an enum plus one or two fields is clearer.

Use the simplest representation that prevents invalid state combinations and remains easy to read in one pass.

## Boolean State Rule

Avoid several booleans representing one state machine.

Avoid combinations such as:

```dart
isLoading
hasError
isEmpty
isSuccess
```

when they can become contradictory.

Use:

- one enum for simple finite status
- one small sealed hierarchy when each case needs distinct data
- derived getters for values that can be calculated

Independent booleans are still appropriate when they represent genuinely independent facts.

## Derived State Rule

Do not store state that can be derived reliably from another source of truth.

Prefer:

```dart
User? get currentUser => _currentUser.value;
bool get isLoggedIn => currentUser != null;
```

over maintaining a separate `RxBool isLoggedIn` that must stay synchronized manually.

Likewise derive:

- `hasPremium` from entitlement when possible
- `isEmpty` from the owned collection
- button availability from the actual validation inputs

Store a derived value only when recomputation is expensive or it represents an independent persisted fact.

## Naming Rule

Names should be precise but concise.

Choose the shortest name that is unambiguous in its local context.

Prefer:

```dart
class PurchaseService {
  Future<void> restore() {}
}

class ProfileController {
  Future<void> _load() {}
  void _apply(UserProfile profile) {}
}
```

over names that repeat context already supplied by the class or file:

```dart
class PurchaseService {
  Future<void> restorePurchaseServicePurchases() {}
}

class ProfileController {
  Future<void> loadProfileControllerProfileData() {}
}
```

Avoid:

- repeating the class name in every member
- stacking synonyms such as `loadFetchUserProfileData`
- suffixes like `ManagerServiceHelper`
- names that encode implementation details callers do not care about

Use longer names only when they genuinely disambiguate two concepts.

### Boolean Naming

Boolean names should read naturally as predicates.

Prefer:

- `isLoading`
- `hasPremium`
- `canPurchase`
- `shouldRefresh`

Avoid vague names such as:

- `loadingFlag`
- `premiumValue`
- `purchaseBoolean`

Prefer positive names when practical so callers do not need double negatives.

### Method Naming

Use verbs for actions and side effects:

- `load()`
- `refresh()`
- `saveDraft()`
- `restore()`
- `completePurchase()`

Do not add `get` mechanically when it adds no meaning.

Within a class whose context is already clear, prefer `load()` over `loadProfile()` if there is only one obvious resource being loaded. Use the longer name when multiple load operations exist and disambiguation is useful.

## Guard Clause And Control Flow Rule

Prefer early returns and guard clauses when they make the main execution path flatter and easier to scan.

Prefer:

```dart
Future<void> submit() async {
  if (_isLoading.value) return;
  if (!_formIsValid()) return;

  _isLoading.value = true;

  try {
    await _save();
  } finally {
    _isLoading.value = false;
  }
}
```

over deeply nested control flow:

```dart
Future<void> submit() async {
  if (!_isLoading.value) {
    if (_formIsValid()) {
      _isLoading.value = true;

      try {
        await _save();
      } finally {
        _isLoading.value = false;
      }
    }
  }
}
```

Use guard clauses for:

- invalid input
- already-running work
- missing optional data
- empty collections when no work is needed
- unsupported states
- fast UI branches

For a short single-statement `if`, prefer a compact one-line form when it remains easy to scan:

```dart
if (a > 3) return;
if (isLoading) return const LoadingWidget();
if (items.isEmpty) return const EmptyView();
```

Do not add braces around a trivial one-line guard merely by habit.

Use braces when:

- the branch contains multiple statements
- the statement spans multiple lines
- comments or debugging code may make the control flow ambiguous
- nested conditions would become hard to scan
- project formatting or lint rules require them

The goal is flatter, clearer control flow, not minimizing line count at all costs.

## Exception Logging Rule

Do not swallow exceptions silently.

When using `try/catch`, catch both the error and stack trace unless there is a specific reason not to:

```dart
try {
  await _repository.refresh();
} catch (e, st) {
  log(
    'Failed to refresh profile',
    name: 'ProfileController._refresh',
    error: e,
    stackTrace: st,
  );

  rethrow;
}
```

At minimum, unexpected caught exceptions should be observable through logging or the project's error-reporting layer.

Prefer contextual log names in the form:

```text
ClassName.methodName
```

For private methods, including the underscore in the log name is acceptable when it helps trace the exact code path:

```dart
name: 'ProfileController._load'
```

Avoid:

```dart
try {
  await work();
} catch (_) {}
```

and avoid:

```dart
try {
  await work();
} catch (e) {
  // ignored
}
```

A catch block should normally do at least one intentional thing:

- log the unexpected issue
- map the exception into a typed failure
- update meaningful error state
- report it to the app's error-reporting service
- rethrow when the current layer cannot handle it correctly

If the exception is mapped to a known `AppFailure`, logging responsibility may live at the boundary that first converts or observes the unexpected exception. Do not log the same failure repeatedly at every layer.

Expected control-flow outcomes should not be modeled as exceptions merely so they can be caught and logged.

## Reuse And Extraction Rule

When logic repeats, consider extracting it, but choose the smallest abstraction that matches the ownership of the behavior.

Prefer this order of consideration:

1. private method when the logic belongs to one class or one file
2. shared top-level method or helper when the logic is pure but does not naturally belong to a specific type
3. extension when the behavior naturally reads as an operation on an existing type
4. mixin when multiple classes genuinely share reusable instance behavior or lifecycle logic
5. a dedicated class or service when the behavior has its own state, dependencies, or responsibility

Do not jump directly to mixins, extensions, base classes, or generic helpers merely because two code blocks look similar.

### Private Method First

If repeated logic is only used inside one controller, service, repository, or widget file, prefer a private method.

```dart
class CheckoutController extends GetxController {
  Future<void> submit() async {
    if (!_canSubmit()) return;

    await _save();
  }

  bool _canSubmit() {
    // Internal validation.
    return true;
  }

  Future<void> _save() async {
    // Internal flow.
  }
}
```

Do not extract internal logic into a global helper or extension unless another real caller needs it.

This keeps usage traceable and lets analyzer / IDE tooling identify dead private methods after refactors.

### Extension Rule

Use an extension when the operation conceptually belongs to the value being extended and is useful in multiple places.

Good candidates:

- date and time formatting
- small string normalization
- nullable convenience helpers with clear semantics
- collection helpers that are domain-neutral and genuinely repeated

Example:

```dart
extension DateTimeFormatting on DateTime {
  String toDateText({String? locale}) {
    return DateFormat.yMMMd(locale).format(this);
  }

  String toDateTimeText({String? locale}) {
    return DateFormat.yMMMd(locale).add_Hm().format(this);
  }
}
```

Usage stays close to the value:

```dart
final text = createdAt.toDateText();
```

Prefer extensions over scattered calls such as:

```dart
DateFormat('dd/MM/yyyy').format(createdAt);
DateFormat('dd/MM/yyyy').format(updatedAt);
DateFormat('dd/MM/yyyy').format(expiredAt);
```

when the app repeatedly uses the same display format.

Do not create extensions for behavior that needs hidden dependencies, mutable state, navigation, network access, storage access, or complex business orchestration.

### Date And Time Formatting Rule

Common date/time presentation formatting should normally live in one or a small number of `DateTime` extensions.

Prefer a structure such as:

```text
app/
  extensions/
    extensions.dart
    date_time_extensions.dart
```

Keep common display formats centralized so the app does not scatter raw format strings such as `'dd/MM/yyyy'`, `'HH:mm'`, or `'yyyy-MM-dd'` across controllers and widgets.

Prefer semantic methods whose names describe the display intent without becoming excessively long.

For example:

```dart
extension DateTimeFormatting on DateTime {
  String toDateText({String? locale}) { ... }
  String toDateTimeText({String? locale}) { ... }
  String toTimeText({String? locale}) { ... }
}
```

If one feature has a genuinely unique date representation used once, keeping it local can be clearer than expanding a global extension.

Do not put API serialization formats and UI display formats into one ambiguous method. For example, a backend ISO timestamp and a localized user-facing date have different responsibilities.

### Mixin Rule

Use a mixin only when multiple classes genuinely share instance behavior that belongs to those classes.

A mixin is reasonable when:

- the same behavior is reused by multiple concrete classes
- the behavior needs access to the host object's members
- inheritance would be artificial or too restrictive
- the resulting API remains small and easy to trace

Avoid mixins for:

- a few standalone utility functions
- behavior used by only one class
- hiding unrelated dependencies
- replacing composition when a dedicated service is clearer
- creating a generic `ControllerMixin`, `LoadingMixin`, or `CommonMixin` before repeated behavior actually exists

Keep mixins focused on one coherent capability.

### Helper Rule

Use a helper or top-level method when logic is:

- pure
- stateless
- not naturally owned by an existing type
- reused by more than one caller

Examples include parsers, validators, or small conversions that do not fit naturally as extensions.

Do not turn `helpers/` into a dumping ground for unrelated code.

## Widget Extraction Rule

When a meaningful UI block deserves its own identity, prefer extracting a `StatelessWidget` or `StatefulWidget` instead of a helper function returning `Widget`.

Prefer a widget when:

- the block is reusable
- the block is large enough to deserve a name
- it owns local widget state
- it benefits from an independent rebuild boundary
- moving it out makes the parent screen easier to scan

A tiny one-off expression does not need a new widget class merely to satisfy the rule.

## Abstraction Rule

Do not create abstraction before there is a real repeated shape.

Avoid introducing:

- `BaseRepository`
- `BaseController`
- `BaseService`
- generic CRUD layers
- generic response wrappers on top of existing typed wrappers

unless several real implementations share meaningful behavior.

Prefer duplication of a few obvious lines over a premature abstraction that hides control flow.

Extract an abstraction when it removes repeated domain behavior, not merely repeated syntax.

## Import Rule

Keep imports predictable and minimal.

Prefer this order:

1. `dart:`
2. `package:`
3. project-relative imports

Within each group, keep imports sorted.

Avoid:

- unused imports
- importing internal `src/` files from third-party packages
- importing broad barrel files when a narrow import prevents circular dependencies
- unnecessary cross-feature imports

Use package or relative imports consistently according to the project's existing convention. Do not mix styles randomly in the same layer.

## Class Modifier Rule

Use Dart class modifiers only when they communicate a real design boundary.

Examples:

- `final class` when outside inheritance or implementation should not be supported
- `base class` when inheritance is controlled and implementation invariants matter
- `sealed class` for a small closed hierarchy used in exhaustive switching

Do not add modifiers everywhere merely because they are available.

Do not introduce a complex hierarchy to justify a modifier.

Simple ordinary classes remain the default.

## Module Export Rule

Barrel files should expose the intended public surface of a module, not every file in the directory.

Export:

- stable public models
- public controller/view/widget entry points
- public service or repository contracts when callers need them

Do not export merely for convenience:

- private implementation helpers
- generated Drift internals
- DAO implementation details
- internal DTOs that should stay behind repositories
- files that are only used by sibling files in the same module

A smaller export surface reduces accidental coupling and makes later refactors safer.

## Validation Checklist

Before finishing Dart or Flutter changes:

- make non-API fields, methods, helpers, and declarations private
- verify controller logic used only inside its own file is private
- make stable references `final`
- add obvious `const` in Flutter UI
- avoid unnecessary `late`
- remove avoidable `dynamic`
- resolve dependencies at bindings/bootstrap and inject them through constructors
- do not guard required GetX dependencies with `Get.isRegistered` before `Get.find`; fail fast on invalid binding setup
- use `Get.isRegistered` only for intentionally optional or lifecycle-specific registration checks
- keep `BuildContext` out of controllers, services, repositories, and DAOs
- prefer guard clauses and early returns over deeply nested `if` blocks
- keep trivial single-statement guards compact when readability remains clear
- never leave unexpected `catch` blocks silent; capture `(e, st)` and log or report the issue
- use contextual error log names such as `ClassName.methodName`
- avoid duplicate logging of the same failure across multiple layers
- do not expose mutable internal collections
- keep the dependency direction View → Controller → Repository/Service → API/DAO/SDK
- derive state instead of duplicating it
- use enum/sealed state only when simpler than booleans, and keep sealed hierarchies small
- do not add Freezed or another union generator just to model simple state
- use concise names without repeating class/file context
- use predicate-style boolean names
- avoid premature base classes and generic abstractions
- keep repeated logic local as a private method until real cross-file reuse appears
- prefer extensions when reusable behavior naturally belongs to an existing type
- keep common date/time display formatting in `DateTime` extensions instead of scattering raw `DateFormat` patterns
- use mixins only for genuine shared instance behavior, not generic utility dumping grounds
- keep helpers pure, stateless, and intentionally scoped
- extract meaningful UI blocks as widgets when it improves structure
- keep imports sorted, minimal, and free of third-party `src/` paths
- use class modifiers only when they communicate a useful boundary
- export only intentional module APIs
- use dot shorthand where Dart >= 3.10 and the context is obvious
- keep app-wide state in `AppController` only when it is truly cross-feature
