# Daily, Rush Loadout, and Cascade Polish

Date: 2026-07-30

## Goal

Fix three player-facing problems without changing their unrelated behavior:

1. Opening the Daily dialog and claiming its reward must not stall on synchronous image processing.
2. The Rush loadout must use the shared full-size dialog instead of the cramped 540 px sheet.
3. Cascade guide chains must never share a cell; when candidates overlap, the longest candidate owns the shared cells.

## Options considered

### Daily performance

- **Prebake the finished shadowed sprites (selected).** Extend the existing dialog bake contract so Daily loads the exact polished-and-shadowed pixels it displays. This removes the cold-open cost as well as the claim-rebuild cost and preserves the current appearance.
- Cache shadows after first use. This makes claims and later opens fast, but the first open still stalls.
- Replace shape-following shadows with cheap UI shadows. This is fast but changes the approved art treatment.

### Rush sizing

- **Use the shared global dialog width (selected).** Size the sheet from `Kit.frame_width_pct`, retain its height cap and scrolling, and keep the existing rows/actions.
- Raise the hard-coded cap from 540 px to another number. This improves one viewport but remains disconnected from the shared frame setting.
- Redesign the loadout as a two-column screen. This is unnecessary scope and creates new small-screen behavior.

### Cascade overlap

- **Greedy longest-first cell reservation (selected).** Candidates are already sorted by length and deterministic row-major tie-breaks. Keep a candidate only if none of its run cells were claimed by an earlier candidate.
- Keep one winner per same-line connected component. This can hide disjoint chains that happen to touch through irrelevant same-line pieces.
- Solve for the maximum number or total length of disjoint candidates. This can choose multiple shorter chains instead of the explicitly requested longest chain.

## Design

### Daily dialog

The Daily surface keeps its current node layout, timing, rewards, and visuals. Its shape-following icon shadows move into the existing baked-texture pipeline:

- The kit exposes a deterministic baked-shadow texture lookup using the same `add_drop_shadow` recipe as today.
- Daily declares the source sprites and shadow recipe it uses.
- `games/tools/bake_textures.gd` emits the derived mirrors.
- The freshness guard verifies the committed outputs against a fresh render of the same recipe.
- Runtime `_shadowed` loads the mirror and never performs `get_image`, blur, or texture creation while opening or rebuilding the dialog.

The fallback remains visually correct if a mirror is absent, but it is recorded as a live-polish violation so tests cannot silently ship the slow path.

### Rush loadout

`Map._open_expedition` derives its dialog width from the same global frame-width setting used by the other map dialogs. The content keeps its current toggle-card layout and interaction contract. The existing vertical cap remains viewport-relative so short screens scroll rather than clipping the action row.

The player-facing regression test opens the real overlay and asserts:

- its sheet width follows the shared dialog width and is materially larger than the former 540 px cap on the standard test viewport;
- all five loadout rows remain present;
- real pointer taps still toggle rows;
- unaffordable selections stay visible and disable Set off.

### Cascade guide

Only guide candidate selection changes; cascade execution, rewards, and scoring do not.

At rest, candidate chains remain sorted longest-first. A filtering pass maintains a set of reserved run cells:

1. inspect the next candidate in ranked order;
2. discard it if any run cell is already reserved;
3. otherwise keep it and reserve every run cell.

This preserves separate non-overlapping chains, including chains on different item lines. Equal-length conflicts keep the existing deterministic row-major winner. Drag mode continues to focus the held piece's longest chain; its dimmed background chains use the same non-overlapping resting set.

## Verification

- Add a Daily regression proving runtime dialog construction and claim rebuild use only prebaked shadow textures.
- Add a real-overlay Rush geometry test at the standard portrait viewport, while retaining the existing pointer and low-wallet tests.
- Add pure Cascade mark tests for longest-over-shorter overlap, equal-length tie-breaking, and preservation of disjoint chains.
- Update the Grove Cascade scene test to assert the visible guide has no shared cells and shows the expected longest winner.
- Run focused suites, `make test-fast`, `make test`, and `git diff --check`.
- Capture the Rush loadout and a deterministic overlapping-Cascade board in one batch and inspect both visible states.

## Out of scope

- Daily reward values, claim timing, animations, or visual redesign.
- Rush boost balance, row content, or expedition gameplay.
- Cascade execution paths, reward tiers, or chain-length thresholds.
