# Asset intake — runbook

How to take a raw image from "dropped in a folder" to "processed, renamed, filed." Design +
rationale: `docs/superpowers/specs/2026-06-18-asset-intake-design.md`.

**The split:** *you* (the agent) make every judgment — classify, name, pick params. The scripts do
every pixel op and every file move. Same plan + same source → identical result.

## When to run

Raw art lands in `games/grove/assets/_originals/new/` whenever the artist drops it. Nothing watches
the folder. When the Dev says "pick up the new art" (or similar), run this loop.

## The loop

1. **List the drop.** `ls games/grove/assets/_originals/new/`. Artists often deliver a pair:
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
     games/grove/assets/_originals/new/bag_asset.png /tmp/peek/cell_
   ```

   `slice_islands` prints `n -> x,y wxh (px=count)` top→bottom, left→right. Open the `/tmp/peek/cell_<n>.png`
   files, decide which islands to keep and what to call each.

4. **Write the plan** as `<name>.plan.json` next to the raw in `_originals/new/`. Schema:

   ```json
   {
     "source": "_originals/new/bag_asset.png",
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
   - `matte`: add `"inner": "<category>"`; `params.min_area` controls the keyer.
   - `scene`: just `{ "source": "...", "category": "scene" }` — the runner prints a hand-off.
   - `archive` is where the raw moves after success (under `_originals/<kind>/`).

5. **Apply it.** `make intake` (all pending plans) or `make intake PLAN=<file>` (one). The runner
   writes the outputs, **moves** the raw to `archive`, moves the plan to `new/_processed/`, and
   reimports. On any tool failure it **skips** that plan and leaves the raw in place for a retry.

6. **Verify.** Confirm the outputs landed (`ls` the target folder), the raw is gone from `new/`, and
   the plan is in `new/_processed/`. For in-engine checks use `make shot-grove` / `make shot-map`.
   Keep `make test` green.

## Principles

- Scripts never guess. If you find yourself wanting the runner to "figure out" a name or a category,
  that belongs in the plan — author it there.
- Raws are archived, never deleted.
- Map scenes stay with the §16 pipeline; don't try to automate the share-gate.
