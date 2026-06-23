# UI Language & Color Scheme Redesign — Design Spec

**Date:** 2026-06-17
**Scope:** Full UI-language system (palette · board · HUD · order strip · shop · overlays)
**Approach:** Principles + direction (no locked hex values — exact colors tuned during implementation)
**Contrast model:** Neutral board, items pop (the cat-game reference)
**Art direction:** Keep the existing painterly cozy-farm illustration. This is a redesign of the *UI system layered on top of the art*, not a re-theme.

---

## Problem statement

The current board reads as a wall of locks on a single flat olive field. Diagnosed at the code level in `games/grove/grove_palette.gd`:

- The play surface `GROUND #3F6B43`, locked cells `BRAMBLE_BG #4A5A3A`, and primary button `BTN_PRIMARY #4E7C46` are **all dark olive-greens inside a ~15-point range**. The palette itself has no figure/ground separation.
- The palette is a **flat list of ~30 named colors** with no semantic tiers (surface / recede / item-pop / accent), so every element renders at one perceptual depth.
- Consequence: locked/inert state is the highest-contrast thing on screen, playable items do not pop, the grid does not read as structure, and the core loop (orders) is the least legible element.

The fix is a **system**, not a recolor: a depth ladder, a de-overloaded palette organized by role, and one consistent cell/item/locked/HUD/order language built on top.

---

## Foundation

### 1. One depth ladder — three planes

Every element sits on exactly one of three planes. Saturation is a privilege of the top two.

| Plane | What lives here | Treatment | Color budget |
|---|---|---|---|
| **Sunk** *(new)* | Locked/sealed cells, inert/empty ground | Inset or shadowless; value pulled *toward* the surface; desaturated | None — neutral only |
| **Rest** | Cells, pills, chips, HUD chrome, secondary buttons | Soft resting shadow (existing `SHADOW_RESTING`) | Neutral + at most one identity tint |
| **Float** | Items/pieces, primary CTA, active orders, rewards | Raised/contact shadow (existing `SHADOW_RAISED`) — grounding, no disc on the board | Full saturation — color lives here |

The engine already runs a two-tier shadow system (`SHADOW_RESTING` / `SHADOW_RAISED` in `tuning.gd` → `UiSkin`). This redesign **adds a third, lower tier — Sunk** — and assigns every element type to a plane. That single rule fixes the core failure: locked cells move *below* playable content instead of shouting above it.

### 2. Stop overloading green

Green currently means three contradictory things: play surface (`GROUND`), locked state (`BRAMBLE_BG`), and primary action (`BTN_PRIMARY`). This is the root cause of the missing figure/ground.

- **Board surface → a warm, hand-painted garden-bed neutral** (a soft cream-tan mat with a gentle low-contrast tilled-soil texture — see Reference instantiation; colour-rich and cozy, never flat white). It recedes into a warm, airy stage so the items pop.
- **Green is reclaimed as a signal** — growth, "go," primary CTA. It now means something because it is the only green on screen.
- **Items keep their painterly saturation** and pop against the neutral stage automatically.

### 3. Color system — semantic role tiers

`grove_palette.gd` is restructured from a flat list into **role tiers**. Values below are described by *intent*; exact hex is tuned during implementation.

- **Surface** — desaturated neutral, low saturation, mid-high value. The stage. (Replaces olive `GROUND`.)
- **Cell / inset** — a hair off Surface; delineates the grid by *structure*, not contrast.
- **Locked** — desaturated, value-merged toward Surface, faint texture hint. Recedes.
- **Item grounding** — a soft contact shadow that lifts any piece onto the Float plane; no disc on the board (a full `ICON_PLATE` pedestal stays in card contexts like orders and shop).
- **Accents — reserved, used ONLY to carry meaning:**
  - `CTA / growth` = leaf green
  - `reward / value` = honey-gold
  - `alert / new` = warm red (existing `#E24B4A`)
  - `info` = soft blue (existing `#5FA8D8`)
  - No structural element may use an accent hue.
- **Ink** — text on light (`INK`) / text on dark (`CREAM`), plus one muted variant.

Raw named colors stay; the new semantic layer maps **role → value**, so consumers ask for `Surface` or `Accent.CTA`, never a raw hue. This is what makes it a system and what lets the whole look re-tune from one file.

---

## Application layer

### 4. Cell + item container system

- **One cell.** Every board cell is the same rounded-square slot at one shared radius. Empty = a subtle inset on the Surface (Sunk plane). The grid reads as structure, never as content.
- **One grounding.** Every item is grounded by a soft contact shadow (no disc) — a consistent base that lifts pieces onto the Float plane and gives figure/ground without a busy repeated plate on every occupied cell. (Full `ICON_PLATE` pedestals were considered for the board and dropped; they remain in card contexts — orders and shop.)
- **One item box + optical scale.** The HUD already solves uneven art weight with `CHIP_ICON_BOX` + per-icon `*_OPTICAL`. Extend that pattern to board pieces: a single `ITEM_BOX` with per-item optical scale, so a large item (seed bag) no longer dwarfs a small one (shovel).

### 5. Locked / sealed state — the most visible fix

- Locked cells render on the **Sunk plane**: desaturated, value pulled toward Surface, faint covered-ground texture — never a high-contrast badge.
- The lock indicator is a **small, low-contrast glyph**, not the loudest thing on screen.
- `Lv2`-style gates show their requirement as a **quiet micro-label**, de-emphasized until the player is one merge away — then it brightens, reusing the existing openable-cell hint-pulse (`BoardLogic.openable_for_hint`). Anticipation, not a wall.
- **The play area is the brightest region; the locked frontier recedes outward.** Figure/ground by value.

### 6. HUD

- Keep the cream-pill currency cluster — already well-tuned (shared icon box, optical scale, identity tints). It lives on the **Rest plane**.
- **Collapse the shape vocabulary.** Today there are four shape languages (round level token, capsule wallet, floating chip, raw icon-numbers). Mandate one corner-radius/elevation family. Spatial grouping: the level token top-left, the wallet pill top-right, consistent `EDGE_MARGIN`.
- **No chapter ribbon.** The chapter concept is retired — the existing `chapter_label` in `board.gd` should be deleted, not restyled. The center of the top bar stays empty, which also reclaims vertical space.

### 7. Order / giver strip — surface the core loop

The most-buried element in the current screen, and the point of the game.

- Each order = a card in the shop's existing help/featured card language (`CARD_BG` cream): the **character avatar is the card's anchor — enlarged**, since *who* wants it carries the charm; beside it the **what** (the requested item on an `ICON_PLATE` pedestal — cards keep the pedestal), the **reward** (honey-gold accent), and **progress**.
- **Actionable vs pending uses planes, not guesswork:** a deliverable order rides the **Float plane** at full saturation (and may breathe); a not-yet-payable order sits on **Rest**, dimmed via the existing `SHADE_LIT` / `SHADE_DIM` shades in `board.gd`.

### 8. Typography & labels

One ramp, four roles:

- **Display** — titles, ribbons
- **Number** — currency, big counts
- **Label** — chips, captions
- **Micro** — tile labels (`Lv2`, `Burst L0`)

Ink on light = `INK`, on dark = `CREAM`, plus one muted. Tile labels get **one placement convention** (a small pill, bottom-center of the cell) at the Micro size, fixing today's scattered placement.

### 9. Iconography & affordance

- **One chrome style.** Today painterly background + flat vector pills + semi-real items fight each other. Rule: *chrome* glyphs = soft, slightly-illustrated to match the art; *content* = painterly. Pick one chrome style and apply it everywhere.
- **Affordance tracks plane.** Mergeable/actionable cells get Float + optional idle breathe (existing `BREATHE_*`); inert cells get nothing. Tappable things press (existing `PRESS_*`). Interactivity becomes legible.

### 10. Motion / feedback

Motion reinforces the depth planes rather than decorating: Float elements may pop/breathe, Sunk/locked elements stay still, rewards arc to the wallet (existing `fly_to_wallet`). Start from the existing FX dials, **and add net-new motion where the language calls for it** — e.g. a satisfying merge/fuse, a sealed-cell reveal (covered ground peeling back) on unlock, an order-complete celebration, and a near-unlock anticipation cue. New motion is in scope when it serves a moment in the loop, not as ambient decoration.

### 11. Navigation & primary action

The bottom chrome differs by page today (board: `[◀ Home][Shop]` + Bag + a contextual gate CTA; map: `[Garden→board][gear][shop][atlas]`). The redesign unifies it without flattening the difference:

- **One nav row, everywhere.** A single row of neutral round chrome buttons (Rest plane), same shape/size on every page; only the icon set changes per page. No two-row stacks — this is what was eating vertical space.
- **Exactly one green Float button per page — the primary destination.** On the **map** it is *enter garden* (persistent). On the **board** there is no persistent green nav button; the green Float is the **contextual gate CTA**, shown only when the gate is affordable.
- **The gate CTA is a slim, context-labeled pill** pinned above the nav row — not a permanent full-width button. Its label is content-driven (a verb + star cost), never a hardcoded string like "Restore garden".
- Persistent destinations (home/map, bag, shop, settings, atlas/vault) keep consistent icons and order across pages so muscle memory holds.

---

## Reference instantiation (locked values)

These concretize the role tiers above into the palette (2026-06-17, with a same-day art-review lightening pass). Most chrome values are retained from the existing tuned system; the systemic change is the **board field** (olive → a **warm hand-painted garden-bed cream `#ECE0C4`** with low-contrast soft-soil patches `#CDA87A` — a second art-review pass warmed it off the too-pale oat so the board reads colour-rich, cozy and hand-painted rather than flat white, while still receding so items pop) and the **locked state** (dark olive → a whisper-quiet recessive `#D9D2BE`).

### Palette

| Group | Token | Hex |
|---|---|---|
| **Surface** | screen chrome bg · board field (+ soil `#CDA87A`) · board frame | `#F4EEDF` · `#ECE0C4` · `#D8B483` |
| | empty cell (inset) · locked (Sunk) · lock glyph | `#E6DBBA` · `#D9D2BE` · `#A99F86` |
| | near-unlock · hint border · card pedestal | `#E2D6B6` · `#8FAE6E` · `#F2EFDC` |
| **Ink** | ink · muted · cream | `#3B402F` · `#7A7558` · `#FBF3EA` |
| **Accents** (reserved) | CTA green / edge · reward gold / bright | `#4E7C46`/`#3C6037` · `#E3B23C`/`#FFD56B` |
| | alert red · close red · info blue | `#E24B4A` · `#D75A4E` · `#5FA8D8` |
| **HUD** | wallet pill / edge · level token / ring | `#FBF6EC`/`#C9A66B` · `#EAD49C`/`#C9A66B` |
| **Nav** | neutral round button (fill / ring) · primary destination | `#FBF6EC`/`#C9A66B` · `#4E7C46` |
| **Currency tints** | star · acorn · gem · water | `#F2C14E` · `#C8852F` · `#3FC6B0` · `#7FB9DD` |
| **Shop** | parchment / edge · hero plate · banner | `#F4E9D6`/`#8A5A3B` · `#F4E7CA` · `#F0DCA8` |

The chrome (`#F4EEDF`) and field (`#ECE0C4`) are both warm neutrals, the field a touch deeper and more hand-painted (with soft soil patches `#CDA87A`) — figure/ground comes from the depth planes (locked recedes; items sit on the Float plane) and the warm garden-bed mat, not from a hue contrast between chrome and field. This is a reference instantiation, not a contract — implementation may fine-tune within each tier so long as the plane relationships hold (locked recedes below playable; accents stay reserved for meaning).

### Component reference

Interactive mockups were produced during design for six components, each rendering the values above and standing as the visual target:

- **Top pill set** — round green level token (left) + cream currency capsule (right) with a green "+"; no chapter ribbon, top-bar center stays empty.
- **Board** — colorful items grounded by a soft contact shadow (Float) over the sage field, empty inset cells (Rest), and a recessive muted-sage locked frontier with quiet glyphs (Sunk); two near-unlock cells carry a faint green hint.
- **Quest / order bar** — parchment order cards anchored by a large character avatar; actionable = bright + raised + green "Ready" chip, pending = dimmed + flat + muted "Lv N" chip.
- **Navigation** — one row of neutral round chrome buttons; exactly one green Float button = the page's primary destination (board: the contextual gate pill above the row; map: enter garden). No two-row stack.
- **Map / home page** — the same HUD and nav language in the homestead context; decor spots (cream dashed disc + star cost) as the actionable layer, with one locked spot; the nav's green Float is the persistent *enter garden* button.
- **Shop panel** — parchment card over a warm-dark scrim, honey banner title, red close disc, hero icons on honey plates, green BUY pills, reserved badge slot on the popular gem pack.

Diffusion prompts for painterly reference art are in the appendix.

## Where it lands (file map)

- **`games/grove/grove_palette.gd`** — restructure flat list → role tiers (Surface / Cell / Locked / Pedestal / reserved Accents / Ink). Raw colors stay; add the semantic role→value layer.
- **`engine/scripts/core/tuning.gd`** — add the **Sunk** elevation tier alongside `SHADOW_RESTING` / `SHADOW_RAISED`; add `ITEM_BOX` + optical-scale dials for board pieces; add locked-cell treatment dials. The `Hud` / `UiSkin` / `Shop` classes receive the shape-collapse and order-card values.
- **`engine/scripts/scenes/board.gd`** — apply planes to cells / locked state / items; route orders through the card language; tie near-unlock emphasis to the existing hint-pulse. Remove `chapter_label`; unify the bottom chrome into one neutral nav row plus the slim contextual gate pill.
- **`engine/scripts/scenes/map.gd`** — the map's bottom chrome adopts the same neutral nav row, with *enter garden* as its single green primary destination.
- **`engine/scripts/ui/hud.gd`** — collapse the shape vocabulary (level token + wallet only; no chapter ribbon).
- **`engine/scripts/ui/giver_stand.gd`** — order/giver cards in the shop card language, anchored by an enlarged character avatar, with plane-based actionable/pending states.

### Precursor — the old dark pill widget is retired (T48, 2026-06-17)

Before implementation, the legacy `Look.stat_chip()` → `kit_panel("chip")` → `panel_chip.png` dark nine-patch capsule was **removed wholesale** (Dev call: "remove this stupid semicircle pill thing + related"). It was the clearest instance of the overloaded shape vocabulary §6 collapses. It backed three live surfaces, all now **rendering blank pending their rebuild in this language**:

- **Burst-upgrade pill** (`board.gd`) — the §6/§10 coin sink's only entry point. The **sink itself stays in code** (`burst_lvl` / `burst_count` / `_upgrade_gen_burst` / cost ladder); only the pill is gone. The redesign must re-surface a burst-upgrade buy affordance (a Rest-plane chip, hub- or generator-anchored) in the new chip language. ✅ **DONE — T54** (2026-06-23): re-surfaced on two Dev-chosen surfaces — the board **info bar** on a generator tap + a **water-shop** card — over a shared seam `G.try_upgrade_burst()`. Spec: [`2026-06-23-burst-upgrade-buy-ui-design.md`](2026-06-23-burst-upgrade-buy-ui-design.md).
- **Vault gem balance** (`vault.gd`) — the jar already conveys balance visually; the redundant number-chip was dropped. Rebuild the explicit balance read in the new chip.
- **Merchant sell tag** (`merchant_stand.gd`) — the live "+N🪙/💎 while dragging" affordance. The stall still brightens on drag; the **+N value read was lost** and must return as a new-language chip (a real affordance, not decoration — see BACKLOG).

Orphaned `UiSkin` chip dials (`CHIP_PAD_X/Y`, `CHIP_ALPHA`, `STAT_NUM_SIZE`, `UiSkin.CHIP_ROW_SEP`) were left in place for the `tuning.gd` rework to absorb; `RADIUS_CHIP` stays (this spec's radius scale uses it).

---

## Scope notes

**In scope — and not limited to what exists today.** New art and motion are welcome wherever they advance the language. Reusing an existing pattern (e.g. `ICON_PLATE`, the shop card language, the FX dials) is the default *only when it already fits* — when the system needs something new, make it new:

- **Net-new art** — a consolidated single-style chrome icon set, the locked/covered-ground texture, order/shop card pedestals, the bottom-nav button set, a neutral board surface — whatever the role tiers and cell/item system call for.
- **Net-new motion** — for key moments in the loop (merge/fuse, sealed-cell reveal, order-complete, near-unlock anticipation), building on the existing FX vocabulary where it fits and extending it where it doesn't.

**Out of scope (YAGNI):**

- No re-theme of the cozy-farm identity.
- No change to game logic, board model, merge rules, or progression — visual/UI language only.
- No art or motion unrelated to the UI language: every new asset or animation must serve a principle or a loop moment in this spec, not decorate.

---

## Success criteria

1. On the board, a first-time viewer's eye lands on **items and the active order first**, not on locked cells.
2. Locked cells are visibly *quieter* than playable cells (lower contrast, desaturated, recessed).
3. Every board piece shares a consistent grounding (contact shadow) and optically-balanced scale.
4. Green appears only as a CTA/growth/reward signal — never as a structural surface.
5. The HUD uses one shape/elevation family; the current order/goal is legible at a glance.
6. The entire look re-tunes from `grove_palette.gd` role tiers + `tuning.gd` dials — no per-scene hardcoded colors reintroduced.

---

## Asset manifest & batch generation

**The problem:** the redesign is mostly a re-tune of code-drawn chrome and a palette swap, so it needs surprisingly little *new* art. Most of what looks like UI art is either already in the repo or drawn procedurally. This manifest separates the three cases so generation effort goes only where it is real.

**Legend:** ✅ exists (keep, or retint via the palette) · ⚙️ code-drawn (no art — retune `tuning.gd`) · 🎨 generate.

### Already have (✅)
- **Icon kit** `games/grove/assets/ui/kit/icon_*.png`: `home`, `gear`, `cart`, `coin`, `gem`, `star`, `water`, `lock`, `level`, `check`, `back`, `question`, `cash`, `rain`. Resolved via `Look.icon("<id>")` ([skin.gd:201](../../../engine/scripts/ui/skin.gd)).
- **Surfaces / panels** `ui/kit/`: `panel_parchment`, `panel_plank`, `ribbon_title`, `divider_vine`, `btn_leaf`, `btn_round`, `shop_stall`; plus `ui/`: `tile_slot`, `wallet`, `board_tray`, `bg_grove_board`, `fence_grove`.
- **Content:** 71 item PNGs (`items/`), generators (`ui/gen_*`), characters (`map/giver_*`, `client_*`, `spirit_*`, `wren_bust`), map art (`map/poi_*`, `way_*`, `map_*`), FX (`fx_sparkle`, `fx_glow`, `p_*`).

### Code-drawn — no art (⚙️)
Currency pills, chips, the level token, nav button bases, the CTA / contextual gate pill, the red close ✕ disc, the "+" acquire token, badges, and the item **contact shadow** are all built from `tuning.gd` StyleBoxFlat + the sticker recipe (`RIM_LIGHT` + tiered shadows). These are *retuned*, never generated.

### Generate (🎨)
1. **Unified chrome icon kit (Batch 1, 12 icons).** Spec §9 ("one chrome style") wants the whole kit matched. Three are net-new (`bag`, `map`, `sprout`); the other nine are restyled for consistency. One 3×4 grid covers all 12.
2. **Recessive locked texture (single, full-bleed).** The current `bramble_1-3` read dark and high-contrast; the Sunk plane needs a quiet covered-soil texture in the `LOCKED #D9D2BE` family. Surfaces generate individually (tileable, full-bleed), not in the isolated-object grid.
3. **Painterly container surfaces (reskin).** The **board backdrop** (`ui/bg_grove_board.png`) is the key miss — it is the old *olive* field and clashes with the sage stage; plus the **fence band** and an **optional board frame**. Shop containers and the order box are reused / code-drawn (see below). Detailed in "Painterly surfaces".

### Painterly surfaces — reskin / generate (containers & backdrops)

How the board/shop/quest containers split:

- **Board backdrop `ui/bg_grove_board.png` — RESKIN (the key one).** Today's olive painted field clashes with the warm garden-bed cells. Either regenerate it as a quiet warm garden-bed stage, or drop it for a flat `SURFACE` fill (code-drawn, fully re-tintable) — an open decision.
- **Fence band `ui/fence_grove.png` — RESKIN if it clashes.** The wall the givers pop over; verify against sage in Phase 2 — warm weathered wood may sit fine, else retint cooler/quieter.
- **Board frame/border — code-draw or generate.** No frame asset today (the backdrop is the edge). Default is a code-drawn `SURFACE_FRAME` border; generate a painterly woven/wood nine-patch only if you want more character.
- **Shop containers — REUSE.** `panel_parchment`, `panel_plank`, `shop_stall` are warm-parchment nine-patches already in the cream language; reuse (minor retint at most). Dedicated stall-interior backdrop already parked in BACKLOG.
- **Quest / order box — code-drawn + existing art.** Ask pill / ribbon / chips are `StyleBoxFlat` (re-tintable from the palette); the only raster is the giver animals (`map/giver_*`, exist) and the fence band above.

### Pipeline
Generate at high resolution → slice the grid into 12 cells → alpha-cut each → place into `games/grove/assets/ui/kit/` via `make icon IN=/tmp/<cell>.png OUT=res://games/grove/assets/ui/kit/icon_<id>.png SIZE=512`. Keep the established ids (`home`, `gear`, `cart`, `coin`, `gem`, `star`, `water`, `lock`, `question`) so no code changes; add new ids `bag`, `map`, `sprout` and point the nav buttons at them (Phase 3). The locked texture follows the `make decor` path into `ui/` and is wired where `bramble_*` is loaded ([board.gd](../../../engine/scripts/scenes/board.gd)).
