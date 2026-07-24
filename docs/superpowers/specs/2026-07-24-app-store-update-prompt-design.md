# App Store update prompt — design

**Date:** 2026-07-24
**Status:** approved for planning
**Branch:** `feat/update-prompt`

## Goal

On iOS, notice when a newer build of Acorn Forest is live on the App Store and offer the player a
one-tap way to go update. The prompt is **optional** — always dismissible — and never blocks play.
Non-backward-compatible / forced updates are out of scope for now.

## Player-facing behaviour

At home open, if the App Store lists a version newer than the installed one, a dialog appears over the
dimmed home (the same modal seam as Settings/Mail):

- **Title:** "Update Available"
- **Body:** a short line ("A new version of Acorn Forest is available. Update now for the latest
  content and fixes.")
- **Update** (green primary) → opens the game's App Store page (`OS.shell_open`), then dismisses.
- **Not now** (cream secondary) → dismisses and **silences this exact version** — it will not re-prompt
  until a still-newer version ships.
- **✕** close disc → same as "Not now".

The look is the approved mock (`games/grove/tools/update_dialog_shot.gd`), built from the shared
`ui_workbench_kit.dialog_frame` + two `pill_button`s.

## Decisions (locked)

- **Detection source:** Apple **iTunes Lookup API** — `https://itunes.apple.com/lookup?bundleId=com.dongurihouse.acornforest`.
  No backend, no per-release step; Apple is the source of truth. Bundle id from `export_presets.cfg`.
- **Cadence:** **once per new version.** "Not now"/✕ persists the dismissed version; a strictly newer
  store version re-prompts. Checked once per session at home open (no in-session polling — a version
  can't change mid-session in a way that matters).
- **Optional only:** no forced-update mode; every path is dismissible.

## Architecture

Three units, each independently testable, mirroring existing patterns.

### 1. `engine/scripts/core/update_check.gd` — detection (network shell + PURE logic)

Modeled directly on `core/inbox_sync.gd` (thin HTTPRequest shell, pure apply, **silent no-op on any
failure — never blocks play, never shows a player error**).

- `LOOKUP_URL := "https://itunes.apple.com/lookup?bundleId=%s"` with the bundle id.
- `check(host: Node, on_prompt: Callable) -> void` — the network shell:
  - Platform gate: return immediately unless running on iOS (`OS.get_name() == "iOS"`). Editor / other
    platforms are a no-op (so the home is unaffected in dev and on non-iOS builds).
  - GET the lookup URL via a transient `HTTPRequest` child of `host` (timeout ~8s, matching mail sync).
  - On completion, call `evaluate(body, BuildInfo installed version, Save.update_dismissed())`; if it
    says prompt, fire `on_prompt.call(store_version, store_url)`.
  - Any failure (no network, non-200, bad start) → no-op.
- `evaluate(lookup_text: String, installed: String, dismissed: String) -> Dictionary` — **PURE**,
  unit-tested with no server. Returns `{"prompt": bool, "version": String, "url": String}`.
  - Parse JSON; read `results[0].version` and `results[0].trackViewUrl`. Malformed / empty results →
    `{"prompt": false}`.
  - `prompt = version_gt(store, installed) and store != dismissed`.
- `version_gt(a: String, b: String) -> bool` — **PURE** dotted-numeric compare, left-to-right
  (so `1.10 > 1.9`, `1.2.0 > 1.1.9`, missing trailing components treated as 0). Any store strictly
  greater than installed qualifies (backward-compat is not a gate, per scope).
- **Store URL:** use the lookup's `trackViewUrl`. `OS.shell_open` on that opens the App Store on device.
  (Implementation note: may rewrite `https://apps.apple.com/...` → `itms-apps://...` so it opens the
  App Store app directly rather than Safari; decided at build time, not a spec-level choice.)

### 2. `engine/scripts/ui/update_prompt.gd` — the dialog (view + wiring)

Modeled on `ui/settings.gd::open(host)` (overlay + dimmed veil + centered `dialog_frame`, load kit by
path so `ui/` keeps no hard dep on the tools script).

- `open(host: Control, store_version: String, store_url: String) -> void`:
  - Guard against double-open (`Overlay.is_open`).
  - Mount overlay → dimmed veil → `CenterContainer` → `dialog_frame(content, width, opts)` with
    `banner_text = Strings.t("update.title")`, `on_close = _dismiss(store_version)`.
  - Content column: a centered autowrap message `Label` (`Strings.t("update.body")`) + an `HBox` of
    two `pill_button`s: **Not now** (`bg: cream`) and **Update** (`bg: green`).
  - **Update** → `Audio.play("button_tap")`, `Save.mark_update_dismissed(store_version)` (so we don't
    re-nag after they've gone to update), `OS.shell_open(store_url)`, close.
  - **Not now / ✕** → `Save.mark_update_dismissed(store_version)`, close.
  - `FX.pop_in(dialog)` for the same entrance as the other modals.

### 3. Persistence — `engine/scripts/core/save.gd`

Mirror the `ftue_seen` / `mark_ftue_seen` idiom (deep-merged over defaults → old saves read as unset,
no migration):

- `update_dismissed() -> String` → `data.get("update_dismissed_version", "")`.
- `mark_update_dismissed(version: String) -> void` → idempotent write of the single string key.

### Wiring — `engine/scripts/scenes/map.gd`

- New feature flag in `core/features.gd`: `"update_check"` (see below), owner-flippable kill switch.
- In `_ready()`, next to `_sync_mail.call_deferred()`, add `_check_update.call_deferred()`.
- `_check_update()`: flag + guarded-`ResourceLoader.exists` check, then
  `load(".../update_check.gd").check(self, func(v, url): load(".../update_prompt.gd").open(self, v, url))`.
  Fires once per home open.

### Feature flag

`core/features.gd`: `"update_check": true` — real endpoint (Apple), so unlike the placeholder-gated
`mail_sync` it can default on. It is still fully platform-gated inside `check()` (no-op off iOS), so
flipping it only matters on device. Flip to `false` to disable app-wide.

## Strings / localization

Add to the game's `strings.json` and go through `Strings.t` / `host.tr` (like `settings.title`):
`update.title`, `update.body`, `update.update`, `update.later`.

## Testing

Headless unit suite (`engine/tests/…`, run via `make test-fast`) — all pure, no server:

- `version_gt`: `1.1.9 < 1.2.0`, `1.9 < 1.10`, equal → false, older → false, ragged lengths (`1.2` vs
  `1.2.0`), non-numeric junk doesn't crash.
- `evaluate`: newer store version → prompt; equal → no; older → no; `store == dismissed` → no;
  `dismissed` older than a newer store version → prompt; malformed JSON → no; missing
  `results`/`version`/`trackViewUrl` → no.
- `Save.mark_update_dismissed` / `update_dismissed` round-trip + idempotency + unset-on-fresh-save.

The dialog itself is verified visually via the existing mock shot (`update_dialog_shot.gd`); the network
path is a thin shell over the tested `evaluate` (same split as `inbox_sync.sync` vs `apply_feed`).

## Out of scope

- Forced / blocking updates and minimum-supported-version gating.
- Non-iOS stores (the check is a no-op off iOS).
- In-session re-checking / background polling.
- Showing release notes or a changelog in the dialog.
