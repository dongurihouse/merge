# Grove Flat-Paper Currency Pills and Icon Buttons

Date: 2026-07-18

## Context

The approved standalone currency-pill study established the desired construction rule: use an uncut, flat paper texture for the surface and draw the silhouette, edge, and shadow in Godot. The live wallet still nine-slices `resource_pill.png`, and the shared square icon-button path still scales `shared/badge_rect.png`. Both raster assets already contain cut geometry and edge treatment, so resizing them can distort corners or expose baked seams.

This pass promotes the approved currency-pill construction into the live shared kit and applies the same construction rule to the common square icon buttons used by Bag, Home, Map/Back, and the map side rail.

## Goals

- Make the live water, coin, and acorn pills use the approved flat cream paper texture with code-defined rounded geometry, edge, and shadow.
- Make the common square icon-button family use flat paper texture fills with code-defined rounded-square geometry, edge, shadow, and interaction states.
- Propagate the change through existing shared constructors so Bag, Home, Map/Back, and side-rail consumers stay consistent.
- Preserve all current sizes, positions, icons, badges, labels, hit targets, callbacks, safe-area behavior, and Workbench sizing controls.
- Keep the standalone currency-pill scene as an isolated visual and regression reference.

## Non-goals

- Do not change text CTA buttons such as Visit, Continue, Claim, or purchase actions in this pass.
- Do not change the circular Play/Restore disc or other intentionally circular controls.
- Do not redesign navigation layout or add the five-tab mock navigation to screens that do not currently use it.
- Do not rebuild the star-shaped level badge in this pass. It is a separate follow-up after the square-button family is accepted in the live game.
- Do not modify currency values, store routing, button callbacks, or gameplay state.

## Shared rendering approach

`ui_workbench_kit.gd` will own one internal rounded-paper surface helper used by the live wallet and square icon buttons. The helper will:

1. Draw a `StyleBoxFlat` base with a code-defined fill, one-pixel structural-slate edge, rounded corners, and antialiasing.
2. Add an inset `TextureRect` using an approved flat Meadow paper tile.
3. Apply a small canvas shader that masks the flat texture to a code-defined rounded rectangle. The shader defines clipping only; it does not paint a baked border, bevel, highlight, or shadow.
4. Apply semantic tint and button-state modulation to the paper layer so normal, hover, pressed, and disabled states remain readable.
5. Use the existing shared Meadow shadow wrapper, clamped to structural slate at no more than 20 percent opacity.

The standalone pill study remains independent and does not become a runtime dependency.

## Live currency pills

`gold_currency_pill()` keeps its public API and layout behavior. Its `Button` frame stops using `resource_pill.png` and instead receives the shared code-drawn paper surface.

- Fill texture: `ui/meadow_v2/texture_cream.png`.
- Fill color: Meadow cream `#F6EBDD`.
- Edge: one-pixel structural slate `#3F6D7D` at restrained opacity.
- Corner radius: 35 percent of the rendered pill height, matching the approved 28 px radius on the 80 px reference pill rather than forming a semicircular capsule.
- Shadow: the existing opt-in shared wallet shadow and Workbench shadow controls remain authoritative.
- Content margins, icons, amount labels, plus art, click routing, and Workbench geometry remain unchanged.

## Common square icon buttons

The existing `home_button()` constructor remains the single public atom. Its `shape: "rect"` branch will always use the code-drawn rounded-paper surface instead of `shared/badge_rect.png`. Existing callers do not receive a new component type.

The rounded-square radius remains proportional to button size so rail, bottom-row, and map buttons scale together. The code edge and shadow use the same Meadow colors and light direction as the wallet.

An optional semantic surface role selects the flat paper tile and tint without changing layout:

- `cream`: side-rail utility buttons and neutral controls.
- `sky`: Map and Back navigation.
- `green`: Home or selected/primary navigation.
- `purple`: Bag.

Consumers that currently use a circular default but belong to this common square family will explicitly request `shape: "rect"`. The circular Play/Restore control remains on its authored disc path.

## Consumer migration

- Board Bag well: rounded square, supporting-purple paper role.
- Board Home/common navigation well: rounded square, action-green paper role where it represents Home.
- Map button and place-picker Back button: rounded square, sky paper role.
- Map Settings, Expedition, Daily, Vault, and Inbox rail buttons: rounded square, cream paper role.
- Specialized Play/Restore: unchanged circular authored shell.

The migration is limited to option dictionaries and the shared constructor. Consumer callbacks and scene layout code remain intact.

## Interaction and state behavior

- The outer `Button` remains the sole input target.
- Decorative texture, icon, plus token, count, and notification-badge nodes remain mouse-transparent.
- Hover uses a slight lightening of the paper tint.
- Pressed uses the existing press-juice transform plus a slight darkening of the paper tint.
- Disabled uses a restrained desaturated/dim tint while preserving silhouette and icon readability.
- Notification badges and Bag counts keep their existing positions and metadata.

## Testing and visual verification

Tests will be written before production changes and will verify:

- Live wallet pills no longer reference or nine-slice `resource_pill.png`.
- Wallet shells use the flat cream texture, code radius, code edge, and existing shared shadow.
- Rectangular `home_button()` instances no longer reference `shared/badge_rect.png`.
- Rectangular buttons use the expected flat paper texture and semantic role.
- Bag, Home, Map/Back, and side-rail consumers request the shared rounded-square path.
- Circular Play/Restore remains on its existing authored disc path.
- Existing click, badge, count, layout, and safe-area tests continue to pass.

Real-renderer captures of the Workbench shared-button preview, board chrome, and map chrome will be inspected for texture continuity, corner shape, edge thickness, shadow direction, and icon placement. The focused Grove suites, `make test-fast`, and the full `make test` sweep must pass before merge.

## Follow-up

After this live square-button pass is visually accepted, the level badge will receive its own focused design and implementation. That pass will preserve the star silhouette and tier meaning while separating flat paper texture from code-defined star geometry, edges, and shadow.
