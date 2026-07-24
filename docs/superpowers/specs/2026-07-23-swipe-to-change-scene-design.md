# Swipe to change scene — design

**Date:** 2026-07-23
**Surface:** the home screen (`engine/scripts/scenes/map.gd`, the `"map"` view)
**Status:** approved, ready for implementation plan

## Goal

On the home screen, let the player **swipe horizontally to move between scene pages**
(Fairy Hollow → Snowy Village → Desert Oasis → Coral Reef → Cherry-Blossom Garden),
with a finger-following slide that snaps to the next or previous scene. This **replaces**
the `‹ ›` page-turn arrows.

## Context (current behavior)

- The home is `map.gd`'s `"map"` view. It shows **one scene page** at a time; `_map_idx`
  is the page index into `G.MAPS`. All five pages browse freely (`open: true` for pages
  2–5; page 0 is the hub, `z == 0`), gated by `map_unlocked(z)`.
- Today scene changes go through the soft `‹ ›` chevrons added by `_add_page_arrows()`,
  which call `_open_map(dest)` — a full rebuild with a `FX.pop_in` transition.
- `content` is a full-rect Control and the **one input surface** (`content.gui_input`
  → `_on_input`). Its children are the scene render. The bottom nav / HUD / drifting
  weather are **siblings** of `content`, toggled by visibility — they are not part of the
  scene render and must not move when a scene slides.
- On the `"map"` view, `_on_input` currently resolves **taps only**: a press records
  `_press`; a release within 18px calls `_map_tap(...)`. Horizontal drags do nothing, so
  a swipe gesture is free to claim them.
- `_build_map()` builds the scene render (a HomeZoneView `holder` + the wandering-
  residents `amb` layer) directly into `content` and registers interactive state into
  members (`spot_hits`, `_zone_badges`, `_zone_coverings`), then runs the coverup ready-
  sequence (`_apply_coverup_sequence`) and the badge-above-nav clamp
  (`_clamp_badges_above_nav`).

## Design

### A. Render restructure (contained to `map.gd`)

Extract a helper so a whole scene can translate as a unit and a neighbor can be previewed
without corrupting the live page's hit-testing:

```
func _build_page_node(z: int, parent: Control, interactive: bool) -> Control
```

- Creates a fresh full-rect, mouse-IGNORE `Control` (the **page node**), adds it to
  `parent` (in-tree so global-rect math works), and builds that scene's visuals into it:
  the HomeZoneView `holder` (fitted into `_map_rect` with the same cover-fit factor) and
  the `amb` population layer for `z`.
- `interactive = true` (the **current** page) keeps today's exact behavior: assigns
  `_zone_coverings` / `_zone_badges`, registers badge hits into `spot_hits`, and — for a
  coverup page — runs `_apply_coverup_sequence()` and `_clamp_badges_above_nav(factor)`.
- `interactive = false` (the **neighbor preview**) builds visuals only and **touches no
  member state**. It may set badge ready-visuals for a faithful look, but never mutates
  `spot_hits` / `_zone_*`. This guarantees previewing the neighbor can't corrupt the live
  page.

`_build_map()` becomes: clear `content`; `_map_rect = _map_image_rect()`;
`_build_page_node(_map_idx, content, true)`; `if animate: FX.pop_in(content)`.

`_add_page_arrows()` **and its call site are deleted** (the `‹ ›` chevrons go away).

### B. Gesture state machine (`_on_input`, `_view == "map"` branch)

New member `_swipe: Dictionary = {}` holds the active drag; empty when idle. Fields:
`origin` (press point), `dir` (int; +1 = revealing previous, -1 = revealing next),
`cur` (current page node), `neighbor` (preview node or null), `neighbor_z`,
`neighbor_base_x`, `vel` (last horizontal drag velocity), `active`, `settling`.

Direction convention: `dx = event.pos.x - origin.x`. Drag **left** (`dx < 0`) reveals the
**next** page entering from the right; drag **right** (`dx > 0`) reveals the **previous**
page from the left. So `neighbor_z = _map_idx - sign(dx)`, and
`neighbor_base_x = -sign(dx) * view.x`.

Flow:

1. **Press** (touch or left-down): record `origin`/`_press`. Ignore presses while a
   settle tween is running (`_swipe.settling`).
2. **Move** (`InputEventScreenDrag`, or mouse motion with left held):
   - If no swipe active yet, decide the gesture on the first significant move: begin a
     swipe only if `abs(dx) > abs(dy)` **and** `abs(dx) > ACTIVATE` (~12px). Otherwise
     leave `_swipe` empty so the release still resolves as a tap.
   - On begin: set `dir`, compute `neighbor_z`. If `neighbor_z` is in range **and**
     `map_unlocked(neighbor_z)`, build the preview via `_build_page_node(neighbor_z,
     content, false)` at `x = neighbor_base_x`; else `neighbor = null` (edge).
   - Live update each move: with a neighbor, `cur.position.x = dx` and
     `neighbor.position.x = neighbor_base_x + dx`. With no neighbor (edge), apply
     resistance: `cur.position.x = dx * EDGE_RESIST` (~0.35), neighbor stays absent.
     Track `vel` from the drag event's velocity when present.
3. **Release** (touch/left-up):
   - If a swipe is active: **commit** iff `neighbor != null` **and**
     (`abs(dx) >= view.x * COMMIT_FRAC` (~0.33) **or** `abs(vel) >= FLING` (~700 px/s) in
     the drag direction). Start a ~0.22s ease-out (`TRANS_CUBIC`, `EASE_OUT`) tween:
     - **Commit:** `neighbor.position.x → 0`, `cur.position.x → sign(dx) * view.x`. On
       finished → `_open_map(neighbor_z, false)` (rebuild the destination as the real
       interactive page, animation suppressed so nothing pops over the just-slid page).
       `_open_map` already persists `last_map` and refreshes chrome badges + Play CTA.
     - **Cancel:** `cur.position.x → 0`, `neighbor.position.x → neighbor_base_x`; on
       finished free the neighbor node and clear `_swipe`.
     - Set `_swipe.settling = true` for the tween's duration so a second gesture can't race
       it.
   - If no swipe is active: fall through to the existing tap path (release within 18px →
     `_map_tap`).

Edge conditions mirror the arrows exactly: no wrap past the first/last page, and
`map_unlocked` is respected (a locked or out-of-range neighbor reads as an edge → resist +
spring back). A viewport resize mid-drag cancels any active swipe (`_on_viewport_resized`)
to avoid stale geometry; the normal rebuild re-fits.

### C. Isolation notes

- Only the scene render (inside `content`) slides. Bottom nav, HUD, and weather are
  siblings of `content` and stay put — no change needed there.
- The neighbor preview is added to `content` after the current page, so it draws on top at
  the seam during the slide (acceptable; they sit side by side).
- Committing rebuilds the destination through `_open_map`, so interactive state
  (`spot_hits`, coverup sequence, badge clamp) is re-established correctly for the new page
  — the preview never needs to be promoted to interactive.

## Testing (headless)

Pure logic (no tree):
- `_swipe_commit(dx, vel, view_w, has_neighbor) -> bool` — assert the ⅓-width and fling
  thresholds, and that an edge (`has_neighbor = false`) never commits.
- `_neighbor_z(map_idx, dx) -> int` (or the inline equivalent) — drag left → `idx+1`,
  drag right → `idx-1`.

Scene-level (in `grove_explore_tests.gd`, where the nav tests already live — instantiate
`Map.tscn`, `_open_map`, drive `_on_input` with synthetic `InputEventScreenTouch` /
`InputEventScreenDrag`, await the settle):
- Arrows are gone: `content.find_child("PageArrowNext"/"PageArrowPrev")` is null.
- A past-threshold swipe advances `_map_idx` to the expected neighbor and writes
  `last_map`.
- A short (sub-threshold) drag cancels: `_map_idx` unchanged, exactly one page node left
  under `content`, no leftover neighbor.
- A swipe at page 0 toward "previous" is a no-op (`_map_idx` stays 0, springs back).
- A plain tap (press → release within 18px, no drag) still routes to `_map_tap` (swipe
  didn't eat taps).

Run `make test-fast` after each step; `make test` (full sweep, includes the grove suites)
before handoff.

## Out of scope

- No changes to the place-picker (`"select"`) or the MAPS gallery (`"maps"`) — swipe is the
  home/`"map"` view only.
- No new scene-unlock rules; gating stays exactly as the arrows had it.
- Velocity/fling is a light assist over the distance threshold, not a full physics fling.
