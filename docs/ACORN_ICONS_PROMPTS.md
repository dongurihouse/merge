# Acorn Icons — "Donguri Merge" brand pass (artist prompt set)

**Status:** owner direction 2026-06-13. The game name is **Donguri Merge**
(*donguri* = acorn), so the acorn becomes the recurring brand motif.

**What's already an acorn (leverage, don't redo):**
- `assets/ui/kit/icon_coin.png` — the wallet **currency icon is already a golden
  acorn**, and the shop already says "+N acorns" (`shop.gd:134`). Coins = acorns
  is effectively canon (`TIDY_UP_V2_SPEC §0`, `GROVE_STYLE §5`).
- `assets/map/spirit_acorn.png` exists (an acorn wood-spirit) and the stall sells
  a 10🪙 **acorn treat**.

**Decision — where to add acorns (highest brand signal first):**
1. **App icon** (`icon.png`) — currently the *old Reach Zero purple ring*; replace
   with an acorn brand mark. (the face of the store listing)
2. **Board coin pickups** (`assets/ui/coin.png`, `coin_pile.png`) — currently
   generic **glossy 3D gold coins** (off-brand AND they violate `GROVE_STYLE §1`'s
   "no glossy 3D render"). Restyle to hand-painted acorns matching the wallet acorn.
3. **Acorn FX particle** (`assets/fx/p_acorn.png`) — a tiny acorn that scatters on
   acorn pickups / big merges, joining the petal·leaf·pollen particle set.
4. **Merchant accent** (note, no new asset yet) — when the Market Squirrel / cart
   art is next touched, the cart brims with acorns and the squirrel wears the
   "acorn cap" already specified in `GROVE_STYLE §2`.

**Deliberately NOT acorns:** the ★ Star (progress currency) and 💎 Diamond stay
distinct — making them acorns too would blur the three currencies.

All prompts append the `GROVE_STYLE.md §1` style core (the **bible bans glossy 3D**,
which is the whole point of restyling the coins) and follow the §2 item-class rules.

---

## §1 style core (append verbatim to every prompt below)
> hand-painted anime film background style, soft gouache and watercolor texture
> with visible brushwork, gentle diffuse summer daylight, warm nostalgic pastoral
> palette of meadow green, straw gold and clear sky blue, painterly cel-shaded
> subject with clean simple line work, no photorealism, no glossy 3D render, no text

---

## A. App icon — `icon.png` (the brand mark)

App icons are opaque and must read at tiny sizes, so: bold silhouette, subject
fills ~70%, soft background (no transparency, no text in the art).
```
hand-painted anime film background style, soft gouache and watercolor texture with visible brushwork, gentle diffuse summer daylight, warm nostalgic pastoral palette of meadow green, straw gold and clear sky blue, painterly cel-shaded with clean simple line work, no photorealism, no glossy 3D render, no text.
A single plump golden acorn as a friendly hero emblem — warm straw-gold nut with a textured nut-brown cap, a small fresh green oak leaf tucked behind it, soft painterly shading and a clean confident outline, centered and slightly tilted, filling about 70% of the frame. Set on a soft sunlit meadow-green rounded background with a gentle warm glow behind the acorn. Bold simple silhouette that stays clear at small sizes. Square.
```
→ process `decor 1024 1024 --opaque`, save to `icon.png` (refresh `icon.png.import`),
keep `project.godot config/icon` pointing at it.

## B. Board coin pickups (restyle 3D → hand-painted acorns)

### `coin.png` — single acorn pickup (tier c1)
```
hand-painted anime film background style, soft gouache and watercolor texture with visible brushwork, gentle diffuse summer daylight, warm nostalgic pastoral palette of meadow green, straw gold and clear sky blue, painterly cel-shaded with clean simple line work, no photorealism, no glossy 3D render, no text.
A single hand-painted golden acorn — the SAME warm straw-gold nut with a textured nut-brown cap as the wallet currency icon — chunky readable silhouette, one soft warm rim light, clean outline, centered on plain solid white background, generous margin. Square.
```
→ `icon 512`

### `coin_pile.png` — acorn heap (tiers c2/c3)
```
hand-painted anime film background style, soft gouache and watercolor texture with visible brushwork, gentle diffuse summer daylight, warm nostalgic pastoral palette of meadow green, straw gold and clear sky blue, painterly cel-shaded with clean simple line work, no photorealism, no glossy 3D render, no text.
A small heap of three or four hand-painted golden acorns nestled together, the same straw-gold nuts with nut-brown caps as the single acorn, reading as one tidy cluster, chunky readable silhouette, one soft warm rim light, clean outline, centered on plain solid white background, generous margin. Square.
```
→ `icon 512`

*(If a distinct top tier is wanted later, add `coin_basket.png` — a little woven
basket brimming with acorns — for c3.)*

## C. FX particle — `assets/fx/p_acorn.png`
```
hand-painted anime film background style, soft gouache and watercolor texture with visible brushwork, gentle diffuse daylight, painterly with clean simple line work, no photorealism, no glossy 3D render, no text.
A single tiny hand-painted acorn, a small painted game particle, warm straw-gold nut with a little brown cap, soft edges, centered on plain solid white background, generous margin.
```
→ `icon 128` (then wire into `fx.gd` as a pickup/celebrate particle alongside
`p_petal`/`p_leaf`/`p_pollen`)

---

## Big optional swing (gameplay content, not just an icon) — flag for owner

**An acorn → oak merge LINE.** A growth line whose ladder is literally
acorn → sprout → seedling → sapling → young oak → spreading oak → great oak →
golden oak — so the core merge verb embodies the name "Donguri Merge." This is
content (8 tiers + a generator, e.g. a "squirrel's acorn cache"), so it follows
the line rules in `GROVE_STYLE §2/§3` and the debut rules in `TIDY_UP_V2_SPEC §2`.
Say the word and I'll spec + write the full line/generator prompts separately.
