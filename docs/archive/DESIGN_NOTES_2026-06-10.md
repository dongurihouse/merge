# Tidy Up — Owner Design Notes (2026-06-10), organized

A brain-dump from the owner, organized into systems. Several ideas **extend** what's
built; a few **contradict locked v1 decisions** — those are flagged ⚠️ and need an
explicit owner decision before any build (see §6). Nothing here is implemented yet.

---

## §1 — The board: from "clear the clutter" to "open the board"

The biggest shift. Today: a fixed authored board you clear to empty. Proposed:

- **Big boards, mostly locked.** e.g. **7×9** with only the center ~5–6 cells open,
  a few items pre-placed. The level GOAL is to **unlock all the locked boxes** —
  meant to take real time, not a 2-minute clear.
- **The Box (generator).** A clickable box in the center **dispenses items**
  (costs **1 Energy per click**). What pops out is chosen smartly:
  - Always the **lowest tier** of an item line (forces more merging).
  - Weighted by **what's around the box** and **what quest givers currently want**
    (solvable, but not too easy).
  - **Anti-stuck guarantee:** if nothing on the board can merge, dispense the lowest
    item that creates a possible merge.
- **Locked boxes open like drawers do now:** a merge **next to** a box unlocks it,
  revealing the items inside. Progression = more complex items unlock later boxes.
- **Multiple item families on one board** (toys merge only with toys, clothes with
  clothes…) so there's never just a single merge path — variety per board.
- **Coins as board items:** merges sometimes drop a coin on the board — click to
  collect 1; merge coins into a bigger coin worth 5. (Coins occupying cells adds
  pressure; eventually the player must collect.)

**What survives from today:** merge-2 of identicals, the families, the
adjacent-merge unlock language (drawers/covers are exactly this, small-scale),
dust covers, the cozy theme.

## §2 — Quests: character-driven asks (the Ticket, evolved)

- **Quest givers** ask for items — some want one item, some several.
- When an asked item exists on the board, the quest icon lights up; **clicking it
  takes the item OFF the board** and hands it to the quest giver, who leaves happy.
- **Completion must SCREAM:** big "hey, you did it!" pop — ideally the quest
  giver's **avatar cheering** (the client busts already exist). Same for drawers:
  both drawer and ticket need to be **more obvious** in the UI, and louder on
  completion.
- Quests are surfaced per district (see §3) and from the home map's quest list.
- ⚠️ Items leaving the board interacts with the clearability/weight rule — needs a
  design pass (asks must be generated against board contents, like the Box logic).

## §3 — World & meta structure

- **The Plaza (home).** After loading → a living hub scene: ambient motion (people/
  cars), interactive spots that lead to puzzles or upgrades, something beautiful at
  the center, and **swipe left/right to pan** the wider scene.
- **Home = a scrollable MAP** with everything on it: locked areas, current asks.
  A button opens the **quest list** — each entry shows its reward and a **Go**
  button that jumps you to the right place.
- **District pages.** Tap a map icon → the district's page: fancy hero art (same
  world style as home), a **progress bar**, and a button showing the district's
  current asks ("3/5"), each ask with its own reward.
- **Player level (top of screen).** Grows as you play; **each level unlocks
  something** along a visible **timeline/track** of upcoming unlocks; level-ups can
  grant **special items** (helpers).
- **Inventory.** Stash an item from the board, use it later.

## §4 — Currencies & pacing — **RESOLVED (owner, 2026-06-10)**

Four currencies, **all earned — no monetization built in v1** (the diamond SYSTEM
exists so purchases could switch on later, but nothing is buyable with money).

| Currency | Earned from | Spent on |
|---|---|---|
| **Stars** | Quests ONLY | **Unlocking the next thing ON the home scene** — a visible object/spot in the current project appears in place (at its default skin). Each unlock grants **EXP + a reward bundle** (can include diamonds/energy/coins). |
| **Energy** | Auto-regen **+1 per 2 min** · level-up rewards · free refills the first few empties · buyable with diamonds | **Every Box pop** (1/click) — the pacing friction |
| **Coins** | Board pickups (1) / coin-merges (5) · quests · rewards | **Personalization**: replace an unlocked home piece with a styled variant (stars buy the default; coins buy the variety) |
| **Diamonds** | **Home-scene unlocks** · **level upgrades** · quest rewards | Fill energy · buy coins · special skin items |

(Owner's list typo'd item 4 as "stars" — it is **diamonds** per the lead-in.)

**No separate "bedroom" screen (owner, 2026-06-10):** the HOME/hub background **IS
the current project** — the space being tidied/renovated is what you see behind the
hub, and star unlocks appear ON it, in place, with the reveal beat. The current
standalone Room screen's decoration role folds INTO the home scene (Room.tscn
retires once the home scene exists). "Archive" was the wrong frame — it's not a
collection menu or new merge lines; it's the **predefined unlock track of the home
scene itself**.

### §4b — The deterministic progression track

The whole chain is **predefined and authored — one deterministic path**, not random:

```
play (Energy → Box pops → merges)
   → QUESTS pay Stars
      → Stars unlock the NEXT SPOT ON THE HOME SCENE (visible, in place, default skin)
         → each unlock grants EXP (+ rewards: diamonds/energy/coins)
            → EXP fills the PLAYER LEVEL → level-ups grant energy/diamonds/helpers
               and unlock features on a visible TIMELINE
                  → diamonds refill energy → more play
Coins (side loop): board pickups → personalize unlocked home pieces with variants
```

Authored tables required: star cost per home-scene unlock + its EXP/reward bundle,
EXP thresholds per level + each level's reward & feature unlock, energy regen/
refill prices, quest ask → star payout. All in one config (EconConfig grows).

## §5 — UX & feel improvements (buildable on what exists today)

1. **Drop zones +50% bigger** while dragging; when enlarged zones overlap, the drop
   resolves to the **closest** target center. (Pure input QoL.)
2. **Idle hint:** if the player idles too long (likely stuck), make two mergeable
   items **pop a little** to show the pair.
3. **Drawer + Ticket prominence:** clearer at-a-glance UI, and completion
   celebrations that pop with the quest-giver avatar (per §2).

## §6 — ⚠️ Conflicts with locked v1 decisions — owner must re-open or reject

| Idea | Locked decision it conflicts with | Status |
|---|---|---|
| **Energy** gating every Box click | "No lives, no energy, never blocked" (fairness pillar) + R1 relax-positioning | **OWNER RE-OPENED 2026-06-10: energy IS in** (deliberate pillar change; softened by regen + free early refills + earnable diamonds) |
| **Diamonds** as purchasable premium currency | "**NO monetization in v1**" | **RESOLVED: diamonds are EARNED-only in v1** (archive unlocks, level-ups, quests) — system built, no IAP wired. No conflict remains. |
| **Generator board / open-the-board goal** | "Board-clear is ALWAYS the only win" + hand-authored fixed boards + the weight clearability rule (the whole map/level/test stack assumes it) | **RESOLVED (owner 2026-06-10): NO authored levels at all.** "This game is not a puzzle anymore — there is really no point of having different boards." ONE persistent generator board is the game. |
| Quest givers **removing items** from the board | Same clearability rule; ticket today only *observes* merges | RESOLVED by the above — clearability retires with authored boards; the Box's anti-stuck dispensing is the new guarantee |
| Big 7×9 mostly-locked boards, slow completion | Current size band (3×3→6×6), "a board is a short cozy session" | RESOLVED by the above — the board is long-running and persistent |
| Stars from quests only → archive/level track | Stars today = per-board performance (★ clear · ★★ goals · ★★★ no-undo) | RESOLVED by the above — per-board stars retire; stars come from quests |

### §6b — Consequences of "no authored levels" (the v2 core)

**Retires:** levels.gd's 15 boards · board-clear win + ZERO screen as the loop beat ·
per-board stars (★/★★/★★★) · move counter & par · the clearability weight rule and
its CI guards · the Jobs map as a LEVEL SELECTOR (pins) · "Next ▶" · per-clear coin
payouts (economy moves to quests/pickups) · Session.next_level handoff.

**Transforms:** the board scene → ONE persistent, SAVED board (grid state survives
sessions) · drawers/covers → the locked-box field covering most of the board ·
Job Ticket → quest givers with item asks (items leave the board) · Jobs map +
district cards → district/project pages (progress + asks + story) · the
earn→spend→reveal room loop → the star-driven home-scene unlock track · undo —
likely retires (with a generator + no fail state there's nothing to undo; decide).

**Survives unchanged:** merge-2 of identical family items · families/tile art ·
adjacent-merge unlock language · all juice/FX · clients/busts · settings/i18n/save
infrastructure · district theming (the board re-skins per current project) ·
quiet-capture/e2e tooling.

**Likely shape (to confirm):** each DISTRICT = one long-running generator-board
"project" — finishing a project (all boxes opened / renovation complete) advances
to the next district with a fresh board, new family debuts, new backdrop. The map
shows projects; the home scene shows the current one's renovation.

**These aren't vetoes** — each was locked for a reason (cozy/can't-lose positioning);
the new direction is closer to the Merge-Mansion economy model. Remaining OPEN rows
decide whether this is an evolution of the current game or a second game mode.

## §7 — What maps cleanly onto existing systems

| New idea | Existing system it grows from |
|---|---|
| Locked boxes opened by adjacent merges | **Drawers** (same trigger, same juice) |
| Quest givers with item asks | **Job Ticket** + client busts |
| Plaza / scrollable home map | **Jobs map** (cards → districts → pins) |
| Star unlocks ON the home scene | **Room decor slots** (Save.rooms model + pins + reveal beats) — relocated onto the home scene; Room.tscn retires |
| District page with progress + asks | District cards + `Districts` data |
| Level-up grants special items | **Helpers** (Wild/Hint/Sweep/Shuffle, spec'd earned-only) |
| Idle hint | The **Hint** helper, made automatic |
| Bigger drop zones | `_pos_to_cell` / `_on_release` input path |
| Avatar cheer on completion | `FX.celebrate` + `assets/map/client_*.png` |

## §8 — Open questions before building any of this

1. Energy + Diamonds: in v1, v2, or never? (This is THE positioning decision.)
2. Does the generator board **replace** the authored clear-the-board levels, or live
   beside them (e.g., districts keep authored jobs; the Plaza adds one persistent
   generator board)?
3. If items can leave the board (quests) and enter it (Box), what's the new
   end-of-board condition — all boxes opened? all asks served?
4. Stars: move entirely to quest rewards, or keep board-stars and rename the
   level-track currency?
5. Inventory size/cost — free slots? coin-priced slots (classic)?
6. Plaza scope: full living scene with ambient agents is big art+code; is a panning
   illustrated backdrop with 3–4 hotspots the v1 version?
