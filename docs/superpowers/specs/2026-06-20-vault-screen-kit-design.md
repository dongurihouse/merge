# Vault (piggy bank) screen on the shared kit + frame border option — design

Date: 2026-06-20
Branch / worktree: `claude/jovial-bassi-95652a`

## Problem

The in-game Vault (piggy bank) face — `engine/scripts/ui/vault.gd` — is hand-drawn: a
`PanelContainer` wearing `Look.kit_panel("parchment")`, a code-built jar (`_make_jar`), and a
title ribbon, assembled inline. Every other modal (mail, daily, shop, settings) has been
rebuilt on the **shared workbench kit** (`games/grove/tools/ui_workbench_kit.gd`) and driven by
the saved design config, so its look is authored once in the UI workbench and read by the game.
The vault is the last hand-drawn holdout.

We have a new `vault_asset.png` art sheet (the vault reference is `vault.png`) carrying a
**twig/branch border**, a jar, an oval base plate, plus a banner / green button / ✕ / icons we
already have in the kit. We want to:

1. Rebuild the vault face from the shared kit + config (same pattern as `settings.gd`).
2. Give the **shared frame a reusable "border" option** (parchment / vault twig), and have the
   vault use the twig border.
3. **Reuse** the existing gold banner and green pill button (not the sheet's own copies).
4. Preserve the vault **math + IAP crack flow** exactly.

## Current behavior (context)

- `engine/scripts/ui/vault.gd` — `Vault.open(host, opts)` draws the overlay/veil/center, a
  parchment `PanelContainer`, a `Look.title_ribbon("Piggy bank")`, a code-built jar
  (`_make_jar`, already anticipating a `vault_jar.png` swap-in), a pitch line, and a green CTA
  via `Look.button(...)`. `_confirm_crack(...)` is the honest IAP confirm (StoreKit when the
  plugin is present, else the non-charging test path); both arms call `Vault.crack()` to grant
  + reset. The MATH lives in `engine/scripts/core/vault.gd` (`balance` / `cap` / `claimable` /
  `claim_min` / `price_usd` / `crack` / `skim`).
- It is opened from `engine/scripts/scenes/map.gd` `_open_vault` (bottom-bar piggy button,
  index 4) with a claimable ready-pip (`_refresh_piggy_pip` → `Vault.claimable()`).
- The shared frame — `ui_workbench_kit.gd` `dialog_frame(content, width, opts)` — draws the
  parchment card, gold banner overlay, docked ✕, and the clipping scroll. It already accepts
  `panel_art` / `banner_art` / `close_art` opts; the **Discovery/tiers** dialog dresses it in a
  twig border by hardcoding `panel_art: "kit/tiers_panel.png"` in `tiers_opts_from_config`.
- Config → opts: the workbench saves `ui_workbench_settings.json`; `dialog_opts_from_config`
  (+ `_frame_cfg`) and the per-dialog `*_opts_from_config` helpers turn it into builder opts.
  Both the workbench preview and the game read the same transform.
- The workbench view (`ui_workbench_view.gd`) registers each component in `IDS` / `CAPTIONS` /
  `ITEMS` / `_params` / layout groups, builds a preview and a per-item sidebar of `_slider_row`
  / `_option_row` / `_toggle_row` controls. `_option_row(label, key, choices)` is the dropdown.

## Decisions (locked)

1. **Border picker on the shared Frame item** — the new twig border is a first-class, reusable
   frame option (a registry + a `border` opt + a Frame-item dropdown), not chrome hardcoded into
   one dialog. The Frame item's saved border **defaults to parchment**, so mail/daily/shop/
   settings are unchanged; the vault carries its own border choice in its own config block.
2. **Reuse the existing banner + button** — the shared gold banner (via `dialog_frame`'s banner)
   and the existing green `pill_button` for the price/Claim CTA. Nothing new is sliced for these.
3. **Full rebuild** — slice the border + jar + plate, build the kit `vault_dialog` + workbench
   item + config, AND rebuild `engine/scripts/ui/vault.gd` on the kit, with a `vault_kit_tests`
   suite. Mirrors how `settings.gd` was done.
4. **Include the oval base plate** — sliced as `vault_plate.png` and seated under the jar.

## Design

### 1. Assets — `vault.plan.json` intake (`docs/design/asset-intake.md`)

`vault_asset.png` is a saturated-cyan UI sheet → `category: "sheet"`, sliced by islands
(template: `_new/_processed/tiers.plan.json`). Author `vault.plan.json` next to the raw in
`_new/`, peek the islands with `slice_islands.gd`, keep **only** the three we need (the banner /
button / ✕ / icons on the sheet are deliberately NOT cut — reused from the existing kit):

| output | path | role |
|---|---|---|
| `vault_panel` | `ui/kit/vault_panel.png` | the twig/branch **border** (new frame option) |
| `vault_jar`   | `ui/kit/vault_jar.png`   | the hero jar (vault content) |
| `vault_plate` | `ui/kit/vault_plate.png` | the oval base plate under the jar |

Run `make intake`, verify the cut sprites, archive the raw to `_originals/ui/vault_asset.png`
(already present — intake re-archives idempotently). `vault.png` stays a reference original.

### 2. Shared frame — the reusable border option (`ui_workbench_kit.gd`)

Add a borders registry near `dialog_frame`:

```gdscript
const FRAME_BORDERS := {
    "parchment":  {"art": "kit/panel_parchment_v2.png", "slice": 48.0, "pad_x": 26.0, "pad_y": 24.0},
    "vault twig": {"art": "kit/vault_panel.png",        "slice": 64.0, "pad_x": 40.0, "pad_y": 34.0},
}
```

(The twig `slice`/`pad` values above are starting defaults — tuned against the sliced sprite and
the Vault item's sliders during build; recorded in config once they read right.)

`dialog_frame(content, width, opts)` gains a `border` opt (default `"parchment"`). Resolution
order, so existing callers are byte-identical:

1. Look up `FRAME_BORDERS[border]` → default `panel_art` / slice (L/T/R/B) / `panel_pad_x|y`.
2. Apply explicit `panel_art` / `card_slice_*` / `panel_pad_*` opts **on top** (they win).

Tiers keeps passing explicit `panel_art` (untouched). Mail/daily/shop/settings pass no `border`
→ parchment default → identical output.

### 3. Vault kit component (`ui_workbench_kit.gd`)

**`vault_dialog(state, width, opts) -> Control`** — game-state-agnostic, mirroring
`settings_dialog`. `state = {balance:int, cap:int, price:String, claimable:bool, claim_min:int,
on_claim:Callable}`. Content column inside the shared frame:

- **Gem balance read** — `make_icon("gem")` + the balance number (the reference's "💎 320"),
  centered above the jar.
- **The jar on its plate** — a `vault_plate.png` base with `vault_jar.png` seated on it
  (plate behind, jar centered over it; sizes from `opts.jar_px` / `opts.plate_px`). When the art
  is absent, fall back to the **code-drawn jar** lifted out of `vault.gd` `_make_jar` (the kit
  invariant — same metrics either way), and a flat oval plate.
- **Pitch line** — the "premium you've earned … claim it all for {price}" copy (preserved).
- **The green price/Claim CTA** — the reused `pill_button(price, {bg:"green", icon:"gem", ...})`
  → fires `state.on_claim`. When `state.claimable` is false the pill dims and a "keep playing —
  fills at {claim_min}" hint shows (preserves today's non-blocking affordance).

**`vault_opts_from_config(cfg) -> Dictionary`** — start from `dialog_opts_from_config(cfg)` (so
the vault inherits the shared banner / ✕ styling tuned on the Frame item), then override from a
new `vault` config block:

```gdscript
o["border"] = "vault twig"                       # the new frame option
o["card_slice_*"] = v.get("card_slice", 64)      # vault's own tuned slice for the twig art
o["panel_pad_x"] = v.get("panel_pad_x", 40); o["panel_pad_y"] = v.get("panel_pad_y", 34)
o["banner_text"] = "Vault"; o["banner_icon_id"] = "piggy"   # existing icon_piggy sprite
o["jar_px"] = v.get("jar_px", 200); o["plate_px"] = v.get("plate_px", 220)
o["width_pct"] = v.get("width_pct", 80)
```

### 4. Workbench — the Vault item (`ui_workbench_view.gd`)

Register `"vault"` in `IDS`, `CAPTIONS` ("Vault — piggy bank (twig border)"), `ITEMS`
(test-only keys: balance / claimable preview), `_params` (saved: `width_pct`, `border`,
`card_slice`, `panel_pad_x|y`, `jar_px`, `plate_px`; preview: `balance`, `claimable`), and the
layout groups (with the other full dialogs). Add `_vault_sidebar()` — the vault-specific knobs +
the standard note that frame chrome (banner / ✕) is edited on the Frame item (matching
daily/shop/settings). Also add a **`Border` dropdown** to `_frame_sidebar()` Card section:
`_option_row("Border", "border", Kit.FRAME_BORDERS.keys())`, and `"border": "parchment"` to the
`frame` `_params` default. The preview builds:

```gdscript
Kit.vault_dialog(_vault_demo_state(p), _dlg_px("vault"), Kit.vault_opts_from_config(cfg))
```

with a demo state (`balance:320, cap:500, price:"$4.99", claimable:<preview toggle>`).

### 5. Game — rebuild `engine/scripts/ui/vault.gd`

`open(host, opts)` adopts the `settings.gd` shape: build overlay + veil (tap-dismiss) + center,
`Kit = load(KIT_PATH)`, `cfg = Kit.load_config(Kit.CONFIG_PATH)`, width from `vault.width_pct` ×
viewport, build `state` from `core/vault.gd` (`balance` / `cap` / `claimable` / `claim_min` /
`price_usd`), wire `state.on_claim` → the **existing `_confirm_crack(host, overlay, opts)`** (kept
verbatim, incl. StoreKit/test-path + grant/reset + `opts.refresh`), then
`Kit.vault_dialog(state, width, Kit.vault_opts_from_config(cfg))` + `FX.pop_in`. The hand-drawn
`_make_jar` is **removed** (its fallback now lives in the kit). `map.gd` `_open_vault` and the
ready-pip are unchanged. Layering holds: `ui/` loads the tools kit by PATH at runtime (the
inbox/settings idiom), keeping no hard dependency on a tools script.

### 6. Tests — `games/grove/tests/vault_kit_tests.gd`

Mirror `settings_kit_tests` (headless SceneTree, `grove_test_base`):

- `FRAME_BORDERS` resolves both names → existent art (or documented-absent → fallback).
- `dialog_frame` with `border:"vault twig"` uses the twig art; with no `border` uses parchment
  (regression guard for mail/daily/shop/settings).
- `vault_dialog(demo_state, …)` builds without error; the gem read, jar, plate, and green CTA
  nodes are present; `on_claim` fires.
- `vault_opts_from_config` returns the expected keys (border, slices, banner_text, jar/plate px).
- Engine vault-math suites (`save_tests`, `store_tests`) stay green unchanged.

Run `make test-fast` after each slice of work; `make test` before handoff.

## Out of scope / preserved

- Vault **math** (`engine/scripts/core/vault.gd`), the three skim sites (level-up, map-restore,
  t8-sell), IAP / StoreKit (`com.tidyup.piggybank`).
- `map.gd` chrome (bottom-bar piggy button) + the claimable ready-pip.
- The sheet's own banner / button / ✕ / icons (reused from the existing kit, not cut).

## Risks / open points

- **Twig-border slice margins** — a thick irregular twig frame can pinch at the nine-patch
  corners. Mitigation: the border registry + Vault-item sliders make slice/pad tunable; verify
  the cut at a few widths before locking values.
- **Jar fill read** — today's code jar shows a GOLD fill scaling with balance/cap. If
  `vault_jar.png` is a single static jar, the "fill grows with play" read weakens. Mitigation:
  keep the gem balance number as the explicit read; the static jar is the vessel. (A future
  pass can layer a fill mask if wanted — not in this scope.)
