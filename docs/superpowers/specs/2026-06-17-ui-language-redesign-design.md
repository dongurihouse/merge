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

- **Board surface → a light, desaturated warm neutral** (a low-green warm oat/cream — see Reference instantiation). It recedes into an airy, uncluttered stage so the items pop.
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

These concretize the role tiers above into the palette (2026-06-17, with a same-day art-review lightening pass). Most chrome values are retained from the existing tuned system; the systemic change is the **board field** (olive → a **light warm neutral `#EDE6D2`** — lightened and warmed from the earlier sage per art review: less green, an airier, less-busy stage that lets the items pop with more juice) and the **locked state** (dark olive → a whisper-quiet recessive `#D9D2BE`).

### Palette

| Group | Token | Hex |
|---|---|---|
| **Surface** | screen chrome bg · board field · board frame | `#F4EEDF` · `#EDE6D2` · `#E0D6BC` |
| | empty cell (inset) · locked (Sunk) · lock glyph | `#E7DFC9` · `#D9D2BE` · `#A99F86` |
| | near-unlock · hint border · card pedestal | `#E4DCC4` · `#8FAE6E` · `#F2EFDC` |
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

> Top-down cozy merge-game board, polished premium mobile-game art — bright, clean, uncluttered. A light, airy warm-cream play field #EDE6D2 in a slim soft frame #E0D6BC, with barely-there rounded cell slots so the grid stays quiet. The heroes are the items: vibrant, glossy, candy-bright garden pieces — tomato, carrot, sprout, flower, honey — each lifted on a soft drop shadow with a gentle glow halo and a tiny sparkle, popping joyfully off the pale surface. The locked frontier is whisper-quiet, a pale #D9D2BE with faint low-contrast lock glyphs #A99F86 that fully recede. Two near-unlock cells carry a soft hint. Saturated juicy items, quiet recessive locks, soft diffused light, gentle bloom, no busy texture, no heavy green, no harsh outlines.

**Board — full screen**

> Full cozy farm merge-game board screen, portrait mobile, polished premium mobile-game art — bright, clean, airy and dopamine-inducing. Keep the background SIMPLE and uncluttered: a soft light warm-cream wash #F4EEDF with only the faintest hint of depth, nothing competing with the board. The board rests on a light airy surface #EDE6D2 in a slim soft frame #E0D6BC; the cells are barely-there rounded slots so the grid stays quiet. The heroes are the items — vibrant, glossy, candy-bright garden pieces (ripe red tomato, bright carrot, fresh sprout, pink flower, golden honey), each lifted on a soft drop shadow with a gentle glow halo and a tiny sparkle, popping joyfully off the pale surface. The locked frontier is whisper-quiet: a pale #D9D2BE with faint low-contrast lock glyphs #A99F86, fully receding. Menu chrome is light and crisp: a cream #FBF6EC currency pill with glossy gold #F2C14E, teal #3FC6B0 and warm-brown #C8852F coin icons that shine; a soft gold-cream level token with a warm-gold #C9A66B ring; an order strip of clean cream cards with big charming character avatars and a glowing leaf-green #4E7C46 "Ready" chip. Green appears ONLY as a single small accent — one leaf-green #4E7C46 contextual action pill near the bottom — never as the surface or the chrome. Below it, one row of light neutral cream #FBF6EC round nav buttons (home, bag, shop, settings). Soft diffused daylight, gentle bloom, juicy glossy highlights, generous spacing, premium and satisfying, no clutter, no heavy outlines, no dark heavy greens.

**Quest / order bar**

> Row of cozy farm order cards, hand-painted UI. Each card is warm parchment #F4E9D6 with a soft bark edge: a large round character avatar as the focal anchor, the requested item on a pale cream pedestal #F2EFDC, a gold-coin reward "+6" in warm gold #E3B23C, and a status chip. One card is bright and raised with a leaf-green #4E7C46 "Ready" chip; the next is dimmed and flat with a muted "Lv 4" lock chip. Storybook lighting, soft shadows on the ready card only, transparent bg.

**Bottom navigation + primary action**

> Cozy farm mobile-game bottom navigation, hand-painted. One row of small neutral round buttons, cream #FBF6EC with a warm-gold #C9A66B ring and ink #3B402F icons (home, bag, shop, settings), sitting flat and quiet. Above the row, a single slim leaf-green #4E7C46 pill with a #3C6037 rim and a cream label — a contextual call-to-action carrying a gold-star #FFD56B cost — raised with a soft drop shadow. On the map screen, one button instead becomes a larger green #4E7C46 round "enter garden" button: the single primary destination. Warm light, soft shadows, no two-row stack.

**Map / home page**

> Cozy farm-game map / homestead screen, hand-painted storybook style. A soft daylight scene — pale sky, rolling meadow, a small farmhouse and trees. The same UI chrome as the board: a round leaf-green #3F6B43 level token with a gold #C9A66B ring top-left, a cream #FBF6EC currency pill top-right. On the meadow sit decor "spots" to restore — cream #FBF6EC discs with a dashed gold #C9A66B rim, a warm-brown #C8852F plus, and a small gold-star #FFD56B cost — plus one locked spot as a muted #D9D2BE disc with a quiet lock glyph #A99F86. A bottom row of neutral cream round buttons, with the "enter garden" button promoted to a larger leaf-green #4E7C46 primary destination. Soft warm light, no flat vectors.

**Shop component**

> Cozy farm-game shop popup, hand-painted storybook style. A warm parchment panel #F4E9D6 with a soft bark border over a dimmed warm-dark scrim. A honey banner title #F0DCA8 reads "Shop"; a round red close button #D75A4E sits at the top-right corner. Two featured product cards, each a cream tile with the product illustration on a pale honey plate #F4E7CA and a leaf-green #4E7C46 price button. Below, a "Gems" section: a row of three teal-gem #3FC6B0 cash packs of increasing size, the middle one wearing a small red "Popular" badge, each with a green buy button. Soft shadows, warm light, no flat vectors.

**Settings card**

> Cozy farm-game settings popup, hand-painted storybook style. A warm parchment card #F4E9D6 with a soft bark border, centered over a dimmed warm-dark scrim. A honey banner title #F0DCA8 reads "Settings"; a round red close button #D75A4E at the top-right corner. Three stacked toggle rows — "Music", "Sounds", "Calm mode" — each a cream #FBF6EC pill with an ink #3B402F label on the left and a rounded toggle switch on the right: the ON switches filled leaf-green #4E7C46 with a cream knob, the OFF switch a muted grey #C7BBA0. Soft shadows, warm light, no flat vectors, no extra text.

**Map-select / world page**

> Cozy farm-game world map-select screen, hand-painted storybook style. A soft daylight sky with a few drifting clouds as the backdrop. The same UI chrome as elsewhere: a round leaf-green #3F6B43 level token with a gold #C9A66B ring top-left, a cream #FBF6EC currency pill top-right. A gentle vertical path of large map cards, each a painterly thumbnail of a homestead district — a farmhouse, a barn, an orchard, a pond — in a soft cream #FBF6EC rounded frame with a warm-gold #C9A66B edge and a small honey title ribbon. The first card or two are bright and inviting (unlocked); the cards further along sit behind a soft deep-ink #33402F fog that thickens toward their lower edge (locked — teased, not greyed). A neutral cream round back button #FBF6EC bottom-left. Warm light, soft shadows, no flat vectors.

**Daily login calendar**

> Cozy farm-game daily-reward calendar popup, hand-painted storybook style. A warm parchment card #F4E9D6 with a soft bark border over a dimmed warm-dark scrim, a honey banner title #F0DCA8 reading "Daily gifts", a round red close button #D75A4E top-right. Inside, a horizontal week-strip of seven reward cells; each is a small cream #FBF6EC tile with a day label and a gift icon (coins, a gem, a water drop, a wrapped present). The earlier days are claimed with a soft gold checkmark, today's cell is lifted, glowing and gently breathing with a leaf-green #4E7C46 "Claim" button, and the later days are quietly dimmed. Warm light, soft shadows, no flat vectors.

**Inbox / mailbox**

> Cozy farm-game inbox / mailbox popup, hand-painted storybook style. A warm parchment card #F4E9D6 with a soft bark border over a dimmed warm-dark scrim, a honey banner title #F0DCA8 reading "Mail" with a small envelope motif, a round red close button #D75A4E top-right. Inside, a vertical scrollable list of message rows; each row is a cream #FBF6EC strip with a round icon on the left (a gift, a leaf, a notice), an ink #3B402F title and a short muted body line, a gold reward chip, and a leaf-green #4E7C46 "Claim" button on the right. Warm light, soft shadows, no flat vectors.

**Vault / piggy bank**

> Cozy farm-game savings-vault popup, hand-painted storybook style. A warm parchment card #F4E9D6 with a soft bark border over a dimmed warm-dark scrim, a honey banner title #F0DCA8 reading "Vault", a round red close button #D75A4E top-right. The hero is a large hand-drawn ceramic jar, half-filled with glittering teal gems #3FC6B0 and gold coins, a soft fill line showing how much premium has accrued and a gem count above it. Below, one fixed leaf-green #4E7C46 price button with a real-money price. Warm light, soft shadows, no flat vectors.

**Discovery ladder**

> Cozy farm-game discovery-ladder popup, hand-painted storybook style. A warm parchment card #F4E9D6 with a soft bark border over a dimmed warm-dark scrim, a honey banner title #F0DCA8, a round red close button #D75A4E top-right. Inside, a vertical ladder of tier slots from small to large; each slot is a cream #FBF6EC rounded tile — discovered tiers show their painterly item sprite, undiscovered tiers show a soft "?" — and the current tier wears a warm-gold #C9A66B ring. A gentle vine or dotted path links the slots. Warm light, soft shadows, no flat vectors.

**Out-of-water offer**

> Cozy farm-game "out of water" offer popup, hand-painted storybook style. A small warm parchment confirm card #F4E9D6 with a soft bark border over a dimmed warm-dark scrim, a honey banner title #F0DCA8 reading "Out of water", a round red close button #D75A4E top-right. A centered watering-can / blue water-drop #7FB9DD icon with an amount line, a short muted sub copy, and a tiny disclosure line. Two buttons side by side at the bottom: a neutral cream #FBF6EC "Maybe later" and a leaf-green #4E7C46 "Yes please". Warm light, soft shadows, no flat vectors.

**Purchase / cash confirm**

> Cozy farm-game purchase-confirm popup, hand-painted storybook style. A small warm parchment card #F4E9D6 with a soft bark border over a dimmed warm-dark scrim, a honey banner title #F0DCA8, a round red close button #D75A4E top-right. Centered, a "what you get" row — a hero icon (a teal gem cluster #3FC6B0 or a coin pouch) on a pale honey plate #F4E7CA with an amount — above a short note. Two buttons at the bottom: a neutral cream #FBF6EC "Cancel" and a leaf-green #4E7C46 buy button showing the price. Warm light, soft shadows, no flat vectors.

**Item detail / info sheet**

> Cozy farm-game item-detail sheet, hand-painted storybook style. A warm parchment card #F4E9D6 with a soft bark border over a dimmed warm-dark scrim, a round red close button #D75A4E top-right. At the top, the item's painterly illustration enlarged on a pale honey plate #F4E7CA, its ink #3B402F name below, then a short body paragraph of muted description, and a small row of meta chips (where it comes from / what it makes). One leaf-green #4E7C46 button at the bottom. Warm light, soft shadows, no flat vectors.

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

### Batch 1 — the 3×4 icon-kit grid prompt

> A single square image laid out as a clean 3-column × 4-row grid (12 equal cells) with even gutters and a plain off-white #F3EEE2 background. Each cell holds ONE cozy farm-game UI icon, centered and isolated with generous padding so it can be cropped out on its own. Cohesive hand-painted storybook style: soft rounded forms, a gentle top rim-light, a small soft contact shadow, warm muted palette keyed to leaf-green #4E7C46, warm gold #C9A66B, ink #3B402F, honey #E3B23C, teal #3FC6B0, sky-blue #7FB9DD; identical scale, line weight, and lighting across all 12. No text, no labels, no frames around the cells. The 12 icons, left to right, top to bottom — row 1: a cozy cottage (home), a canvas backpack (bag), a wooden market stall (shop); row 2: a settings gear, a folded paper map, a young sprout in soil (garden); row 3: a five-point gold star, a teal cut gem, a blue water drop; row 4: a brown acorn coin, a closed padlock, a lowercase letter "i" in a circle (info).

### Locked / covered-soil texture prompt (single, 3 variants)

Replaces `bramble_1-3` — the clearable cover over sealed cells. Generated as a 1×3 strip (three variants for board variety, matching today's count); the padlock is *not* part of this art — it is the separate code-drawn `icon_lock` glyph laid on top per the Sunk treatment.

> Three cozy farm-game "covered ground" tiles in a single 1×3 horizontal strip, evenly spaced on a transparent background, each a square cell-sized cover for a merge board. Hand-painted storybook style, but deliberately QUIET and recessive: a soft mound of tangled moss, leaf-litter and loose soil filling the cell, in a muted desaturated warm-grey-beige family keyed to #D9D2BE with the darkest accents no stronger than #A99F86 — low contrast, no bright highlights, no hard outlines, gently shadowed so it reads as sunken and sealed rather than popping forward. Three subtly different variants (denser, sparser, and one with a few tiny dormant sprigs). No padlock, no text, no bright greens, consistent soft lighting and scale across all three.

### Painterly surfaces — reskin / generate (containers & backdrops)

How the board/shop/quest containers split:

- **Board backdrop `ui/bg_grove_board.png` — RESKIN (the key one).** Today's olive painted field clashes with the sage cells. Either regenerate it as a quiet neutral sage stage (prompt below), or drop it for a flat `SURFACE` fill (code-drawn, fully re-tintable) — an open decision.
- **Fence band `ui/fence_grove.png` — RESKIN if it clashes.** The wall the givers pop over; verify against sage in Phase 2 — warm weathered wood may sit fine, else retint cooler/quieter.
- **Board frame/border — code-draw or generate.** No frame asset today (the backdrop is the edge). Default is a code-drawn `SURFACE_FRAME` border; generate a painterly woven/wood nine-patch only if you want more character.
- **Shop containers — REUSE.** `panel_parchment`, `panel_plank`, `shop_stall` are warm-parchment nine-patches already in the cream language; reuse (minor retint at most). Dedicated stall-interior backdrop already parked in BACKLOG.
- **Quest / order box — code-drawn + existing art.** Ask pill / ribbon / chips are `StyleBoxFlat` (re-tintable from the palette); the only raster is the giver animals (`map/giver_*`, exist) and the fence band above.

**Board backdrop prompt (textured sage reskin):**

> A seamless cozy farm-game board backdrop, hand-painted storybook style, top-down. A calm, QUIET light warm field #EDE6D2 that reads as a neutral stage so colourful items pop on top — a soft low-contrast painterly texture (a faint hint of tilled-soil rows at most), no bright greens, no busy detail, airy and even soft daylight, a gentle edge vignette toward #E0D6BC. Full-bleed, fills the frame, nothing centered, designed to sit behind a grid of game items.

**Fence band prompt (reskin):**

> A long horizontal cozy farm fence band, hand-painted storybook style, to run full-width across the top of a merge board as a low wall that character animals pop up behind. Soft weathered wood in warm muted tones that sit calmly against a light warm #EDE6D2 board below — low contrast, no bright saturated colour, with a plain flat area along the top rail for characters to rest on. Transparent above and below the fence, tileable horizontally.

**Optional board frame prompt (nine-patch):**

> A square cozy farm-game panel frame as a nine-patch tile, hand-painted storybook style: a soft woven-willow / light-wood border running around all four edges with a fully transparent centre, uniform border thickness on every side so it slices cleanly as a nine-patch. Warm muted tones keyed to #E0D6BC that frame a light warm field without competing with the items inside. No text, even lighting.

### Pipeline
Generate at high resolution → slice the grid into 12 cells → alpha-cut each → place into `games/grove/assets/ui/kit/` via `make icon IN=/tmp/<cell>.png OUT=res://games/grove/assets/ui/kit/icon_<id>.png SIZE=512`. Keep the established ids (`home`, `gear`, `cart`, `coin`, `gem`, `star`, `water`, `lock`, `question`) so no code changes; add new ids `bag`, `map`, `sprout` and point the nav buttons at them (Phase 3). The locked texture follows the `make decor` path into `ui/` and is wired where `bramble_*` is loaded ([board.gd](../../../engine/scripts/scenes/board.gd)).
