# Apple services hookup — Game Center + StoreKit (one plugin)

Both run through **GodotApplePlugins** ([github.com/migueldeicaza/GodotApplePlugins](https://github.com/migueldeicaza/GodotApplePlugins))
— a Godot-4 GDExtension that ships prebuilt binaries and covers Game Center, StoreKit 2, and Sign in
with Apple. The GDScript side is done and **inert until the plugin is in the build**:

- `core/identity.gd` — Game Center sign-in → a pseudonymous `player_id()` + the server-verification signature.
- `core/store.gd` — StoreKit 2 purchases (`purchase()` / `restore()`).
- `core/inbox_sync.gd` sends `X-Player-Id` when an id exists; `ui/vault.gd` routes the piggy-bank crack
  through `store.gd` when StoreKit is present (else the honest non-charging path).

Every native class is reached via `ClassDB` (never a direct symbol). `available()` additionally requires
`OS.has_feature("ios")`, so even though the plugin's macOS frameworks register the classes on the dev Mac
(see §1), the providers report unavailable on desktop and the game behaves exactly as today — verified by
`identity_tests` / `store_tests` in the active sweep.

## 1. Install the plugin (one command)
Run **`make ios-plugins`** (`tools/install_ios_plugins.sh`). It fetches a **pinned** GodotApplePlugins
release, verifies its checksum, and lays down the Game Center + StoreKit modules (plus their shared
`SwiftGodotRuntime`) under `addons/`, using the shipped `.gdextension` files. `make ios` runs this first,
so an export never lacks the plugin.

The binaries are large and **gitignored** (`/addons/`) — a regenerable per-checkout artifact like the
baked `.ctex` caches, so re-run `make ios-plugins` once in each fresh checkout/worktree. To bump the
plugin, change the pinned `COMMIT`/`SHA256` at the top of the script.

Both **iOS and macOS** slices are installed. The macOS frameworks aren't used by the game (it's iPad-only)
but are present so the GDExtension loads cleanly in the desktop editor/headless — otherwise Godot logs a
`No GDExtension library found for ... macos.arm64` error on every launch. They register
`StoreKitManager`/`GameCenterManager` on the Mac, which is why `available()` gates on `OS.has_feature("ios")`
to stay inert there. On a non-Apple host the modules fall back to the shipped no-op linux/windows stubs.

## 2. App Store Connect + entitlements
- **Game Center:** enable the capability for the app in App Store Connect. The iOS export already carries
  the entitlement (`entitlements/game_center=true` in `export_presets.cfg`).
- **Min iOS:** the plugin requires **iOS 17.0**, so the preset's `min_ios_version` is bumped to `17.0`
  (the app is iPad-only). Devices below iOS 17 can no longer install — revert if that is unacceptable.
- **StoreKit:** create the products. Register the piggy-bank id used by the code:
  `com.tidyup.piggybank` (see `PIGGY_PRODUCT` in `ui/vault.gd`). Add the shop's cash-pack ids when you
  wire those (below). Test with a sandbox account on a real device, or via an Xcode **StoreKit
  Configuration** file (`.storekit`) for local sandbox runs without App Store Connect round-trips.

## 3. Confirm the two undocumented StoreKit specifics (one sandbox buy)
GodotApplePlugins' StoreKit method/signal names are verified, but two values aren't in its public docs
and are isolated in `core/store.gd`:
- `STATUS_OK` — the `status` int that means "purchased"/"restored".
- `_product_id()` — the `StoreProduct` id property (expected `"id"`).
Run one sandbox purchase, check the logged `status`/product fields, and fix these two if needed.

## 4. Turn it on
- Game Center: `game_center` is now `true` in `core/features.gd` — sign-in runs on the iOS build. Safe to
  test; see §5 before trusting the id for targeting.
- StoreKit: no flag — `store.available()` gates it, so **shipping the plugin enables real charges**. The
  vault confirm caption already switches from "(test build — nothing is charged)" to a real-charge line
  when StoreKit is present. (Sandbox accounts are not charged real money.)

## 5. Server-side identity verification (REQUIRED before targeting)
A client can claim any `X-Player-Id`, so the server must verify it before targeting mail.
`Identity.verification()` returns the signed payload (`public_key_url, signature, salt, timestamp,
player_id`). Server: reject non-Apple `public_key_url`; fetch the public key; rebuild
`playerID + bundleID + timestamp(8-byte BE) + salt`; verify the signature; then issue a short-lived
session token the mail `GET` sends instead of re-signing every poll. Until that server exists, sign-in is
fine to test, but do NOT target mail by the id — `mail_sync` stays off and the feed serves broadcast
(already supported).

## Follow-ups (same pattern, not yet wired)
- **Shop cash packs** (`ui/shop.gd`): route the coin/gem-pack buys through `store.purchase()` exactly like
  the vault, with the existing grant as the success branch. Register their product ids in step 2.
- **Receipt/transaction verification** server-side for purchases (StoreKit 2 JWS), mirroring step 5.
