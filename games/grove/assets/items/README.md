# Drop item art here

The game auto-loads `assets/items/<family>/<family>_<tier>.png` and shows it on the
tile; if a file is missing it falls back to a colored placeholder with the tier number.
Each item family lives in its own subfolder (e.g. `items/flower/flower_1.png`).

Generator sprites (`gen_*.png`) live in `items/generator/`. Coin board pieces live in
`items/coin/coin_<tier>.png` (the tiered merge-board coins). The currency-pill coin sprite
is separate, at `ui/currency/coin.png`.

Expected files (512×512, transparent PNG — see ../../ICON_PROMPTS.md for prompts):

```
flower/flower_1.png    … flower_8.png
tools/tools_1.png      … tools_8.png
mushroom/mushroom_1.png… mushroom_8.png
honey/honey_1.png      … honey_8.png
```

After adding files, open the project in the Godot editor once so it imports them.
