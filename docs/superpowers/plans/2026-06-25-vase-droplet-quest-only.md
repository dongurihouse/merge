# Vase Droplet Quest-Only Polish

## Goal

Make the Purge vase droplet smoother and smaller, show it only when a quest completion awards EXP, and shift the vase left so the droplet lands under the level badge area. Debug EXP should still fill the vase without showing the droplet.

## Steps

1. Add regression tests for the smaller smoother droplet outline, event-only droplet playback, debug EXP without droplet playback, and left-shifted Purge vase layout.
2. Update `VaseWaterEffect` so idle ticking no longer auto-spawns the droplet, add an explicit droplet playback method, reduce droplet scale, and generate a higher-resolution outline.
3. Update `Board` so quest completion requests droplet playback while debug EXP uses the normal fill animation only.
4. Run the focused headless water/vase test suite and inspect the result visually.
