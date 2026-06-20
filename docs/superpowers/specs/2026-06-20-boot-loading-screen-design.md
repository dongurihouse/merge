# Boot loading screen + boot trace — design

**Date:** 2026-06-20
**Branch:** `worktree-loading-screen`
**Status:** approved direction, pending spec review

## Goal

Add a branded cold-boot loading screen to *Tidy Up*, and — because the game is under
active development — instrument the boot path so we can **monitor what is taking long**.

Two deliverables, one feature:

1. **On screen:** a splash shown on app launch (logo on the cream chrome + a determinate
   progress bar + a current-phase label) that covers the initial scene load and reveals
   the home map when it is ready.
2. **In the log:** a detailed, aligned **per-phase timing table** printed on every cold
   boot — the durable, copy-pasteable, diff-able record of where boot time goes.

The split matters: the heavy boot work (`Map._ready` building the whole home view) runs
**synchronously on the main thread**, so the screen cannot repaint mid-build. Rather than
refactor the build into a coroutine (invasive, spreads the build across frames), the live
on-screen element stays coarse (bar + label) and the **log table** carries the detail.

## Current boot (what we're changing)

- `project.godot` `run/main_scene = res://engine/scenes/Map.tscn`. The app boots straight
  into the home map, which builds the entire view synchronously in `map.gd._ready`
  (`_load_state` → `_build_hud` → `_build_chrome` → `_open_map` → weather/ambient).
- Existing infra we reuse, not replace:
  - `engine/scripts/core/scene_warm.gd` — threaded scene preload + packed swap
    (`prewarm` / `take` / `go` / `is_warm`). The Map load+compile is ~270 ms (measured).
  - `engine/scripts/ui/scene_fade.gd` — cover/fade helpers (`fade_in`, `to`) that hide the
    synchronous instantiate hitch behind a near-black cover. `Map._ready` already calls
    `SceneFade.fade_in`.

## Architecture

A new **Boot** scene becomes `main_scene`. It is cheap to instantiate, so it paints on the
first frame with no hitch. It kicks the threaded Map load, animates a progress bar while
the worker thread loads, then hands off to the map through the existing fade+warm path.

```
app launch
  → Boot.tscn (main_scene)           cheap; paints immediately
      _ready:  BootTrace.start()
               window fit + font
               build splash UI (bg + logo + bar + label)
               SceneWarm.prewarm(Map)         load+compile on worker thread
      _process: poll load status → drive bar  (live; yields across frames)
               when warm AND min-time elapsed:
                 SceneFade.to(self, tree, Map) cover → SceneWarm.go (warm packed swap)
  → Map.tscn
      _ready:  instrumented with BootTrace.phase(...) around its build steps
               SceneFade.fade_in (existing)   reveals the home map
               BootTrace.done()               prints the full timing table
```

### New / changed files

| File | Change |
|---|---|
| `engine/scripts/core/boot_trace.gd` | **New.** Static phase timer + table formatter. |
| `engine/scenes/Boot.tscn` | **New.** Root `Control`, full-rect, `boot.gd`. |
| `engine/scripts/scenes/boot.gd` | **New.** Splash UI + load polling + handoff. |
| `engine/scripts/scenes/map.gd` | Add `BootTrace.phase(...)` markers + `BootTrace.done()` (no-op when no trace is active, so Board→Map returns are unaffected). |
| `project.godot` | `run/main_scene` → `Boot.tscn`; optional matching engine `boot_splash` (bg color + logo) for a seamless first frame. |
| `games/grove/assets/ui/boot/logo_tidyup.png` | **New.** Copied out of `_concepts/tidyup/` so the shipped splash does not depend on a scratch folder. Re-imported via `make import`. |
| `engine/tests/boot_trace_tests.gd` | **New.** Headless suite (added to `ENGINE_TESTS`). |
| `engine/tools/boot_splash_shot.gd` | **New.** Dev tool: render the splash to a PNG for visual verification (real renderer via `quiet_godot.sh`). |

## Component 1 — `BootTrace` (the instrument)

`extends RefCounted`, static-only (never instantiated), mirroring the `SceneWarm` style.

Boot phases are **sequential and non-overlapping**, so the API is a moving cursor:

- `start()` — begin a trace: clear phases, record `boot_t0`, set `active = true`.
- `phase(name: String)` — stamp the previous phase's duration, open `name`. No-op unless
  a trace is active.
- `done()` — close the final phase, print the table, set `active = false`. No-op if inactive.
- `active() -> bool` — is a trace running? (Lets `map.gd` call `phase`/`done`
  unconditionally; they no-op on normal Board→Map opens because only `Boot` calls `start()`.)
- `format_table(phases, total_us) -> String` — **pure** function: an aligned table with
  phase name, ms, and a share-of-total bar. This is the unit-tested core.

Timing source: `Time.get_ticks_usec()`. Output via `print()` so it shows in both the
headless log and the running game's stdout. Example shape:

```
── boot trace ──────────────────────────────
  boot.window        2.1 ms  ▏
  boot.ui            4.8 ms  ▎
  scene.load       268.4 ms  ███████████████▌
  scene.swap         9.0 ms  ▌
  map.load_state    11.2 ms  ▋
  map.build_hud     18.7 ms  █▏
  map.build_chrome  22.0 ms  █▎
  map.open_map      96.4 ms  █████▌
  ─────────────────────────────────────────
  total            432.6 ms
```

The cursor model means each `phase(name)` closes the prior one — the names above are the
proposed instrumentation points (refine during implementation).

## Component 2 — `boot.gd` (the splash)

`_ready()`:
1. `BootTrace.start()`, then `phase("boot.window")` → `Design.fit_desktop_window()`,
   `UiFont.apply()` (same calls `map.gd` makes today; idempotent — done once here, early).
2. `phase("boot.ui")` → build the splash tree:
   - full-rect `ColorRect` background, `SCREEN_BG` (`#F4EEDF`, the game's chrome cream);
   - centered column: logo `TextureRect` (`logo_tidyup.png`, keep-aspect, ~60% viewport
     width), a gap, a rounded **progress track** with a **fill** rect, and a phase
     **label** beneath. Keep refs to fill / label / track width.
3. `phase("boot.prewarm")` → `SceneWarm.prewarm(MAP_PATH)`.
4. `phase("scene.load")` (the threaded-load wait begins), start `_process`.

`_process(delta)` — drive the bar from **real** load progress, paced by a minimum duration
so it never flashes:
- `ResourceLoader.load_threaded_get_status(MAP_PATH, p)` → `warm = (status == LOADED)`,
  `load_frac = warm ? 1.0 : p[0]`.
- Bar value and handoff are two **pure** static helpers (unit-tested):
  - `boot_bar(elapsed, min_dur, load_frac, warm)`:
    `time_ease = clamp(elapsed/min_dur, 0, 1)`;
    `load_cap = warm ? 1.0 : min(0.9, 0.1 + 0.8*load_frac)`;
    returns `min(time_ease, load_cap)` — reflects real load %, paced by min time, and
    honestly **holds at ≤0.9 until the scene is warm** (so a slow load is visible, not faked).
  - `boot_ready(elapsed, min_dur, warm)`: `warm and elapsed >= min_dur`.
- Apply: fill width = `value * track_width`; label = `warm ? "Ready" : "Loading… %d%%"`.
- When `boot_ready`: `set_process(false)`, `phase("scene.swap")`,
  `SceneFade.to(self, get_tree(), MAP_PATH)`.

`MIN_DURATION ≈ 1.0 s` (tunable). The handoff reuses `SceneFade.to`: cream → near-black
cover → warm packed swap → `Map`'s own `fade_in`. The brief dark dip matches the existing
Board↔Map transition; the cover hides the Map instantiate hitch.

The splash-UI build is factored into a callable `_build_splash()` so the screenshot tool
can render a frozen splash without running the auto-handoff.

## Component 3 — `map.gd` instrumentation

Add `BootTrace.phase("map.<step>")` markers around the existing `_ready` build steps and
`BootTrace.done()` at the end of the synchronous `_ready`. Because `BootTrace` is only
`active()` during the cold boot (Boot calls `start()`), these calls **no-op on every later
Board→Map open** — no behavior change, no per-open overhead, nothing printed.

## Asset

`logo_tidyup.png` (512×384, an orange bubble-letter "Tidy Up" mark with a star) exists but
is unused concept art under `_concepts/tidyup/`. Copy it to
`games/grove/assets/ui/boot/logo_tidyup.png` (a stable runtime path; engine scenes already
reference grove asset paths) and run `make import` to generate the `.import`. Optionally
point the engine `boot_splash` at the same logo on `SCREEN_BG` so the pre-scene engine
splash hands off seamlessly into our cream splash.

## Testing

- **`engine/tests/boot_trace_tests.gd`** (new, added to `ENGINE_TESTS`, headless):
  - `BootTrace.format_table` — formatting on synthetic phase data (alignment, total, bar).
  - `BootTrace` sequencing — `start → phase → phase → done`: phase names/order recorded,
    durations ≥ 0, `active()` flips true→false, and `phase`/`done` are no-ops when inactive.
  - `boot.gd` pure helpers — `boot_bar` / `boot_ready` across cases: cold start (≈0),
    mid-load (cap ≤ 0.9), warm-but-early (held by min time), warm-and-late (1.0 + ready).
- `make test-fast` then `make test` stay green. Changing `main_scene` does not affect
  suites (they run specific scripts, never the main scene).
- **Visual:** `engine/tools/boot_splash_shot.gd` renders the splash to a PNG via
  `quiet_godot.sh` (born-minimized, no-focus — never steals window focus). Deliver the PNG
  for human review; I will not eyeball quality from code.

## Out of scope (YAGNI)

- Scene-transition loading covers (already handled by `SceneFade` + `SceneWarm`).
- An async preload gate / progress for arbitrary assets beyond the Map scene.
- Refactoring `Map._ready` into a coroutine to show its build phases live on screen
  (the log table covers that detail without the risk).

## Risks / notes

- `change_scene_to_packed` frees the old scene; the Boot splash is gone after handoff — the
  on-screen bar therefore tracks the **load**, while the **build** detail lands in the log
  table. This is the explicit, chosen trade-off.
- The log table covers up to the end of `Map._ready`; the first-frame GPU upload after that
  is not timed (not cheaply measurable from script). Noted, acceptable.
- `boot_splash` engine keys are optional polish; if they complicate import, drop them — the
  in-scene cream splash is the real loading screen.
