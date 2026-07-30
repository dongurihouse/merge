# Resting chain FX

Date: 2026-07-30

## Goal

The resting board shows the existing chain FX for every legal merge whose resulting cascade length
is at least `CascadeMarks.GUIDE_MIN_N` (`3`). The player does not need to pick up a piece before the
board reveals those chains.

## Design

- Keep the existing chain mark shape, target bloom, `×n` tag, renderer, and DRAG/RUN behavior.
- In REST, enumerate the board's legal piece-to-piece merges using the same target/path calculation
  already used by DRAG.
- Emit the existing full-strength chain stack for every candidate with `n >= GUIDE_MIN_N`.
- Deduplicate candidates that produce the same target and run, so equivalent source directions do
  not paint the same FX twice.
- Do not cap resting chains. Every qualifying chain is shown.
- Preserve deterministic row-major ordering after sorting longer chains first.

## Verification

- A pure regression proves a remote source plus a target staircase emits chain FX at REST before
  pickup.
- A pure regression proves every qualifying chain is retained when more than three exist.
- The Grove scene regression exercises the live resting-board publish path.
- A deterministic resting-board capture visibly proves the FX appears without a drag.
