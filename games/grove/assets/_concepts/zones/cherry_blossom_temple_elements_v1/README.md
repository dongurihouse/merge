# Cherry Blossom Temple — Scene Workbench bundle

Open the scene with:

```sh
make sw SCENE=cherry_blossom_temple ROOT=games/grove/assets/_concepts/zones
```

The scene preserves the paper-cut grain and zen-sand backdrop of the original mock, but is rebuilt from independently placeable assets.

## Major grouped placements

Every major placement is a Scene Workbench `cluster`, so its nearby visual dressing travels, scales, and re-stacks as one unit:

- `upper_garden` — upper pine garden, local bonsai, and rock.
- `shrine_hall` — hall, rear bush, and foundation rock.
- `left_sakura` / `right_sakura` — each cherry tree with its own bush-and-rock footing.
- `pond_bridge` — clean pond, separate bridge, and only edge dressing; the pond asset itself has no bridge or lower-right vegetation.
- `temizuya` — water-cleansing pavilion with its bamboo basin, plus local bonsai and bush.
- `torii_gate` — gate, the two front lanterns, and the two approach-side bushes.

## Reusable decals

- `05_dressing/stepping_stones/` has four individual stone variations. The placed route is `pilgrim_path`, a cluster of independent stone decals, never a baked path image.
- `05_dressing/rocks/` has three rock-cluster variations.
- `05_dressing/bushes/` has three bush-cluster variations.
- `05_dressing/bonsai/` has three bonsai variations.

Unused variations remain in the Workbench palette for further local dressing. Associate a decal with its nearby major group by assigning the same `cluster` value in `metadata/placements.json`.
