# ART DONE — the artist's ledger (APPEND-ONLY)

**Ownership (single-writer rule, owner 2026-06-11):** this file is written by
the **artist / generation agent ONLY**. The triage agent only READS it and
ticks your `[g]` boxes in `BUILD_QUEUE.md` §ARTIST from your entries. Never
edit `BUILD_QUEUE.md`; never edit or delete earlier entries here — append only.

**How to append:** one entry per processed image (or per stall/re-roll note).
Number entries sequentially. Format:

```
## <N> · <row id> · DONE|REROLL|STALLED
<one line: anything that diverged — reworded subject, added constraint, etc.>
file: <dest path> · imported: yes|no
```

Example:
```
## 1 · icon_star · DONE
clean first take; petals read at 48px
file: res://assets/ui/kit/icon_star.png · imported: yes
```

---------- triage never writes below this line ----------

## 1 · panel_parchment · DONE
clean first take; calm stretch center, edge character only
file: res://assets/ui/kit/panel_parchment.png · imported: yes

## 2 · panel_plank · REROLL
first take had plank seams crossing the stretch center; re-rolled with one added constraint to keep the central stretch region seam-free
file: res://assets/ui/kit/panel_plank.png · imported: no

## 3 · panel_plank · DONE
accepted re-roll; central wood field is calm enough for nine-patch stretch, decorative carving stays near the border
file: res://assets/ui/kit/panel_plank.png · imported: yes

## 4 · panel_chip · DONE
clean first take; center is quiet, corner ornamentation stayed non-text
file: res://assets/ui/kit/panel_chip.png · imported: yes

## 5 · btn_leaf · DONE
clean first take; wide 2:1 button, stitched border and leaf character stay near the ends
file: res://assets/ui/kit/btn_leaf.png · imported: yes

## 6 · btn_round · DONE
clean first take; round branch-slice button with calm center for engine-composited icons
file: res://assets/ui/kit/btn_round.png · imported: yes

## 7 · ribbon_title · DONE
clean first take; empty center band, folded ends, no text
file: res://assets/ui/kit/ribbon_title.png · imported: yes

## 8 · divider_vine · DONE
generated on a taller source canvas; processed with --cover so the final crop is the centered 12:1 vine strip
file: res://assets/ui/kit/divider_vine.png · imported: yes

## 9 · shop_stall · DONE
clean first take; no signage or text, counter edge runs along the bottom
file: res://assets/ui/kit/shop_stall.png · imported: yes

## 10 · icon_star · DONE
clean first take; Bloomstar reads as a straw-gold flower-star at icon size
file: res://assets/ui/kit/icon_star.png · imported: yes

## 11 · icon_coin · DONE
clean first take; acorn emboss reads clearly, no currency symbols
file: res://assets/ui/kit/icon_coin.png · imported: yes

## 12 · icon_gem · DONE
clean first take; pale-blue dewdrop shape stays distinct from the water icon
file: res://assets/ui/kit/icon_gem.png · imported: yes

## 13 · icon_water · DONE
clean first take; simple round droplet with one soft highlight
file: res://assets/ui/kit/icon_water.png · imported: yes

## 14 · icon_rain · DONE
clean first take; cloud plus exactly three drops, no face or text
file: res://assets/ui/kit/icon_rain.png · imported: yes

## 15 · icon_cart · DONE
clean first take; reads as a woven basket rather than a metal cart
file: res://assets/ui/kit/icon_cart.png · imported: yes

## 16 · icon_gear · DONE
clean first take; daisy silhouette also reads as a gentle gear
file: res://assets/ui/kit/icon_gear.png · imported: yes

## 17 · icon_check · DONE
clean first take; single leaf forms a clear checkmark
file: res://assets/ui/kit/icon_check.png · imported: yes

## 18 · icon_lock · DONE
clean first take; wooden padlock and sprout are readable
file: res://assets/ui/kit/icon_lock.png · imported: yes

## 19 · icon_question · DONE
clean first take; carved wooden question mark only, no extra marks
file: res://assets/ui/kit/icon_question.png · imported: yes

## 20 · icon_home · DONE
clean first take; mossy farmhouse has a strong small-icon silhouette
file: res://assets/ui/kit/icon_home.png · imported: yes

## 21 · icon_back · DONE
clean first take; folded leaf reads as a left arrow
file: res://assets/ui/kit/icon_back.png · imported: yes

## 22 · icon_level · DONE
clean first take; sprout inside painted ring, no numerals
file: res://assets/ui/kit/icon_level.png · imported: yes

## 23 · icon_cash · DONE
clean first take; folded leaf banknote has no printed marks
file: res://assets/ui/kit/icon_cash.png · imported: yes

## 24 · int_farmhouse · DONE
clean first take; empty placement zones are readable, no furniture baked into the room
file: res://assets/rooms/int_farmhouse.png · imported: yes

## 25 · furn_fh_hearth · DONE
clean first take; accepted small decorative props because the hearth/fire/kettle read as one furnishing
file: res://assets/rooms/furn_fh_hearth.png · imported: yes

## 26 · furn_fh_bed · DONE
clean first take; readable bed silhouette, small decorative heart is non-text
file: res://assets/rooms/furn_fh_bed.png · imported: yes

## 27 · furn_fh_table · DONE
clean first take; round table plus exactly two stools
file: res://assets/rooms/furn_fh_table.png · imported: yes

## 28 · furn_fh_rug · DONE
clean first take; shallow oval braided rug in meadow tones
file: res://assets/rooms/furn_fh_rug.png · imported: yes

## 29 · furn_fh_shelf · DONE
clean first take; pantry shelf reads as one wall-shelf furnishing, no jar labels
file: res://assets/rooms/furn_fh_shelf.png · imported: yes

## 30 · furn_fh_lamp · DONE
clean first take; brass oil lamp on stand with warm flame
file: res://assets/rooms/furn_fh_lamp.png · imported: yes

## 31 · furn_fh_chair · DONE
clean first take; rocking chair silhouette with blanket, small cutout is non-text
file: res://assets/rooms/furn_fh_chair.png · imported: yes

## 32 · furn_fh_window · DONE
retry after transient image-tool server error; accepted cottage window with shutters and flower box, no text
file: res://assets/rooms/furn_fh_window.png · imported: yes

## 33 · spirit_puff · DONE
retry after transient image-tool server error; accepted original seed-head design, not a plain soot-ball silhouette
file: res://assets/map/spirit_puff.png · imported: yes

## 34 · spirit_moss · DONE
clean first take; original moss-cloak silhouette with body hidden under moss and leaf hat
file: res://assets/map/spirit_moss.png · imported: yes

## 35 · spirit_acorn · DONE
clean first take; acorn cap and sprout-tail carry the original seedling design
file: res://assets/map/spirit_acorn.png · imported: yes

## 36 · spirit_lantern · DONE
clean first take; non-humanoid wisp with mushroom lantern as the signature
file: res://assets/map/spirit_lantern.png · imported: yes

## 37 · p_rain · DONE
clean first take; single pale slanted rain streak
file: res://assets/fx/p_rain.png · imported: yes

## 38 · p_snow · DONE
clean first take; single soft six-point snowflake
file: res://assets/fx/p_snow.png · imported: yes

## 39 · map_grove_v2 · DONE
retry after transient image-tool server error; accepted for owner eyeball before engineering re-fit, with five readable landforms and no baked buildings or water
file: res://assets/rooms/map_grove.png · imported: yes

## 40 · tray_grove_tall_v2 · DONE
clean first take; warm packed earth and pale straw replace the too-green moss bed, with sparse dull moss and no baked border
file: res://assets/ui/tray_grove_tall.png · imported: yes

## 41 · icon_coin · DONE
owner re-roll accepted; now reads as a natural golden acorn currency, not a metal coin or medallion
file: res://assets/ui/kit/icon_coin.png · imported: yes

## 42 · icon_gem · DONE
owner re-roll accepted; faceted violet-blue teardrop crystal separates clearly from the round water droplet
file: res://assets/ui/kit/icon_gem.png · imported: yes

## 43 · int_farmhouse_v2 · DONE
replacement accepted; outside canvas is garden instead of white, hearth/window are baked architecture, floor remains open for placed furnishings
file: res://assets/rooms/int_farmhouse.png · imported: yes

## 44 · furn_fh_bed · DONE
owner re-roll accepted; ROOM CAMERA take shows top and front face, matching the farmhouse view better than v1
file: res://assets/rooms/furn_fh_bed.png · imported: yes

## 45 · furn_fh_chair · DONE
owner re-roll accepted; rocking chair uses ROOM CAMERA with top visible and blanket readable
file: res://assets/rooms/furn_fh_chair.png · imported: yes

## 46 · furn_fh_chest · DONE
clean first take; rounded-lid storage chest with simple iron bands, ROOM CAMERA
file: res://assets/rooms/furn_fh_chest.png · imported: yes

## 47 · furn_fh_plant · DONE
clean first take; leafy clay-pot fern, ROOM CAMERA and floor-standing
file: res://assets/rooms/furn_fh_plant.png · imported: yes

## 48 · furn_fh_wheel · DONE
clean first take; spinning wheel with stool base and wool tuft, ROOM CAMERA
file: res://assets/rooms/furn_fh_wheel.png · imported: yes

## 49 · furn_fh_picture · DONE
clean first take; wall-hung meadow picture uses the allowed near-frontal exception
file: res://assets/rooms/furn_fh_picture.png · imported: yes

## 50 · map_grove_v3 · REROLL
first v3 candidate had useful flat clearings but introduced a visible sky/horizon band, unsafe for the draggable top-down map
file: res://assets/rooms/map_grove.png · imported: no

## 51 · map_grove_v3 · DONE
second take accepted; full-bleed ground-only map with five flat uncluttered clearings and one flat damp reedy clearing, no crater or baked water
file: res://assets/rooms/map_grove.png · imported: yes

## 52 · poi_meadow · DONE
owner re-roll accepted; meadow edge is irregular with grass tufts and petals, processed with transparent outside instead of a hard disc
file: res://assets/map/poi_meadow.png · imported: yes

## 53 · spirit_porter · DONE
clean first take; original errand spirit silhouette with oversized wicker pack-basket
file: res://assets/map/spirit_porter.png · imported: yes

## 54 · way_lantern · DONE
clean first take; rustic lantern post reads from high map view
file: res://assets/map/way_lantern.png · imported: yes

## 55 · way_birdbath · DONE
clean first take; small stone bird bath with clear water, high map view
file: res://assets/map/way_birdbath.png · imported: yes

## 56 · way_flowertub · DONE
clean first take; half-barrel flower tub reads clearly as a wayside prop
file: res://assets/map/way_flowertub.png · imported: yes

## 57 · way_bench · DONE
clean first take; mossy wooden bench with high map-view silhouette
file: res://assets/map/way_bench.png · imported: yes

## 58 · way_skep · DONE
clean first take; straw skep on wooden stand, high map-view silhouette
file: res://assets/map/way_skep.png · imported: yes

## 59 · way_cairn · DONE
clean first take; rounded-stone cairn with flower tuft, high map view
file: res://assets/map/way_cairn.png · imported: yes

## 60 · amb_grove1 · STALLED
remaining artist row is audio .ogg; no audio generation tool is available in this Codex thread
file: assets/music/amb_grove1.ogg · imported: no

## 61 · amb_grove2 · STALLED
remaining artist row is audio .ogg; no audio generation tool is available in this Codex thread
file: assets/music/amb_grove2.ogg · imported: no

## 62 · tray_grove_tall_v3 · DONE
owner re-roll accepted; pale warm cream-sage play surface is near-flat and light, with no straw, earth patches, moss clumps, border, rim, or frame
file: res://assets/ui/tray_grove_tall.png · imported: yes

## 63 · amb_grove1 · DONE
supersedes stalled entry #60; owner-generated mp3 now exists and imports, while BUILD_QUEUE keeps the legacy ogg label with an mp3 note
file: assets/music/amb_grove1.mp3 · imported: yes

## 64 · amb_grove2 · DONE
supersedes stalled entry #61; owner-generated mp3 now exists and imports, while BUILD_QUEUE keeps the legacy ogg label with an mp3 note
file: assets/music/amb_grove2.mp3 · imported: yes

## 65 · int_barn · DONE
clean first take; roof-off barn background keeps architecture baked, floor open, daylight from the right, and farmyard outside instead of white
file: res://assets/rooms/int_barn.png · imported: yes

## 66 · furn_bn_bales · REROLL
first two takes overproduced into four-bale stacks; rejected because the row asks for two stacked hay bales
file: res://assets/rooms/furn_bn_bales.png · imported: no

## 67 · furn_bn_bales · DONE
third take accepted; exactly two hay bales, one over one, with loose straw wisps
file: res://assets/rooms/furn_bn_bales.png · imported: yes

## 68 · furn_bn_stool · DONE
clean first take; three-legged milking stool with small tin pail, room-camera perspective
file: res://assets/rooms/furn_bn_stool.png · imported: yes

## 69 · furn_bn_churns · DONE
clean first take; exactly three lidded milk churns with one tilted
file: res://assets/rooms/furn_bn_churns.png · imported: yes

## 70 · furn_bn_trough · DONE
clean first take; long wooden trough with clear water and one floating leaf
file: res://assets/rooms/furn_bn_trough.png · imported: yes

## 71 · furn_bn_lantern · DONE
clean first take; lantern hangs from its own free-standing floor post, not a wall mount
file: res://assets/rooms/furn_bn_lantern.png · imported: yes

## 72 · furn_bn_cart · DONE
clean first take; small two-wheeled hay cart with a little hay inside
file: res://assets/rooms/furn_bn_cart.png · imported: yes

## 73 · furn_bn_coop · DONE
clean first take; wooden hen coop with ramp and exactly one round hen peeking out
file: res://assets/rooms/furn_bn_coop.png · imported: yes

## 74 · furn_bn_plow · DONE
clean first take; old single-handle wooden plow with worn iron blade
file: res://assets/rooms/furn_bn_plow.png · imported: yes

## 75 · int_pond · DONE
clean first take; calm open pond background with level grassy banks and no baked placed props
file: res://assets/rooms/int_pond.png · imported: yes

## 76 · furn_pd_dock · DONE
clean first take; tiny weathered dock of a few planks on stub posts
file: res://assets/rooms/furn_pd_dock.png · imported: yes

## 77 · furn_pd_lilies · DONE
clean first take; exactly three lily pads with one pink blossom and no water background
file: res://assets/rooms/furn_pd_lilies.png · imported: yes

## 78 · furn_pd_reeds · DONE
clean first take; reed tuft has exactly two brown cattails and no water background
file: res://assets/rooms/furn_pd_reeds.png · imported: yes

## 79 · furn_pd_bench · DONE
clean first take; mossy wooden bench in outdoor camera
file: res://assets/rooms/furn_pd_bench.png · imported: yes

## 80 · furn_pd_stones · DONE
clean first take; exactly five flat stepping stones in a short curve
file: res://assets/rooms/furn_pd_stones.png · imported: yes

## 81 · furn_pd_willow · DONE
clean first take; young willow tree as a placed sprite, not baked into the pond background
file: res://assets/rooms/furn_pd_willow.png · imported: yes

## 82 · furn_pd_boat · DONE
clean first take; little rowboat with two oars and no water background
file: res://assets/rooms/furn_pd_boat.png · imported: yes

## 83 · furn_pd_fireflies · DONE
clean first take; glowing firefly jar on a small stump
file: res://assets/rooms/furn_pd_fireflies.png · imported: yes

## 84 · int_orchard · DONE
clean first take; sunny orchard backdrop keeps mature trees on the outer edges and the middle open for placed objects
file: res://assets/rooms/int_orchard.png · imported: yes

## 85 · furn_or_rows · DONE
clean first take; exactly four young apple saplings in two tidy dirt rows
file: res://assets/rooms/furn_or_rows.png · imported: yes

## 86 · furn_or_ladder · DONE
clean first take; free-standing A-frame orchard ladder, not leaning on anything
file: res://assets/rooms/furn_or_ladder.png · imported: yes

## 87 · furn_or_baskets · DONE
clean first take; exactly two woven baskets heaped with red apples
file: res://assets/rooms/furn_or_baskets.png · imported: yes

## 88 · furn_or_press · DONE
clean first take; cider press includes turn-screw, spout, and jug
file: res://assets/rooms/furn_or_press.png · imported: yes

## 89 · furn_or_hives · DONE
clean first take; exactly two friendly hive boxes with a few hovering bees
file: res://assets/rooms/furn_or_hives.png · imported: yes

## 90 · furn_or_swing · DONE
clean first take; rope swing hangs from its own free-standing A-frame, no tree dependency
file: res://assets/rooms/furn_or_swing.png · imported: yes

## 91 · furn_or_scarecrow · DONE
clean first take; friendly scarecrow on a sturdy ground post
file: res://assets/rooms/furn_or_scarecrow.png · imported: yes

## 92 · furn_or_wagon · DONE
clean first take; wooden farm wagon loaded with apple crates
file: res://assets/rooms/furn_or_wagon.png · imported: yes

## 93 · int_meadow · DONE
clean first take; wildflower meadow backdrop keeps open grass through the middle and bakes only the lower-left brook, no bridge
file: res://assets/rooms/int_meadow.png · imported: yes

## 94 · furn_md_path · DONE
clean first take; short winding pale-stone path segment with tiny wildflowers
file: res://assets/rooms/furn_md_path.png · imported: yes

## 95 · furn_md_picnic · DONE
clean first take; red-checkered blanket with basket and exactly two cups
file: res://assets/rooms/furn_md_picnic.png · imported: yes

## 96 · furn_md_kite · DONE
clean first take; kite is grounded and tethered to a small stake, not flying
file: res://assets/rooms/furn_md_kite.png · imported: yes

## 97 · furn_md_brook · DONE
clean first take; arched wooden footbridge is a standalone sprite with no water background
file: res://assets/rooms/furn_md_brook.png · imported: yes

## 98 · furn_md_stand · DONE
clean first take; lemonade stand has striped awning, pitcher, two cups, and a blank sign with no lettering
file: res://assets/rooms/furn_md_stand.png · imported: yes

## 99 · furn_md_garden · REROLL
first take added a birdbath and bird; rejected because the row only asked for fence, gate, and flowers
file: res://assets/rooms/furn_md_garden.png · imported: no

## 100 · furn_md_garden · DONE
second take accepted; fenced secret-garden patch has gate and flowers only
file: res://assets/rooms/furn_md_garden.png · imported: yes

## 101 · furn_md_telescope · DONE
clean first take; brass telescope on wooden tripod, text-free and no sky background
file: res://assets/rooms/furn_md_telescope.png · imported: yes

## 102 · furn_md_arch · DONE
clean first take; free-standing wooden rose arch, attached to nothing else
file: res://assets/rooms/furn_md_arch.png · imported: yes

## 103 · furn_fh_chair_v3 · DONE
owner re-roll accepted; steep top-down rocking chair take passes farmhouse side-by-side check; punch cleared 8 enclosed regions / 9295 px, re-run punched 0
file: res://assets/rooms/furn_fh_chair.png · imported: yes · contact: /tmp/fh_chair_wheel_contact.png

## 104 · furn_fh_wheel_v2 · DONE
owner re-roll accepted; spinning wheel take is more top-down with stool/wheel support readable beside the farmhouse room; punch cleared 16 enclosed regions / 13612 px, re-run punched 0
file: res://assets/rooms/furn_fh_wheel.png · imported: yes · contact: /tmp/fh_chair_wheel_contact.png
