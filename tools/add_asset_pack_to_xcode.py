#!/usr/bin/env python3
"""Add grove_assets.pck to the generated Xcode project so it lands in the .app bundle.

Godot writes the Xcode project from its own template and knows nothing about our second
pack, so the four references the main pack gets have to be mirrored for ours. Rather than
inventing pbxproj structure, this copies the exact shape Godot already uses for
AcornForest.pck: a PBXBuildFile, a PBXFileReference, a group child, and a Resources
build-phase entry.

Idempotent — re-running on an already-patched project changes nothing, so it is safe in a
Makefile that may run twice.

usage: add_asset_pack_to_xcode.py <project.pbxproj> [pack-filename]
"""
import re
import sys

# Deterministic 24-hex object ids. Godot's own ids are a fixed template, so a fixed pair
# here cannot collide across runs and keeps the pbxproj diff stable build to build.
BUILD_FILE_ID = "AC0F0E5701000000000000A1"
FILE_REF_ID = "AC0F0E5701000000000000A2"


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else sys.exit(__doc__)
    pack = sys.argv[2] if len(sys.argv) > 2 else "grove_assets.pck"
    src = open(path, encoding="utf-8").read()

    if pack in src:
        print(f"add_asset_pack_to_xcode: {pack} already referenced — nothing to do")
        return 0

    # Anchor on the main pack's own entries; if Godot's template ever changes shape, this
    # fails loudly instead of writing a subtly broken project.
    anchors = {
        "build": re.search(r"^(\t*)(\S+) /\* (\S+\.pck) in Resources \*/ = \{isa = PBXBuildFile;.*$",
                           src, re.M),
        "ref": re.search(r"^(\t*)(\S+) /\* (\S+\.pck) \*/ = \{isa = PBXFileReference;.*$", src, re.M),
        "child": re.search(r"^(\t*)(\S+) /\* (\S+\.pck) \*/,\s*$", src, re.M),
        "phase": re.search(r"^(\t*)(\S+) /\* (\S+\.pck) in Resources \*/,\s*$", src, re.M),
    }
    missing = [k for k, v in anchors.items() if not v]
    if missing:
        print(f"add_asset_pack_to_xcode: could not find the main pack's {missing} entry in "
              f"{path} — Godot's Xcode template changed; update this script.", file=sys.stderr)
        return 1

    out = src
    b = anchors["build"]
    out = out.replace(b.group(0), b.group(0) + "\n" + f"{b.group(1)}{BUILD_FILE_ID} /* {pack} in "
                      f"Resources */ = {{isa = PBXBuildFile; fileRef = {FILE_REF_ID} /* {pack} */; }};", 1)
    r = anchors["ref"]
    out = out.replace(r.group(0), r.group(0) + "\n" + f'{r.group(1)}{FILE_REF_ID} /* {pack} */ = '
                      f'{{isa = PBXFileReference; lastKnownFileType = file; path = "{pack}"; '
                      f'sourceTree = "<group>"; }};', 1)
    c = anchors["child"]
    out = out.replace(c.group(0), c.group(0) + "\n" + f"{c.group(1)}{FILE_REF_ID} /* {pack} */,", 1)
    p = anchors["phase"]
    out = out.replace(p.group(0), p.group(0) + "\n" + f"{p.group(1)}{BUILD_FILE_ID} /* {pack} in "
                      f"Resources */,", 1)

    if out == src:
        print("add_asset_pack_to_xcode: no substitution applied", file=sys.stderr)
        return 1
    open(path, "w", encoding="utf-8").write(out)
    print(f"add_asset_pack_to_xcode: added {pack} to {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
