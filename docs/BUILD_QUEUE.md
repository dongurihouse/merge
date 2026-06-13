# BUILD QUEUE — owner feedback → work orders (LIVING DOC)

**⚠ SINGLE-WRITER RULE (owner 2026-06-11, prevents race conditions):**
**this file is written by the TRIAGE agent ONLY.** Worker agents READ it and
APPEND to their own ledgers — the **eng agent** to `WORK_DONE.md`, the
**artist** to `ART_DONE.md`. Triage folds ledger entries back into this file
(ticks boxes, quotes notes, archives to the DONE log) and advances the markers:

`INGESTED: WORK_DONE through entry #108 (S/V/W/X/Y/Z/AA/AD ALL COMPLETE — eng queue clear) · ART_DONE through entry #104`

**How the loop flows:** owner feedback → triage/TPM writes work orders here
(§INBOX for eng, §ARTIST for image generation) → a worker CLAIMS an item by
copying the order verbatim into their ledger, then builds AGAINST THAT
SNAPSHOT (the queue may change under them) → appends results → triage
reconciles each DONE item against the snapshot: order unchanged → tick and
archive; order changed since the claim → only snapshot-covered work counts,
and the changed/remaining parts STAY in the queue as a residual item.

**Reconcile cadence (owner law, amended 2026-06-12): on EVERY owner
interaction.** No standing watcher — at each owner prompt/feedback, the
Director first checks the ledger tails against the INGESTED marker and folds
anything new BEFORE handling the feedback (and at session start, per
/director step 1). Builders: the queue updates at the next owner touchpoint
after your batch report; the INGESTED marker above always tells you how far
the fold has reached.

This file absorbed `ART_CHECKLIST.md` (owner 2026-06-11) — the artist's queue
is §ARTIST below; the old file is a redirect stub.

---

## OPERATING INSTRUCTIONS — eng/build agent (read once, follow exactly)

1. **Never write this file.** Your only outputs are code/commits and APPEND
   entries in `WORK_DONE.md` (format is at the top of that file). Checkboxes
   here are ticked by triage, from your entries.
2. **Survey before writing a line.** Read this whole file, then `git log --oneline -10`
   and `git status`. The tree may carry in-flight work or the owner's parallel
   edits — never assume a clean slate. Read every file you're about to change.
3. **Branch per batch:** `fix/<short-name>` or `feat/<short-name>` off `main`.
   One branch may cover several INBOX items if they're small and related
   (say which items in the first commit body).
4. **Work §INBOX top-down.** Items marked ⚡ jump the queue. Within an item the
   boxes are ordered — they build on each other.
4b. **CLAIM before you build.** The moment you start an item, append a `CLAIM`
   entry to `WORK_DONE.md` containing a VERBATIM copy of the order's boxes as
   you read them. That snapshot is your contract: build against IT, even if
   the queue text changes mid-batch (triage may be editing it live). At
   ingest, triage diffs your snapshot vs the current queue — work matching
   the snapshot counts; anything added/changed since stays queued for the
   next batch. Never re-read the queue mid-item to "pick up" changes.
5. **Report honestly, immediately.** Append a `DONE` entry to `WORK_DONE.md`
   the moment a box is done AND VERIFIED (not "should work"), one entry per
   box, with the divergence note and evidence (test line / tool output /
   screenshot path / commit hash).
6. **Acceptance is what the box SAYS it is.** If a box names a tool run, a
   screenshot, or a specific assertion, suite-green does not close it. The two
   click tools (`tools/click_gate.gd`, `tools/click_spot.gd`) exist because
   green suites missed real input bugs — when an item names them, run them.
7. **Disagree in writing, don't silently skip.** Wrong/impossible/contradicted
   order → append a `BLOCKED` entry (1-3 lines why), skip the box, continue.
   Triage resolves it next pass.
8. **Scope discipline.** Build exactly what the boxes say. Unrelated bug found →
   append a `FOUND` entry with 2-3 lines of evidence; don't fix it in this
   batch unless it blocks your item.
9. **Never touch:** the owner's parallel files (list in "How to verify" below)
   and the §ARTIST section (report art WIRING verifications as WORK_DONE
   entries — triage ticks the `[w]` column there). The owner often has a LIVE
   `godot --path .` running — never kill it.
10. **The final gate of the batch:** full suite sweep run SERIALLY + the quiet
    screenshots named by the items + click tools when named. Then commit
    (conventions in "How to verify"), merge `--no-ff` to main, and append the
    batch `report` entry to `WORK_DONE.md`:
    `<branch> merged <hash> — items X,Y done; Z blocked. Shots: /tmp/<...>.png`
11. **Stop conditions.** Stop and append `BLOCKED` rather than improvise when:
    an order requires a product decision not written here; a fix would touch a
    locked design rule (TIDY_UP_V2_SPEC.md §0c); or the suites were already red
    BEFORE your first change (report that immediately).
12. **Feature flags (owner law).** Every NEW ambient/juice/assist/ftue feature
    ships behind a `Features.on("<flag>")` guard (scripts/features.gd, order N)
    and its WORK_DONE entry names the flag — triage indexes it in FEATURES.md.
    Core mechanics and numeric tuning dials are NOT bool-flagged.
13. **Assets MOVE out of `~/Downloads` (owner law 2026-06-11).** Anything you
    wire from the download folder is `mv`'d into the repo — never `cp` — and
    if a process tool already wrote the repo dest, DELETE the raw it consumed.
    The download folder stays clean; nothing of ours lingers there.
14. **UI lands PIXEL-RIGHT in ONE shot (owner law 2026-06-11).** Any UI
    element you add or touch must come out aligned: panel wraps its content
    with the designed margins, text centered where centering is the design,
    the element anchored to the thing it belongs to. VERIFY IT YOURSELF
    before writing DONE: run the `assert_wraps`/`assert_centered` rect
    asserts AND look at a zoomed `--crop` capture of the exact element
    (tooling: order R3), and name that crop in the WORK_DONE entry.
    "Looks fine at full-screen scale" is not verification.
15. **LOOK-class work matches a VISUAL TARGET, and the OWNER is the final
    assert (2026-06-12, after the fence/tray misses).** Any box whose output
    is judged by eye (layout style, palette, art direction — not pure
    geometry) must NAME its target: a file in `docs/canon/` (owner-accepted
    references and screenshots of owner-accepted states) or an owner
    reference named in the order. The DONE entry shows a SIDE-BY-SIDE (your
    crop next to the target), not a lone crop — "matches the canon" is the
    claim, and rule 14's asserts still apply underneath. Box ticks at
    Director pass as usual, but a LOOK-class ORDER only CLOSES after the
    owner eyeballs its crop pack (a standing owner gate per order; rejection
    re-opens as a residual, not a new feedback cycle). Look-orders report in
    batches of ≤5 boxes so course-corrections land early, not after 17.
    If no target exists for what you're building, STOP and flag — building
    taste from prose is the failure mode this rule kills.

---

## How to verify (non-negotiable, from ~/.claude/CLAUDE.md + project memory)

- **Never open a visible window or steal focus.** Real-renderer checks ONLY via
  `tools/quiet_godot.sh --path . -s res://tools/<tool>.gd -- <args>`; the shot
  tools REFUSE without it. Logic: `godot --headless --path . -s res://tests/<suite>.gd`.
- **No sound during debugging** (the wrapper forces the dummy audio driver).
- **Run godot serially** — concurrent instances deadlock on the import lock.
  ⚠ The owner often has a LIVE `godot --path .` session running — never kill it,
  never run `--editor`, and expect occasional truncated captures (re-run them).
- If a replaced PNG looks stale in-engine: `godot --headless --path . --import`.
- **Unicode editing traps:** blocks containing emoji/`\uXXXX` escapes — use the
  Edit tool with literal characters, or anchored python splices that ASSERT the
  anchor was found. GDScript `\U` escapes are **6 hex digits** (8 silently breaks).
- Hands OFF the owner's parallel files: `ICON_PROMPTS.md`, `TIDY_UP_SPEC.md`,
  `tools/icon_gen_browser.js`, `tools/process_icon.gd`, `tools/_gen_queue.json`,
  `ReachZero*`, `docs/icon-gen-runbook.md`.
- Suites that must stay green: core 4 · save 32 · map 19 · quest 20 · grove 123+ ·
  engine 6 · smoke 10 · `tools/grove_sim.gd` PASS. Commit trailer:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`, author
  `git -c user.name="Tidy Up Dev" -c user.email="xupengqi@gmail.com"`.
- End-to-end input checks: `tools/click_gate.gd` / `tools/click_spot.gd` drive
  REAL clicks via `Input.parse_input_event` — they exist because handler-level
  tests missed the map input-swallow bug. Keep them honest.
- **After deleting/renaming ANY func: grep the whole repo for stale callers**
  (scripts/, tests/, tools/). Three incidents now (J's index assumption, K's
  _focus_zone suite HANG, the smoke out-of-tree crash) — a stale caller in a
  test hangs the headless suite silently.
- **`docs/canon/` is the visual ground truth (rule 15):** owner-accepted
  reference images + quiet captures of owner-accepted states. Bootstrap
  (first look-batch): capture the accepted farmhouse interior (all-owned),
  map v3 composite, and current board into canon/ via the quiet tools; the
  owner drops external references (e.g. the 2026-06-12 fence/page reference
  screenshot) in alongside. Look-class DONE entries compare against these.
- **Pixel-right self-check (eng rule 14; tooling = order R3):** any UI element
  you touch gets `assert_wraps(panel, content, minpad, tol)` /
  `assert_centered(box, content, axes, tol)` (helpers in `tests/grove_tests.gd`)
  AND a zoomed `crop=x,y,w,h` capture via `tools/home_shot.gd`/`grove_shot.gd`
  — LOOK at the crop before writing DONE.

---

## §INBOX — open work orders

> **Reconciled 2026-06-11 (Director pass 3 + auto-folds):** WORK_DONE #36–83
> + ART_DONE #40–74 folded. Orders **N, O, P, Q, R, U, T, M** verified done
> and archived to the DONE log — along with **J, I, K, L, E, F, H, G-UI, A–D** from earlier
> batches (verified then but left in place; the INBOX now holds OPEN work
> only). **Q3/Q4 are UNBLOCKED** (the whole §I farmhouse-v2 set landed +
> imported) — eng#72's "Q3/Q4 art-blocked" queue-state note is SUPERSEDED.
> Music beds re-assigned to the OWNER (no audio tool in the artist thread —
> ART_DONE #60/#61; §F note).
>
> **Reconciled 2026-06-12 (Director pass 4):** WORK_DONE #84–92 + ART_DONE
> #75–104 folded. **AB** (frameless fence) archived; **AC** archived (built,
> but its bleach is SUPERSEDED by AF — see the AC entry); **AE1** done (AE2–4
> open). The owner-direct **placement tool** (#86, spec §0c #12) + live fixes
> (#85/#87) archived. Pond/orchard/meadow art (27 files) committed `5981ef6`,
> §I rows ticked; chair-v3/wheel-v2 re-rolls landed. **S is NOT done** — eng
> claimed it (#84) but the ⚡ orders + your placement-tool request preempted
> it; only S3 (+ an S10 crash-fix) landed. S stays OPEN below.
>
> **⭐⭐⭐ THE ENG QUEUE IS FULLY CLEAR (eng#98–108, 2026-06-12): AF-eng ✓ · S ✓ ·
> V ✓ · W ✓ · X ✓ · Y ✓ · Z ✓ (structural #105 + treats #108) · AA ✓ · AD ✓.**
> All suites green (grove 297 · sim 40/40 default + 40/40 greedy · 0 jams). **Nothing
> left in the eng queue** — only the owner gates below remain.
> **OWNER-EYEBALL GATES STACKED (rule 15 — your calls; my numbers are proven):** the
> whole S cream/green UI restyle · X difficulty feel · Y porter+basket · Z wayside
> placements · AA CTA slot/feel · AF5 warm board · AF1 tray-v4 (artist) · AE2/AE3
> furniture POV (artist).
>
> **Pass 5 (2026-06-12, fold #93–97):** AF eng-half DONE (#94 — board
> re-warmed, HUD legibility fixed; AF1 tray-v4 + AF5 owner-eyeball remain) ·
> **AB fence WHITE-BG fixed** (#93→93c — `tools/cutout_bg.gd`, region-size
> then min=1; magenta-composite proof 41366→0 opaque white; the AB-archive
> residual is closed) · **V1** generator-preview done (V2/V3 remain) ·
> owner-direct: water/Lv overlap (real 76px Lv height, +guard, #96), wallet
> icons enlarged (#97). Marker → #97.
>
> **OWNER-DIRECT (2026-06-12):** the owner is instructing eng directly to
> build the HUMAN PLACEMENT TOOL (spec §0c #12: people place items on real
> art, the tool writes coords+footprint back to content data; agents never
> guess placements again). Expect its ledger entries WITHOUT a queue order —
> fold them as usual. Once the tool exists, every placement box below routes
> through it.
>
> **OPEN OWNER GATES (decisions, not eng work):**
> - **M (archived)** — the re-fit is DONE on the v3 art (eng#74): eyeball the
>   COMPOSITE — /tmp/m_fullmap.png or just open the game's map.
> - **Boot self-heal (eng#73)** — suites can't prove a window restore; the
>   owner's next NORMAL launch is the proof (should open full-size, focused).
> - **Audible walk (order O landed, eng#82)** — with sound on, walk
>   board↔home↔interior↔shop: the ambient bed must NEVER cut or restart.
>   Code-side is proven; only ears can pass this one.
> - ~~U pick~~ SUPERSEDED 2026-06-12: the owner judged the warm tray still
>   too low-contrast — order ⚡AC re-decides the levers (light near-flat tray
>   v3 — LANDED, ART_DONE #62; backing default OFF, owner confirms via the
>   AC2 crops).
> - ~~Music beds~~ RESOLVED same evening: the owner generated both takes —
>   landed (unledgered) as `assets/sfx/amb_grove1/2.mp3` ~19:00; order O's
>   arrival amendment moves + wires them. Audible pass = Dev after O.
>
> *(The pass caught eng mid-stride twice: T merged during the reconcile and
> the M re-fit landed as `9e89334` between the Director's two commits — both
> folded above; the ledger and this queue agree as of #75.)*

### ⚡ S — WHOLE-UI placement & juice audit → punch list (Director review, owner-ordered 2026-06-11 late)

> **IN FLIGHT** — claimed by eng (CLAIM #84, branch `feat/inbox-s`; all 17
> boxes snapshotted incl. the R4-disposition assert rule and S17's
> crops-only rescope). Text below frozen for this batch per rule 4b.

**Owner.** "The overall UI still needs a lot of work — the level display is
just plain text with a plain border, we need the screen juice everywhere,
consistent and well placed… same with the shop screen. I'll stop here and
have you review the whole UI and placement."

> **STATUS (pass 4):** S was CLAIMED (#84) then PREEMPTED by the ⚡ orders
> (AE/AB/AC) and the owner-direct placement tool — only **S3** (brambles,
> done with AC3 in #91) and an **S10 crash-fix** (#85, the grove Lv label
> was never stored) landed; S10's full kit-chip styling rode AC4's cream-pill
> recolor (#92). The other 14 boxes are UNBUILT — S resumes after AF. Rule 15
> now applies to its look-boxes (named target + side-by-side).

**Director ran the full review** — 7 quiet captures (`/tmp/ui_audit_*.png`:
board played + ladder · home fresh/progress/interior · shop · confirm),
audited against GROVE_UI_SPEC. Every box below ships under **rule 14**
(rect asserts + named crop). R owns the wallet-strip and zone-pin anatomy;
Q owns interior pin POSITIONS; S is everything else found. Work top-down.

**Plus (R4 disposition, eng #57):** every S box ADDS its permanent
`assert_wraps`/`assert_centered` coverage in the same edit — R4 swept the
chip/pin family; the heavy composites (fence cards, shop rows/price chips,
gate button, bag, ladder rows) are deliberately left to THESE boxes so each
element is touched exactly once.

**Board:**
- [x] S1 bottom bar (eng#98): one `[◀ Home | hint]` plank, Home btn + hint
      both fully inside the plank, nothing clips — rect-asserted at BOTH
      1080×1920 AND 1080×2340 (the resize test confirms the viewport grows to
      2340, so the tall-aspect check is real)
- [x] S2 chapter chip (eng#98): was STILL floating text — the kit
      `ribbon_title.png` (a wide gold banner) used as a 40px nine-patch
      collapsed invisibly in the ~69px chip. Now a solid CREAM chip in the HUD
      pill language (INK title, panel-text law), centered, lifts off the
      foliage. FLAG: gold banner is an owner look-option (different language)
- [x] S3 brambles render near-BLACK → warm the modulate toward deep
      moss-brown (eng#91: a multiply can't lift true black → shared warm-lift
      SHADER adds a moss-brown floor under the texture; 3× crop confirms warm
      earth, twig detail intact)
- [x] S4 currency/refill chips never clip (eng#98): water chip · wallet · Lv
      chip · refill button all rect-asserted fully on-screen in BOTH scenes;
      water/Lv no-overlap guard holds. The "water chip missing" was the
      intentional `ftue_staged_chrome` (water chip shows after the intro), not
      a clip — the test passes the intro (pops=10) before asserting

**Map:**
- [x] S5 zone pin (eng#99): name + status on ONE plank centered UNDER the
      building (`_zone_status_plank`, anchor 0.5 grow-both) — never on the art
- [x] S6 bottom CTA + gear (eng#99): the CTA was a collapsed `btn_leaf` sliver
      (nine-patch margins > button height) → SHARED FIX: `Look.button` is now a
      solid grove pill (green primary / cream secondary, centered label, no
      halo) — fixes EVERY leaf button app-wide. Gear is a `btn_round`. Solid-
      pill regression guards added (grove). FLAG: button restyle = owner eyeball

**Interior:**
- [x] S7 spot pins (eng#99): kit chips, 28px text, one anchor (centered under
      the plot), never over the furniture sprite
- [x] S8 variant tint (eng#99): full-multiply → SUBTLE wash (lerp 0.28) + a
      swatch dot; furniture renders naturally colored (no green wash). Owner
      eyeballs the final variant look (per box)
- [x] S9 interior title (eng#99): centered on the header plank (full-rect
      overlay + center alignment), ✿-progress inside the content margin
- [x] S10 the Lv chip (eng#92/#97): kit cream pill + `icon_level` + value +
      xp, FX.tick on change, ONE Hud module shipped to both scenes

**Shop:** (all eng#100 — extracted `Look.title_ribbon`, the 3rd ribbon collapse)
- [x] S11 title chip on the awning (not the squirrel's face) — solid cream chip
- [x] S12 wallet stat_chips dock inside the parchment, below the stall art
- [x] S13 section headers are solid tan tab chips + vine dividers
- [x] S14 gem cards fit badge+icon+count+price in flow; Popular badge inside;
      price = solid pill sized to content (avoids the chip nine-patch)
- [x] S15 close ✕ = `btn_round` docked at the parchment's top-right
- [x] S16 confirm dialog kit-normalized: parchment card, title chip, CREAM+GREEN
      `Look.button` pair side by side, 0.5 scrim, gem-as-icon (no raw emoji)
- [x] S17 [w] crops: the faceted violet gem reads distinct from water at a glance
      (`/tmp/s_shop2.png` — gem cards vs the rain/water help card)

> **⭐ ORDER S COMPLETE (eng#98–100, 2026-06-12).** All 17 boxes closed. Three
> nine-patch-collapse bugs found + fixed (chapter ribbon, `btn_leaf` buttons
> app-wide, shop titles) — every chip/button is now a solid pill with permanent
> guards. The whole UI speaks one cream/green pill language. **OWNER-EYEBALL
> GATE (rule 15):** the full restyle (board chapter chip, all buttons green/cream,
> shop title chips) awaits the owner's look — rejection re-opens as a residual.

### ⚡ AF — Re-WARM the calm board: calm ≠ bleached (owner 2026-06-12, board screenshot)

**Owner feedback (board screenshot).** "What part of your directions caused
the background of the board to be completely bland and void of any colors?
The builder removed the low-contrast background but also removed any screen
juice — why?"

**Evaluation — Director error, not builder error.** The builder executed
order AC faithfully; AC was over-corrected. Three of MY directions stacked
into a colorless flat: (a) the tray v3 prompt asked for "near-flat, no
texture, desaturated" → a dead grey-sage mat; (b) AC3 "veil bg_grove_board so
the painting stops competing" → eng applied a `#EAF0DC @0.62` LIGHT haze
(grove.gd:88-92) that bleached the whole painted meadow to pale nothing — but
the background was never the contrast culprit, the MAT was; (c) AC2 flipped
`item_backing` OFF, removing the only grounding under the pieces. Net: every
plane went to the same pale value → no depth, no warmth, no pop. The FX juice
SYSTEM is intact (breathe/floaters/bursts/scatter still flag-on) — what's
gone is STATIC richness, and that loss is what reads as "juice removed." This
is a LOOK order under rule 15: the owner's cited reference (`docs/canon/
ref_merge_calm.*`) is a WARM light surface with soft depth — that is the
target, not a pale void.

- [ ] AF1 ARTIST — `tray_grove_tall` **v4** (§B row): keep it LIGHT and
      low-contrast so pieces pop, but WARM and ALIVE — soft warm wheat/cream,
      a faint painterly texture (not dead-flat), and a gentle radial vignette
      so the board has FORM, not a uniform fill. NOT grey-sage, NOT
      desaturated. Same dest/process; hot-swaps.
- [x] AF2 lift the background veil (eng#94 — `#EAF0DC@0.62` light wash → warm DIM `#2A2A1E@0.20`, hue kept; meadow colored again): the `#EAF0DC @0.62` `calm_veil`
      (grove.gd:88-92) BLEACHES — replace the recede mechanism with a SOFTEN,
      not a wash: a slight darken+desaturate that KEEPS hue (e.g. a low-alpha
      dim ~0.18-0.25 or a blur feel), so the painted meadow stays present and
      colored but sits back. The play surface stays the lightest thing by the
      MAT being light, not by erasing the background. Owner eyeballs the crop.
- [x] AF3 re-ground the pieces (eng#94 — `item_backing` default back ON, re-purposed as a tight warm-grey contact shadow `#3E342A@0.30`): a soft
      warm CONTACT SHADOW under each piece — tight, low, warm-grey, ~0.25a —
      NOT the old hard dark ellipse (which vanished on a light mat per AC2).
      Re-purpose `item_backing` as this shadow (flag stays; default ON);
      before/after crops.
- [x] AF4 cells read as soft WELLS (eng#94 — warm tan fill `#C7BB94` a touch darker than the mat + drop shadow): warm the cell fill a touch and keep the
      inset+shadow so the grid has gentle depth (reference style), not flat
      pale squares; rule 14 asserts unaffected (colour only).
- [ ] AF5 acceptance (rule 15): full-board SIDE-BY-SIDE crop vs
      `docs/canon/ref_merge_calm.*` at 1080×1920 + one taller; the order
      CLOSES only on the owner's eyeball (warm + alive + items pop). Capture
      the accepted result into `docs/canon/board_calm_target.*`.
- [x] AF6 HUD text LEGIBILITY (eng#94 — per-label `outline_size 0` on the pill, xp 0.6→0.85; panel-text law honored; `/tmp/af_hud.png` crisp). DONE: (owner 2026-06-12: "the font is illegible").
      AC4 flipped the HUD fill CREAM→INK on the new cream pill but left the
      GLOBAL dark outline (`ui_font.gd:43-44` — `font_outline_color =
      BG_DEEP`, `outline_size 10`) that existed to make LIGHT text pop on the
      OLD dark wood bar. Dark text + a 10px dark halo on a cream pill = the
      glyph counters fill in and the strokes smear (the "5" survives, the
      "300/800" + wallet numbers blob). Compounded by the XP sub-label at
      `Color(INK, 0.6)` (hud.gd:102 — washed grey on cream). Fix: HUD labels
      on the solid pill get **outline_size 0** (theme-constant override per
      label — do NOT change the global, world-text on art still needs it) and
      **solid INK fill at full alpha** (the XP line → INK ~0.85, not 0.6).
      **LAW (panel-text, 2026-06-12):** text on a SOLID panel carries NO
      world-outline — the panel IS the contrast; the dark outline is ONLY for
      text floating on art/photo. Crops of both pills (board + interior),
      owner eyeball on legibility (rule 15).

### ⚡ AE — Furn sprites: punch the holes, audit the POV in situ (owner placement-tool session 2026-06-12)

**Owner (screenshot from the placement tool, farmhouse).** "Cut out the blank
spots within the items so they are transparent; and the angle of many of the
items does not fit the background, making it impossible to place."

**Evaluation — two distinct pipeline defects, both about to multiply into
the barn/pond/orchard/meadow wave; fixed at the source ABOVE, repaired
below.** (1) HOLES: Q2 built `tools/cutout_holes.gd` and ran it on exactly
ONE sprite (the table) — the pass was never made mandatory, so the chair and
wheel re-rolls landed with enclosed white (slats, spokes). The artist
process now includes the punch for every `furn_*` (step above). (2) POV:
ROOM CAMERA v1 was too soft — generators default to eye-level product shots
— and artist acceptance judged the take alone, not against the room. Macro
is now v2 (top face dominant + negatives) and FURN ACCEPTANCE is an in-situ
side-by-side (rule 15's logic at the generation step).

- [x] AE1 punch ALL landed furn sprites (eng#88): `cutout_holes.gd` over
      every `furn_*.png`, `--import`; 8 had enclosed white and changed
      (fh_chair/plant/wheel + 5 barn), rest punched to 0. fh_chair/fh_wheel
      verified clean+intact in-engine. ↳ Director: eng also punched the
      pond/orchard/meadow wave (over-reach beyond AE1's scope, flagged) —
      ACCEPTED (idempotent, matches the new mandatory artist step); those
      files now committed (5981ef6)
- [ ] AE2 in-situ POV contact sheet (rule 15): quiet all-owned interior shot
      per landed zone (farmhouse now; barn once AD1 wires it) + one crop per
      placed item — the pack goes to the OWNER, who marks any further
      misfits beyond AE3's two (their re-roll rows get queued at the fold)
- [ ] AE3 known misfits RE-ROLL (artist rows in §I, ROOM CAMERA v2 +
      mandatory punch): `furn_fh_chair` v3 + `furn_fh_wheel` v2 — eng
      re-imports on arrival, provisional pos/fsize per §0c #12 (the owner is
      mid-placement; finals are theirs)
- [ ] AE4 standing arrival law (amends AD1): a furn sprite's [w] requires
      BOTH (a) the punch verified — a re-run punches 0 — and (b) the in-situ
      side-by-side named in the entry; POV misfits are FLAGGED with their
      crop and NOT wired

### AD — The remaining four zones LIGHT UP as their art lands (owner 2026-06-12: "the barn is also empty")

> **ALL FOUR ZONE ART SETS LANDED (barn #65-74, pond/orchard/meadow
> #75-102, committed 5981ef6).** AD1–AD3 fire per zone as eng picks them up —
> import + verify + PROVISIONAL pos (owner finalizes with the placement
> tool). The §I rows are [g]-ticked; [w] ticks at AD wiring.

**Owner.** "The barn is also empty and has no image generation prompts —
could this be the same for other zones?" **Yes — all four were deliberately
parked on the farmhouse-v2 pattern gate; the gate is passed (Q done) and the
36 generation rows are now LIVE in §I** (barn → pond → orchard → meadow, one
zone per artist batch). Eng's side is pure arrival work — the loaders are
path-convention (K1: `int_<zone>.png` backdrop, `furn_<spot_id>.png` per
spot), so nothing new is built; each zone is import + verify + provisional
placement. Boxes fire PER ZONE as its batch lands (K4-residual precedent —
standing art-arrival work, claim per zone).

- [x] AD1 (×4, eng#107): all-owned interiors verified — every backdrop
      CONTAIN-fits + ALL 8 furn/zone render as art (no fallback chips);
      content↔art ids match 32/32. Crops `/tmp/ad_{barn,pond,orchard,meadow}.png`.
      AE4 hole-punch re-run = 0 regions (clean, per-zone sample)
- [x] AD2 (×4, eng#107): ZONES `pos` defaults render sensibly per backdrop —
      PROVISIONAL (owner authors finals with the placement tool, §0c #12)
- [x] AD3 (×4, eng#107): all-owned quiet shots + `click_spot` e2e PASS
      (zone tap → lid → row buy, stars 10→7; cheapest-spot id unchanged by art)
- [x] AD4 (eng#107): pond CORRECT (boat + lilies ON the water, reeds at the
      edge). **FLAG: the meadow bridge `md_brook` renders on grass, not ON the
      baked brook** — geometry-sensitive, for the owner's placement tool (not forced)

> **⭐ ORDER AD COMPLETE (eng#107, 2026-06-12).** 4 zone interiors wired + verified
> (32/32 furn render, hole-punch clean, click_spot e2e green). All placements
> PROVISIONAL (placement tool). **OWNER GATE:** the meadow bridge wants the brook.

### V — New generators are INVISIBLE until they arrive (owner 2026-06-11 late-2)

**Owner feedback.** "The border of the game unlocked a few different things
that the current generator doesn't do, but there's no new generator being
offered in any way for a long time."

**Evaluation — confirmed by the numbers; this is a COMMUNICATION gap first,
maybe a pacing gap second.** Edge (ring-4) brambles demand t5 of line 3
(mushrooms — compost bin, `appears_at` chapter 16) and line 4 (honey —
beehive, chapter 26), but a player expanding outward meets those brambles
MANY chapters earlier with zero signal that a new generator is coming — the
content reads as impossible, not as "later". Fix the signal now; retune the
arrival numbers only with data.

- [x] V1 locked-generator PREVIEW (eng#95 — `gen_preview` flag: greyed silhouette + "after N spots" chip when the line's edge bramble is revealed; tap→name floater; grove 237): from the moment any bramble gated on a
      generator's line is REVEALED (adjacent-open), that generator's future
      cell draws a greyed silhouette of its art + a small kit chip
      "after N more spots" (engine text, i18n); tap → floater with its name.
      Behind `Features.on("gen_preview")`. The silhouette cell still counts
      as bramble terrain until the reveal (no gameplay change)
- [x] V2 MEASURE (eng#101): grove_sim reports the blind gap per generator.
      **hive (line 4): ~18–20 spots, STABLE** (seen ~6–8, arrives 26) — the real
      gap. **compost (line 3): SEED-DEPENDENT +11/-10** (expansion direction
      decides). Report-only; owner retunes `appears_at` (16/26 unchanged here)
- [x] V3 proof (eng#101): `tools/click_preview.gd` drives a REAL tap on the
      silhouette → floater "compost — after 16 spots" (PASS); genpreview shot
      `/tmp/v3_preview.png`; full sweep + sim PASS unchanged

> **⭐ ORDER V COMPLETE (eng#95 · #101, 2026-06-12).** Preview (V1) + measured gap
> (V2) + real-input proof (V3). Owner has the two numbers to retune `appears_at`.

### W — Board FEEL batch: hint earlier+longer, constant pop rhythm, sell discoverability (owner 2026-06-11 late-2)

**Owner feedback.** (a) "On idle, the merge hint needs to show up earlier and
with longer wiggle — don't just wiggle once, wiggle slower and a couple of
times." (b) "As items fill up, the click speed for the generator slows as
items travel further — make the rate constant; items always travel the same
total time, not the same speed." (c) "Did we decide to allow selling? When an
item reaches max level I don't have a way to do anything with it."

**Evaluation.** (a) accepted — pure tuning. (b) accepted, but the diagnosis
in code differs from the feel: spawn travel is ALREADY fixed-duration
(0.22s, grove.gd ~1177) — the real throttle is the `animating` flag DROPPING
board taps during each flight (grove.gd:1053 early-return), so every pop
eats ~0.25s of dead input; on a crowded board pops also chain into relocate
animations. Fix the input gate, keep fixed-duration as written law.
(c) selling EXISTS — drag any item onto the merchant's stall at the fence's
right end (tier-scaled pocket change, `_sell_item`). The owner not knowing
IS the bug: zero affordance. Make it discoverable; do NOT add a second sell
mechanic.

- [x] W1 idle hint (eng#102): first hint at 4.5s (was 7), re-nudge ~4s;
      `FX.rock` gentle rock (±6°, ~1.2s/cycle × 3) replaces the fast shake;
      constants named at top of grove.gd; `idle_hint` flag unchanged
- [x] W2 constant pop rhythm (eng#102): the pop's spawn-flight no longer sets
      `animating` (it gates MERGES only now), so rapid generator taps are never
      dropped. Headless test: 5 board-surface taps without awaiting → 5 items
- [x] W3 sell discoverability (eng#102, `sell_hints` flag): while dragging, the
      stall brightens + a live "+N🪙" tag (the dragged item's sell_value) at the
      merchant's shoulder; first max-tier item floats a one-time persisted hint.
      No second sell mechanic. Affordance assert-verified (mid-drag is transient)
- [~] W4 ~~undo floater + sell tripwire~~ → SUPERSEDED same day by order
      **Y** (owner expanded selling: diamond pinnacle + porter collection
      with built-in buy-back window). Do not build W4; Y owns sell safety.

> **⭐ ORDER W COMPLETE (eng#102, 2026-06-12).** Idle hint sooner+gentler · the
> animating gate no longer eats rapid generator taps · sell affordance (brighten
> + shoulder tag + one-time max-tier hint, `sell_hints` flag). W4 superseded by Y.

### X — Quest difficulty must GROW: tiers, counts, cross-generator mixes (owner 2026-06-11 late-2)

**Owner feedback.** "Quests currently only request items from the same
generator. As new generators unlock, quests should ask for high-level items,
multiple items, items from new generators or a mix — much more difficult as
the game progresses."

**Evaluation — accepted; today's builder is single-ask by construction**
(quest = {line, tier, count, stars}; lines drawn per-generator with
two_count_every as the only escalation). This is an ECONOMY-COUPLED change:
the affordability proof (worst case 1+1+2+2 ≥ dearest 5★ spot) and the jam
sim are the safety net — they must be RE-PROVEN, not edited around.

- [x] X1 schema (eng#103): quest = `{asks:[{line,tier,count}], stars}`;
      `G.quest_asks(q)` normalizes (legacy single-ask → one entry). Verified
      saves store only `qdone` booleans, not quest defs — persistence untouched
- [x] X2 curve (eng#103): the REQUIRED ramp quests are byte-for-byte the proven
      single-ask curve; multi-LINE stretch asks are PURE ADDITIONS (slack grows
      to cover them) — zone 3 → 1×2-line, zone 4 → 1×3-line, zone 5 → 2 stretch.
      Stretch pays 2–3★ (3★ NEW); t8 never appears. (Making it a REPLACEMENT
      stalled the sim at 16/40 — it ate the slack the bot needs to skip the
      hardest single; the ADDITION design keeps 40/40 + the proven affordability)
- [x] X3 giver UI (eng#103): the AB2 pill renders one [item+n/m] pair PER ask
      (1–3, joined by "+"), ✓-ready spans all pairs, deliver is all-or-nothing.
      Crop `/tmp/x_fence2.png` (a 3-ask fox quest +3★). No second card invented
- [x] X4 proof (eng#103): affordability re-derived GREEN (unchanged required
      path) · pigeonhole/spot-level green · sim PASS **40/40, day-4 runway, 0
      jams** · t8-never + multi-ask-exists + skippable asserts · 3-ask fence crop

> **⭐ ORDER X COMPLETE (eng#103, 2026-06-12).** Difficulty grows via skippable
> multi-line stretch quests (2–3 lines, 2–3★) on top of the unchanged required
> path. Completability + affordability PROVEN (sim 40/40, 0 jams). **OWNER GATE:**
> the difficulty FEEL is your eyeball — numbers proven, taste is yours.

### Y — Selling v2: the diamond pinnacle + the porter's collection round (owner 2026-06-11 late-3)

**Owner feedback.** "Allow selling any item — maybe make it even better: a
top-tier item grants 1 diamond; just make sure the water↔diamond round trip
can't be abused. Since selling is a deliberate drag, give the shop a buy-back
that disappears after a few minutes so the player doesn't abuse it — or even
better, a separate animation of another spirit coming to collect the items,
then they're gone."

**Evaluation — accepted, both halves; the numbers already make it safe.**
Earning 1💎 = one t8 = 2^7 ≈ **128 water** of pops; 1💎 buys at most **4
water** (full 100-refill / 25💎). The round trip loses ≥96% — selling can
never become a water pump. INVARIANT (sim-asserted, not commented): water
spent to EARN 1💎 ≥ 10× the water 1💎 BUYS. The porter beat is the better
buy-back: the collection moment IS the expiry — diegetic, charming, and it
hard-caps abuse without a single popup.

- [x] Y1 (eng#104): `G.sell_reward` — t8 trades for 1💎 (no coins), t1–t7 keep
      1–7🪙; "+1💎" floater + gem fly-to; `_sell_item`/`_on_merchant_tap`/the W3
      tag/the sim all route through it; t8 off the quest table (X)
- [x] Y2 (eng#104): a wicker `basket_chip` at the merchant's feet holds the last
      ≤3 sales as tappable chips; tap = buy-back with an EXACT refund (return the
      granted currency, item to a free cell; wobble if full/already-spent);
      cap 3, a 4th sale overflows → porter early. (basket renders — probe-confirmed)
- [x] Y3 (eng#104, `porter_collect` flag): a `_porter_tick` timer (~3 min) sends
      the `spirit_porter` drifting in to scoop the basket — buy-back closes the
      instant he arrives (data clears immediately; drift is cosmetic). Flag OFF →
      chips fade on the same timer. Basket not persisted (away >3 min ⇒ gone)
- [x] Y4 (eng#104): grove +12 — t8 grant, exact-refund/no-arbitrage, full-board
      block, cap-3→porter overflow, timer expiry; the abuse invariant
      water-to-earn-1💎 (128) ≥ 10× water-1💎-buys (4); sim 40/40 + live
      tripwires coins/100💧 = 9.2 (<25) AND the diamond invariant

> **⭐ ORDER Y COMPLETE (eng#104, 2026-06-12).** t8 → 1💎 with a buy-back basket
> the porter clears; the water↔💎 round trip provably loses 32× (no pump). No
> second sell mechanic. **OWNER GATE:** the porter drift + basket placement feel.

### Z — The coin SINKS (owner greenlit the design 2026-06-11 late-3)

**Owner.** "Yes, let's design the sink for coins."

**Director design — two sinks, one structural + one recurring-delight; both
diegetic, neither touches water (friction law).**

**Z-A Wayside decorations (the structural sink).** Small cosmetic props at
authored path-side PLOTS on the map — lantern post, bird bath, flower tub,
mossy bench, beehive skep, stone cairn. Priced 40–150🪙 each, one-time per
plot; 4 plots unlock per restored zone (20 on map 1) → lifetime sink
capacity ~1.5–2k🪙, scaling with future maps. Same placement law as
everything else: ground-standing sprites on calm clearings (map v3's
clearings give them homes); same 3-state pins as spots but COIN-priced
(level-gate-free — pure cosmetics, never progression).

**Z-B Spirit treats (the recurring sink).** A 10🪙 acorn-treat button at the
merchant stall; buying one sends a treat to a random wandering spirit, which
scurries over, nibbles, and does a happy hop+glow. Infinitely repeatable,
intentionally tiny — a delight loop that keeps coins meaningful between
wayside purchases. Behind `Features.on("spirit_treats")`.

- [x] Z1 content (eng#105): `G.waysides()` — 20 plots (4/zone), 6 prop types
      (landed `way_*` art), 40–154🪙 (sum 1940), `{id,name,tex,cost,map_pos,zone_req}`;
      `waysides` save key + `home.buy_wayside`. map_pos PROVISIONAL (owner finalizes)
- [x] Z2 map flow (eng#105, `wayside_decor` flag): plots render dormant ghost →
      ghost + coin-cost pin → owned prop; `_on_map_tap`→`_on_wayside_tap` buys
      (wobble if dormant/unaffordable). Positions provisional (rule 15)
- [x] Z3 treats (eng#108, `spirit_treats` flag): a 10🪙 acorn chip at the merchant
      shoulder → `_buy_treat` spends 10🪙, hops a RANDOM board spirit (`_amb_layer`)
      with a ✿ glow; endlessly repeatable, rapid-buy graceful, no overspend.
      grove +3. The recurring-delight sink — now built (was the parked residual)
- [x] Z4 proof (eng#105): grove +12 (20 plots · all coin-priced · none gate
      progression · sink 1.5–2k · full buy lifecycle); sim 40/40 + live report —
      faucet 108🪙 vs sink 1940🪙 (absorbs 1796%, no overflow) + no-collision assert

> **⭐ ORDER Z FULLY COMPLETE (eng#105 structural + eng#108 treats).** Waysides are
> the structural sink (1940🪙 ≫ the 108🪙 faucet → coins always spendable, no
> progression-gate); spirit treats are the 10🪙 recurring sink. **OWNER GATE:** wayside
> placements are provisional (placement tool); the coin-pin + treat look is your eyeball.
- [x] Z5 art (§I rows added): 6 wayside props + `spirit_porter` (Y3) +
      a treat nibble needs no art (reuse acorn icon + hop)
      ↳ Director pass 3: ALL landed + imported (ART_DONE #53–59) — Z2's
      placement pass still waits on order M's map_pos re-fit

### AA — The star gate goes SOFT: bank past the requirement (owner 2026-06-11 late-3)

**Owner feedback (with a fence screenshot).** "Allow me to go past the stars
required for unlock if I want to — although the design and pacing should make
it very hard for me to simply just merge and not do anything else."

**Evaluation — accepted; the soft wall already exists in the data, the hard
wall is one rule we delete.** Today gate-ready PAUSES the givers (grove.gd
~324: asks stop the moment the frontier's cheapest level-allowed spot is
affordable) — a hard stop. But each chapter's quest pool is FINITE (5–6
quests + slack), so with the pause gone, a player who refuses to decorate
simply finishes the chapter's asks and the fence runs DRY — nothing left to
earn but sell-coins until they spend stars. That IS the owner's "very hard
to just merge" pacing: natural exhaustion, no artificial wall. Stars bank
freely; buying several spots back-to-back already fast-forwards chapters
(chapter = unlocks count). The owner's screenshot also shows the Decorate
CTA centered ON TOP of the merchant card (gate_btn anchors 0.5 on the
giver_bar) — it gets a reserved slot in the same rework.

- [x] AA1 delete the affordability pause (eng#106): `_active_quest_idx` dropped
      the `_gate_ready()` pause + the `done >= needed` stop — givers serve the
      FULL pool past gate-ready; it exhausts naturally. Pause tests updated to
      the soft-gate law; the LEVEL-gate rule stays untouched
- [x] AA2 Decorate CTA + reserved slot (eng#106): breathes at gate-ready,
      escalates to a hop when DRY. Moved OUT of the fence band to a reserved
      bottom-center board slot — rect-asserted to never cover a giver/merchant
      (fixes the owner's screenshot). Crop `/tmp/aa_gate.png`
- [x] AA3 economy proof (eng#106): affordability test unaffected (proves a
      minimum); sim `greedy` variant does every completable single before
      decorating → **40/40, day-7 runway, 0 jams** (vs default day 4) — a
      thorough merger is never permanently stuck (the soft gate is the escape)
- [x] AA4 shots (eng#106): gate-ready WITH quests flowing (`/tmp/aa_gate.png`);
      DRY state asserted in grove (giver_chips empty + gate visible)

> **⭐ ORDER AA COMPLETE (eng#106, 2026-06-12).** The star gate is soft — bank
> past the requirement; the finite pool exhausts naturally; the reserved-slot CTA
> never covers a giver. Default sim 40/40 day 4 · greedy 40/40 day 7 · 0 jams.

## OPERATING INSTRUCTIONS — artist / generation agent (read once, follow exactly)

1. **Never write this file.** Your only output besides the images is APPEND
   entries in `ART_DONE.md` (format at the top of that file): one entry per
   processed image (or re-roll/stall note). Triage ticks your `[g]` boxes here
   from your entries; the eng agent's wiring reports tick `[w]`.
2. Work §ARTIST top-down inside a section; one batch = one chat so the style
   stays consistent. §H (the UI kit) is consistency-critical — single batch.
3. Every image prompt = subject text + `⊕CORE` verbatim (below). Never add
   style/IP names. NO text, numerals, or letters in any image — ever.
4. Download raw to `~/Downloads/<id>_raw.png`, run the row's **Process**
   command from the repo root, then after a batch:
   `godot --headless --path . --import`
4b. **MOVE, don't copy (owner law 2026-06-11): `~/Downloads` stays clean.**
   The moment a Process command succeeds, `rm` its raw from `~/Downloads` —
   the repo copy is now the ONLY copy (a re-roll re-downloads anyway).
   Direct-drop assets with no process step (audio `.wav`/`.ogg`, fonts) are
   `mv`'d into the repo, never `cp`'d. Nothing of ours lingers in Downloads
   after a batch.
5. Re-rolls: SAME prompt + one added constraint (never rewrite — drift
   compounds). If a prompt stalls the generator, reword the SUBJECT only and
   say so in your ART_DONE entry.
6. Respect the ASPECT DISCIPLINE block below — generate IN the row's shape.

---

## §ARTIST — image generation queue

**⊕CORE (the style core — paste verbatim into every image prompt):**
> hand-painted anime film background style, soft gouache and watercolor texture
> with visible brushwork, gentle diffuse summer daylight, warm nostalgic pastoral
> palette of meadow green, straw gold and clear sky blue, towering soft cumulus
> clouds, atmospheric haze in the distance, wind-blown grass, painterly
> cel-shaded subjects with clean simple line work, no photorealism, no glossy 3D
> render, no text

**Process commands** (from repo root; `qi` = quiet not needed, these are headless):
- icons: `godot --headless --path . -s res://tools/process_icon.gd -- ~/Downloads/<id>_raw.png <dest> <SIZE>`
- scenes: `godot --headless --path . -s res://tools/process_decor.gd -- ~/Downloads/<id>_raw.png <dest> <W> <H> --opaque`
- **furn sprites (`furn_*`) — MANDATORY extra step (owner 2026-06-12):**
  after the icon process, punch enclosed white:
  `godot --headless --path . -s res://tools/cutout_holes.gd -- <dest>` then
  `--import`; the ART_DONE entry states the punched-region count (0 is fine).
  Enclosed white between legs/spokes/slats is the defect this kills.
- then `rm ~/Downloads/<id>_raw.png` — rule 4b: the raw is CONSUMED, Downloads stays clean

**⚠ ASPECT DISCIPLINE (owner 2026-06-11) — every row names its shape; generate IN that shape:**
- **Square** (1:1) — board items, POI landmarks, fixtures, busts, particles. Say "Square." in the prompt.
- **Tall portrait** (9:16 or 3:4) — full screens & mats: board bg 1080×1920, home map 2160×2880, board tray 1080×1440. Say "Tall portrait." in the prompt.
- **Wide landscape** — strips & banners: the quest fence 1080×220 (very wide!), vista 1920×1080. Say "Wide landscape banner." (or the exact feel) in the prompt.
- If the generator can't hit an extreme ratio (the fence!), generate the nearest LARGER canvas with the subject composed full-bleed along the needed band and the process crop takes it — never stretch after the fact.

**OPEN RE-ROLLS / NEXT GENERATION (do these alongside your current section):**
- **FIRST (⚡): `tray_grove_tall` v4** (§B, order AF) — the v3 surface read
  bland/colorless; v4 is WARM + alive + soft depth. Match
  `docs/canon/ref_merge_calm` (owner drops the screenshot there).
- **AE3 re-rolls** — `furn_fh_chair` v3 + `furn_fh_wheel` v2 (§I farmhouse)
  under **ROOM CAMERA v2** + MANDATORY furn hole-punch + FURN ACCEPTANCE
  side-by-side
- **THEN the remaining zone close-ups** — pond → orchard → meadow (barn
  landed #65–74), ONE ZONE PER BATCH; read the PLACEMENT LAW + ROOM CAMERA
  v2 + OUTDOOR + FURN ACCEPTANCE blocks BEFORE generating — every furn take
  is judged in situ now

---

## §A — P1 board items (8-tier lines; tiers must step in SIZE + SILHOUETTE)

Item prompt shape: *"A single [SUBJECT] as a small painted game item: chunky
readable silhouette, soft painterly shading with a single warm rim light, clean
simple outline, centered on a plain solid white background, generous margin.
Square. ⊕CORE"*

### Wildflower line → `res://assets/items/flower_<n>.png` · process: icon 512

| g | w | id | SUBJECT |
|---|---|---|---|
| [x] | [x] | flower_1 | tiny paper seed packet with a single seed spilling out |
| [x] | [x] | flower_2 | small green sprout with two leaves in a soil mound |
| [x] | [x] | flower_3 | young seedling with first flower bud in a soil mound |
| [x] | [x] | flower_4 | leafy sapling with one open wildflower in a terracotta pot |
| [x] | [x] | flower_5 | bushy wildflower plant with three blooms, planted in the ground |
| [x] | [x] | flower_6 | lush blooming wildflower bush covered in flowers |
| [x] | [x] | flower_7 | small flowering tree with a petal-dusted canopy |
| [x] | [x] | flower_8 | radiant flowering tree in FULL bloom with falling petals and a golden glow |

### Berry line → `res://assets/items/berry_<n>.png` · process: icon 512

| g | w | id | SUBJECT |
|---|---|---|---|
| [x] | [x] | berry_1 | tiny burlap pouch with a few red berry seeds |
| [x] | [x] | berry_2 | **REGEN (owner 2026-06-11: reads identical to flower_2 on the board)** — a small berry sprout in a soil mound with TWO ROUND RED BERRIES already hanging from a drooping stem, leaf edges tinged dark red. Constraint to append: *"must NOT read as a plain two-leaf green sprout — the hanging red berries are the silhouette."* (replaces the live file in place) |
| [x] | [x] | berry_3 | young berry seedling with white blossoms |
| [x] | [x] | berry_4 | small berry sapling with green unripe berries in a terracotta pot |
| [x] | [x] | berry_5 | berry bush with the first ripe red berries, planted in the ground |
| [x] | [x] | berry_6 | full berry bush heavy with ripe red berry clusters |
| [x] | [x] | berry_7 | small berry tree with abundant fruit |
| [x] | [x] | berry_8 | magnificent berry tree LOADED with glistening fruit and a wooden harvest basket at its base |


### Mushroom line (debuts with the compost bin, zone 3) → `res://assets/items/mushroom_<n>.png` · process: icon 512

| g | w | id | SUBJECT |
|---|---|---|---|
| [x] | [x] | mushroom_1 | tiny paper spore packet with a few brown spores |
| [x] | [x] | mushroom_2 | one small button mushroom sprouting from dark soil |
| [x] | [x] | mushroom_3 | a pair of young button mushrooms in a soil mound |
| [x] | [x] | mushroom_4 | a cluster of plump mushrooms on a mossy log piece — ⚠ original wording silently aborted ChatGPT gen twice (thought 35s → empty response); reworded to 'cluster of three plump brown forest mushrooms growing together on a piece of mossy fallen log' |
| [x] | [x] | mushroom_5 | a hearty mushroom cluster with one big speckled cap, planted |
| [x] | [x] | mushroom_6 | a rich mushroom patch with caps of several sizes |
| [x] | [x] | mushroom_7 | a magnificent fairy-ring of mushrooms with glowing gills |
| [x] | [x] | mushroom_8 | a grand mushroom kingdom on a mossy stump with tiny lanterns and a harvest basket |

### Honey line (NEW — debuts with the beehive, zone 4 / chapter 27) → `res://assets/items/honey_<n>.png` · process: icon 512

Every tier must differ in SILHOUETTE, not just size (lesson from berry_2/flower_2):
golden palette throughout, one new shape element per tier.

| g | w | id | SUBJECT |
|---|---|---|---|
| [x] | [x] | honey_1 | a single hexagonal wax honeycomb cell with one glistening drop of honey |
| [x] | [x] | honey_2 | a small broken piece of honeycomb, three cells, honey oozing from one |
| [x] | [x] | honey_3 | a chunk of golden honeycomb with one tiny bee resting on top |
| [x] | [x] | honey_4 | a small round wax hive nub hanging from a leafy twig, two bees circling |
| [x] | [x] | honey_5 | a squat glass jar full of honey with a wooden dipper resting against it |
| [x] | [ ] | honey_6 | a tidy stack of three honey jars tied with twine, one open with a dipper |
| [x] | [ ] | honey_7 | a wooden hive box with a little roof, flowers at its base, bees in a friendly halo |
| [x] | [ ] | honey_8 | a grand golden hive crowned with wildflowers, honey pots at its base and a gentle glow of circling bees |

## §B — P1 board fixtures

| g | w | id | dest | process | prompt |
|---|---|---|---|---|---|
| [x] | [x] | gen_satchel | `res://assets/ui/gen_satchel.png` | icon 512 | *A worn leather seed satchel with the flap open, small seeds and a sprout peeking out, friendly and well-loved, slight three-quarter angle, chunky game-object silhouette, soft painterly shading, single warm rim light, centered on plain solid white background, generous margin. Square. ⊕CORE* |
| [x] | [x] | bramble_1 | `res://assets/ui/bramble_1.png` | icon 512 | *A light patch of thin twigs and a few leaves loosely covering a board cell, sparse and wispy, flat muted colors, NO rim light, low saturation, reads as terrain not as an item, centered on plain solid white background. Square. ⊕CORE* |
| [x] | [x] | bramble_2 | `res://assets/ui/bramble_2.png` | icon 512 | *A medium tangle of thorny bramble with a few small leaves covering a board cell, clearly denser than thin twigs, flat muted colors, NO rim light, low saturation, terrain not item, centered on plain solid white background. Square. ⊕CORE* |
| [x] | [x] | bramble_3 | `res://assets/ui/bramble_3.png` | icon 512 | *A dense dark thicket of thorny bramble completely covering a board cell, clearly the thickest overgrowth, flat muted colors, NO rim light, low saturation, terrain not item, centered on plain solid white background. Square. ⊕CORE* |
| [x] | [x] | gen_compost | `res://assets/ui/gen_compost.png` | icon 512 | *A friendly wooden compost bin with a slightly open lid, rich dark soil and a tiny mushroom peeking out, well-loved garden object, slight three-quarter angle, chunky game-object silhouette, soft painterly shading, single warm rim light, centered on plain solid white background, generous margin. Square. ⊕CORE* |
| [x] | [x] | tray_grove | `res://assets/ui/tray_grove.png` | decor 1024 1024 --opaque | *(fallback only once tray_grove_tall lands)* Top-down square mossy garden bed mat: soft green moss with tiny clover, a subtle rounded earthen border, completely calm flat and even in the center (game pieces sit on top), no objects, no pockets, flat top-down view, even soft light. Square. ⊕CORE |
| [x] | [ ] | gen_beehive | `res://assets/ui/gen_beehive.png` | icon 512 | *A friendly wooden bee hive box with a peaked little roof and a round entrance hole, a few painted bees hovering nearby and wildflowers at its base, well-loved garden object, slight three-quarter angle, chunky game-object silhouette, soft painterly shading, single warm rim light, centered on plain solid white background, generous margin. Square. ⊕CORE* |
| [x] | [ ] | tray_grove_tall | `res://assets/ui/tray_grove_tall.png` | decor 1080 1440 --opaque | *Top-down TALL mossy garden bed mat (the board now fills the phone edge to edge): soft green moss with tiny clover, completely calm flat and even EDGE TO EDGE — **NO border, NO rim, NO frame baked in** (owner killed the solid edge; the engine feathers the rim itself), no objects, no pockets, no paths, flat top-down view, even soft light. Tall portrait, 3:4. ⊕CORE* |
| [x] | [x] | tray_grove_tall **v2 RE-ROLL** (order U — owner: green items vanish on green moss) | `res://assets/ui/tray_grove_tall.png` (replaces) | decor 1080 1440 --opaque | *(superseded by v3 below — owner 2026-06-12: still too low contrast)* |
| [x] | [x] | tray_grove_tall **v3 RE-ROLL** (order AC) | `res://assets/ui/tray_grove_tall.png` | decor 1080 1440 --opaque | *(LANDED + wired but OVERSHOT — owner: "bland and void of color"; the "desaturated / no texture" wording killed the warmth. Superseded by v4 below.)* |
| [ ] | [ ] | tray_grove_tall **v4 RE-ROLL** (order AF — calm ≠ bleached; match `docs/canon/ref_merge_calm`) | `res://assets/ui/tray_grove_tall.png` (replaces) | decor 1080 1440 --opaque | *Top-down TALL board mat in a soft WARM wheat-cream tone — LIGHT and low-contrast so colorful pieces pop, but WARM and ALIVE: a faint painterly cloth/paper texture (not dead-flat, not uniform), and a gentle soft vignette so the board has form and soft depth toward the edges. NOT grey, NOT desaturated, NOT a flat fill. Calm and even, no hard border or rim or frame baked in. Tall portrait, 3:4. ⊕CORE* |
| [x] | [ ] | fence_grove | `res://assets/ui/fence_grove.png` | decor 1080 220 --opaque --cover | *A weathered wooden garden fence strip seen straight on: two warm horizontal rails on sturdy posts, moss tufts and tiny wildflowers at the base, simple calm storybook woodwork, slightly darker top edge so characters popping up behind it read clearly, no animals, no text, even soft light. VERY WIDE landscape banner (about 5:1 — compose the fence full-bleed along the middle band; the crop takes the band). ⊕CORE* |

## §C — P1 characters (mascot framing — "round character, chest up")

| g | w | id | dest | process | prompt |
|---|---|---|---|---|---|
| [x] | [x] | giver_fox | `res://assets/map/giver_fox.png` | icon 512 | *A friendly round fox character from the chest up, soft fur in gentle painted strokes, big warm amber eyes, a tiny leaf tucked behind one ear, kind expectant smile, three-quarter view, clean character line art over painterly shading, centered on plain solid white background, no text. Square. ⊕CORE* |
| [x] | [x] | giver_hedgehog | `res://assets/map/giver_hedgehog.png` | icon 512 | *A friendly round hedgehog character from the chest up, soft spines like painted grass, rosy cheeks, a tiny acorn cap worn as a hat, shy happy smile, three-quarter view, clean character line art over painterly shading, centered on plain solid white background, no text. Square. ⊕CORE* |
| [x] | [x] | giver_squirrel | `res://assets/map/giver_squirrel.png` | icon 512 | *A cheerful round squirrel merchant character from the chest up, fluffy tail curling behind, wearing a tiny straw hat and a coin pouch on a strap, bright eager eyes, friendly grin, three-quarter view, clean character line art over painterly shading, centered on plain solid white background, no text. Square. ⊕CORE* |

## §D — P1 scenes

| g | w | id | dest | process | prompt |
|---|---|---|---|---|---|
| [x] | [x] | bg_grove_board | `res://assets/ui/bg_grove_board.png` | decor 1080 1920 --opaque | *Looking down a quiet forest clearing's edge: tall sunlit grass and wildflowers framing the left and right, dappled light from an unseen canopy, a soft mossy open space in the middle, drifting pollen motes in the light, very calm and low contrast in the center, ambience not focal point. Tall portrait. ⊕CORE* |
| [x] | [x] | grove_vista | `res://assets/rooms/grove_vista.png` | decor 1920 1080 --opaque | *(SUPERSEDED by map_grove below — owner 2026-06-11: the home is now a free-pan top-down map with placeable POIs, not a side vista. Keep the file; no longer wired.)* |

## §D2 — THE HOME MAP (owner 2026-06-11 — generate these next, top priority)

The home screen is now ONE large draggable top-down map. The land art must be
**EMPTY terrain** — NO buildings, NO water, NO structures — because the zones are
separate POI sprites the code places at `G.ZONES.map_pos` (we choose/move the
spots, and locked POIs render greyed-out in-engine). POIs share one camera: a
**high three-quarter top-down view** (like looking down at a tabletop diorama,
slight angle so buildings show a roof AND a front face).

| g | w | id | dest | process | prompt |
|---|---|---|---|---|---|
| [x] | [x] | map_grove | `res://assets/rooms/map_grove.png` | decor 2160 2880 --opaque | *Seen from high above at a gentle angle, a large empty storybook countryside valley to explore: rolling meadow greens with mowed and wild patches, winding dirt footpaths that fork and wander, low hedgerows, scattered clover and wildflower drifts, a soft treeline closing the edges, small clearings left open and quiet, NO buildings, NO water, NO animals, NO people, NO text, even soft daylight, calm low-contrast painterly ground that game pieces can sit on top of. Tall portrait. ⊕CORE* |
| [x] | [x] | poi_farmhouse | `res://assets/map/poi_farmhouse.png` | icon 512 | *A small old wooden farmhouse with a mossy shingle roof and a crooked stone chimney, seen from high above at a gentle three-quarter angle showing the roof and one warm face, a tiny front step and flower pots, chunky readable game-landmark silhouette, soft painterly shading, centered on plain solid white background, generous margin. Square. ⊕CORE* |
| [x] | [x] | poi_barn | `res://assets/map/poi_barn.png` | icon 512 | *A leaning weathered red barn with faded doors and a hay loft window, seen from high above at a gentle three-quarter angle showing the roof and one face, a few straw wisps at its base, chunky readable game-landmark silhouette, soft painterly shading, centered on plain solid white background, generous margin. Square. ⊕CORE* |
| [x] | [x] | poi_pond | `res://assets/map/poi_pond.png` | icon 512 | *A small calm pond seen from high above, soft blue-green water with painted ripples, a reedy grassy bank all the way around, two lily pads, gentle three-quarter top-down angle, chunky readable game-landmark silhouette, soft painterly shading, centered on plain solid white background, generous margin. Square. ⊕CORE* |
| [x] | [x] | poi_orchard | `res://assets/map/poi_orchard.png` | icon 512 | *A tiny apple orchard: a tight cluster of five round fruit trees with red apples on a grassy patch, seen from high above at a gentle three-quarter angle, chunky readable game-landmark silhouette, soft painterly shading, centered on plain solid white background, generous margin. Square. ⊕CORE* |
| [x] | [x] | poi_meadow | `res://assets/map/poi_meadow.png` | icon 512 | *A wildflower meadow patch with drifts of blooms, one winding flower-lined footpath and a small rose arch, seen from high above at a gentle three-quarter angle, chunky readable game-landmark silhouette, soft painterly shading, centered on plain solid white background, generous margin. Square. ⊕CORE* |

## §E — P1 FX particles (tiny, soft-edged)

Prompt shape: *"A single [SUBJECT], small painted game particle, soft edges,
centered on plain solid white background, generous margin. Square. ⊕CORE"*

| g | w | id | dest | process | SUBJECT |
|---|---|---|---|---|---|
| [x] | [x] | p_petal | `res://assets/fx/p_petal.png` | icon 128 | soft pink-cream flower petal |
| [x] | [x] | p_leaf | `res://assets/fx/p_leaf.png` | icon 128 | small meadow-green leaf |
| [x] | [x] | p_pollen | `res://assets/fx/p_pollen.png` | icon 128 | soft golden pollen mote, glowing faintly |
| [x] | [x] | p_drop | `res://assets/fx/p_drop.png` | icon 128 | round water droplet with one highlight |
| [x] | [x] | p_star | `res://assets/fx/p_star.png` | icon 256 | wobbly hand-painted five-point star, straw gold |

## §F — Audio (prompts live in `AUDIO_PROMPTS.md` §5 — one row per file here)

> **Director note 2026-06-11:** the SFX wave LANDED + was wired (WORK_DONE #24)
> but arrived with NO ART_DONE entries — **audio counts as deliverables: ledger
> every file like an image row.** Sfx rows ticked from eng's wiring evidence;
> ~~the three music beds + `amb_grove` are still MISSING — the artist's next
> item after §I~~ (superseded TWICE: consolidation note below kills the
> per-screen beds; the STALL→OWNER note below moves the two survivors to the
> owner). Audible quality pass = Dev (WITH_AUDIO=1).
>
> **Music RE-SPEC (owner 2026-06-11):** early takes came out fast, complex,
> multi-instrument. Owner law: beds are **near-ambience, not songs** — slow,
> sparse, one instrument + faint drone, no beat/percussion/melody hooks,
> ignorable at low volume ("almost white noise"). Prompts REWRITTEN in
> `AUDIO_PROMPTS.md` §5 — **do not use any §5 music prompt cached from before
> this note, and discard any beds already generated from the old prompts.**
>
> **Music CONSOLIDATION (owner 2026-06-11, same day, supersedes the file
> list):** no per-screen beds. The game plays ONE continuous bed alternating
> two interchangeable takes — `amb_grove1.ogg` + `amb_grove2.ogg` — never
> restarted on screen changes (eng side is order **O** in §INBOX).
> `music_menu` / `music_play` / `music_room` / standalone `amb_grove` are
> DEAD — do not generate. The two takes must share key, loudness, and
> ambience family (they hand off back-to-back); prompts + acceptance test in
> `AUDIO_PROMPTS.md` §5 music table.
>
> **STALL → OWNER (ART_DONE #60–61, pass 3):** the artist thread has NO audio
> generation tool — the two beds went to the OWNER. **RESOLVED same evening:**
> both takes landed (unledgered) as `assets/sfx/amb_grove1/2.mp3` ~19:00 and
> are imported. Order O's arrival amendment moves them to `assets/music/`
> and wires `.mp3` loading — see O2. [g] ticked below from the files on disk;
> [w] = order O.

Specs: SFX mono 44.1k `.wav` ≤0.6s (trim silence, peak −3dBFS); music stereo
`.ogg` seamless loops 45–90s (−16..−14 LUFS); everything in ONE shared key.
After dropping files: `godot --headless --path . --import`

| g | w | file |
|---|---|---|
| [x] | [x] | `assets/music/amb_grove1.ogg` (take A — owner-gen `.mp3`, moved + wired by O2/eng#81) |
| [x] | [x] | `assets/music/amb_grove2.ogg` (take B — owner-gen `.mp3`, moved + wired by O2/eng#81) |
| — | — | ~~`music_menu.ogg` · `music_play.ogg` · `music_room.ogg` · `amb_grove.ogg`~~ DEAD (owner consolidation 2026-06-11) |
| [x] | [x] | `assets/sfx/item_pickup.wav` (grove re-take) |
| [x] | [x] | `assets/sfx/item_drop.wav` (grove re-take) |
| [x] | [x] | `assets/sfx/merge_soft.wav` (grove re-take) |
| [x] | [x] | `assets/sfx/merge_success.wav` (grove re-take) |
| [x] | [x] | `assets/sfx/tidy_poof.wav` (grove re-take) |
| [x] | [x] | `assets/sfx/level_complete.wav` (grove re-take) |
| [x] | [x] | `assets/sfx/button_tap.wav` (grove re-take) |
| [x] | [x] | `assets/sfx/invalid_soft.wav` (grove re-take) |
| [x] | [x] | `assets/sfx/water_pop.wav` (NEW) |
| [x] | [x] | `assets/sfx/bramble_clear.wav` (NEW) |
| [x] | [x] | `assets/sfx/giver_cheer.wav` (NEW) |
| [x] | [x] | `assets/sfx/star_earn.wav` (NEW) |
| [x] | [x] | `assets/sfx/bag_in.wav` (NEW) |
| [x] | [x] | `assets/sfx/bag_out.wav` (NEW) |
| [x] | [x] | `assets/sfx/roof_open.wav` (NEW) |
| [x] | [x] | `assets/sfx/rain_refill.wav` (NEW) |

## §G — Backlog (P2/P3 — DO NOT generate yet; rows get prompts when their phase nears)

- Water/currency HUD icons: water drop, star, acorn-coin, dewdrop-diamond (P2)
- ~~Zone close-ups: farmhouse interior (roof-off) + its 8–10 unlock overlay layers~~ → REAL now: §I (order K) — approach changed to an interior backdrop + PLACED furn sprites, not overlay layers
- Zone exteriors on the vista: barn / pond / orchard / meadow states (P3)
- More animal givers: owl, rabbit, badger, deer… (P3+)
- ~~Additional generators: compost bin, beehive (their item lines too)~~ → REAL now: gen_compost done; gen_beehive + honey line queued above (§A/§B)
- Map-2 teaser postcard art (later)

## §H — THE UI KIT (owner 2026-06-11: tie the whole UI together — spec in GROVE_UI_SPEC.md)

One batch, one chat (consistency matters MORE here than anywhere — these sit on
every screen). **ABSOLUTE RULE: no text, no numerals, no letters in ANY of
these** — every word is engine-rendered. Panels must have calm, even centers
(they stretch as nine-patches; corners stay 96px of a 512 source).

### Panels & furniture → process: decor (sizes below, transparent unless noted)

| g | w | id | dest | size | prompt |
|---|---|---|---|---|---|
| [x] | [x] | panel_parchment | `res://assets/ui/kit/panel_parchment.png` | 512×512 | *A square aged-cream parchment card with a softly hand-painted wobbly edge and a faint paper grain, completely calm flat and even across the whole center (it stretches as a UI nine-patch; all character lives in the outer 96px border), gentle warm tone, no objects, no shadows baked in, no text. Square. ⊕CORE* |
| [x] | [x] | panel_plank | `res://assets/ui/kit/panel_plank.png` | 512×512 | *A square panel of warm weathered wooden planks with a simple carved border frame around the edge, flat and even across the center (UI nine-patch; detail only in the outer 96px), soft painterly wood grain, no nails standing out, no objects, no text. Square. ⊕CORE* |
| [x] | [x] | panel_chip | `res://assets/ui/kit/panel_chip.png` | 384×384 | *A small square deep-ink-green rounded plaque, like a painted wooden tag, soft even dark center (UI nine-patch for tiny stat chips; subtle border character in the outer 72px only), no objects, no text. Square. ⊕CORE* |
| [x] | [x] | btn_leaf | `res://assets/ui/kit/btn_leaf.png` | 512×256 | *A wide rounded pill button shape of fresh leaf green with a delicate stitched border like a sewn leaf, flat and even across the middle (UI nine-patch; ends hold the character), gentle top light, no icon, no text. Wide landscape, 2:1. ⊕CORE* |
| [x] | [x] | btn_round | `res://assets/ui/kit/btn_round.png` | 256×256 | *A small round wooden button like a smooth branch slice with a soft carved rim, calm even center (an icon sprite is composited on top by the engine), no symbol, no text. Square. ⊕CORE* |
| [x] | [x] | ribbon_title | `res://assets/ui/kit/ribbon_title.png` | 768×192 | *A small straw-gold painted banner ribbon with gently folded ends, calm flat center band (the engine writes the title on it), soft painterly shading, no text. Wide landscape, 4:1. ⊕CORE* |
| [x] | [x] | divider_vine | `res://assets/ui/kit/divider_vine.png` | 768×64 | *A very thin horizontal sprig of vine with a few tiny leaves, delicate and calm, used as a divider line inside cards, no text. VERY wide and thin, 12:1 (compose along the center band). ⊕CORE* |
| [x] | [x] | shop_stall | `res://assets/ui/kit/shop_stall.png` | 1024×400 | *A cheerful round squirrel merchant with a tiny straw hat behind the counter of his small wooden market stall with a scalloped awning, paws resting on the counter, warm and welcoming, the counter edge running along the bottom (a UI card attaches beneath it), no goods with writing, no text. Wide landscape banner, about 5:2. ⊕CORE* |

### Icons (the emoji purge — GROVE_UI_SPEC §3) → process: icon 256 · dest `res://assets/ui/kit/<id>.png`

Prompt shape: *"A single [SUBJECT] as a small painted game icon: chunky readable
silhouette at 48px, soft painterly shading, clean simple outline, centered on a
plain solid white background, generous margin, no text. Square. ⊕CORE"*

| g | w | id | SUBJECT |
|---|---|---|---|
| [x] | [x] | icon_star | the Bloomstar — a five-petal flower-star in straw gold (the game's star IS a bloom) |
| [x] | [ ] | icon_coin | **RE-ROLL (owner 2026-06-11: the medallion take reads metal/casino, off-theme — the prompt's fault, it asked for one):** the acorn currency — a single plump golden acorn sitting upright, warm straw-gold with a soft glowing sheen and a neatly textured cap; a NATURAL object like the Bloomstar and the dewdrop, NOT a coin — no medallion, no disc, no gold rim, no metal. Same dest/process (icon 256 → `res://assets/ui/kit/icon_coin.png`); same filename hot-swaps everywhere, then `--import`. Eng `[w]` = one HUD shot showing the acorn in the wallet row |
| [x] | [ ] | icon_gem | **RE-ROLL (owner 2026-06-11: identical read to the water drop):** a faceted dewdrop GEM — a teardrop-CUT crystal in pale violet-blue with crisp facet planes and one bright sparkle glint, unmistakably a cut gem and NOT a plain round water drop. Same dest/process (icon 256 → `res://assets/ui/kit/icon_gem.png`), hot-swaps everywhere, then `--import` |
| [x] | [x] | icon_water | a round water droplet with one soft highlight |
| [x] | [x] | icon_rain | a tiny friendly rain cloud with three falling drops |
| [x] | [x] | icon_cart | a small woven willow basket with a curved handle |
| [x] | [x] | icon_gear | a daisy seen straight on whose petals read like gentle gear teeth |
| [x] | [x] | icon_check | a checkmark shaped from a single fresh green leaf |
| [x] | [x] | icon_lock | a small warm wooden padlock with a tiny sprout growing from the keyhole |
| [x] | [x] | icon_question | a question mark carved from light wood |
| [x] | [x] | icon_home | a tiny farmhouse with a mossy roof, simple silhouette |
| [x] | [x] | icon_back | a left-pointing arrow shaped from a folded leaf |
| [x] | [x] | icon_level | a young sprout inside a thin painted ring |
| [x] | [x] | icon_cash | a neatly folded large leaf resembling a banknote, tied with twine |

## §I — INTERIORS, SPIRITS, WEATHER, MAP v2 (owner 2026-06-11 — orders K/L/M)

**⚠ ORIGINALITY RULE for spirits:** these evoke beloved film-spirit FEELINGS but
must be ORIGINAL designs — never name studios/films/characters in prompts (law),
and re-roll anything that reads as a copy of a known creature silhouette.

### Farmhouse interior v2 (order Q — prove the pattern here, other zones follow)

**⚠ PLACEMENT LAW (TIDY_UP_V2_SPEC §0c #11, owner screenshot 2026-06-11) —
binding for THIS and every future zone's close-up art:** unlockables are
FLOOR-standing sprites (+ at most ONE wall-hung picture per room);
architecture (hearth/fireplace, stalls, lofts, doors, windows) is BAKED into
the room background, never an unlockable sprite; the canvas OUTSIDE the room
cutaway shows the surrounding garden/grounds — NEVER plain white.

**ROOM CAMERA v2 (owner 2026-06-12 — v1 was too soft, generators drifted to
eye-level product shots; paste verbatim wherever a prompt carries the ROOM
CAMERA token — every FLOOR-standing `furn_*` sprite; the one wall-hung
picture per room is the EXCEPTION and is drawn nearly frontal, see its
row):** *a bird's-eye three-quarter view looking steeply DOWN at the object
from high above, as if photographed from a tall ladder standing beside it —
the object's TOP surface is the LARGEST visible face and its front face is
small and strongly foreshortened, matching a dollhouse room seen from above;
NOT a side view, NOT an eye-level product shot, NOT a catalog angle; soft
daylight from the upper right*

**FURN ACCEPTANCE (owner law 2026-06-12, before ledgering ANY `furn_*`
take):** open the processed take BESIDE the zone's `int_*.png` backdrop —
if the top face is not dominant the way that room's floor demands, the
object cannot sit on the floor: **RE-ROLL.** The prompt claiming the camera
is not acceptance; the side-by-side is. (This is how chair/wheel v2 passed
while being unplaceable.)

| g | w | id | dest | process | prompt |
|---|---|---|---|---|---|
| [x] | [x] | int_farmhouse **v2 RE-ROLL** | `res://assets/rooms/int_farmhouse.png` (replaces landed v1 — v1's surround was white) | decor 1080 1440 --opaque | *Looking down into a cozy old farmhouse room with the roof lifted away, high gentle angle: warm wooden floorboards, stone walls, soft light from a window opening, and a warm stone FIREPLACE with a small fire built INTO the left wall (part of the room itself); the wooden floor otherwise EMPTY and open (the game places every furnishing), one calm bare patch of wall left clear (a framed picture will hang there); the window sits in the RIGHT wall so daylight falls from the upper right (every furniture sprite is lit that way); OUTSIDE the room's walls the canvas shows the cottage garden seen from above — grass, a dirt path, flowerbeds — never white, never blank; NO loose furniture, NO people, no text. Tall portrait, 3:4 — CONTAIN-fit in-game; compose nothing critical within 4% of the edges; if the generator only does 2:3, compose the garden full-bleed with the top/bottom ~6% expendable and add `--cover` to the process call (the plain letterbox pad is near-white — it would re-violate this row's own law). ⊕CORE* |
| [x] | [x] | furn_fh_bed **RE-ROLL** | `res://assets/rooms/furn_fh_bed.png` (replaces — v1's POV clashed with the room) | icon 512 | *A cozy wooden bed with a patchwork quilt in meadow colors, ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [x] | furn_fh_table | KEEP the landed art | — | owner flagged white in the leg gaps — that's eng's hole-punch (order Q2), NOT a re-roll |
| [x] | [x] | furn_fh_rug | KEEP the landed art | — | flat piece, angle-tolerant |
| [x] | [x] | furn_fh_chair **RE-ROLL** | `res://assets/rooms/furn_fh_chair.png` (replaces landed v1, ART_DONE #31 — generated pre-ROOM-CAMERA) | icon 512 | *(v2 landed but FAILED in situ — eye-level POV + white in the slats; superseded by v3 below)* |
| [x] | [ ] | furn_fh_chair **v3 RE-ROLL** (order AE3 — landed ART_DONE #103, punched) | `res://assets/rooms/furn_fh_chair.png` (replaces) | icon 512 + punch | *A well-loved wooden rocking chair with a knitted blanket over one arm, ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_fh_wheel **v2 RE-ROLL** (order AE3 — landed ART_DONE #104, punched) | `res://assets/rooms/furn_fh_wheel.png` (replaces) | icon 512 + punch | *A wooden spinning wheel with a small stool base and a tuft of wool, ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [x] | furn_fh_chest | `res://assets/rooms/furn_fh_chest.png` | icon 512 | *A sturdy wooden storage chest with a rounded lid and simple iron bands, ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [x] | furn_fh_plant | `res://assets/rooms/furn_fh_plant.png` | icon 512 | *A leafy potted fern in a simple clay pot standing on the floor, ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [x] | furn_fh_wheel | `res://assets/rooms/furn_fh_wheel.png` | icon 512 | *A wooden spinning wheel with a small stool base and a tuft of wool, ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [x] | furn_fh_picture | `res://assets/rooms/furn_fh_picture.png` | icon 512 | *A small framed painting of a sunny meadow in a simple wooden frame, drawn nearly frontal with the slightest downward tilt (it hangs on a wall), chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| — | — | ~~furn_fh_hearth · furn_fh_shelf · furn_fh_lamp · furn_fh_window~~ | | | DEAD (placement law): the hearth is baked architecture; shelf/lamp/window were shelf- or wall-mounted. ALL FOUR landed (ART_DONE #24-32) — eng deletes all four files (+`.import`s) in Q3 |

**UNPARKED 2026-06-12 (owner: "the barn is also empty"):** the farmhouse v2
pattern is proven (Q done) — the remaining four zones generate NOW, one zone
per batch (consistency within a zone), barn → pond → orchard → meadow.
File convention (already wired, K1): backdrop `res://assets/rooms/int_<zone>.png`
· furnishings `res://assets/rooms/furn_<spot_id>.png` — sprites auto-load by
path. Eng side = order AD. Positions are HUMAN-placed (spec §0c #12).

**OUTDOOR CLOSE-UP variant (pond/orchard/meadow — paste where a prompt
carries the OUTDOOR token):** *a bird's-eye three-quarter view looking
steeply DOWN from high above, the ground filling the frame, soft daylight
from the upper right; the scene is FULL-BLEED ground (no cutaway, no
surround) with calm OPEN patches of short grass left empty where objects
will be placed* — the backdrop must NOT bake any of its own unlockables
(each row lists them), and every OUTDOOR `furn_*` take obeys the same
TOP-FACE-DOMINANT rule and FURN ACCEPTANCE side-by-side as ROOM CAMERA v2
(judged against this zone's `int_*.png`).

### Barn close-up (interior — ROOM CAMERA; architecture baked per order Q)

| g | w | id | dest | process | prompt |
|---|---|---|---|---|---|
| [x] | [ ] | int_barn | `res://assets/rooms/int_barn.png` | decor 1080 1440 --opaque | *Looking down into a cozy old barn with the roof lifted away, high gentle angle: worn plank floor dusted with straw, weathered red-brown wooden walls; BAKED architecture — empty animal stalls along the LEFT wall, a hay loft edge across the top, and the big barn doors standing open in the RIGHT wall so daylight falls from the upper right; the floor otherwise EMPTY and open (the game places every furnishing); OUTSIDE the walls the canvas shows the farmyard from above — dirt, grass tufts, a bit of fence — never white, never blank; NO loose furniture, NO hay bales, NO animals, NO people, no text. Tall portrait, 3:4 — CONTAIN-fit in-game; nothing critical within 4% of the edges; if the generator only does 2:3, compose the farmyard full-bleed with top/bottom ~6% expendable and add `--cover`. ⊕CORE* |
| [x] | [ ] | furn_bn_bales | `res://assets/rooms/furn_bn_bales.png` | icon 512 | *Two stacked golden hay bales with loose straw wisps, ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_bn_stool | `res://assets/rooms/furn_bn_stool.png` | icon 512 | *A three-legged wooden milking stool with a small tin pail beside it, ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_bn_churns | `res://assets/rooms/furn_bn_churns.png` | icon 512 | *A cluster of three tin milk churns with lids, one slightly tilted, ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_bn_trough | `res://assets/rooms/furn_bn_trough.png` | icon 512 | *A long wooden water trough with clear water and one floating leaf, ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_bn_lantern | `res://assets/rooms/furn_bn_lantern.png` | icon 512 | *A warm glowing lantern hanging from its own free-standing wooden floor post (floor-standing object, nothing wall-mounted), ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_bn_cart | `res://assets/rooms/furn_bn_cart.png` | icon 512 | *A small two-wheeled wooden hay cart with a little hay inside, ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_bn_coop | `res://assets/rooms/furn_bn_coop.png` | icon 512 | *A small wooden hen coop with a ramp and one round hen peeking out, ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_bn_plow | `res://assets/rooms/furn_bn_plow.png` | icon 512 | *An old single-handle wooden plow with a worn iron blade, lovingly weathered, ROOM CAMERA, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |

### Pond close-up (OUTDOOR — must NOT bake: dock, lily pads, reeds, bench, stepping stones, willow, boat, jar)

| g | w | id | dest | process | prompt |
|---|---|---|---|---|---|
| [x] | [ ] | int_pond | `res://assets/rooms/int_pond.png` | decor 1080 1440 --opaque | *OUTDOOR. A calm round pond of soft blue-green water filling the middle, clean grassy banks all the way around with open level patches at the water's edge, painted ripples, the water surface calm and OPEN (objects will float on it later); NO reeds, NO lily pads, NO dock, NO boat, NO stones, NO bench, NO trees at the bank, NO animals, no text. Tall portrait, 3:4; 2:3 contingency with `--cover` as int_barn. ⊕CORE* |
| [x] | [ ] | furn_pd_dock | `res://assets/rooms/furn_pd_dock.png` | icon 512 | *A tiny weathered wooden dock of a few planks on stub posts, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_pd_lilies | `res://assets/rooms/furn_pd_lilies.png` | icon 512 | *A cluster of three lily pads with one pink blossom, seen from high above, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_pd_reeds | `res://assets/rooms/furn_pd_reeds.png` | icon 512 | *A tuft of tall green reeds with two brown cattails, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_pd_bench | `res://assets/rooms/furn_pd_bench.png` | icon 512 | *A mossy wooden garden bench, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_pd_stones | `res://assets/rooms/furn_pd_stones.png` | icon 512 | *A short curving run of five flat stepping stones, seen from high above, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_pd_willow | `res://assets/rooms/furn_pd_willow.png` | icon 512 | *A young willow tree with gracefully drooping fronds, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_pd_boat | `res://assets/rooms/furn_pd_boat.png` | icon 512 | *A little wooden rowboat with two oars resting inside, seen from high above, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_pd_fireflies | `res://assets/rooms/furn_pd_fireflies.png` | icon 512 | *A glass jar on a little tree stump glowing softly with fireflies inside, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |

### Orchard close-up (OUTDOOR — must NOT bake: sapling rows, ladder, baskets, press, hives, swing, scarecrow, wagon; mature trees only at the EDGES)

| g | w | id | dest | process | prompt |
|---|---|---|---|---|---|
| [x] | [ ] | int_orchard | `res://assets/rooms/int_orchard.png` | decor 1080 1440 --opaque | *OUTDOOR. A sunny orchard clearing: short tended grass with a few fallen apples, mature apple trees ONLY along the outer edges framing the scene, the whole middle ground OPEN and level (the game places everything there); NO young trees in the middle, NO ladders, NO baskets, NO beehives, NO swing, NO scarecrow, NO wagon, NO animals, no text. Tall portrait, 3:4; 2:3 contingency with `--cover` as int_barn. ⊕CORE* |
| [x] | [ ] | furn_or_rows | `res://assets/rooms/furn_or_rows.png` | icon 512 | *A short double row of four young apple saplings in tidy dirt beds, seen from high above, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_or_ladder | `res://assets/rooms/furn_or_ladder.png` | icon 512 | *A free-standing wooden A-frame orchard ladder (stands on its own, leans on nothing), OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_or_baskets | `res://assets/rooms/furn_or_baskets.png` | icon 512 | *Two woven baskets heaped with shiny red apples, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_or_press | `res://assets/rooms/furn_or_press.png` | icon 512 | *A small wooden cider press with a turn-screw and a jug beneath the spout, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_or_hives | `res://assets/rooms/furn_or_hives.png` | icon 512 | *A pair of friendly wooden beehive boxes with little roofs, a few painted bees hovering, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_or_swing | `res://assets/rooms/furn_or_swing.png` | icon 512 | *A rope swing with a wooden seat hanging from its own simple free-standing wooden A-frame (placement law: stands on its own, attaches to nothing), OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_or_scarecrow | `res://assets/rooms/furn_or_scarecrow.png` | icon 512 | *A friendly smiling scarecrow with a straw hat and patched coat on a sturdy ground post, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_or_wagon | `res://assets/rooms/furn_or_wagon.png` | icon 512 | *A wooden farm wagon loaded with crates of apples, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |

### Meadow close-up (OUTDOOR — must NOT bake: flower path, picnic, kite, BRIDGE, stand, garden patch, telescope, rose arch; the BROOK is baked architecture)

| g | w | id | dest | process | prompt |
|---|---|---|---|---|---|
| [x] | [ ] | int_meadow | `res://assets/rooms/int_meadow.png` | decor 1080 1440 --opaque | *OUTDOOR. A gentle wildflower meadow: flower drifts at the outer edges, big open patches of soft grass through the middle (the game places everything there), and ONE narrow painted brook crossing the lower-left corner with clean grassy banks (a bridge is placed over it later — bake NO bridge); NO rose arch, NO paths, NO blankets, NO structures, NO animals, no text. Tall portrait, 3:4; 2:3 contingency with `--cover` as int_barn. ⊕CORE* |
| [x] | [ ] | furn_md_path | `res://assets/rooms/furn_md_path.png` | icon 512 | *A short winding garden path segment of pale stones lined with tiny wildflowers (flat ground piece), seen from high above, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_md_picnic | `res://assets/rooms/furn_md_picnic.png` | icon 512 | *A red-checkered picnic blanket with a woven basket and two cups (flat ground piece), seen from high above, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_md_kite | `res://assets/rooms/furn_md_kite.png` | icon 512 | *A cheerful diamond kite tethered to a small wooden ground stake, resting tilted against it with its ribbon tail curling onto the grass (placement law: grounded, not flying), OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_md_brook | `res://assets/rooms/furn_md_brook.png` | icon 512 | *A small arched wooden footbridge with simple rails, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_md_stand | `res://assets/rooms/furn_md_stand.png` | icon 512 | *A tiny wooden lemonade stand with a striped awning, a pitcher and two cups on the counter, NO lettering on the blank sign, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_md_garden | `res://assets/rooms/furn_md_garden.png` | icon 512 | *A tiny fenced secret-garden patch with a little gate and overflowing flowers inside, seen from high above, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_md_telescope | `res://assets/rooms/furn_md_telescope.png` | icon 512 | *A small brass stargazing telescope on a wooden tripod, tilted toward the sky, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |
| [x] | [ ] | furn_md_arch | `res://assets/rooms/furn_md_arch.png` | icon 512 | *A wooden garden arch wrapped in climbing roses, free-standing, OUTDOOR camera, chunky readable silhouette, soft painterly shading, centered on plain solid white background, generous margin, no text. Square. ⊕CORE* |

### Spirit folk (order L) → `res://assets/map/spirit_<id>.png` · process: icon 256

Original designs — see the originality rule above; re-roll lookalikes.

Prompt shape: *"A single [SUBJECT], a small gentle nature spirit as a painted
game character, round friendly silhouette readable at 64px, soft painterly
shading, centered on plain solid white background, generous margin, no text.
Square. ⊕CORE"*

| g | w | id | SUBJECT |
|---|---|---|---|
| [x] | [ ] | spirit_puff | a tiny drifting SEED spirit shaped like a dark dandelion seed-head, charcoal-grey downy fluff with two warm amber eyes and wispy little limbs |
| [x] | [ ] | spirit_moss | a small spirit hidden under a thick shaggy moss cloak that hides its whole body shape, a single oversized leaf drooping over it as a hat, shy bright eyes peeking from under the moss |
| [x] | [ ] | spirit_acorn | a tiny seedling spirit wearing an acorn cap, sprout-tail behind, cheerful |
| [x] | [ ] | spirit_lantern | a gentle wisp spirit with a trailing tadpole-like tail body (clearly non-humanoid), carrying a tiny glowing mushroom like a lantern, faint warm glow |

### Porter & wayside props (orders Y/Z) — same prompt shapes as their tables

Porter: spirit-folk prompt shape + originality rule. Waysides: icon 512,
ground-standing objects seen from high above (map view), plain white bg.

| g | w | id | dest | process | SUBJECT |
|---|---|---|---|---|---|
| [x] | [ ] | spirit_porter | `res://assets/map/spirit_porter.png` | icon 256 | a small busy errand spirit with a big woven wicker pack-basket on its back nearly as large as itself, round friendly body, tiny quick feet, cheerful and industrious |
| [x] | [ ] | way_lantern | `res://assets/map/way_lantern.png` | icon 512 | a rustic wooden lantern post with a warm glowing lamp, seen from high above |
| [x] | [ ] | way_birdbath | `res://assets/map/way_birdbath.png` | icon 512 | a small stone bird bath with clear water, seen from high above |
| [x] | [ ] | way_flowertub | `res://assets/map/way_flowertub.png` | icon 512 | a half-barrel tub overflowing with wildflowers, seen from high above |
| [x] | [ ] | way_bench | `res://assets/map/way_bench.png` | icon 512 | a mossy wooden garden bench, seen from high above |
| [x] | [ ] | way_skep | `res://assets/map/way_skep.png` | icon 512 | a small woven straw beehive skep on a wooden stand, seen from high above |
| [x] | [ ] | way_cairn | `res://assets/map/way_cairn.png` | icon 512 | a friendly stack of smooth rounded stones with a tuft of flowers at its base, seen from high above |

### Weather particles (order L) — prompt shape: as §E particles

| g | w | id | dest | process | SUBJECT |
|---|---|---|---|---|---|
| [x] | [ ] | p_rain | `res://assets/fx/p_rain.png` | icon 128 | a single thin slanted rain streak, soft edges, pale blue |
| [x] | [ ] | p_snow | `res://assets/fx/p_snow.png` | icon 128 | a single soft six-point snowflake, slightly wobbly hand-painted |

### Map v3 (order M — owner REJECTED v2: landforms must RECEIVE props, not be scenery)

| g | w | id | dest | process | prompt |
|---|---|---|---|---|---|
| [x] | — | ~~map_grove_v2~~ | (landed, ART_DONE #39) | | owner eyeball verdict: the "dry hollow" generated as a CRATER (unusable under a flat pond prop) and anchors sit in busy growth — superseded by v3 below |
| [x] | [ ] | map_grove_v3 | `res://assets/rooms/map_grove.png` (replaces) | decor 2160 2880 --opaque --cover | *Seen from high above at a gentle angle, a storybook countryside valley of soft meadows connected by winding dirt paths, with FIVE calm flat clearings of short quiet grass and packed earth spaced comfortably apart along the paths — each clearing plain, gently worn, and completely FLAT and uncluttered (game buildings are placed on top of them later), one clearing slightly damp-looking with a few reeds at its rim (a pond overlays here); NO craters, NO pits, NO steep banks, NO dense flowerbeds at the clearings, NO buildings, NO water, NO animals, NO people, no text; calm even daylight; painterly ground that game pieces sit on top of. Tall portrait, 3:4 — if generating 2:3, keep the top and bottom ~6% expendable and no clearing inside the crop band. ⊕CORE* |
| [x] | [ ] | poi_meadow **RE-ROLL** | `res://assets/map/poi_meadow.png` (replaces — owner: reads as a floating cut-out disc) | decor 1024 1024 | *A small flowery meadow garden with a rose arch and a winding path, seen from high above, whose grassy edges FEATHER OUT into thin scattered grass tufts and petals so it blends into any lawn it is placed on — soft irregular outer edge fading to transparent, NEVER a hard cut or a raised earth rim, no text. Square. ⊕CORE* |

> v3 anchor NOTE (carry of the v2 lesson): the generator will NOT respect
> position fractions — that's fine and EXPECTED. Generate good clearings
> anywhere sensible; eng re-fits `G.ZONES.map_pos` TO the painted clearings
> after the owner approves (M's box). Do not re-roll for placement alone.


---

## DONE log — Director pass 4 (reconciled 2026-06-12 · WORK_DONE #84–92 · ART_DONE #75–104)

<details><summary>AB, AC, AE1, the placement tool + live fixes — and the pond/orchard/meadow art wave</summary>

- **AB** — the quest fence goes FRAMELESS (eng#89, merge 300f44c): `_bust`
  rewritten — the chest-up cutout IS the element (~124px, no Panel/border),
  idle bob behind flag **`giver_bob`**; the band-filling parchment card →
  content-sized cream ask PILL under each giver (the anatomy X3 extends);
  "+N★" to the bust's shoulder; ready = a check docked on the pill corner
  (ring deleted); merchant parity; +20 asserts (grove 234). Slots left clear
  for AA2/S2.
- **AC** — the CALM pass (eng#90–92): item_backing default OFF (#90), light
  background veil + the S3 bramble warm-lift shader (#91), top-bar → cream
  pill (#92). **⚠ PARTLY SUPERSEDED THE SAME DAY by order AF** — the v3 tray
  prompt + the `#EAF0DC@0.62` veil over-corrected into "bland and void of
  color" (owner), and AC4's fill-flip left the dark world-outline → illegible
  HUD font. AF re-warms the board, lifts the veil to a hue-keeping soften,
  re-grounds the pieces, and fixes the font (AF6). KEPT from AC: the frameless
  fence (AB), the bramble warm-lift (S3), the cream-pill DIRECTION (AF tunes,
  doesn't revert). **Lesson recorded in the calm-law note (AF area): a
  calm-pass change must re-check what the changed value was PAIRED with.**
- **AE1** — hole-punch all landed furn (eng#88): every `furn_*` punched,
  8 had enclosed white; fh_chair/wheel clean+intact. AE2–4 (in-situ POV
  sheet, the chair/wheel re-rolls now landed, arrival law) stay OPEN.
- **The PLACEMENT TOOL** (owner-direct #86, spec §0c #12) — `scripts/layout.gd`
  (id-keyed override layer; renderers read `map_pos`/`pos`/`fsize` through it;
  persists `data/placements.json`; **21-test `layout_tests.gd`, verified
  21/21 this pass**) + `scripts/debug.gd` (PRODUCTION default / DEBUG editor,
  headless-inert) + the in-map editor (drag buildings, enter rooms, drag/
  resize furniture, 💾 save). **This is what makes spec §0c #12 real** — the
  owner authors every placement; agents only set provisional defaults.
- **Owner-direct live fixes** (#85, #87): music console-spam (deferred
  add_child/play), water-chip vs Lv-chip overlap (stacked 64px below),
  Decorate button transparent on the fence (solid StyleBoxFlat pill), a latent
  grove Lv-label crash (S10 store gap); plus placement-tool reachability
  (meadow/orchard sat under HUD chips → chrome hidden in place mode; locked
  zones enterable+draggable in debug). All headless-inert; full sweep green.
- **ART wave** (ART_DONE #75–104, committed 5981ef6): pond + orchard + meadow
  close-ups (3 OUTDOOR backdrops + 24 furnishings, one md_garden re-roll) +
  the fh_chair v3 / fh_wheel v2 re-rolls (ROOM CAMERA v2 + punched). Barn
  (#65–74) folded in pass 3-era. §I rows ticked [g]; [w] = order AD per zone.

</details>

## DONE log — Director pass 3 (reconciled 2026-06-11 · WORK_DONE #36–83 · ART_DONE #40–61)

<details><summary>20 orders archived (full order text lives in the eng CLAIM snapshots in WORK_DONE.md + git history)</summary>

- **⚡E / A / B / C / D** — spend-stars input swallow + honest click tools +
  store inline + one price const + shop/HUD test gaps (`fix/inbox-spend-stars`
  batch; STAGE1+2 PASS).
- **F** — diegetic spend-star flow: scatter-on-land + inline customize strip —
  eng#1–4, merge 00ac3bd.
- **H** — board-mat corner retune (thin warm soil edge) — eng#6–7.
- **G-UI** — kit API + storefront + component sweep + aspect matrix —
  eng#11–15, merge 13ec6d8 (art-arrival residual closed by order I).
- **I** — §H kit art wire-verified on every screen; FOUND+fixed: the home item
  pins had no icon swap point (eng#15 overclaim) — eng#17–19, merge 7d8209f.
- **J** — bramble ground-tile z-order (`move_child` 0→1) + structural parity
  test — eng#21–23, `fix/inbox-j`.
- **K** — zone interiors (takeover view, one-input-surface law, OS-back, shot
  tooling) — eng#26–29, merge 8031d90; the K4 spot re-fit landed as eng#44
  (merge 34dd7b2) when the art arrived.
- **L** — ambient spirits + weather (stateless wall-clock layer, hourly
  schedule, win-back rain, calm-wins) — eng#32–34, merge d4240da.
- **N** — `scripts/features.gd` (17 flags) + retrofit guards + flip smokes —
  eng#37–41, merge 8ddc1ab. **Dispositions:** FLAGS as `static var` —
  sanctioned (N3 said eng's call). `interior_view` stays UNFLAGGED — Director:
  it is load-bearing navigation now (T/Q build on it; flag-off would soft-lock
  spot buying) → recategorized `core` in FEATURES.md. The N-after-K/L
  ordering note — acknowledged; retrofit outcome identical. The water chip's
  own staged_chrome term (eng#38 deviation) — accepted, within
  `ftue_staged_chrome`'s intent.
- **P** — drag-to-SWAP behind `drag_swap` (merge keeps precedence; displaced
  node glides; swap shot mode) — eng#63–65, merge 63ca797. **Disposition:**
  the skipped CLAIM (eng#66, self-flagged) is accepted this once — order text
  was stable + boxes quoted in the commit; rule 4b stands unchanged.
  click_gate landing Home not Grove (eng#64 note) — expected: the gate IS the
  Decorate button; e2e coverage of the jump now lives in `click_decorate.gd`
  (T4).
- **R** — the pixel-right law: assert_wraps/assert_centered + crop tooling;
  wallet plank root-cause (texture opaque band ≠ layout rect — the asserts
  passed while it LOOKED wrong, which is why the law pairs asserts WITH crops);
  zone-pin plank; R4 chip/pin sweep + level-chip evenness — eng#52–57, merges
  8c3b070 + c21a014. **Dispositions:** the "How to verify" one-liner is pasted
  above (eng#52 flag); R4's heavy composites — RE-DISPOSITIONED 2026-06-12 (S's
  boxes never covered three of the five): fence cards → AB2/AB5 · ladder →
  AB5 · bag → AC3 · shop rows/price chips → S12/S14 (in flight) · gate
  button → AA2 (its rect asserts ARE the absorption). Each element still
  touched exactly once.
- **U** — board contrast: `item_backing` under-ellipse (U1) + warm
  earth-and-straw tray v2 wired (U2 [w]) — eng#60–61, merge 907fe30.
  Owner pick → SUPERSEDED 2026-06-12 by order AC (the warm tray judged
  still too low-contrast): tray v3 + `item_backing` default OFF (AC2);
  owner re-picks from the AC2 crops.
- **T** — Decorate jumps INTO the last-decorated room (persisted `last_zone`;
  pre-frame interior open, no map flash; map CTA path unchanged) + interior
  "to the board" CTA in the map CTA's exact slot (tap resolves against the
  laid-out node's own rect) + NEW `tools/click_decorate.gd` 3/3 — eng#68–71,
  merge e641c41, grove 195. CLAIM honoured at pickup. **Disposition:** no
  flag is correct (nav/core — matches the `interior_view` ruling above);
  `Home.decorate_zone` as a process-scoped one-shot static — accepted.
- **M** — map v3: five flat clearings (artist, one re-roll for a sky band) +
  `map_pos` snapped to MEASURED clearing centroids (dirt/grass classify →
  erode paths → blob cores; method documented in the content comment) +
  `fullmap` shot mode — eng#74, merge 9e89334, /tmp/m_fullmap.png.
  **Dispositions:** eng treated the owner's "placement still not correct" as
  approval-to-fix and re-fit without the explicit eyeball — accepted (the
  gate's PURPOSE was to not waste a re-fit on rejected art; the art on disk
  IS v3, ART_DONE #51, so eng#74's "if a v3 repaint lands later" caveat is
  moot). Owner now eyeballs the COMPOSITE (gate above). Z2's wayside
  placement is now unblocked by M (plots go on the clearings' edges).
- **Q** — interior PLACEMENT LAW + farmhouse v2, FULLY done: Q1 content swap
  + idempotent save migration in Save.grove() (a37ac28, eng#46) · Q2
  `tools/cutout_holes.gd` hole-punch (a37ac28, eng#47) · Q3 all 8 spot pos
  re-fit onto the v2 painted plots, the 4 dead sprites DELETED (verified
  gone), bed POV ✓ (1219f9d, eng#76) · Q4 proof set + click_spot e2e on
  fh_chest (eng#77). **Bonus root-cause accepted (eng#76, in scope): owned
  furn sprites rendered at full 512px since K — expand/stretch now precede
  size; footprint is per-spot `fsize` DATA.** The interior now reads as a
  real furnished room — this is the PATTERN the other zones' close-up art
  follows (§I note stands).
- **O** — ONE continuous ambient playlist: music.gd two-take A↔B alternation
  on `finished` (ogg > mp3 > wav per take), idempotent ensure(), play(bed)
  deleted, all SIX call sites swapped (Music.play grep = zero), owner's mp3
  beds moved sfx→assets/music (no transcode, stale imports removed), 9
  state-not-sound tests — eng#80–82, merge db93cd9, grove 204. **Remaining
  acceptance is the OWNER's audible walk (gate above).** Eng#83's "M residual
  awaits v3 art" queue note — already dispositioned at the M entry (the map
  on disk IS v3; nothing residual).
- **Standing fixes** — `tools/quiet_godot.sh` signal traps + stale-override
  reclaim + foreign-file refusal (eng#42); interior back affordance + Esc +
  dark-tap exit + `force_draw` on ALL 7 shot tools (stale-frame class killed)
  — eng#43, merge 13c39a3; boot SELF-HEAL (eng#73, merge 9e89334): a normal
  launch (TU_QUIET unset) deletes our leftover override.cfg, un-minimizes and
  restores focus/border — leaks and mid-capture launches now cost the owner
  nothing (owner confirms on next launch).
- **Art wave ART_DONE #40–61** — tray v2 · acorn `icon_coin` · faceted
  `icon_gem` · `int_farmhouse` v2 + 6 furn · map v3 (one re-roll) +
  `poi_meadow` re-roll · `spirit_porter` · 6 waysides. `amb_grove1/2`
  STALLED → re-assigned to the owner (§F).

</details>

## DONE log — `feat/zone-lids-hud-shop` batch (merged `787b08b`, 2026-06-11)

<details><summary>1 — Zones are CHESTS with lids (owner: placement that blends)</summary>

- [x] Closed zone node: building + name + one status line (locked "✿ after %s" ·
      open "✿ %d★ left" · done "✿ restored") — verified in `/tmp/lids_fresh.png`
      (farmhouse "✿ 31★ left", pond "✿ after The Barn", real map art landed)
- [x] Open zone node: lid-open panel in place listing ALL spots as rows with
      state pins (✿N★ / Lv N / ✓ + variant swatch); rows in `spot_hits`;
      art thumb clipped to its frame (the sliver artifact fix)
- [x] Focus flow: one lid at a time; pan centers; land tap closes; locked tap
      wobbles with the requirement floater
- [x] Lid-open juice: scale-y 0.12→1 `TRANS_BACK` 0.22s + `roof_open` audio
- [x] i18n `✿ %d★ left`; tests (closed=empty rows, focus=8 rows, stars-left 31,
      unfocus empties, buy-while-focused works) — grove suite 123
- [x] `tools/home_shot.gd` closeup/progress focus the farmhouse
- [x] Visual acceptance at 1080×1920 — no HUD/CTA overlap

</details>

<details><summary>2 — Shared top-bar module</summary>

- [x] `scripts/hud.gd`: ★🪙💎 cluster + 🛒 Store, consumed by BOTH scenes;
      home passes blob-writing `water_grant`, grove fills live water; home's
      diamonds stay live via the module `refresh` in `_update_hud`
      *(leftovers: overlap check + anchor tests → INBOX B/D)*

</details>

<details><summary>3 — Board mat juice back</summary>

- [x] Pixel-space rounded mask (`rect_size`/`radius_px 26`/`feather_px 8`),
      under-panel pop (border + shadow), light rim catch, tan border still
      cropped via AtlasTexture — verified in `/tmp/mat_juice.png`

</details>

<details><summary>4 — The Shop</summary>

- [x] `scripts/shop.gd`: pure grants (`buy_water`, `buy_coin_pack`,
      `grant_cash_pack`) + storefront + cash confirm ("test build — nothing is
      charged"), disabled-by-affordability rows, rebuilt balances after buys
- [x] i18n rows; tests (insufficient refuse / success balances / cash grant /
      water spend / open smoke on grove); storefront screenshot
      *(leftovers: price const, §6b section, confirm shot, home smoke → INBOX C/D)*

</details>

<details><summary>Final gate (that batch)</summary>

- [x] Full sweep green: core 4 · save 32 · map 19 · quest 20 · grove 123 ·
      engine 6 · smoke 10 · sim PASS; merged `--no-ff` as `787b08b`
- [x] Map art wave wired+verified the same day: `map_grove` + 5 POIs ([w] ticked
      in ART_CHECKLIST §D2)

</details>
