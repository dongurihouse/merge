#!/usr/bin/env bash
# Export the art/audio pack (grove_assets.pck) that ships alongside the main pack.
#
# The main "iOS" preset excludes games/grove/assets/**, so its pack is just code + data
# (~6 MB) and is rewritten on every build. This script builds the other half: the art and
# audio (~56 MB), which stays byte-identical between code-only releases so Xcode's
# incremental install and Apple's update delta can skip it. boot.gd mounts it at startup.
#
# Why a GENERATED preset instead of a committed one: "assets only" cannot be written as a
# glob. The bytes that matter are the imported .ctex under res://.godot/imported/, whose
# paths look nothing like their sources, so Godot needs an explicit resource list and pulls
# each source's .ctex in as a dependency. Deriving that list from the filesystem on every
# export is the only version that cannot silently go stale — a committed list would drift
# the moment art is added, and the failure mode is shipping without art.
#
# The preset is appended to export_presets.cfg, used, and removed again; the trap restores
# the file even if Godot fails.
set -euo pipefail

PROJECT="${1:?usage: export_asset_pack.sh <project-dir> <out.pck>}"
OUT="${2:?usage: export_asset_pack.sh <project-dir> <out.pck>}"
GODOT="${GODOT:-godot}"
CFG="$PROJECT/export_presets.cfg"
PRESET_NAME="iOS Assets"

[ -f "$CFG" ] || { echo "export_asset_pack: no $CFG" >&2; exit 1; }
BACKUP="$(mktemp)"
cp "$CFG" "$BACKUP"
trap 'cp "$BACKUP" "$CFG"; rm -f "$BACKUP"' EXIT

python3 - "$PROJECT" "$CFG" "$PRESET_NAME" <<'PY'
import os, re, sys
project, cfg, preset_name = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(cfg).read()

# The same rules the exporter itself applies, read straight from the preset so the two
# can never disagree: skip .gdignore subtrees and anything the exclude_filter drops.
ASSETS = "games/grove/assets"
m = re.search(r'^exclude_filter="([^"]*)"', text, re.M)
prefixes = []
for pat in (m.group(1).split(",") if m else []):
    pat = pat.strip()
    # The main preset excludes the whole asset tree so its pack stays code-only. That entry
    # is an artifact of the split, not a "never ship this" rule — honouring it here would
    # select zero files and build an empty pack.
    if pat == ASSETS + "/**":
        continue
    if pat.endswith("/**"):
        p = pat[:-3]
        if "*" not in p:                       # literal dir prefix; globs handled below
            prefixes.append(p)

def excluded(rel):
    if any(rel == p or rel.startswith(p + "/") for p in prefixes):
        return True
    # the one glob form actually in use: games/grove/assets/map/*/reference/**
    return "/reference/" in rel or rel.endswith("/reference")

files = []
for dp, dn, fn in os.walk(os.path.join(project, ASSETS)):
    if ".gdignore" in fn:
        dn[:] = []
        continue
    rel_dir = os.path.relpath(dp, project).replace("\\", "/")
    if excluded(rel_dir):
        dn[:] = []
        continue
    for f in fn:
        if f.endswith(".import"):              # Godot pulls these in with their source
            continue
        rel = os.path.relpath(os.path.join(dp, f), project).replace("\\", "/")
        if not excluded(rel):
            files.append("res://" + rel)
files.sort()
if not files:
    sys.exit("export_asset_pack: found no asset files — refusing to build an empty pack")

# Clone preset.0's shape so platform/bundle options stay identical, then switch it to an
# explicit resource list. Critically, drop the assets exclusion the main preset carries —
# otherwise this pack would exclude the very files it exists to hold.
head, opts = text.split("[preset.0.options]", 1)
body = head.split("[preset.0]", 1)[1]
body = re.sub(r'^name="[^"]*"', 'name="%s"' % preset_name, body, flags=re.M)
body = re.sub(r'^export_filter="[^"]*"', 'export_filter="resources"', body, flags=re.M)
body = re.sub(r'^export_path="[^"]*"', 'export_path=""', body, flags=re.M)
ex = re.search(r'^exclude_filter="([^"]*)"', body, re.M)
if ex:
    kept = [p for p in ex.group(1).split(",") if p.strip() != ASSETS + "/**"]
    body = re.sub(r'^exclude_filter="[^"]*"',
                  'exclude_filter="%s"' % ",".join(kept), body, flags=re.M)
arr = "export_files=PackedStringArray(%s)" % ",".join('"%s"' % f for f in files)
if re.search(r'^export_files=', body, re.M):
    body = re.sub(r'^export_files=PackedStringArray\([^)]*\)', arr, body, flags=re.M)
else:
    body = body.replace('export_filter="resources"', 'export_filter="resources"\n' + arr, 1)

open(cfg, "w").write(text + "\n[preset.%d]" % 1 + body + "\n[preset.1.options]" + opts)
print("export_asset_pack: selected %d asset files" % len(files))
PY

mkdir -p "$(dirname "$OUT")"
"$GODOT" --headless --path "$PROJECT" --export-pack "$PRESET_NAME" "$OUT"

[ -s "$OUT" ] || { echo "export_asset_pack: $OUT was not written" >&2; exit 1; }
echo "export_asset_pack: wrote $OUT ($(du -h "$OUT" | cut -f1))"
