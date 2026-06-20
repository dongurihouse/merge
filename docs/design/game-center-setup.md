# Game Center hookup (iOS player identity)

The GDScript side is done and inert until you turn it on: `core/identity.gd` (the provider),
`map.gd` boots it on home open behind the `game_center` feature flag, and `core/inbox_sync.gd`
sends the id as `X-Player-Id` when present. None of the native path runs in the editor / on desktop /
in tests — the provider degrades to `""` (broadcast) wherever the `GameCenter` singleton is absent.

What's left is native + Apple + backend work that can't be built or tested from this repo alone.

## 1. Get the plugin into the iOS export

The game targets **Godot 4.6**. The official plugin
([godot-sdk-integrations/godot-ios-plugins](https://github.com/godot-sdk-integrations/godot-ios-plugins))
exposes the `GameCenter` singleton this code uses, **but has no Godot-4 binary release — you build it
from `master`**:

```sh
git clone https://github.com/godot-sdk-integrations/godot-ios-plugins
cd godot-ios-plugins
# fetch the matching godot headers, then:
scons platform=ios target=template_release plugin=gamecenter arch=arm64
```

Drop the resulting `.a` + the `gamecenter.gdip` config into `ios/plugins/` of the export, and tick the
plugin in the iOS export preset. (Alternatives if the Obj-C plugin is painful: the Swift GDExtensions
[migueldeicaza/GodotApplePlugins](https://github.com/migueldeicaza/GodotApplePlugins) or
[rktprof/godot-ios-extensions](https://github.com/rktprof/godot-ios-extensions) are Godot-4-native and
also ship StoreKit2 — useful for the IAP the shop/vault stub. They expose a **different API**, so
`identity.gd`'s internals (the singleton name + method/event names) would need retargeting; its public
interface — `boot()`, `player_id()`, `verification()` — stays the same.)

## 2. Apple config

- **App Store Connect:** enable Game Center for the app.
- **Entitlements:** add the Game Center capability to the iOS export's entitlements.
- A real device signed into a sandbox Game Center account is required to test sign-in.

## 3. Turn it on

Flip `game_center` to `true` in `core/features.gd`. On the next home open, `Identity.boot()` calls
`GameCenter.authenticate()` and drains the result onto `player_id()`; `inbox_sync` then sends the header.

## 4. Server-side verification (REQUIRED before trusting the id for targeting)

A client can claim any `X-Player-Id`, so the server must verify it with Apple's signature before
targeting mail. `Identity.verification()` returns the signed payload to send to your backend:

```
player_id, public_key_url, signature, salt, timestamp   (+ your app's bundle id)
```

Server steps (Apple's GKLocalPlayer identity-verification algorithm):
1. Reject `public_key_url` whose host isn't an Apple domain; fetch the public key (cache it).
2. Rebuild the signed blob: `playerID` (UTF-8) + `bundleID` (UTF-8) + `timestamp` (8-byte big-endian) + `salt`.
3. Verify `signature` against the blob with the public key. Only then trust `player_id`.
4. Issue a short-lived session token; the mail `GET` can then send the token instead of re-signing
   every request (cheaper than attaching the full signature to each poll).

Until step 4 exists, leave `game_center` off and ship broadcast mail — the client already handles that.
