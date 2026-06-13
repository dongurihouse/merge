# Tidy Up — Jobs/Map Art Prompts (for the Districts → Clients → Jobs screen)

Companion to `ROOM_PROMPTS.md` / `ICON_PROMPTS.md`. These are the images for the **M7 Jobs map** —
the screen that wraps the levels in the locked hierarchy **Town → District → Client → Job**.
v1 ships **3 districts = the 3 item families**, one family debuting per district:
**Clothes → Books → Toys**.

> **✅ STATUS — all 6 generated, processed, imported & verified in-engine (2026-06-09).**
> Cards `district_clothes/books/toys.png` (1024×512 opaque) + busts `client_wren/juniper/pip.png`
> (512² transparent) are in `assets/map/` and render correctly on Jobs.tscn (cards composite under
> the code-drawn pins/stamps/locks; busts show in the client chip + "client says thanks" beat).
> Busts were generated with a reworded *"cute flat cartoon mascot avatar"* framing — the literal
> "person portrait" wording stalled ChatGPT's Thinking model for 5–7 min; the mascot framing
> generated reliably. Nothing else needed for M7.

> **➕ District BOARD skins also generated 2026-06-10** (referenced by `districts.gd`, were falling back
> to the bedroom bg + plain mat). Now on disk + imported, processed opaque via `tools/process_decor.gd`:
> board mats `assets/ui/tray_{clothes,books,toys}.png` (1024²) and board backdrops
> `assets/ui/bg_{linen_lane,paperleaf,tumble}.png` (1080×1920). Verified on the board (tidy_07 renders
> in the Paperleaf reading-room backdrop on the teak/teal book mat).

---

## §0 — How the art is used (read first)

The Jobs screen is a portrait scroll of **district cards**, one per district. Each card is a wide
illustrated strip; the game draws everything interactive ON TOP of it in code:

```
[ district card art ]            ← you generate (this file)
   + job pin nodes               ← code-drawn (bobbing dots + numbers)
   + wax completion stamps       ← code-drawn
   + lock veil on locked cards   ← code-drawn (desaturate + fog)
   + district name label         ← code-drawn text (i18n)
```

So: **no text, no pins, no UI in the art** — just a charming little neighborhood with
**a clear horizontal "street" through the middle** where the job nodes will sit.
A client **bust** appears in a small round portrait chip on the card and in the
"client says thanks" beat between jobs.

---

## §1 — Specs

- **District cards:** **1024 × 512** landscape strips, opaque. Keep the middle band
  (vertical center ±20%) compositionally calm so a row of ~5 job pins reads on top of it.
- **Client busts:** **512 × 512**, character from the chest up, **plain white background**
  (I'll process to transparent — same pipeline as the item icons).
- **Style:** the same cozy storybook world as the bedroom art — warm, soft, illustrated,
  peach/cream/teal/wood palette, soft top-left light. No text anywhere.
- **Names / paths:** drop in `assets/map/` exactly as named below; then
  `godot --headless --path . --import`.

---

## §2 — The three district cards

District names below are placeholders (i18n keys later) — the *theme* is what's locked:
each district is the neighborhood of its item family.

| File | District (family) | Prompt |
|---|---|---|
| `district_clothes.png` | **Linen Lane** (Clothes — the starter district) | *A cozy storybook residential lane in warm morning light: small friendly houses, a clothesline with socks and shirts gently hanging between two of them, potted flowers, a winding pavement through the middle. Warm peach/cream/teal illustrated style, soft shading, calm uncluttered middle band, no people, no text. Landscape 2:1.* |
| `district_books.png` | **Paperleaf Court** (Books) | *A snug storybook street corner with a little bookshop: big warm-lit shop window full of colorful book spines, a tiny free-library box on a post, autumn-toned trees, a winding pavement through the middle. Warm peach/cream/teal illustrated style, soft shading, calm middle band, no people, no text. Landscape 2:1.* |
| `district_toys.png` | **Tumble Park** (Toys) | *A playful storybook park block: a small toy-shop facade with a striped awning, a gentle playground with a slide and a kite caught mid-air, soft green lawn, a winding path through the middle. Warm peach/cream/teal illustrated style, soft shading, calm middle band, no people, no text. Landscape 2:1.* |

---

## §3 — Client busts (the story spine)

v1 needs **Wren** (the first client) + two more so each district's client run has a face.
Same character style as the world: soft, round, friendly — think gentle picture-book people.

| File | Who | Prompt |
|---|---|---|
| `client_wren.png` | **Wren** — your first client, a warm slightly-frazzled young parent | *Friendly storybook character portrait, chest up: a warm young parent with soft round features, slightly frazzled curly hair, a cozy mustard cardigan, gentle grateful smile. Soft illustrated style, peach/cream palette, plain white background, no text. Square.* |
| `client_juniper.png` | **Juniper** — retired teacher drowning in books | *Friendly storybook character portrait, chest up: a kind elderly teacher with round glasses, silver bun, a teal shawl, a book hugged to their chest, warm smile. Soft illustrated style, plain white background, no text. Square.* |
| `client_pip.png` | **Pip** — energetic kid whose toys are EVERYWHERE | *Friendly storybook character portrait, chest up: a cheerful gap-toothed kid with messy hair and a striped tee, holding a teddy bear by one arm, big grin. Soft illustrated style, plain white background, no text. Square.* |

---

## §4 — Tips

- **Card middle band calm** is the one hard requirement — pins, stamps, and the travel trail
  draw across it; busy art there turns the map to noise.
- Generate all three cards in one chat so the style/palette stays consistent (same trick as
  the bedroom layers).
- Busts: white background, generous margin around the head — they get circle-cropped into
  a portrait chip.
- Pins, stamps, star arcs, locks, and the district name labels are all code-drawn.

---

## §5 — Per-district BOARD theming (trays + backdrops)

Each district also re-skins the board itself (see `DISTRICTS_SPEC.md` §1): the **tray**
(the mat the pockets sit on) and the **backdrop** (the room behind the board). Both are
optional — the game falls back to `board_tray.png` / the bedroom until these land.

### Trays — drop in `assets/ui/`

**Format (same as the current `board_tray.png`):** **1024×1024**, ONE plain square mat
filling ~87% of the canvas (a transparent margin rings it), softly rounded corners
(~12% of the side), **NO pockets, NO objects** — the game stamps the pocket grid on top,
so the center must be a flat, even texture. Top-down view, soft even light.

| File | District | Prompt |
|---|---|---|
| `tray_clothes.png` | Linen Lane | *Top-down square woven laundry mat in warm peach and cream stripes, soft fabric texture, gently rounded corners, flat and even — no objects, no pockets, no shadows of items. Fills most of the canvas, transparent background. Cozy storybook style.* |
| `tray_books.png` | Paperleaf Court | *Top-down square warm wooden board like a bookshelf backboard, honey-toned wood grain, gently rounded corners, flat and even — no objects, no pockets. Fills most of the canvas, transparent background. Cozy storybook style.* |
| `tray_toys.png` | Tumble Park | *Top-down square soft play mat in muted teal with faint cream polka dots, quilted fabric texture, gently rounded corners, flat and even — no objects, no pockets. Fills most of the canvas, transparent background. Cozy storybook style.* |

### Board backdrops — drop in `assets/ui/`

**Format:** **1080×1920** portrait, opaque. The game dims it heavily behind the board
(a ~60% dark scrim), so keep it **low-contrast and calm in the middle** — it's ambience,
not a focal point. Same warm storybook world as `bedroom_tidy.png`.

| File | District | Prompt |
|---|---|---|
| `bg_linen_lane.png` | Linen Lane | *Cozy illustrated laundry nook, portrait: warm cream walls, a wooden shelf with folded linens, a wicker basket, soft hanging shirts at the edges, gentle morning light. Calm, uncluttered center. Peach/cream/teal palette, no text.* |
| `bg_paperleaf.png` | Paperleaf Court | *Cozy illustrated study corner, portrait: tall warm bookshelves at the sides, a reading lamp's soft glow, scattered warm light. Calm, uncluttered center. Peach/cream/teal palette, no text.* |
| `bg_tumble.png` | Tumble Park | *Cozy illustrated playroom, portrait: a toy chest and stacked blocks at the edges, soft pennant bunting up high, warm afternoon light. Calm, uncluttered center. Peach/cream/teal palette, no text.* |

With §2+§3+§5 together the complete per-district shopping list is **4 images each**
(card · bust · tray · backdrop) — **12 total** for the three live districts.
