# Tidy Up — Art Generation Prompts (Bedroom, Room 1)

Theme: **cozy merge-and-tidy.** You merge identical clutter up a short ladder — loose → folded → stacked → *put away* — and clearing the board tidies the room. Everything should look **soft, glossy, adorable, and satisfying to touch** — premium cozy-mobile eye-candy (think Royal Match / Gossip Harbor / Merge Mansion item art crossed with a warm, cozy bedroom).

When you generate images, **drop them in `assets/items/` with the exact filenames below** and the game will auto-load them (no code change needed). Until then it shows colored placeholders.

---

## STATUS — what's already generated vs. what still needs generating

_As of 2026-06-08. The prompt bodies below the table remain the canonical source for each file._

### ✅ Already generated (on disk + wired)

| Section | File(s) | Notes |
|---|---|---|
| §2 Items — **Clothes** | `assets/items/clothes_1.png … clothes_5.png` | full 5-tier ladder |
| §2 Items — **Books** | `assets/items/books_1.png … books_5.png` | full 5-tier ladder |
| §2 Items — **Toys** | `assets/items/toys_1.png … toys_5.png` | full 5-tier ladder |
| §3 UI / eye-candy | `assets/fx/fx_sparkle.png`, `assets/fx/fx_glow.png` | particle + bloom textures |
| §3 UI / eye-candy | `assets/ui/logo_tidyup.png` | title-screen logo |
| §3 UI / eye-candy | `assets/ui/btn_play.png` | Play button (baked text) |
| §3 UI / eye-candy | `assets/ui/play.png` | extra Play-button source |
| §4 / §6 Meta | `assets/rooms/bedroom_messy.png`, `assets/rooms/bedroom_tidy.png` | room before/after |
| §6 Board organizer | `assets/ui/bg_bedroom.png` | board background |
| §6 Board organizer | `assets/ui/tile_slot.png` | one pocket |
| §6 Board organizer | `assets/ui/board_tray.png` | plain mat behind pockets |
| §7 UI font | `assets/fonts/ui_glyph_atlas.png` + `.json` + built `ui.fnt` | ⚠️ **no longer used for UI text** — replaced by a tintable rounded system font (see "Superseded" below); still on disk for big display art |

### ✅ §8–§13 ALL GENERATED 2026-06-10 (on disk + imported + verified in-engine)

All 16 remaining §8–§13 PNGs were generated via the scripted ChatGPT loop, processed
(`tools/process_icon.gd`), and imported. (`drawer_clothes`/`drawer_books` were already done earlier.)

| Section | Files | Status |
|---|---|---|
| §8 Drawers | `drawer_clothes`, `drawer_books`, `drawer_toys` | ✅ full set |
| §9 Job Ticket | `ticket_card` (512×320), `ticket_stamp_done` (256), `ticket_checkmark` (256) | ✅ |
| §10 Fill the Shelf | `shelf_books`, `dresser_clothes`, `toybin_toys` (512×768) | ✅ |
| §11 Economy | `coin` (256), `coin_pile` (512), `wallet` (320) | ✅ |
| §12 Narrator | `wren_bust` (512, owl) | ✅ ⚠️ see note |
| §13 Helpers | `helper_key/wild/sweep/hint/shuffle` (256) | ✅ |

> ⚠️ **Naming clash to resolve:** §12 `wren_bust.png` is **Wren the owl narrator**, but `MAP_PROMPTS.md`
> also has a client **`client_wren.png` = "Wren the parent."** Two different characters share the name
> "Wren." Rename one (e.g. owl narrator → "Hoot"/"Olwen", or client → another name) before they appear
> together in dialogue. Art is correct either way; this is a text/string rename only.

> Note: `process_icon.gd` now supports a `W H` aspect-fit mode (added for the wide ticket card + the
> tall furniture). Single-size arg = square as before.

### ⚠️ Superseded / no longer needed

| Section | File | Why |
|---|---|---|
| §7 UI font | `assets/fonts/ui.ttf` (never delivered) | The atlas approach was abandoned for UI text — the generated bitmap glyphs aren't tintable and don't carry a real dark outline at small sizes. **UI now uses a rounded system font (Arial Rounded MT Bold + cozy fallbacks) styled in-engine with a dark outline.** If you ever want full cross-device font consistency, generating a real rounded TTF (Fredoka / Baloo / Comfortaa vibe) and dropping it at `assets/fonts/ui.ttf` would still be picked up automatically. Not blocking. |

### 🎵 Audio (separate doc — `AUDIO_PROMPTS.md`)

- ✅ Already on disk in `assets/sfx/`: 8 SFX — `button_tap`, `invalid_soft`, `item_drop`, `item_pickup`, `level_complete`, `merge_soft`, `merge_success`, `tidy_poof`.
- 🟡 Pending: the 3 music beds (`music_menu`, `music_play`, `music_room`) and the 7 new SFX cues (`item_slide`, `coin_earn`, `star_pop`, `quest_complete`, `unlock`, `undo`, `room_complete`) — all prompts in `AUDIO_PROMPTS.md`.

---

## 0. Consistent color scheme (LOCKED — keep all art in this family)

| Role | Hex | Use |
|---|---|---|
| Background (cozy night) | `#241E2E` | app & board background |
| Background deep | `#17121E` | finish-screen veil |
| Slot / cubby | `#332A3D` | empty board cells |
| Surface / cards | `#3A3047` | panels, tiles behind art |
| Text (warm cream) | `#FBF3EA` | primary text |
| Text muted | `#A99FB5` | secondary text |
| **Accent — warm peach** | `#FFB877` | primary buttons, "Tidy Up" logo |
| Accent — calm mint | `#8AE0C8` | secondary accents |
| Gold (rewards/stars) | `#FFD56B` | stars, sparkles, the "tidy!" pop |
| Merge-OK green | `#7FE0A0` | highlight a legal merge |
| Slide-OK blue | `#7FB4FF` | highlight a reachable cell |

Family signature hues (so each clutter type reads at a glance): **Clothes = coral/peach `#FF9DBB`/`#FFB877`**, **Books = teal/green `#8AE0C8`/`#7FE0A0`**, **Toys = sunny `#FFD56B`/`#FFC24A`**. Each item should sit comfortably on the dark `#241E2E` board.

---

## 1. MASTER STYLE PROMPT (prepend to EVERY item prompt)

> Adorable glossy 3D-rendered mobile-game item icon, cozy and inviting, soft squishy candy-like materials, smooth rounded chunky forms, gentle top-left key light with a soft rim light, soft ambient occlusion, no harsh shadows, vibrant but warm slightly-pastel colors, ultra-clean crisp silhouette, centered, **isolated on a fully transparent background, no ground shadow, no text, no border**, charming and satisfying, high detail, studio product render, mobile puzzle game asset, style of Royal Match / Gossip Harbor / Merge Mansion.

**Output spec for every item:** square **512×512**, transparent **PNG**, subject centered with ~10% padding, **consistent camera angle** (slight top-down 3/4 view) and **consistent light direction (top-left)** across the whole set so they look like one family. Each tier should read as *more tidy / more of it* than the one below.

---

## 2. ITEMS — the merge ladders (generate these first)

Each family is a 5-step ladder. **T1–T4 are board pieces; T5 is the "ready to put away" item that sparkles off the board** (the satisfying clear). Keep a family's color consistent across its 5 tiers.

### Family: CLOTHES (coral/peach) → files `clothes_1.png … clothes_5.png`
1. **`clothes_1`** — *a single small crumpled cozy sock, soft coral knit with a cute cream stripe, slightly rumpled, fuzzy texture.*
2. **`clothes_2`** — *one neatly folded pair of socks, a tidy little rolled bundle, soft coral knit, crisp and cute.*
3. **`clothes_3`** — *one neatly folded t-shirt, soft cotton in warm coral, crisp clean fold lines, plump and pillowy.*
4. **`clothes_4`** — *a small tidy stack of three folded clothes (folded shirt, folded sweater, folded pants), warm coral & cream tones, neatly squared pile.*
5. **`clothes_5`** — *a woven wicker laundry basket brimming with neatly folded coral & cream clothes, cozy and full, a little sparkle of "all done," ready to be put away.*

### Family: BOOKS (teal/green) → files `books_1.png … books_5.png`
1. **`books_1`** — *a single closed hardcover book, glossy teal cover with soft gold corner accents, rounded spine, cute.*
2. **`books_2`** — *two small books leaning together, teal and mint covers, tidy pair.*
3. **`books_3`** — *a short neat stack of three books, teal/mint/cream covers, edges aligned, glossy.*
4. **`books_4`** — *a taller tidy stack of books with a little red ribbon bookmark peeking out, warm teal palette.*
5. **`books_5`** — *a small cozy wooden shelf cubby filled with upright books in teal & mint, neatly arranged, a soft sparkle, ready to shelve.*

### Family: TOYS (sunny yellow) → files `toys_1.png … toys_5.png`
1. **`toys_1`** — *a single chunky wooden toy block, sunny yellow, rounded edges, a cute star embossed on it.*
2. **`toys_2`** — *two stacked wooden blocks, sunny yellow and warm orange, playful and tidy.*
3. **`toys_3`** — *a small neat cluster of toys: a block, a little ball, a wooden star, warm sunny palette.*
4. **`toys_4`** — *a tidy row of cute toys lined up, blocks and a small plush, sunny warm colors.*
5. **`toys_5`** — *a woven toy bin filled with adorable plush toys and blocks, cozy and full, a soft sparkle, ready to put away.*

> If you only generate one family first, do **CLOTHES** — it's the launch tutorial family.

---

## 3. EYE-CANDY / UI ELEMENTS (after the items)

- **`fx_sparkle.png`** (256×256, transparent) — *a soft burst of warm golden sparkles and tiny four-point stars with a gentle glow,* for merge bursts & the "tidy!" poof.
- **`fx_glow.png`** (256×256, transparent) — *a soft radial warm-white/gold glow, fading to transparent,* for blooms behind the finish text.
- **`tile_slot.png`** (192×192, transparent) — *a soft empty rounded cubby / fabric pocket, warm wood rim + cozy felt interior, gentle inner shadow,* the empty board cell.
- **`btn_play.png`** (512×256, transparent) — *a soft glossy rounded pill button in warm peach `#FFB877`, pillowy and candy-like, with the word **"Play"** centered on it in a friendly rounded cream/white font (matching the logo), subtle inner highlight and a soft drop shadow.* (Text is baked into the art — the game no longer overlays a label.)
- **`logo_tidyup.png`** (transparent) — *the words "Tidy Up" in a soft rounded friendly font, warm peach `#FFB877` with a gentle cream outline and a tiny sparkle on the dot, cozy and inviting.*

## 4. META / BACKGROUND (later — the room you restore)

- **`bedroom_messy.png`** and **`bedroom_tidy.png`** (1080×1080+, opaque) — *a cute cozy cartoon bedroom in a warm 3/4 isometric view: bed, rug, window with soft evening light, shelves, soft pastel palette on the `#241E2E`-friendly warm scheme. One version cluttered/messy, one version clean & beautifully decorated* — for the "restore the room" progression screen.

---

## 5. Where they go
```
assets/items/clothes_1.png … clothes_5.png
assets/items/books_1.png   … books_5.png
assets/items/toys_1.png    … toys_5.png
assets/fx/fx_sparkle.png, fx_glow.png
assets/ui/tile_slot.png, btn_play.png, logo_tidyup.png
assets/rooms/bedroom_messy.png, bedroom_tidy.png
```
Items are wired now (`assets/items/<family>_<tier>.png`); the rest I'll wire as we build those screens.

---

## 6. Board background & organizer (LOCKED direction)

Decision: the board is a **cozy themed organizer** — a neat grid of soft **pockets** on a tray/rug, set into the bedroom — and items **float inside their pocket** (no card behind them). The **room behind the board** is the restoration meta (it gets cosier as you tidy). Backgrounds are **full-bleed, opaque, soft-focus, low-contrast** (the opposite of the crisp transparent item icons) so the colorful pieces pop on top.

### `assets/ui/bg_bedroom.png` — room background (1080×1920, opaque)
> Cozy bedroom interior as a soft background for a relaxing mobile puzzle game. Warm late-evening light, painterly soft-3D storybook render, gentle depth-of-field blur, calm and inviting. A neat warm-wood floor with a soft round rug in the **lower-center foreground left deliberately open and uncluttered** (a calm space for a game board). Around the edges, softly out of focus: a cozy bed with plush pillows and a knit blanket, a window with a warm sunset glow and sheer curtains, a small bookshelf, a leafy potted plant, a warm lamp casting a soft golden pool of light. **Muted, low-contrast, slightly desaturated**, warm aubergine-and-cream palette matching `#241E2E` / `#FBF3EA` / `#FFB877`; soft dark vignette on the edges; no people, no text, no UI, no game pieces. Portrait 1080×1920, cozy diorama feel.

### `assets/ui/tile_slot.png` — one pocket / cubby (512×512, transparent)
> A single soft rounded empty storage pocket / cubby seen top-down, cozy felt interior in a muted warm tone with a gentle inner shadow and a soft rounded wooden rim, subtle and low-contrast, isolated on a transparent background, no text. An item icon nests inside it.

### `assets/ui/board_tray.png` — a PLAIN rug/mat behind the pockets (square ~1024×1024, transparent)
> A soft cozy **plain** woven rug / warm wooden tidy-mat, rounded corners, gentle soft drop shadow, warm cream-and-peach tones, subtle even texture, top-down, isolated, no text. **IMPORTANT: NO pockets, cubbies, holes, or compartments drawn on it** — the game draws the pockets on top, so the mat must be empty/uniform. Make it roughly **square** so it doesn't distort. *(The first version had pockets baked in + a 4:3 shape, which fought the code's pocket grid — hence this clarification.)*

> Later: per-family tray skins — a **woven laundry basket** (Clothes), a **bookshelf of cubbies** (Books), a **toy bin** (Toys) — each reinforcing "put it away."

---

## 7. UI font — generate → drop as `assets/fonts/ui.ttf`

The game applies a global cozy font from `assets/fonts/ui.ttf` if present (else Godot's default). **One font restyles every bit of text** — buttons, title, stats, finish screen — so no text needs to be drawn as an image. (Wired in `scripts/ui_font.gd`; no-op until the file exists.)

- **Format:** a real **TTF or OTF** (renders any string at any size — far better than a bitmap sheet). Drop at `assets/fonts/ui.ttf`.
- **Style:** cozy, **rounded, chunky, friendly display font** matching the "Tidy Up" logo — soft rounded terminals, generous bowls, warm and playful but **legible at small sizes** (the stats line). (Fredoka / Baloo / Chewy / Comfortaa vibe.)
- **Required glyphs:**
  - Uppercase `A–Z`, lowercase `a–z`, digits `0–9`
  - Punctuation/symbols: `space . , : ; ! ? ' " - – — _ ( ) [ ] / & % # @ * + = < > · • … $`
  - Game/UI chars the game uses: `▶ ◀ ★ ☆ ✦ ✨ ✓ ✕ ← → ↑ ↓` (nice-to-have: `↺` undo)
- **Icons/emoji note:** many display fonts lack `▶ ★ ✨ 🛏`. The game wires a **system-font fallback** so missing glyphs still render — but for crisp on-brand icons, prefer **sprite icons** (we already have `fx_sparkle`); say the word and I'll swap the in-text `▶`/`★`/`🛏` for sprites.
- **Bitmap-sheet alternative:** if you can only generate a glyph *image*, provide an even grid (one glyph per cell, known order) and I'll convert it to a Godot BitmapFont — but a TTF/OTF is strongly preferred.

---

## 8. FRICTION MECHANIC — Locked Drawers (per-family)

These replace the placeholder CSS drawers on the board. **Three closed-container variants**, one per family — themed to what's *inside* (a clothes drawer holds clothes, etc.). The closed container shows a faint silhouette of its contents peeking out, then pops open with a sparkle when a merge happens next to it.

**Master style addendum for drawers:** *Soft 3D bubble-render, warm woods + soft cream highlights, slightly tilted ¾ angle, transparent background, cute "open me" lid/handle, contents barely peeking through a slat or top, gentle drop-shadow. Square 512×512.*

- **`assets/ui/drawer_clothes.png` (512×512, transparent)** — *Closed wicker laundry hamper with a soft lid, warm coral-peach palette, a striped sock or folded sweater corner peeking out from under the lid. Cozy 3D bubble illustration, woven texture, soft cream highlight, ¾ angle, transparent background. Cute "open me" vibe.*
- **`assets/ui/drawer_books.png` (512×512, transparent)** — *Closed wooden book chest / slipcase with a brass clasp, warm teak with teal accent panels, a single book spine peeking out the top. Soft 3D bubble render, cream highlight, ¾ angle, transparent background.*
- **`assets/ui/drawer_toys.png` (512×512, transparent)** — *Closed wooden toy chest with a domed lid and rope handles, warm honey-wood with sunny yellow trim, a stuffed teddy ear or star-block corner peeking from the lid gap. Soft 3D bubble render, ¾ angle, transparent background.*

> **Wired:** code already reads `assets/ui/drawer_<family>.png` (e.g. `drawer_clothes.png`) when popping; falls back to the current procedurally-drawn placeholder if absent.

---

## 9. FRICTION MECHANIC — Job Ticket card

A small illustrated work-order card pinned beside the board that shows what the client wants tidied — the in-game "instructions" surface (also doubles as the clients/jobs meta object).

- **`assets/ui/ticket_card.png` (512×320, transparent)** — *A cute illustrated work-order card — cream paper with rounded corners, a torn-perforation top edge, a folded peach corner, soft warm drop-shadow. Empty interior (the game stamps items + checkboxes on top procedurally). Soft 3D bubble render, transparent background.*
- **`assets/ui/ticket_stamp_done.png` (256×256, transparent)** — *A round "JOB DONE" rubber stamp in warm peach with a slight rotation tilt, ink-edge texture, transparent background. (Plays over the ticket on completion.)*
- **`assets/ui/ticket_checkmark.png` (128×128, transparent)** — *A chunky cute peach checkmark with a cream outline, slight wobble, transparent background. (Lights up next to each completed target.)*

---

## 10. FRICTION MECHANIC — Fill the Shelf (per-family)

A piece of furniture beside the tray with item-shaped ghosted slots. Each top-tier "put away" flies into the next slot and lights it. Filling the whole thing = star goal + a mini room-reveal beat. **One per family** matching the items.

- **`assets/ui/shelf_books.png` (512×768, transparent)** — *A warm teak 3-shelf bookcase, ¾ angle, with ghosted book-shaped silhouettes on each shelf (3 per row, dim cream outlines hinting at where books will go). Cozy 3D bubble render, soft drop-shadow, transparent background.*
- **`assets/ui/dresser_clothes.png` (512×768, transparent)** — *A warm coral-painted 4-drawer dresser, ¾ angle, with ghosted folded-clothes silhouettes peeking from each drawer (dim cream outlines). Brass cup handles, cozy 3D bubble render, transparent background.*
- **`assets/ui/toybin_toys.png` (512×768, transparent)** — *A round honey-wood toy bin with rope-trim rim, ¾ angle, with ghosted star-block / teddy silhouettes hinting at contents. Cozy 3D bubble render, soft drop-shadow, transparent background.*

> **Wired:** the Fill-the-Shelf system reads `assets/ui/shelf_<family>.png` (`shelf_books`, `dresser_clothes`, `toybin_toys`) and animates put-aways into the named ghost slots.

---

## 11. ECONOMY & CURRENCY

- **`assets/ui/coin.png` (256×256, transparent)** — *A cute chunky gold coin with a soft tilted ¾ angle, glossy highlight, peach/cream rim, a tiny embossed star or "T" in the center. Cozy 3D bubble render, transparent background. (Used in coin-fly + counter.)*
- **`assets/ui/coin_pile.png` (512×512, transparent)** — *A small pile of 4–5 of the same cute gold coins stacked at varied angles, the top one sparkling. Cozy 3D bubble render, soft warm shadow, transparent background. (Used on payout cards + reward chips.)*
- **`assets/ui/wallet.png` (320×320, transparent)** — *A small coral leather purse / coin pouch with a brass clasp and one gold coin peeking out the top. Cozy 3D bubble render, ¾ angle, transparent background. (Used as the HUD coin counter icon.)*

---

## 12. NARRATOR — Wren the owl

The spec's warm narrator who texts you jobs in 1–2 cozy lines. **One reusable bust** is enough for all v1 dialogue beats (no per-line variants).

- **`assets/ui/wren_bust.png` (512×512, transparent)** — *A cute round barn owl from the shoulders up, warm cream + peach feathers, big friendly eyes, tiny bowtie or a clipboard tucked under one wing, soft smile. Cozy 3D bubble render, ¾ angle facing slightly right, soft drop-shadow, transparent background. Warm, approachable, never serious. (Wren is the player's owl dispatcher — friendly small-business vibe.)*

---

## 13. HELPER ITEMS (special items / monetization)

Cute one-tap conveniences the player earns or buys — never required, always optional. **Icons only** (the game draws the button background); each should read at ~96 px.

Each prompt: *Soft 3D bubble render, cozy palette, transparent background, single icon centered, readable at small size, ¾ angle, soft drop-shadow. Square 256×256.*

- **`assets/ui/helper_key.png`** — *A chunky cute brass "skeleton key" with a heart-shaped bow and a soft glossy highlight. (Master Key: pops all closed drawers on a board.)*
- **`assets/ui/helper_wild.png`** — *A cute rainbow-swirl gem / candy shape with sparkles around it, peachy + mint + coral, glossy. (Wild: counts as any family for one merge.)*
- **`assets/ui/helper_sweep.png`** — *A cute mini broom-and-dustpan combo, soft honey wood handle, peach bristles, a few dust sparkles. (Sweep: one-tap clears a chosen piece into "put away".)*
- **`assets/ui/helper_hint.png`** — *A cute glowing lightbulb with a heart-shaped filament, warm gold inside, soft mint outline. (Hint: highlights a strong next move.)*
- **`assets/ui/helper_shuffle.png`** — *Two cute curved arrows chasing each other in a circle, peach + mint two-tone, soft sparkles. (Shuffle: re-lays the loose pieces.)*

