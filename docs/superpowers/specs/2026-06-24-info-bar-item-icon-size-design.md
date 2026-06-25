# Info Bar Item Icon Size

*2026-06-24 · workbench follow-up for the board info bar*

## What

Add a saved workbench knob that changes only the selected item/generator sprite size in the board info bar.
The existing `inner_scale` continues to size the info button and icon slot. The new knob sizes the artwork
inside that slot, so the owner can make the selected item read larger without moving the rest of the bar.

## Design

- Add `item_icon_scale` to the `info_bar` saved config block. It is stored as a percent of the selected
  icon slot and defaults to `80`, matching the current `_info_inner_px * 0.8` behavior.
- Resolve it in `Kit.info_bar_opts_from_config` as `item_icon_scale / 100.0`.
- Expose the resolved scale through `Kit.info_bar` metadata so live board code and workbench preview use
  the same value.
- Use the scale for both regular selected items and selected generators. The coin/gem icons in Buy/Sell
  chips remain controlled by the existing `sell_icon` knob.
- Add a workbench sidebar slider under Info bar with a practical range of `50..120`.

## Acceptance

- The Info bar workbench section has a saved `item_icon_scale` slider.
- The default selected item preview remains visually unchanged.
- Raising `item_icon_scale` makes the selected item/generator sprite larger in the preview and live board.
- Existing Buy/Sell currency icon sizing is unchanged.
