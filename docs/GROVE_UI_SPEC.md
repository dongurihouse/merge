# GROVE UI SPEC — the holistic UI system (owner directive 2026-06-11)

> Owner: "Design the UI holistically — borders, screen juice, icons, text — tie
> the whole UI together and fit the theme. Spec where to generate images, where
> to use text, how text is rendered, placement across aspect ratios. The store
> menu shouldn't just be a list of buttons."

This is the single source for HOW the UI looks and moves. Components implement
it via ONE module (`scripts/skin.gd` — "Look"), which serves themed pieces with
code-drawn fallbacks until the generated kit lands. Build orders live in
`BUILD_QUEUE.md` §G-UI; art rows in `ART_CHECKLIST.md` §H.

---

## §0 — Principles

1. **Diegetic first, chrome second.** Anything that can live IN the world does
   (chests, fence, merchant). True overlays (Shop, Settings, ladder card,
   confirms) are "objects from the world": parchment, planks, leaves — never a
   flat rectangle with buttons.
2. **One kit, every screen.** All panels/buttons/chips/icons come from `Look`.
   No component invents its own StyleBox again — that's how we drifted.
3. **Art carries shape and texture; the ENGINE carries every letter and
   number.** Generated images contain NO text, NO numerals, ever (⊕CORE already
   bans it — localization and crispness demand it too).
4. **Everything ships twice:** kit-art version AND code-drawn fallback with the
   same metrics, so the game is always playable before/while art generates.
5. **Juice is a vocabulary, not improvisation.** The same press, pop, fly, and
   tick everywhere (§6) — that sameness IS the cohesion.

---

## §1 — Surfaces & borders (the panel system)

Three elevation levels, each ONE nine-patch texture (generated; §H):

| level | kit texture | use | fallback (today's StyleBoxFlat) |
|---|---|---|---|
| **Ground band** | `panel_plank` | fence wall, shop header band, bottom dock | bark `#6E4B2F` r18 b4 `#3D2A1B` |
| **Card** | `panel_parchment` | quest cards, shop body, settings, ladder, confirms | cream `#FBF3EA` r26 b5 `#8A5A3B` + shadow |
| **Chip** | `panel_chip` | wallet, water chip, price chips, state pins | ink `#33402F` a.65 r20 |

Rules: nine-patch margins 96px (512 source) so corners never stretch; ALL
shadows/glows stay code (StyleBoxFlat shadow under the texture) so elevation is
tunable without regen; border accents (gilded variant edge, ready-green) are
code tints layered on the same texture — never separate art.

Decorations (sparingly, generated): `ribbon_title` (small banner that sits
half-over a card's top edge — titles live ON it as engine text),
`divider_vine` (thin sprig divider inside cards). Nothing else.

---

## §2 — Text: where and how

**Where text:** every label, number, price, name, status line. **Where art:**
shape, texture, icons, characters, terrain. If a mock shows words inside an
image — it's wrong; the image gets a blank plate and the engine sets the words.

**Font:** bundle ONE rounded OFL typeface at `assets/fonts/ui.ttf`
(`ui_font.gd` already prefers it) — pick **Baloo 2 SemiBold** (or Fredoka
Medium); download the OFL file, commit it + its LICENSE next to it. The system
fallback stays for safety. NO bitmap/baked fonts (not tintable, not localizable).

**Hierarchy (sizes at 1080-wide base):**

| role | size | color & treatment |
|---|---|---|
| Display (card titles) | 40–44 | INK on parchment; CREAM + 6px INK outline when floating on world |
| Body / row label | 26–30 | INK on parchment · CREAM on chips |
| Number (wallet, prices, counts) | 30–34 | CREAM on chips, always beside a sprite icon (§3) |
| Caption / status lines | 21–24 | 60–80% alpha of the surface's text color |
| Floaters (world feedback) | 30–38 | CREAM/STRAW + 5px INK outline, drift+fade |

Rule of outlines: **outline = floating over the world; no outline = sitting on
a panel.** Never both looks for the same role.

---

## §3 — Icons (the emoji purge)

Emoji glyphs (★ 🪙 💎 💧 ☔ 🛒 ⚙ ✓ ✿…) render differently per OS, can't be
recolored, and break the painted look. Replace every one in UI with generated
sprite icons (256px, transparent, ⊕CORE style, NO text), served via
`Look.icon(id, px)`:

| id | replaces | subject (canon decisions) |
|---|---|---|
| `icon_star` | ★ and pin ✿ | **the Bloomstar** — five-petal flower-star, straw gold (stars ARE blooms) |
| `icon_coin` | 🪙 | **the acorn** — a plump golden acorn, a natural object like its siblings (owner 2026-06-11: the medallion v1 read metal/casino — no coin, no disc, no rim; the currency IS the acorn) |
| `icon_gem` | 💎 | **dewdrop** — teardrop gem catching light |
| `icon_water` | 💧 | round water drop, one highlight |
| `icon_rain` | ☔ | tiny rain cloud with three drops |
| `icon_cart` | 🛒 | the merchant's woven basket |
| `icon_gear` | ⚙ | daisy-as-gear (petals = teeth) |
| `icon_check` | ✓ green badge | leaf-shaped check, fresh green |
| `icon_lock` | Lv-gate grey pin | small wooden padlock with a sprout keyhole |
| `icon_question` | ladder "?" | carved wooden question mark |
| `icon_home` | ◀ Home | tiny farmhouse silhouette |
| `icon_back` | ◀ | leaf-shaped left arrow |
| `icon_level` | Lv chip | sprout in a ring |
| `icon_cash` | IAP rows | folded leaf "banknote" |

Pattern: `Look.stat_chip(icon_id, label)` = chip panel + icon + number — the
HUD, water chip, prices, pins all use it. Fallback before art: the current
glyph in a Label (exactly today's look), so the swap is art-arrival, not code.
In-WORLD text glyphs (bramble ✿N badges) keep the glyph until `icon_star`
lands, then `_make_bramble` swaps to icon+number too.

---

## §4 — Generate vs code (the full split)

**Generated (ART_CHECKLIST §H):** 3 nine-patch panels · `btn_leaf` (one pill
nine-patch; states are code tints) · `btn_round` (one round wood button; the
glyph on top is an icon sprite) · `ribbon_title` · `divider_vine` · the 14
icons (§3) · `shop_stall` header banner (§8). ~22 images, one batch, one chat.

**Stays code-drawn forever:** veils, shadows, slot grids, swatches, progress
fills, breathing/tween states, disabled desaturation (shader), text. **Already
generated, untouched:** items, generators, brambles, busts, map art, particles,
tray, fence (queued).

---

## §5 — Layout & aspect ratios

Base canvas **1080×1920 portrait**, `canvas_items` + `expand` — width is the
design constant; height/width both grow on other devices. **Portrait-locked
v1** (no landscape work). QA matrix (use `board_shot`'s `WxH` arg; add the same
optional arg to `home_shot`): **1080×1920** (base) · **1170×2532** (modern
tall phone) · **1536×2048** (iPad 3:4).

Anchoring rules (already mostly true — this makes them LAW):

- **Top bar (Hud module):** the ONLY top-right authority — wallet + Store at
  `safe_top + 16`, identical pixels every scene. Scene chip (Lv / 💧) top-left,
  same row height (≤64). Nothing else may pin into the top 160px.
- **Bottom dock:** primary CTA bottom-center (`-24 - safe_bottom`), utility
  buttons in corners (gear right, back/classic left). Same offsets every scene.
- **Board screen:** fence band and bag bar are fixed-height rows; the grid
  takes `min(width-fit, height-budget)` — fills phone width edge-to-edge; on
  iPad it height-binds and centers with terrain art showing at the sides
  (that's correct, not a bug). Fence stands stay 330px and scroll; never shrink.
- **Map screen:** free-pan world; pan clamps to map bounds; focus centering
  biases to y·0.40–0.44 to clear the bottom dock. Chrome floats above.
- **Overlays:** CenterContainer card, width = `min(920, viewport·0.86)`;
  content scrolls inside the card if taller than `viewport·0.78` (cards never
  outgrow the screen on small devices).
- **Interior view (zones, order K):** full-rect takeover UNDER the Hud module
  (bottom chrome hidden while open); the room art is CONTAIN-fit (3:4) with a
  warm room-tone surround filling taller screens; `spot.pos` maps to the ART
  RECT only; plank header strip (name + stars-left + back); OS back closes.
- **Safe areas:** ONLY via `Look.safe_top/safe_bottom` (mobile-gated). No raw
  notch math anywhere else.

---

## §6 — Screen juice (the standard vocabulary)

All implemented once in `FX`/`Look`, used by name:

| name | motion | where |
|---|---|---|
| `press` | scale 0.96 in, overshoot 1.03 out (0.09s) | every button/row on touch |
| `pop_in` | scale 0.92→1 + fade 0.12s `TRANS_BACK` | overlay cards, confirms |
| `scatter_in` | per-item scale 0.3→1, stagger 0.04s | chest items (F), shop cards |
| `fly_to_wallet` | icon sprite arcs to the HUD chip + chip `tick` | any grant (coins/gems/stars/water) |
| `tick` | number counts toward target ~0.4s + chip pulse 1.06 | wallet labels |
| `wiggle` | ±6° rotation ×3 | idle merge hint, refusals |
| `breathe` | scale 1↔1.04 loop | the ONE suggested next action per screen (max one breathing thing at a time) |
| `hop` | quick squash-stretch jump, ~0.25s | tapped ambient spirits |
| `ambient_bob` | slow 1-3px float loop ±2° tilt | wandering spirits (idle motion) |
| `floater` | outlined text drift-up + fade | world feedback |

Calm mode halves particle counts (existing) and disables `breathe`.

---

## §7 — Component treatments (delta from today)

- **Hud module:** chips → `panel_chip` + sprite icons + `tick` on change; Store
  = `btn_round` + `icon_cart`. Metrics unchanged.
- **Fence quest cards:** card → `panel_parchment`; star reward chip →
  `stat_chip(icon_star, +N)`; ready ✓ → `icon_check` badge + green border tint;
  the fence wall → `fence_grove` art (queued) over `panel_plank` fallback.
- **Board mat:** keep current pop (it's the spec look); the moss texture swaps
  to `tray_grove_tall` when generated.
- **Zones (orders F→K):** the MAP shows only the closed state (building +
  status line) — fully diegetic, no panels on the terrain. Tapping opens the
  Interior view (§5) where the same `stat_chip` pins, furniture sprites, and
  the inline swatch strip live. Ambient spirits/weather ride `ambient_bob` /
  `hop` and never intercept input.
- **Ladder card:** parchment card + `pop_in`; unseen tiers → `icon_question`;
  highlight ring stays code.
- **Settings:** parchment + `btn_leaf` toggles; gear button → `icon_gear`.
- **Floaters/celebrations:** unchanged motion, fonts per §2.

---

## §8 — THE SHOP: a storefront, not a list (owner's named example)

The shop is **the squirrel merchant's market stall**:

```
╭─ shop_stall banner (squirrel at his stall awning — generated, wide) ─╮
│            [ribbon_title: "Shop" — engine text on the ribbon]         │
│  wallet strip: [icon_coin N] [icon_gem N]      (you're here to spend) │
│                                                                       │
│  ── Quick help ──────────────────────────────── (divider_vine)        │
│  ┌────────────────────────────┐ ┌────────────────────────────┐        │
│  │ icon_rain 64  Fill water   │ │ icon_coin 64  Coin pouch   │        │
│  │ caption: top up the can    │ │ caption: +150 acorns       │        │
│  │           [chip: 25 gem]   │ │           [chip: 5 gem]    │        │
│  └────────────────────────────┘ └────────────────────────────┘        │
│  ── Dewdrop pouches ─────────────────────────── (divider_vine)        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                             │
│  │ gem art  │  │ gem art  │  │ gem art  │   3-up GRID of cards;       │
│  │   80     │  │  450     │  │  1000    │   middle wears a small      │
│  │ [$0.99]  │  │ [$4.99]  │  │ [$9.99]  │   "Popular" ribbon (code)   │
│  └──────────┘  └──────────┘  └──────────┘                             │
╰── round wood ✕ top-right; tap-outside closes ─────────────────────────╯
```

Behavior: opens with `pop_in`, sections `scatter_in`; water card only when a
water sink exists (unchanged); unaffordable card = desaturated + grey price
chip (whole card still pressable → wallet wiggles + "Need N more" floater);
purchase = card bounce + `fly_to_wallet` + `tick` (NO full rebuild flash);
cash cards → existing confirm (parchment, `pop_in`, test-build caption kept).
Grant functions and prices unchanged — this is presentation only.

---

## §9 — Order of work

`BUILD_QUEUE.md` §G-UI: **G1** Look kit API + emoji→icon swap points +
font drop-in (all with fallbacks; zero visual regression before art) →
**G2** Shop storefront rebuild (works with fallback panels immediately) →
**G3** sweep fence/HUD/ladder/settings onto the kit + juice vocabulary →
**G4** aspect QA matrix shots + click tools + sweep. Art generates in
parallel from `ART_CHECKLIST.md` §H and auto-upgrades the same UI as it lands.
