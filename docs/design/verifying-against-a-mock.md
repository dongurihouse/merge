# Verifying an implementation against a concept mock

How to establish that a UI element we render matches the concept art it was drawn from — and how to
know when it does. Advisory: no suite enforces this. It exists because a nav-bar restyle was
"verified against the mock" five times in a row, every time by measuring OUR element on OUR
background against THE MOCK's element on ITS background, and every one of those verifications was
invalid. The first like-for-like measurement found the real defect in one pass.

Read this before measuring anything off `games/grove/assets/_concepts/`. For art direction, palette
and asset intake see `docs/design/art-style-guide.md`.

## The rig

The split is the load-bearing part: everything a human had to LOOK at the mock to decide lives in a
JSON registry, and the scripts are deterministic — they never guess a rect, a colour or a scale.

```bash
# our element and the mock's own pixels on ONE flat field, at ONE scale, in ONE launch
make shot-mock OUT=/tmp/nav.png CELLS="mock:nav_home mock:nav_shop nav_home nav_home:fill=#F1B596"

# read the sheet back: the darkening at each px out from every element's own edge
python3 games/grove/tools/mock_profile.py --sheet /tmp/nav.png --side left --out /tmp/review.png
python3 games/grove/tools/mock_profile.py --sheet /tmp/nav.png --side right --vs "MOCK nav_shop"
```

| file | what it owns |
| --- | --- |
| `games/grove/tools/mock_targets.json` | ALL judgement: which mock, the element's face rect, how far the clean ground beside it really runs, which patches are flat field |
| `games/grove/tools/mock_elements.gd` | one adapter per element — builds it through the SHIPPING call at the mock's own size |
| `games/grove/tools/mock_compare_shot.gd` | crops, paints, lays out, writes `<sheet>.png.json` (every cell's rect + the mock's grain sigma) |
| `games/grove/tools/mock_profile.py` | per-row edge finding, the darkening table, the rms score, the review sheet |
| `games/grove/tools/tests/test_mock_targets.py` | re-checks the registry's rects and field patches against the actual PNG on every `make test-config` |

A cell is `[mock:]REGION[:MOD]…`. `:fill=#RRGGBB` forces our face colour, `:cp=K=V,…` and `:opt=K=V,…`
override any knob (`Nw` = that fraction of the face width), `:label=` names the column. Cell specs are
shell words: no spaces (`_` reads as a space in `label=`/`cap=` only) and no apostrophes — `make`
expands `CELLS` unquoted.

Adding an element: an adapter in `mock_elements.gd` plus a region in `mock_targets.json`. Adding a
region to an element that already has an adapter is JSON only.

## The rules

Each of these cost a wrong conclusion.

1. **Compare like-for-like or not at all.** Render our element alone on a flat field of the mock's own
   background colour, at the mock's own pixel size, with a 1:1 crop of the mock in the same sheet, and
   force our face to the mock's own fill. Darkening is inferred from a luma ratio, so it is a function
   of the ground it falls on; a scale difference resamples the very pixels a shadow lives in; a fill
   difference moves the contact reading. Varying all three at once — our screen vs the mock's — is how
   five rounds of "verified" produced no evidence at all.

2. **Scale every metric, not just the one knob that happens to own the size.** `nav` derives its whole
   geometry from one slot width, so handing it the mock's width is enough. The wallet pill does not:
   `overall_scale` moves the layout numbers but the shared cut-paper edge knobs are absolute px. Left
   alone, our pill at the mock's 0.86x carries a 1.16x-too-large shadow reach against a shrunken face,
   and the sheet reads as a shadow defect that is really a rig bug. `mock_elements.scale_cp()`.

3. **Validate the instrument before trusting it, in both directions.** A metric must be shown finding a
   known positive before it is believed on new art (the ring detector was checked against the old art's
   known ring; zeroing `HALO_OFFSET_FRAC` must fail the nav suite). And the isolated build must be shown
   matching a live capture once — otherwise the rig's own bugs get reported as the element's. A scanner
   returning zero findings is a bug until proven otherwise.

4. **An override that changes nothing must refuse, not fall through.** Every knob consumer in this
   project reads with `.get(key, default)`, so a misspelt knob renders the BASELINE, under the tuning's
   own label, and gets compared as if it were the tuning. Measured: a `_`→space rule meant for labels
   silently corrupted every knob name in a `cp=` list, and the sheet looked entirely reasonable.
   `mock_elements._apply_pairs` refuses an unknown knob for exactly this reason.

5. **Find the element's edge per row, not down a fixed column.** A tapered or flared element smears its
   own taper into the profile — on a nav tab (~7% flare) that turned a flat contact plateau into a
   decay, and the tuning read off it went entirely the wrong way.

6. **The declared face rect must be the outermost drawn sheet of BOTH.** Our wallet pill draws a gold
   backer 6px past its face; the mock's has none. Profiled against the face rect, our pill reports
   NEGATIVE darkening — a shadow that brightens. That sign is the tell. Turn the extra layer off
   (`:opt=backer=false`) or the two silhouettes are not the same object.

7. **Know how much real reference you have, and refuse to report past it.** A mock carries only so much
   clean ground beside an element: 24px beside one nav tab, 10px before the next, 4px between two
   wallet pills. Past that a cell is flat field and profiles as a serene, meaningless 0.000 — and a
   crop that ran out of mock reads exactly like a shadow that ended. Worse, a `clean` window overstated
   by 4px lets the NEIGHBOUR's shadow in: the acorn pill's left profile turned back upward at 6-8px,
   which was the coin pill, not this one.

8. **Check every edge before fitting one curve.** The mock's light is upper-left. Its leftmost nav tab
   reads 0.168 at contact and is gone by 9px; its rightmost reads 0.388 and still 0.010 at 16px. The
   wallet pills split the same way (top 0.097, left 0.129, right 0.366, bottom 0.396). No symmetric
   ring is both, and fitting one number to two curves is what every earlier "match" had been doing.

9. **A sample box that spans structure measures structure, not the thing.** Report the low-frequency
   range inside any texture or noise box — blur, then max−min over a 24px tile — and calibrate the
   limit against a known positive rather than assuming one. A grain measurement reported 3-5x off came
   from boxes reading 35 and 64, which had swallowed a tile edge and icon pixels; on the meadow board
   mock, genuinely empty sky reads 3.4-7.9 and a box slid onto a nav tab reads 144.
   `mock_profile.py` prints this for every field sample it takes, and
   `games/grove/tools/tests/test_mock_targets.py` runs it over every declared field patch in
   `make test-config` — including one deliberate known positive, because a check that has never failed
   is not a check.

10. **Know when you are done: rms against the reference, versus the reference's own noise floor.** The
    mock is paper; its grain is ~0.016 as a darkening fraction. Below that, a further tuning round is
    fitting noise — the render cannot show a difference the reference does not carry. The nav fit went
    0.144 → 0.018 against a floor of 0.016, and stopped. `mock_profile.py --vs`.

11. **A green numeric gate is not a substitute for looking.** A despill pass with every gate green had
    dragged all the coral art to brown; only the render showed it. An unknown icon id draws a `?`
    placeholder whose shadow profile is perfectly ordinary. Open the review sheet.

12. **A bound written in terms of the constant under test is vacuous.** A density assertion spelled
    `STEP_PX * 1.3` passed a deliberately re-sparsed stack. Use literals. Bound what is SEEN (the
    distance at which each side dies), not the parameter that produces it.

13. **Re-baseline warm before declaring byte-identity.** A cold first capture differed from the same
    commit's second capture and would have reported a false regression. Take both halves of a
    before/after the same way, in the same kind of process.

14. **Check for an existing documented rule before inventing one.** `engine/scripts/ui/cut_paper.gd:27-32`
    already said a drop shadow must be a DENSE ~1px stack and that a sparse 3/7/11 one bands visibly on
    a small element — and a later change broke exactly that. Read up to the feature's own constant
    before inventing a shadow.

15. **The mock is a painting, not a render.** Some differences are not implementable and some are not
    desirable. Name them as residuals with numbers instead of chasing them, and say plainly when a
    change is correct but imperceptible at 1x — e.g. the nav tab's lit contact reads 0.108 where the
    mock reads 0.168 because the ring stack is ~1px granular and the mock's value falls between two
    rings: one pixel column 6% light.

## What this cannot do

Only an element that can stand ALONE on a flat field can be rigged this way. Anything whose look
depends on what is behind or beside it — board tiles (they sit on the board frame's paper, not on
sky), giver cards (their fill is a per-giver tint from live state), scene backdrops — cannot be
isolated without inventing the very context under test. Say so and measure something else; do not
fake a field.

A shadow INSIDE an element (a glyph's own pool) has no shared silhouette to step out from, because our
art and the mock's are different drawings. `mock_profile.py --probe LABEL:x,y,dir,len` takes a
hand-placed ray instead, named in the command — honest about being chosen by eye rather than dressed
up as a derived measurement.

One sheet carries ONE flat field. `mock_compare_shot.gd` refuses a sheet whose regions sit on grounds
more than 8 (L1 over RGB) apart, because the profiler divides every cell by one field luma.
