# Mail Dialog Icon Sprite Design

## Goal

Create a production-oriented icon pack for the approved Mail dialog mock while leaving scalable cards, buttons, and the modal frame to the UI system.

## Sheet Contract

- One square `3x3` raw sheet on a perfectly flat `#FF00FF` background.
- Nine equal invisible cells, read left-to-right and top-to-bottom.
- Every subject is centered, occupies roughly 60-68% of its cell, and has visible magenta gutter on all four sides.
- No visible grid, labels, text, numerals, shadows, floor plane, glow, or detached decoration outside its cell.
- All artwork follows the fixed Meadow Sky + Cut-Paper Playground palette and material rules.

## Row-Major Asset Map

1. Open slate-blue envelope holding a cream letter, with one small garden-green leaf.
2. Reward-gold coin medallion with a simple embossed five-point star.
3. Small warm-wood garden delivery crate containing one water droplet, one acorn, a few leaves, and one cream daisy.
4. Single clear sky-blue water droplet.
5. Single warm-brown acorn with a darker cap.
6. Small reward-gold treasure chest wrapped with a coral ribbon and bow.
7. Cream sealed envelope with one attached reward-gold four-point sparkle.
8. Standalone thick rounded cream X close glyph with no circular button background.
9. Standalone small coral unread dot with a subtle locally darker cut edge and no badge ring.

## Deliverables

- Native generated raw sheet and exact prompt.
- Clean keyed sheet and transparent `1536x1536` atlas.
- Nine individually named transparent `512x512` masters.
- Contact-sheet previews over dark, light, and shipping-cream backgrounds.
- Manifest and processor metadata describing row-major identity and QC.

## Acceptance

- Exactly nine populated cells with the specified identity order.
- No subject touches a cell edge or the sheet edge.
- Transparent corners and no visible magenta fringe.
- Every icon remains recognizable at `256x256` runtime size.
- UI surface art is deliberately excluded from this pack.
