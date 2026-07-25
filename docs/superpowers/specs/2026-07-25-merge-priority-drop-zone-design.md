# Merge-Priority Drop Zone Design

## Goal

Make intended merges easier to land without changing ordinary movement or swapping.

## Behavior

Before resolving a drop against the exact grid cell, the board searches an enlarged area around nearby compatible merge targets. The nearest compatible target wins. This applies to matching items, valid recipe pairs, and matching same-tier generators.

If no compatible target is inside the enlarged area, the existing exact-cell drop path remains unchanged. Moves, swaps, bag drops, taps, and invalid snap-backs keep their current behavior.

## Implementation

`board.gd` owns one merge-target helper and one named hit-area constant. Item hover telegraphs and item/generator releases use the helper, keeping the visible item cue aligned with the final item merge result. No board-model, save-data, feature-flag, or content changes are required.

## Verification

A real board-scene drag regression releases over a competing neighboring cell while a compatible target remains inside the enlarged area. It verifies merge precedence for normal items, recipe pairs, and generators, while existing suites protect unchanged swap and movement behavior.
