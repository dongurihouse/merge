# App size reduction and update speed — design

Date: 2026-07-23
Branch: `app-size-reduction`

## Problem

The shipped iOS build is 262 MB installed. Two consequences:

1. It sits above Apple's cellular-download cap, so a meaningful share of installs stall
   at "connect to Wi-Fi" instead of completing.
2. Every update ships as effectively a full re-download, because all game content lives
   in one monolithic `.pck` whose bytes shift on any change.

## Goals

- Cut installed size substantially, with image quality held to an evidence-based bar.
- Cut the size of a code-only update by an order of magnitude or more.

## Non-goals

- On-demand resources, CDN-hosted packs, or any over-the-air content delivery.
- Re-authoring or re-cutting art. This is an encoding and packaging change only.
- Renderer changes.

## Measured baseline

Taken from the real artifacts: `build/ios/AcornForest.pck` (parsed directly) and
`build/ios/AcornForest.xcarchive/.../AcornForest.app`.

Installed `.app` — 262 MB:

| Component | Size |
| --- | --- |
| `AcornForest.pck` | 169 MB |
| `AcornForest` (engine binary) | 59 MB |
| `Frameworks` (MoltenVK) | 23 MB |
| `Assets.car` (app icons) | 11 MB |

Inside the pck — 94% is textures:

| Content | Size | Files |
| --- | --- | --- |
| `.ctex`, compress mode 0 (Lossless) | **151.6 MB** | 522 |
| `.ctex`, compress mode 1 (Lossy WebP) | 13.1 MB | 427 |
| raw `.png` (boot splash + app icon) | 5.1 MB | 2 |
| music (`.mp3str`) | 2.8 MB | 2 |
| all code, scenes, data (`.gdc`/`.json`/`.scn`) | ~3 MB | — |

The 522 lossless textures average 290 KB each; the 427 already-lossy ones average 31 KB.

Ruled out as problems, by measurement:

- `_archive` (1.2 GB on disk) carries a `.gdignore`; Godot never imports it and it ships
  zero bytes.
- `map/*/reference/` and `_review/` ship zero entries.
- There is no meaningful dead art. The art that ships is art the game uses; it is simply
  stored uncompressed.

## Constraints discovered

Two facts that constrain the solution space, both of which contradict the obvious advice:

1. **`export_filter="all_resources"` is load-bearing and must not change.** All art
   resolves through `Game.art(rel)` (`engine/scripts/core/game.gd:28`), which returns a
   runtime string path that the caller passes to `load()`. No scene holds an
   `ext_resource` dependency on any shipped texture. Godot's dependency scanner therefore
   sees no references, and switching the filter to `"resources"` would strip nearly all
   art from the build.

2. **VRAM compression (ASTC/ETC2, mode 2) is not a download-size lever.** ASTC 4x4 is a
   fixed 1 byte/pixel, so a 1080x2340 backdrop lands at ~2.5 MB — roughly what lossless
   WebP already costs. It reduces GPU memory, not download. The download lever is lossy
   WebP (mode 1), which has *identical* VRAM cost to mode 0 since both decode to RGBA8 on
   the GPU. Mode 0 to mode 1 is therefore a pure download win whose only cost is image
   quality.

The same runtime-string-path property that blocks constraint 1 is what makes the pck split
cheap: mounting a second pack before the first `load()` requires no call-site changes.

## Levers

| Lever | Estimated saving | Risk |
| --- | --- | --- |
| 522 lossless textures to lossy WebP | ~100-120 MB | Quality on soft alpha edges |
| Ship a release export template (`make ios` uses `--export-debug`, `Makefile:150`) | ~15-30 MB | None; confirm the archive is not already release |
| Drop duplicate raw `splash_launch.png` + `icon.png` from the pck | ~5 MB | Trivial |
| Exclude tests/tools/workbenches (188 entries ship today) | <1 MB | None; hygiene |
| Split the pck (code ~3 MB / assets ~166 MB) | Update size, not install size | Low |

Target: 262 MB to roughly 120 MB installed, and a code-only update from 169 MB to ~3 MB.

## Design

### Texture re-encoding

Change `compress/mode` from 0 to 1 in the `.import` files of the shipped lossless
textures, with `compress/lossy_quality` set from spike evidence. Assets whose quality
regresses beyond the bar stay lossless — the change is per-file and reversible.

This does not alter VRAM use, does not touch source art, and does not change any call
site.

### Pck split

Main pck holds code, scenes, and data. A second pack holds `games/grove/assets/**`. Both
ship inside the `.app`. Because the asset pack is byte-identical across code-only
releases, both Xcode's incremental device install and Apple's update delta skip it.

Mount mechanism: prefer the export preset's `patches` array (auto-mounted at startup, no
boot code); fall back to an explicit `ProjectSettings.load_resource_pack()` as the first
action in `boot.gd` if the preset route misbehaves on iOS.

### Build integration

Extend the `ios` target in `Makefile:147` to emit both packs and place the asset pack in
the generated Xcode project, so the existing one-command export keeps working.

## The texture spike

The spike decides one thing: **at what `lossy_quality`, if any, is WebP acceptable on this
art.** Everything else in the texture lever follows mechanically from that answer.

Method:

1. Select representative assets spanning the real art classes — full-screen backdrop,
   tileable paper texture, dialog background, soft-alpha organic element (leaf, flower
   clump), small item sprite, character.
2. Encode each to WebP across a quality sweep.
3. Measure rather than eyeball: per-asset file size, PSNR and SSIM on RGB, and error
   concentrated on alpha edges — the failure mode this art style is most exposed to,
   given the existing defringe and feather work.
4. Produce 1:1 side-by-side composites with an amplified difference channel, for human
   review.

Acceptance: a quality setting is adoptable when the alpha-edge error is invisible at 1:1
on the composites and the projected total saving is material. The quality call is the
developer's, made against the composites — not inferred from the metrics alone.

Assets that fail at every quality level stay mode 0 and are listed explicitly in the
rollout.

## Rollout order

1. Texture spike; developer picks the quality bar.
2. Apply the texture change; verify installed size and run the full suite.
3. Release template and duplicate-PNG removal.
4. Pck split and build integration.

## Parked

- Native Metal renderer instead of MoltenVK (up to 23 MB, needs real-device testing).
- On-demand resources and OTA content packs.
- Source-art downscaling.
- `_archive`: 1.2 GB across 2484 files tracked in git. No effect on players; it makes
  every clone expensive. Needs a separate decision.
