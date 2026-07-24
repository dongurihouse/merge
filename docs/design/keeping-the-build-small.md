# Keeping the iOS build small

The app went from 274.7 MB installed to ~158 MB, almost entirely by storing textures
compressed instead of lossless, and the shipped content is now split so a code-only update
downloads a few MB instead of the whole game. This note is what keeps it that way. Most of
it is now automatic; the short list of things a human still has to get right is at the top.

## What a human must not break

1. **Do not remove `[importer_defaults]` from `project.godot`.** It makes every new texture
   import as lossy WebP (`compress/mode=1`, `lossy_quality=0.9`). Without it, new art
   imports lossless and silently re-inflates the pack — exactly how the original 522
   textures grew the build to 176.7 MB.

2. **Do not pin a texture to `compress/mode=0` (Lossless) without a real reason.** If an
   asset genuinely needs it (a data mask, a normal map, hard-edged pixel art), set the mode
   on that one `.import` AND add its source path to `LOSSLESS_ALLOWLIST` in
   `engine/tests/asset_size_guard_tests.gd`, with the reason. The guard fails the build
   otherwise — that is intentional.

3. **Keep working/source art out of the shipped tree.** Concept art, originals, montages,
   and review renders must live under a directory the export drops: either a `.gdignore`
   subtree (`_originals`, `_new`, `_archive`, `map/*/shared`) or an `exclude_filter` prefix
   in `export_presets.cfg` (`_concepts`, `_review`, `map/*/reference`). New scratch art goes
   in one of those, never loose under a shipping path.

Everything below is handled by tooling and needs no attention unless it breaks.

## What is automatic

**New textures compress themselves.** `[importer_defaults]` → lossy WebP on import. VRAM
cost is unchanged (mode 0 and mode 1 both decode to RGBA8 on the GPU); this is a download
saving only. Verified: dropping a fresh PNG in and reimporting produces `compress/mode=1`
with no manual step.

**The guard enforces it.** `engine/tests/asset_size_guard_tests.gd` runs in `make test`.
It walks the shipped texture set — the same definition the exporter uses (under
`games/grove/assets`, not in a `.gdignore` subtree, not dropped by `exclude_filter`) — and
fails if any texture ships lossless. It reads the real `exclude_filter` from
`export_presets.cfg`, so the guard and the export cannot silently disagree.

**The split rebuilds itself.** `make ios` produces two packs:

- `AcornForest.pck` — code + data, ~5 MB, rewritten every build.
- `grove_assets.pck` — art + audio, ~56 MB, **byte-identical between builds when art is
  unchanged** (verified: two exports with no art change are `cmp`-identical).

`tools/export_asset_pack.sh` derives the asset file list from the filesystem on every
export — nothing to maintain by hand, and it refuses to build an empty pack.
`tools/add_asset_pack_to_xcode.py` wires the second pack into the generated Xcode project.
`boot.gd` mounts it at startup, before any art loads.

Because the asset pack is byte-stable, a release that only changed code re-downloads ~5 MB,
not 57 MB — both for App Store update deltas and for on-device dev installs. If you *did*
change art, that pack changes and ships in full; that is expected and unavoidable.

**Release builds ship the release template.** `make release-ios` passes
`IOS_EXPORT_MODE=release`; a bare `make ios` stays debug for on-device iteration. (This is a
correctness fix — a debug template carries the remote debugger — not a size lever; the
stripped binaries differ by ~68 KB.)

## Known limits, deliberately not fixed

- **The boot splash is a 3.41 MB PNG and Godot force-exports it into every pack** (it
  rejects any non-PNG splash outright: "The only supported format is PNG"). It is therefore
  duplicated across both packs, costing ~3.6 MB of install. Shrinking it is a
  resolution-only, visual-quality call; left at full size by choice.
- **The 1024×1024 app icon** is kept out of the pack via a 128px `config/icon` stand-in
  plus an explicit `icons/icon_1024x1024`; the App Store icon is unaffected.

## If the build grows again, measure the pack, not the source

Source art on disk is not what ships. To see what actually ships, parse the pack directly
(`.godot/imported/*.ctex` entries are the textures) rather than reasoning from source PNG
sizes or a stale prior build. See the analysis in
`docs/superpowers/specs/2026-07-23-app-size-and-update-speed-design.md`.
