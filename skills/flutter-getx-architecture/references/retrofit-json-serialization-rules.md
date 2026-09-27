# Retrofit and Json Serializable Rules

## Core Principle

Let generated tooling handle mechanical transport code, and add handwritten architecture only where it creates real value.

Use:

- `retrofit` to define typed REST endpoints
- `json_serializable` to generate request and response mapping
- `build_runner` to generate implementation files
- `result_dart` when an explicit typed success/failure boundary is useful; it is not mandatory for every simple API call

Do not recreate boilerplate that Retrofit and `json_serializable` already remove.

## Progressive API Architecture

Start with the shallowest useful dependency flow.

### Level 1: Simple Remote Flow

For a straightforward remote-only feature, this is valid:

```text
View
  ↓
GetX Controller
  ↓
Retrofit API
  ↓
Request / Response models
```

The controller may call an injected typed Retrofit API directly when:

- one remote source is involved
- the generated request/response models already match the feature needs
- there is no cache/offline policy
- there is no multi-source coordination
- there is no reusable business workflow that needs a separate owner

Example:

```dart
class ProfileController extends GetxController {
  ProfileController(this._api);

  final ProfileApi _api;

  final _profile = Rxn<ProfileResponse>();

  ProfileResponse? get profile => _profile.value;

  Future<void> load() async {
    try {
      _profile.value = await _api.profile();
    } catch (e, st) {
      log(
        'Failed to load profile',
        name: 'ProfileController.load',
        error: e,
        stackTrace: st,
      );
    }
  }
}
```

This is different from placing raw HTTP code in the controller. The controller consumes a generated typed API contract; it does not build URLs, configure `Dio` requests, or parse JSON manually.

### Level 2: Repository Boundary

Add a repository when it provides a real data boundary, such as:

- normalizing errors across endpoints
- shared data behavior used by multiple features
- hiding transport-specific response shapes
- mapping transport models into a genuinely different app/domain model
- preparing for or coordinating multiple data sources

```text
Controller
    ↓
Repository
    ↓
Retrofit API
```

Do not add a repository whose implementation is only:

```dart
Future<ProfileResponse> profile() => _api.profile();
```

unless that boundary has a concrete project-level reason.

### Level 3: Local + Remote

A repository becomes especially useful when it owns where data comes from:

```text
Controller
    ↓
Repository
   ↙       ↘
Retrofit   Drift
```

Typical reasons:

- cache policy
- offline-first behavior
- stale-while-revalidate
- local fallback
- persistence after successful remote calls
- merge/conflict behavior

### Level 4: Business Orchestration

Add a service or use case when it performs meaningful work across multiple operations or dependencies:

```text
Controller
    ↓
Service / UseCase
    ↓
Repository / SDK / other services
```

Good use-case/service responsibilities include:

- checkout across cart, entitlement, payment, and persistence
- offline synchronization
- multi-step account migration
- workflows with retries, transactions, or business invariants

Do not create a use case that only forwards one call:

```dart
Future<ProfileResponse> call() => _repository.profile();
```

A new layer should remove complexity from its caller or establish a useful boundary.

## Package Expectations

Typical dependencies:

- `dio`
- `retrofit`
- `json_annotation`

Add `result_dart` when the chosen architecture uses a typed result boundary.

Typical dev dependencies:

- `retrofit_generator`
- `json_serializable`
- `build_runner`

## Recommended Structure

A simple app may only need:

```text
app/
  data/
    datasources/
      profile_api.dart
      auth_api.dart
    models/
      profile_response.dart
      update_profile_request.dart
```

Add shared transport infrastructure only when it exists:

```text
app/
  data/
    models/
      api_response.dart
      response_meta.dart
    failures/
      app_failure.dart
    repositories/
      profile_repository.dart
```

Do not create empty folders or placeholder layers just to match a template.

If the backend wraps payloads in a common envelope such as `meta + data`, define one shared generic envelope model and reuse it.

## Retrofit Client Rule

Declare APIs with `@RestApi()` and method annotations such as:

- `@GET`
- `@POST`
- `@PUT`
- `@PATCH`
- `@DELETE`

Example:

```dart
@RestApi()
abstract class ProfileApi {
  factory ProfileApi(Dio dio, {String? baseUrl}) = _ProfileApi;

  @GET('/profile')
  Future<ProfileResponse> profile();

  @PUT('/profile')
  Future<ProfileResponse> update(
    @Body() UpdateProfileRequest request,
  );
}
```

Rules:

- keep endpoint definitions in API files
- inject `Dio` during composition setup
- inject the generated typed API into the controller/repository that actually uses it
- avoid building URLs or request options manually in controllers
- do not name a custom generic envelope `Response<T>` because it collides with `dio.Response`
- keep shared Retrofit clients in the centralized data layer unless the current project has an established feature-local convention

## Json Serializable Rule

Request and response DTOs should use `@JsonSerializable()` when serialization is needed.

Example:

```dart
@JsonSerializable()
class ProfileResponse {
  const ProfileResponse({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory ProfileResponse.fromJson(Map<String, dynamic> json) =>
      _$ProfileResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileResponseToJson(this);
}
```

Rules:

- do not handwrite repetitive JSON mapping
- keep raw `Map<String, dynamic>` near the serialization boundary
- add custom converters only when the API shape actually requires them
- let Retrofit parse typed responses instead of parsing them again in controllers

## Request / Response Model Rule

Do not automatically create a second domain entity for every request/response model.

Use the generated request/response model directly when:

- its shape already matches app needs
- transport-specific details are not leaking into unrelated layers
- no independent domain invariant requires another representation

Create a separate domain/app model when it provides a real benefit, for example:

- backend fields need substantial normalization
- one app model combines multiple remote/local sources
- the domain model must remain stable while the API contract changes
- business invariants differ from transport representation

Do not create DTO → entity → view-model mapping chains when each mapping only copies fields unchanged.

## Generic Envelope Rule

When the backend returns a wrapped payload such as:

```json
{
  "meta": { "message": "ok" },
  "data": { }
}
```

use a shared generic envelope such as `ApiResponse<T>` or `BaseResponse<T>`.

Use `genericArgumentFactories: true` when required by the generic serialization flow.

Keep the envelope separate from application success/failure semantics: an HTTP response envelope and a typed app result solve different problems.

## Repository Rule

A repository is optional, not ceremonial.

Create one when it owns at least one meaningful concern:

- local + remote coordination
- cache or offline policy
- failure normalization
- non-trivial transport-to-app mapping
- shared data behavior
- hiding multiple implementations/sources

When a repository exists:

- it depends on typed Retrofit APIs and/or DAOs, not raw HTTP calls
- it should remove data complexity from callers
- it may return `ResultDart<T, AppFailure>` when typed failures improve the flow
- it should not exist only to rename one API method

Repository interfaces are also optional. Add an interface when there is a real substitution/boundary reason such as multiple implementations, package/domain isolation, or a testing strategy that benefits from the contract.

Do not create `ProfileRepository` + `ProfileRepositoryImpl` mechanically when only one concrete class exists and no boundary needs the interface.

## Result Dart Rule

Use `result_dart` when explicit typed failure handling improves a repository, service, or complex orchestration boundary.

Good fit:

```text
Controller
    ↓
Repository / Service
    ↓
ResultDart<T, AppFailure>
```

Do not force `ResultDart` around every generated Retrofit method.

A simple controller → Retrofit flow may catch unexpected transport errors at that boundary, log `error` + `stackTrace`, and map them into presentation error state.

When using typed failures:

- keep one coherent failure hierarchy
- avoid wrapping `ResultDart` inside another generic success wrapper
- avoid logging the same failure at every layer
- convert unexpected exceptions at the boundary that has enough context to classify them

## Generation Rule

After changing Retrofit clients or JSON models, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

If the repo already uses `watch` or a wrapper command, preserve the project convention.

## Decision Rule

When adding or changing an API feature:

1. define only the request/response models that the endpoint actually needs
2. use `@JsonSerializable()` for generated serialization
3. define the endpoint with `@RestApi()`
4. inject the typed API directly into the controller if the flow is simple
5. add a repository only when it introduces real data policy, reuse, mapping, failure normalization, or multiple-source coordination
6. add a service/use case only when it owns meaningful business orchestration
7. add `result_dart` when a typed result boundary makes that deeper flow clearer
8. stop adding layers when the next layer would only forward the previous call
