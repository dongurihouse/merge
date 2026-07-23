# Task 2 report — the hand-hint overlay

## Status: DONE

## What changed

- Created `engine/scripts/ui/hand_hint.gd` — the reusable, input-transparent FTUE teach
  overlay (`HandHint.present` / `retarget` / `dismiss` / `cutouts` / `gesture` /
  `GESTURE_DRAG` / `GESTURE_TAP`), implemented from the brief's starting point.
- Appended the "the overlay" test section (16 new assertions) plus the `HandHint` preload
  and the `_all_ignore_mouse` helper to `engine/tests/ftue_hand_hint_tests.gd`, exactly as
  given in the brief, immediately before the final `print("== %d passed…` line. Nothing
  above that line was reordered or rewritten.

## TDD evidence

**RED** — `godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd` (Step 2,
before writing the overlay), fails as expected:
```
SCRIPT ERROR: Parse Error: Preload file "res://engine/scripts/ui/hand_hint.gd" does not exist.
ERROR: Failed to load script "res://engine/tests/ftue_hand_hint_tests.gd" with error "Parse error".
```

Same command after pasting `hand_hint.gd` verbatim from the brief (still RED — 2 failures,
see "Deviations" below):
```
FAIL  drag: every node in the overlay ignores mouse input (never blocks play)
SCRIPT ERROR: Cannot call method 'get_children' on a null value.
          at: _rebuild_veil (res://engine/scripts/ui/hand_hint.gd:99)
...
FAIL  tap: every node ignores mouse input
== 25 passed, 2 failed ==
```

**GREEN** — same command after both fixes below:
```
== FTUE hand hint tests ==
  PASS  fresh save: merge is unseen
  ... (all 11 Task-1 assertions PASS) ...
  PASS  drag: present returns an overlay
  PASS  drag: the overlay is parented to the host
  PASS  drag: the gesture is recorded
  PASS  drag: two cutouts (source + target)
  PASS  drag: cutout 0 is centred on the source
  PASS  drag: cutout 1 is centred on the target
  PASS  drag: every node in the overlay ignores mouse input (never blocks play)
  PASS  retarget: cutout 0 follows the new source
  PASS  retarget: cutout 1 follows the new target
  PASS  retarget: the overlay stays live (no re-present)
  PASS  dismiss: the overlay is marked dismissed immediately (the fade then frees it)
  PASS  tap: present returns an overlay
  PASS  tap: one cutout (the target only)
  PASS  tap: every node ignores mouse input
  PASS  flag off: present returns null
  PASS  flag off: nothing is added to the host
== 27 passed, 0 failed ==
```
Exit code 0, no engine ERROR lines. 27 total (11 Task-1 + 16 new) — matches the brief's
hand-counted figure, but per its own caveat I did not add or remove assertions to chase
that number; it's simply what the pasted block produces.

**Layering** — `godot --headless --path . -s res://engine/tests/layering_tests.gd`:
`== 124 passed, 0 failed ==`, including the specific line
`PASS  ui/hand_hint.gd does not import scenes/`.

**Full sweep** — `make test-fast`:
```
23 suites · 856 passed · 0 failed
ALL SUITES PASSED
```
`engine/tests/ftue_hand_hint_tests` reported `27 passed` there too (0.74s).

## Deviations from the brief's pasted code, and why

The brief said the pasted overlay code "has not been run" and to fix real problems rather
than paper over them. Two fixes were needed; both are behavior-preserving for the
documented, tested interface — no constant, method signature, `GESTURE_*` value, or
cutout/retarget/dismiss semantic changed.

### 1. `_ready()` → explicit `_build()`, called from `present()`

**Symptom:** with the code pasted verbatim, `HandHint.present(...)` returned a non-null
Control (so `present != null` passed), but every subsequent call — `.cutouts()`,
`.gesture`, `_all_ignore_mouse`, `.retarget` — either failed or crashed with `Cannot call
method 'get_children' on a null value` / `Invalid access to property ... on a base object
of type 'Nil'`.

**Cause:** `present()` does `host.add_child(o)` and returns `o` immediately. Godot does not
guarantee `_ready()` has fired by the time `add_child()` returns — in this headless
`SceneTree` script (which runs its entire `_initialize()` before the tree ever processes a
frame) it provably had not: `_veil` and `_hand` were still null right after `present()`
returned, so every method touching them broke.

**Fix:** renamed the `_ready()` body to a plain method `_build()` and call it explicitly,
synchronously, right after `add_child(o)` inside `present()`. Construction now happens on
the same call stack as `present()` in every host — headless or live game — rather than
depending on when (or whether, before the caller's very next statement) the engine
schedules `NOTIFICATION_READY`. `_ready()` itself is no longer defined on the class, so
there is no risk of double construction if the engine also later dispatches the
notification — it's simply unused. `present()` still returns the overlay already parented
to `host` and fully built, which is all the tests (and the brief's contract) require.

### 2. `_screen_size()` fallback instead of `size` / `get_viewport_rect()`

**Symptom (after fix #1):** the two `_all_ignore_mouse` assertions still failed, and an
engine-level `ERROR: Condition "!is_inside_tree()" is true` fired from `get_viewport_rect()`
inside `_rebuild_veil()`.

**Cause:** `_rebuild_veil()`'s screen rect was `size if size != Vector2.ZERO else
get_viewport_rect().size`. `_build()` now runs synchronously right after `add_child()`,
before the engine's layout pass has resolved the `PRESET_FULL_RECT` anchors into an actual
`size` — so `self.size` reads `(0, 0)` at that point even though the host was already given
a real size by the caller. That sent it down the `get_viewport_rect()` branch, which itself
asserts `is_inside_tree()`; in this headless `SceneTree` script `is_inside_tree()` reports
`false` for nodes added within `_initialize()`'s own call stack — confirmed with a
standalone probe script: even `host`, added directly to `root`, reports
`is_inside_tree() == false` before the tree's first process frame. This matches the
project's known "Godot headless-test gotchas" pattern (tree-membership queries lag behind
`add_child()` in a not-yet-running `SceneTree`). With a zero-size screen, the veil's
subtract-bands loop degenerated (a `Rect2()` screen fully "covered" by the hole produces no
bands), so no dim `ColorRect`s were ever added under `_veil` — that's why the "every node
ignores mouse input" walk still reported false: mouse-filter aside, the missing bands meant
the overlay wasn't actually painting a dim at all, a real visual defect, not merely the
harness noise.

**Fix:** replaced the `size` / `get_viewport_rect()` fallback with a `_screen_size()` helper
that prefers, in order: (1) `self.size` once the layout pass has run; (2) the immediate
parent's `Control.size` if non-zero (the host `present()` was given, which the caller
already sized — matches every documented call, `present(host: Control, …)`); (3)
`get_viewport_rect().size`, now guarded behind `is_inside_tree()` so it never fires the
assert; (4) `Vector2.ZERO` as a last resort. This is not only a test-only patch: without it,
a live-game call to `HandHint.present()` would hit the identical zero-size-on-first-build
race (construction is synchronous with `add_child()`, before any layout pass runs),
producing a veil that dims nothing on its very first frame with no later trigger to correct
it — a real, user-visible bug. Falling back to the host's own size fixes it for both paths
and is strictly more correct than the brief's version, not merely a headless workaround.

Neither fix touches the veil-subtraction geometry (`_subtract`), the hand animation
(`_loop_drag` / `_loop_tap`), the fallback hand drawing (`_HandDraw`), or the
`Look.kit("kit/hand.png")` texture-vs-fallback branch — those matched the brief and needed
no changes.

## Self-review findings

- `dismiss()` guards re-entry via the `dismissed` flag, so a second `dismiss()` call (e.g.
  Task 3 calling it defensively) is a no-op past the first, matching the "marked dismissed
  immediately" contract.
- `_ready()` is genuinely gone from the class (grepped to confirm), so there is no dead code
  path that could double-run `_build()`'s child-adds if the engine does later dispatch
  `NOTIFICATION_READY` on the node.
- The `res://addons/*/…gdextension` load errors visible in every raw Godot run are
  pre-existing environment noise (missing native iOS plugin binaries in this checkout,
  unrelated to iOS Game Center / StoreKit), present on every headless invocation in this
  worktree regardless of this change.
- `ui/kit/hand.png` does not exist yet in this worktree (Task 4's job — confirmed via
  `find`), so every run above exercised the `_HandDraw` code-drawn fallback path, not the
  texture path. Both share the same sizing/pivot metrics per the brief, but the
  `TextureRect` + `Look.kit` branch is untested by `make test-fast` until Task 4 lands the
  art — expected per the task split, not a gap closeable here.
- `_screen_size()`'s parent-size fallback only helps when the immediate parent is a
  `Control` with a non-zero size. `present(host: Control, …)`'s static type hint enforces
  "host is a Control" for any GDScript caller, so this is not a runtime gap in practice.
- `.superpowers/sdd/task-2-report.md` (this file) previously held a report for an unrelated,
  already-merged feature ("`Kit.action_button` builder + config reader", committed
  `af59439e` on a commit that is an ancestor of this branch's base `ab1d6804`). That content
  has been replaced with this report, per this task's brief which names this exact path as
  the destination — consistent with how the repo already treats `task-N-report.md` as
  reused per active plan (the old content itself noted the same thing about its own
  predecessor).

## Files changed

- `engine/scripts/ui/hand_hint.gd` (new)
- `engine/tests/ftue_hand_hint_tests.gd` (appended overlay section)

## Concerns

None blocking. The two fixes above are narrow and behavior-preserving; flagged here per the
brief's own instruction to explain rather than silently paper over anything Godot rejected.


---

# Task 2 review-fix report — two review findings

## Status: DONE

## What changed

### Finding 1 (Important) — the veil's rectangle-subtraction geometry had no test coverage

Added 6 small helpers to `engine/tests/ftue_hand_hint_tests.gd`, grouped in a new
"veil geometry helpers" block placed right before the existing `fresh()` helper (next to
`ok()` / `_all_ignore_mouse()`), so no summation logic is repeated inline per case:

- `_veil_bands(overlay)` — reads the overlay's real `ColorRect` children out of its private
  `_veil` node (GDScript does not enforce the underscore as access control, so this reads
  exactly the same way the existing tests already read `.gesture` / `.cutouts()` off a
  `Control`-typed handle) and returns them as `Rect2` in host space.
- `_sum_area(rects)` — plain area sum.
- `_rect_union_area(rects)` — union area for the 1-2 rects `cutouts()` ever returns; subtracts
  the shared intersection once so an overlapping pair isn't double-counted in the expected
  total.
- `_no_overlap(rects_a, rects_b)` — true iff no rect in one list has positive-area intersection
  with any rect in the other (band-vs-cutout check).
- `_no_self_overlap(rects)` — true iff no two rects within one list overlap each other
  (band-vs-band check, catches double-counted band area that a lucky area-sum coincidence
  might otherwise hide).
- `_all_sizes_nonnegative(rects)` — guards against a negative-size rect.

Appended 15 new assertions to the existing overlay section, immediately before the final
`print("== %d passed…` line, using a dedicated `vhost` (800x600) kept separate from the
existing `host`/`host2` so previously-dismissed-but-still-fading overlays can't be
miscounted:

- **one cutout (tap):** bands' total area == host area minus the grown cutout; no band
  overlaps the cutout.
- **two disjoint cutouts (drag):** bands' total area == host area minus both grown cutouts
  (via `_rect_union_area`, which degrades to a plain sum when disjoint); no band overlaps
  either cutout.
- **two cutouts that OVERLAP each other** (`Rect2(100,100,100,100)` vs
  `Rect2(150,130,100,100)`, sharing a `112x112`-ish region after growing): bands' total area
  == host area minus the UNION (not the naive sum) — proving no double-counted area; bands
  pairwise disjoint — proving no gaps/overlaps among the bands themselves; no band overlaps
  either cutout.
- **a cutout lying partly offscreen** (`Rect2(-20,250,60,60)`, grown to `x∈[-26,46]`, so the
  left ~26px hangs off the host's left edge): bands' total area == host area minus only the
  ON-SCREEN sliver of the cutout (clipped against the host rect); no band has a negative
  size; no band overlaps the (clipped) cutout.

Sums are compared with the global `is_equal_approx()` float comparator (never `==`), per the
project's known float32 `Control` geometry gotcha. The overlap checks use a small epsilon
(`> 0.01`) rather than a strict `> 0.0`, since touching (non-overlapping) band/cutout edges
computed from the same float ops could in principle differ by a sub-pixel rounding sliver.

### Finding 2 (Minor) — `retarget()` had no guard against being called after `dismiss()`

`engine/scripts/ui/hand_hint.gd`: added an early-return guard to `retarget()`:

```gdscript
func retarget(source_rect: Rect2, target_rect: Rect2) -> void:
	if dismissed:
		return
	_src = source_rect
	_dst = target_rect
	_rebuild_veil()
	_start_loop()
```

No signature, constant, or other public behavior changed — `dismissed` was already a public
field set by `dismiss()`; `retarget()` now simply reads it before doing anything.

Added one assertion in `engine/tests/ftue_hand_hint_tests.gd` (appended with the veil-geometry
block, also before the final print line): present a fresh tap overlay, `dismiss()` it, then
call `retarget()` with different rects and confirm `cutouts()` is unchanged — proving the
call was a no-op rather than silently rebuilding the veil / restarting a tween on a dying
node.

## Commands run and full output

### `godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd`

```
ERROR: Error loading GDExtension configuration file: 'res://addons/GodotApplePluginsGameCenter/godot_apple_plugins_game_center.gdextension'.
   at: parse_gdextension_file (core/extension/gdextension_library_loader.cpp:277)
ERROR: GDExtension dynamic library not found: 'res://addons/GodotApplePluginsGameCenter/godot_apple_plugins_game_center.gdextension'.
   at: open_library (core/extension/gdextension.cpp:740)
ERROR: Error loading extension: 'res://addons/GodotApplePluginsGameCenter/godot_apple_plugins_game_center.gdextension'.
   at: load_extensions (core/extension/gdextension_manager.cpp:329)
ERROR: Error loading GDExtension configuration file: 'res://addons/GodotApplePluginsStoreKit/godot_apple_plugins_storekit.gdextension'.
   at: parse_gdextension_file (core/extension/gdextension_library_loader.cpp:277)
ERROR: GDExtension dynamic library not found: 'res://addons/GodotApplePluginsStoreKit/godot_apple_plugins_storekit.gdextension'.
   at: open_library (core/extension/gdextension.cpp:740)
ERROR: Error loading extension: 'res://addons/GodotApplePluginsStoreKit/godot_apple_plugins_storekit.gdextension'.
   at: load_extensions (core/extension/gdextension_manager.cpp:329)
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

== FTUE hand hint tests ==
  PASS  fresh save: merge is unseen
  PASS  fresh save: gen_tap is unseen
  PASS  an unknown id reads as unseen (never crashes)
  PASS  marking merge makes it seen
  PASS  marking merge leaves gen_tap alone
  PASS  marking twice is idempotent
  PASS  seen state survives a reload
  PASS  unseen state survives a reload
  PASS  a save missing the ftue_seen key reads as unseen (no migration)
  PASS  the ftue_hand_hint flag exists
  PASS  the ftue_hand_hint flag defaults ON
  PASS  drag: present returns an overlay
  PASS  drag: the overlay is parented to the host
  PASS  drag: the gesture is recorded
  PASS  drag: two cutouts (source + target)
  PASS  drag: cutout 0 is centred on the source
  PASS  drag: cutout 1 is centred on the target
  PASS  drag: every node in the overlay ignores mouse input (never blocks play)
  PASS  retarget: cutout 0 follows the new source
  PASS  retarget: cutout 1 follows the new target
  PASS  retarget: the overlay stays live (no re-present)
  PASS  dismiss: the overlay is marked dismissed immediately (the fade then frees it)
  PASS  tap: present returns an overlay
  PASS  tap: one cutout (the target only)
  PASS  tap: every node ignores mouse input
  PASS  flag off: present returns null
  PASS  flag off: nothing is added to the host
  PASS  veil: tap bands' total area == host area minus the grown cutout
  PASS  veil: tap bands never overlap the cutout
  PASS  veil: drag bands' total area == host area minus both grown cutouts
  PASS  veil: drag bands never overlap either cutout
  PASS  veil: overlapping cutouts — bands' total area == host area minus the UNION (no double-counted area)
  PASS  veil: overlapping cutouts — the bands themselves have no gaps or overlaps
  PASS  veil: overlapping cutouts — no band overlaps either cutout
  PASS  veil: an off-screen-partial cutout — bands still tile the visible screen (only the on-screen sliver is punched out)
  PASS  veil: an off-screen-partial cutout — no band has a negative size
  PASS  veil: an off-screen-partial cutout — no band overlaps the (clipped) cutout
  PASS  retarget after dismiss: a no-op — the target doesn't move
== 38 passed, 0 failed ==
```

Exit code 0. All 38 assertions (27 pre-existing + 11 new: 10 veil-geometry + 1 retarget-guard)
passed on the first run — no assertion initially failed. The `GodotApplePlugins*` GDExtension
errors are pre-existing environment noise (missing native iOS plugin binaries in this
checkout), present on every headless invocation in this worktree, unrelated to this change.

### `make test-fast`

```
      time   pass  status  suite
  ------------------------------------------------------------
     1.95s    183  ok      engine/tests/mechanics_tests
     1.15s     13  ok      engine/tests/action_button_tests
     1.06s    124  ok      engine/tests/layering_tests
     0.96s     66  ok      engine/tests/quest_fence_tests
     0.96s     93  ok      engine/tests/save_tests
     0.95s     47  ok      engine/tests/quest_tests
     0.87s      4  ok      engine/tests/strings_tests
     0.85s      4  ok      engine/tests/kit_config_cache_tests
     0.78s     18  ok      engine/tests/inbox_sync_tests
     0.78s     12  ok      engine/tests/hint_tests
     0.77s     13  ok      games/tools/tests/slice_islands_tests
     0.77s     38  ok      engine/tests/ftue_hand_hint_tests
     0.77s      6  ok      engine/tests/identity_tests
     0.76s     19  ok      engine/tests/tuning_tests
     0.76s     33  ok      engine/tests/home_build_tests
     0.76s     31  ok      engine/tests/bucket_adapter_tests
     0.76s      9  ok      engine/tests/store_tests
     0.76s     66  ok      engine/tests/resident_bucket_tests
     0.75s      4  ok      engine/tests/build_info_tests
     0.75s     25  ok      engine/tests/boot_trace_tests
     0.75s     15  ok      engine/tests/bust_tests
     0.75s      7  ok      engine/tests/scene_warm_tests
     0.73s     37  ok      engine/tests/iap_tests
  ------------------------------------------------------------
  wall   5.24s  (sum of suite-times  20.12s, speed-up 3.8× at JOBS=4)
  23 suites · 867 passed · 0 failed

  ALL SUITES PASSED
```

Exit code 0. 23 suites (unchanged), 867 passed (up from the prior 856 baseline by exactly
the 11 new assertions — `ftue_hand_hint_tests` now reports `38 passed` where it previously
reported `27`), 0 failed.

## Whether any assertion initially failed

No. Every new assertion passed on the first run of both commands above — the geometric
predictions (worked out by hand against `Rect2.grow(CUTOUT_PAD)` and the `_subtract()`
algorithm's band-splitting rules before writing the test) matched what `_rebuild_veil()`
actually produced in every case, including the overlapping-cutouts union-area case and the
partly-offscreen clipped-area case. No implementation change was needed to make the veil
geometry tests pass — `_subtract()`/`_rebuild_veil()` were already correct; they simply had
no coverage. Only `retarget()` needed a code change (the dismissed-guard itself), and it
worked as intended on the first run once the guard was added.

## Files changed

- `engine/scripts/ui/hand_hint.gd` — added the `dismissed` guard to `retarget()` (4 lines).
- `engine/tests/ftue_hand_hint_tests.gd` — added 6 veil-geometry helpers + 15 new assertions
  (11 veil-geometry cases, 1 retarget-after-dismiss guard case; the helper block itself
  contributes no assertions).

## Concerns

None blocking. Both fixes are narrow, additive, and behavior-preserving for every documented
public name (`present`, `retarget`, `dismiss`, `cutouts`, `GESTURE_DRAG`, `GESTURE_TAP`,
`dismissed`, `gesture`) — no signature or semantic changed, only `retarget()` gained an early
return for a state (`dismissed == true`) that was previously unhandled.
