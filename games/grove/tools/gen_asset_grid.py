#!/usr/bin/env python3
"""Generate asset_grid.html — the live asset map for Acorn Forest: Merge.

Data is transcribed from games/grove/grove_data.gd (LINES, GENERATORS,
ZONE_BASE_LINES/ZONE_SPECIAL_LINES, ACCUMULATORS, TREAT_GEN_TEX, RESIDENT_LINES,
SPECIAL_ITEMS). Every art path is verified on disk; missing files are reported
and rendered as a placeholder so the page never silently hides a gap.
"""
import os, glob, html, sys

REPO = "/Users/xup/dh/merge"
ASSETS = os.path.join(REPO, "games/grove/assets")
REL = "games/grove/assets"   # href root, relative to repo-root asset_grid.html
OUT = os.path.join(REPO, "asset_grid.html")

MISSING = []

def art(relpath):
    """Return (href, exists). relpath is under games/grove/assets."""
    disk = os.path.join(ASSETS, relpath)
    ok = os.path.isfile(disk)
    if not ok:
        MISSING.append(relpath)
    return f"{REL}/{relpath}", ok

def item(base, tier):
    return art(f"items/{base}/{base}_{tier}.png")

def gen_icon(name):
    return art(f"items/generator/{name}.png")

def tier_count(base):
    return len(glob.glob(os.path.join(ASSETS, f"items/{base}/{base}_*.png")))

MAP_NAMES = {0: "The Farm", 1: "The Orchard", 2: "The Garden", 3: "The Mill", 4: "The Gate"}

# ---- LINE names/bases (from LINES dict) -----------------------------------
LINE = {
    1:("Wildflower","flower"),2:("Feather","feather"),3:("Garden tools","tools"),
    4:("Honey","honey"),5:("Mushroom","mushroom"),
    21:("Orchard fruits","orchard_fruits"),22:("Orchard tools","orchard_tools"),
    23:("Orchard seeds","orchard_seeds"),24:("Scarecrows","orchard_scarecrows"),
    31:("Juice","garden_juice"),32:("Kites","garden_kites"),33:("Stones","garden_stones"),
    34:("Mossy trinkets","garden_mossy_trinkets"),35:("Rain charms","garden_rain_charms"),
    36:("Birds","garden_birds"),37:("Small critters","garden_small_critters"),
    38:("Vegetables","garden_vegetables"),
    41:("Small fish","mill_small_fish"),42:("Small animals","mill_small_animals"),
    43:("Water plants","mill_water_plants"),44:("Gears","mill_gears"),
    51:("Glowcaps","gate_glowcaps"),52:("Bells","gate_bells"),
    53:("Arch tokens","gate_arch_tokens"),54:("Star pebbles","gate_star_pebbles"),
    61:("Hearth embers","hearth_ember"),62:("Kitchen herbs","kitchen_herbs"),
    63:("Well water","well_water"),64:("Larder provisions","larder_provisions"),
    65:("Porch packages","porch_packages"),66:("Flower boxes","flower_boxes"),
    71:("Prize pumpkin","special_pumpkin"),72:("Golden banana","special_banana"),
    73:("Jewel avocado","special_avacado"),74:("Ruby cherry","special_cherry"),
    75:("Sugar melon","special_watermelon"),76:("Brass cogs","mill_gears"),
    77:("Starstones","gate_star_pebbles"),78:("Golden bells","gate_bells"),
}

# ---- 17 BASE generators (GENERATORS array) --------------------------------
# (gen_id, line, icon_num, zone, map, anchor?)
BASE_GENS = [
    ("gen_1",1,1,0,0,True),("gen_2",2,2,1,0,False),("gen_3",3,3,3,0,False),
    ("gen_4",4,4,4,0,False),("gen_5",5,5,6,1,False),("gen_21",21,6,7,1,False),
    ("gen_22",22,7,9,1,False),("gen_23",23,8,10,2,False),("gen_24",24,9,12,2,False),
    ("gen_31",31,10,13,2,False),("gen_32",32,11,15,2,False),("gen_33",33,12,16,2,False),
    ("gen_34",34,13,18,3,False),("gen_35",35,14,19,3,False),("gen_36",36,15,21,4,False),
    ("gen_37",37,16,22,4,False),("gen_51",51,17,24,4,False),
]

# ---- 8 specials / recipes (ZONE_SPECIAL_LINES; recipe = two preceding base lines)
# (line, ingredientA, ingredientB, zone, map, reuse_note_or_None)
SPECIALS = [
    (71,1,2,2,0,None),(72,3,4,5,0,None),(73,5,21,8,1,None),
    (74,22,23,11,2,None),(75,24,31,14,2,None),
    (76,32,33,17,3,"line 44 · Gears"),
    (77,34,35,20,3,"line 54 · Star pebbles"),
    (78,36,37,23,4,"line 52 · Bells"),
]

# ---- utility generators (named icons) -------------------------------------
ACCUMULATORS = [  # (icon, name, banks, cap, secs, value, unlock_spot)
    ("gen_rainbarrel","Rain barrel","water",2,3600,2,0),
    ("gen_coinpress","Coin press","coins",5,1800,8,1),
    ("gen_crystalfont","Crystal font","exp",4,3600,1,2),
    ("gen_acornmill","Acorn mill","acorn",3,7200,1,3),
]
TREAT_ICONS = ["gen_seedcart","gen_beehive","gen_lilyfountain","gen_applepress","gen_wildflowerarch"]

# ---- spare / parked generator art -----------------------------------------
SPARE_NUM_ICONS = list(range(18, 37))   # generators_18..36
PARKED_NAMED = ["gen_wildflowers","gen_twig_nest","gen_cattails","gen_apples",
                "gen_glowcaps","gen_honeycomb","gen_porcini"]

# ---- shelved item lines (in LINES, not in the 25-zone roster) --------------
SHELVED_LINES = [38,41,42,43,44,52,53,54,61,62,63,64,65,66]
REUSED_INTO = {44:76, 52:78, 54:77}   # shelved line art → special that reuses it
FARM_LINES = {61,62,63,64,65,66}

# ---- residents (live sub-game) --------------------------------------------
RESIDENTS = [  # (id, name, map_display)
    ("ember","Ember","The Farm"),("sprout","Sprout","The Orchard"),
    ("dewdrop","Dewdrop","The Garden"),("breeze","Breeze","The Mill"),
    ("starlight","Starlight","The Gate"),
]

# ---- special drop / currency items (wired) --------------------------------
SPECIAL_ITEMS = [  # (line, name, base)
    (9,"Coin","coin"),(10,"Chest","chest"),(11,"Key","key"),(12,"Water drop","water"),
    (13,"Acorn drop","acorn"),(14,"Spark","spark"),(15,"Wildcard","wildcard"),
]

# ===========================================================================
def esc(s): return html.escape(str(s))

def tile(href, ok, caption, sub="", badge=None, badge_cls="", big=False):
    cls = "tile big" if big else "tile"
    img = (f'<img src="{esc(href)}" alt="{esc(caption)}">'
           if ok else '<div class="miss">missing</div>')
    b = f'<span class="badge {badge_cls}">{esc(badge)}</span>' if badge else ""
    subhtml = f'<span class="sub">{sub}</span>' if sub else ""
    return (f'<div class="{cls}"><div class="thumb">{img}{b}</div>'
            f'<span class="cap">{esc(caption)}</span>{subhtml}</div>')

def recipe_tile(line, a, b, zone, mp, reuse):
    nm, base = LINE[line]
    (ah, ao), (bh, bo) = item(LINE[a][1],1), item(LINE[b][1],1)
    (rh, ro) = item(base, 1)
    def mini(h, o, lbl, cls="mini"):
        im = f'<img src="{esc(h)}" alt="">' if o else '<div class="miss sm">?</div>'
        return f'<figure class="{cls}">{im}<figcaption>{esc(lbl)}</figcaption></figure>'
    badge = (f'<span class="badge reused">SPARE art · {esc(reuse)}</span>'
             if reuse else '<span class="badge bespoke">bespoke art</span>')
    return (f'<div class="recipe">'
            f'<div class="rhead"><b>{esc(nm)}</b> <span class="muted">line {line} · zone {zone} · {esc(MAP_NAMES[mp])}</span>{badge}</div>'
            f'<div class="rbody">{mini(ah,ao,LINE[a][0])}<span class="op">+</span>'
            f'{mini(bh,bo,LINE[b][0])}<span class="op">&rarr;</span>'
            f'{mini(rh,ro,nm,"mini out")}</div></div>')

# Build sections -------------------------------------------------------------
parts = []

def section(title, note, body):
    n = f'<p class="note">{note}</p>' if note else ""
    parts.append(f'<h2>{esc(title)}</h2>{n}<div class="grid">{body}</div>')

def section_raw(title, note, body):
    n = f'<p class="note">{note}</p>' if note else ""
    parts.append(f'<h2>{esc(title)}</h2>{n}{body}')

# §1 base generators
tiles = []
for gid, line, icon, zone, mp, anchor in BASE_GENS:
    nm, base = LINE[line]
    h, ok = gen_icon(f"generators_{icon}")
    badge = ("ANCHOR" if anchor else "LIVE")
    bcls = "anchor" if anchor else "live"
    tiles.append(tile(h, ok, f"{gid} · {nm}",
                      f"line {line} · zone {zone} · {MAP_NAMES[mp]}<br>icon generators_{icon} · art {base}",
                      badge, bcls, big=True))
section("Base generators — the live per-line roster (17)",
        "The 2026-06-28 gen redesign: ONE generator per BASE line, born on tap as its zone (restoration spot) opens. "
        "Each carries icon <code>generators_N.png</code> and pops its single line. <code>gen_1</code> (Wildflower) is the FTUE anchor. "
        "Generators merge 2:1 up to tier 3. Source: <code>grove_data.gd</code> GENERATORS + ZONE_BASE_LINES.",
        "".join(tiles))

# §2 recipes / specials
rtiles = [recipe_tile(line,a,b,zone,mp,reuse) for line,a,b,zone,mp,reuse in SPECIALS]
section_raw("Recipes — crafted specials (8)",
        "Every 3rd zone is a SPECIAL: no generator, crafted by merging the two base lines just before it (same tier). "
        "71&ndash;75 ship bespoke <code>special_*</code> fruit art; <b>76&ndash;78 reuse SPARE base-line art</b> "
        "(mechanically identical). Recipe derived from the zone model (<code>content.zone_recipe</code>).",
        '<div class="recipes">'+"".join(rtiles)+'</div>')

# §3 base lines as merge chains (t1 -> t12)
ctiles = []
for gid, line, icon, zone, mp, anchor in BASE_GENS:
    nm, base = LINE[line]
    n = tier_count(base)
    (h1,o1),(h2,o2) = item(base,1), item(base,n if n else 1)
    def mini(h,o,lbl):
        im = f'<img src="{esc(h)}" alt="">' if o else '<div class="miss sm">?</div>'
        return f'<figure class="mini"><div class="thumb sm">{im}</div><figcaption>{esc(lbl)}</figcaption></figure>'
    ctiles.append(f'<div class="chain"><div class="chead"><b>{esc(nm)}</b> '
                  f'<span class="muted">line {line} · {n} tiers</span></div>'
                  f'<div class="cbody">{mini(h1,o1,"t1")}<span class="op">&rarr;</span>{mini(h2,o2,"t"+str(n))}</div></div>')
section_raw("Base merge chains — the 17 live lines (t1 &rarr; top tier)",
        "Each base line merges 2:1 up its tier ladder; <code>code = line&times;100 + tier</code>. These are the items the generators above pop.",
        '<div class="chains">'+"".join(ctiles)+'</div>')

# §4 utility generators
utiles = []
for icon,name,banks,cap,secs,val,spot in ACCUMULATORS:
    h,ok = gen_icon(icon)
    utiles.append(tile(h,ok,name,
        f"banks {banks} · +1/{secs//60}m · cap {cap} · &times;{val}<br>unlock spot {spot} · {icon}",
        "BONUS GEN","live", big=True))
section("Utility generators — accumulators (4)",
        "Side-spawn off a main-generator tap (<code>BONUS_SPAWN_CHANCE</code> 3%), pop collectables for a random "
        "<code>BONUS_CLICKS</code> [5&ndash;15] budget, then vanish. Named art, wired. Source: ACCUMULATORS.",
        "".join(utiles))

ttiles = []
for icon in TREAT_ICONS:
    h,ok = gen_icon(icon)
    ttiles.append(tile(h,ok,icon.replace("gen_",""), icon, "SHELVED","shelved", big=True))
section("Treat-generator icons (5) — shelved",
        "The per-map treat generator's random icon pool (<code>TREAT_GEN_TEX</code>). "
        "Currently OFF: <code>TREAT_SPAWN_CHANCE = 0.0</code> — art kept, emission path shelved.",
        "".join(ttiles))

# §5 SPARE / parked generator art
stiles = []
for n in SPARE_NUM_ICONS:
    h,ok = gen_icon(f"generators_{n}")
    stiles.append(tile(h,ok,f"generators_{n}", "unassigned", "SPARE","spare", big=True))
section(f"Spare generator icons ({len(SPARE_NUM_ICONS)}) — unassigned",
        "Numbered icons <code>generators_18&ndash;36.png</code> ship in the repo but are NOT referenced by any generator. "
        "Free pool for future generators / a repaint.",
        "".join(stiles))

ptiles = []
for icon in PARKED_NAMED:
    h,ok = gen_icon(icon)
    ptiles.append(tile(h,ok,icon.replace("gen_",""), icon, "PARKED","spare", big=True))
section(f"Parked legacy generator icons ({len(PARKED_NAMED)})",
        "Named icons from the retired one-generator-per-map theme (<code>gen_wildflowers/twig_nest/cattails/apples/glowcaps</code>) "
        "plus the authored-but-unwired replacements <code>gen_honeycomb</code> (Honey) and <code>gen_porcini</code> (Mushroom). "
        "Not in the live roster.",
        "".join(ptiles))

# §6 shelved item lines
sltiles = []
for line in SHELVED_LINES:
    nm, base = LINE[line]
    h,ok = item(base,1)
    n = tier_count(base)
    if line in REUSED_INTO:
        badge, bcls = f"ART → special {REUSED_INTO[line]}", "reused"
    elif line in FARM_LINES:
        badge, bcls = "FARM · shelved", "shelved"
    else:
        badge, bcls = "SHELVED", "shelved"
    sltiles.append(tile(h,ok,f"{nm}", f"line {line} · {n} tiers · {base}", badge, bcls, big=True))
section(f"Shelved item lines ({len(SHELVED_LINES)})",
        "Lines defined in <code>LINES</code> with full art, but NOT in the 25-zone roster — so no generator pops them. "
        "Three have their art REUSED by the late specials: <b>44&rarr;76, 54&rarr;77, 52&rarr;78</b>. "
        "The Farm lines 61&ndash;66 are the staged-line model (retired; <code>min_level</code> now vestigial).",
        "".join(sltiles))

# §7 residents (reference — wired)
restiles = []
for rid,name,mapd in RESIDENTS:
    h,ok = art(f"items/resident_{rid}/resident_{rid}_1.png")
    restiles.append(tile(h,ok,name, f"{mapd} · 12 tiers<br>resident_{rid}", "LIVE","live", big=True))
section("Residents — population sub-game (5, reference)",
        "Separate from the merge board: one spirit-folk family per map, welcomed (bought) and merged up a 12-tier ladder. "
        "Wired art (<code>RESIDENT_LINES</code>) — listed so it isn't mistaken for spare.",
        "".join(restiles))

# §8 special drop items (reference — wired)
ditiles = []
for line,name,base in SPECIAL_ITEMS:
    h,ok = item(base,1)
    n = tier_count(base)
    ditiles.append(tile(h,ok,name, f"line {line} · {n} tiers · {base}", "LIVE","live", big=True))
section("Special drop & currency items (reference)",
        "Pseudo-lines that drop/merge but are never popped by generators or asked by quests "
        "(<code>SPECIAL_ITEMS</code> + the coin line). Wired art — reference, not spare.",
        "".join(ditiles))

# ===========================================================================
counts = {
    "base generators": len(BASE_GENS),
    "specials / recipes": len(SPECIALS),
    "spare gen icons": len(SPARE_NUM_ICONS),
    "parked named icons": len(PARKED_NAMED),
    "shelved lines": len(SHELVED_LINES),
}
kpis = "".join(f'<div class="kpi"><b>{v}</b><span>{esc(k)}</span></div>' for k,v in counts.items())

legend = """
<span class="badge anchor">ANCHOR</span><span class="badge live">LIVE</span>
<span class="badge bespoke">bespoke art</span><span class="badge reused">SPARE art reused</span>
<span class="badge spare">SPARE</span><span class="badge shelved">SHELVED</span>
""".strip()

doc = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Acorn Forest — Asset Grid (generators · recipes · spare)</title>
<style>
  :root{{
    --bg:#10140f; --panel:#181d15; --panel2:#1f261a; --ink:#e8efe0; --muted:#9aa890;
    --line:#2c3626; --accent:#9ad36b; --warn:#e6b65c; --bad:#e07a6b; --good:#7fd0a0;
    --reuse:#9b8cd6;
  }}
  *{{box-sizing:border-box}}
  body{{margin:0;background:var(--bg);color:var(--ink);font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;padding:24px;max-width:1180px;margin:0 auto}}
  h1{{font-size:22px;margin:0 0 2px}}
  h2{{font-size:16px;margin:30px 0 8px;color:var(--accent);border-bottom:1px solid var(--line);padding-bottom:6px}}
  .sub{{color:var(--muted)}}
  .lead{{color:var(--muted);margin:0 0 14px}}
  .note{{color:var(--muted);font-size:12.5px;margin:2px 0 12px}}
  code{{background:var(--panel2);padding:1px 5px;border-radius:4px;color:var(--accent);font-size:12px}}
  .kpis{{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px;margin:6px 0 4px}}
  .kpi{{background:var(--panel2);border:1px solid var(--line);border-radius:8px;padding:10px}}
  .kpi b{{display:block;font-size:22px;color:var(--accent)}} .kpi span{{font-size:11px;color:var(--muted)}}
  .legend{{display:flex;flex-wrap:wrap;gap:8px;align-items:center;background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:10px 12px;margin:10px 0 4px}}
  .grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(132px,1fr));gap:10px}}
  .tile{{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:8px;display:flex;flex-direction:column;align-items:center;text-align:center}}
  .tile.big{{padding:10px}}
  .thumb{{position:relative;width:100%;display:flex;align-items:center;justify-content:center;background:var(--panel2);border-radius:8px;padding:8px;min-height:74px}}
  .thumb img{{max-width:84px;max-height:84px;width:auto;height:auto;display:block;image-rendering:auto}}
  .thumb.sm img{{max-width:54px;max-height:54px}}
  .cap{{font-size:12px;margin-top:6px;font-weight:600}}
  .tile .sub{{font-size:10.5px;color:var(--muted);margin-top:2px;line-height:1.35}}
  .miss{{color:var(--bad);font-size:11px;padding:18px 6px;font-family:monospace}}
  .miss.sm{{padding:8px}}
  .badge{{display:inline-block;font-size:9.5px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;
          padding:2px 6px;border-radius:999px;border:1px solid var(--line);background:var(--panel2);color:var(--muted)}}
  .thumb .badge{{position:absolute;top:5px;right:5px}}
  .badge.live{{color:#0f1a0f;background:var(--good);border-color:var(--good)}}
  .badge.anchor{{color:#0f1a0f;background:var(--accent);border-color:var(--accent)}}
  .badge.spare{{color:#1a0f0f;background:var(--bad);border-color:var(--bad)}}
  .badge.shelved{{color:#1a160a;background:var(--warn);border-color:var(--warn)}}
  .badge.reused{{color:#120f1f;background:var(--reuse);border-color:var(--reuse)}}
  .badge.bespoke{{color:var(--good);background:transparent;border-color:var(--good)}}
  .recipes{{display:grid;grid-template-columns:repeat(auto-fill,minmax(310px,1fr));gap:10px}}
  .recipe{{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:10px 12px}}
  .rhead{{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin-bottom:6px}}
  .rhead .muted{{font-size:11px;color:var(--muted)}}
  .rbody{{display:flex;align-items:center;justify-content:center;gap:8px}}
  .mini{{margin:0;display:flex;flex-direction:column;align-items:center;gap:3px}}
  .mini img{{max-width:52px;max-height:52px;background:var(--panel2);border-radius:6px;padding:4px}}
  .mini .thumb.sm{{min-height:0;padding:4px}}
  .mini figcaption{{font-size:9.5px;color:var(--muted);max-width:64px}}
  .mini.out figcaption{{color:var(--accent);font-weight:600}}
  .op{{color:var(--muted);font-size:16px;font-weight:700}}
  .chains{{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:10px}}
  .chain{{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:8px 10px}}
  .chead{{font-size:12px;margin-bottom:4px}} .chead .muted{{font-size:10.5px;color:var(--muted)}}
  .cbody{{display:flex;align-items:center;justify-content:center;gap:8px}}
  .muted{{color:var(--muted)}}
  footer{{margin:30px 0 6px;color:var(--muted);font-size:11.5px;border-top:1px solid var(--line);padding-top:10px}}
</style>
</head>
<body>
<h1>Acorn Forest — Asset Grid</h1>
<p class="lead">Live map of every board asset: which <b>generators</b> and <b>recipes</b> are wired, and which art is <b>spare</b>.
Generated from <code>games/grove/grove_data.gd</code> — every thumbnail links a real file under <code>games/grove/assets/</code>.</p>

<div class="kpis">{kpis}</div>
<div class="legend">{legend}</div>

{''.join(parts)}

<footer>Generated by <code>games/grove/tools/gen_asset_grid.py</code> from <code>games/grove/grove_data.gd</code>
(LINES · GENERATORS · ZONE_BASE_LINES/ZONE_SPECIAL_LINES · ACCUMULATORS · TREAT_GEN_TEX · RESIDENT_LINES · SPECIAL_ITEMS).
Re-run <code>python3 games/grove/tools/gen_asset_grid.py</code> after editing the data tables to refresh.
Codes: <code>item = line&times;100 + tier</code>.</footer>
</body>
</html>
"""

with open(OUT, "w") as f:
    f.write(doc)

print(f"WROTE {OUT} ({len(doc):,} bytes)")
if MISSING:
    print(f"\n!! {len(MISSING)} MISSING art paths:")
    for m in MISSING:
        print("  -", m)
else:
    print("All referenced art paths exist on disk.")
