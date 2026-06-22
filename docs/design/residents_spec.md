# Residents — Expansion Spec

*Working title: "The Homecoming" (placeholder).*
*Status: in progress — this is the summary and thesis. Mechanics, economy, and risk sections to follow.*

A standalone expansion that layers on top of the base game (`merge_spec.md`, `grove_spec.md`).
It supersedes the base game's "residents are cosmetic-only" stance — see *What this changes*.

---

## Summary

Residents is an expansion layer that sits on top of the base game's core loop (merge →
deliver quests → restore the map). The base game's job is to *restore* a place. This
expansion's job is to make a *restored place worth returning to*. Once a map is complete it
becomes a living habitat: spirit-folk come home, the player chooses who to take in, the
population grows on its own while away, and the residents pay the player back — in resources
and in requests. It turns today's dead-end ("the map is finished, there's nothing left to do
here") into the game's primary long-tail and daily-return loop.

## Why we want it (the fundamental reasoning)

A completed map is currently a trophy with nothing behind it. Residents technically exist,
but welcoming one is a pure coin **sink**: you spend, a placeholder wanders in, and you get
nothing back — no goal, no reward, no reason to keep going. That was deliberate; the
"cosmetic-only, no yield, no power" rule kept the economy provably safe. But it left the
endgame hollow on three fronts that matter for a live game:

- **Coins have nowhere meaningful to go.** Spending is a drain, not a power — so the
  late-game economy is inert.
- **Finished maps go dead.** The thing the player worked hardest to complete becomes the
  thing with the least to do.
- **Nothing compounds and nothing pulls them back.** No reason to return tomorrow, no set to
  complete, no growth to check on.

The base game proves the player *can* finish a map. It gives them no reason to *live* in one.

## Thesis

A restored world should **grow, reward, and ask** — not just sit there. We turn residents
from a cost into the engine of the late game by stacking four reinforcing pulls on a single
roster:

- **Acquire with delight** — you don't buy a unit, you *take in a stray*: a few show up, you
  keep one. Choice plus chance, endlessly repeatable, with a premium path that improves the
  odds of rarer or higher residents.
- **Collect** — the roster becomes a set worth completing: rarer and higher-tier residents
  are *visible goals*, not invisible counts.
- **Grow idle** — the habitat keeps filling while you're away, and fills **faster the more
  you already have** — the compounding hook that makes leaving and returning feel earned.
- **Be repaid** — residents *produce*, and they *ask* (quest-givers offering special things),
  so the spend finally carries power and the finished map stays a live surface.

**The bet:** each pull is weak alone — we've watched the cosmetic-only version fall flat —
but stacked they reinforce. Acquisition feeds collection, collection motivates idle growth,
idle growth feeds production, production funds more acquisition. That self-renewing loop is
the retention engine and the reason coins and diamonds matter, bolted on top of the merge
core without changing how the core plays.

## What this changes in the base game

This expansion **supersedes** the current "residents are cosmetic-only forever — no yield, no
power" mandate (`merge_spec.md` §4 corollary; `grove_spec.md` §3). Residents become an
economic faucet and a progression system, which deliberately reopens the economy's
"sink > faucet" balance — to be kept bounded and re-validated against the pacing sim
(`grove_sim.gd`). That trade *is* the point: the base game showed coins have no power; this
expansion gives them power.
