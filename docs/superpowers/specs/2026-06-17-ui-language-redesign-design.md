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

- **Board surface → a desaturated neutral** (sage / oat / soft warm-grey — locked to cool sage; see Reference instantiation). It recedes and becomes a stage.
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

These concretize the role tiers above into the palette locked during design (2026-06-17). Most chrome values are retained from the existing tuned system; the systemic change is the **board field** (olive → **cool sage `#D9DCC4`**, chosen over warm oat / warm wheat for the strongest item pop via warm-cool contrast and tightest fit to the neutral-backdrop model) and the **locked state** (dark olive → recessive muted sage).

### Palette

| Group | Token | Hex |
|---|---|---|
| **Surface** | screen chrome bg · board field · board frame | `#EFE7D5` · `#D9DCC4` · `#C3C8AC` |
| | empty cell (inset) · locked (Sunk) · lock glyph | `#CFD3B6` · `#C2C7A6` · `#8F977A` |
| | near-unlock · hint border · card pedestal | `#CDD3B0` · `#8FAE6E` · `#F2EFDC` |
| **Ink** | ink · muted · cream | `#3B402F` · `#7A7558` · `#FBF3EA` |
| **Accents** (reserved) | CTA green / edge · reward gold / bright | `#4E7C46`/`#3C6037` · `#E3B23C`/`#FFD56B` |
| | alert red · close red · info blue | `#E24B4A` · `#D75A4E` · `#5FA8D8` |
| **HUD** | wallet pill / edge · level token / ring | `#FBF6EC`/`#C9A66B` · `#3F6B43`/`#C9A66B` |
| **Nav** | neutral round button (fill / ring) · primary destination | `#FBF6EC`/`#C9A66B` · `#4E7C46` |
| **Currency tints** | star · acorn · gem · water | `#F2C14E` · `#C8852F` · `#3FC6B0` · `#7FB9DD` |
| **Shop** | parchment / edge · hero plate · banner | `#F4E9D6`/`#8A5A3B` · `#F4E7CA` · `#F0DCA8` |

Warm cream chrome (`#EFE7D5`) intentionally frames the cooler sage play field so the board reads as its own zone. This is a reference instantiation, not a contract — implementation may fine-tune within each tier so long as the plane relationships hold (locked recedes below playable; accents stay reserved for meaning).

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

- **Burst-upgrade pill** (`board.gd`) — the §6/§10 coin sink's only entry point. The **sink itself stays in code** (`burst_lvl` / `burst_count` / `_upgrade_gen_burst` / cost ladder); only the pill is gone. The redesign must re-surface a burst-upgrade buy affordance (a Rest-plane chip, hub- or generator-anchored) in the new chip language.
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

## Appendix: image-generation prompts

Copy-paste prompts for a diffusion model (Midjourney / DALL·E / SDXL) to produce painterly reference art on-palette.

**Top pill set (level → currencies)**

> Mobile game HUD top bar, cozy hand-painted farm style, soft storybook illustration. Left: round level token, deep leaf-green #3F6B43 disc with a warm-gold #C9A66B ring, cream "3" numeral. Right: a single cream capsule pill #FBF6EC with a thin gold #C9A66B edge, holding three currency icons — a gold flower star #F2C14E, a warm-brown acorn #C8852F, a teal gem #3FC6B0 — each with a number, and a small round leaf-green "+" button. Center is empty (no chapter ribbon). Flat warm lighting, subtle soft drop shadow, no gradients on UI, transparent bg.

**Board**

> Top-down cozy merge-game board, hand-painted warm storybook style. A calm cool-sage play field #D9DCC4 framed by a soft muted-sage border #C3C8AC. Bright interior cells hold colorful garden items — tomato, carrot, sprout, flower, honey — each grounded by a soft contact shadow (no disc) so they pop against the cool field. The outer frontier cells are quiet, desaturated muted-sage #C2C7A6 with a small low-contrast padlock glyph #8F977A, clearly receding behind the play area. Two near-unlock cells glow faintly green #8FAE6E. Items saturated, locks muted, soft daylight, no harsh outlines.

**Quest / order bar**

> Row of cozy farm order cards, hand-painted UI. Each card is warm parchment #F4E9D6 with a soft bark edge: a large round character avatar as the focal anchor, the requested item on a pale cream pedestal #F2EFDC, a gold-coin reward "+6" in warm gold #E3B23C, and a status chip. One card is bright and raised with a leaf-green #4E7C46 "Ready" chip; the next is dimmed and flat with a muted "Lv 4" lock chip. Storybook lighting, soft shadows on the ready card only, transparent bg.

**Bottom navigation + primary action**

> Cozy farm mobile-game bottom navigation, hand-painted. One row of small neutral round buttons, cream #FBF6EC with a warm-gold #C9A66B ring and ink #3B402F icons (home, bag, shop, settings), sitting flat and quiet. Above the row, a single slim leaf-green #4E7C46 pill with a #3C6037 rim and a cream label — a contextual call-to-action carrying a gold-star #FFD56B cost — raised with a soft drop shadow. On the map screen, one button instead becomes a larger green #4E7C46 round "enter garden" button: the single primary destination. Warm light, soft shadows, no two-row stack.

**Shop component**

> Cozy farm-game shop popup, hand-painted storybook style. A warm parchment panel #F4E9D6 with a soft bark border over a dimmed warm-dark scrim. A honey banner title #F0DCA8 reads "Shop"; a round red close button #D75A4E sits at the top-right corner. Two featured product cards, each a cream tile with the product illustration on a pale honey plate #F4E7CA and a leaf-green #4E7C46 price button. Below, a "Gems" section: a row of three teal-gem #3FC6B0 cash packs of increasing size, the middle one wearing a small red "Popular" badge, each with a green buy button. Soft shadows, warm light, no flat vectors.
