# Coral Reef V2 Layered Art Design

## Goal

Rebuild Coral Reef from the approved `coral_reef.png` mock using extraction-oriented image edits so every runtime layer preserves the source scene's matte paper grain, palette, silhouette language, lighting, object direction, and composition. Preserve V1 and create `coral_reef_elements_v2` as a separate production bundle.

## Source authority

`games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/coral_reef.png` is the exact identity, composition, palette, paper-material, camera, and lighting authority. It is an edit target, not loose visual inspiration.

The source palette remains:

- water `#6FA9C0`
- canyon slate `#3F6D7D`
- receding blue `#8296AF`
- warm cream `#F6EBDD`
- deep local edge `#243B4B`
- kelp `#5F9B6D`
- coral `#D87865`
- reward gold `#D6A94C`
- rare purple `#8677A3`

All accepted art must retain visible fine paper fiber, softly imperfect hand-cut contours, warm cut edges, shallow same-hue paper relief, mild printed mottling, and diffuse upper-left aquatic lighting.

## V2 architecture

### Opaque environmental plate

Generate one coherent 1320 × 2346 opaque environmental plate by editing the original mock. Remove the ship, coral garden, anemones, chest, mermaid statue, clam, kelp, and bubble streams. Preserve the original water, canyon-wall silhouettes, rock morphology, sand pattern, paper grain, palette, camera, and lighting.

Keep canyon walls and shelves baked into this invariant plate. Do not regenerate left and right canyon walls as separate runtime layers.

Widen the usable shelf tops while keeping them structurally attached to their canyon walls:

- upper-left coral shelf: at least 500 px usable width
- mid-left chest shelf: 300–340 px usable width
- lower-left clam shelf: 450–500 px usable width
- upper-right anemone shelf: 300–340 px usable width
- mid-right statue shelf: 340–380 px usable width
- lower-right kelp contact: a broad continuous seabed zone

Add 12–20 irregular slate-blue paper pebbles around the lower-left and lower-right seabed edges, with a few sparse center pebbles. Keep the central navigation floor open. Do not create gravel bands, repeated patterns, or object-shaped pads.

### Runtime subjects

Generate independent RGBA layers for:

1. sunken ship
2. coral garden
3. anemone cluster
4. treasure chest
5. mermaid statue
6. giant clam with pearl
7. kelp bed
8. bubble-stream backdrop

Each subject uses an extraction edit based on the original mock. Preserve the source object's silhouette, aspect ratio, facing direction, three-quarter angle, proportions, paper grain, internal painted mottling, palette, visible construction, and lighting. Do not rotate, flip, mirror, straighten, center it front-facing, sharpen, vectorize, emboss, simplify, or redesign it.

Remove all surrounding water, shelves, sand, rocks, and neighboring objects. Reconstruct only tiny portions naturally hidden by the original shelf. Raw extraction outputs use a perfectly flat `#FF00FF` background with generous margin; cleanup produces transparent RGBA finals.

Object-specific locks:

- Ship: bow remains high-left, hull descends toward lower-right, broken mast rises up-right.
- Chest: preserve the original slight three-quarter turn and visible top/side planes; reject symmetrical front-facing chests.
- Clam: preserve the backward-leaning upper shell, foreshortened lower shell, slight asymmetric turn, lavender exterior, cream interior, and nested pearl.
- Coral garden: preserve the overlapping salmon, cream, and lavender sea-fan morphology, embossed veins, broad scalloped lobes, and chunky tube accents.
- Anemones: preserve the source's soft organic cup and flower forms; reject rigid flowerpots or plastic fingers.
- Statue: preserve its seated pose, downward gaze toward center-left, hair, flower, and compact pedestal.
- Kelp: preserve muted olive-green narrow S-curved blades and shallow layered-paper construction; reject bright emerald ribbons.

### Bubble treatment

Preserve the source's irregular two-ribbon rhythm, spacing, and scale. Bubble bodies are pale water blue approximately `#8FC1D0`, with edges near `#6FA9C0` and only tiny highlights near `#D4E7E5`. Bubble bodies must not be cream or white. Composite the bubble layer at 55–70% opacity so it remains background atmosphere.

## Reconstruction

Create a 1320 × 2346 reconstruction using the opaque plate plus the eight runtime layers. Place each asset at the original mock's normalized position, scale, and orientation. The preview is a QA artifact; the runtime assets remain independent.

## Acceptance criteria

- The backdrop reads as one coherent edited copy of the original scene, not assembled canyon towers.
- Every placement shelf meets its minimum usable width and visibly supports its assigned item.
- Every runtime subject is RGBA with transparent corners and zero visible magenta residue.
- Chest and clam facing match the source; no mirroring or front-facing redesign.
- Subject silhouette and displayed aspect remain within roughly 10% of the source reference.
- Fine paper grain and painted mottling remain visible at game scale.
- Coral retains source-specific fan veins, layered lobes, tubes, and muted palette.
- Bubbles remain close to the water palette and visually recede behind objects.
- Bottom pebbles increase grounding without obstructing the open navigation floor.
- No item contains a shelf, broad platform, sand island, dark shadow slab, halo, or unrelated scenery.
- Reconstruction contains no UI, text, fish, creatures, extra treasure, ruins, anchors, or decorative landmarks.

## Rejection criteria

Reject any output that looks like glossy plastic, clean vector art, generic 3D game props, deep miniature diorama sculpture, realistic ocean photography, neon cyan water, black outlines, hard shadows, white bubbles, generic branching coral, rigid potted anemones, symmetrical front-facing chest or clam, undersized placement shelves, or uniformly scattered pebbles.
