# Tidy Up — Art Direction Candidates (the style IS the hook)

**Problem (owner, 2026-06-10):** the current art reads as "AI-generated cute" —
pleasant, soft-3D, and interchangeable with every other merge game (Merge Mansion,
Travel Town, Gossip Harbor all live in the same glossy-render space). The style
must become the thing that stops the thumb on the store page.

**What "distinct" means in this genre:** the whole category is glossy 3D bubbles —
so distinctiveness lives in **visible handcraft**: brush grain, ink wobble, paper
texture, physical materials. Anything that looks *made by hands* reads as premium
and personal against the genre baseline.

**Hard requirements for any direction:**
1. **Tiny-icon readability** — items must read at ~100px in a pocket, 5 tiers
   apart, color-blind-safely distinct between families.
2. **Pipeline-reproducible** — hundreds of assets come from the scripted
   generation loop, so the style must be promptable CONSISTENTLY (fixed style
   suffix + reference sheet + locked palette hexes).
3. **Cozy-fantasy fit** — tidying, warmth, domesticity.

---

## Direction A — "Picture-Book Gouache" (storybook hand-paint)

*The vintage children's-book look: visible gouache brushwork, paper grain, wobbly
hand lines, muted naturals with one warm accent.*

- **Feels like:** Moomin books · Beatrix Potter · Carson Ellis's "Home" — a book
  your grandmother kept.
- **Board items:** little painted objects with off-register color (paint slightly
  outside the line), soft paper-white halo instead of drop shadow.
- **Home scene:** a full-bleed painted spread; unlocks appear as freshly-painted
  patches (the reveal beat = a brush "paints" the furniture in — gorgeous).
- **Characters:** round, dot-eyed picture-book people/animals.
- **Why it wins:** maximum warmth; the "hand-made home" metaphor IS the game's
  fantasy. Ages beautifully, screenshots like a book page.
- **Risks:** low contrast needs careful tier-color discipline; gouache texture can
  mush at 100px (keep shapes chunky).
- **Prompt fragment:** *"…flat gouache illustration, visible brush strokes, paper
  grain, wobbly hand-drawn outline, muted cream/terracotta/sage palette with warm
  peach accent, vintage children's picture-book style, no gloss, no 3D render…"*

## Direction B — "Ink & Wash Cats" (the hand-drawn cat neighborhood)

*Loose ink outlines with watercolor wash — and the CAST is cats. You're the
neighborhood's tidy cat; every client, quest giver, and passer-by is a cat.*

- **Feels like:** Ghibli sketchbook pages · "She and Her Cat" · Japanese stationery
  cats — whiskery, imperfect, alive.
- **Board items:** ink-contour objects with a single loose wash of color escaping
  the line; cat paw-prints as UI accents.
- **Home scene:** an ink-and-wash room that gains color as it's tidied (grisaille
  → washed-in color per unlock — a STUNNING progression device).
- **Characters:** cats. Wren the frazzled tabby, Juniper the bespectacled gray,
  Pip the kitten. Cheering avatar beats become irresistible.
- **Why it wins:** cats + hand-drawn = the two most screenshot-shareable forces in
  cozy gaming, and a mascot cast gives marketing a face. Clear merchandise/icon
  identity.
- **Risks:** cast reskin touches narrative art (busts redo); ink lines need weight
  discipline to read small.
- **Prompt fragment:** *"…loose ink line drawing with watercolor wash, sketchbook
  style, visible pen texture, color bleeding past lines, soft cream paper
  background, gentle Japanese stationery aesthetic, a [item] / a cozy cat
  character…"*

## Direction C — "Folk Print" (mid-century screen-print, Charley Harper energy)

*Hard geometric simplification: every object reduced to bold flat shapes with
screen-print texture and a strict 6-color palette.*

- **Feels like:** Charley Harper · Mary Blair · vintage travel posters · modern
  board-game art (Everdell-adjacent).
- **Board items:** unmistakable silhouettes — a sock is three shapes, a book is
  two. **Best tiny-icon readability of any direction, by far.**
- **Home scene:** a poster-flat room where each unlock is a crisp new shape
  cluster; the whole game looks like a living mid-century print.
- **Characters:** geometric birds/people with paper-cut charm.
- **Why it wins:** ZERO other merge game looks like this; instantly ownable,
  trivially consistent (flat shapes + locked palette = the most
  pipeline-reproducible style here), reads perfectly at any size.
- **Risks:** "warm" must come from palette/composition since texture is minimal;
  less obviously "cute" — charming instead.
- **Prompt fragment:** *"…mid-century flat screen-print illustration, bold
  geometric shapes, limited palette (cream #FBF3EA, terracotta #E2725B, mustard
  #E3B23C, teal #2E6E65, charcoal #2A2A2A), subtle print grain, no outlines, no
  gradients, Charley Harper style…"*

## Direction D — "Painterly Cel" (the Breath-of-the-Wild nod)

*Soft cel shading over painterly atmosphere: watercolor-edged silhouettes, light
shafts, wind-blown particles — a premium adventure-calm look.*

- **Feels like:** BotW promo art · "Sable"-meets-watercolor · Studio Ghibli
  backgrounds with cel props.
- **Board items:** cel-shaded objects with one crisp rim light — closer to today's
  art but ART-DIRECTED (unified light, palette, edge language) instead of
  "render-cute".
- **Home scene:** the showpiece — atmospheric depth, dust motes in god-rays
  (we already have the glow tech).
- **Why it wins:** premium feel, the smallest migration from existing assets
  (could re-prompt rather than replace), trailer-gorgeous.
- **Risks:** the LEAST distinct of the five (premium ≠ unique); drifts back
  toward "AI look" without a strict style bible — this direction lives or dies
  on discipline.
- **Prompt fragment:** *"…soft cel-shaded illustration with painterly watercolor
  edges, atmospheric warm light shafts, gentle rim light, Ghibli-background
  quality, unified golden-hour palette, no photorealism, no glossy 3D…"*

## Direction E — "Handcraft Diorama" (clay & felt miniatures)

*Everything is physically MADE: plasticine items with fingerprints, felt board
pockets, cardboard furniture, stop-motion energy.*

- **Feels like:** Wallace & Gromit · LittleBigPlanet · Kirby's Epic Yarn — a
  hand-built miniature world.
- **Board items:** clay objects photographed straight-on; merging two clay socks
  SQUISHES them into a bigger one (the juice writes itself).
- **Home scene:** a shoebox diorama gaining hand-made furniture; the bag is a
  literal felt pouch.
- **Why it wins:** tactility = the tidying fantasy made literal ("everything in
  its place" with hands); deeply distinct; toy-like screenshots.
- **Risks:** the hardest to keep consistent through generation (material/light
  continuity across hundreds of assets); busy backgrounds can fight readability.
- **Prompt fragment:** *"…handmade plasticine clay miniature, soft studio light,
  visible fingerprints and tool marks, felt and cardboard set, stop-motion
  diorama photography, shallow depth of field OFF, flat front lighting…"*

---

## Direction F — "Ghibli Grove" (anime hand-drawn + the GROWING theme)

*Hand-drawn anime pastoral — soft watercolor backgrounds, clean character lines,
wind in the grass — and the THEME shifts from tidying a home to **restoring an
overgrown forest homestead**: merging is growing.*

- **Feels like:** Ghibli countryside (Totoro's woods, Kiki's hills) · Stardew's
  cozy-pastoral fantasy · anime key-visual skies.
- **The metaphor remap:** merge = grow (seed → sprout → sapling → tree → fruiting
  tree — tier readability comes FREE with growth stages) · generators = seed
  satchel / compost bin / beehive · energy = **water** (a watering can beats an
  abstract lightning bolt for cozy optics) · locked boxes = bramble/overgrowth
  patches that adjacent growth clears · covers = leaf piles · tangles = vines ·
  quest givers = forest animals & neighbors · the home scene = the farmhouse,
  barn, pond — and **unlocks make animals appear and stay** (ambient life = the
  plaza idea, earned).
- **Why v2 argues FOR this theme:** v1's fantasy was *finishing* ("All tidy!") —
  perfect for tidying. v2's fantasy is *perpetual cultivation* — a board that
  never finishes feels WRONG for a tidying job but exactly RIGHT for a garden;
  gardens are never done, and that's their charm. The energy/wait loop also
  reads kinder as "things need time to grow".
- **Why it wins:** the cozy-pastoral-anime cluster (Ghibli × Stardew) is the
  single most coveted aesthetic in cozy gaming; "merge-to-grow on a hand-drawn
  homestead" is a store-page sentence that sells itself. The animal cast slots
  straight into the quest-giver/avatar-cheer system.
- **Risks:** garden-merge is the genre's most CROWDED theme (Merge Dragons/
  Gardens/EverMerge) — the hand-drawn anime execution must carry distinctiveness
  (those games are all glossy-3D, so it can); abandons the tidier identity and
  the home/street art (but the bake-off was going to re-style those anyway —
  see "switch cost" below).
- **Prompt fragment:** *"…hand-drawn anime illustration, soft watercolor
  background with clean line-art subjects, Ghibli countryside palette (warm
  greens, sky blue, straw gold), gentle wind-blown atmosphere, cozy pastoral
  storybook anime, no 3D render, no gloss…"*

## On THEME (tidy-home vs grove) and the v2 mechanics

The mechanics are theme-agnostic, but the FEELINGS aren't:

| v2 mechanic | Tidy-home reading | Grove reading |
|---|---|---|
| Board never finishes | a job you never finish (uneasy) | a garden that keeps growing (charming) |
| Energy gating | "too tired to tidy" (negative) | "plants need water & time" (natural) |
| Quest givers consuming items | clients taking your work | animals/neighbors enjoying the harvest |
| Unlock track on the scene | furniture appears | life returns — plants, then ANIMALS |

**Hybrid worth considering ("the homestead"):** the grove theme KEEPS the
renovation DNA — the scene you restore is a farmhouse-home; tidying the wild
garden is our tidying fantasy moved outdoors. Not either/or.

**Switch cost honesty:** v2 already discards boards/levels, and the style
bake-off was already going to re-generate item families and scenes in a new
style — so changing THEME costs barely more than changing STYLE. This is the
one moment where a theme pivot is nearly free; after P2 it won't be.

## On player-selectable art styles (Disney/anime/European homes)

**Advise against as a core feature.** Three reasons:
1. **Cost multiplies:** every asset × N styles, forever (every new district,
   item line, character — triple the generation+QA surface).
2. **Identity dilutes:** the store page, icon, and trailers need ONE iconic look;
   a style-switcher game looks like nothing in particular from outside.
3. **We already have the right slot for variety:** coins buy STYLE VARIANTS of
   unlocked pieces (specced), and each district/project can carry its own
   sub-aesthetic (a European-cottage district, an onsen district…) WITHIN one
   signature style. That delivers "I made it mine" without forking the art.
If style-switching ever returns, it's a v3 seasonal-event experiment (one scene,
one alternate skin), not an engine feature.

## Recommendation — **DECIDED (owner, 2026-06-10): Direction F "Ghibli Grove"**

Style bible + P1 generation kit: **`GROVE_STYLE.md`**. Theme noun-map:
`TIDY_UP_V2_SPEC.md` §0. The analysis below is kept for the record.

- **If the theme moves to the grove: F "Ghibli Grove"** — the theme and style
  reinforce each other, v2's mechanics read kinder, and the animal cast powers
  the quest/avatar system. (Within F, hold the line on hand-drawn discipline —
  it must not drift back to generic "anime render".)
- **If the theme stays tidy-home: C "Folk Print"** — most distinct in genre, most
  reproducible through the pipeline, best icon readability. **Pair with B's cat
  cast** for warmth and a marketing face.
- **Runner-up either way: A "Picture-Book Gouache"** (max warmth), and it can
  host EITHER theme.
- **D** is the safe/cheap evolution (re-prompt existing assets) — only if
  migration cost dominates, and only with a strict style bible.
- Theme call first, then style bake-off: add F's kit to the bake-off (same 6
  assets re-cast as seed/sprout/tree, bramble box, seed-satchel generator,
  animal bust, farmhouse corner) → **30 images, still one evening**.

## Direction F — ready-to-paste prompts (no style names, ingredients only)

**Style core — append VERBATIM to every prompt in the batch (consistency lives here):**
> hand-painted anime film background style, soft gouache and watercolor texture
> with visible brushwork, gentle diffuse summer daylight, warm nostalgic pastoral
> palette of meadow green, straw gold and clear sky blue, towering soft cumulus
> clouds, atmospheric haze in the distance, wind-blown grass, painterly
> cel-shaded subjects with clean simple line work, no photorealism, no glossy 3D
> render, no text

**Homestead vista (home scene):** *A wide storybook countryside homestead seen
from a gentle hill: an old wooden farmhouse with a mossy shingle roof, a leaning
barn, a stone well, an overgrown vegetable garden waiting to be tended, a winding
dirt path, distant rolling meadows under towering soft clouds. Calm, slightly
wild, full of promise — no people, no animals yet. Wide landscape, painterly
depth with light haze toward the horizon.* + core

**Board backdrop (calm center, sits under a 60% scrim):** *Looking down a quiet
forest clearing's edge: tall sunlit grass and wildflowers framing the left and
right, dappled light from an unseen canopy, a soft mossy open space in the
middle, drifting pollen motes in the light. Very calm, low contrast in the
center, ambience not focal point. Tall portrait orientation.* + core

**Item template (per tier, white bg → transparency pipeline):** *A single
[TIER OBJECT] as a small painted game item: chunky, readable silhouette, soft
painterly shading with a single warm rim light, clean simple outline, centered
on a plain solid white background, generous margin. Square.* + core
Tier ladder example: tiny seed packet with a sprouting seed → young sprout in a
soil mound, two bright leaves → leafy sapling in a terracotta pot → small
blossoming fruit tree → lush fruit-laden tree with a wooden crate of harvest.

**Animal giver bust (mascot framing — the one that generates reliably):** *A
friendly round fox character from the chest up, soft fur rendered in gentle
painted strokes, big warm amber eyes, a tiny leaf tucked behind one ear, kind
expectant smile, three-quarter view. Clean character line art over painterly
shading, centered on a plain solid white background, no text. Square.* + core

## The Bake-Off (decide with eyes, not words)

Generate the SAME 6-asset test kit in each candidate style through the existing
loop, then view them side-by-side at game size:

1. `sock_t1`, `sock_t3`, `sock_t5` (one family, three tiers — the readability test)
2. one **locked box** + one **generator Box**
3. one **client bust** (Wren)
4. one **home-scene corner** (bed + window, 1024²)

Per style: fixed suffix from the prompt fragments above + the palette hexes.
Success criteria: tiers distinguishable at 100px in 1 second · two styles never
confusable · the home corner makes you want to live there. The kit is ~24 images
total — one evening of the generation loop.
