# Purchase Service Rules

## Core Principle

In-app purchases should be coordinated through one app-level `PurchaseService`, not spread across many screens or controllers.

This service should own store connection, product loading, purchase event listening, entitlement refresh, restore flow, and transaction completion.

## Package Rule

Prefer Flutter's official `in_app_purchase` package for storefront-independent purchase handling.

The official API exposes:

- `InAppPurchase.instance`
- `queryProductDetails(...)`
- `purchaseStream`
- `buyConsumable(...)`
- `buyNonConsumable(...)`
- `restorePurchases(...)`
- `completePurchase(...)`

The official package supports the common product categories exposed by the stores:

- consumable
- non-consumable
- subscription

## Suggested Placement

Prefer:

```text
app/
  controllers/
    app_controller.dart
  services/
    purchase_service.dart
```

`PurchaseService` owns purchase infrastructure. When entitlement or premium-access state is consumed across unrelated routes, `AppController` owns the small GetX reactive projection used by the UI.

If purchase state needs repository access or backend verification, the service may collaborate with `app/data/repositories/`.

## Service Responsibilities

`PurchaseService` should usually:

- initialize the store connection once
- check store availability
- load and cache product metadata
- subscribe to `purchaseStream` in one place
- handle purchase updates and errors
- trigger entitlement refresh or backend verification
- expose purchase state to the rest of the app
- support restore purchases
- call `completePurchase(...)` when delivery is finished and required

It should usually not:

- let multiple features listen to purchase updates independently
- embed UI-specific purchase flow inside feature widgets
- couple transaction handling to one screen lifecycle

## Reactive State Rule

Separate purchase infrastructure state from app-wide presentation state.

`PurchaseService` should own store-facing coordination and expose domain-friendly snapshots, streams, or callbacks without requiring feature controllers to understand the store SDK.

When purchase entitlement, premium access, or owned-product state is consumed across unrelated routes, project the shared reactive state through `AppController`.

Typical app-wide reactive state may include:

- current entitlement snapshot
- premium-access flag
- owned product ids
- store availability when many routes care about it
- purchase-in-progress state only when it has meaningful app-wide UI impact

Prefer this direction:

```text
InAppPurchase SDK
      ↓
PurchaseService
      ↓
AppController
      ↓
multiple routes / features
```

Do not create separate entitlement observables in every feature controller.

Keep `AppController` focused on the small presentation snapshot. Store connection, product loading, `purchaseStream`, restore logic, verification, and `completePurchase(...)` remain in `PurchaseService`.

## API Shape Rule

Purchase actions should usually receive an explicit product id or product details input.

Prefer shapes such as:

```dart
Future<ResultDart<void, AppFailure>> buy(String productId)
```

or:

```dart
Future<ResultDart<void, AppFailure>> buyProduct(ProductDetails product)
```

For products that can be purchased many times, product-id-driven APIs are especially important.

Avoid:

- hardcoding purchase behavior in widgets
- many separate methods like `buyPremiumMonthly()`, `buyCoins100()`, `buyRemoveAds()` unless the product model is extremely small and fixed
- hiding the purchased product identity from the service response and reactive state

## Product ID Naming Rule

Define a consistent product-id naming convention early and keep it aligned across store configuration, app code, and backend mapping.

Prefer ids that are:

- lowercase
- stable
- semantic
- environment-safe
- easy to group by product family

Prefer patterns such as:

- `premium.monthly`
- `premium.yearly`
- `remove_ads.lifetime`
- `coins.100`
- `coins.500`
- `pro.lifetime`

If the project or store conventions require underscores, keep the same structure:

- `premium_monthly`
- `premium_yearly`
- `remove_ads_lifetime`

Rules:

- do not rename product ids casually after release
- do not encode temporary UI wording into product ids
- keep ids predictable enough that local or backend entitlement mapping stays simple
- use one naming style across all products in the app
- prefer explicit duration or quantity in the id when that matters to the business model

Avoid:

- mixed naming styles such as `premium.monthly`, `removeAds`, `coin_pack_100`, `vipYear`
- vague ids such as `product1`, `premium1`, or `sub_a`
- ids that depend on current marketing copy

## Flow Rule

Prefer this flow:

1. initialize `InAppPurchase.instance`
2. call `isAvailable()` and handle unavailable store state
3. query products with `queryProductDetails(...)`
4. start purchases through the service
5. handle updates from `purchaseStream`
6. verify and unlock entitlement
7. call `completePurchase(...)` when appropriate

This keeps purchase state predictable and centralized.

## Product Type Rule

Design purchase handling according to product type.

### Consumable

Use for items that can be bought multiple times, such as:

- credits
- coins
- token packs
- one-time consumable boosts

Typical implications:

- delivery often updates a balance or counter
- restore behavior may differ by platform and product model
- local bookkeeping must be careful if no backend exists
- product-id-based purchase calls are usually the cleanest fit

### Non-Consumable

Use for one-time permanent unlocks, such as:

- remove ads
- premium upgrade
- feature pack unlock

Typical implications:

- entitlement is long-lived
- restore flow is important
- local-only apps may persist the unlocked state locally

### Subscription

Use for recurring access, such as:

- premium monthly
- premium yearly
- recurring membership

Typical implications:

- entitlement can expire, renew, or lapse
- backend confirmation is usually safer for long-term trust
- restore and entitlement refresh are critical

## Entitlement Model Rule

Apps usually choose one of these two purchase architectures.

### 1. Local-Only Entitlement

Use this when:

- the app is small
- the purchase model is simple
- the team does not want to build a purchase backend yet

Typical approach:

- handle purchase updates locally
- unlock features locally
- persist entitlement in local storage
- restore from store data when appropriate

Good fit for:

- simple non-consumable unlocks
- small paid utilities
- low-risk product models where server trust is not required

Tradeoffs:

- weaker trust boundary
- harder to reconcile entitlement across devices and platforms
- more risk of local state drift

### 2. Backend-Confirmed Entitlement

Use this when:

- the app already has an API
- subscriptions exist
- entitlement must sync across devices
- product access needs stronger trust and auditability

Typical approach:

- purchase update arrives from store
- app sends purchase evidence to backend confirmation endpoint
- backend validates and stores entitlement
- app refreshes entitlement from backend state

Good fit for:

- subscriptions
- shared accounts
- higher-value unlocks
- apps with server-driven permissions or content access

Tradeoffs:

- more implementation complexity
- requires API design and server ownership
- adds backend dependency to purchase flow

## Entitlement Rule

Do not treat a local purchase event alone as the final source of truth for long-term entitlement when the product requires backend trust.

Prefer:

- mapping store purchase updates into app entitlement state
- verifying with backend when the product model requires it
- refreshing entitlement after restore or purchase completion

If the app intentionally uses a local-only entitlement model, document that choice explicitly and keep the product scope simple.

## Restore Rule

Expose restore behavior through the service, not through ad-hoc feature logic.

Typical responsibilities:

- trigger `restorePurchases()`
- handle restored purchase updates from the purchase stream
- recompute entitlement state after restore

## Completion Rule

The official package requires pending completed purchases to be finalized with `completePurchase(...)` when `pendingCompletePurchase` is true.

Treat this as a required part of the purchase flow, not an optional cleanup step.

## UI Boundary Rule

Features may:

- request product lists from the service or an appropriate feature controller
- trigger buy actions through the service or a small delegating app-level action
- read shared entitlement state from `AppController` when that state is app-wide

Features should not:

- own the purchase stream subscription
- directly coordinate transaction completion
- duplicate restore logic across multiple screens
- maintain independent copies of app-wide entitlement state

## Decision Rule

When unsure:

1. put purchase coordination in `app/services/purchase_service.dart`
2. use `in_app_purchase` as the purchase layer
3. identify whether the product is consumable, non-consumable, or subscription
4. choose local-only or backend-confirmed entitlement architecture explicitly
5. define a stable product-id naming convention
6. expose only the minimal shared reactive purchase state through `AppController` when multiple unrelated routes need it
7. keep purchase APIs explicit with `productId` or `ProductDetails` input
8. keep one listener for `purchaseStream`
9. centralize entitlement refresh and restore handling
10. call `completePurchase(...)` when delivery is complete and required
