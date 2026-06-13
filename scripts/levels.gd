extends RefCounted
##
## Tidy Up — levels for the drag-any-to-any core. Drag any two MATCHING items together to merge
## them up the ladder; clear the board to tidy the space. Cell codes:
##   0  empty   ·   -2 locked drawer   ·   family*100 + tier  (Clothes 101.., Books 201.., Toys 301..)
## `top` = the family's "put away" tier (two of it vaporize). Optional per level:
##   "drawers" {flat_index: contained_code} · "ticket" [{code, count}] · "shelf" [target codes]
##   "covers" [flat_index, ...]  (a dusty cover; a merge next to it puffs it off)
##
## Clearability rule: each family's total weight (sum of 2^(tier-1), counting drawer contents)
## must be a multiple of 2^top so it can fully vaporize.
##
## DISTRICT TILE IDENTITY (see DISTRICTS_SPEC.md — enforced by tests/map_tests.gd):
## a level only uses families already debuted by its district, and the district's signature
## family is the most common one on the board. Linen Lane (tidy_01-04) = pure Clothes ·
## Paperleaf Court (tidy_06/05/07) = Books-dominant + Clothes · Tumble Park (tidy_08-09) =
## Toys-dominant + Books + Clothes.

const LEVELS := [
	{
		"id": "tidy_01",
		"name": "First tidy",
		"rows": 3, "cols": 3, "top": 1,
		"grid": [
			0,   0,   0,
			0, 101, 101,
			0,   0,   0,
		],
		"hint": "Drag one sock onto the other — two of a kind tidy away. Clear the board!",
	},
	{
		"id": "tidy_02",
		"name": "Up the ladder",
		"rows": 4, "cols": 4, "top": 2,
		"grid": [
			101, 101, 101, 101,
			101, 101, 101, 101,
			101, 101, 101, 101,
			101, 101, 101, 101,
		],
		"hint": "Matching items merge into bigger ones — merge those again to put them away.",
	},
	{
		"id": "tidy_03",
		"name": "Locked drawers",
		"rows": 5, "cols": 5, "top": 2,
		"grid": [
			101, 101, 101, 102, 102,
			101, 101, 101, 101, 101,
			102, 102, 101, 101, 101,
			101, 101, 101,  -2,   0,
			 -2,   0,   0,   0,   0,
		],
		"drawers": { 18: 101, 20: 101 },
		"hint": "Locked drawers! Do a merge right next to a drawer and it pops open.",
	},
	{
		"id": "tidy_04",
		"name": "The job ticket",
		"rows": 5, "cols": 5, "top": 3,
		"grid": [
			101, 101, 101, 101, 101,
			101, 101, 101, 101, 101,
			101, 101, 101, 101, 101,
			101, 101, 101, 101, 101,
			101, 101, 101, 101,   0,
		],
		"ticket": [ {"code": 102, "count": 3} ],
		"shelf": [ 103, 103, 103 ],
		"hint": "The ticket shows what to make; the shelf shows what to put away. Tidy it all!",
	},
	{
		"id": "tidy_10",
		"name": "Laundry day",
		"rows": 5, "cols": 5, "top": 3,
		"grid": [
			101, 101, 102, 101, 101,
			101, 102, 101, 101, 101,
			102, 101, 101, 101, 101,
			101, 101, 102,   0,   0,
			 -2,  -2,   0,   0,   0,
		],
		"drawers": { 20: 101, 21: 101 },
		"ticket": [ {"code": 102, "count": 4}, {"code": 103, "count": 2} ],
		"shelf": [ 103, 103, 103 ],
		"hint": "The big one — every basket, every drawer. A proper laundry day!",
	},
	{
		"id": "tidy_06",
		"name": "Under the dust",
		"rows": 5, "cols": 5, "top": 2,
		"grid": [
			201, 201, 201, 201, 101,
			201, 201, 201, 201, 201,
			201, 201, 101, 101, 201,
			101, 201, 201, 201, 201,
			  0,   0,   0,   0,   0,
		],
		"covers": [ 2, 12 ],
		"hint": "Some items hide under dust! A merge right beside one puffs the cover off.",
	},
	{
		"id": "tidy_11",
		"name": "Overdue returns",
		"rows": 5, "cols": 5, "top": 2,
		"grid": [
			201, 201, 201, 201, 201,
			201, 101, 201, 201, 101,
			101, 201, 201, 201, 101,
			201, 201, 201,  -2,   0,
			 -2,   0,   0,   0,   0,
		],
		"drawers": { 18: 201, 20: 201 },
		"covers": [ 0, 9 ],
		"hint": "Dusty shelves and stuck drawers — the library cart waits for no one.",
	},
	{
		"id": "tidy_05",
		"name": "A proper tidy",
		"rows": 5, "cols": 6, "top": 3,
		"grid": [
			201, 201, 201, 201, 201, 201,
			101, 101, 201, 201, 201, 201,
			201, 201, 201, 201, 101, 101,
			101, 101, 101, 101,  -2,  -2,
			  0,   0,   0,   0,   0,   0,
		],
		"drawers": { 22: 201, 23: 201 },   # book drawers (drawer_books art); books 14+2=16, clothes 8
		"ticket": [ {"code": 202, "count": 2}, {"code": 103, "count": 1} ],
		"shelf": [ 203, 203, 103 ],
		"hint": "Everything at once — drawers, a ticket, and a shelf. Tidy the whole room!",
	},
	{
		"id": "tidy_12",
		"name": "Study session",
		"rows": 5, "cols": 6, "top": 3,
		"grid": [
			201, 201, 201, 201, 201, 201,
			201, 201, 101, 101, 201, 201,
			101, 101, 201, 201, 201, 201,
			101, 101, 201, 201, 101, 101,
			  0,   0,   0,   0,   0,   0,
		],
		"covers": [ 3, 14, 20 ],
		"ticket": [ {"code": 202, "count": 3}, {"code": 103, "count": 1} ],
		"shelf": [ 203, 203, 103 ],
		"hint": "Three dusty piles between you and a clear desk. Make it shine!",
	},
	{
		"id": "tidy_07",
		"name": "The whole room",
		"rows": 5, "cols": 6, "top": 3,
		"grid": [
			201, 201, 201, 201, 201, 201,
			201, 201, 101, 101, 201, 201,
			101, 101, 201, 201, 201, 201,
			101, 101, 101, 101,  -2,  -2,
			  0,   0,   0,   0,   0,   0,
		],
		"drawers": { 22: 201, 23: 201 },
		"covers": [ 0, 5 ],
		"ticket": [ {"code": 202, "count": 2}, {"code": 103, "count": 1} ],
		"shelf": [ 203, 203, 103 ],
		"hint": "The whole room — drawers, dust covers, a ticket, and a shelf. Tidy it all!",
	},
	{
		"id": "tidy_08",
		"name": "All tangled up",
		"rows": 5, "cols": 5, "top": 2,
		"grid": [
			301, 301, 301, 301, 201,
			301, 301, 201, 201, 301,
			101, 101, 301, 301, 301,
			101, 101, 301, 201, 301,
			  0,   0,   0,   0,   0,
		],
		"tangles": { 0: 3, 17: 3 },
		"hint": "Some items are roped together — keep tidying and the knots loosen, then they spring free.",
	},
	{
		"id": "tidy_09",
		"name": "Mind the rug",
		"rows": 5, "cols": 5, "top": 2,
		"grid": [
			201, 301, 301, 301, 201,
			101, 301, 301, 301, 101,
			101, 301, 301, 301, 101,
			201, 301, 301, 301, 201,
			  0,   0,   0,   0,   0,
		],
		"floor": [ 6, 7, 8, 11, 12, 13 ],
		"hint": "Clear the rug first! The marked floor brightens as you tidy the things on it.",
	},
	{
		"id": "tidy_13",
		"name": "Knot a problem",
		"rows": 5, "cols": 6, "top": 2,
		"grid": [
			301, 301, 301, 301, 201, 201,
			301, 301, 101, 101, 301, 301,
			101, 101, 301, 301, 301, 301,
			301, 201, 201, 301,  -2,  -2,
			  0,   0,   0,   0,   0,   0,
		],
		"drawers": { 22: 301, 23: 301 },
		"tangles": { 0: 3, 9: 3, 21: 4 },
		"hint": "Tangles AND drawers — every merge loosens the ropes, so just keep tidying.",
	},
	{
		"id": "tidy_14",
		"name": "The play corner",
		"rows": 6, "cols": 6, "top": 2,
		"grid": [
			301, 301, 201, 201, 301, 301,
			301, 101, 301, 301, 101, 301,
			201, 301, 301, 301, 301, 201,
			301, 301, 201, 201, 301, 301,
			101, 101, 201, 201,   0,   0,
			  0,   0,   0,   0,   0,   0,
		],
		"covers": [ 0, 5 ],
		"floor": [ 13, 14, 15, 19, 20, 21 ],
		"ticket": [ {"code": 302, "count": 3} ],
		"hint": "Clear the play rug first, then sweep the whole corner. Big job, big tidy!",
	},
	{
		"id": "tidy_15",
		"name": "The grand tidy",
		"rows": 6, "cols": 6, "top": 3,
		"grid": [
			301, 301, 301, 301, 301, 301,
			301, 301, 201, 201, 301, 301,
			201, 201, 301, 301, 201, 201,
			101, 101, 301, 301, 101, 101,
			101, 101, 201, 201,  -2,  -2,
			101, 101,   0,   0,   0,   0,
		],
		"drawers": { 28: 301, 29: 301 },
		"tangles": { 0: 4, 15: 3 },
		"floor": [ 8, 9, 14, 15 ],
		"ticket": [ {"code": 302, "count": 3}, {"code": 203, "count": 1} ],
		"shelf": [ 303, 303, 203, 103 ],
		"hint": "Everything Tumble Park taught you — ropes, rugs, drawers, the lot. Go get it!",
	},
]
