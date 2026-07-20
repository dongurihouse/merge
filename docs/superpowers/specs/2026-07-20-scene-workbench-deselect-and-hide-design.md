# Scene Workbench: click-to-deselect + hide cluster/layer — design

**Date:** 2026-07-20
**Scope:** `games/grove/tools/scene_workbench_view.gd` (behavior), `scene_workbench_model.gd`
(one hit-test param). Workbench-only view state — nothing is written to the scene doc.

## Problem

Two workbench interaction gaps:

1. Clicking an already-selected cluster does nothing (it is kept selected so the press can
   start a drag). There is no way to deselect by clicking the cluster again.
2. There is no way to temporarily hide a cluster — or a whole layer — to see and work on what
   sits behind it.

## Part 1 — Click a selected cluster again to deselect

A **click** (press + release with negligible movement) on the already-selected cluster
deselects it; a **drag** (press + move) still moves it.

- On stage press over the already-selected cluster (today's no-op `else` branch), arm
  `_pending_deselect = true` and record the press point.
- Cluster drags are delta-based and begin on the first motion. Gate this for the pending case:
  do not begin moving until the pointer travels past a small threshold (~3 canvas px). Crossing
  the threshold clears `_pending_deselect` — the gesture is a drag, and normal move resumes.
- On release, if `_pending_deselect` is still set, `_select(-1)` (deselect).
- Isolation is untouched: deselecting does not exit isolation (that stays on `Esc` and the
  Exit-isolation button).
- Scoped to cluster re-clicks. A selected single item keeps its current behavior.

Normal drags (on a not-yet-selected cluster, which selects then drags) are unchanged — the
threshold gate applies only to the re-click-of-selected path.

## Part 2 — Hide a cluster or a layer (workbench-only)

New view state, neither persisted, both cleared on reload (`R`):

- `_hidden: Dictionary` — set of hidden cluster names.
- `_hidden_layers: Dictionary` — set of hidden layer slugs.

**Triggers**

- `H` key hides the current selection's cluster (`_sel_cluster`, or the cluster of the selected
  item `_sel`), then deselects.
- Each sidebar **cluster row** gets an eye toggle (`👁` visible / `🚫` hidden) that toggles that
  cluster in `_hidden`.
- Each of the six sidebar **layer headers** gets an eye toggle that toggles that layer slug in
  `_hidden_layers`.

**Effects**

- `_rebuild_stage` skips any entry whose cluster is in `_hidden` **or** whose layer is in
  `_hidden_layers` (and skips that entry's shadow).
- `M.hit_at` gains an optional `hidden_clusters := {}` / `hidden_layers := {}` filter (or one
  `is_hidden: Callable`) so hidden entries do not catch stage clicks — clicks fall through to
  whatever is behind.
- Hidden cluster rows and hidden layer headers render dimmed and keep their eye toggle, so the
  sidebar is how you find and restore them.
- Hiding a cluster or layer that contains the current selection deselects it (cannot edit what
  is not shown).

## Testing

Add to `grove_ui_tests` (workbench slice):

- Re-clicking the selected cluster (press + release, no motion) deselects; a press + past-threshold
  motion does not deselect and moves the cluster.
- `H` hides the selected cluster: it leaves the render set and the hit-test set, and its restore
  row remains in the sidebar.
- Hiding a layer removes all its entries from render + hit-test.
- Reload clears `_hidden` and `_hidden_layers`.

## Decisions

- Threshold-to-drag applies only to re-clicking the already-selected cluster.
- Hide auto-deselects the affected selection.
- Hide is view-only; reload restores everything.
