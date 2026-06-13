# Tidy Up — Bedroom Decor Art Prompts (for the room reveal)

Companion to `ICON_PROMPTS.md`. These are the images for the **room you decorate** with earned Coins,
slot by slot, until the **Room Complete reveal**. The game layers them: a base room + one transparent
overlay per decoration + a warm-light glow on top.

---

## §0 — How the layering works (read first)

The room is drawn as a STACK of same-size PNGs, back to front:

```
bedroom_base.png          ← the bare room (always visible)
 + decor_rug.png          ┐
 + decor_bed.png          │  each is the FULL room canvas, but only THIS piece is
 + decor_lamp.png         │  painted (in its final position); everything else transparent.
 + decor_shelf.png        │  Bought one at a time as the player spends coins.
 + decor_plant.png        │
 + decor_art.png          ┘
 + bedroom_glow.png       ← warm light, alpha fades IN as the room fills
```

**Critical:** every file MUST be the **same canvas size and the same camera** as `bedroom_base.png`, with
the piece drawn exactly where it sits in the finished room and **full transparency everywhere else**. If
you generate the finished room and the pieces separately, they won't line up. Best workflow: generate the
**finished room first**, then generate each piece as a cutout on transparent background *at its same
position/scale*, plus the empty base.

---

## §1 — Specs

- **Canvas:** **1024 × 1280** (portrait 4:5), all files identical. Transparent PNG (except the base).
- **Style:** same cozy world as the existing `bedroom_tidy.png` — warm, soft, illustrated, gentle shadows,
  the game palette (peach/cream/teal/wood). Soft top-left light. No text, no UI.
- **Names / paths:** drop in `assets/rooms/` exactly as named below; then `godot --headless --path . --import`.

---

## §2 — The base + glow

| File | What it is | Prompt |
|---|---|---|
| `bedroom_base.png` | the **bare** room — walls, wood floor, a window with soft daylight, baseboards. NO furniture. | *Cozy illustrated child's bedroom, EMPTY: warm cream walls, soft wood floor, one window with gentle morning light and sheer curtains, baseboards, soft ambient shadow. No furniture, no clutter. Warm storybook style, soft shading, peach/cream/teal palette, portrait 4:5, no text.* |
| `bedroom_glow.png` | a soft warm-light overlay (sun rays + cozy glow) on transparent; the game fades its alpha in as the room fills | *Soft warm light overlay on transparent background: gentle golden sun rays from the top-left window, a cozy ambient glow, faint floating dust motes. Subtle, semi-transparent, no objects. Portrait 4:5.* |

---

## §3 — The decoration pieces (6 slots)

Each is the **full 1024×1280 canvas**, the piece in its finished position, everything else transparent.

| File | Piece & placement | Prompt (draw only this, transparent elsewhere) |
|---|---|---|
| `decor_rug.png` | a round/oval **rug** on the floor, center-lower | *A cozy round braided rug, warm peach & cream, soft shadow, sitting on the floor in the lower-center of the room. Only the rug, transparent everywhere else. Same camera/scale as the room. Portrait 4:5.* |
| `decor_bed.png` | a **bed** with pillow & quilt, against the left/back wall | *A cute single bed with a plump pillow and a folded quilt in warm tones, wooden frame, against the wall, mid-left. Soft shadow. Only the bed, transparent elsewhere. Same camera. Portrait 4:5.* |
| `decor_lamp.png` | a **bedside lamp** on a small nightstand | *A small wooden nightstand with a round cozy lamp (warm glow), beside where the bed sits. Only the nightstand + lamp, transparent elsewhere. Same camera. Portrait 4:5.* |
| `decor_shelf.png` | a **bookshelf** with a few books/toys, on the right wall | *A small wooden bookshelf with a few colorful books and a tiny toy, against the right wall. Soft shadow. Only the shelf, transparent elsewhere. Same camera. Portrait 4:5.* |
| `decor_plant.png` | a **potted plant** in a corner | *A friendly potted leafy plant in a terracotta pot, standing in a corner of the room. Soft shadow. Only the plant, transparent elsewhere. Same camera. Portrait 4:5.* |
| `decor_art.png` | framed **wall art / pictures** above the bed | *A couple of cute framed pictures (a sun, a little landscape) hanging on the wall, upper area. Only the frames, transparent elsewhere. Same camera. Portrait 4:5.* |

---

## §4 — Tips
- Generate the **finished room** once as a reference, then ask for each piece "as a cutout on transparent
  background, identical position and scale, nothing else." Consistency of camera/scale is everything.
- Keep each piece's soft shadow WITH the piece (so it grounds when layered).
- The first 4 pieces are the "required" set (the room reads done at 4/6); rug · bed · lamp · shelf are a
  good required four, with plant + art as the bonus two.
- When the art's in `assets/rooms/`, I'll wire the per-slot decoration UI + the Room Complete reveal.
