# Task 4 report — the hand art, and seeing the result

Note: this file previously held an unrelated stale report ("swap home bottom bar to
`Kit.action_button`") from a different task-numbering scheme in this worktree's history (which
itself had overwritten an even earlier stale report). Overwritten with this task's report below.

## What was generated

**Raw art:** `games/grove/assets/_new/hand_raw.png` (512×512, transparent), generated with
`codex exec` (built-in image generation, no reference-image extraction). Subject: a pointing-hand
cursor glyph — index finger extended up-left ~45°, other fingers curled, short rounded cuff, warm
cream fill (measured ≈(247,226,202) — slightly warmer/more saturated than the guide's exact cream
hex `#F6EBDD`≈(246,235,221), but well inside the guide's "small gameplay items may reach 65–85%
[chroma]" allowance, and reads clearly as cream, not skin-tone), fine ink-dark outline (measured
≈(29,50,74) vs guide ink `#243B4B`≈(36,59,75) — a close match), no shadow, generous padding (min
77px on the 512 canvas per the generation run's own self-check).

Two mandatory Meadow Sky references were attached (found archived under
`games/grove/assets/_concepts/screens/`, not at the guide's literal `_new/...` path — an earlier
task's intake had already processed and moved that whole batch):
- `palette_a_meadow_sky_board.png` (palette/material authority)
- `home_screen_meadow_sky_v2_working_farm.png` (camera/scale/detail-budget authority)

Full prompt text used this run is preserved at
`/private/tmp/claude-501/-Users-xup-dh-merge/a5c53ca1-94c6-4fd2-a8cb-64be626df854/scratchpad/hand_prompt.txt`
(session scratchpad, not part of the repo) — the guide's `_originals/` archive holds the shipped
raw PNG, which is the artifact of record.

**Intake plan authored** (`games/grove/assets/_new/hand.plan.json`, now consumed and moved to
`games/grove/assets/_new/_processed/hand.plan.json`):

```json
{
  "source": "_new/hand_raw.png",
  "category": "icon",
  "params": { "size": 512 },
  "outputs": [ { "name": "hand", "path": "ui/kit/hand.png" } ],
  "archive": "_originals/ui/hand_raw.png"
}
```

`category: icon` (single source → single output, `process_icon.gd`) was correct — the raw already
had a real transparent alpha channel (Codex keys its own generated background out to alpha), so the
"truly transparent PNG" path in `process_icon.gd` applied: trim to opaque bounds, pad, center on a
512² canvas. No `matte`/chroma-key step was needed since there was no baked flat/checker background
to strip.

## Commands run

```bash
cd /Users/xup/dh/wt-ftue-hand-hint
codex exec -i games/grove/assets/_concepts/screens/palette_a_meadow_sky_board.png \
  -i games/grove/assets/_concepts/screens/home_screen_meadow_sky_v2_working_farm.png \
  --dangerously-bypass-approvals-and-sandbox - < hand_prompt.txt > hand_codex_run.log 2>&1
# -> exit 0; codex's own verification script confirmed 512x512 RGBA, transparent corners,
#    alpha bbox (129,88)-(400,419), min padding 88px, zero green-channel spill.

make intake
# -> "OK _new/hand_raw.png -> 1 output(s); raw archived to _originals/ui/hand_raw.png"
#    games/grove/assets/ui/kit/hand.png written, plan moved to _new/_processed/, reimport ran clean.

make shot-grove MODE=ftue OUT=/tmp/ftue_merge.png
# -> "SHOT saved=/tmp/ftue_merge.png err=0 stars=0 coins=0 brambles=54"

make shot-grove MODE=ftuegen OUT=/tmp/ftue_gen.png
# -> "SHOT saved=/tmp/ftue_gen.png err=0 stars=0 coins=0 brambles=54"

make test
# -> 31 suites · 1743 passed · 0 failed · ALL SUITES PASSED (10.95s wall)
```

Both `shot-grove` runs printed the benign end-of-process Godot cleanup noise
(`WARNING: ObjectDB instances leaked at exit`, `ERROR: 1 resources still in use at exit`) that
other modes in this tool also print on quit — not a regression from this task.

## Alpha / edge verification (guide §8 acceptance gate)

Checked `games/grove/assets/ui/kit/hand.png` over three backgrounds (dark `#141414`, board cream
`#ECDFC2`, magenta/checker) by compositing and reading the actual images, not eyeballing a
thumbnail:
- No magenta/key fringe on any background; edges are a clean, consistent dark-ink line.
- No leftover pockets or checkerboard remnants.
- Corners fully transparent; alpha bbox `(67,26)-(444,486)` inside the 512² canvas — generous,
  roughly symmetric padding.
- Zoomed the fingertip apex 4× on a magenta backdrop: crisp anti-aliased edge, no halo.

## HAND_OFFSET retune (deviation from the brief's default)

The brief flagged this explicitly: adjust `HAND_OFFSET` if the generated art's fingertip doesn't
land where the code-drawn fallback assumed. It didn't.

Measured on the shipped `hand.png`: the processor centers the trimmed subject, so the alpha-bbox
center ≈ (255.5, 256) sits essentially at the 512² canvas center (padding came out
`(67, 26, 68, 26)` — left/right and top/bottom pairs nearly equal). The fingertip apex (topmost
opaque pixel band) sits at ≈ (102, 29). That's an offset of (−153.5, −227) from center at 512px,
which scales to (−28.8, −42.6) at the 96px `HAND_PX` the overlay actually renders.

`_hand_pos_for()` places the *whole hand box's* center at `rect.center + HAND_OFFSET`, so for the
fingertip (which sits `HAND_OFFSET`-worth up-left of the box's own center) to land back on
`rect.center`, `HAND_OFFSET` must equal the negation of the fingertip's own offset from center —
`(28.8, 42.6)` for this art, not the fallback's hand-tuned `(18.0, 14.0)`.

Changed in `engine/scripts/ui/hand_hint.gd`:

```gdscript
const HAND_OFFSET := Vector2(29.0, 43.0)   # was Vector2(18.0, 14.0)
```

with a comment recording the measurement. Grepped `engine/tests/` and `games/grove/tests/` for
`HAND_OFFSET` / `18.0, 14.0` / `HAND_PX` — no hits, so nothing else needed updating. The code-drawn
fallback hand's own circle-fingertip geometry no longer aligns as precisely with this new offset,
but the fallback only renders when `ui/kit/hand.png` is absent — no longer true — so this is an
acceptable, expected trade-off on a dead code path, not a regression on the shipped one. Verified
against the actual capture below: the tap shot's hand fingertip visibly lands on the generator
cell's icon.

## grove_shot.gd changes

Added `ftue` and `ftuegen` to the mode header comment, and — following the brief's placement
guidance ("before the board is built") — inserted right after `Save.mark_board_tutorial_seen()`
and before `Board.tscn` is instantiated:

```gdscript
if mode == "ftue":
    Save.data["ftue_seen"] = {}          # a brand-new player: the merge hand is live
if mode == "ftuegen":
    Save.data["ftue_seen"] = {"merge": true}   # merge taught — the generator tap hand is live
```

This placement matters: `Save.configure_for_test()` resets `Save.data = {}` and `_loaded = false`;
the first `Save.*` call after that (`mark_board_tutorial_seen()`) triggers `_ensure_loaded()` →
`load_now()`, which would stomp a `Save.data["ftue_seen"]` write made *before* it. Placing the
assignment after that first call and before the board is built is what the brief's snippet implied,
confirmed correct by the captures below (each mode showed exactly the intended hint, nothing more).

No new `match` branch was needed inside the mode switch: neither capture requires simulated board
interaction. `Board.tscn`'s own `_ready()` → `_rebuild_all()` → `_maybe_hand_hint()` chain
(`engine/scripts/scenes/board.gd`) presents the hint automatically once the ledger is set, and the
existing `await create_timer(0.5).timeout` after scene instantiation is ample for
`_maybe_hand_hint`'s single `await get_tree().process_frame` to resolve before the screenshot is
taken. `ftue`/`ftuegen` therefore fall through the `match` block with no branch, straight to the
shared capture tail — the shape implied by the brief's plain-language description, confirmed by
tracing board.gd rather than taken as a literal snippet.

## Honest description of both screenshots

**`/tmp/ftue_merge.png`** (1080×1920, MODE=ftue): fresh Level-1 board. The dim over locked cells
reads as a soft grey-blue tint — the keyhole icons and cell texture underneath stay fully visible
through it, not a blackout. Exactly **two** bright (undimmed) cells: two egg-shaped items, each with
a light halo box around it — the merge-source and merge-target cells. The hand cursor sits in the
empty cell between them, mid-glide (a looping tween; the capture caught an arbitrary point in the
drag-glide phase, which is expected for a looping animation, not a defect). At 96px the hand reads
unambiguously as a pointing hand — cream fill, dark outline, extended index finger, curled fingers,
cuff — legible against the board without looking pasted-on. The board's HUD (level badge, water/
star/acorn pills, next-unlock bar, ladder rail, bottom nav) stays fully legible and undimmed.

**`/tmp/ftue_gen.png`** (1080×1920, MODE=ftuegen): same board, `ftue_seen.merge = true`. Same soft
dim treatment. Exactly **one** bright cell: the mushroom-cap generator (with its own unrelated
sparkle FX active). The hand is mid-tap-bob, fingertip landing squarely on the generator icon —
confirming the `HAND_OFFSET` retune: the fingertip visibly touches the target cell rather than
hovering off to one side. 2×-zoomed crops of both hand+cutout regions (not just the full-page view)
confirm clean edges with no key-color fringe or checkerboard artifact around the hand sprite.

Both screenshots were read with the Read tool at full resolution plus zoomed crops around the hand
— not judged from a thumbnail or from test output alone.

## `make test` result

```
31 suites · 1743 passed · 0 failed
ALL SUITES PASSED
wall 10.95s (sum of suite-times 39.14s, speed-up 3.6× at JOBS=4)
```

Includes `games/grove/tests/grove_ftue_tests` (16 passed) and `engine/tests/ftue_hand_hint_tests`
(48 passed) — both green with the retuned `HAND_OFFSET` and the real texture now present (neither
suite pins the fallback's exact `HAND_OFFSET` value or asserts on the fallback code path once the
texture exists).

## Deviations from the brief

1. **`HAND_OFFSET` changed from `(18.0, 14.0)` to `(29.0, 43.0)`**, per the brief's own instruction
   to retune it to match the real art rather than ship a mis-pointing hand. Documented above and in
   the source comment.
2. **Reference images** for the guide's §1 mandatory pair were not at the literal path the guide
   names (`games/grove/assets/_new/ui_redesign_direction_b/...`) — an earlier task's intake had
   already archived/moved that batch. Found and used the same two images at their current location
   (`games/grove/assets/_concepts/screens/`), confirmed by filename match.
3. No `matte`/chroma-key step was needed — flagging it in case a reviewer expected one; Codex's own
   generation already produced a real alpha channel, so the "icon" category's transparent-PNG path
   in `process_icon.gd` applied directly.

## Files touched

- `engine/scripts/ui/hand_hint.gd` — `HAND_OFFSET` retuned + comment.
- `games/grove/tools/grove_shot.gd` — `ftue`/`ftuegen` capture modes + header doc update.
- `games/grove/assets/_new/hand.plan.json` → consumed, now `games/grove/assets/_new/_processed/hand.plan.json`.
- `games/grove/assets/ui/kit/hand.png` (+ `.import`) — the shipped art.
- `games/grove/assets/_originals/ui/hand_raw.png` — archived raw (never deleted).
- `/tmp/ftue_merge.png`, `/tmp/ftue_gen.png` — delivered screenshots (not committed; `/tmp`).

Not staged: `.superpowers/sdd/progress.md` (intentionally uncommitted per operating rules) and two
incidental `*.gd.uid` sidecars (`engine/tests/ftue_hand_hint_tests.gd.uid`,
`games/grove/tests/grove_ftue_tests.gd.uid`) that Godot generated during `make test` for
pre-existing task-1/2/3 files this task didn't touch — left untracked rather than swept in with
`git add -A`.

---

# Follow-up task — hairline seam fix (veil pixel-snapping)

## The defect

The dim veil is built by subtracting bright cutout rects from the full screen rect and filling the
remainder with `ColorRect` bands (`_rebuild_veil()` / `_subtract()` in `hand_hint.gd`). Real board
layout math hands `cutouts()` fractional coordinates (e.g. a cutout at `pos=(765.0333, 915.05)
size=(130.0167, 130.0167)`), so the bands `_subtract` produces also land on fractional edges — two
adjacent bands sharing a logical edge (e.g. one ending at `y=915.05`, the next starting at
`y=1045.067`) rasterize with a sub-pixel gap between them, letting the undimmed layer beneath show
through as a full-width bright hairline.

## The fix

Added `_snap_out(r: Rect2) -> Rect2` to `engine/scripts/ui/hand_hint.gd`: floors the rect's
position and ceils its end, so it only ever grows (never shrinks/clips). `_rebuild_veil()` now
snaps the screen rect once and each cutout hole once, right before feeding them into `_subtract`,
instead of leaving the raw fractional rects to flow through. Every band `_subtract` produces is
built purely from `min`/`max` combinations of already-snapped (integer) coordinates, so
integer-ness propagates through both the one-cutout and two-cutout (subtract-of-a-subtract) cases
with no further rounding anywhere else in the pipeline.

`cutouts()` itself is untouched — it still returns the raw, unsnapped, grown rects (its public
return value, asserted by tests via `get_center()`, is unchanged). Snapping happens only inside
`_rebuild_veil()`, on a local copy of each hole, so the "bright cutout" contract and the hand's
target position (still derived from unsnapped `_src`/`_dst` centers) are unaffected — growing a
cutout's edges outward by at most ~1px never shifts its center by more than a fraction of a pixel.

## Why no test tolerances needed loosening

`engine/tests/ftue_hand_hint_tests.gd`'s geometry section uses only rects built from whole-number
inputs (`Rect2(100, 200, 60, 60)`, `CUTOUT_PAD := 6.0`, etc.) — `floor`/`ceil` are no-ops on
already-integer values, so every assertion (cutout centers, band-area identities, no-overlap
checks) produces bit-identical results before and after the fix. Confirmed by running the suite
unmodified: 48/48 still pass. No assertion was loosened, deleted, or had its tolerance changed —
none needed it.

## Verification

**Ground-truth geometry**, via a temporary headless probe (`games/grove/tests/_tmp_veil_probe.gd`,
written, run, then deleted — not part of the diff) that opened a real `Board.tscn` in both FTUE
states and dumped the actual `_veil` `ColorRect` children:

Before (quoted in the brief, from a real capture against this same board):
```
band pos=(0.0, 0.0)        size=(1920.0, 915.05)
band pos=(0.0, 1045.067)   size=(1920.0, 874.9333)
band pos=(0.0, 915.05)     size=(765.0333, 130.0167)
band pos=(895.05, 915.05)  size=(128.0167, 130.0167)
band pos=(1153.083, 915.05) size=(766.9167, 130.0167)
```

After (same board, same "merge" drag-gesture state — the cutout positions match exactly,
confirming this is the same scenario the brief measured):
```
cutouts: pos=(765.0333, 915.05) size=(130.0167,130.0167) / pos=(1023.067, 915.05) size=(130.0167,130.0167)
bands:
  pos=(0.0, 0.0)      size=(1920.0, 915.0)   end=(1920.0, 915.0)
  pos=(0.0, 1046.0)   size=(1920.0, 874.0)   end=(1920.0, 1920.0)
  pos=(0.0, 915.0)    size=(765.0, 131.0)    end=(765.0, 1046.0)
  pos=(896.0, 915.0)  size=(127.0, 131.0)    end=(1023.0, 1046.0)
  pos=(1154.0, 915.0) size=(766.0, 131.0)    end=(1920.0, 1046.0)
all band edges integer: true
any band-band overlap: false
```
The top band's end (`915.0`) exactly equals the middle bands' start; the middle bands' end
(`1046.0`) exactly equals the bottom band's start. Same result (all-integer, gap-free, no overlap)
for the single-cutout `gen_tap`/tap state. The "gaps" between the three middle bands are the two
bright cutouts themselves (by design), not defects.

**Pixel-level check on the re-captured screenshots**: a full-board-width row-brightness scan (every
column in the board's x-range, every row) looking for rows where >85% of columns brighten or darken
in lockstep — the signature of a rasterization seam spanning the whole width. The only rows that
matched in either image were ordinary HUD panel borders (NEXT UNLOCK bar, board container edge,
bottom nav) confirmed by cropping and viewing each one — none fell inside the board's dimmed
interior. 2×-zoomed crops centered exactly on the cutout-row boundary (top-band → cutout-row →
bottom-band transition, the precise geometry quoted in the bug) show the dim tint running smoothly
and continuously right up to a clean, sharp cutout edge, in both the drag/merge and tap/generator
captures — no bright line anywhere along the transition.

## Commands run

```bash
godot --headless --path . --check-only --script res://engine/scripts/ui/hand_hint.gd   # parse OK
godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd                # 48 passed, 0 failed
godot --headless --path . -s res://games/grove/tests/grove_ftue_tests.gd               # 16 passed, 0 failed
make test                                                                               # 31 suites · 1743 passed · 0 failed
make shot-grove MODE=ftue OUT=/tmp/ftue_merge.png       # SHOT saved=/tmp/ftue_merge.png err=0
make shot-grove MODE=ftuegen OUT=/tmp/ftue_gen.png      # SHOT saved=/tmp/ftue_gen.png err=0
```

## Files touched

- `engine/scripts/ui/hand_hint.gd` — added `_snap_out()`, snap the screen rect and each cutout
  before `_subtract` in `_rebuild_veil()`.
- `/tmp/ftue_merge.png`, `/tmp/ftue_gen.png` — re-captured (not committed; `/tmp`).
- `games/grove/tests/_tmp_veil_probe.gd` — temporary ground-truth probe, deleted after use, never
  committed.

## Verdict

The full-width bright hairline reported at the veil band seams is gone: the real board's veil
geometry now lands on exact, matching integer pixel edges (verified against the exact coordinates
quoted in the bug), and both re-captured screenshots show a clean, sharp cutout boundary with no
seam, confirmed by both direct visual inspection and an automated full-width brightness scan.
