# Board Quest Card Variations Design

**Status:** Approved for concept generation on 2026-07-19.

## Goal

Generate three clearly different quest-card directions for the board without
changing the quest information model. The comparison should determine the
card's composition, not redesign the surrounding board.

## Shared comparison contract

- Show a horizontal row of four quest cards at believable phone-game scale.
- Reuse the same four content examples in every variation: a flower-crowned
  forest child requesting a blue-green herb for `+5`, a purple-cloaked child
  requesting a white winter rabbit for `+24`, a sandcastle-crowned child
  requesting a green sprig for `+34`, and a leaf-hooded child requesting a
  pine cone for `+12`.
- Preserve the three live data roles: resident portrait, one requested item,
  and coin reward.
- Do not add names, quest descriptions, progress meters, buttons, rarity,
  timers, or additional counters.
- Use the current board screenshot for content and scale authority, not as a
  layout template that must be copied.
- Present the row against a quiet Meadow Sky blue surface with generous outer
  margin. Do not regenerate the entire board.
- Keep every card readable at roughly 160 x 145 logical pixels and suitable
  for horizontal scrolling.

## Art direction

Apply `docs/design/art-style-guide.md` exactly: Meadow Sky palette, matte
Cut-Paper Playground material, broad low-complexity silhouettes, restrained
paper grain, warm cut edges, shallow down-right tinted shadows, cream UI
surfaces, ink text, action green, and meaningful reward gold. Avoid glossy 3D,
clay, sticker outlines, painterly rendering, neon colors, and dense ornament.

## Variation A: Story Bubble

The resident fills the left half of a softly tinted rounded card. A large cream
speech bubble occupies the upper-right and points naturally toward the
resident. The requested item is centered in the bubble. A small cream reward
pill sits inside the lower-right edge. This is the clearest evolutionary step
from the current card and is the control direction.

## Variation B: Split Ticket

Divide each card into two connected paper fields: a muted colored portrait
field on the left and a warm-cream request field on the right. Use a shaped
paper seam rather than a hard line. Center the requested item in the right
field. Hang a compact reward tab from the lower card edge. No speech bubble.

## Variation C: Layered Postcard

Use one softly tinted base card. Let the resident overlap the lower-left edge
with a complete rounded paper base. Place the requested item on a separate,
slightly rotated cream paper note in the upper-right. Attach the reward as a
small gold-edged seed-shaped tag near the lower-right. No speech bubble and no
split background.

## Deliverables

- Three separate high-resolution PNG comparison mockups.
- One prompt text file beside each PNG.
- One README identifying the variations and their intended trade-offs.
- Concept-only assets under
  `games/grove/assets/_concepts/screens/quest_card_variations_v1/`; no runtime
  integration in this task.

## Acceptance criteria

- All three files show four complete, uncropped cards.
- The information hierarchy is legible: resident first, request second, reward
  third.
- All three directions are structurally distinct at thumbnail size.
- Content and reward values remain consistent across variations.
- No unrelated board controls or invented quest mechanics appear.
