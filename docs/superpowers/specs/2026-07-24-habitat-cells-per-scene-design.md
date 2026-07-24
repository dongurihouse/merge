# Habitat cells per completed scene — retire the home-building system

Date: 2026-07-24
Branch: `cells-per-scene`

## Goal

A habitat (resident bucket) cell unlocks for **each cover-up scene the player fully
unlocks** — one cell per completed scene, five scenes, so five cells. Both Expedition
entry points open on the first cell, exactly as today's gate reads.

At the same time, remove the retired **home-building** system everywhere. It is the sole
current source of bucket cells, it is unreachable in the live game, and it is why no cell
ever unlocks.

## Root cause

All five maps are picture-book **cover-up scenes** (`coverup_mode: true`): Fairy Hollow
(hub), Snowy Village, Desert Oasis, Coral Reef, Cherry-Blossom Garden. Live progression is
the **cluster** system — unlock authored regions top-down in one strict global sequence
(`content.next_locked_cluster`, `cluster_ready`).

Bucket cells, however, are still derived from **completed home buildings**:

- `Bucket.cells_total()` → `Home.cells_total()` → `home_build.cells_granted(state, BUILDINGS)`
  ([bucket.gd:33](../../../engine/scripts/core/bucket.gd), [home.gd:44](../../../engine/scripts/core/home.gd),
  [home_build.gd:65](../../../engine/scripts/core/home_build.gd)).
- Buildings are bought via `map.gd::_on_build_tap` — but that path only fires for
  **non-coverup** pages, and there are none. So no building is ever built.
- Therefore `cells_granted()` is permanently **0** → every habitat cell renders locked
  ([residents.gd:423](../../../engine/scripts/ui/residents.gd)) and both Expedition buttons
  are suppressed by their `Bucket.cells_total() > 0` guard
  ([residents.gd:297](../../../engine/scripts/ui/residents.gd),
  [map.gd:1302](../../../engine/scripts/scenes/map.gd)).

A parallel, older per-map grant table `BUCKET_CELL_GRANTS = [2,1,2,1,2]`
([grove_data.gd:241](../../../games/grove/grove_data.gd)) is orphaned: only the economy sim
(`grove_sim.gd::_hab_cap`) still reads it, so the sim and the shipped game already disagree
on resident capacity.

## Design

### New cell source: completed scenes

Add a pure query to `content.gd`:

```gdscript
## Habitat cells granted so far — ONE per fully-unlocked cover-up scene (every cluster
## of the page unlocked). The only capacity source. Derived, never stored.
static func cells_from_scenes(unlocks: Dictionary) -> int:
    var n := 0
    for z in coverup_pages():
        if next_locked_cluster(int(z), unlocks) == "":
            n += 1
    return n
```

`coverup_pages()` returns the five coverup maps; `next_locked_cluster(z, unlocks) == ""`
means every cluster on that page is unlocked. The count is naturally capped at five. A
scene the player has merely *reached* (browseable, some clusters still locked) grants
nothing — the cell arrives only on full completion, matching "one cell per completely
unlocked scene."

`Bucket.cells_total()` becomes:

```gdscript
static func cells_total() -> int:
    return Content.cells_from_scenes(Save.grove().get("unlocks", {}))
```

Everything downstream of `cells_total()` is unchanged — the residents dialog's free/locked
cell split, the habitat wrap, both Expedition guards, the bottom-bar Residents-tile
visibility gate, and `bucket.state()`'s capacity re-sync all already read `cells_total()`
and need no edits. Capacity can still only grow here (completing a scene is monotonic), but
the existing overflow-return-to-hand guard in `bucket.state()` stays as a safety net.

### Remove the home-building system

Delete the system and repoint its two live readers.

**Delete outright**
- `engine/scripts/core/home.gd` — the save adapter.
- `engine/scripts/core/home_build.gd` — the pure module.
- `engine/tests/home_build_tests.gd` — its suite.
- `grove_data.gd`: `const BUILDINGS` and `const BUCKET_CELL_GRANTS` (both retired).

**Repoint the two live readers**
- `bucket.gd`: drop the `const Home` preload; `cells_total()` calls `Content.cells_from_scenes`
  (above).
- `board.gd`: `_gate_ready()` returns `Home.any_buyable()` to make a CTA breathe "go build."
  Repoint it to a new `content.gd` query — **is the next cover-up cluster unlockable right
  now** (level floor met + affordable):

  ```gdscript
  static func any_cluster_ready(unlocks: Dictionary, level: int, coins: int) -> bool:
      var z := current_unlock_map(unlocks)
      var cl := next_locked_cluster(z, unlocks)
      return cl != "" and cluster_ready(z, cl, unlocks, level, coins)
  ```
  Drop board.gd's `const Home` preload.

**Excise the dead build-tap path in `map.gd`**
- Remove the `const HomeBuild` preload and its uses: `_home_state_id` / `_home_next_step`
  collapse to constant `"built"` / `{}` (the coverup renderer already ignores them —
  [home_zone_view.gd:77,109](../../../engine/scripts/ui/home_zone_view.gd) only calls
  `state_of`/`next_step_of` when `not coverup_mode`). `HomeZoneView.build` keeps its
  signature; the scene passes trivial stubs.
- Remove `_on_build_tap` and its now-unreachable tap-target registration
  (the `building` hit branch feeding `_map_tap` at map.gd:1993/2227), plus `_building_label`
  and the `HomeBuild.def_of/next_step/any_buyable/defs` reads at map.gd:583–586, 860–863,
  2184, 2235–2237. Each removal is verified against the coverup render path (props still
  render `"built"`, take no badge).

**Debug + tools**
- `engine/scripts/ui/debug.gd:283–290` — the "build everything" helper is removed (or, if a
  quick cell-grant is still wanted for debugging, replaced by a helper that unlocks every
  cluster).
- `games/grove/tools/residents_dialog_shot.gd` and `map_shot.gd` — the building-buy setup
  that granted cells for the shot is replaced by marking scene clusters unlocked.

**Economy sim**
- `grove_sim.gd::_hab_cap` already counts completed maps, but via `BUCKET_CELL_GRANTS`.
  Rewrite it to mirror `cells_from_scenes`: `+1` per coverup page whose clusters are all
  unlocked. Sim and game then agree.

**Save / migration**
- `Save.grove()["home"]` (the building state) becomes vestigial. It is created lazily by the
  now-deleted `home.gd`, so nothing will recreate it and existing saves simply carry a dead
  key — harmless, read by nothing. `bucket.gd::_migrated_state` is confirmed not to read
  `BUILDINGS` or `Home` (its only `Home` reference is the `cells_total` line being
  repointed); the bucket's own migration is untouched. No migration code is needed — cells
  re-derive from `unlocks` (`Save.grove()["unlocks"]`), which every save already has.

**Docs**
- Mark `docs/superpowers/specs/2026-07-17-home-build-upgrade-map-design.md` superseded by
  this spec (a header note; history is kept).
- Fix the stale comment in `content.gd:714–717` that points cells at the building system.

## What stays

- The cover-up cluster system, `HomeZoneView` (still the scene renderer), the map render,
  scene manifests, and the `fh_*` prop entries inside `MAPS[0]` (scene props, not `BUILDINGS`
  — they render `"built"`).
- The residents dialog, both Expedition buttons, the bucket, and the whole acquire loop —
  all already read `cells_total()`.
- `can_populate` (the separate, softer "welcome residents" gate on first-spot-restored) is
  unrelated and untouched.

## Testing

- **New** `engine/tests/` coverage for `content.cells_from_scenes`: zero when the first
  scene has any locked cluster; `1` when every cluster of scene 0 is unlocked and scene 1 has
  a locked cluster; `5` when all five scenes are complete; and `content.any_cluster_ready`
  toggling on level/coin gates.
- **Update** `engine/tests/bucket_adapter_tests.gd` — `cells_total` now flows from `unlocks`,
  not building state; re-express its cell assertions in cluster terms.
- **Delete** `engine/tests/home_build_tests.gd`.
- **Update** `grove_test_base.gd` and the grove residents/economy suites where they seed
  cells via buildings — seed via unlocked clusters instead. `grove_residents_tests` should
  gain a case: completing a scene surfaces free cells and the `ResidentsExpeditionButton`;
  before completion, none.
- `make test-fast` after each engine edit; full `make test` before hand-off; render the home
  screen (`games/grove/tools/map_shot.gd`) and the residents dialog
  (`residents_dialog_shot.gd`) with a scene completed, and **look at** the unlocked cell +
  Expedition button before calling it done.

## Phasing (additive → flip, `make test` clean at each step)

1. **Additive.** Add `content.cells_from_scenes` and `content.any_cluster_ready` with their
   tests. Nothing consumes them yet; the game is unchanged.
2. **Flip the readers.** Repoint `bucket.cells_total`, `board._gate_ready`, and
   `grove_sim._hab_cap`. Cells now unlock per completed scene — the user-visible fix lands
   here. Update `bucket_adapter_tests` and the grove suites.
3. **Remove the system.** Delete `home.gd`, `home_build.gd`, `home_build_tests.gd`,
   `BUILDINGS`, `BUCKET_CELL_GRANTS`; excise the `map.gd` build-tap path and the debug/tool
   setup; fix docs/comments. Full `make test`, then the rendered smoke check.

## Verification

Not eyeballed: headless suites assert `cells_from_scenes`/`any_cluster_ready` and the real
residents dialog's cell + button structure; the final proof is the rendered home screen and
residents dialog with scene 0 completed, showing one free cell and a live Expedition button.
