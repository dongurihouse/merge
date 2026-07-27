# Refactor review — de-duplication, guards, robustness

Scope: whole tree (runtime `engine/` + `games/`, build config, Makefile, tools, docs).
Method: five parallel read-only surveys. Full evidence in the finding notes below; every
file:line was read in context, not grepped.

House pattern this follows: `engine/tests/const_ssot_tests.gd` and
`engine/tests/palette_ssot_tests.gd`. Vocabulary:
- **DELETE** — a real de-dup; the copy goes away.
- **REMAIN+ASSERT** — a purity constraint worth more than the copy costs; the copy stays and a
  guard keeps it honest.
- An allowlist entry is a decision with a one-line reason, keyed `path@TOKEN` — never by line.

## STATUS (2026-07-26) — COMPLETE

**Every item in this spec has landed on `main`.** Full sweep green at each merge; final state
43 suites · 2558 passed · 0 failed (suite count includes concurrent non-review work).

- **Wave 1** 1.1–1.8 · **Wave 2** 2.1–2.8 · **Wave 3** 3.1–3.10 · **Wave 4** 4.1, 4.2 ·
  **Wave 5** 5.1–5.8.

Guard surface added: `const_ssot_tests` 15 → 28 assertions; new `feature_flag_registry_tests`
(the registry that failed *open*), new `save_migrate_tests` (90 assertions over the extracted
save hygiene); `suite_registry_tests` extended to `.py`/`.sh` and to `games/grove/tools/tests/`;
the palette scan widened to bare-hex strings; the asset size guard widened from one subtree to
all of `res://`.

Size: `board.gd` 4153 → 3958, `map.gd` 2611 → 2448, roughly 1500 lines net removed across the
review, two dead systems deleted.

**The pixel gate.** `engine/tools/board_montage.gd` — the before/after gate this spec's Wave 4
depends on — was found **dead**: it errored on a builder deleted in `cfee2439` (2026-06-25) and
then hung forever at 100% CPU, because a GDScript error kills `_initialize` but not the
`SceneTree`, so `quit()` is never reached. It had been producing nothing for a month while
looking like a working gate. Repaired under 5.8, and its content scale was disabled (it had been
resampling the sheet to 0.604, which hides exactly the sub-pixel differences it exists to catch).
Now byte-deterministic: sha256 `74864a84c12b8dd5…`, identical before and after both Wave 4 cuts.

Three items were **refused during implementation** and the refusals stand:

1. **1.1 (`inbox.gd` half).** Routing it through `Save.add_water` would have trimmed a banked
   over-cap can down to the cap, and over-cap is live (`shop.gd:581` free refill,
   `grove_data.gd:611`). The local `maxi` top-up is load-bearing. It now reads the can through
   `Save.water()` — the duplicated *default* is gone, the over-cap guard survives.
2. **2.3 (bundle id).** Porting `build_info.gd`'s preset parser would have **broken the shipped
   update check**: `export_presets.cfg` is not in the pack, and `update_check.check()` only runs
   on iOS, where the file is absent — the app would poll `lookup?bundleId=` empty forever.
   `build_info.gd` gets away with it only because a release also stamps a shipped
   `engine/generated/build_info.gd`. Took REMAIN+ASSERT instead.
3. **1.3 (`click_spot.gd`).** Not converted — it is dead for a larger reason (it errors on
   `map_nodes` and hangs, and every `spot_hits` entry now carries `k: -1`, so its `hit.k == 0`
   search can never match). Converting the seed would leave a dead tool looking fixed.
   **Owner's call: retire it, or rewrite it as a cluster-tap purchase test.**

### Still outstanding

Nothing from this spec. What follows is work the review *uncovered* but did not take on.

**Needs an owner decision**
- **The min-iOS-17 floor.** Its documented justification ("the app is iPad-only") was false —
  `targeted_device_family=2` ships to iPhone and iPad, so the floor excludes every iPhone below
  the XS/XR generation too. The real tradeoff: the Game Center + StoreKit plugin requires 17.0,
  so it is keep-the-plugin-and-accept-the-cut, or drop the floor and lose both. The docs now
  state this honestly; the setting is unchanged.
- **Four inert test functions** in `games/grove/tests/grove_test_base.gd` — `_test_residents`,
  `_test_resident_wiring`, `_test_2x_doubler_rehome`, `_test_t45_wiring`. No suite calls them.
  That is ~90 lines of scene-driving coverage (resident roster rendering, the 2× doubler, the
  piggy vault and daily-login wiring) that has been silently dead. Revive or delete.
- **The daily-card sparkle has no live render path.** `Kit.daily_card` — the only instantiator
  of `games/grove/sparkle.gd` — is reached now only from `games/tools/bake_targets.gd` and one
  unit test. The live calendar is `LoginUI.open`, which draws its own sparkles.

**Mechanism gaps worth closing**
- `engine/tests/layering_tests.gd` scans only `engine/scripts/`, so `engine/tools/*.gd` could
  preload `games/` and pass. That blind spot is what would have let a lazy fix through in 5.8.
- `shot_base.begin()` has no wall-clock watchdog. Any capture tool that errors mid-coroutine
  hangs forever at 100% CPU with no output and no non-zero exit — the exact failure that hid
  `board_montage`'s death for a month. A bound needs measuring across all 17 tools first.
- **Texture import quality is split** 549 at 0.9 / 425 at 0.88. Both lossy so the size guard
  passes, but a new asset dropped beside a 0.88 neighbour imports differently from its sheet.
- `map.gd`'s decorative kit guard is still decorative — now carrying a comment saying so, since
  closing it either way is a behaviour change rather than a de-duplication.

**Small, factual**
- `grove_shot.gd`'s `unlock` mode: `int(round(coins_at_level(2) * 0.67))` evaluates to `1`,
  i.e. exactly L2 at 0% progress, not the "~67%" its comment claims.
- `grove_shot.gd`'s `producing` mode seeds discovery codes `6101/6201/6301` (Farm lines 61–63),
  which are no longer in `G.LINES`, so seven of eight cells render as locked "?" wells.

### Discovered during implementation and FIXED here

- **`docs/design/mocks/weather_hours/*.png` were shipping.** `docs/` had no `.gdignore` and no
  `exclude_filter` entry, so the mocks entered the shipped texture set on any import. Surfaced by
  the widened asset guard (1.6) — the narrow walk could never have produced it. Closed with
  `docs/.gdignore` (nothing in the tree loads `res://docs`, so stopping the import outright beats
  an export filter that would still import them).
- **`merge_fx._color`** carried a bare `if tier >= 8` — a third live copy of `PREMIUM_TIER` the
  survey missed. Collapsed under 2.2.
- **`board.gd`'s two currency hex literals** now read `FX.reward_color(...)` (4.2).
- **`grove_shot.gd`'s Lv chip needed the seed moved earlier**, not just corrected: `board.gd`
  builds the HUD level chip once and `_update_hud` only re-ticks the wallet, so a correct coin
  seed applied in the mode branch still rendered Lv 1.
- **`_spawn_bonus_gen` / `_spawn_treat_gen` could not be merged naively.** The bonus path draws
  `pick_bonus_kind(rng)` *before* the free-cell search; the treat path draws nothing. Since the
  rng is seeded and persisted, collapsing them the obvious way would have been a silent
  save-compat break. The kind draw stays at the call site and the click budget is a `Callable`.
- **The real fixture count was 45, not 42** (3.6), and the real kit-handle counts were 25
  declarations / 60 load sites / **five** divergent guard styles, not 3 (3.10).
- **`suite_registry_tests` was right and I was wrong** about the new save-migration suite: it
  failed with exactly one assertion until the suite was wired into `ENGINE_TESTS`.

Owner decisions taken 2026-07-26:
- Board gate grid: **keep the shipped L16 board.** No pacing change. `grove_data.gd` re-syncs to
  the JSON and is demoted to the absent-file fallback.
- Extra extractions (`ui_kit` image math → engine; `map.gd` gallery cards → `ui/map_card.gd`):
  **not taken.**

---

## Wave 1 — live defects

### 1.1 `login.gd:205` — water gift destroys an implicit full can
`water` is a lazily created grove key. Every read defaults it to `WATER_CAP` (`save.gd:505`,
`board.gd:842`, `hud.gd:142`/`:238`, `content.gd:1682`, `debug.gd:336`) except two, which default
to `0` and write the result back as an absolute value.

Change: route `engine/scripts/core/login.gd:203-205` `_grant_water` and
`engine/scripts/core/inbox.gd:247` through `Save.add_water(n)` (`save.gd:512`), which reads via
`Save.water()` and clamps. Removes the duplicated default rather than correcting it.

Accept: a new case in `engine/tests/save_tests.gd` — on a grove dict with no `water` key, granting
N leaves `Save.water() == WATER_CAP` (not `N`). Must fail before the change.

### 1.2 `store.gd:53-60` — a dropped StoreKit signal bricks IAP for the process
`_pending_id`/`_pending_cb` clear only in `_settle()`, reached only from the two native signal
handlers. No timeout. `purchase_wait.gd:16` has `WAIT_TIMEOUT_SECS := 12.0`, so the sheet recovers
and the state machine does not; every later Confirm returns `on_done(false)` immediately.

Change: stamp `_pending_at` on entry to `purchase()`. In the `_pending_id != ""` guard, treat a
pending older than `PENDING_STALE_SECS` (15.0, > the sheet's 12.0) as abandoned — `_settle(false)`,
then proceed with the new purchase. `push_warning` naming the abandoned product id.

Accept: `engine/tests/store_tests.gd` — with a stub that never fires the completion signal, a
second `purchase()` after the stale window reaches `request_products` rather than returning false.

### 1.3 Screenshot tools seed the retired exp clock
The level clock moved to coins (`save.gd:15` SCHEMA v5; `content.gd:1577-1582`
`level() = level_at_coins(...)`). `grove["exp"]` / `Save.add_exp` feed no level at HEAD, so every
"leveled" capture renders Level 1 at exit 0.

Sites: `games/grove/tools/grove_shot.gd:94-97`, `:116`, `:165-168`, `:175-177`, `:257`;
`games/grove/tools/map_shot.gd:68-69`, `:122`, `:134`; `games/grove/tools/click_spot.gd:24`.

Change: seed `gpr["coins_earned"] = G.coins_at_level(N)` — the pattern the same file already uses
correctly at `grove_shot.gd:158`, `:207`, `:220`, `:511`. `map_shot.gd:134`'s `G.spot_unlock_exp(...)`
→ `G.coins_at_level(G.cluster_min_level(...))`, or delete with the dead spot ladder.
Delete the stale arithmetic in the `:257` comment (`exp_at_level 6 = 230`; the JSON override makes
it 90).

Accept: run each affected capture mode and **look at the PNG** — the Lv chip must show the intended
level, and `level`/`levelup` must show a non-zero progress fraction. A green exit is not evidence.

### 1.4 `make test-one` bypasses the runner's verification
`Makefile:96` trusts a raw exit code. `run_suites.py:12-35` documents that a suite passes only on
`== N passed, M failed ==` with `M==0`, exit 0, **and** no logged `SCRIPT ERROR`, plus a 120s hang
guard — because an uncaught `SCRIPT ERROR` mid-`_initialize()` aborts without reaching `quit()`.
`README.md:29` advertises this target for debugging.

Change: `test-one: @python3 $(RUNNER) $(SUITE)`. `run_suites.py` already accepts a single suite.

Accept: point `test-one` at a suite with a deliberately introduced `SCRIPT ERROR`; it must fail.

### 1.5 Unwired Python suites
`games/grove/tests/bake_scene_composites_tests.py` and
`games/grove/tools/tests/test_extract_meadow_ui_v2.py` are referenced by no target and never run.

Change: add both to `PY_TESTS` (`Makefile:26`). Fix whatever they surface, or record a one-line
reason if a failure is a stale expectation rather than a defect.

### 1.6 `icon_small.png` ships lossless and the guard cannot see it
`icon_small.png.import:24` `compress/mode=0`. It is `project.godot:18 config/icon`, and
`export_presets.cfg:10 exclude_filter` excludes literal `icon.png` but not `icon_small.png`.
`asset_size_guard_tests.gd:2` claims "no shipped texture is stored LOSSLESS"; `:17` scopes the walk
to `res://games/grove/assets`, so the claim is false and `LOSSLESS_ALLOWLIST` is empty on a lie.

Change: widen the walk to `res://` minus the excluded prefixes (the suite already parses the real
`exclude_filter` at `:32-57` — reuse it). Then either compress `icon_small.png` or add it to
`LOSSLESS_ALLOWLIST` with a one-line reason.

Accept: the widened scan must find `icon_small.png` **before** the fix (known-positive), and pass
after. A guard that reports zero findings is broken until proven otherwise.

### 1.7 `Bucket._credit_line` has no `_:` arm over a duplicated line list
`bucket.gd:155-166`. Exhaustive today (`RB.LINES` is exactly the four arms), but `RB.collect`
debits the bank **before** `_credit_line` runs and the returned `got` drives the fly-to-wallet FX
regardless. A fifth line means the player watches "+N" arc into their wallet while the balance does
not move, the bank is emptied, and nothing is logged.

Change: add `_: push_error("Bucket._credit_line: no grant path for line \"%s\" (%d units LOST)")`.

### 1.8 `board_model.gd:410 take()` lacks the bounds guard its neighbours have
`item_at:52`, `collect_reward_at:411` and `set_collect_reward:419` all guard with `in_bounds`.
Unreachable at HEAD (callers are guarded upstream). One line to close the class.

---

## Wave 2 — guards

Grow `engine/tests/const_ssot_tests.gd` in its existing shape (numbered section, one-line reason,
keyed allowlist).

### 2.1 Board gate grid — the divergence that is live today
`grove_data.gd:82` const says corners L22; `games/grove/economy_tuning.json:6` says L16; the JSON
wins (`content.gd:24` seeds from the const, `_static_init()` → `apply_tuning()` at `:146-148`
overwrites). Verified headless: `cell_min_level(0,0)` = 16.

Owner decision: **the shipped L16 board stays.**

Change:
1. Re-sync `grove_data.MIN_LEVEL` to the JSON's values.
2. Rewrite its comment. Delete the L22 story, delete the claim "THIS GRID IS THE OWNER'S FEEL DIAL
   — re-tune it" (it is not read when the JSON exists), and delete the stated scene windows
   (`L1-7 · L8-19 · L20-37 · L38-61 · L62-87`) — `SCENE_END_LEVEL := [28, 41, 54, 64, 71]` makes
   the real windows S1 L1-28, S2 L29-41, S3 L42-54, S4 L55-64, S5 L65-71, so the const's claim that
   the corners "open near the START of Desert Oasis" is wrong twice over. Both grids finish opening
   the board inside scene 1. Demote to "absent-JSON fallback", the wording `LEVEL_BASE_EXP`
   (`grove_data.gd:534`) already uses correctly.
3. `_coerce_grid` (`content.gd:152-165`) silently returns `[]` on a mis-shaped grid → the key is
   skipped → the board falls back to the const with no signal. Make it `push_error` naming the
   expected `ROWS × COLS` and the shape it got.

Guard (REMAIN+ASSERT — the const is the seed and the absent-file fallback, so it cannot be deleted):
`Content.MIN_LEVEL == G.MIN_LEVEL`, plus the JSON's `ROWS × COLS` shape, plus a known-positive
proving the check can see the grid at all.

`docs/economy_tuning.html:110 GRID0` is a third copy and generates the JSON via `scaledGrid()`.
Re-sync it and note it in the guard's comment; a check that pairs only the const and the JSON leaves
the tool free to drift.

### 2.2 Pinnacle tier — `ESCALATE_TIER` restates `PREMIUM_TIER`
`tuning.gd:277 ESCALATE_TIER := 8` and `:295 MERGE_BURST_HOT_TIER := 8` both restate
`grove_data.gd:11 PREMIUM_TIER := 8`. `merge_fx.gd:82` states the intent in code. `ESCALATE_TIER`
gates the whole reserved big-moment vocabulary (`feel.gd:34`, `:74`, `:84`, `:411`;
`merge_fx.gd:87`, `:152`). Move `PREMIUM_TIER` to 9 and every cue keeps firing at 8 — the juice
reserved for the pinnacle fires on an ordinary merge, and the real pinnacle feels identical to the
one below it. No test fails.

- `MERGE_BURST_HOT_TIER` is a second copy of `ESCALATE_TIER` 18 lines away in the same file →
  **DELETE**.
- `ESCALATE_TIER` **REMAINS**: `tuning.gd` preloads nothing on purpose and declares itself the
  engine's game-independent defaults; reading `Game.DATA` would make it game-dependent — the same
  trade `resident_bucket.gd` refused. Assert `Tune.FX.ESCALATE_TIER == G.PREMIUM_TIER`.

### 2.3 Bundle id — third hand-typed copy
`export_presets.cfg:37` (owner) · `tools/asc_lib.sh:15` (fails loudly — self-announcing) ·
`engine/scripts/core/update_check.gd:18` (silent). On a rebrand the shipped app polls
`itunes.apple.com/lookup?bundleId=<old>` forever; the update prompt never fires again.

Change: `update_check.gd` reads the preset the way its sibling `build_info.gd` already does
(`const_ssot_tests.gd:144-166` asserts exactly this for the marketing version). Assert the agreement.

### 2.4 App display name
`project.godot:13` and `export_presets.cfg:267` both spell `"Acorn Forest: Merge!"`. Godot's iOS
`application/name` falls back to `config/name` when blank. Rename in `project.godot` and the iOS
home-screen label stays stale — visible only at export.

Change: blank `application/name` so Godot inherits, or assert the equality beside the splash
assertions in `tools/test_boot_splash_assets.py`.

### 2.5 Feature-flag id scan — the registry that fails OPEN
`features.gd:58-62` `Features.on()` returns **`true`** for an unknown flag with only a
`push_warning`. 30 ids; every consumer re-types the string (`board.gd:441`, `:456`, `:532`;
`hand_hint.gd:54`; `explore_rush.gd:945`, `:985`; `feel.gd:34`, `:74`, `:84`; +25 more). Rename a
flag and every stale call site returns `true` for the product's life; the owner then flips the bool
OFF and the feature stays ON.

Change: a new scan modelled line-for-line on `strings_tests.gd:27-39` (which already does exactly
this for the other string-key registry). Keyed `path@flag_id`. Pair with the reverse check — a flag
in `FLAGS` that no call site names is dead; `features.gd:51-52` already carries commented tombstones,
so that half is a real recurring cost.

Land in **reporting mode** first if the initial scan finds pre-existing offenders: print them, pass,
gated on one `FAIL_ON_UNKNOWN_FLAG` constant. Validate against a known-positive (one real flag id
and one invented one) before trusting a zero result.

### 2.6 Palette guard — bare hex strings evade the scanner
`palette_ssot_tests.gd` matches `Color("#RRGGBB")` and therefore misses the same values in string
form:
- `ui_kit.gd:4993` `const PROGRESS_FILL_HEX := "5F9B6D"` — the trailing comment literally says
  `# Pal.LEAF`
- `ui_kit.gd:2587` `Color.from_string("#" + d.get("tint", "F6EBDD"), MAIL_TINT_DEFAULT)`
- `ui_kit.gd:5694` `Color.from_string("#" + b.get("frame_tint", "3F6D7D"), Pal.BARK)`
- `ui_workbench_view.gd:222` `"frame_tint": "3F6D7D"` · `:336` `"tint": "F6EBDD"`

The two `Color.from_string` sites spell the same colour **twice on one line** — a re-typed hex
default and a `Pal.*` fallback argument. That is the pattern the suite's own docstring calls out
(`giver_stand.gd`), in a form its regex misses.

Change: widen the scan to bare 6-hex string literals, using the existing keyed-allowlist mechanism
for genuine one-offs. Fix the five sites (`Pal.LEAF.to_html(false)`, or read the fallback off `Pal`).

### 2.7 Suite registry — extend to `.py`/`.sh`
`suite_registry_tests.gd:14` scans three dirs, `:24` only `*.gd`. A `.py` suite in a scanned dir is
invisible, and `games/grove/tools/tests/` is not scanned at all — which is how 1.5 happened.
Its own docstring (`:5-9`) states the failure: "its absence looks exactly like success."

Change: scan `*_tests.py` / `test_*.py` tree-wide against `PY_TESTS`, add `games/grove/tools/tests/`
to the roots. Note `games/tools/test_intake_apply.py` and `tools/sfx_synth/test_synth.py` run only
under their own targets — either fold them into `make test` or allowlist with a reason.

### 2.8 Suite list vs the docs
`suite_registry_tests.gd:31-48` compares the Makefile to **disk only**; it never reads `README.md`
or `CLAUDE.md`. `CLAUDE.md:39` says "keep this line in step with it" — which `const_ssot_tests.gd:7-8`
itself names as *not a mechanism*: "A comment saying 'keep these in step' is not a mechanism — it is
a promise, and promises drift." They agree today by luck; `suite_registry_tests.gd:11-12` records
README having previously advertised five grove suites that no longer existed.

Change: assert the `GROVE_TESTS` set (order-insensitive) appears in both docs.

---

## Wave 3 — de-duplication

### 3.1 Eight board-layout constants mirrored into the workbench
`ui_workbench_view.gd:745-755`, comment "The board's own layout law, mirrored so the preview shows
what the board WILL render (board wins)". `:797-804` then recomputes board's real clamp arithmetic
— `board.gd:2008`'s expression with the mirrored names substituted. Retune `BOTTOM_BAR_MAX` and the
workbench keeps drawing the old clamp; the operator drags a slider to a value the preview accepts
and the board silently clamps away.

This is verbatim the hazard `const_ssot_tests.gd:11-13` records for `PHONE_W`/`PHONE_H` — same file,
eight more numbers.

| value | current sites | new owner |
|---|---|---|
| 166.0 `BOTTOM_BAR_H` | `board.gd:73`, `action_bar.gd:24`, `ui_workbench_view.gd:747` | `action_bar.gd` |
| 130.0 `BOTTOM_BTN_PX` | `board.gd:74`, `:2072` (default arg), `ui_workbench_view.gd:748` | `action_bar.gd` |
| 150.0 `BOTTOM_BAR_MIN` | `board.gd:68`, `:749` | `action_bar.gd` |
| 200.0 `BOTTOM_BAR_MAX` | `board.gd:69`, `:750` | `action_bar.gd` |
| 110.0 `BOTTOM_BTN_MIN` | `board.gd:70`, `:751` | `action_bar.gd` |
| 150.0 `QUEST_H_MIN` | `board.gd:66`, `:752` | `board_fit.gd` |
| 300.0 `QUEST_H_MAX` | `board.gd:67`, `:753` | `board_fit.gd` |
| 16.0 `EDGE_GAP` | `board.gd:84`, `:754` | `board_fit.gd` |

**DELETE** all eight workbench copies. `action_bar.gd` owns the bar band because it *builds* the bar,
already holds one copy, and sits in `ui/` — which both `scenes/board.gd` and game tools may import,
while `ui/` may not import `scenes/` (`layering_tests.gd`), so the arrow must point this way. Both
call sites already preload `ActionBar` (`board.gd:45`, `ui_workbench_view.gd:15`) — zero new imports.

Also: `board.gd:2072`'s `px: float = 130.0` is a re-typed `BOTTOM_BTN_PX` 2000 lines from its own
const; the sole caller (`:1883`) always passes a value, so the default is unreachable — delete it.

Keep `HUD_UNLOCK_BAR_H := 108.0` (`:755`) — it is declared "a representative" height, not a mirror.
Allowlist it with that reason.

Then assert the identities directly (the bag-band shape in `const_ssot_tests`), not a literal scan —
a scan for `166.0` is over-fitted.

### 3.2 Quest-band default — three spellings, two numbers
`board.gd:2027` `var frac := 0.13` · `ui_kit.gd:5154` `h.get("quest_bar_h_pct", 11.0)` → 0.11 ·
`ui_workbench_view.gd:804` `layout.get("quest_bar_h_frac", 0.13)` (dead — the key is always
populated). Dormant only because `ui_kit_settings.json` ships `"quest_bar_h_pct": 10.0`.

Change: `ui_kit.gd`'s resolver is the owner; board and workbench read it unconditionally. **DELETE**
both private fallbacks. Fold the currently-agreeing siblings into the same change: `button_w_frac`
(`board.gd:2062` 0.15 / `ui_kit.gd:5150` 15.0), `edge_margin_px` (`ui_kit.gd:5155`, `:6291`, `:6330`;
`hud.gd:40`, `:103`; `ui_workbench_view.gd:774`, `:777`, `:778`).

### 3.3 `_celebrate` ×3 + the reward colour table ×5
`login.gd:653-661` (canonical) · `inbox.gd:137-146` (**byte-identical**) · `login_mystery.gd:314-321`
(identical minus a leading `Audio.play`). The comments admit it.
`Color("#A9C7E8")` in 5 files, `Color("#9CCDE8")` in 4 — `login.gd:657`, `:661`; `inbox.gd:141`,
`:145`; `login_mystery.gd:317`, `:321`; `vault.gd:150`; `fx_workbench_view.gd:598`, `:636`, `:638`
(a 4th independent icon→colour switch).

Change: `engine/scripts/ui/fx.gd` gains
`static func celebrate_rewards(host, at, rew, with_sound := true)` and
`static func reward_color(icon_id) -> Color`. ~22 lines + 9 hex literals → one table.

### 3.4 Three bypassed `ActionBar` helpers
`ui_workbench_view.gd` already calls `ActionBar.bar_style`/`well_gap`/`content_host`/`info_tray`
(`:829`, `:886`, `:887`, `:924`) and then hand-copies three more:
`_action_bar_nudge:831-845` ≡ `ActionBar.offset_slot:134-151` (original adds a null guard) ·
`_action_bar_clear_button_frame:847-850` ≡ `ActionBar.clear_button_frame:158-161` (byte-identical) ·
`_action_bar_transparent_info_frame:852-861` ≡ `ActionBar.info_bar_frame:163-172` (byte-identical,
param renamed). Pure deletion, ~30 lines. This workbench *is* the tuning surface for the shipped bar.

### 3.5 `_gd_files_deep` ×3 — the guards' own coverage function
`layering_tests.gd:38-48`, `palette_ssot_tests.gd:49-59`, `const_ssot_tests.gd:170-180` — byte-identical.
`strings_tests.gd:55-71` is an older implementation of the same walk **plus a dotfile skip the other
three lack**, so they already disagree about what "every .gd file" means. Four file-slurp helpers too
(`const_ssot_tests.gd:182-188`, `layering_tests.gd:51-58`, `build_info_tests.gd:7`,
`slice_islands_tests.gd:134`).

Change: `engine/tests/test_base.gd` gains `gd_files(dir, deep := true)` and `read_text(path)`.
Decide the dotfile question explicitly and document it — a walker that quietly misses a directory
makes every guard report green over unscanned code.

Accept: after the change, each guard must still find its own known-positive.

### 3.6 Test scene-host fixture — 42 mount sites, 29 teardown pairs
Same shape: load scene, add under root, re-run `_ready()` if headless construction skipped it, later
`queue_free` + drain a frame. `grove_explore_tests.gd` ×23 · `grove_shop_tests.gd` ×8 ·
`grove_test_base.gd` ×6 · `mechanics_tests.gd` ×3 · `grove_ftue_tests.gd:44` ·
`grove_rush_ftue_tests.gd:24`.

Drift has started: `grove_shop_tests.gd:474`, `:497` carry a different guard than their 40 siblings.

Change: awaitable `mount(path, ready_probe)` / `drop(n)` on `engine/tests/test_base.gd` (Board/Map/
Rush are engine scenes, so `mechanics_tests` gets them too), with `map_host()`/`board_host()`/
`rush_host()` wrappers in `grove_test_base.gd`. ~140 lines.

Do this **after** the rest of Wave 3 lands, so it rebases onto stable suites.

### 3.7 Byte-identical pairs
- `_cell_style` — `board.gd:2559-2570` ≡ `action_bar.gd:202-213`. The action_bar copy explains
  itself: `layering_tests.gd` forbids `ui/ → scenes/`. But every constant is already in
  `tuning.gd UiSkin` and `ui/skin.gd` is legal for both → `Look.empty_cell_style()`. Keep a one-line
  `board._cell_style` if `grove_shop_tests` reaches it by name.
- `_spirit_tex` `residents.gd:828-844` ≡ `_resident_content_tex` `map.gd:1931-1946`. They cache the
  **same** art paths in two dicts — decode + `get_used_rect` runs twice, textures held twice →
  `piece_view.gd` `static func trimmed_tex(path)`.
- `_soft_silhouette` `prop_shadow.gd:36-52` / `sprite_shadow.gd:55-77` — first 12 lines identical,
  including the hard-won "cache the null so a headless dummy renderer never retries per frame" →
  `_soft_silhouette(tex, div, whiten)`, one shared cache. `prop_shadow`'s rid-only cache key is a
  latent collision once `SOFT_DIV` becomes configurable; key on rid+div.
- `gen_sparkle.gd` (57 L) / `games/grove/sparkle.gd` (52 L) — near line-for-line. gen_sparkle's
  header says "engine may not import a game script": true, but `games/ → engine/` **is** legal, so
  the game one `extends` the engine one. Only `_BASE` (7 vs 9), the phase step (0.41 vs 0.37) and
  the size base (`5.0 + 2.5i` vs `6.0 + 3.5i`) need overriding.

### 3.8 Dead systems — delete
- **`games/tools/button_shadow_tool/` (311 lines + a .tscn).** A second shadow-tuning system with
  the same knob names but an incompatible model (`button_preview.gd:44-67` hand-paints a multi-layer
  ramp; `Look.shadow` is a single `StyleBoxFlat` cast) plus a `warmth` knob no other surface has.
  `skin.gd:507-536` states the invariant: "ONE model drives every component (the workbench Shadow
  item is its only tuning surface)". Nothing outside its own directory references it; no Makefile
  target; its `verify_*.gd` doesn't end in `_tests.gd` so `suite_registry_tests.gd` never notices.
- **The FX workbench's dead half (~200 lines).** `fx_gallery_view.gd` (907 L) superseded
  `fx_workbench_view.gd` (712 L) but keeps it as an embedded preview (`:746-753`, `embedded = true`).
  Nothing instantiates it with `embedded == false`, so the standalone chrome is dead **and**
  duplicates the live sidebar (`_slider_row` vs `_fx_slider_row`, `_action_option` vs `_fx_action_row`
  are near line-for-line). Keep it as the embedded Coin-Flow preview only; lift `FX_DEFS` into
  `games/grove/tools/fx_defs.gd` so the gallery stops reaching into a view class for a table.
  While there: `fx_gallery_view.gd:640-672` string-dispatches onto the preview's *private* methods
  (`preview.call("_set_global_setting", …)`) — make those public on the component.
  Verify reachability before deleting; do not trust the `embedded` flag alone.
- **`board.gd:106-107`.** `SHADE_LIT` and `SHADE_DIM` are **both** `Color(1,1,1,1.0)`; their only
  use is `:1502` `chip.modulate = SHADE_LIT if lit else SHADE_DIM` — a ternary that cannot change
  anything. Delete both, the no-op branch, and the stale 4-line comment describing a "~0.78 alpha"
  dim value that no longer exists. Keep `GEN_LIT := SHADE_LIT` (`:114`), which is live at `:1601` —
  re-point it at a literal or `Color.WHITE`.

### 3.9 Internal duplication in the big files
`board.gd`:
- `_drop_coin_near:3290-3313` vs `_drop_special_near:3348-3370` — ~20 identical lines (same
  `pick_drop_cell`, `_make_piece`/`_cell_pos`/`scale 0.3`, same parallel tween durations and easings,
  same `LandFx.apply` + `Feel.ripple` chain). The comment at `:3364` says "Mirrors `_drop_coin_near`".
  One function; the only real difference is the coin default.
- `_has_bonus_gen:3511-3518` / `_has_treat_gen:3539-3547` → `_board_has_gen(pred: Callable)`.
- `_spawn_bonus_gen:3521-3536` / `_spawn_treat_gen:3549-3563` → `_spawn_gen_on_free_cell(...)`.
- `_on_refill:1148-1152` and `:1158-1162` — the same 5-line block verbatim twice, 10 lines apart, in
  the same function.
- `_animate_unlock_bar_from:1367-1377` should call `_update_unlock_bar:1359-1365` then tween.

`map.gd`:
- `_on_map_input:1409-1415` ≡ `_on_select_input:1498-1503` (verbatim 6-line press/release/moved
  classification); `_on_maps_input:1001-1003` is a third variant → one `static _classify(event)`.
  Three copies of touch-vs-mouse handling is a correctness hazard, not just noise.

`ui_kit.gd`:
- `_card_grid:4387-4427` vs `_shop_sections:4614-4653` — ~30 near-identical lines; `_shop_sections`
  **is** `_card_grid` plus a divider per section → `_card_rows(...)` + a shared `_fit_cards`.
- `toggle_card:2188-2197` vs `info_card:2648-2657` — the 9-line `name_l` Label block is
  byte-identical → `_row_name_label(text, font)`.
- ~37 Label construction sites: 32× `add_theme_constant_override("outline_size", 0)`, 14×
  `add_theme_color_override("font_color", Pal.INK)`, always in a 4–8 line run after `Label.new()`.
  `_bar_label:1230` already has this shape but serves only `rush_bar` → `_kit_label(...)`, ~150 lines.

### 3.10 `Game.kit()` boilerplate — do last
`static var KIT_PATH := Game.kit()` in 25 files, then 51 `load(KIT_PATH)` and 74
`Kit.load_config(Kit.CONFIG_PATH)`. Guards diverged three ways: `if Kit == null: return`
(`map.gd:1697`, `:1888`, `:2052`, `:2072`), inline ternary (`:645`, `:1028`, `:1266`), none at all
(most). `map.gd:645-646` guards line 645 then calls `Kit.map_select_layout(...)` unguarded on 646 —
the guard is already decorative.

Change: `game.gd` gains `static func kit_script() -> GDScript` (cached) and
`static func kit_config() -> Dictionary`. Wide blast radius, mechanical; the SSOT win is bigger than
the line win. Land alone, after everything else.

---

## Wave 4 — decomposition (two cuts, everything else refused)

Prior art `docs/design/board_decomposition.md`: Waves 1–2 shipped (`core/quests.gd`,
`ui/piece_view.gd`, `ui/bust.gd`, `ui/giver_stand.gd`, the `_after_board_change()` fan-out with 26
call sites). **Wave 3 never landed and is now partly obsolete** — `board.gd` grew +65% to 4083 lines;
the merchant subsystem was deleted (`df18c895`); the bag became `ui/bag_overlay.gd`; `burst_chip` was
absorbed into a new 429-line info-bar cluster that is now the worst-coupled region in the file
(31 member vars). Do not resume Wave 3 as written. Its architecture decision — coordinator owns
mutable state *and all transactions*; components are views that emit intents — still holds and is
not re-litigated here.

Method for scoring a seam: list the member variables and globals every function in the cluster
references. Only preloads + own arguments = a clean cut.

### 4.1 `map.gd` L1931–2070 + `_force_ignore:598-605`, `_dock_chip_button:1241-1263`,
`_line_icon:1369-1384` → `engine/scripts/ui/resident_view.gd` (~190 L)

Eleven functions, **zero member variables across all of them**. Complete external dependency set:
`G.resident_art`, `FocusRing`, `Look`, the local `DOCK_INK`/`DOCK_PARCH` consts, and a `Kit` handle
that `_spirit_cell` and `_empty_cell` already take as a *parameter* — the seam is half-drawn.
39 internal call sites, all mechanical. **Zero external callers**, so unlike Wave 2 no thin wrappers
are needed. `_resident_content_tex` is already `static` and owns its own cache.

Detail: `_focus_ring_opts` reads `KIT_PATH` (a `static var` on `map.gd`) — pass the `Kit` handle in,
matching `_spirit_cell`.

Do this cut **first**: it is the lowest-risk decomposition available and re-establishes the pattern.

Accept: `engine/tools/board_montage.gd`-style pixel diff, not an eyeball. Note board_montage's own
determinism caveat in 5.x before relying on it.

### 4.2 `board.gd` L697–823, L878–929, L4070–4084 → `core/` (~194 L)

Save sanitize + above-level purge + discovery-log/ladder entries. Every function references only
preloaded pure modules (`G`, `Save`, `Quests`, `Strings`, `BoardModel`) and its own arguments; not
one touches a node, a Control, `csz`, a node dict, or an FX opts bundle.

| function | lines | touches |
|---|---|---|
| `_sanitize_saved_item_bag` | 697–707 | `G` |
| `_quest_items_are_known` | 708–718 | `G` |
| `_sanitize_saved_quests` | 719–732 | `G` |
| `_sanitize_seen` | 733–757 | `G` |
| `_quest_line_gated_out` | 758–773 | `G` |
| `_purge_above_level_content` | 774–823 | `G`, `BoardModel`; mutates `board`/`bag`/`quests` → `(board, bag, quests, lvl) -> Dictionary` |
| `_mark_seen` | 878–886 | `G`, `Save` |
| `_ladder_entries` | 887–893 | already a one-line delegation |
| `_gen_line_entries` | 894–921 | `G`, `Save` |
| `_lowest_seen_code` | 922–929 | `G` |
| `_ladder_header` | 4070–4078 | `G`, `Strings` |
| `_ladder_line_name` | 4079–4084 | `G` |

Destination: the discovery-log half → `core/quests.gd` (already owns `ladder_entries`); the
sanitizers → `core/board_logic.gd` or a new `core/save_migrate.gd`.

**Wrapper caveat:** `grove_explore_tests.gd:538` calls `scn._purge_above_level_content()` directly —
keep a one-line instance wrapper, per the Wave-2 realization note in the prior-art doc.

Payoff is testability, not line count: this is the code most likely to silently eat a player's save,
and it is currently reachable only by booting a whole `Control` scene. Add direct headless coverage
once extracted.

### Refused, on the record
- **`ui_kit.gd` (6448 L) is not a defect.** 178 static functions, **zero instance state**; the only
  mutable state is 13 caches each owned by one function family. Nothing preloads it — every consumer
  resolves it once through `Game.kit()`, so splitting means every consumer holds N handles or ui_kit
  becomes 178 forwarding statics. And `engine/` cannot preload `games/`
  (`layering_tests.gd FAIL_ON_GAMES_REFS := true`), so 200 call sites across 30 files reach it
  through the injected handle by necessity. Splitting the 51 config readers (~1005 L) is the most
  tempting cut and the wrongest — they are the most externally-called part of the kit.
- **`ui_workbench_view.gd` (2074 L)** — dev-only; `export_presets.cfg:10` excludes
  `games/grove/tools/**` from every export. Its generic machinery is already in the
  `workbench_view.gd` base class; what remains is per-element data, and the dup scanner found zero
  repeated 6-line blocks. Honest criticism worth recording and not acting on: `_default_params`
  (30 arms), `_make_element` (25) and `_element_sidebar` (25) are a parallel switch on the same ids
  ~1000 lines apart, and the last two don't order their arms consistently. The correct fix is a
  per-element spec table — a redesign of a working dev tool that never ships. Minimal step if it ever
  hurts: reorder the two `match` statements to match `IDS`.
- **`board.gd`** info bar/selection (429 L, **31 members**), spawn/economy (664 L, 25 — and the RNG
  call order is load-bearing and *persisted*, so any reshuffle risks a silent save-compat break),
  fence (354 L, 15), drag/input (308 L, 24 — the drag gesture *is* coordinator state), HUD/water
  (177 L, 20), geometry (147 L, 16). All controller glue.
- **`board.gd` unlock-bar glue** (79 L, only 2 members — narrow enough to tempt): `ui/unlock_bar.gd`
  (221 L) already exists; these 79 lines are the thin mount+refresh glue that belongs in a
  coordinator. Fix the duplication inside it (3.9) and stop.
- **`map.gd`** hand/dock picker (481 L) + orb drag (218 L) — look narrow (6 and 11 members) but
  **share** `_hand_orbs`/`_placed_orbs`/`_sel_orb`/`_cells_grid`: one ~700-line stateful drag system.
  Chrome/rail (423 L, 23 members) — widest constructor in the file. Note the good sign:
  `_swipe_commit_dir` and `map_rect_for` were already pulled out as pure statics — keep doing that
  incrementally instead of a wave.
- Both extra cuts offered to the owner (`ui_kit` image math → `engine/scripts/ui/image_polish.gd`;
  `map.gd` gallery cards → `ui/map_card.gd`) were **declined** 2026-07-26.

---

## Wave 5 — config and documentation

Every item below is a claim that is **false today**, not merely terse.

### 5.1 `README.md:39-47` "Layout" table describes a tree that does not exist
- `scripts/` — no such directory (`engine/scripts/{core,ui,scenes}/`, `games/grove/`).
- "`board.gd` is the pure, verified rules engine (no UI deps)" — **false**. The only `board.gd` is
  `engine/scripts/scenes/board.gd`, the live scene script. The pure engine is `core/board_logic.gd`
  + `board_model.gd` + `board_actions.gd`. An agent told this edits the scene script.
- `grove.gd` / `home.gd` — neither exists anywhere.
- `scenes/Home.tscn`, `Grove.tscn`, `Room.tscn`, `Menu.tscn` — none exist (real:
  `engine/scenes/{Boot,Board,Map,ExploreRush}.tscn`), and "Home.tscn (main scene)" contradicts
  `README.md:18` five lines earlier.
- Root `assets/` — no such directory.
- `build/` "gitignored" — `build/ios/ci_scripts/ci_post_clone.sh` is deliberately tracked
  (`.gitignore:5-8`).

Change: regenerate from the real tree, or reduce to the dirs that are actually stable.

### 5.2 `docs/design/grove_spec.md:601`
The same false code map with more detail, plus `districts.gd`/`levels.gd`/`jobs.gd`/`room.gd`/
`main.gd` (none exist), a **third stale bundle id** `com.dongurihouse.dongurimerge`, and a suite list
(`core_tests`, `grove_tests`, `layout_tests`, `map_tests`) of which none exist.

### 5.3 "iPad-only" is false in three places and justifies a config choice
`apple-services-setup.md:27`, `:37` ("the preset's `min_ios_version` is bumped to 17.0 (the app is
iPad-only). Devices below iOS 17 can no longer install"), `tools/install_ios_plugins.sh:15`.
Reality: `export_presets.cfg:260 targeted_device_family=2` is **iPhone & iPad** in Godot's enum
(emits `TARGETED_DEVICE_FAMILY = "1,2"`). Corroborated by `appstore_screenshots/` holding an iPhone
set at root *and* an `ipad/` subdir, and `appstore/*_1179x2556.png` being an iPhone 15 Pro frame.

The min-iOS-17 decision is documented as costing nothing because "iPad-only". It drops every iPhone
below iOS 17 too. Correct the claim; **do not** change the setting — flag the re-priced tradeoff to
the owner.

### 5.4 `keeping-the-build-small.md:23` inverts a `.gdignore` path — scratch art ships
Says `map/*/shared`. On disk the `.gdignore` files are at
`games/grove/assets/map/shared/{backdrop,foreground,coverup,primary}/` — i.e. **`map/shared/*`**.
The doc's own rule #3 is "keep working art out of the shipped tree — put it under one of these";
following the stated path creates `map/<zone>/shared/`, which is neither `.gdignore`d nor in
`exclude_filter`, **so it ships**. (`map/*/reference` on the next line is correct.)

### 5.5 `.gitignore` phantom references
`:1` points at `docs/iOS_BUILD.md` — no such file (real: `docs/design/apple-services-setup.md`,
`keeping-the-build-small.md`). `:41-42` documents `make run_base` / `make run_grove` — **neither
target exists** (real: `run`, `g`, `debug`; `g` and `debug` both `rm -f
games/grove/assets/.gdignore`, and nothing in the repo creates it). `:46` still ignores
`games/placeholder/assets/llm/` though no placeholder game remains.

### 5.6 `Makefile:9-10` contradicts the list beneath it
"Suites = the pure code-logic set. The UI / FX / layout / scene-display suites were removed" — the
next line includes `layering_tests`, `fx_config_tests`, `action_button_tests`, `modal_dismiss_tests`,
`scene_cells_tests`, `ftue_hand_hint_tests`, `palette_ssot_tests`. An agent trusting the comment puts
a new UI guard somewhere unwired — landing back in 1.5.

### 5.7 Config duplication
- **Team ID** `export_presets.cfg:30` `7F5H5YC2UT` vs `tools/release_ios.sh:26` (written into
  `ExportOptions.plist` at `:50`). Two Apple team ids in one build → `xcodebuild -exportArchive`
  fails at *upload*, after a full archive. `tools/stamp_build_info.sh:19-30` already has an `awk`
  preset parser to reuse. The `ASC_TEAM_ID` override exists but nothing sets it.
- **`test_boot_splash_assets.py:12`** pins `CREAM = "Color(0.956, 0.933, 0.874, 1)"` as a **third**
  copy instead of asserting the two config files agree. `tools/test_stamp_build_info.sh:18-20`
  records this exact lesson in the same directory: "The expected values are READ from
  `export_presets.cfg` … never re-typed here. Hardcoding them meant the next `make release-ios patch`
  turned this guard red for no reason." A correct change to both configs turns this guard red; the
  predictable response is to edit the constant, reducing the guard to restating itself.
  The *image path* (`:10`) is legitimately pinned because `:87` also asserts `boot.gd` names it —
  leave that.
- **`Makefile:172` ≡ `Makefile:204`** — byte-identical destructive line
  `find build/ios -mindepth 1 -maxdepth 1 ! -name ci_scripts -exec rm -rf {} +`. The exclusion
  encodes `.gitignore:5-8` and `test_xcode_cloud_ci.sh:17`. → one `WIPE_IOS :=` variable.
- **`build/ios/AcornForest.xcodeproj`** typed at `Makefile:174`, `:180`, `:182`, `:184`, `:187`;
  `release_ios.sh:21-22`; `ci_post_clone.sh:19`, `:148`; `test_xcode_cloud_ci.sh:60`, `:71`.
  → `IOS_XCODEPROJ :=`. **`Makefile:182` uses a different shape**
  (`build/ios/AcornForest/AcornForest-Info.plist`) — a blind find-replace misses it.
- **`.PHONY` (`Makefile:32-34`) omits 8 live targets**: `g`, `debug`, `w`, `sfx`, `sfx-test`,
  `ios-plugins`, `c`, `l`. `ios-plugins` is a prerequisite of `ios`, and
  `apple-services-setup.md:20-21` promises "`make ios` runs this first, so an export never lacks the
  plugin" — a root file named `ios-plugins` silently breaks that.
- **`[importer_defaults]` quality split**: `project.godot:51` says 0.9; measured across shipped grove
  textures, **549 at 0.9, 425 at 0.88**. Both lossy, so the size guard is satisfied, but a new asset
  dropped beside a 0.88 neighbour imports at a different quality than its sheet. Either reimport the
  425 or assert one quality across the shipped set.
- **`export_presets.cfg:11 export_path`** is dead for every real build (the destination is passed on
  the command line: `Makefile:174` → `tools/export_ios.sh:42`). Godot's format requires the key, so
  it stays — note it as inert so it does not read as authoritative.

### 5.8 `board_montage.gd` determinism
`board_montage.gd` is the pixel-comparison gate this spec leans on in 4.1, and it does **not** run
under the guarantees its own docstring assumes: it re-hand-rolls `shot_base.gd`'s prologue and is
missing the `_apply_size` retry loop (the documented macOS window-height race), `seed(RNG_SEED)`, and
the weather pin. Two sibling tools have the same gap: `currency_pill_study_shot.gd:12-38` and
`boot_splash_shot.gd:14-56` (which uses two bare 0.2s sleeps instead of the retry loop).

`shot_base.gd`'s header states the cause: "Every `*_shot.gd` used to carry a byte-identical ~28-line
header… That copy-paste is what let four tools drift without the refusal guard, and what let the
window-size race go unnoticed." 15 tools use it; these three do not.

Change: route all three through `Base.begin()`, whose existing `size`/`out_arg`/`save`/`save_dir`
knobs cover every difference (`currency_pill_study_shot`'s non-design `941x160` → `size`;
`boot_splash_shot`'s `noload` positional → parse after `begin`; `board_montage`'s `save_dir` → already
a cfg key). **Do this before 4.1 relies on board_montage.**

---

## Sequencing

| | Wave | Depends on |
|---|---|---|
| 1 | Live defects (1.1–1.8) | — |
| 2 | Guards (2.1–2.8) | 2.3 assumes 1.x untouched files; land after Wave 1 |
| 3 | De-dup (3.1–3.9), then 3.6, then 3.10 alone | 2.x (guards catch regressions) |
| 4 | 5.8 (shot_base) → 4.1 → 4.2 | pixel gate must be trustworthy first |
| 5 | Docs + config (5.1–5.7) | independent; may run beside any wave |

Every wave: `make test-fast` after each change, `make test` before merge. Each wave in its own
worktree, merged to `main` on verified-done.

## Non-goals
- Re-litigating the `board_decomposition.md` architecture decision.
- Changing board pacing, the min-iOS floor, or `targeted_device_family` — 5.3 corrects the *claim*
  and surfaces the re-priced tradeoff; the setting is the owner's call.
- Any refactor of `ui_kit.gd` or `ui_workbench_view.gd` beyond the named duplication fixes.
