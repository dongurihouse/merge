#!/usr/bin/env python3
"""Measure — and then SHOW — the darkening beside each element on a mock_compare_shot.gd sheet.

mock_compare_shot.gd puts one of our UI elements and the concept mock's own on ONE sheet: same flat
field, same scale, and (with `fill=`) the same face colour, so the only thing left varying between two
cells is the thing under test. This reads that sheet back. The method, and the wrong conclusion each
rule prevents, is docs/design/verifying-against-a-mock.md.

  python3 games/grove/tools/mock_profile.py --sheet /tmp/nav.png --side left --out /tmp/nav_review.png
  python3 games/grove/tools/mock_profile.py --sheet /tmp/pill.png --side right --vs mock

The cell rects, the flat field and the mock's own grain sigma come from `<sheet>.json`, which
mock_compare_shot writes beside every capture (`--cells` takes a path or the literal JSON instead).

For each cell it steps outward from the element's own edge and reports the DARKENING
(1 - sampled_luma / field_luma) at each pixel. The field luma is ONE number for the whole sheet — the
flat field the tool painted, which is by construction the mean of the mock's own background — so a
darkening on one cell means the same thing as a darkening on the next. That is the property every
naive comparison lacks: darkening inferred from a luma ratio is a function of the ground it falls on.

FOUR THINGS THIS REFUSES TO DO, because each of them silently produces a believable wrong number:

  * MEASURE OFF A NOMINAL EDGE. A tapered or flared element's edge moves several px across the rows a
    profile averages over. Sampling one fixed column and taking the median smears the taper into a
    slope that is a property of the taper, not of the shadow (measured on a nav tab: it turned a flat
    contact plateau into a decay, and the tuning read off it was wrong). Every row finds the element's
    own edge first and steps out from THAT.
  * REPORT WHERE THERE IS NO GROUND. A mock cell crops concept art and the concept art runs out — 24px
    of sky beside one nav tab, 10px before the next. Past that the cell is flat field, which profiles
    as a perfect 0.000 and reads as "the shadow ended here". `real_ground` bounds every profile.
  * CALL A SHEET DONE WITHOUT A NOISE FLOOR. `--vs` scores rms against a reference cell and prints it
    against the mock's OWN paper grain. Below the grain there is nothing left to measure, and a
    further tuning round is fitting noise.
  * TRUST A GRAIN NUMBER FROM A BOX THAT SPANS STRUCTURE. Every field sample is reported with its
    low-frequency RANGE (blur, then the worst max-min over a 24px tile). Clean sky reads single
    figures; a box that has swallowed an element edge or an icon reads tens to hundreds, and the grain
    read off it is wrong by a multiple, not by a rounding.

`--out` writes a review sheet: each cell at 1x, the same edge zoomed `--zoom` times so the falloff is
actually visible, and the numbers under it. LOOK at that file; the numbers alone are not the check.
"""

import argparse
import json
import sys

from PIL import Image, ImageDraw, ImageFont

# Rec.601 luma — the same weighting every shadow measurement in this project has used.
LUMA = (0.299, 0.587, 0.114)
# Distances (px out from the element's edge) printed under each cell.
REPORT_AT = (1, 2, 3, 4, 6, 8, 10, 12, 16)
# How far either side of the nominal edge the per-row edge finder looks. Wide enough for a taper's full
# run and for a rect measured a pixel or two off, tight enough that it can never wander onto the
# element's own content or the neighbouring one.
EDGE_SEARCH = 14
# How far from the element's FACE colour, as a fraction of the whole face->field distance, a pixel must
# be before it counts as ground rather than as part of the edge. Both a painted arc and our own
# `edge_feather` blend face into ground over a pixel or two, and "the largest colour step" lands
# ANYWHERE inside that blend depending on how it happens to fall — measured, it moved our whole profile
# by a pixel against the mock's, which at 1-2px out is the entire contact reading. `d = 1` is instead
# the first pixel carrying no more than 1 - EDGE_GROUND of the face, which is the same physical place
# on any edge however it is antialiased.
EDGE_GROUND = 0.85
# The flatness diagnostic: box-blur radius, the tile the range is taken over, and the range above which
# a sample box is reported as spanning STRUCTURE rather than field. CALIBRATED, not assumed: on
# palette_a_meadow_sky_board.png the declared field patches — genuinely empty sky — read 3.4 to 7.9,
# and a patch slid onto a nav tab reads 144. The limit sits above the first band and an order of
# magnitude under the second. Re-measure it against a known positive before moving it.
FLAT_BLUR = 3
FLAT_WINDOW = 24
FLAT_LIMIT = 12.0

SIDES = ("left", "right", "top", "bottom")
# Which way "outward" is, per side, and whether the profile walks along x (vertical edges) or y.
OUT_SIGN = {"left": -1, "right": +1, "top": -1, "bottom": +1}
VERTICAL_EDGE = {"left": True, "right": True, "top": False, "bottom": False}


def luma(px):
    return LUMA[0] * px[0] + LUMA[1] * px[1] + LUMA[2] * px[2]


def median(xs):
    s = sorted(xs)
    n = len(s)
    return s[n // 2] if n % 2 else 0.5 * (s[n // 2 - 1] + s[n // 2])


def name(cell):
    """What a column is CALLED: the label mock_compare_shot gave it, else its raw spec."""
    return cell.get("label") or cell["spec"]


def face(cell):
    return cell["face_x"], cell["face_y"], cell["face_w"], cell["face_h"]


def at(px, side, along, across):
    """One pixel, in the (along the edge, across it) frame the whole module works in."""
    return px[across, along] if VERTICAL_EDGE[side] else px[along, across]


def inside(size, side, along, across):
    W, H = size
    p, q = (across, along) if VERTICAL_EDGE[side] else (along, across)
    return 0 <= p < W and 0 <= q < H


def sample_band(cell, side, corner_skip):
    """The rows (or columns) a profile is averaged over: the element's flat edge, clear of its corners."""
    x, y, w, h = face(cell)
    if VERTICAL_EDGE[side]:
        # a bottom-bleeding element has no bottom corner on the sheet, so its band runs to the edge
        end = y + h if cell.get("bleed_bottom") else y + h - corner_skip
        return range(y + corner_skip, max(y + corner_skip + 1, end))
    return range(x + corner_skip, x + w - corner_skip)


def nominal_edge(cell, side):
    x, y, w, h = face(cell)
    return {"left": x, "right": x + w - 1, "top": y, "bottom": y + h - 1}[side]


def l1(p, q):
    return abs(p[0] - q[0]) + abs(p[1] - q[1]) + abs(p[2] - q[2])


def face_color(px, size, cell, side):
    """The element's own face, sampled well inside its edge — what the edge finder walks away from."""
    x, y, w, h = face(cell)
    inset = {"left": x + 10, "right": x + w - 11, "top": y + 10, "bottom": y + h - 11}[side]
    band = list(sample_band(cell, side, 40)) or list(sample_band(cell, side, 4))
    chans = [[], [], []]
    for b in band[::3]:
        if inside(size, side, b, inset):
            for k in range(3):
                chans[k].append(at(px, side, b, inset)[k])
    return tuple(median(ch) if ch else 0 for ch in chans)


def find_edge(px, size, cell, side, b, face_rgb, ground):
    """Where the ground starts on row (or column) `b`: the innermost pixel that is essentially all ground.

    Returns that coordinate (so `d = 1` IS it), or None when the row never reaches ground inside the
    search window — a row the caller leaves out rather than sampling a guess.
    """
    nominal = nominal_edge(cell, side)
    out_sign = OUT_SIGN[side]
    need = EDGE_GROUND * l1(ground, face_rgb)
    if need <= 0.0:
        return None
    for step in range(-4, EDGE_SEARCH):      # start just INSIDE, so a tapered edge is caught either way
        c = nominal + out_sign * step
        if not inside(size, side, b, c):
            return None
        if l1(at(px, side, b, c), face_rgb) >= need:
            return c
    return None


def profile(img, cell, side, max_px, field, field_rgb, corner_skip):
    """Darkening at 1..max_px out from the element's own edge, median over the band.

    Returns (rows, edges_found, edge_spread) — the last two are the honesty check on the first: a
    profile built from three rows, or from an edge that never moved on a tapered element, is not a
    measurement of anything.
    """
    px = img.load()
    size = img.size
    out_sign = OUT_SIGN[side]
    max_px = min(max_px, int(cell.get("real_ground", {}).get(side, max_px)))
    face_rgb = face_color(px, size, cell, side)
    edges = []
    for b in sample_band(cell, side, corner_skip):
        e = find_edge(px, size, cell, side, b, face_rgb, field_rgb)
        if e is not None:
            edges.append((b, e))
    rows = []
    for d in range(1, max_px + 1):
        vals = []
        for b, e in edges:
            c = e + out_sign * (d - 1)       # the edge finder's own pixel IS d = 1
            if inside(size, side, b, c):
                vals.append(luma(at(px, side, b, c)))
        if not vals:
            break
        rows.append((d, median(vals)))
    spread = (max(e for _, e in edges) - min(e for _, e in edges)) if edges else 0
    return [(d, v, 1.0 - v / field) for d, v in rows], len(edges), spread


def ground_box(cell, side, max_px):
    """The strip of a cell treated as CLEAN field: past every shadow in play, inside real ground."""
    x, y, w, h = face(cell)
    gap = (cell["cell_w"] - w) // 2
    room = gap
    if cell.get("is_mock"):
        room = min(gap, int(cell.get("real_ground", {}).get(side, gap)) + 1)
    lo, hi = max_px + 6, room
    if hi <= lo:
        return None
    edge = nominal_edge(cell, side)
    band = sample_band(cell, side, 0)
    a0, a1 = min(band), max(band) + 1
    # both directions cover the same DISTANCES out from the edge pixel, lo..hi-1 — hence the +1 on the
    # side that counts downward. Off by one here shifts the field luma every darkening is divided by.
    c0, c1 = (edge - hi + 1, edge - lo + 1) if OUT_SIGN[side] < 0 else (edge + lo, edge + hi)
    return (c0, a0, c1, a1) if VERTICAL_EDGE[side] else (a0, c0, a1, c1)


def flat_range(img, box):
    """Low-frequency range of luma inside `box`: box-blur, then the worst max-min over a FLAT_WINDOW tile.

    The diagnostic that says whether a sample box measured FIELD or STRUCTURE. Under FLAT_LIMIT the box
    is clean paper; a box that has swallowed an element edge or an icon reads tens, and any grain or
    noise number taken from it is wrong by a multiple, not by a rounding.

    Measured LOCALLY, in tiles, and not end to end: the mock's sky carries a slow gradient, so a 128px
    strip of genuinely empty sky reads 7 across its whole length while a 24px window of it reads 3. End
    to end, every honest patch on this mock fails and the diagnostic gets ignored. Tiled, the same
    patches read 2-3 and a patch laid over a nav tab reads 144.
    """
    x0, y0, x1, y1 = box
    W, H = img.size
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(W, x1), min(H, y1)
    if x1 - x0 < 2 * FLAT_BLUR + 1 or y1 - y0 < 2 * FLAT_BLUR + 1:
        return None
    px = img.load()
    vals = [[luma(px[x, y]) for x in range(x0, x1)] for y in range(y0, y1)]
    n = 2 * FLAT_BLUR + 1
    blur = []
    for j in range(FLAT_BLUR, len(vals) - FLAT_BLUR):
        row = []
        for i in range(FLAT_BLUR, len(vals[0]) - FLAT_BLUR):
            s = 0.0
            for dj in range(-FLAT_BLUR, FLAT_BLUR + 1):
                for di in range(-FLAT_BLUR, FLAT_BLUR + 1):
                    s += vals[j + dj][i + di]
            row.append(s / float(n * n))
        blur.append(row)
    if not blur or not blur[0]:
        return None
    worst = 0.0
    for j0 in range(0, len(blur), FLAT_WINDOW):
        for i0 in range(0, len(blur[0]), FLAT_WINDOW):
            tile = [v for row in blur[j0:j0 + FLAT_WINDOW] for v in row[i0:i0 + FLAT_WINDOW]]
            worst = max(worst, max(tile) - min(tile))
    return worst


def field_pixels(img, cells, side, max_px):
    """The sheet's own flat field, plus each cell's flatness diagnostic for the box it was read from."""
    px = img.load()
    vals = []
    flats = {}
    for i, c in enumerate(cells):
        box = ground_box(c, side, max_px)
        flats[i] = None if box is None else flat_range(img, box)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        for x in range(max(0, x0), min(img.width, x1)):
            for y in range(max(0, y0), min(img.height, y1)):
                vals.append(px[x, y])
    if not vals:
        return 255.0, (255, 255, 255), flats
    return (median([luma(v) for v in vals]),
            tuple(median([v[k] for v in vals]) for k in range(3)), flats)


def pick(cells, wanted):
    """The cell `--vs` names: an index, or a substring of exactly one cell's label or spec."""
    if wanted.isdigit():
        return int(wanted)
    hits = [i for i, c in enumerate(cells) if wanted in name(c) or wanted in c["spec"]]
    if len(hits) != 1:
        raise SystemExit("--vs %r matches %d cells (%s) — name one exactly"
                         % (wanted, len(hits), ", ".join(name(cells[i]) for i in hits)))
    return hits[0]


def score(prof, ref_i, cells):
    """rms of each cell against the reference, over the distances BOTH of them really measured.

    This is the only honest answer to "is it close enough". Fitting past the reference's own paper
    grain is fitting noise — the render cannot show a difference the reference does not carry.
    """
    ref = dict((p[0], p[2]) for p in prof[ref_i][0])
    out = []
    for i, c in enumerate(cells):
        if i == ref_i:
            continue
        mine = dict((p[0], p[2]) for p in prof[i][0])
        shared = sorted(set(ref) & set(mine))
        if not shared:
            out.append((i, None, 0))
            continue
        rms = (sum((mine[d] - ref[d]) ** 2 for d in shared) / len(shared)) ** 0.5
        out.append((i, rms, len(shared)))
    return out


def font(size):
    try:
        return ImageFont.load_default(size=size)      # Pillow >= 10.1 scales the built-in face
    except TypeError:
        return ImageFont.load_default()


def review_sheet(img, cells, side, prof, zoom, max_px, out_path):
    """1x cell · the same edge at `zoom` · the numbers, one column per cell."""
    n = len(cells)
    cw = max(c["cell_w"] for c in cells)
    strip_a, strip_c = 46, max_px + 8                 # along the edge, across it (source px)
    if VERTICAL_EDGE[side]:
        cut_w, cut_h = strip_c, strip_a
    else:
        cut_w, cut_h = strip_a, strip_c
    zw, zh = cut_w * zoom, cut_h * zoom
    col_w = max(cw, zw + 16)
    head, rows, line = 22, len(REPORT_AT) + 2, 15
    top_h = img.height
    total = Image.new("RGB", (col_w * n, top_h + head + zh + 14 + rows * line + 18), (250, 248, 244))
    d = ImageDraw.Draw(total)
    f, fb = font(12), font(13)

    for i, c in enumerate(cells):
        ox = i * col_w
        total.paste(img.crop((c["cell_x"], 0, c["cell_x"] + c["cell_w"], top_h)),
                    (ox + (col_w - c["cell_w"]) // 2, 0))
        x, y, w, h = face(c)
        e = nominal_edge(c, side)
        if VERTICAL_EDGE[side]:
            c0 = e - max_px - 4 if side == "left" else e - 4
            a0 = y + h // 2 - strip_a // 2
            crop = (c0, a0, c0 + strip_c, a0 + strip_a)
        else:
            c0 = e - max_px - 4 if side == "top" else e - 4
            a0 = x + w // 2 - strip_a // 2
            crop = (a0, c0, a0 + strip_a, c0 + strip_c)
        cut = img.crop(crop).resize((zw, zh), Image.NEAREST)
        zy, zx = top_h + head, ox + (col_w - zw) // 2
        total.paste(cut, (zx, zy))
        d.rectangle([zx, zy, zx + zw - 1, zy + zh - 1], outline=(120, 120, 120))
        d.text((ox + 8, top_h + 5), "%s edge, %dx" % (side, zoom), font=f, fill=(40, 40, 40))
        ty = zy + zh + 10
        d.text((ox + 8, ty), "darkening out from the edge", font=fb, fill=(20, 20, 20))
        ty += line + 2
        table = dict((p[0], p[2]) for p in prof[i][0])
        for a in REPORT_AT:
            v = table.get(a)
            d.text((ox + 8, ty), "%3dpx   %s" % (a, ("%.3f" % v) if v is not None else "no ground"),
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

    For a shadow INSIDE an element (a glyph's own pool) rather than the one it casts. That cannot be
    measured the way an edge is: our art and the mock's are different drawings, so there is no shared
    silhouette to step out from and no rect a tool could derive. The ray is therefore CHOSEN, by
    looking at the render, and named in the command — which is honest about being a hand-placed probe
    instead of dressing one up as a derived measurement. Its reference is the far end of its own ray:
    the clean face it lands on, so the darkening is relative to the surface the shadow falls on.
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
    ref = median(series[-5:])                  # the clean face at the far end of the ray
    return label, [(d, v, 1.0 - v / ref) for d, v in enumerate(series)], ref, (x, y, direction, length)


def probe_sheet(img, runs, rows, zoom, out_path):
    """One column per probe: the strip the ray crossed, zoomed, with its numbers under it."""
    f, fb = font(12), font(13)
    pads = 4
    cols = []
    for label, series, ref, (x, y, direction, length) in runs:
        x0 = min(x, x + direction * (length - 1)) - pads
        cut = img.crop((x0, y - pads, x0 + length + pads * 2, y + rows + pads))
        cols.append((label, series, ref, cut.resize((cut.width * zoom, cut.height * zoom), Image.NEAREST)))
    zw = max(c[3].width for c in cols)
    zh = max(c[3].height for c in cols)
    line, head = 15, 20
    n_rows = min(14, max(len(c[1]) for c in cols))
    total = Image.new("RGB", ((zw + 16) * len(cols), head + zh + 14 + (n_rows + 2) * line + 12),
                      (250, 248, 244))
    d = ImageDraw.Draw(total)
    for i, (label, series, ref, cut) in enumerate(cols):
        ox = i * (zw + 16) + 8
        d.text((ox, 4), "%s  (face luma %.0f)" % (label, ref), font=fb, fill=(20, 20, 20))
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


def load_sidecar(a):
    src = a.cells or (a.sheet + ".json")
    raw = json.loads(src if src.lstrip().startswith(("[", "{")) else open(src).read())
    if isinstance(raw, dict):
        return raw.get("cells", []), raw.get("field", {})
    return raw, {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", required=True)
    ap.add_argument("--cells", default="",
                    help="the sidecar mock_compare_shot wrote, or the literal JSON "
                         "[default: <sheet>.json, written beside every capture]")
    ap.add_argument("--side", default="left", choices=SIDES)
    ap.add_argument("--max", type=int, default=20)
    ap.add_argument("--corner-skip", type=int, default=34,
                    help="px of the element's own corner arc to stay clear of when averaging")
    ap.add_argument("--zoom", type=int, default=6)
    ap.add_argument("--out", default="")
    ap.add_argument("--vs", default="",
                    help="score every other cell's rms against this one (index, or a substring of its "
                         "label) and print it against the mock's own paper grain")
    ap.add_argument("--probe", action="append", default=[],
                    help="LABEL:x,y,dir,len — a hand-placed horizontal ray for a shadow INSIDE an "
                         "element (repeatable). Prints instead of the edge table.")
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

    cells, field_meta = load_sidecar(a)
    if not cells:
        raise SystemExit("no cells in the sidecar — mock_compare_shot writes one beside every capture")
    img = Image.open(a.sheet).convert("RGB")
    field, field_rgb, flats = field_pixels(img, cells, a.side, a.max)
    prof = [profile(img, c, a.side, a.max, field, field_rgb, a.corner_skip) for c in cells]

    print("sheet %s  %dx%d  side=%s  flat-field luma %.1f rgb%s"
          % (a.sheet, img.width, img.height, a.side, field, str(field_rgb)))
    hdr = "%-5s" % "px"
    for c in cells:
        hdr += "  %-26s" % name(c)[:26]
    print(hdr)
    for d in REPORT_AT:
        row = "%-5d" % d
        for p, _, _ in prof:
            t = dict((q[0], q[2]) for q in p)
            row += "  %-26s" % (("%.3f" % t[d]) if d in t else "(no ground)")
        print(row)
    for i, (c, (_, found, spread)) in enumerate(zip(cells, prof)):
        room = int(c.get("real_ground", {}).get(a.side, a.max))
        note = "  ONLY %dpx of real ground — nothing reported past it" % room if room < a.max else ""
        print("  %-26s edge tracked on %d rows, moving %dpx across them (the taper)%s"
              % (name(c)[:26], found, spread, note))
        fr = flats.get(i)
        if fr is None:
            print("      no clean field box on this side — the flatness of the sample is unchecked")
        else:
            print("      field sample low-frequency range %.1f%s" % (
                fr, "" if fr <= FLAT_LIMIT else "  <-- SPANS STRUCTURE, not field: any grain or noise"
                    " number from this box is wrong by a multiple"))

    if a.vs:
        ref_i = pick(cells, a.vs)
        floor = float(field_meta.get("sigma", 0.0)) / field if field else 0.0
        rows = score(prof, ref_i, cells)
        print("  --- rms against %s (its own paper grain = %.3f) ---" % (name(cells[ref_i]), floor))
        for i, rms, n in rows:
            if rms is None:
                print("  %-26s no overlapping ground with the reference" % name(cells[i])[:26])
                continue
            verdict = ("at the reference's own grain — further tuning is unmeasurable"
                       if floor > 0 and rms <= floor else
                       "%.1fx the reference's grain" % (rms / floor) if floor > 0 else "")
            print("  %-26s rms %.3f over %2dpx   %s" % (name(cells[i])[:26], rms, n, verdict))
    if a.out:
        print("REVIEW %s" % review_sheet(img, cells, a.side, prof, a.zoom, a.max, a.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
