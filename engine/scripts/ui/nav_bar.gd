extends RefCounted
## The shared bottom-navigation GEOMETRY constants (owner: one module read by the board + the map).
## The row builder that used to live here is gone — every shipped surface now builds its own bottom
## row — but the spacing contract stayed shared so the board and the home/map screen keep placing
## their bottom row (and everything that must clear it) at the SAME insets.
## Read by `engine/scripts/scenes/map.gd`, which preloads this script purely for these values.
## Lives in ui/ so scenes/ may import it; it must NOT reach up into scenes/ (the layering guard enforces this).

const DEFAULT_PX := 150.0     # nav button box size
const SIDE_INSET := 32.0      # left/right inset of the row
const BOTTOM_MARGIN := 16.0   # extra px above the safe-bottom
