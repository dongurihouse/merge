# Lantern Lodge modular layer pack v1

This is the first usable proof of the layer-first scene workflow, derived from
`winter_layered_lantern_lodge_plaza_v1.png`.

It has three stable game layers and one intentionally separate atmosphere underlay:

1. `backdrop/foundation.png` — terrain, ice, path, mountains, and far trees. The sky area is transparent.
2. `heroes/*.png` — exactly five independent, alpha-trimmed hero objects.
3. `coverings/edge_coverings.png` — fixed foreground trees, shrubs, and stones, rendered over heroes.
4. `underlay/sky_atmosphere.png` — optional separate sky/cloud/snow pass behind the terrain.

The initial sizes and centre-bottom anchors are in `metadata/layer_contract.json`. A replacement needs one
new hero image for the same slot; it does not require reconstructing the foundation or covering layer.

`raw/` retains the keyed sources for provenance; the runtime candidates are the alpha PNGs outside that folder.
