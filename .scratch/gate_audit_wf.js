export const meta = {
  name: 'gate-design-vs-code-audit',
  description: 'Audit every progression gate in Tidy Up: design intent vs shipped code, verify each divergence, judge good/bad',
  phases: [
    { title: 'Inventory', detail: 'one agent per gate: extract design intent + code reality' },
    { title: 'Verify', detail: 'adversarially confirm each claimed divergence against the code' },
    { title: 'Empirical', detail: 'run the economy sim + tests, capture current state' },
  ],
}

const ROOT = '/Users/xup/dh/merge'

const DESIGN_FILES = [
  'docs/design/grove_spec.md (the grove-specific instance — authoritative for this game)',
  'docs/design/merge_spec.md (the engine-level design)',
  'docs/FEATURES.md, docs/BACKLOG.md, docs/TASKS.md (status / retired list)',
]
const CODE_FILES = [
  'engine/scripts/core/content.gd (quest generation, soft-gate meter, map_complete/map_unlocked, gate-quest logic)',
  'engine/scripts/core/board_model.gd (cell gating / openable_brambles)',
  'engine/scripts/core/quests.gd, engine/scripts/core/game.gd (loop, map advance)',
  'games/grove/grove_data.gd (the tuning tables: MIN_LEVEL, soft-gate consts, tier consts, generators)',
  'games/grove/game.gd (the grove G singleton: cell_min_level, active_giver_count, etc.)',
  'games/grove/tools/grove_sim.gd (the Monte-Carlo economy sim — what the loop actually does)',
  'games/grove/tests/ suites (what behavior is actually asserted)',
]

const FINDING_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    gate: { type: 'string', description: 'the gate name' },
    design_intent: { type: 'string', description: 'what the DESIGN says this gate is / does, with doc section refs and short quotes' },
    code_reality: { type: 'string', description: 'what the CODE actually implements, with file:line evidence' },
    divergences: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          claim: { type: 'string', description: 'one concrete way code differs from design' },
          design_says: { type: 'string' },
          code_says: { type: 'string' },
          evidence: { type: 'string', description: 'file:line citations on both sides' },
          severity: { type: 'string', enum: ['major', 'moderate', 'minor', 'doc-only'], description: 'major=load-bearing feature gap; doc-only=spec is just stale' },
        },
        required: ['claim', 'design_says', 'code_says', 'evidence', 'severity'],
      },
    },
    matches: { type: 'string', description: 'what DOES match design (so the report is balanced)' },
  },
  required: ['gate', 'design_intent', 'code_reality', 'divergences', 'matches'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    confirmed: { type: 'boolean', description: 'true if the divergence is real after checking the code yourself' },
    correction: { type: 'string', description: 'if not confirmed OR partially wrong, the corrected statement with evidence; empty if fully confirmed' },
    extra_evidence: { type: 'string', description: 'any additional file:line you found that strengthens or weakens the claim' },
  },
  required: ['confirmed', 'correction', 'extra_evidence'],
}

const GATES = [
  {
    key: 'soft-star-gate',
    prompt: `The SOFT STAR-GATE (a.k.a. gate_pause / the metered fence): meters how many quest-givers (stands) are active to roughly the stars still needed for the next unlock, capped at MAX_GIVERS, and EMPTIES the fence once the player can afford the next unlock. Look at active_giver_count / the giver meter in content.gd, MAX_GIVERS + STARS_PER_QUEST_EST in grove_data.gd, and how grove_sim.gd refills the fence. Compare to grove_spec section 7 "Metered fence" and merge_spec section 7 "Stars & the soft gate".`,
  },
  {
    key: 'level-board-gate',
    prompt: `The LEVEL GATE on board cells (the section-4 obstacle field): cells sealed until the player's level reaches the cell's number, then opening on the next adjacent merge. Look at MIN_LEVEL grid in grove_data.gd, cell_min_level() in games/grove/game.gd, openable_brambles() in board_model.gd. Compare to merge_spec section 4 (the L2..L12 diamond, "every cell by ~L12", corners last) and grove_spec section 4. Note exact gate values: does code reach L12 at corners or something else? Is the FTUE board (L1) what the spec describes?`,
  },
  {
    key: 'map-completion-gate',
    prompt: `The MAP-UNLOCK GATE / completion chain / the great-spirit's GATE QUEST. The DESIGN (grove_spec section 3/7/8, merge_spec section 7/8) centers a "gate quest": when a map's spots are all restored it UNVEILS the gatekeeper's (great-spirit/heart-tree) gate quest — a randomized handful of the map's TOP-TIER harvest, the ONLY quest asking the ceiling/t8, deliberately hard, "an act of care not a toll" — and DELIVERING it unlocks the next map for a large reward; described as "the pacing spine" and the per-map narrative climax (wisp escalation Farmhouse to Meadow). Determine what the CODE actually does: does the gate quest exist? Check content.gd map_complete/map_spots_done/map_unlocked (around lines 429-465), the "gate QUEST is retired" comment, and grove_sim.gd ("There is NO gate quest", spots-done trigger ~lines 21,435,450). Quote exact code comments. This is the headline gate — be exhaustive about what was cut and what replaced it.`,
  },
  {
    key: 'generator-grant-gate',
    prompt: `The GENERATOR arrival/grant mechanism. DESIGN history: an old "evolve-merge", then a "hand-in" (hand a finished map's generator in for the next map's, the old line "graduates" into the Collection) — see merge_spec section 6, grove_spec section 2 ("a hand-in, not a merge"), and the narrative "even your producers carry forward". What does the CODE do now? Check GENERATORS table + grant_from "vestigial" comment in grove_data.gd, content.gd around lines 143-146 ("Generators now PERSIST (never handed in)... rides on an ordinary near-end quest's reward.generators"). Is the hand-in gone? Do generators persist? How does the next map's generator actually arrive?`,
  },
  {
    key: 'spot-and-tier-gate',
    prompt: `Two related gates: (1) RESTORATION SPOT gating — design says spots are STARS-ONLY now (spot_level_gates retired, no second coin axis) per grove_spec section 8/flags, BUT merge_spec section 8 still says spots are "gated by progress (Stars) + level" in places (lines ~273,279). Determine what code does (content.gd map_cheapest_spot / unlocks; is there any spot level requirement?). Flag the internal merge_spec contradiction. (2) The TIER CEILING gate: design says a map's ceiling (up to t8) is asked ONLY by the gate quest, never a regular quest (merge_spec section 7, grove_spec section 7). But code has TOP_TIER=12, PREMIUM_TIER=8, and content.gd ~line 265 says the asked ceiling "climbs with level up to TOP_TIER, which IS askable (no gate-ceiling)". Determine: with the gate quest retired, what is the actual asked tier ceiling for regular quests, and where does t8/PREMIUM_TIER vs TOP_TIER=12 actually matter (diamond-earn, sell)? Cite file:line.`,
  },
]

phase('Inventory')
const inventoryNote = `You are auditing the Godot game "Tidy Up (Donguri Merge)" at ${ROOT}. Compare DESIGN to SHIPPED CODE for one specific gate.
DESIGN files: ${DESIGN_FILES.join('; ')}.
CODE files: ${CODE_FILES.join('; ')}.
Read BOTH sides yourself (use Read/Grep). Every claim MUST carry a file:line citation. Quote the design's own words and the code's own comments. Be precise about what matches AND what diverges — do not invent divergences, and do not miss real ones. The grove_spec is the authoritative game-specific design; merge_spec is the engine design and may itself be internally stale.`

const results = await pipeline(
  GATES,
  function (g) {
    return agent(inventoryNote + '\n\nGATE TO AUDIT: ' + g.prompt, {
      label: 'inventory:' + g.key, phase: 'Inventory', schema: FINDING_SCHEMA,
    })
  },
  function (finding, g) {
    if (!finding || !finding.divergences || finding.divergences.length === 0) return finding
    return parallel(finding.divergences.map(function (d, i) {
      return function () {
        return agent('Adversarially verify ONE claimed design-vs-code divergence in the Tidy Up game at ' + ROOT + '. Try to REFUTE it: open the actual code and design files and check whether the claim is accurate. A claim is FALSE if the feature is actually implemented somewhere the auditor did not look, or the design does not actually say what is claimed. Default to confirmed=false if you cannot find supporting evidence yourself.\n\nCODE files: ' + CODE_FILES.join('; ') + '\nDESIGN files: ' + DESIGN_FILES.join('; ') + '\n\nCLAIM: ' + d.claim + '\nDesign allegedly says: ' + d.design_says + '\nCode allegedly says: ' + d.code_says + '\nCited evidence: ' + d.evidence, {
          label: 'verify:' + g.key + '#' + i, phase: 'Verify', schema: VERDICT_SCHEMA,
        }).then(function (v) { return { gate: g.key, divergence: d, verdict: v } })
      }
    }))
  }
)

phase('Empirical')
const empirical = await agent('Capture the CURRENT empirical state of the Tidy Up game economy/gates at ' + ROOT + '.\n1. Run `cd ' + ROOT + ' && make test-fast` and report pass/fail summary.\n2. Run the Monte-Carlo economy sim headless and capture its key output, especially anything about no-strand, map completion, the soft gate / fence metering, and pacing. The sim is games/grove/tools/grove_sim.gd; its file header documents how to run it. Try `godot --headless --path ' + ROOT + ' -s res://games/grove/tools/grove_sim.gd` (or check the Makefile for a sim target). Headless ONLY — if it needs a real window, do not run it and say so.\n3. Report the concrete numbers the sim prints (spots completed, jams/strands, maps reached, fence behavior, any PASS/WARN/FAIL lines). Quote the actual output lines.\nReturn a concise factual summary of what currently happens when the game economy runs — no interpretation, just observed state and the commands you ran.', { label: 'run:sim+tests', phase: 'Empirical' })

const verified = results.flat().filter(Boolean)
const inventory = verified.filter(function (x) { return x && x.gate && x.design_intent })
const verdicts = verified.filter(function (x) { return x && x.verdict })

return { inventory, verdicts, empirical }
