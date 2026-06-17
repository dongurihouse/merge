# Tree foliage motion in Godot — design spec

How to make our 2D sprite trees sway believably. The goal is *foliage* that moves — leaves and outer
branches drifting and fluttering in the wind — while the **trunk stays planted**. This documents the
current implementation, why a rigid rotation reads wrong, and the ladder of techniques (cheap → rich)
for getting to "realistic," with the Godot specifics for each.

Shared implementation lives in [`tree_wind.gd`](../../engine/scripts/ui/tree_wind.gd); the grove map
([`map.gd`](../../engine/scripts/scenes/map.gd)) and the dev placer
([`map_placer.gd`](../../games/grove/tools/map_placer.gd)) both use it. Preview/tune it in the placer:
press **G** to trigger a gust.

## Why naïve approaches read as fake

- **Rigid rotation about the base** (our first version): the whole sprite — trunk included — tips like a
  metronome. Trees are not inverted pendulums; the trunk barely moves and the canopy moves *most*. It
  also moves as one rigid body, so there's no sense of many leaves.
- **Uniform horizontal slide of the top**: better (trunk stays), but the canopy slides as a single slab.
  Real foliage has the motion *propagate* across and through it — a travelling ripple, not a rigid shear.
- **One global sine**: a single frequency is hypnotically regular. Wind is broadband — a slow sway with
  faster flutter riding on top, gusting and lulling.

The fixes, in order: (1) weight displacement by height so the trunk is fixed and the canopy moves most;
(2) vary phase across the sprite so motion ripples; (3) sum multiple frequencies; (4) gate it all with a
gusting envelope so it isn't constant; (5) per-tree variation so a stand doesn't move in unison.

## The ladder of techniques

### 1. Canopy-shear fragment shader — *current, shipped*

A `canvas_item` fragment shader offsets the sampled UV horizontally (plus a touch vertically) by an
amount that grows from 0 at the trunk line to max at the top. Phase varies with `UV.x` (ripple) and two
sine frequencies mix (sway + flutter). A `gust` uniform (0→1→0, tweened from GDScript) is the envelope.

- **Pros:** one material, no extra nodes, runs on every sprite as-is, trunk stays planted, reads
  organic enough for ambient background trees.
- **Cons:** UV shear samples *within* the sprite's own texture, so large offsets smear or clip at the
  texture edge (we zero-out samples that fall outside `[0,1]`, which needs transparent margins in the
  cutout). It cannot move parts *past* the sprite's bounding box, and there's no real parallax/overlap
  between leaf masses.
- **When it's enough:** distant or small trees, dense ambient foliage, anything not a hero asset.

### 2. Noise-driven turbulence — *recommended next step*

Replace the pure sines with a scrolling noise lookup so the wind is broadband and non-repeating.

- `uniform sampler2D wind_noise` fed a `NoiseTexture2D` (Perlin/Simplex, `seamless = true`).
- Sample it at `UV * scale + TIME * wind_dir * speed`; use the value (remapped to −1..1) as the
  displacement, still weighted by the canopy height mask and the gust envelope.
- Two octaves (a large slow one + a small fast one) give gust-and-flutter for free.
- **Cost:** one extra texture fetch per fragment — negligible. **Win:** the single biggest jump in
  believability for the least work. This is the highest-value upgrade.

### 3. Vertex-grid mesh (`MeshInstance2D`) — for smooth, edge-safe displacement

Render the tree on a subdivided quad mesh and displace in a **vertex** shader instead of sampling UVs.

- Build a grid mesh (e.g. 8×12) sized to the sprite; texture it with the tree.
- Vertex shader pushes each vertex by the wind function (same height weight + noise + gust).
- **Pros:** geometry actually bends — no UV smear, no edge clipping, displacement can exceed the
  original silhouette, and it's cheaper per-pixel. Smoother large motions.
- **Cons:** more setup (mesh generation, a `ShaderMaterial` on a `MeshInstance2D`), and our sprites are
  `TextureRect`s today, so this is a per-asset upgrade for hero trees.

### 4. Per-leaf-cluster sprites — most natural for 2D

Author (or slice) a tree as a trunk sprite plus several overlapping **canopy-cluster** sprites. Give
each cluster its own pivot near where it joins the branch, its own phase/frequency/amplitude, and the
shader (or a simple rotation/offset) on each.

- **Pros:** clusters move independently and overlap → real depth, parallax, and the read of *many*
  leaves. This is how most polished 2D games sell foliage.
- **Cons:** needs art authored in layers (or an automated alpha-island slice — we already have a
  connected-components splitter from the cloud work that could seed this), and more nodes per tree.
- **Recommendation:** reserve for hero/foreground trees; combine with technique 2 on each cluster.

### 5. Bones (`Skeleton2D`) / springs — usually overkill

Rig the canopy with a few bones and drive them with a wind force + spring-back (or `SpringBone`-style
damping). Most physically faithful, but heavy to author and tune for what is background dressing. Skip
unless a tree is interactive (e.g. the player shakes it).

### Orthogonal polish
- **Light shimmer:** a subtle brightness ripple synced to the sway (leaves catching light as they turn)
  adds life cheaply — modulate `COLOR.rgb` by a small noise term.
- **Settle on gust end:** ease-out with a tiny overshoot/bounce so the canopy *settles* rather than
  stopping dead. (Our envelope eases, but a damped-spring tail would be nicer.)

## The wind model (shared field)

Individual per-tree randomness is good, but a *shared* wind makes a scene cohere — a gust should sweep
across the whole map, not fire independently per tree.

- A global wind: direction `wind_dir` + a time-varying strength (slow noise) exposed as a global shader
  uniform or an autoload value.
- Per-tree variation layered on top: random `phase`, `freq`, `amp`, and **stiffness by size** (big trees
  sway slower and less; saplings flutter more).
- **Gusts:** model strength as base + gust envelope. A gust ramps in fast (~0.4s), holds briefly, and
  damps out (~1.5s). Stagger per tree, or — better — propagate one gust across the map as a moving front
  (offset each tree's envelope start by its x position ÷ gust speed).

## Recommended path for this game

1. **Now (done):** canopy-shear shader + ripple + dual-frequency + gust envelope, shared in `tree_wind.gd`,
   previewable in the placer (G).
2. **Next, cheap, high-impact:** swap the sine displacement for **noise turbulence** (technique 2) and add
   a shared wind field so gusts sweep the map.
3. **For hero trees:** per-cluster sprites (technique 4), optionally on a vertex mesh (technique 3), each
   driven by the same wind field.
4. **Polish:** light shimmer + a damped settle.

## Godot specifics / gotchas

- `canvas_item` fragment shaders get `TIME`, `UV`, `TEXTURE`, `COLOR`. UV-offset sampling must guard
  `uv` outside `[0,1]` (clamp/repeat will smear the edge pixel) — we discard those to transparent, which
  relies on the cutout having transparent margins.
- Animate a shader uniform from a `Tween` with the property path `"shader_parameter/<name>"` (this is how
  the gust envelope is driven). Bind the tween to the sprite node so it dies with it.
- `NoiseTexture2D` with `seamless = true` tiles without a visible seam for scrolling wind.
- Per-instance variation without N materials: Godot 4 `instance_uniform`s let many sprites share one
  shader yet vary phase/amp per instance. We currently make one `ShaderMaterial` per tree (fine at our
  counts); switch to instance uniforms if tree counts grow large.
- Headless test runs don't execute shaders (dummy renderer); keep the GDScript side (material creation,
  tween scheduling) null-safe so suites still pass.
- Mesh route: `MeshInstance2D` + a generated `ArrayMesh`/`QuadMesh`-like grid; displace in `vertex()`.

## Tuning surface (current shader, `tree_wind.gd`)

| uniform | meaning | current range |
|---|---|---|
| `phase` | per-tree desync | random `0..TAU` |
| `freq`  | base sway speed | `1.3–2.4` rad/s |
| `amp`   | peak canopy shear (fraction of width) | `0.04–0.07` |
| `trunk` | UV.y below which nothing moves (trunk) | `0.56–0.66` |
| `gust`  | envelope, 0=still 1=full | tweened 0→1→0 |
