# Ghibli Grove — Style Bible & P1 Generation Kit

The authoritative look reference for ALL art (owner-locked direction, 2026-06-10:
ART_DIRECTION.md Direction F). Every generated asset uses §1 verbatim; every
asset class follows its §2 spec; P1's complete shopping list is §3.

---

## §1 — The style core (append VERBATIM to every prompt)

> hand-painted anime film background style, soft gouache and watercolor texture
> with visible brushwork, gentle diffuse summer daylight, warm nostalgic pastoral
> palette of meadow green, straw gold and clear sky blue, towering soft cumulus
> clouds, atmospheric haze in the distance, wind-blown grass, painterly
> cel-shaded subjects with clean simple line work, no photorealism, no glossy 3D
> render, no text

**Saturation lever:** if a result reads "digital anime wallpaper", add
`muted vintage film colors, slightly faded`. **Never** add style/IP names.

## §1b — The palette (locks the "generated feel" out)

| Role | Hex | Use |
|---|---|---|
| Meadow | `#7FA65A` | grass fields, UI positive |
| Deep leaf | `#3F6B43` | foliage shadow, outlines on greens |
| Straw gold | `#E3B23C` | harvest accents, stars, highlights |
| Sky | `#9CCDE8` | skies, water, cool rest areas |
| Cream | `#FBF3EA` | paper/UI surfaces, text on dark |
| Warm bark | `#8A5A3B` | wood, line work on warm subjects |
| Clay red | `#C96F4A` | roofs, the warm accent (sparingly) |
| Ink | `#33402F` | text, deepest accents (replaces v1's night-purple) |

UI rebuild note (P1): `palette.gd`'s cozy-night BG/SURFACE purples retire in the
grove scenes; board chrome moves to cream-on-leaf with bark borders.

## §2 — Per-asset-class rules

- **Items (board pieces):** 512², subject on plain solid white (the transparency
  pipeline), chunky readable silhouette, ONE warm rim light, clean outline,
  generous margin. A growth line's 5 tiers must read as the SAME line at a
  glance (shared pot/soil/leaf motif) and as 5 distinct sizes/stages in 1 second
  at 100px.
- **Generators:** same as items but visually "openable/giving" (a satchel mouth,
  a hive entrance) + slightly larger presence; they sit on the board for weeks —
  they must be charming.
- **Brambles (locked cells):** 512² white-bg patch of overgrowth; 3 densities
  (ring 1 light twigs → ring 3 dense thicket); must read as "board texture",
  never as an item (no rim light, lower saturation).
- **Animal busts:** 512² white bg, "friendly round [animal] character from the
  chest up" mascot framing (the phrasing that generates reliably), one accessory
  each (leaf, scarf, acorn cap) for silhouette identity.
- **Scenes (homestead vista / board backdrops):** opaque; vistas wide with haze
  depth; board backdrops TALL PORTRAIT with a calm low-contrast center (they sit
  under a 60% scrim).
- **Scene unlock layers:** same-canvas transparent overlays per restoration spot
  (the bedroom-decor technique — generate the finished vista first, then each
  piece as a cutout at identical position/scale; `process_decor.gd` handles it).

## §3 — P1 generation kit (the complete shopping list, ~19 images)

Drop raws in `~/Downloads/<name>_raw.png`; process per the noted mode.

| # | Asset | File → | Process |
|---|---|---|---|
| 1–8 | Wildflower line, **8 tiers** (seed packet → sprout → seedling → sapling → bush → blooming bush → flowering tree → radiant bloom tree) | `assets/items/flower_1..8.png` | icon 512 |
| 9–16 | Berry line, **8 tiers** (seeds → sprout → seedling → berry sapling → berry bush → fruiting bush → berry tree → harvest tree) | `assets/items/berry_1..8.png` | icon 512 |
| 17 | Seed satchel generator | `assets/ui/gen_satchel.png` | icon 512 |
| 18–20 | Bramble ring 1/2/3 | `assets/ui/bramble_1..3.png` | icon 512 |
| 21 | Fox bust (first giver) | `assets/map/giver_fox.png` | icon 512 |
| 22 | Hedgehog bust (second giver) | `assets/map/giver_hedgehog.png` | icon 512 |
| 23 | **Market Squirrel bust + tiny cart (the Merchant — always takes top tiers for coins)** | `assets/map/giver_squirrel.png` | icon 512 |
| 24 | Board backdrop: forest clearing (calm center, tall portrait) | `assets/ui/bg_grove_board.png` | decor 1080 1920 --opaque |
| 25 | Homestead vista (wide, the home scene base) | `assets/rooms/grove_vista.png` | decor 1920 1080 --opaque |
| 26 | Board mat: mossy clearing mat (plain square, ~87% fill, rounded corners, no pockets) | `assets/ui/tray_grove.png` | decor 1024 1024 --opaque |

**Tier-readability rule for 8-tier lines:** tiers must step in SIZE and
SILHOUETTE, not just detail — at 100px, t4 vs t5 must read in a glance
(pot → ground planting, bush → tree are good step-changes).

Prompts: §1 core + the §2 class rules + ART_DIRECTION.md Direction F templates
(vista/backdrop/item/bust are written out there verbatim). Items 1–10: keep the
shared-motif rule — both lines use the same soil/pot language so the board reads
as one garden.

**P1 does NOT need:** scene unlock layers (P3), more animals, acorn/dewdrop
currency art (P2), additional generators (post-P1 content), audio.

## §5 — Juice restyle (the FX must be hand-painted too)

The v1 juice speaks "vibrant arcade" (saturated dot bursts, gold flashes, neon
floating text on night-purple). In the grove, **every effect becomes something
from the meadow** — same FX engine (fx.gd / main's burst), new clothes:

| v1 effect | Grove replacement |
|---|---|
| Colored dot bursts | **Petal / leaf / pollen puffs** — hand-painted particle sprites, drifting with a little flutter (gravity low, slight rotation), in palette tones not rainbow |
| Gold flash on big merges | **Sun-dapple bloom** — soft straw-gold radial glow, low alpha, never white-out |
| Merge pop squash | keep — it's physical, style-agnostic |
| Floating text shouts | **Ink-brush hand-lettered look**: ink `#33402F` on a small cream paper chip, gentle rise + sway like a falling leaf (not a rocket) |
| Landing/pulse rings | **Water ripple rings** (we water things now) |
| ZERO confetti storms | **Petal drift** — fewer, slower, floatier (the celebrate beats are warm, not explosive) |
| Star iconography (vibrant ★) | **Hand-painted straw-gold star**, wobbly outline — or fireflies as the sparkle language at dusk beats |
| Wallet coin (gold circle) | acorn/painted-coin sprite (P2, with currency art) |
| FX color constants | bursts draw from the §1b palette ONLY: straw `#E3B23C`, meadow `#7FA65A`, sky `#9CCDE8`, clay `#C96F4A` — never pure RGB |

**Motion rule:** grove juice is *floaty, breezy, settling* — longer lifetimes,
lower velocities, slight horizontal sway — vs v1's snappy bursts. Calm mode
still reduces counts/motion on top.

**New particle sprites needed (added to the §3 kit):**

| # | Asset | File → | Process |
|---|---|---|---|
| 20 | Petal (single, soft pink-cream) | `assets/fx/p_petal.png` | icon 128 |
| 21 | Leaf (single, meadow green) | `assets/fx/p_leaf.png` | icon 128 |
| 22 | Pollen mote (soft gold blob) | `assets/fx/p_pollen.png` | icon 128 |
| 23 | Water droplet | `assets/fx/p_drop.png` | icon 128 |
| 24 | Hand-painted star (straw gold, wobbly) | `assets/fx/p_star.png` | icon 256 |

Prompt template: *"a single [petal / green leaf / soft golden pollen mote /
water droplet / wobbly hand-painted five-point star], small painted game
particle, soft edges, centered on plain solid white background, generous
margin"* + §1 style core.

## §6 — Audio direction (forest, hand-played, unhurried)

Full prompt set in `AUDIO_PROMPTS.md` §5 (the grove set supersedes the bedroom
set). Identity in one line: **a small acoustic ensemble playing in a sunlit
field** — nylon guitar, felt piano, wooden flute/recorder, light strings,
brushes; birdsong and leaves under everything; pentatonic, one shared key;
water sounds for water verbs, wood for UI. Nothing electronic, nothing casino.
File names are UNCHANGED from the engine's point of view (`music_menu/play/
room.ogg`, `merge_soft.wav`…) so the new takes drop in with zero code changes.

## §4 — Consistency drill (how the loop stays on-style)

1. One batch = one chat/session; the §1 core VERBATIM in every prompt.
2. Generate the two item LINES back-to-back (1–10) before anything else — if the
   soil/pot motif drifts between lines, fix it before generating the rest.
3. After processing, composite items onto the board backdrop at 100px and LOOK
   (the bake-off criteria: tiers distinguishable in 1s; lines never confusable).
4. Any asset that needs a re-roll gets the SAME prompt + one added constraint —
   never a rewritten prompt (drift compounds).
