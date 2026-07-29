#!/usr/bin/env python3
"""Measure — and then SHOW — the cast shadow beside each tab on a navtab_shot.gd sheet.

navtab_shot.gd puts our nav tab and the concept mock's own tab on ONE sheet: same flat sky, same
scale, and (with `fill=`) the same paper colour, so the only thing left varying between two cells is
the shadow. This reads that sheet back.

  python3 games/grove/tools/navtab_profile.py --sheet /tmp/navtab.png --side left \
      --out /tmp/navtab_sheet.png

The cell rects come from `<sheet>.json`, which navtab_shot writes beside every capture (`--cells`
takes a path or the literal JSON instead).

For each cell it steps outward from the tab's own edge and reports the DARKENING
(1 - sampled_luma / field_luma) at each pixel. The field luma is ONE number for the whole sheet — the
flat field the tool painted, which is by construction the mean of the mock's own sky — so a darkening
on one cell means the same thing as a darkening on the next. That is the property every earlier
comparison lacked: alpha inferred from a luma ratio is a function of the ground it falls on, and those
measurements were taken over different grounds, at different scales, through different fills.

TWO THINGS THIS REFUSES TO DO, because both of them silently produce a believable wrong number:

  * MEASURE OFF A NOMINAL EDGE. A nav tab FLARES — its sheet is ~7% narrower at the top — so its edge
    moves several px across the rows a profile averages over. Sampling one fixed column and taking the
    median smears the falloff into a slope that is a property of the flare, not of the shadow (measured:
    it turned a flat contact plateau into a decay, and the first tuning read off it was wrong). Every
    row finds the tab's own edge first, by the largest colour step near it, and steps out from THAT.
  * REPORT WHERE THERE IS NO GROUND. A mock cell crops the concept art and the concept art runs out —
    24px of sky beside the leftmost tab, 10px before the next tab starts. Past that the cell is flat
    field, which profiles as a perfect 0.000 and reads as "the shadow ended here". `real_ground` in the
    cell record bounds every profile; nothing is reported where nothing was measured.

`--out` writes a review sheet: each cell at 1x, the same edge zoomed `--zoom` times so the falloff is
actually visible, and the numbers under it. LOOK at that file; the numbers alone are not the check.
"""

import argparse
import json
import sys

from PIL import Image, ImageDraw, ImageFont

# Rec.601 luma — the same weighting every shadow measurement in this project has used.
LUMA = (0.299, 0.587, 0.114)
# Distances (px out from the tab's edge) printed under each cell. Past ~16px nothing in play reaches.
REPORT_AT = (1, 2, 3, 4, 6, 8, 10, 12, 16)
# How far either side of the nominal edge the per-row edge finder looks. Wide enough for the flare's
# full run (~5px each side) and for a mock rect measured a pixel or two off, tight enough that it can
# never wander onto the glyph or the neighbouring tab.
EDGE_SEARCH = 14
# How far from the tab's FACE colour, as a fraction of the whole face→field distance, a pixel must be
# before it counts as ground rather than as part of the edge. Both the mock's arc and our own 2px
# `edge_feather` blend face into ground over a pixel or two, and "the largest colour step" lands
# ANYWHERE inside that blend depending on how it happens to fall — measured, it moved our whole profile
# by a pixel against the mock's, which at 1-2px out is the entire contact reading. `d = 1` is instead
# the first pixel carrying no more than 1 - EDGE_GROUND of the face, which is the same physical place
# on any edge however it is antialiased.
EDGE_GROUND = 0.85


def luma(px):
    return LUMA[0] * px[0] + LUMA[1] * px[1] + LUMA[2] * px[2]


def median(xs):
    s = sorted(xs)
    n = len(s)
    return s[n // 2] if n % 2 else 0.5 * (s[n // 2 - 1] + s[n // 2])


def name(cell):
    """What a column is CALLED: the tab's own label when navtab_shot gave it one, else its raw spec."""
    return cell.get("label") or cell["spec"]


def sample_band(cell, side, corner_skip):
    """The rows (or columns) a profile is averaged over: the tab's flat edge, clear of its corner arc."""
    x, y, w, h = cell["tab_x"], cell["tab_y"], cell["tab_w"], cell["tab_h"]
    if side in ("left", "right"):
        return range(y + corner_skip, y + h)
    return range(x + corner_skip, x + w - corner_skip)


def l1(p, q):
    return abs(p[0] - q[0]) + abs(p[1] - q[1]) + abs(p[2] - q[2])


def face_color(px, size, cell, side):
    """The tab's own face, sampled well inside its edge — the reference the edge finder walks away from."""
    W, H = size
    x, y, w, h = cell["tab_x"], cell["tab_y"], cell["tab_w"], cell["tab_h"]
    band = list(sample_band(cell, side, 40))
    chans = [[], [], []]
    for b in band[::3]:
        c = {"left": x + 10, "right": x + w - 11, "top": y + 10}[side]
        p, q = (b, c) if side == "top" else (c, b)
        if 0 <= p < W and 0 <= q < H:
            for k in range(3):
                chans[k].append(px[p, q][k])
    return tuple(median(ch) if ch else 0 for ch in chans)


def find_edge(px, size, cell, side, b, face, ground):
    """Where the ground starts on row (or column) `b`: the innermost pixel that is essentially all ground.

    Returns that coordinate (so `d = 1` IS it), or None when the row never reaches ground inside the
    search window — a row the caller leaves out rather than sampling a guess.
    """
    W, H = size
    x, y, w, h = cell["tab_x"], cell["tab_y"], cell["tab_w"], cell["tab_h"]
    nominal = {"left": x, "right": x + w - 1, "top": y}[side]
    out_sign = {"left": -1, "right": +1, "top": -1}[side]
    need = EDGE_GROUND * l1(ground, face)
    if need <= 0.0:
        return None
    for step in range(-4, EDGE_SEARCH):          # start just INSIDE, so a flared edge is caught either way
        c = nominal + out_sign * step
        p, q = (b, c) if side == "top" else (c, b)
        if not (0 <= p < W and 0 <= q < H):
            return None
        if l1(px[p, q], face) >= need:
            return c
    return None


def profile(img, cell, side, max_px, field, field_rgb, corner_skip):
    """Darkening at 1..max_px out from the tab's own edge, median over the band.

    Returns (rows, edges_found, edge_spread) — the last two are the honesty check on the first: a
    profile built from three rows, or from an edge that never moved on a flared tab, is not a
    measurement of anything.
    """
    px = img.load()
    size = img.size
    W, H = size
    out_sign = {"left": -1, "right": +1, "top": -1}[side]
    max_px = min(max_px, int(cell.get("real_ground", {}).get(side, max_px)))
    face = face_color(px, size, cell, side)
    edges = []
    for b in sample_band(cell, side, corner_skip):
        e = find_edge(px, size, cell, side, b, face, field_rgb)
        if e is not None:
            edges.append((b, e))
    rows = []
    for d in range(1, max_px + 1):
        vals = []
        for b, e in edges:
            c = e + out_sign * (d - 1)         # the edge finder's own pixel IS d = 1
            p, q = (b, c) if side == "top" else (c, b)
            if 0 <= p < W and 0 <= q < H:
                vals.append(luma(px[p, q]))
        if not vals:
            break
        rows.append((d, median(vals)))
    spread = (max(e for _, e in edges) - min(e for _, e in edges)) if edges else 0
    return [(d, v, 1.0 - v / field) for d, v in rows], len(edges), spread


def field_pixels(img, cells, side, max_px):
    """The sheet's own flat field: pixels well outside every tab's reach, and inside real ground."""
    px = img.load()
    W, H = img.size
    vals = []
    for c in cells:
        gap = (c["cell_w"] - c["tab_w"]) // 2
        room = gap
        if c["spec"].startswith("mock"):
            room = min(gap, int(c.get("real_ground", {}).get(side, gap)) + 1)
        for d in range(max_px + 6, room):
            for b in sample_band(c, side, 0):
                p = c["tab_x"] - d if side != "right" else c["tab_x"] + c["tab_w"] - 1 + d
                if 0 <= p < W and 0 <= b < H:
                    vals.append(px[p, b])
    if not vals:
        return 255.0, (255, 255, 255)
    return median([luma(v) for v in vals]), tuple(median([v[k] for v in vals]) for k in range(3))


def font(size):
    try:
        return ImageFont.load_default(size=size)      # Pillow >= 10.1 scales the built-in face
    except TypeError:
        return ImageFont.load_default()


def review_sheet(img, cells, side, prof, zoom, max_px, out_path):
    """1x cell · the same edge at `zoom` · the numbers, one column per cell."""
    n = len(cells)
    cw = max(c["cell_w"] for c in cells)
    strip_w, strip_h = max_px + 8, 46                 # the px window the zoom shows, in source px
    zw, zh = strip_w * zoom, strip_h * zoom
    col_w = max(cw, zw + 16)
    head, rows, line = 22, len(REPORT_AT) + 2, 15
    top_h = img.height
    total = Image.new("RGB", (col_w * n, top_h + head + zh + 14 + rows * line + 14), (250, 248, 244))
    d = ImageDraw.Draw(total)
    f, fb = font(12), font(13)

    for i, c in enumerate(cells):
        ox = i * col_w
        total.paste(img.crop((c["cell_x"], 0, c["cell_x"] + c["cell_w"], top_h)),
                    (ox + (col_w - c["cell_w"]) // 2, 0))
        ex = c["tab_x"] if side != "right" else c["tab_x"] + c["tab_w"]
        y0 = c["tab_y"] + c["tab_h"] // 2 - strip_h // 2
        x0 = ex - max_px - 4 if side != "right" else ex - 4
        cut = img.crop((x0, y0, x0 + strip_w, y0 + strip_h)).resize((zw, zh), Image.NEAREST)
        zy, zx = top_h + head, ox + (col_w - zw) // 2
        total.paste(cut, (zx, zy))
        d.rectangle([zx, zy, zx + zw - 1, zy + zh - 1], outline=(120, 120, 120))
        d.text((ox + 8, top_h + 5), "%s edge, %dx" % (side, zoom), font=f, fill=(40, 40, 40))
        ty = zy + zh + 10
        d.text((ox + 8, ty), "darkening out from the edge", font=fb, fill=(20, 20, 20))
        ty += line + 2
        table = dict((p[0], p[2]) for p in prof[i][0])
        for at in REPORT_AT:
            v = table.get(at)
            d.text((ox + 8, ty), "%3dpx   %s" % (at, ("%.3f" % v) if v is not None else "no ground"),
                   font=f, fill=(20, 20, 20))
            ty += line
        room = int(c.get("real_ground", {}).get(side, 10 ** 6))
        if room < max_px:
            # the numbers above are real but SHORT — say so ON the sheet, not only in the terminal, or
            # a cell whose ground ran out reads as a shadow that ended.
            d.text((ox + 8, ty + 3), "only %dpx of real ground here" % room, font=f, fill=(170, 40, 40))
    total.save(out_path)
    return out_path


def probe(img, spec, rows):
    """`label:x,y,dir,len` — the darkening along a horizontal ray, averaged over `rows` rows down from y.

    For the GLYPH's shadow rather than the tab's. A glyph shadow cannot be measured the way the tab's is:
    our glyph art and the mock's are different drawings, so there is no shared silhouette to step out
    from and no rect a tool could derive. The ray is therefore CHOSEN, by looking at the render, and
    named in the command — which is honest about being a hand-placed probe instead of dressing one up as
    a derived measurement. Its reference is the far end of its own ray: the clean paper face it lands on,
    so the darkening is relative to the very surface the shadow falls on.
    """
    label, rest = spec.split(":", 1)
    x, y, direction, length = (int(v) for v in rest.split(","))
    px = img.load()
    W, H = img.size
    series = []
    for d in range(length):
        vals = [luma(px[x + direction * d, y + r]) for r in range(rows)
                if 0 <= x + direction * d < W and 0 <= y + r < H]
        series.append(median(vals) if vals else 0.0)
    face = median(series[-5:])                 # the clean face at the far end of the ray
    return label, [(d, v, 1.0 - v / face) for d, v in enumerate(series)], face, (x, y, direction, length)


def probe_sheet(img, runs, rows, zoom, out_path):
    """One column per probe: the strip the ray crossed, zoomed, with its numbers under it."""
    f, fb = font(12), font(13)
    pads = 4
    cols = []
    for label, series, face, (x, y, direction, length) in runs:
        x0 = min(x, x + direction * (length - 1)) - pads
        cut = img.crop((x0, y - pads, x0 + length + pads * 2, y + rows + pads))
        cols.append((label, series, face, cut.resize((cut.width * zoom, cut.height * zoom), Image.NEAREST)))
    zw = max(c[3].width for c in cols)
    zh = max(c[3].height for c in cols)
    line, head = 15, 20
    n_rows = min(14, max(len(c[1]) for c in cols))
    total = Image.new("RGB", ((zw + 16) * len(cols), head + zh + 14 + (n_rows + 2) * line + 12),
                      (250, 248, 244))
    d = ImageDraw.Draw(total)
    for i, (label, series, face, cut) in enumerate(cols):
        ox = i * (zw + 16) + 8
        d.text((ox, 4), "%s  (face luma %.0f)" % (label, face), font=fb, fill=(20, 20, 20))
        total.paste(cut, (ox, head))
        d.rectangle([ox, head, ox + cut.width - 1, head + cut.height - 1], outline=(120, 120, 120))
        ty = head + zh + 12
        d.text((ox, ty), "darkening along the ray", font=fb, fill=(20, 20, 20))
        ty += line + 2
        for j in range(n_rows):
            d.text((ox, ty), "%3dpx   %.3f" % (series[j][0], series[j][2]), font=f, fill=(20, 20, 20))
            ty += line
    total.save(out_path)
    return out_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", required=True)
    ap.add_argument("--cells", default="",
                    help="the cells=[...] JSON navtab_shot printed, or a path to it "
                         "[default: <sheet>.json, written beside every capture]")
    ap.add_argument("--side", default="left", choices=("left", "right", "top"))
    ap.add_argument("--max", type=int, default=20)
    ap.add_argument("--corner-skip", type=int, default=34,
                    help="px of the tab's own corner arc to stay clear of when averaging")
    ap.add_argument("--zoom", type=int, default=6)
    ap.add_argument("--out", default="")
    ap.add_argument("--probe", action="append", default=[],
                    help="LABEL:x,y,dir,len — a hand-placed horizontal ray for the GLYPH's shadow "
                         "(repeatable). Prints instead of the tab-edge table.")
    ap.add_argument("--probe-rows", type=int, default=6)
    a = ap.parse_args()

    if a.probe:
        img = Image.open(a.sheet).convert("RGB")
        runs = [probe(img, s, a.probe_rows) for s in a.probe]
        print("sheet %s  %d probes, %d rows each" % (a.sheet, len(runs), a.probe_rows))
        print("%-5s" % "px" + "".join("  %-22s" % (r[0] + " face %.0f" % r[2])[:22] for r in runs))
        for d in range(max(len(r[1]) for r in runs)):
            row = "%-5d" % d
            for _, series, _, _ in runs:
                row += "  %-22s" % (("%.3f" % series[d][2]) if d < len(series) else "-")
            print(row)
        if a.out:
            print("REVIEW %s" % probe_sheet(img, runs, a.probe_rows, a.zoom, a.out))
        return 0

    src = a.cells or (a.sheet + ".json")
    cells = json.loads(src if src.lstrip().startswith("[") else open(src).read())
    img = Image.open(a.sheet).convert("RGB")
    field, field_rgb = field_pixels(img, cells, a.side, a.max)
    prof = [profile(img, c, a.side, a.max, field, field_rgb, a.corner_skip) for c in cells]

    print("sheet %s  %dx%d  side=%s  flat-field luma %.1f rgb%s"
          % (a.sheet, img.width, img.height, a.side, field, str(field_rgb)))
    hdr = "%-5s" % "px"
    for c in cells:
        hdr += "  %-26s" % name(c)[:26]
    print(hdr)
    for at in REPORT_AT:
        row = "%-5d" % at
        for p, _, _ in prof:
            t = dict((q[0], q[2]) for q in p)
            row += "  %-26s" % (("%.3f" % t[at]) if at in t else "(no ground)")
        print(row)
    for c, (_, found, spread) in zip(cells, prof):
        room = int(c.get("real_ground", {}).get(a.side, a.max))
        note = "  ONLY %dpx of real ground — nothing reported past it" % room if room < a.max else ""
        print("  %-26s edge tracked on %d rows, moving %dpx across them (the flare)%s"
              % (name(c)[:26], found, spread, note))
    if a.out:
        print("REVIEW %s" % review_sheet(img, cells, a.side, prof, a.zoom, a.max, a.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
