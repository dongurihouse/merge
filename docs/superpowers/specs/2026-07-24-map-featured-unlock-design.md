# Map Gallery Featured Unlock Target

## Goal

The large top card on the MAPS gallery must show the picture-book map the
player is currently unlocking. It must not remain on Fairy Hollow or follow a
different map merely because the player browsed there.

## Root Cause

`map.gd._featured_map()` still selects from the retired per-map spot and gate
completion chain, with `last_map` as its first preference. The live
picture-book progression instead unlocks cover-up clusters in one strict
global sequence across all five maps. Later maps are intentionally browseable,
so browsing state and the legacy map frontier do not identify the active
unlock target.

## Design

Add a pure progression query to `content.gd` that returns the current cover-up
map:

1. Walk `coverup_pages()` in play order.
2. Return the first page whose `next_locked_cluster()` is not empty.
3. If every cover-up cluster is unlocked, return the final cover-up page.
4. If no cover-up pages are authored, fall back to the existing map frontier,
   then the hub map.

`map.gd._featured_map()` will delegate to that query using its loaded
`unlocks`. It will no longer consult `last_map`, legacy spot completion, or
player level. The gallery card layout, progress presentation, taps, and
navigation remain unchanged.

## Verification

Add a regression test that:

- confirms a fresh cluster state features the first cover-up map;
- marks every cluster on the first map unlocked while leaving `last_map` on
  that map, then confirms the featured target advances to the second map;
- marks all clusters unlocked and confirms the final map remains featured.

Run the focused suite, `make test-fast`, the full `make test`, and the map
scene smoke check before integration.
