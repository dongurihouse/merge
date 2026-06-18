# Asset intake — design

**Date:** 2026-06-18
**Scope:** A repeatable process to take a raw image from "dropped in a folder" to "processed,
renamed, and filed in the right place." Splits the work cleanly: an **agent** makes every
judgment call (classify, name, choose params), and **deterministic scripts** do every pixel
operation and every file move. Operationalizes the user's rule: *each script simple and
deterministic; non-deterministic actions done by agents; agent instructions live in the project
root.*

This is the **intake half** of the existing art pipeline (`docs/design/grove_art_pipeline.md`),
which covers generation + hook-up but not a standard "new image → filed" loop.

## Decision summary

| Question | Decision |
|---|---|
| Decision-to-execution shape | **Manifest-driven.** Agent authors a per-drop `plan.json`; one deterministic runner applies it. The plan is the audit trail and is replayable. |
| Where agent instructions live | New project-root `CLAUDE.md` (auto-loaded) with a short trigger → full runbook in `docs/design/asset-intake.md`. |
| Raw disposition after processing | **Archive, never delete** — raw moves `_new/ → _originals/<category>/`, matching the `_originals` keep-the-source convention. |
| Map scenes | **Stay agent-driven** (the §16 box-detection + share-gate are perceptual). The runner does their mechanical steps; the agent supplies/verifies boxes. |
| Drop-folder watching | **None.** Nothing watches the folder; an agent is explicitly directed to pick up the new art. |

## 1 · The drop convention

- **Drop zone:** `games/grove/assets/_new/` (already exists; currently holds the
  `bag*`/`shop*` raws). The user or artist drops raw PNGs here at any time. Nothing watches it.
- **Pair recognition:** the artist often returns a pair — `X.png` (composed reference look, usually
  *not shipped*) and `X_asset.png` (a transparent sheet of the individual pieces, irregularly
  placed). The agent treats `*_asset.png` as the sliceable source and bare `X.png` as
  reference-only, unless the drop says otherwise.
- **Filenames are freeform.** The agent classifies from the **pixels** (it opens the image with the
  Read tool, which renders it), using the filename only as a hint.

## 2 · The manifest (`<name>.plan.json`) — the only non-deterministic artifact

When directed to pick up the new art, the agent inspects each drop and writes a sibling plan file
in `_new/`. The plan captures every judgment so the runner needs none.

```json
{
  "source": "_new/bag_asset.png",
  "category": "sheet",
  "params": { "threshold": 0.05, "min_area": 400 },
  "outputs": [
    { "island": 3, "name": "nav_bag",   "path": "ui/kit/nav_bag.png",   "post": "icon:512" },
    { "island": 0, "name": "panel_bag", "path": "ui/kit/panel_bag.png" }
  ],
  "archive": "_originals/ui/bag_asset.png"
}
```

**Field reference**

| Field | Meaning |
|---|---|
| `source` | path (under `games/grove/assets/`) of the raw being processed |
| `category` | one of the taxonomy values in §3 |
| `inner` | required only when `category` is `matte`: the taxonomy value to re-dispatch to after the background is keyed out (see §3) |
| `params` | category-specific knobs (size, canvas `W`/`H`, grid `rows`/`cols`, `threshold`, `min_area`) |
| `outputs` | the deterministic targets. For single-output categories: one entry `{ "path": "...", "post": "..." }`. For `grid`: one entry per tile (or a `name_template` + tile order). For `sheet`: one entry per kept island, keyed by `island` index. |
| `outputs[].post` | optional follow-up op on a produced PNG, e.g. `icon:512` (run `process_icon` at size 512 after slicing) |
| `archive` | where the raw moves after a successful run (under `games/grove/assets/`) |

Paths are relative to `games/grove/assets/` (= `ART_ROOT`, `game.gd:7`), so the plan reads the same
way the engine loads art.

## 3 · The category taxonomy

Each category maps to a tool that **already exists** in `games/tools/`.

| `category` | What it is | Deterministic tool | Default folder |
|---|---|---|---|
| `icon` | one subject; trim + center + square transparent PNG | `process_icon.gd` | `ui/` |
| `decor` | bg/layer; position preserved, fit to a fixed canvas | `process_decor.gd` | `rooms/` |
| `grid` | LLM icon-sheet (band-detected, not uniform) | `slice_grid.gd` → `process_icon` per tile | `items/` |
| `sheet` | irregular transparent/checkerboard island sheet (the `*_asset.png`) | `slice_islands.gd` → island→name map | `ui/kit/` |
| `scene` | map locale; §16 multi-phase pipeline | **handed off** — not pixel-processed by the runner; the §16 map flow in `grove_art_pipeline.md` owns it | `map/` |
| `matte` | raw with a bright/white background baked in | `cutout_bg.gd` (clears bright+achromatic regions) **then** re-dispatch to the inner category | (inner) |

**`matte` is a prefix, not a leaf.** A `matte` plan carries an inner category (e.g.
`"category": "matte", "inner": "icon"`): the runner keys out the background first, then runs the
inner category's tool on the result.

**`scene` is handed off, not pixel-processed by the runner.** The §16 pipeline's box-detection and
the §9 share-gate are perceptual calls, and the existing map tools (`process_map1v2.py`, the
cutout/recompose steps in `grove_art_pipeline.md`) already own map slicing. So when a drop is a map
scene, the runner recognizes the `scene` category and prints a one-line hand-off to the §16 flow
rather than slicing it. Building the full scene cut/recompose into the runner is deferred (YAGNI) —
nothing today needs it, and folding it in would push a perceptual call into a script. This keeps the
runner small and keeps the perceptual judgment with a brain (§5).

This taxonomy is **images only** — no audio, no animation flipbooks (those follow their own paths
in the existing pipeline doc). If a new art class appears that none of these fit, the agent parks
it back to the Dev rather than forcing a category (§5).

## 4 · The deterministic runner — `make intake`

A thin orchestrator (`games/tools/intake_apply.py`, pure-stdlib Python) wired as a Makefile target.
It dispatches to the godot image tools via subprocess and does the file moves itself. For each
`*.plan.json` in `_new/` (or one named plan via `make intake PLAN=<file>`):

1. **Dispatch** by `category` to the tool in §3, passing the plan's `params`.
2. **Write `outputs`** to their target paths, applying any per-output `post` step.
3. **Archive** the raw: move `source` → `archive` (move, never delete).
4. **Log** the plan: move the applied `*.plan.json` → `_new/_processed/`.
5. **Reimport:** run the equivalent of `make import` so Godot picks up the new art.
6. **Summarize:** print one line per output (`wrote ui/kit/nav_bag.png  (512×512)`).

The runner contains **no classification and no naming** — it is a pure function of
`(plan, source pixels)`. Re-running the same plan against the same source produces identical
outputs (idempotent), which is what makes it safe to replay and easy to verify.

**Failure handling:** if a tool fails or a target path's parent doesn't exist, the runner aborts
that plan **before** archiving the raw (so the raw stays in `_new/` for a retry) and prints the
error. Other plans in the batch still run.

## 5 · Division of labor

The load-bearing principle. Everything that needs a brain is the agent's; everything mechanical is
a script's.

**Agent (non-deterministic):**
- Open each drop and **classify** it into a category.
- Choose **target names** and the **destination folder**.
- Choose **params** (icon size, decor canvas `W×H`, grid `rows×cols`, slice `threshold`/`min_area`).
- For `sheet`s: run the slicer once into a scratch dir, read the printed `index → bbox` list,
  eyeball the tiles, and assign each kept island a name.
- For `scene`s: supply/verify the object boxes and sign off the §9 share-gate.
- Write the `plan.json`. **Park** anything ambiguous (unrecognizable class, unclear naming) back to
  the Dev instead of guessing.

**Scripts (deterministic):**
- Every pixel operation (trim, center, resize, slice, key, cut, recompose).
- Every file operation (write outputs, rename, archive the raw, log the plan, reimport).
- Zero guessing — they read the plan.

## 6 · Where the instructions live

- **New project-root `CLAUDE.md`** — a short trigger, auto-loaded by Claude Code each session:

  > **Asset intake.** Raw art lands in `games/grove/assets/_new/`. When asked to process
  > intake / "pick up the new art," follow `docs/design/asset-intake.md`: classify each drop,
  > author a `plan.json`, run `make intake`, verify, archive. Scripts are deterministic; all
  > judgment (classification, naming, params) goes in the plan.

  (This is the project's first root `CLAUDE.md`; it can grow other project pointers later. It does
  not duplicate the global `~/.claude/CLAUDE.md`.)

- **`docs/design/asset-intake.md`** — the full operational runbook the trigger points to:
  - The classify → plan → `make intake` → verify → archive loop, step by step.
  - The §3 taxonomy table (look → category → tool → folder) as a classification aid.
  - The §2 manifest schema with a worked example per category.
  - The `scene` special-case (when to hand back to the §16 pipeline in `grove_art_pipeline.md`).
  - The park-it-back-to-Dev rule for ambiguous drops.

## 7 · Verification

- **Per output (automated):** reuse the existing checks — alpha-over-magenta (no halos/scraps),
  subject-not-eaten, correct dims, transparent where expected. Run after `make intake`.
- **Sheets:** confirm the island→name mapping by overlaying the printed bboxes (never trust the raw
  slice blindly — the `slice_islands` bbox print exists for exactly this).
- **Scenes:** the §16 round-trip recompose-diff is the built-in correctness check; the Dev eyeballs
  the share-gate.
- **In-engine:** `make shot-grove` / `make shot-map` to see the new art placed.
- **Regression:** `make test` stays green (intake only adds files + edits data/`tex` paths where a
  hook-up is needed).

## 8 · What this reuses vs. builds

**Reuses (already in `games/tools/`):** `process_icon.gd`, `process_decor.gd`, `slice_grid.gd`,
`slice_islands.gd`, `cutout_bg.gd` (bright-bg keyer), `make import`, `make shot-*`. (The map-scene
keyers `cutout_map1_asset.py` / `process_map1v2.py` stay owned by the §16 flow.)

**Builds:**
1. `games/tools/intake_apply.py` — the manifest runner (§4), pure-stdlib Python that dispatches to
   the godot tools and does the file moves.
2. `make intake` target in the `Makefile`.
3. `docs/design/asset-intake.md` — the runbook (§6).
4. Project-root `CLAUDE.md` — the trigger (§6).
5. `_new/_processed/` — the applied-plan log dir (created on first run).

## 9 · Risks

- **Mis-classification.** The agent picks the wrong category → wrong tool. Mitigation: the taxonomy
  table is small and tool-aligned; the park-it-back rule covers the unclear cases; the plan is
  reviewable before `make intake` runs.
- **Sheet island drift.** Island indices shift if the slicer's threshold changes. Mitigation: the
  plan pins `threshold`/`min_area`, and naming is by verified bbox, not a guessed index.
- **Scene automation temptation.** Trying to fully automate `scene` would push a perceptual call
  into a script. Mitigation: §3 keeps scenes agent-driven by design.
- **Raw loss.** A bug could delete a raw. Mitigation: the runner **moves to archive**, never
  deletes, and aborts a plan before archiving on any failure.
