# Apple services hookup — Game Center + StoreKit (one plugin)

Both run through **GodotApplePlugins** ([github.com/migueldeicaza/GodotApplePlugins](https://github.com/migueldeicaza/GodotApplePlugins))
— a Godot-4 GDExtension that ships prebuilt binaries and covers Game Center, StoreKit 2, and Sign in
with Apple. The GDScript side is done and **inert until the plugin is in the build**:

- `core/identity.gd` — Game Center sign-in → a pseudonymous `player_id()` + the server-verification signature.
- `core/store.gd` — StoreKit 2 purchases (`purchase()` / `restore()`).
- `core/inbox_sync.gd` sends `X-Player-Id` when an id exists; `ui/vault.gd` routes the piggy-bank crack
  through `store.gd` when StoreKit is present (else the honest non-charging path).

Every native class is reached via `ClassDB` (never a direct symbol), so off iOS / without the plugin the
providers report unavailable and the game behaves exactly as today — verified by `identity_tests` /
`store_tests` in the active sweep.

## 1. Install the plugin (no build-from-source)
Download a release from the repo / Godot Asset Library, drop it into `addons/`, and add its
`.gdextension` to the iOS export. After this, `GameCenterManager`, `GKLocalPlayer`, and `StoreKitManager`
exist in `ClassDB` on the iOS build (and nowhere else).

## 2. App Store Connect + entitlements
- **Game Center:** enable the capability for the app; add the Game Center entitlement to the iOS export.
- **StoreKit:** create the products. Register the piggy-bank id used by the code:
  `com.tidyup.piggybank` (see `PIGGY_PRODUCT` in `ui/vault.gd`). Add the shop's cash-pack ids when you
  wire those (below). Test with a sandbox account on a real device.

## 3. Confirm the two undocumented StoreKit specifics (one sandbox buy)
GodotApplePlugins' StoreKit method/signal names are verified, but two values aren't in its public docs
and are isolated in `core/store.gd`:
- `STATUS_OK` — the `status` int that means "purchased"/"restored".
- `_product_id()` — the `StoreProduct` id property (expected `"id"`).
Run one sandbox purchase, check the logged `status`/product fields, and fix these two if needed.

## 4. Turn it on
- Game Center: flip `game_center` to `true` in `core/features.gd`.
- StoreKit: no flag — `store.available()` gates it, so **shipping the plugin enables real charges**. The
  vault confirm caption already switches from "(test build — nothing is charged)" to a real-charge line
  when StoreKit is present.

## 5. Server-side identity verification (REQUIRED before targeting)
A client can claim any `X-Player-Id`, so the server must verify it before targeting mail.
`Identity.verification()` returns the signed payload (`public_key_url, signature, salt, timestamp,
player_id`). Server: reject non-Apple `public_key_url`; fetch the public key; rebuild
`playerID + bundleID + timestamp(8-byte BE) + salt`; verify the signature; then issue a short-lived
session token the mail `GET` sends instead of re-signing every poll. Until that exists, keep
`game_center` off and ship broadcast mail (already supported).

## Follow-ups (same pattern, not yet wired)
- **Shop cash packs** (`ui/shop.gd`): route the coin/gem-pack buys through `store.purchase()` exactly like
  the vault, with the existing grant as the success branch. Register their product ids in step 2.
- **Receipt/transaction verification** server-side for purchases (StoreKit 2 JWS), mirroring step 5.
