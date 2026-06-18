# Drop board / room art here

The game auto-uses these if present, and falls back to flat cozy colors if not.
See ../../docs/design/merge_spec.md §13 for the art direction.

| File | Size | Notes |
|---|---|---|
| `bg_bedroom.png` | 1080×1920, opaque | full-bleed cozy room background (low-contrast so tiles pop) |
| `tile_slot.png` | 512×512, transparent | one cozy empty pocket/cubby; items nest inside it |
| `board_tray.png` | square-ish, transparent | the rug/basket the grid of pockets sits on |

After adding files, open the project in Godot once so it imports them.
Per-family tray skins (laundry basket / bookshelf / toy bin) come later.
