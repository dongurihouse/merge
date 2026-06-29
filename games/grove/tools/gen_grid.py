#!/usr/bin/env python3
"""Generate a self-contained HTML grid of all grove item + character (resident) assets.
Parses grove_data.gd for the authoritative metadata, scans disk for what art exists,
flags missing / extra tiers. Images referenced by absolute file:// path."""
import os, re, html, json

ROOT   = "/Users/xup/dh/merge/games/grove"
ASSETS = os.path.join(ROOT, "assets")
ITEMS  = os.path.join(ASSETS, "items")
DATA   = os.path.join(ROOT, "grove_data.gd")

text = open(DATA).read()

# ── pull a `const NAME := { ... }` block by brace-matching ────────────────────
def block(name):
    m = re.search(r'const '+name+r'\s*:=\s*\{', text)
    i = m.end()-1
    depth = 0
    start = i
    while i < len(text):
        c = text[i]
        if c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return text[start+1:i]
        i += 1
    return ""

def field(inner, key, num=False):
    if num:
        m = re.search(r'"'+key+r'"\s*:\s*(\d+)', inner)
        return int(m.group(1)) if m else None
    m = re.search(r'"'+key+r'"\s*:\s*"([^"]*)"', inner)
    return m.group(1) if m else None

def color(inner):
    m = re.search(r'"color"\s*:\s*Color\("([^"]*)"\)', inner)
    return m.group(1) if m else None

# parse an entry block into [(key, inner, comment)], one entry per physical line
def entries(blk, str_key=False):
    out = []
    keyre = r'"(\w+)"' if str_key else r'(\d+)'
    pat = re.compile(r'^\s*'+keyre+r'\s*:\s*\{(.*)\}\s*,?\s*(?:#\s*(.*))?$')
    for line in blk.splitlines():
        m = pat.match(line)
        if m:
            out.append((m.group(1), m.group(2), (m.group(3) or "").strip()))
    return out

LINES    = entries(block("LINES"))
SPECIALS = entries(block("SPECIAL_ITEMS"))
RESID    = entries(block("RESIDENT_LINES"), str_key=True)

# generator pngs actually referenced anywhere in the data (named gen_*.png: accumulators + treat)
gen_refs = set(re.findall(r'items/generator/(gen_\w+\.png)', text))

# ── NEW per-line generator roster + zone recipes (gen redesign 2026-06-28) ────
def array_block(name):
    m = re.search(r'const '+name+r'\s*:=\s*\[', text)
    if not m: return ""
    i = m.end()-1; depth = 0; start = i
    while i < len(text):
        c = text[i]
        if c == '[': depth += 1
        elif c == ']':
            depth -= 1
            if depth == 0: return text[start+1:i]
        i += 1
    return ""

def int_list(name):
    m = re.search(r'const '+name+r'\s*:=\s*\[([^\]]*)\]', text)
    return [int(x) for x in re.findall(r'-?\d+', m.group(1))] if m else []

# GENERATORS: one producer per BASE line; tex = its icon items/generator/generators_N.png
GEN_DEFS = []
for em in re.finditer(r'\{([^}]*)\}', array_block("GENERATORS")):
    inner = em.group(1)
    gid = re.search(r'"id"\s*:\s*"([^"]+)"', inner)
    if not gid: continue
    def _gi(k, _in=inner):
        m = re.search(r'"'+k+r'"\s*:\s*(\d+)', _in); return int(m.group(1)) if m else None
    tex = re.search(r'"tex"\s*:\s*"items/generator/([^"]+)"', inner)
    lab = re.search(r'"label"\s*:\s*"([^"]+)"', inner)
    GEN_DEFS.append({"id": gid.group(1), "line": _gi("line"), "zone": _gi("zone"), "map": _gi("map"),
                     "tex": tex.group(1) if tex else None, "label": lab.group(1) if lab else "",
                     "anchor": bool(re.search(r'"anchor"\s*:\s*true', inner))})
GEN_BY_LINE = {g["line"]: g for g in GEN_DEFS}
GEN_TEX     = {g["tex"]: g for g in GEN_DEFS if g["tex"]}

# zone model — base·base·special rhythm; a special is crafted from the two base lines before it
ZONE_BASE    = int_list("ZONE_BASE_LINES")
ZONE_SPECIAL = int_list("ZONE_SPECIAL_LINES")
RECIPE = {sp: (ZONE_BASE[2*k], ZONE_BASE[2*k+1]) for k, sp in enumerate(ZONE_SPECIAL) if 2*k+1 < len(ZONE_BASE)}
MAP_SPOTS = [6, 4, 7, 4, 4]
MAP_NAME  = ["The Farm", "The Orchard", "The Garden", "The Mill", "The Gate"]
def zone_to_map(z):
    c = 0
    for mi, n in enumerate(MAP_SPOTS):
        if z < c+n: return mi
        c += n
    return len(MAP_SPOTS)-1
# full 25-zone sequence → zone index per line (base·base·special)
ZONE_OF_LINE = {}; _bi = 0; _k = 0; _zi = 0
while _bi < len(ZONE_BASE):
    ZONE_OF_LINE[ZONE_BASE[_bi]] = _zi; _zi += 1; _bi += 1
    if _bi < len(ZONE_BASE):
        ZONE_OF_LINE[ZONE_BASE[_bi]] = _zi; _zi += 1; _bi += 1
    if _k < len(ZONE_SPECIAL):
        ZONE_OF_LINE[ZONE_SPECIAL[_k]] = _zi; _zi += 1; _k += 1

# base → line codes using it (art-reuse detection: a special borrowing a shelved line's art)
BASE_TO_LINES = {}
for _c, _in, _cm in LINES:
    BASE_TO_LINES.setdefault(field(_in, "base"), []).append(int(_c))
LINE_NAME = {int(c): field(i, "name") for c, i, _ in LINES}
def reuse_of(line, base):          # the shelved base line whose art this special reuses
    return [c for c in BASE_TO_LINES.get(base, []) if c != line and c not in ZONE_SPECIAL]
def specials_reusing(base):        # specials that borrow THIS shelved line's art
    return [c for c in BASE_TO_LINES.get(base, []) if c in ZONE_SPECIAL]

# accumulator + treat generator icons (named art, wired)
ACC_TEX = {}
for _k2, _in2, _cm2 in entries(block("ACCUMULATORS"), str_key=True):
    _t = re.search(r'items/generator/(gen_\w+\.png)', _in2)
    if _t: ACC_TEX[_t.group(1)] = field(_in2, "name")
_tm = re.search(r'const TREAT_GEN_TEX\s*:=\s*\[(.*?)\]', text, re.S)
TREAT_TEX = set(re.findall(r'items/generator/(gen_\w+\.png)', _tm.group(1))) if _tm else set()

# the live per-line icons count as referenced → fixes the orphan scan AND the spare classification
gen_refs |= {g["tex"] for g in GEN_DEFS if g["tex"]}

# ── UNUSED-ASSET SCAN: PNGs in shipping dirs not referenced by any code/data ──
REPO   = os.path.dirname(os.path.dirname(ROOT))           # /Users/xup/dh/merge
ENGINE = os.path.join(REPO, "engine")
corpus = []
for base in (ROOT, ENGINE):
    for r,_,fs in os.walk(base):
        for f in fs:
            if f.endswith((".gd",".tscn",".tres",".json",".cfg",".godot")) and not f.endswith(".import"):
                try: corpus.append(open(os.path.join(r,f),errors="ignore").read())
                except Exception: pass
CORP = "\n".join(corpus)

line_bases = set(re.findall(r'"base"\s*:\s*"([^"]+)"', block("LINES")))   # 12-tier (incl special_* treat lines)
spec_defs  = {}
for ln in block("SPECIAL_ITEMS").splitlines():
    mb = re.search(r'"base"\s*:\s*"([^"]+)"', ln)
    if mb:
        tp = re.search(r'"top"\s*:\s*(\d+)', ln)
        spec_defs[mb.group(1)] = int(tp.group(1)) if tp else 3
spec_defs["coin"] = 3
resident_bases = {"resident_"+i for i in re.findall(r'"id":\s*"(\w+)"', block("RESIDENT_LINES"))}
try:
    GIVER_COUNT = int(re.search(r'GIVER_COUNT\s*:=\s*(\d+)', open(os.path.join(ENGINE,"scripts/ui/bust.gd")).read()).group(1))
except Exception:
    GIVER_COUNT = 16

def _maxtier(b):
    if b in spec_defs: return spec_defs[b]
    if b in line_bases or b in resident_bases: return 12
    return None
def _dyn(stem):
    cands={re.sub(r'\d+','%d',stem), re.sub(r'\d+','%s',stem)}
    m=re.match(r'(.*_)([a-z]+)$',stem)
    if m: cands.add(m.group(1)+'%s')
    return any(c!=stem and c in CORP for c in cands)
def is_referenced(rel):
    name=os.path.basename(rel); stem=name[:-4]
    m=re.match(r'items/([^/]+)/([^/]+)_(\d+)\.png$', rel)
    if m:
        b,fb,t=m.group(1),m.group(2),int(m.group(3))
        if b=="generator": return name in gen_refs
        if b!=fb: return False
        mt=_maxtier(b); return mt is not None and 1<=t<=mt
    if rel.startswith("items/generator/"): return name in gen_refs
    g=re.match(r'characters/giver_(\d+)\.png$', rel)
    if g: return int(g.group(1))<GIVER_COUNT
    snr=re.sub(r'@\d+$','',stem)
    return (stem in CORP) or (snr in CORP) or _dyn(stem) or _dyn(snr)

SHIP_DIRS=["items","characters","map","ui","baked"]
orphans=[]
for d in SHIP_DIRS:
    bp=os.path.join(ASSETS,d)
    for r,_,fs in os.walk(bp):
        for f in fs:
            if f.endswith(".png"):
                rel=os.path.relpath(os.path.join(r,f),ASSETS)
                if not is_referenced(rel): orphans.append(rel)
orphans.sort()

# giver (quest-giver character) portraits on disk
giver_dir=os.path.join(ASSETS,"characters")
givers=sorted([f for f in os.listdir(giver_dir) if re.match(r'giver_\d+\.png$',f)],
              key=lambda x:int(re.search(r'(\d+)',x).group(1))) if os.path.isdir(giver_dir) else []

# ── disk scan helpers ─────────────────────────────────────────────────────────
def tiers_on_disk(base):
    d = os.path.join(ITEMS, base)
    found = {}
    if os.path.isdir(d):
        for f in os.listdir(d):
            m = re.match(re.escape(base)+r'_(\d+)\.png$', f)
            if m:
                found[int(m.group(1))] = os.path.join(d, f)
    return found

def fileurl(p):
    return "file://" + p

# ── build row data ────────────────────────────────────────────────────────────
def make_row(code, name, base, desc, maxtier, col, kind="", extra=""):
    disk = tiers_on_disk(base)
    cells = []
    missing = []
    for t in range(1, maxtier+1):
        present = t in disk
        if not present:
            missing.append(t)
        itemid = (int(code)*100+t) if str(code).isdigit() else f"{base}_{t}"
        info = {
            "id": str(itemid), "line": str(code), "name": name, "base": base,
            "tier": t, "max": maxtier, "kind": kind,
            "path": (disk.get(t) or f"{base}/{base}_{t}.png"),
            "desc": desc, "present": present,
        }
        cells.append((t, present, disk.get(t), info))
    # extra tiers present beyond the expected max
    extras = sorted(x for x in disk if x > maxtier)
    return {"code": str(code), "name": name, "base": base, "color": col or "#888",
            "kind": kind, "maxtier": maxtier, "cells": cells, "missing": missing,
            "extras": extras, "have": len(disk), "note": extra, "desc": desc}

rows_items, rows_special, rows_resid, rows_gen = [], [], [], []

# group + note per line — the 25-zone roster: base lines by map, specials = recipes, rest = shelved
SPECIAL_GROUP = "Crafted specials — recipes (no generator)"
SHELVED_GROUP = "Shelved — art on disk, not in the 25-zone roster"
FARM_LINES = {61, 62, 63, 64, 65, 66}
def line_group_note(code, base):
    c = int(code)
    if c in GEN_BY_LINE:
        g = GEN_BY_LINE[c]
        return (f"Map {g['map']} · {MAP_NAME[g['map']]}",
                f"⚙ {g['id']} · zone {g['zone']} · icon {g['tex']}"
                + (" · ANCHOR (FTUE starter)" if g['anchor'] else ""))
    if c in ZONE_SPECIAL:
        a, b = RECIPE.get(c, (None, None))
        rec = f"recipe: {LINE_NAME.get(a, a)} ({a}) + {LINE_NAME.get(b, b)} ({b})" if a else "recipe: —"
        z = ZONE_OF_LINE.get(c)
        loc = f"zone {z} · map {zone_to_map(z)} ({MAP_NAME[zone_to_map(z)]})" if z is not None else ""
        ru = reuse_of(c, base)
        tail = f" · reuses SPARE art (line {ru[0]} {LINE_NAME.get(ru[0], '')})" if ru else " · bespoke art"
        return (SPECIAL_GROUP, f"{loc} · {rec}{tail}")
    sp = specials_reusing(base)
    bits = ["Farm line" if c in FARM_LINES else "shelved", "no generator"]
    if sp: bits.append(f"art → special {sp[0]} ({LINE_NAME.get(sp[0], '')})")
    return (SHELVED_GROUP, " · ".join(bits))

for code, inner, cmt in LINES:
    base = field(inner, "base")
    grp, note = line_group_note(code, base)
    rows_items.append((grp, make_row(code, field(inner, "name"), base,
                       field(inner, "desc"), 12, color(inner), extra=note)))

SPECIAL_TOP = 3
for code, inner, cmt in SPECIALS:
    top = field(inner,"top",True) or SPECIAL_TOP
    rows_special.append(make_row(code, field(inner,"name"), field(inner,"base"),
                       field(inner,"desc"), top, color(inner), kind=field(inner,"kind") or ""))
# coin is a board item but lives outside SPECIAL_ITEMS (COIN_LINE 9)
rows_special.append(make_row(9, "Coin", "coin", "On-board currency; merges to t3, tap-collect.", 3, "#E3C84A", kind="coin"))

MAP_THEME = {"farmhouse":"The Farm","barn":"The Orchard","pond":"The Garden","orchard":"The Mill","meadow":"The Gate"}
for mapkey, inner, cmt in RESID:
    rid = field(inner,"id"); rname = field(inner,"name")
    rows_resid.append(make_row(rid, rname, "resident_"+rid, cmt or "", 12, "#B6A7D9",
                       kind="resident", extra=MAP_THEME.get(mapkey, mapkey)))

# generators gallery
gendir = os.path.join(ITEMS,"generator")
if os.path.isdir(gendir):
    for f in sorted(x for x in os.listdir(gendir) if x.endswith(".png")):
        used = f in gen_refs
        rows_gen.append({"file":f, "path":os.path.join(gendir,f), "used":used})

# ── render ────────────────────────────────────────────────────────────────────
def esc(s): return html.escape(str(s if s is not None else ""))

def cell_html(t, present, path, info):
    di = " ".join(f'data-{k}="{esc(v)}"' for k,v in info.items())
    if present:
        inner = f'<a href="{fileurl(path)}" target="_blank"><img loading="lazy" src="{fileurl(path)}"></a>'
        cls = "cell"
    else:
        inner = f'<div class="miss">×</div>'
        cls = "cell bad"
    return f'<div class="{cls}" {di}><div class="imgwrap">{inner}</div><span class="cap">{t}</span></div>'

def row_html(r):
    ok = not r["missing"] and not r["extras"]
    status = f'{r["have"]}/{r["maxtier"]}'
    badbits = []
    if r["missing"]: badbits.append(f'missing {",".join(map(str,r["missing"]))}')
    if r["extras"]:  badbits.append(f'extra {",".join(map(str,r["extras"]))}')
    statcls = "ok" if ok else "warn"
    stattxt = status + ("" if ok else " — "+"; ".join(badbits))
    search = f'{r["code"]} {r["name"]} {r["base"]} {r["kind"]} {r["note"]}'.lower()
    cells = "".join(cell_html(t,p,pa,info) for (t,p,pa,info) in r["cells"])
    note = f'<span class="note">{esc(r["note"])}</span>' if r["note"] else ""
    return f'''<div class="row {'has-problem' if not ok else ''}" data-search="{esc(search)}" data-problem="{0 if ok else 1}" style="--lc:{r['color']}">
      <div class="rowhead">
        <span class="code">{esc(r["code"])}</span>
        <span class="swatch" style="background:{r['color']}" title="fallback color {r['color']}"></span>
        <span class="name">{esc(r["name"])}</span>
        <span class="base">{esc(r["base"])}</span>{note}
        <span class="status {statcls}">{esc(stattxt)}</span>
      </div>
      <div class="tiers">{cells}</div>
    </div>'''

def section(title, rows, subtitle=""):
    body = "".join(row_html(r) for r in rows)
    sub = f'<p class="sub">{esc(subtitle)}</p>' if subtitle else ""
    return f'<section><h2>{esc(title)} <span class="count">{len(rows)} lines</span></h2>{sub}{body}</section>'

# grouped items section — by map (base lines), then crafted specials (recipes), then shelved
def grouped_items():
    groups = {}
    for z, r in rows_items:
        groups.setdefault(z, []).append(r)
    order = [f"Map {i} · {MAP_NAME[i]}" for i in range(len(MAP_NAME))] + [SPECIAL_GROUP, SHELVED_GROUP]
    sub = {SPECIAL_GROUP: "Every 3rd zone — crafted by merging the two base lines before it (same tier), no generator. "
                          "71–75 ship bespoke special_* art; 76–78 reuse SPARE base-line art.",
           SHELVED_GROUP: "Defined in LINES with full art, but no generator in the 25-zone roster — never popped or asked. "
                          "Lines 44·54·52 have their art reused by specials 76·77·78; 61–66 are the retired staged Farm lines."}
    out = ['<section><h2>Item lines <span class="count">'+str(len(rows_items))+
           ' lines · code = line×100 + tier · base·base·special 25-zone roster</span></h2>']
    for z in order:
        if z in groups:
            out.append(f'<h3>{esc(z)}</h3>')
            if z in sub: out.append(f'<p class="sub">{esc(sub[z])}</p>')
            out += [row_html(r) for r in sorted(groups[z], key=lambda r: int(r["code"]))]
    out.append('</section>')
    return "".join(out)

def gen_html():
    roles = {"live": [], "acc": [], "treat": [], "spare": [], "parked": []}
    for g in rows_gen:
        f, path = g["file"], g["path"]
        if f in GEN_TEX:
            gd = GEN_TEX[f]
            roles["live"].append((f, path, f"{gd['id']} · {LINE_NAME.get(gd['line'], '')}", True,
                f"line {gd['line']} · zone {gd['zone']} · map {gd['map']} ({MAP_NAME[gd['map']]})"
                + (" · ANCHOR" if gd['anchor'] else "")))
        elif f in ACC_TEX:
            roles["acc"].append((f, path, ACC_TEX[f], True, "accumulator / bonus generator"))
        elif f in TREAT_TEX:
            roles["treat"].append((f, path, f.replace("gen_", "").replace(".png", ""), True, "treat generator — shelved"))
        elif re.match(r'generators_\d+\.png$', f):
            roles["spare"].append((f, path, f.replace(".png", ""), False, "unassigned — SPARE"))
        else:
            roles["parked"].append((f, path, f.replace("gen_", "").replace(".png", ""), False, "parked legacy icon — not in roster"))

    def grid(items):
        cells = []
        for f, path, cap, used, detail in items:
            info = {"file": f, "path": path, "referenced": used, "detail": detail}
            di = " ".join(f'data-{k}="{esc(v)}"' for k, v in info.items())
            cls = "cell" if used else "cell stale"
            badge = "" if used else '<span class="cap warnote">spare</span>'
            cells.append(f'<div class="{cls}" {di}><div class="imgwrap"><a href="{fileurl(path)}" target="_blank">'
                         f'<img loading="lazy" src="{fileurl(path)}"></a></div>'
                         f'<span class="cap fn">{esc(cap)}</span>{badge}</div>')
        return '<div class="tiers gengrid">'+"".join(cells)+'</div>'

    secs = [('Live — per-line generators', roles["live"],
             'generators_1…17 — one per base line, tap-born as its zone opens, merge 2:1 to tier 3. gen_1 (Wildflower) is the FTUE anchor.'),
            ('Accumulators (bonus generators)', roles["acc"], 'Side-spawn off a main-generator tap, pop collectables, then vanish.'),
            ('Treat generators — shelved', roles["treat"], 'TREAT_SPAWN_CHANCE = 0.0 — emission path shelved, art kept.'),
            ('SPARE — unassigned generator icons', roles["spare"], 'generators_18…36 — on disk, referenced by nothing. Free pool for future generators.'),
            ('Parked legacy icons', roles["parked"], 'Retired per-map theme icons + authored-but-unwired replacements (gen_honeycomb, gen_porcini).')]
    body = []
    for title, items, subt in secs:
        if not items: continue
        body.append(f'<h3>{esc(title)} <span class="count">{len(items)}</span></h3>'
                    f'<p class="sub">{esc(subt)}</p>'+grid(items))
    n_spare = len(roles["spare"]) + len(roles["parked"])
    return ('<section><h2>Generators <span class="count">'+str(len(rows_gen))+
            f' icons · {len(roles["live"])} live · {n_spare} spare/parked</span></h2>'
            '<p class="sub">Icons under items/generator/. Each LIVE icon maps to its line above; SPARE / parked icons are unreferenced.</p>'
            +"".join(body)+'</section>')

def gcell(abspath, caplabel, referenced, cls_extra=""):
    info = {"file": os.path.basename(abspath), "path": abspath, "referenced": referenced}
    di = " ".join(f'data-{k}="{esc(v)}"' for k,v in info.items())
    cls = ("cell "+cls_extra).strip()
    return (f'<div class="{cls}" {di}><div class="imgwrap"><a href="{fileurl(abspath)}" target="_blank">'
            f'<img loading="lazy" src="{fileurl(abspath)}"></a></div>'
            f'<span class="cap fn">{esc(caplabel)}</span></div>')

def givers_html():
    if not givers: return ""
    cells = "".join(gcell(os.path.join(giver_dir,f), re.search(r'(\d+)',f).group(1), "True") for f in givers)
    return (f'<h3>Quest givers — giver_0…{len(givers)-1} <span class="count">{len(givers)} portraits · '
            f'all in use (random pool of {GIVER_COUNT}, picked per quest)</span></h3>'
            f'<div class="tiers gengrid">{cells}</div>')

def orphans_html():
    if not orphans:
        return '<section><h2>Unused / unreferenced</h2><p class="sub">None found — every shipping PNG is referenced.</p></section>'
    from collections import defaultdict
    byd = defaultdict(list)
    for o in orphans:
        byd["/".join(o.split("/")[:-1])].append(o)
    blocks = []
    for folder in sorted(byd):
        cells = "".join(gcell(os.path.join(ASSETS,o), os.path.basename(o)[:-4], "False", "stale")
                        for o in sorted(byd[folder]))
        blocks.append(f'<h3>{esc(folder)}/ <span class="count">{len(byd[folder])}</span></h3>'
                      f'<div class="tiers gengrid">{cells}</div>')
    note = ('PNGs under items/ characters/ map/ ui/ baked/ with NO reference in any .gd/.tscn/.tres/.json. '
            'Click to copy the repo-relative path. Caveat: baked/ outputs and a few dynamically-built UI '
            'paths can be false positives — verify before deleting.')
    return (f'<section><h2>Unused / unreferenced <span class="count">{len(orphans)} files</span></h2>'
            f'<p class="sub">{esc(note)}</p>'+"".join(blocks)+'</section>')

# totals
def count_missing(rows):
    return sum(len(r["missing"]) for r in rows)
tot_missing = count_missing([r for _,r in rows_items]) + count_missing(rows_special) + count_missing(rows_resid)
tot_problem_lines = sum(1 for _,r in rows_items if r["missing"] or r["extras"]) \
                  + sum(1 for r in rows_special if r["missing"] or r["extras"]) \
                  + sum(1 for r in rows_resid if r["missing"] or r["extras"])
tot_imgs = sum(r["have"] for _,r in rows_items)+sum(r["have"] for r in rows_special)+sum(r["have"] for r in rows_resid)

CSS = """
:root{--bg:#1c1f26;--panel:#262a33;--ink:#e8e6e0;--mut:#9aa0ab;--ok:#5fb56b;--warn:#e0a13c;--bad:#e0574f;--line:#343a45}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:13px/1.4 -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif}
header{position:sticky;top:0;z-index:30;background:rgba(20,22,28,.96);backdrop-filter:blur(8px);border-bottom:1px solid var(--line);padding:10px 16px;display:flex;gap:14px;align-items:center;flex-wrap:wrap}
header h1{font-size:15px;margin:0;font-weight:650}
.stat{color:var(--mut)}.stat b{color:var(--ink)}.stat.bad b{color:var(--bad)}
.spacer{flex:1}
input[type=search]{background:#11141a;border:1px solid var(--line);color:var(--ink);padding:6px 10px;border-radius:7px;width:200px}
label.ctl{color:var(--mut);display:flex;gap:5px;align-items:center;cursor:pointer;user-select:none}
.bgsel{display:flex;gap:4px}
.bgsel button{background:#11141a;border:1px solid var(--line);color:var(--mut);padding:5px 9px;border-radius:6px;cursor:pointer}
.bgsel button.on{border-color:var(--ink);color:var(--ink)}
main{padding:8px 16px 80px}
section{margin:18px 0}
h2{font-size:14px;border-bottom:1px solid var(--line);padding-bottom:6px;margin:22px 0 8px;font-weight:600}
h2 .count{color:var(--mut);font-weight:400;font-size:12px}
h3{font-size:12px;color:var(--mut);text-transform:uppercase;letter-spacing:.06em;margin:16px 0 4px;font-weight:600}
.sub{color:var(--mut);margin:2px 0 10px}
.row{display:flex;gap:12px;align-items:flex-start;padding:7px 8px;border-radius:9px;border:1px solid transparent}
.row:hover{background:var(--panel);border-color:var(--line)}
.rowhead{width:210px;flex:none;display:flex;flex-wrap:wrap;gap:5px 7px;align-items:center;padding-top:4px}
.code{font-weight:700;color:#fff;background:var(--line);border-radius:5px;padding:1px 7px;font-variant-numeric:tabular-nums}
.swatch{width:12px;height:12px;border-radius:3px;border:1px solid rgba(255,255,255,.25)}
.name{font-weight:600}
.base{color:var(--mut);font-family:ui-monospace,Menlo,monospace;font-size:11px}
.note{color:#8fb4d9;font-size:11px;width:100%}
.status{width:100%;font-size:11px}
.status.ok{color:var(--ok)}.status.warn{color:var(--warn)}
.tiers{display:flex;flex-wrap:wrap;gap:6px;flex:1}
.gengrid{gap:10px}
.cell{width:76px;display:flex;flex-direction:column;align-items:center;gap:2px;position:relative;cursor:pointer}
.imgwrap{width:72px;height:72px;border-radius:8px;display:flex;align-items:center;justify-content:center;overflow:hidden;border:1px solid var(--line)}
.cell img{max-width:100%;max-height:100%;display:block}
.cap{font-size:10px;color:var(--mut);font-variant-numeric:tabular-nums}
.cap.fn{max-width:72px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.warnote{color:var(--warn)}
.cell.bad .imgwrap{border:1px dashed var(--bad);background:repeating-linear-gradient(45deg,#2a1a1a,#2a1a1a 6px,#241616 6px,#241616 12px)}
.miss{color:var(--bad);font-size:26px;font-weight:300}
.cell.stale .imgwrap{border-color:var(--warn)}
.cell:hover .imgwrap{outline:2px solid #6fa8dc;outline-offset:1px}
/* bg modes on imgwrap */
body.bg-check .imgwrap{background:conic-gradient(#666 90deg,#999 0 180deg,#666 0 270deg,#999 0)0 0/16px 16px,#888}
body.bg-dark .imgwrap{background:#15171c}
body.bg-light .imgwrap{background:#f3f0ea}
body.bg-color .row .imgwrap{background:var(--lc)}
body.bg-color .gengrid .imgwrap{background:#15171c}
body.problems .row:not(.has-problem){display:none}
body.problems h3{opacity:.4}
#tip{position:fixed;z-index:99;pointer-events:none;background:#0c0e12;border:1px solid #3a4150;border-radius:8px;padding:8px 10px;max-width:300px;box-shadow:0 8px 28px rgba(0,0,0,.6);display:none;font-size:12px}
#tip .tid{font-weight:700;color:#fff;font-size:13px}
#tip .trow{color:var(--mut);margin-top:2px}
#tip .trow b{color:var(--ink);font-weight:600}
#tip .tpath{color:#7fae7f;font-family:ui-monospace,Menlo,monospace;font-size:10px;margin-top:5px;word-break:break-all}
#tip .tmiss{color:var(--bad);font-weight:700}
#tip .tdesc{margin-top:5px;color:#c9c4ba;font-style:italic}
#tip .thint{margin-top:6px;color:#5f6b7a;font-size:10px}
#toast{position:fixed;z-index:100;pointer-events:none;background:#1f7a3f;color:#fff;font-weight:650;padding:5px 11px;border-radius:7px;display:none;font-size:12px;box-shadow:0 6px 20px rgba(0,0,0,.55)}
"""

JS = """
const tip=document.getElementById('tip');
function show(el,e){
  const d=el.dataset;
  const hint='<div class="thint">click to copy · ⌘/Ctrl-click opens full image</div>';
  if(d.file!==undefined){ // generator cell
    tip.innerHTML=`<div class="tid">${d.file}</div>
      ${d.detail?`<div class="trow">${d.detail}</div>`:''}
      <div class="trow">referenced in data: <b>${d.referenced==='True'?'yes':'NO — spare'}</b></div>
      <div class="tpath">${d.path}</div>`+hint;
  } else {
    const present=d.present==='True';
    tip.innerHTML=`<div class="tid">${present?'id '+d.id:'<span class=tmiss>MISSING</span> '+d.id}</div>
      <div class="trow">line <b>${d.line}</b> · tier <b>${d.tier}</b>/${d.max}</div>
      <div class="trow">name <b>${d.name}</b></div>
      <div class="trow">base <b>${d.base}</b>${d.kind?' · kind <b>'+d.kind+'</b>':''}</div>
      <div class="tpath">${present?d.path:'(expected) items/'+d.path}</div>
      ${d.desc?`<div class="tdesc">${d.desc}</div>`:''}`+hint;
  }
  tip.style.display='block'; move(e);
}
function move(e){
  const pad=14,w=tip.offsetWidth,h=tip.offsetHeight;
  let x=e.clientX+pad,y=e.clientY+pad;
  if(x+w>innerWidth)x=e.clientX-w-pad;
  if(y+h>innerHeight)y=e.clientY-h-pad;
  tip.style.left=x+'px';tip.style.top=y+'px';
}
document.addEventListener('mouseover',e=>{const c=e.target.closest('.cell');if(c)show(c,e);});
document.addEventListener('mousemove',e=>{if(tip.style.display==='block'){const c=e.target.closest('.cell');if(c)move(e);else tip.style.display='none';}});
document.addEventListener('mouseout',e=>{if(!e.relatedTarget||!e.relatedTarget.closest('.cell'))tip.style.display='none';});
// click to copy
const toast=document.getElementById('toast');
function relOf(p){return p.replace(REPO,'');}
function copyInfo(d){
  if(d.file!==undefined)
    return `${d.file}${d.detail?' · '+d.detail:''} · ${relOf(d.path)} · referenced: ${d.referenced==='True'?'yes':'no'}`;
  const present=d.present==='True';
  const path=present?relOf(d.path):'games/grove/assets/items/'+d.path+' (expected)';
  return `${present?'':'MISSING '}id ${d.id} · line ${d.line} · tier ${d.tier}/${d.max} · ${d.name} · base ${d.base}${d.kind?' · '+d.kind:''} · ${path}`;
}
function copyText(t){
  if(navigator.clipboard&&window.isSecureContext){navigator.clipboard.writeText(t).catch(()=>fallbackCopy(t));}
  else fallbackCopy(t);
}
function fallbackCopy(t){
  const ta=document.createElement('textarea');ta.value=t;ta.style.position='fixed';ta.style.opacity='0';
  document.body.appendChild(ta);ta.focus();ta.select();
  try{document.execCommand('copy');}catch(e){}
  document.body.removeChild(ta);
}
function flash(e,msg){toast.textContent=msg;toast.style.display='block';
  let x=e.clientX+14,y=e.clientY-12;
  if(x+toast.offsetWidth>innerWidth)x=e.clientX-toast.offsetWidth-14;
  toast.style.left=x+'px';toast.style.top=y+'px';
  clearTimeout(toast._t);toast._t=setTimeout(()=>toast.style.display='none',1000);}
document.addEventListener('click',e=>{
  const c=e.target.closest('.cell');if(!c)return;
  if(e.metaKey||e.ctrlKey||e.button===1)return;   // let ⌘/Ctrl-click open the image link
  e.preventDefault();
  const txt=copyInfo(c.dataset);
  copyText(txt);
  flash(e,'✓ copied');
});
// search
const q=document.getElementById('q');
q.addEventListener('input',()=>{const v=q.value.trim().toLowerCase();
  document.querySelectorAll('.row').forEach(r=>{r.style.display=(!v||r.dataset.search.includes(v))?'':'none';});});
// problems only
document.getElementById('po').addEventListener('change',e=>document.body.classList.toggle('problems',e.target.checked));
// bg toggle
const modes=['check','dark','light','color'];
function setbg(m){document.body.className=document.body.className.replace(/bg-\\w+/g,'').trim();document.body.classList.add('bg-'+m);
  document.querySelectorAll('.bgsel button').forEach(b=>b.classList.toggle('on',b.dataset.m===m));}
document.querySelectorAll('.bgsel button').forEach(b=>b.addEventListener('click',()=>setbg(b.dataset.m)));
setbg('check');
"""

doc = f"""<!doctype html><html><head><meta charset="utf-8"><title>Grove asset grid</title><style>{CSS}</style></head>
<body>
<header>
  <h1>Grove assets</h1>
  <span class="stat"><b>{tot_imgs}</b> images</span>
  <span class="stat {'bad' if tot_missing else ''}"><b>{tot_missing}</b> missing tiers</span>
  <span class="stat {'bad' if tot_problem_lines else ''}"><b>{tot_problem_lines}</b> lines with gaps</span>
  <span class="stat {'bad' if orphans else ''}"><b>{len(orphans)}</b> unused files</span>
  <span class="spacer"></span>
  <input id="q" type="search" placeholder="filter id / name / base…">
  <label class="ctl"><input id="po" type="checkbox"> problems only</label>
  <span class="stat">bg</span>
  <span class="bgsel">
    <button data-m="check">checker</button><button data-m="dark">dark</button>
    <button data-m="light">light</button><button data-m="color">line color</button>
  </span>
</header>
<main>
{grouped_items()}
{section("Special / drop items", rows_special, "Chest·key·water·acorn·spark·wildcard·coin — short pseudo-lines (merge to a small top).")}
{section("Characters — residents", rows_resid, "One spirit-folk family per map; merges 2-of-a-kind up a 12-tier ladder. base = resident_<id>.").replace("</section>", givers_html()+"</section>")}
{gen_html()}
{orphans_html()}
</main>
<div id="tip"></div>
<div id="toast"></div>
<script>const REPO={json.dumps(os.path.dirname(os.path.dirname(ROOT))+"/")};</script>
<script>{JS}</script>
</body></html>"""

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "asset_grid.html")
open(out,"w").write(doc)
print("wrote", out)
print(f"items lines={len(rows_items)} special={len(rows_special)} residents={len(rows_resid)} generators={len(rows_gen)}")
print(f"images={tot_imgs} missing_tiers={tot_missing} problem_lines={tot_problem_lines}")
