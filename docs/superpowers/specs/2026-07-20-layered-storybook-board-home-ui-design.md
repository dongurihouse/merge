# Layered Storybook Board and Home UI

## Goal

Create two full-screen visual concepts that make Grove's Board and Home interface feel built from the same layered matte paper as the new scene art. These are review assets only; no runtime UI implementation is in scope.

## Shared visual system

- Use the Meadow Sky palette and Cut-Paper Playground material language from `docs/design/art-style-guide.md`.
- Every control is a distinct die-cut paper component: irregular or scalloped silhouette, warm cut edge, 2–4% paper fiber variation, and one shallow down-right paper shadow.
- Avoid smooth white plastic pills, glossy gradients, thick dark outlines, universal white sticker borders, and puffy rounded-square icon containers.
- Keep the compact language consistent across both screens: layered level rosette, three distinct resource tags, shallow folded-paper buttons, and overlapping bottom navigation tabs.
- Render at 1080 × 1920. Keep the top 160 px and bottom navigation region legible; leave the middle content area for play.

## Board concept

The Board remains a familiar merge board but receives a tactile paper HUD:

- A gold layered flower/star level rosette sits at upper-left.
- Water, coin, and acorn counters are three individual cream die-cut tags with their own recognisable contour and a small green add-tab.
- The next-unlock indicator is a short scalloped paper trail with a leaf-green progress strip and small paper milestones, not a full-width plastic banner.
- Resident/quest cards read as small layered request postcards above the board.
- The board is a dark slate paper sheet with a slightly irregular cut edge. Cells are stacked paper tiles: muted locked cards, clear open meadow cards, and distinct gold-tinged unlockable cards.
- The selected-item panel is a cream paper flap folded upward from the bottom. The five bottom destinations are overlapping cut-paper tabs; Board is the raised selected tab.

## Home concept

The working farm remains the hero. The HUD must frame rather than cover it:

- Reuse the level rosette and three individual resource tags from Board.
- Use small edge-mounted die-cut tabs for daily gift, mail, settings, and vault rather than a vertical stack of rounded-square controls.
- Place a large but compact flower-rosette customization/build action near the lower-right, clear of buildings and pathing.
- Use the same overlapping bottom navigation tabs as Board, with Home raised as selected.
- Farm buildings, crops, paths, and terrain retain a readable central play field. UI does not hide the house, barn, or primary interaction points.

## Deliverables

Save the final concepts and the exact prompts in `games/grove/assets/_concepts/screens/cutpaper_storybook_ui_v1/`:

- `board_cutpaper_storybook_ui_v1.png`
- `home_cutpaper_storybook_ui_v1.png`
- `board_cutpaper_storybook_ui_v1.prompt.txt`
- `home_cutpaper_storybook_ui_v1.prompt.txt`
- `README.md`, identifying reference roles and the concept-only scope.

