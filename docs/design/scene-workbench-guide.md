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

## 9 · Deconstructing a source mock

The best source is one coherent full-scene mock where the camera, palette, lighting, and object
scale already agree. Deconstruction means turning that mock into a clean foundation plus separate
runtime-controllable sprites without losing the feeling that everything was painted together.

**First pass rules**

- Store the untouched source under `00_source/` or, for review-only concepts, under
  `games/grove/assets/_concepts/zones/` with the prompt beside it.
- Record source-space object bounds in `metadata/source_bounds.json`. Those boxes are the first
  placement truth: scale them from source size to the 1320 x 2346 canvas, then convert from
  top-left boxes into center-bottom anchors for `placements.json`.
- Keep v1/v2/v3 bundles side-by-side. Never overwrite an accepted bundle while trying a new
  decomposition.
- Do not generate a full batch before checking one visible round trip: foundation + one hero
  object + grounding. If that looks forced, fix the method before making the remaining assets.

**Foundation rules**

- The foundation is stable scenery only: water/sky, ground or sand, paths, cliffs, ledges,
  low terrain markings, and other non-runtime surfaces.
- Do not bake in objects that should move, unlock, animate, be replaced, receive collision, or
  layer independently: buildings, shipwrecks, chests, statues, plants, signs, fences, gates,
  foreground occluders, reward props, bubbles, or UI.
- If the source geometry matters, prefer localized editing/patching over a full-scene redraw.
  A full redraw can preserve the general style while drifting ledge shape, perspective, usable
  platforms, and object sockets.
- Keep usable placement surfaces large enough for the intended objects. A beautiful ledge that
  cannot hold the sprite without overlap is not a usable foundation.

**Sprite extraction rules**

- Generate or edit sprites as if extracting from the source: preserve silhouette, direction,
  proportion, palette, paper grain, printed mottling, and lighting. Only reconstruct small
  occluded parts when needed.
- Use one-by-one generation for large, wide, tall, identity-sensitive, or direction-sensitive
  objects. Shipwrecks, houses, statues, large trees, bridges, gates, and kelp beds do not belong
  in square prop packs.
- Use compact prop packs only for small related dressing: pebbles, tufts, small corals, flowers,
  debris, barrels, or small rocks. Do not mix hero props with tiny dressing in one pack.
- Raw sprite generations use a flat `#FF00FF` background, then chroma cleanup to RGBA. Validate
  transparent corners, non-empty alpha, and zero visible magenta-like pixels.
- Be careful with despill: it can desaturate purple/blue/lavender assets into gray. If palette
  loss appears, redo the matte without despill or with a tighter edge contract.
- Avoid baked floors, grass pads, sand pads, heavy drop shadows, and scenic bases around sprites.
  They create the "pasted on" or "forced to be put there" feeling.

**Grounding rules**

- Grounding should be separate cluster members, not baked into the hero sprite: soft contact
  shadows, small grass/seaweed tufts, pebble strips, flower patches, sand dust, or edge dressing.
- Shadows must match the scene material and light. Prefer soft watercolor/contact shadows in the
  local palette over dark black slabs.
- Use environmental trims to integrate edges: grass around houses, pebbles around underwater
  props, snow mounds around cabins, blossom petals around garden objects. Generate these as small
  reusable sprites where possible.
- Roads, stepping stones, fences, and other alignment-sensitive paths should be separate terrain
  or strip assets. Do not bake them into a hero object unless the object always owns that path.

**Atmosphere rules**

- Atmosphere layers can be full-scene or tall overlays: bubbles, light shafts, haze, drifting
  specks, mist, snowfall, petals, or dust. Keep them low contrast enough to belong to the
  background.
- Match color to the foundation. For example, underwater bubbles should sit close to the water
  color and often need reduced alpha; bright white bubbles read like stickers.
- Animated candidates should remain separate layers: bubbles, clouds, snow, petals, water glints,
  and light rays.

## 10 · Reconstructing and judging the scene

`metadata/placements.json` is the scene authority. The flat reconstruction is only a QA artifact,
but it is the fastest way to catch bad extraction, bad placement, or bad grounding.

**Placement rules**

- Convert every placement to center-bottom anchors: `x = left + w/2`, `y = top + h`.
- Keep related pieces in clusters. A hero object should usually be a cluster containing the object
  plus its shadow/tufts/pebbles/contact trim. Move and scale the cluster first; isolate only for
  fine adjustment.
- Use z bands consistently: atmosphere/environment behind, contact shadows immediately below their
  object, hero props in the 250-420 range, foreground occluders at 500+.
- Keep source-facing directions unless there is a strong design reason to change them. A chest,
  shell, building, or ship facing the wrong way breaks the illusion faster than a small scale error.

**Pasted-on checks**

Reject or revise when:

- the sprite has its own floor pad, grass island, sand island, or heavy dark bottom shadow;
- the road/path does not lead to the object entrance;
- the object base does not match the ledge, slope, or perspective beneath it;
- the object palette is sharper, duller, warmer, or colder than the foundation;
- paper grain/noise density differs enough that the object reads from another source;
- bubbles, haze, or glows are too bright compared with the backdrop;
- the final scene feels crowded enough that the main gameplay spaces are hard to read.

**Checkpoint order**

1. Show the source mock or concept mock.
2. Show the foundation-only pass.
3. Show one hero-object reconstruction with grounding.
4. Generate simple-to-fancy variants for critical hero objects if direction is uncertain.
5. Add remaining hero props.
6. Add small dressing and atmosphere.
7. Run the deterministic compositor and `make shot-sw`; inspect the actual images before calling
   the scene done.

**Verification**

- Parse every JSON file touched.
- Check foundation/reconstruction dimensions are `1320 x 2346`.
- Check sprite PNGs are RGBA, have transparent corners, and no visible magenta-like fringe.
- Run the bundle's `09_reconstruction/compose_reconstruction.py` when present.
- Run:
  ```bash
  make shot-sw SCENE=<scene> ROOT=<picturebook_scene_mocks_v1 root> OUT=/tmp/<scene>_sw.png
  ```
  Then look at the screenshot. It must open the intended highest-version bundle, show the expected
  clusters, and keep palette entries limited to addable production assets.
- Move raw, rejected, old checkpoint, and crop/reference PNGs under `references/`, `00_source/`,
  `09_reconstruction/`, or filenames containing `_raw`, `_review`, `montage`, or `contact` so
  they do not clutter the addable palette.
