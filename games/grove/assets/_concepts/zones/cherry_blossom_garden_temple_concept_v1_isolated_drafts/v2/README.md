# V2 scene-workbench asset drafts

This revision separates the pond from the bridge and replaces the monolithic
path extraction with a deterministic composition of four reusable stepping
stones. All PNG assets have alpha.

- `01_pond_only.png` — koi pond, stone rim, fish, and lily pads only.
- `02_bridge_only.png` — arched footbridge only.
- `03_stepping_stones/` — four individual stepping-stone PNGs, transparent
  sheet, raw source, processor metadata, and QC GIF.
- `05_reconstructed_stepping_path.png` — a curved path assembled locally from
  those four individual stones; no generative path art.
- `04_garden_props_v2/` — nine separated props in a 3x3 pack: three rock
  clusters, three bush clusters, and three bonsai trees.

Generation references and raw chroma-key sources are retained under `raw/` and
`references/`. `00_v2_assets_preview.png` is the review sheet.

## Prompt set

- Pond: source-style koi pond without bridge, lower-right vegetation, fence, or
  path; bare even stone rim and minimal moss.
- Bridge: source-style red-orange arched wooden bridge with stone underside,
  isolated from water and foliage.
- Stones: four loose pale warm stepping-stone shapes, generated as a 2x2 pack
  and split deterministically.
- Garden props: a 3x3 pack of small/medium/large rocks, bushes, and bonsai
  props, generated with strict safe margins and split deterministically.
