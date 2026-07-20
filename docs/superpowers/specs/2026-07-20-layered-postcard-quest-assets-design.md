# Layered Postcard Quest Assets Design

**Status:** Approved for asset production on 2026-07-20.

## Goal

Create the smallest faithful production asset pack needed to reconstruct the
approved Layered Postcard quest-card concept while leaving resident selection,
requested items, reward values, tinting, rotation, readiness, and shadows
dynamic at runtime.

Reference concept:
`games/grove/assets/_concepts/screens/quest_card_variations_v1/quest_cards_c_layered_postcard.png`.

## Architecture

Use a hybrid composition. The base card remains a code-drawn rounded panel
using existing Meadow paper tiles and runtime tinting. Existing systems continue
to render requested items, the reward coin, reward text, and shared shadows.
Only the two new irregular paper surfaces and the three prop-free resident
portraits are authored as new transparent sprites.

No runtime code is changed in this task. The bundle records the layout contract
for a later integration pass.

## New production sprites

1. `quest_request_note_512x576.png`
   - Empty warm-cream cut-paper note.
   - Slightly irregular deckled perimeter with generous safe interior.
   - No item, text, pin, pointer, tail, rotation, or baked shadow.
   - 512 x 576 RGBA master plus a 256 x 288 runtime derivative.
2. `quest_reward_seed_tag_512.png`
   - Empty seed-shaped cream tag with restrained reward-gold edge.
   - Includes one transparent punched hole and a short attached paper loop.
   - No coin, reward value, label, or baked shadow.
   - 512 x 512 RGBA master plus a 256 x 256 runtime derivative.
3. `giver_m2_1_clean_256.png`
   - Identity-preserving edit of `characters/giver_m2_1.png`.
   - Remove only the held acorn cluster; restore empty hands and costume.
4. `giver_m2_2_clean_256.png`
   - Identity-preserving edit of `characters/giver_m2_2.png`.
   - Remove the shovel and shield; restore empty hands and costume.
5. `giver_m2_3_clean_256.png`
   - Identity-preserving edit of `characters/giver_m2_3.png`.
   - Remove only the jar; restore empty hands and costume.

Every portrait preserves the original headwear, face, palette, upper-body
silhouette, and authored rounded paper base. Portraits are 256 x 256 RGBA with
transparent corners and no baked shadow.

## Reused assets and systems

- `characters/giver_m2_0.png` for the flower-crowned resident.
- `ui/meadow_v2/texture_cream.png`, `texture_meadow.png`,
  `texture_supporting_purple.png`, and `texture_warm_kraft.png` for base-card
  grain and tint families.
- `Bust.make(...)` for resident selection.
- `PieceView.make_piece(...)` for requested items and the existing ready check.
- `ui/meadow_v2/coin.png` and code-drawn `+N` reward text.
- Shared runtime shadows from `skin.gd`.

Do not reuse `ui/quest/bubble_ask.png`, the old stitched quest card, the wooden
plaque, the circular reward token, or the shop ribbon.

## Layout contract

The bundle includes `layout.json` with a logical card of 160 x 145 units:

- Portrait box: `[-8, 10, 110, 144]`, unclipped, with the rounded base extending
  approximately 9 units below the card.
- Request-note box: `[97, 8, 61, 69]`, rotated at runtime by -3 to +3 degrees.
- Requested-item safe box: `[106, 18, 44, 48]`.
- Reward-tag box: `[100, 81, 59, 63]`.
- Layer order: runtime card shadow, tintable base card, overflowing resident,
  note shadow, request note, requested item, tag shadow, reward tag, coin and
  reward text, readiness overlay.

The request note and tag are fixed-aspect textures, not nine-slices. The base
card is code-drawn and tintable; no base-card bitmap is generated.

## Art and processing rules

- Follow `docs/design/art-style-guide.md`: Meadow Sky plus Cut-Paper Playground.
- Broad, rounded, low-complexity cardstock shapes with restrained paper grain.
- No plastic, clay, glossy 3D, painterly gradients, heavy outlines, white
  sticker border, deep shadow, or baked contact shadow.
- Generate raw art on flat `#FF00FF`, except use flat `#00FF00` for the
  legitimate-purple `giver_m2_3` portrait, then remove the key deterministically.
- Preserve enclosed transparency, especially the reward tag's punched hole.
- Zero visible key fringe, opaque canvas-edge pixels, enclosed key pockets, and
  non-zero RGB outside alpha.

## Deliverables

Store the bundle under
`games/grove/assets/_concepts/screens/quest_card_variations_v1/layered_postcard_assets_v1/`:

- Raw flat-key sources and exact prompts.
- Five transparent production masters and two runtime derivatives.
- A transparent 3 x 2 review sprite sheet containing the five new masters.
- `layout.json`, `manifest.json`, and `README.md`.

## Acceptance criteria

- All five sprites match the approved mock and current resident identities.
- Removed props do not leave cropped hands, gaps, or replacement objects.
- Note and tag interiors remain empty for live content.
- Every final file opens as RGBA at its declared dimensions.
- All alpha/chroma acceptance counts are zero.
- The review sheet has five isolated, consistently scaled assets and no cell
  boundary contacts.
- No runtime code or existing production asset is modified.
