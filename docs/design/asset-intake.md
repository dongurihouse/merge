# Asset intake — runbook

How to take a raw image from "dropped in a folder" to "processed, renamed, filed." Design +
rationale: `docs/superpowers/specs/2026-06-18-asset-intake-design.md`.

**The split:** *you* (the agent) make every judgment — classify, name, pick params. The scripts do
every pixel op and every file move. Same plan + same source → identical result.

## When to run

Raw art lands in `games/grove/assets/_new/` whenever the artist drops it. Nothing watches
the folder. When the Dev says "pick up the new art" (or similar), run this loop.

## The loop

1. **List the drop.** `ls games/grove/assets/_new/`. Artists often deliver a pair:
   `X.png` (composed reference, usually not shipped) + `X_asset.png` (a sheet of the pieces). Treat
   `*_asset.png` as the sliceable source.

2. **Open each image and classify it** into one `category`. Paths below are relative to
   `games/grove/assets/`.

   | Look | `category` | Tool | Default folder |
   |---|---|---|---|
   | one subject, want a clean square icon | `icon` | `process_icon.gd` | `ui/` |
   | a background / layer, keep its position | `decor` | `process_decor.gd` | `rooms/` |
   | an even sheet of items (a line's tiers) | `grid` | `slice_grid.gd` → `process_icon` | `items/` |
   | an irregular sheet of UI pieces | `sheet` | `slice_islands.gd` | `ui/kit/` |
   | a map locale | `scene` | **hand off** to the §16 flow (`grove_art_pipeline.md`) | `map/` |
   | any of the above but on a baked white/bright background | `matte` (+ `inner`) | `cutout_bg.gd` then the inner tool | (inner) |

   If it fits none of these, **park it back to the Dev** — do not force a category.

3. **For `sheet`/`grid`: slice once to scratch and read the indices** before naming. The runner
   uses the same indices, so this is how you map index → name:

   ```
   godot --headless --path . -s res://games/tools/slice_islands.gd -- \
     games/grove/assets/_new/bag_asset.png /tmp/peek/cell_
   ```

   `slice_islands` prints `n -> x,y wxh (px=count)` top→bottom, left→right. Open the `/tmp/peek/cell_<n>.png`
   files, decide which islands to keep and what to call each.

4. **Write the plan** as `<name>.plan.json` next to the raw in `_new/`. Schema:

   ```json
   {
     "source": "_new/bag_asset.png",
     "category": "sheet",
     "params": { "min_area": 400 },
     "outputs": [
       { "island": 3, "name": "nav_bag",   "path": "ui/kit/nav_bag.png", "post": "icon:512" },
       { "island": 0, "name": "panel_bag", "path": "ui/kit/panel_bag.png" }
     ],
     "archive": "_originals/ui/bag_asset.png"
   }
   ```

   - `icon`/`decor`: one `outputs` entry (`{ "path": "..." }`); put size/canvas in `params`
     (`{"size": 512}` or `{"w":1024,"h":1280,"opaque":true}`).
   - `grid`/`sheet`: one entry per kept slice, keyed by `tile`/`island` index; add `"post": "icon:512"`
     to clean each slice into a square icon.
   - `matte`: add `"inner": "<category>"`. Bright/white baked background → `params.min_area` tunes the
     keyer. **Saturated colour** background (e.g. the cyan UI sheets) → add `"key": "#RRGGBB"` (+ optional
     `"tol"`, default 0.18); the runner chroma-keys it transparent, then the inner `sheet`/`icon` slices
     it. Sample the colour from a corner pixel; bump `tol` if a colour fringe survives.
   - `scene`: just `{ "source": "...", "category": "scene" }` — the runner prints a hand-off.
   - `archive` is where the raw moves after success (under `_originals/<kind>/`).

5. **Apply it.** `make intake` (all pending plans) or `make intake PLAN=<file>` (one). The runner
   writes the outputs, **moves** the raw to `archive`, moves the plan to `_new/_processed/`, and
   reimports. On any tool failure it **skips** that plan and leaves the raw in place for a retry.

6. **Verify.** Confirm the outputs landed (`ls` the target folder), the raw is gone from `_new/`, and
   the plan is in `_new/_processed/`. For in-engine checks use `make shot-grove` / `make shot-map`.
   Keep `make test` green.

## Principles

- Scripts never guess. If you find yourself wanting the runner to "figure out" a name or a category,
  that belongs in the plan — author it there.
- Raws are archived, never deleted.
- Map scenes stay with the §16 pipeline; don't try to automate the share-gate.

## Pre-baked texture polish (`make bake-textures`)

Separate from intake. At runtime the UI kit's `clean_tex_path()` (in `games/grove/tools/ui_workbench_kit.gd`)
polishes a sprite — defringe + alpha-feather — the first time it's drawn. That's a per-pixel GDScript pass:
cheap per icon, but a dialog draws a dozen at once and froze its open for ~0.7s. The bake runs the **exact
same** `_clean_image()` offline and ships the polished result, so the runtime just `load()`s it.

**Auto-discovery — no manifest.** `make bake-textures` builds every kit dialog headless (via
`BakeTargets.build_all` in `games/tools/bake_targets.gd`, with demo data + the real config opts), which
drives `clean_tex_path` for each sprite the dialogs draw. The cache then holds the exact `(path, max_dim)`
set, and the bake writes each to a `baked/<subpath>@<cap>.png` mirror under `assets/`. `clean_tex_path` loads
that mirror when present; if absent it falls back to the live polish (correct, just the old hitch).

- **The baked PNGs are committed**, alongside their `.import` sidecars, like any other shipped art. The source
  PNGs stay un-polished, so the bake is idempotent (always re-bakes from source).
- **A guard test** (`engine/tests/kit_bake_tests`) builds every dialog and fails if any sprite it polishes
  is un-baked — so a new or changed dialog can't silently re-introduce the first-open freeze.

**When you add or change a sprite, or add a dialog:**

1. Land the source PNG (the normal intake loop for new art, or just replace the file).
2. If you added a **new top-level dialog**, add one line for it to `BakeTargets.build_all`. Existing dialogs
   and the sprites they already draw need nothing — discovery finds them.
3. Run `make bake-textures`, then commit the regenerated `baked/*.png` (+ `.import`).
4. Forget step 3? `make test` fails the guard and names the un-baked sprites. Until you bake, the sprite still
   renders correctly — it just live-polishes on first open. It's a performance bake, never a correctness gate.
