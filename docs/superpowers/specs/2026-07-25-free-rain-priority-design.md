# Free Rain Priority Design

## Goal

Make the water refill flow prefer the daily free rain and remove the old introductory refill allowance.

## Behavior

- The water stall grants one free full-can rain per day.
- The old three lifetime introductory refills no longer exist or persist.
- When the daily free rain is ready, an empty board labels the refill as free and opens the water stall without spending acorns.
- The paid 25-acorn rain card stays hidden while the free rain is ready.
- After the daily free rain is unavailable, the existing 25-acorn refill behavior remains available.
- An empty player who cannot afford the paid refill still opens the water stall.

## Implementation

Use `Claims.can_show("refill_water")` as the single source of truth for free-rain availability. The board routes ready free rain through the existing shop flow so the claim ledger remains authoritative. Existing saves may retain a stale `refills_used` key, but runtime code ignores it.
