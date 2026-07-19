# Winter Scene Variations Design

## Goal

Create three new portrait winter-scene concepts inspired by `snowy_village_v2.png`. Preserve the handcrafted paper-cut grain language while progressively increasing the image model's freedom to invent the setting, composition, landmarks, and story.

## Generation Strategy

Treat the source as a reference, not an edit target. Generate three independent scenes so the source layout is not implicitly locked into every result. Use one built-in image-generation call per variation.

Every call attaches three images with explicit roles:

1. `games/grove/assets/_concepts/zones/snowy_village_v2.png` — winter mood and scene-family reference only. It may suggest snow, warmth, portrait rhythm, and playful seasonal storytelling, but its exact pond, cabins, and props must not be copied as a checklist.
2. `games/grove/assets/_concepts/screens/palette_a_meadow_sky_board.png` — palette and matte cut-paper material authority only. This is the checked-in equivalent of the guide's currently absent `_new/.../palette_studies_board_v1/` path. Do not copy its UI or board layout.
3. `games/grove/assets/_concepts/screens/home_screen_meadow_sky_v2_working_farm.png` — elevated three-quarter camera, common object scale, shallow shadow, and detail-budget authority only. This is the checked-in equivalent of the guide's currently absent `_new/.../screen_reference_pack_meadow_sky_v1/` path. Do not copy its farm content or UI.

## Variations

### A — Familiar Village Remix

Keep the result recognizably a cozy snowy village and retain a frozen-water focal area, but allow a new shoreline, building arrangement, landmarks, seasonal activities, and supporting props. This is the closest visual cousin to the source.

### B — Reimagined Winter Gathering

Keep only the idea of a welcoming winter community. The model chooses the primary gathering place, circulation, landmarks, terrain, and seasonal story. A pond or cabins may appear, but neither is required. This is the recommended balance between continuity and surprise.

### C — Storybook Winter Surprise

Keep the winter mood, portrait scene readability, Meadow Sky palette relationships, and cut-paper material language. Give the model broad freedom to invent a different believable winter place with one strong hero destination and a clear approach-to-activity-to-destination spatial story.

## Shared Visual Contract

- Exact final canvas: 941 x 1672 pixels.
- Dressed reference-only scene mocks with no UI.
- Elevated three-quarter camera and a single upper-left light.
- Friendly matte hand-cut cardstock with broad rounded silhouettes, warm cut edges, thin locally darker edges, subtle 2-4% paper fiber, and short soft down-right contact shadows.
- Keep detail readable at phone size; use a few strong masses instead of dense ornament.
- One continuous believable ground plane and one clear hero destination.
- Arrange content according to how the place is approached and used rather than as an evenly spaced prop display.
- No text, labels, numerals, UI, logo, border, or watermark.
- Avoid photorealism, glossy plastic, clay, sticker rendering, watercolor, gouache, visible brushwork, painterly gradients, realistic miniature dioramas, heavy black outlines, and dark cinematic lighting.

## Outputs

Save non-destructively under:

`games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1/`

- `winter_scene_familiar_v1.png`
- `winter_scene_familiar_v1.prompt.txt`
- `winter_scene_gathering_v1.png`
- `winter_scene_gathering_v1.prompt.txt`
- `winter_scene_surprise_v1.png`
- `winter_scene_surprise_v1.prompt.txt`

Do not overwrite `snowy_village_v2.png` or any existing scene mock.

## Review and Acceptance

Each candidate must:

1. Read immediately as a coherent winter place at phone-review size.
2. Preserve the paper-cut grain and Meadow Sky material language.
3. Have consistent camera, scale, light, and grounding within the scene.
4. Show a meaningful progression in creative freedom from A through C.
5. Avoid simply reproducing the source's exact inventory of cabins, central tree, pond props, snowmen, and market stall.
6. Contain no malformed structures, nonsensical paths, floating props, clipped hero elements, readable text, or watermark.
7. Be exactly 941 x 1672 pixels after non-destructive normalization.

The final share gate is visual review by the user; model-side inspection is only a preliminary rejection pass.
