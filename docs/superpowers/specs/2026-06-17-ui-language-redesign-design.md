# UI Language & Color Scheme Redesign — Design Spec

**Date:** 2026-06-17
**Scope:** Full UI-language system (palette · board · HUD · order strip · shop · overlays)
**Approach:** Principles + direction (no locked hex values — exact colors tuned during implementation)
**Contrast model:** Neutral board, items pop (the cat-game reference)
**Art direction:** Keep the existing painterly cozy-farm illustration. This is a redesign of the *UI system layered on top of the art*, not a re-theme.

---

## Problem statement

The current board reads as a wall of locks on a single flat olive field. Diagnosed at the code level in `games/grove/grove_palette.gd`:

- The play surface `GROUND #3F6B43`, locked cells `BRAMBLE_BG #4A5A3A`, and primary button `BTN_PRIMARY #4E7C46` are **all dark olive-greens inside a ~15-point range**. The palette itself has no figure/ground separation.
- The palette is a **flat list of ~30 named colors** with no semantic tiers (surface / recede / item-pop / accent), so every element renders at one perceptual depth.
- Consequence: locked/inert state is the highest-contrast thing on screen, playable items do not pop, the grid does not read as structure, and the core loop (orders) is the least legible element.

The fix is a **system**, not a recolor: a depth ladder, a de-overloaded palette organized by role, and one consistent cell/item/locked/HUD/order language built on top.

---

## Foundation

### 1. One depth ladder — three planes

Every element sits on exactly one of three planes. Saturation is a privilege of the top two.

| Plane | What lives here | Treatment | Color budget |
|---|---|---|---|
| **Sunk** *(new)* | Locked/sealed cells, inert/empty ground | Inset or shadowless; value pulled *toward* the surface; desaturated | None — neutral only |
| **Rest** | Cells, pills, chips, HUD chrome, secondary buttons | Soft resting shadow (existing `SHADOW_RESTING`) | Neutral + at most one identity tint |
| **Float** | Items/pieces, primary CTA, active orders, rewards | Raised shadow (existing `SHADOW_RAISED`) + pedestal | Full saturation — color lives here |

The engine already runs a two-tier shadow system (`SHADOW_RESTING` / `SHADOW_RAISED` in `tuning.gd` → `UiSkin`). This redesign **adds a third, lower tier — Sunk** — and assigns every element type to a plane. That single rule fixes the core failure: locked cells move *below* playable content instead of shouting above it.

### 2. Stop overloading green

Green currently means three contradictory things: play surface (`GROUND`), locked state (`BRAMBLE_BG`), and primary action (`BTN_PRIMARY`). This is the root cause of the missing figure/ground.

- **Board surface → warm neutral** (oat / wheat / soft warm-grey). It recedes and becomes a stage.
- **Green is reclaimed as a signal** — growth, "go," primary CTA. It now means something because it is the only green on screen.
- **Items keep their painterly saturation** and pop against the neutral stage automatically.

### 3. Color system — semantic role tiers

`grove_palette.gd` is restructured from a flat list into **role tiers**. Values below are described by *intent*; exact hex is tuned during implementation.

- **Surface** — warm neutral, low saturation, mid-high value. The stage. (Replaces olive `GROUND`.)
- **Cell / inset** — a hair off Surface; delineates the grid by *structure*, not contrast.
- **Locked** — desaturated, value-merged toward Surface, faint texture hint. Recedes.
- **Item pedestal** — light, soft disc/napkin that lifts any piece off the board. (Reuse the shop's `ICON_PLATE`.)
- **Accents — reserved, used ONLY to carry meaning:**
  - `CTA / growth` = leaf green
  - `reward / value` = honey-gold
  - `alert / new` = warm red (existing `#E24B4A`)
  - `info` = soft blue (existing `#5FA8D8`)
  - No structural element may use an accent hue.
- **Ink** — text on light (`INK`) / text on dark (`CREAM`), plus one muted variant.

Raw named colors stay; the new semantic layer maps **role → value**, so consumers ask for `Surface` or `Accent.CTA`, never a raw hue. This is what makes it a system and what lets the whole look re-tune from one file.

---

## Application layer

### 4. Cell + item container system

- **One cell.** Every board cell is the same rounded-square slot at one shared radius. Empty = a subtle inset on the Surface (Sunk plane). The grid reads as structure, never as content.
- **One pedestal.** Every item sits on the same light pedestal (reuse `ICON_PLATE`), so pieces feel like pieces on a board.
- **One item box + optical scale.** The HUD already solves uneven art weight with `CHIP_ICON_BOX` + per-icon `*_OPTICAL`. Extend that pattern to board pieces: a single `ITEM_BOX` with per-item optical scale, so a large item (seed bag) no longer dwarfs a small one (shovel).

### 5. Locked / sealed state — the most visible fix

- Locked cells render on the **Sunk plane**: desaturated, value pulled toward Surface, faint covered-ground texture — never a high-contrast badge.
- The lock indicator is a **small, low-contrast glyph**, not the loudest thing on screen.
- `Lv2`-style gates show their requirement as a **quiet micro-label**, de-emphasized until the player is one merge away — then it brightens, reusing the existing openable-cell hint-pulse (`BoardLogic.openable_for_hint`). Anticipation, not a wall.
- **The play area is the brightest region; the locked frontier recedes outward.** Figure/ground by value.

### 6. HUD

- Keep the cream-pill currency cluster — already well-tuned (shared icon box, optical scale, identity tints). It lives on the **Rest plane**.
- **Collapse the shape vocabulary.** Today there are four shape languages (round level token, capsule wallet, floating "Chapter" pill, raw icon-numbers). Mandate one corner-radius/elevation family. Spatial grouping: identity (level + chapter) top-left, wallet top-right, consistent `EDGE_MARGIN`.
- **"Chapter N" becomes a titled ribbon** in the existing `TITLE_*` language, not a floating chip.

### 7. Order / giver strip — surface the core loop

The most-buried element in the current screen, and the point of the game.

- Each order = a card in the shop's existing help/featured card language (`CARD_BG` cream, hero item on `ICON_PLATE`): **who** wants it (character) · **what** (item on the same pedestal as board items) · **reward** (honey-gold accent) · **progress**.
- **Actionable vs pending uses planes, not guesswork:** a deliverable order rides the **Float plane** at full saturation (and may breathe); a not-yet-payable order sits on **Rest**, dimmed via the existing `SHADE_LIT` / `SHADE_DIM` shades in `board.gd`.

### 8. Typography & labels

One ramp, four roles:

- **Display** — titles, ribbons
- **Number** — currency, big counts
- **Label** — chips, captions
- **Micro** — tile labels (`Lv2`, `Burst L0`)

Ink on light = `INK`, on dark = `CREAM`, plus one muted. Tile labels get **one placement convention** (a small pill, bottom-center of the cell) at the Micro size, fixing today's scattered placement.

### 9. Iconography & affordance

- **One chrome style.** Today painterly background + flat vector pills + semi-real items fight each other. Rule: *chrome* glyphs = soft, slightly-illustrated to match the art; *content* = painterly. Pick one chrome style and apply it everywhere.
- **Affordance tracks plane.** Mergeable/actionable cells get Float + optional idle breathe (existing `BREATHE_*`); inert cells get nothing. Tappable things press (existing `PRESS_*`). Interactivity becomes legible.

### 10. Motion / feedback

No new motion — **map existing FX to the planes.** Float elements may pop/breathe; Sunk/locked elements stay still. Rewards arc to the wallet (existing `fly_to_wallet`). Motion reinforces depth rather than decorating.

---

## Where it lands (file map)

- **`games/grove/grove_palette.gd`** — restructure flat list → role tiers (Surface / Cell / Locked / Pedestal / reserved Accents / Ink). Raw colors stay; add the semantic role→value layer.
- **`engine/scripts/core/tuning.gd`** — add the **Sunk** elevation tier alongside `SHADOW_RESTING` / `SHADOW_RAISED`; add `ITEM_BOX` + optical-scale dials for board pieces; add locked-cell treatment dials. The `Hud` / `UiSkin` / `Shop` classes receive the shape-collapse and order-card values.
- **`engine/scripts/scenes/board.gd`** — apply planes to cells / locked state / items; route orders through the card language; tie near-unlock emphasis to the existing hint-pulse.
- **`engine/scripts/ui/hud.gd`** — collapse the shape vocabulary; chapter ribbon.
- **`engine/scripts/ui/giver_stand.gd`** — order/giver cards in the shop card language with plane-based actionable/pending states.

---

## Non-goals (YAGNI)

- No new art assets beyond what the pedestal/chrome-style consolidation requires.
- No new animation systems — existing FX dials are remapped, not extended.
- No re-theme of the cozy-farm identity.
- No change to game logic, board model, merge rules, or progression — visual/UI language only.

---

## Success criteria

1. On the board, a first-time viewer's eye lands on **items and the active order first**, not on locked cells.
2. Locked cells are visibly *quieter* than playable cells (lower contrast, desaturated, recessed).
3. Every board piece shares a consistent pedestal and optically-balanced scale.
4. Green appears only as a CTA/growth/reward signal — never as a structural surface.
5. The HUD uses one shape/elevation family; the current order/goal is legible at a glance.
6. The entire look re-tunes from `grove_palette.gd` role tiers + `tuning.gd` dials — no per-scene hardcoded colors reintroduced.
