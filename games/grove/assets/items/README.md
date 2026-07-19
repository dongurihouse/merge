# Live item art

The game auto-loads `assets/items/<family>/<family>_<tier>.png` and shows it on the
tile; if a file is missing it falls back to a colored placeholder with the tier number.
Each item family lives in its own subfolder. The live family roster is owned by `LINES`
and `SPECIAL_ITEMS` in `grove_data.gd`.

The picture-book item lines currently use these 12-tier families:

```
fairy_hollow_glowshroom       fairy_hollow_wild_berries
snowy_village_snow_ice       snowy_village_woolens
snowy_village_winter_berries oasis_desert_fruits
oasis_sand_sculptures        oasis_spices
coral_reef_shells            coral_reef_corals
cherry_blossom_koi           cherry_blossom_tea_cups
```

Generator sprites (`gen_*.png`) live in `items/generator/`. Coin board pieces live in
`items/coin/coin_<tier>.png`; the currency-pill coin sprite is separate, at
`ui/currency/coin.png`. Resident lines follow the same tiered convention under
`items/resident_<id>/`.

Retired item families and generator sprites are preserved under `assets/_archive/items/`.
Do not move them back into this live folder without also restoring their data definitions.

After adding files, open the project in the Godot editor once so it imports them.
