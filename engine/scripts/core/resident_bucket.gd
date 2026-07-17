extends RefCounted
## The global resident bucket — PURE logic, no game wiring.
## Spec: docs/superpowers/specs/2026-07-16-global-resident-bucket-design.md
## State is a plain Dictionary (make_state); time (seconds) and RNG are always injected.
## This module preloads NOTHING — a later adapter persists state in Save and feeds real time.

const MAX_TIER := 12
const SELL_PER_TIER := 5
const LINES := ["coin", "water", "boost", "diamond"]

# PROVISIONAL dials — sim-tuned later. rate is units/HOUR per point of the line's Σtier;
# bank(Σtier) = bank_base + bank_per_tier × Σtier; day_cap 0 = unbounded; weight = box roll odds.
const DEFAULTS := {
	"lines": {
		"coin":    {"rate_per_tier_h": 0.25, "bank_base": 4.0, "bank_per_tier": 1.0,   "day_cap": 0, "weight": 60},
		"water":   {"rate_per_tier_h": 0.05, "bank_base": 2.0, "bank_per_tier": 0.25,  "day_cap": 0, "weight": 25},
		"boost":   {"rate_per_tier_h": 0.02, "bank_base": 1.0, "bank_per_tier": 0.125, "day_cap": 0, "weight": 10},
		"diamond": {"rate_per_tier_h": 0.01, "bank_base": 1.0, "bank_per_tier": 0.125, "day_cap": 2, "weight": 5},
	},
	"tier_weights": [60, 25, 10, 5],   # box tier roll — t1-heavy, capped at t4
}

static func make_state(now: float = 0.0) -> Dictionary:
	return {
		"cells": 0,
		"hand": [],          # [{line, tier}] — unbounded
		"placed": [],        # [{line, tier}] — bounded by cells
		"banks": {},         # line -> float matured units awaiting collect
		"last": now,         # last settle timestamp (s)
		"day": {"stamp": -1, "granted": {}},   # per-day collect bookkeeping for day_cap lines
	}

static func hand_add(state: Dictionary, line: String, tier: int = 1) -> int:
	if line in LINES:
		state.hand.append({"line": line, "tier": clampi(tier, 1, MAX_TIER)})
	return state.hand.size()

static func hand_merge(state: Dictionary, i: int, j: int) -> bool:
	if i == j or not _pair_mergeable(state.hand, i, state.hand, j):
		return false
	state.hand[i].tier += 1
	state.hand.remove_at(j)
	return true

static func grant_cells(state: Dictionary, n: int) -> int:
	if n > 0:
		state.cells += n
	return state.cells

static func place(state: Dictionary, hand_index: int, now: float, cfg: Dictionary = {}) -> bool:
	if hand_index < 0 or hand_index >= state.hand.size() or state.placed.size() >= state.cells:
		return false
	_settle(state, now, cfg)
	state.placed.append(state.hand.pop_at(hand_index))
	return true

static func place_merge(state: Dictionary, hand_index: int, placed_index: int, now: float, cfg: Dictionary = {}) -> bool:
	if not _pair_mergeable(state.hand, hand_index, state.placed, placed_index):
		return false
	_settle(state, now, cfg)
	state.placed[placed_index].tier += 1
	state.hand.remove_at(hand_index)
	return true

static func unplace(state: Dictionary, placed_index: int, now: float, cfg: Dictionary = {}) -> bool:
	if placed_index < 0 or placed_index >= state.placed.size():
		return false
	_settle(state, now, cfg)
	state.hand.append(state.placed.pop_at(placed_index))
	return true

static func sell_hand(state: Dictionary, i: int) -> int:
	if i < 0 or i >= state.hand.size():
		return 0
	return SELL_PER_TIER * int(state.hand.pop_at(i).tier)

static func sell_placed(state: Dictionary, i: int, now: float, cfg: Dictionary = {}) -> int:
	if i < 0 or i >= state.placed.size():
		return 0
	_settle(state, now, cfg)
	return SELL_PER_TIER * int(state.placed.pop_at(i).tier)

static func line_cfg(line: String, cfg: Dictionary = {}) -> Dictionary:
	var lines: Dictionary = cfg.get("lines", DEFAULTS["lines"])
	return lines.get(line, {})

static func line_stier(state: Dictionary, line: String) -> int:
	var total := 0
	for p in state.placed:
		if p.line == line:
			total += int(p.tier)
	return total

static func rate(state: Dictionary, line: String, cfg: Dictionary = {}) -> float:
	return float(line_cfg(line, cfg).get("rate_per_tier_h", 0.0)) * float(line_stier(state, line))

static func bank_cap(state: Dictionary, line: String, cfg: Dictionary = {}) -> float:
	var lc := line_cfg(line, cfg)
	return float(lc.get("bank_base", 0.0)) + float(lc.get("bank_per_tier", 0.0)) * float(line_stier(state, line))

static func pending(state: Dictionary, line: String, now: float, cfg: Dictionary = {}) -> float:
	var bank: float = state.banks.get(line, 0.0)
	var hours: float = maxf(0.0, now - float(state.last)) / 3600.0
	var cap := bank_cap(state, line, cfg)
	if bank >= cap:
		return bank   # an over-cap bank neither accrues nor decays
	return minf(bank + rate(state, line, cfg) * hours, cap)

static func _settle(state: Dictionary, now: float, cfg: Dictionary = {}) -> void:
	if now < float(state.last):
		return
	for line in LINES:
		state.banks[line] = pending(state, line, now, cfg)
	state.last = now

static func _pair_mergeable(list_a: Array, i: int, list_b: Array, j: int) -> bool:
	if i < 0 or j < 0 or i >= list_a.size() or j >= list_b.size():
		return false
	var a: Dictionary = list_a[i]
	var b: Dictionary = list_b[j]
	return a.line == b.line and int(a.tier) == int(b.tier) and int(a.tier) < MAX_TIER
