# Local Storage Rules

## Core Principle

Choose local storage by data shape, query needs, and schema growth risk, not by convenience.

Within this GetX architecture, prefer only these two options by default:

- `shared_preferences`
- `drift`

GetX remains the presentation and lifecycle framework. Local database infrastructure belongs below the repository boundary and should be composed through `get_it`.

## Use `shared_preferences` When

Use `shared_preferences` for small, stable key-value data such as:

- onboarding completion flags
- locale or theme preference
- small feature toggles
- tiny primitive counters or timestamps

Prefer the newer package APIs for new code:

- `SharedPreferencesAsync`
- `SharedPreferencesWithCache`

The package is intended for simple key-value persistence, so it is a poor fit for large, evolving user datasets.

If the app uses `get_it` or `injectable`, the shared preferences abstraction can be pre-resolved during app bootstrap so settings access is available immediately. This is acceptable for a small app-level settings service.

## Avoid Overusing `shared_preferences`

Avoid using `shared_preferences` for:

- large JSON strings
- growing arrays of user content
- lists of structured objects
- draft systems
- history, feed, or offline domain data
- data that needs filtering, ordering, joins, transactions, or migrations

Pre-resolving one small preferences service is reasonable. Pre-resolving large amounts of preference-backed state at startup is not.

## Use `drift` When

Use Drift for:

- structured local user data
- offline-first or cached user content
- dynamic datasets that may grow over time
- relational data or records with indexes and constraints
- local data that needs typed filtering, ordering, joins, transactions, or reactive queries
- persisted data whose schema is expected to evolve

Drift should be treated as app infrastructure, not as GetX state.

Prefer this dependency direction:

```text
GetX controller
    ↓
repository
    ↓
DAO / local data source
    ↓
AppDatabase
```

Controllers should consume repository results. They should not import Drift tables, generated database rows, companions, query builders, or database APIs directly.

## Drift Structure

Prefer one app-level database and explicit table / DAO boundaries:

```text
app/storage/drift/
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
```

Exact filenames may vary, but keep these responsibilities separate:

- `AppDatabase` owns database configuration and `schemaVersion`
- tables define persistent schema
- DAOs own reusable local queries and writes
- repositories decide when remote or local data should be used
- migration code owns upgrades between shipped schema versions

Do not create a DAO for every table automatically. Create DAOs around meaningful query or write boundaries.

## Package Rule

For Flutter projects using Drift, prefer:

```yaml
dependencies:
  drift:
  drift_flutter:

dev_dependencies:
  drift_dev:
  build_runner:
```

Add other supporting packages only when the concrete platform or project setup requires them.

Use code generation for the database and generated query types instead of maintaining generated boilerplate manually.

## Migration Rule

Treat database migrations as **release boundaries**, not as a counter that must increase after every schema edit during development.

Distinguish between:

- the **last shipped schema version**: the schema already present in a production/app-store release
- the **pending release schema**: all database changes accumulated since that shipped version

### During Development

When schema work is still unreleased:

- update the table definitions as needed
- keep accumulating related schema changes for the same upcoming release
- do not increment `schemaVersion` for every intermediate edit
- if `schemaVersion` has already been bumped once for the current unreleased release, keep refining that same pending migration instead of bumping again
- reset/recreate the local development database when necessary while the pending schema is still changing
- keep a TODO or release-note entry that a production migration must be finalized before release

Do not preserve artificial migration steps for development-only states that no production user has ever had.

For example, if production is on schema `4` and the next app release has three rounds of database edits, prefer one reviewed migration:

```text
shipped schema 4
      ↓
pending release schema 5
```

instead of creating:

```text
4 → 5 → 6 → 7
```

when versions `5` and `6` never shipped.

### Before Release

When preparing a real app release that contains persisted schema changes:

1. identify the last schema version that actually shipped
2. review all pending schema changes since that release
3. bump `schemaVersion` once for the release if it has not already been bumped for this unreleased release
4. consolidate the pending migration so users can upgrade from the last shipped schema to the new release schema
5. run `dart run drift_dev make-migrations` when using Drift's generated migration workflow
6. implement/review the migration steps
7. run migration tests
8. verify important data survives upgrades from supported shipped versions
9. record the app version and resulting database schema version in the migration history
10. clear the pending migration TODO only after the release migration is ready

If the current branch/thread already bumped the next schema version and that version has **not shipped yet**, do not bump it again merely because another schema edit was made. Update the same pending release migration.

### Development Database Caveat

If the local development database has already been opened with the pending schema version and the schema changes again without another version bump, Drift will not magically replay that same migration version.

During unreleased development, use an intentional development workflow such as:

- clear/reinstall the development database
- use a test database
- recreate local tables when disposable dev data allows it

Do not use this shortcut for production user databases.

### Migration History

Keep a small human-readable migration history when the app has persistent production data.

A recommended placement is:

```text
app/storage/drift/migrations/
  migrations.dart
  schema_history.md
```

The history should map app releases to database schema versions, for example:

```text
App 1.4.0 → DB schema 3
App 1.6.0 → DB schema 4
Next release → DB schema 5 (pending)
```

Record only meaningful release boundaries. Do not turn the history into a log of every development edit.

This makes it easier to answer:

- which schema version is currently in production?
- has the pending schema bump already been created?
- which app release introduced a migration?
- should the next schema edit amend the pending migration or create a new one?

If the project already has a release-note/changelog system that reliably tracks this information, reuse it instead of creating redundant documentation.

### Migration Safety

Prefer generated migration helpers and tests over ad-hoc manual migrations.

Do not use destructive table recreation in production merely because it is easier. Destructive migration is acceptable only when the product explicitly permits losing that local data.

Keep generated schema snapshots used for migration verification under version control when the project adopts Drift's migration tooling.

## Reactive Query Rule## Reactive Query Rule

Drift streams can feed GetX state, but keep the framework boundary explicit.

Prefer:

- DAO exposes a typed `Stream<List<T>>` or domain-friendly stream
- repository maps database records to domain/app models when needed
- controller subscribes and projects the result into the smallest useful GetX state surface

Avoid:

- exposing Drift query builders to controllers
- opening database watchers directly inside widgets
- creating duplicate reactive layers when a one-shot query is sufficient

Use reactive database queries only when the UI actually needs to stay synchronized with local changes.

## Transaction Rule

Use a database transaction when multiple writes must succeed or fail as one logical operation.

Keep transaction ownership in the storage or repository layer, not in the controller.

Do not split one atomic business write across multiple controller-level DAO calls.

## Decision Rule

When unsure:

1. if the data is a few simple settings or flags, use `shared_preferences`
2. if the data belongs to structured user content, models, caches, or collections, use `drift`
3. if the data needs queries, relationships, transactions, or schema migrations, use `drift`
4. if the data may expand materially later, choose `drift` early instead of accumulating JSON blobs in preferences

## Suggested Placement

Prefer:

- `app/storage/preferences/` for `shared_preferences` wrappers
- `app/storage/drift/` for the database, tables, DAOs, and migrations

Do not read and write preference keys or execute database queries all over the app. Keep persistence behind small services, DAOs, and repositories.

## DI Rule

Register non-GetX storage infrastructure through `get_it`.

Put these in `get_it`:

- shared preferences wrappers
- `AppDatabase`
- Drift DAOs
- repositories that coordinate remote and local persistence

Keep these in GetX bindings:

- `GetxController`
- GetX stores
- GetX-specific services whose lifecycle intentionally follows GetX

Do not register ordinary Drift infrastructure in GetX bindings merely to make it globally reachable.
