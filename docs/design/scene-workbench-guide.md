# Scene workbench (`make sw`) — building a picture-book scene

A guide for an agent composing or fine-tuning one of the picture-book scenes (Fairy Hollow, Snowy
Village, Desert Oasis, Coral Reef, Cherry-Blossom Garden) with the scene-placement workbench. The
workbench edits a bundle's `metadata/placements.json` in place; the game and the bundle's own
`compose_reconstruction.py` read the same file, so what you place here is the scene.

Code map: `games/grove/tools/scene_workbench.gd` (launcher) · `scene_workbench_view.gd` (window)
· `scene_workbench_model.gd` (PURE ops — use it directly for scripted edits) · gated by
`games/grove/tests/grove_scene_workbench_tests.gd`.

## 1 · The bundle contract

A scene is a **bundle directory**: `<scene>_elements_v<N>/` under the scenes root. The workbench
opens the highest `v<N>` that carries `metadata/placements.json`.

```
<scene>_elements_v2/
  01_backdrop/…        02_terrain/…       03_structures/…
  04_garden_items/…    05_dressing/vegetation_pack/…  05_dressing/rock_pack/…
  09_reconstruction/   metadata/placements.json       00_style/…
```

- Element art: one keyed PNG per element, named `<scene>_<element>_v<N>.png`, nested anywhere
  under the numbered dirs. (Asset discovery — `M.addable_assets` — skips `00_style/`,
  `09_reconstruction/`, `metadata/`, any `references/` dir, and files containing `_raw`,
  `_review`, `montage`, or `contact`; **category** = the top dir minus its `NN_` prefix,
  refined by a `*_pack` subdir. The in-tool add palette was removed 2026-07-18 — new elements
  enter via `M.add_entry` scripted edits or by hand in placements.json, then `R` reloads.)
- **Scenes root**: the launcher scores every candidate root (repo copy, mocks worktree — relative
  and absolute) and opens the one with the MOST openable scenes, so a partially-intaken repo copy
  never shadows the full set; `ROOT=` overrides. The repo copy of
  `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1`, falling back to
  the codex mocks worktree (`.worktrees/codex-ui-redesign-rush-maps-mocks/...`). `ROOT=<dir>`
  overrides. New bundles land through the art intake workflow (see `art-style-guide.md`).

**Bootstrapping a brand-new scene**: create the dirs above plus a minimal
`metadata/placements.json` — the workbench opens an empty scene fine:

```json
{
 "schemaVersion": 2,
 "scene": "snowy_village_v1",
 "canvas": {"width": 1320, "height": 2346, "anchorConvention": "center-bottom"},
 "base": {"id": "foundation", "image": "<repo-relative path to the foundation png>", "opaque": true, "z": 0},
 "placements": []
}
```

## 2 · The placement schema (what a save writes)

Each entry in `placements`:

| key | meaning |
|---|---|
| `id` | unique in the file (the tool de-duplicates as `name_2`, …) |
| `image` | **repo-relative** PNG path (resolved against the root that contains `games/`) |
| `x`, `y` | the **CENTER-BOTTOM anchor** on the canvas (top-left origin) — items stand on `y` |
| `w`, `h` | drawn size in canvas px (aspect is locked by the tool's resize) |
| `z` | paint order (higher = on top; ties keep list order) |
| `cluster` | optional group tag — the unit of selection (absent = a one-item unit) |
| `category`, `layer` | descriptive; preserved but not behavioral |

Unknown keys on the doc or entries round-trip untouched. Saves write `.json` with a one-time
sibling `placements.json.bak` (the pre-session state). Never hand-edit the JSON while the
workbench is open — press `R` in the tool to reload instead.

**Z-band convention** (follow cherry v2 so scenes stay consistent):
`0` base · `10–19` environment (mountains, horizon) · `100s` rear props + their contacts ·
`200s` terrain surface + its contacts · `250–420` hero props (structures, garden items) + contacts
· `500+` foreground occluders.

## 3 · Clusters are the unit of work

Model rule: **a scene is a set of clusters**. Every hero thing is a cluster of its element plus
its grounding — e.g. a tent = `tent` + surrounding rocks + vegetation + its shadow, all tagged
`"cluster": "tent_camp"`. Backdrop layers (mountains, foundation-wide vegetation) stay untagged.

- A stage **click selects the whole cluster**; drag moves it, wheel resizes it about its footing,
  `Z`/`X` restack it with relative z preserved.
- **Isolation** (`I`, or `make sw … CLUSTER=<name>`): the rest of the scene ghosts; clicks now
  pick individual members for fine placement.
- **The sidebar is cluster-driven**: selecting a cluster expands its MEMBER rows — click one to
  select that single item (drag/wheel/arrows act on just it), press its `✕` to remove it — and
  below them the ICONED add palette scoped to that cluster: clicking an asset drops a new member
  at the cluster's footing (top of its z band), joined and selected for immediate placement.
  (Recovered bundles feed the palette from the surviving page art.)
- `Alt+click` force-picks a single item without isolating. `Esc` exits isolation / deselects.
- **Shift+click paints membership**: with a cluster in context (selected or isolated), Shift+click
  any item — even ghosted scenery — to toggle it in/out of the cluster; with only a single item
  selected, Shift+click a second item to birth a new cluster from the pair.
- `N` makes a new cluster from the selected single; a selected cluster shows a **rename field**
  in the sidebar (type + Enter — members re-tag, collisions unique-ify).

**Building a new cluster**: select the hero item → `N` (or Shift+click the second piece) → `I` to
isolate → Shift+click the surrounding rocks / vegetation into the cluster → wheel + drag each
member into place → `Esc`, then place the whole cluster.

## 4 · The loop (interactive)

```bash
make sw SCENE=cherry_blossom_garden          # or any scene in the dropdown
make sw SCENE=desert_oasis CLUSTER=oasis_pool  # open isolated on one cluster
```

1. Pick the scene (dropdown switches in place; unsaved edits auto-save first).
2. Rough-place clusters, back to front, respecting the z bands.
3. Isolate each cluster and fine-tune members (arrows nudge 1px, Shift 10).
4. `⌘S` saves. The header shows `UNSAVED` until you do.

## 5 · Agent verification (headless — never steal focus)

Never open a visible window to check work. The quiet screenshot path is born-minimized:

```bash
make shot-sw SCENE=<scene> [CLUSTER=<name>] OUT=/tmp/scene.png
```

Render the shot, **look at it**, and compare against the bundle's
`09_reconstruction/*_reconstruction_*.png` (the composition authority). For scripted edits, skip
the UI entirely — drive `scene_workbench_model.gd` headless (`load_doc` / `add_entry` /
`set_cluster` / `move_cluster` / `scale_cluster` / `bump_cluster_z` / `save_doc`); it enforces
id uniqueness, the grabbable-size floor, and the backup. After tool changes run
`make test-fast`; the workbench suite runs in the full `make test` sweep.

## 6 · Gotchas

- `x,y` anchor the **bottom-center** — placing by top-left will sink items by their height.
- A cluster's downward restack floors the LOWEST member at z 0 (relative order survives).
- Clearing a cluster tag erases the key — files without clusters stay byte-identical.
- Missing art still occupies its rect (select it via the sidebar, not the stage).
- Coral/desert `v2` bundles have no `placements.json` yet — the tool opens their `v1`; add a
  minimal placements file to a `v2` (schema above) to start composing it.

## 7 · Shipping a scene to the game

The game renders each page from a GENERATED zone manifest — after fine-tuning in `make sw`:

```bash
python3 games/grove/tools/build_page_manifests.py   # placements.json -> assets/map/pages/* + manifests
make import                                         # import the copied element art
make test-fast                                      # grove_page_manifest_tests guards the wiring
```

`grove_data._build_maps()` names the five pages; `map.gd` renders the current page's manifest and
adds the page-turn chevrons. The first page carries the interim farmhouse build items until the
pages build system lands. Verify with a real in-game render:
`engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/map_shot.gd -- fresh /tmp/page.png page=<scene id>`.

## 8 · The reference column

The left column (sidebar-width) shows ONE reference at a time; a dropdown picks among the
scene's mocks — the root-level `<scene>*.png` images plus the bundle's `09_reconstruction`
composites. The original AI mocks died with the codex worktree (2026-07-18);
`bake_scene_composites.py` bakes a faithful `_baked_composite` + `_baked_props_only` pair per
scene from the live placements — re-run it after big composition changes so the references
track the scene.
