# Water fill FX demo — design

Date: 2026-06-25
Worktree: `/Users/xup/.codex/worktrees/ae0d/merge`
Status: approved (brainstorm), pending implementation plan

## Goal

Create a standalone Godot demo that shows a transparent box half-filled with water.
The water has small, cozy fluid motion. A water drop appears above the box, grows,
falls into the surface, briefly increases the wave energy, then the surface damps
back to calm. The effect loops so it can be watched and tuned.

## Non-goals

- No gameplay integration.
- No new raster art or imported assets.
- No full fluid solver. This is a stylized surface simulation: convincing ripples,
  splash rings, and damping, not physically exact water.
- No shader dependency for this version; keep the effect code-drawn and easy to
  screenshot.

## Approach

Use a standalone `SceneTree` tool, matching the existing `engine/tools/fx_demo.gd`
pattern. Add a `make water-fx` target for the live window and a quiet capture path
for verification.

The effect itself is one self-contained drawn node:

- Draw the tank outline and glass highlights.
- Clip/draw the water body to the tank interior, with the fill baseline at 50%.
- Build the surface from sampled sine/noise waves plus a small impact impulse.
- Animate a droplet that swells, falls, hits the surface, and fades into the water.
- On impact, raise the wave amplitude, add a short depression at the impact point,
  emit small upward beads and circular ripples, then decay all energy back to idle.

## Components

### 1. `engine/tools/water_fill_demo.gd`

A standalone `SceneTree` launcher.

- Live mode: opens a window titled "Water fill FX demo".
- Capture mode: when run under the existing quiet screenshot pattern, renders a
  short horizontal frame strip to a user-provided output path.
- Creates a neutral background and centers the demo node.
- Keeps the project main scene untouched.

### 2. `WaterFillEffect` drawn node

A local `Control` class inside the tool file is enough for this version.

State:

- `time`: continuous animation clock.
- `energy`: wave amplitude, slowly returning to the idle amplitude.
- `impact_phase`: short-lived impact envelope after the drop lands.
- `drop_t`: loop phase for droplet spawn, growth, fall, impact, and calm.
- `splash_bits`: small deterministic splash beads spawned on impact.

Drawing:

- Tank: rounded or lightly beveled rectangle, semi-transparent glass stroke,
  inner shadow, and top-left highlight.
- Water body: polygon from tank bottom up to the sampled wave surface.
- Surface: brighter stroke following the wave samples.
- Droplet: circular/teardrop mark above the water that grows before falling.
- Impact: splash beads and ripple rings, all alpha-faded by their lifetime.

The water sample function should combine:

- low idle wave: `sin(x * k + time * speed)`;
- second small wave at a different frequency;
- localized impact pulse centered on the droplet hit position;
- damping via `energy = lerp(energy, idle_energy, decay * delta)`.

### 3. Makefile targets

Add:

- `water-fx`: live demo.
- `shot-water-fx`: quiet frame-strip capture to `/tmp/water_fill_demo.png` by default.

These should follow the existing `fx` and screenshot target conventions.

## Data flow

`make water-fx` launches the standalone tool. The tool builds the view, starts the
effect clock, and loops this sequence:

1. Calm half-filled water idles.
2. Droplet appears and grows above the box.
3. Droplet falls into the center of the surface.
4. Impact injects energy, a surface depression, beads, and ripple rings.
5. Energy decays until the water returns to the idle motion.
6. Loop restarts.

## Error handling

- Capture mode prints the output path and image save error code, matching existing
  tool output style.
- If no output path is provided, capture mode writes to `/tmp/water_fill_demo.png`.
- The demo is deterministic: no frame-random behavior outside a fixed-seed splash
  pattern, so captures are comparable.

## Testing and verification

- Run `make test-fast` after implementation to protect the engine suite.
- Run `make water-fx` for a live visual check.
- Run `make shot-water-fx OUT=/tmp/water_fill_demo.png` and inspect the rendered
  frame strip.
- Verify that early frames show calm water, middle frames show the droplet impact
  and increased ripples, and late frames show damping back toward calm.

## Risks and decisions

- **Perceived fluidity:** a single sine wave will look mechanical, so combine two
  gentle waves and a localized impact envelope.
- **Overdraw / complexity:** drawing a modest number of surface samples keeps it
  cheap and clear.
- **Scope creep:** do not add editor UI, sliders, gameplay hooks, or shaders in this
  first version. Tune constants in code.
