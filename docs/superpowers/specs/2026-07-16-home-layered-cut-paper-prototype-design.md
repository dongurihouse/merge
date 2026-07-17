# Layered Cut-Paper Home Prototype — Design Spec

**Date:** 2026-07-16
**Scope:** Standalone visual workbench only; the shipped Home renderer is unchanged.
**Direction:** Selected Direction B, a saturated cut-paper playground.

## Outcome

Produce a reviewable layered Home composition made from one foundation image and seven independently placed structure sprites. The preview must prove that the structures can be removed, restored, moved, or replaced without exposing hard rectangular seams or looking pasted onto the landscape.

## Pipeline

- `map_mode`: `scene_mode`
- `visual_model`: `layered_raster`
- `runtime_object_model`: `separate_props`
- `collision_model`: `none` for this visual prototype
- `engine_target`: project-native Godot `Control` scene
- `visual_asset_source`: built-in image generation, followed only by deterministic resizing, chroma-key removal, cropping, and composition

## Canvas and anchors

- Art canvas: exactly `941x1672`, matching the current Farm Home plate.
- Preview viewport: `1080x1920`; the art canvas scales uniformly and remains centered.
- Every prop uses a center-bottom anchor: `x` is the horizontal center and `y` is the bottom of the rendered sprite in map pixels.
- The preview sorts structures by `sort_y`, which equals the base `y` unless explicitly overridden.

## Foundation-only background

The base contains the permanent landscape: saturated cyan sky, layered hills, edge trees and shrubs, ground grass, small low flowers, and a winding path. It contains no farmhouse, shed, flower box, well, fenced kitchen garden, doghouse, lantern, restore badge, dashed outline, UI, text, or baked shadow belonging to a removable structure.

The ground may include broad, natural variations in grass tone where structures will sit, but it must not contain obvious empty circular pads. The path must still make spatial sense when every structure is hidden.

## Shared cut-paper structure contract

All seven structure sprites follow one contract:

- One connected opaque silhouette on transparent output.
- Bright cut-paper color blocking, subtle paper fiber, and low internal detail.
- Mostly front-facing three-quarter view with the same top-left lighting direction.
- A connected irregular turf skirt around the structure base, occupying roughly 8–16% of the sprite height.
- The turf skirt carries only a few large attached grass tufts, leaves, stones, or flowers. No loose fragments.
- A soft down-right contact shadow falls only onto the opaque turf skirt; no shadow extends into transparency.
- A narrow dark-green/navy cut edge outlines the combined turf silhouette. No white sticker halo.
- Full sprite remains inside the source canvas with generous flat-magenta margin before keying.
- No labels, restore numbers, dashed outlines, UI, watermark, glow, particles, or detached FX.

## Structure manifest and initial placement

| id | structure | x | y | display size | role |
|---|---|---:|---:|---:|---|
| `fh_hearth` | farmhouse with porch | 470 | 700 | 520x483 | primary landmark |
| `fh_larder` | small storage shed | 805 | 700 | 250x253 | right-side landmark |
| `fh_boxes` | raised flower-box cluster | 165 | 975 | 260x202 | compact garden prop |
| `fh_kitchen` | fenced vegetable garden | 680 | 1080 | 500x370 | wide ground structure |
| `fh_well` | roofed stone well | 190 | 1330 | 310x320 | lower-left landmark |
| `fh_lantern` | timber lantern post and small gate feature | 805 | 1410 | 210x227 | narrow right-side prop |
| `fh_porch` | small doghouse | 600 | 1510 | 240x215 | lower landmark |

These are review defaults, not shipped tuning. The standalone scene exposes per-prop visibility and guide toggles so placement can be judged before any live integration.

## Workbench behavior

`HomeLayerWorkbench.tscn` loads the base plus `home_props.json` and creates seven named `TextureRect` props. It supports:

- `1`–`7`: toggle an individual prop
- `A`: show all
- `N`: hide all
- `G`: toggle anchor/bounds guides
- `R`: reload the manifest and reset placement
- `H`: toggle the small help overlay

The default view shows all props with guides and help hidden. A screenshot harness renders the same default state to a PNG for review.

## Acceptance criteria

1. The base is exactly `941x1672` and contains none of the seven removable structures.
2. Every final prop PNG has alpha, transparent corners, no magenta fringe, and a connected turf skirt.
3. All prop paths, display sizes, anchors, and sort values are explicit in parseable JSON.
4. The Godot workbench instantiates exactly seven named prop nodes from the manifest.
5. The assembled screenshot has no obvious rectangular sprite edges, conflicting light directions, or floating structures.
6. Hiding every prop leaves a coherent landscape rather than seven conspicuous empty holes.
7. The current shipped Home scene and assets are not modified.

## Out of scope

- Replacing the live Home renderer or progression logic
- UI/HUD/navigation implementation
- Restore-state vines, badges, collision, residents, or animation
- Final production polish beyond this placement and cohesion checkpoint
