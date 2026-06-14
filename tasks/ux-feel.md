# UX & Interface + Game Feel & Juice — task log

Readability & layout (HUD, menus, chips, navigation, info design, onboarding) · AND the alive
layer (animation, FX, audio, breathe/bob/floaters, responsiveness). Format + rules: `../TASKS.md`
(index) → `~/.claude/docs/engineer.md` §"The task log".

---

### T3 — Live UI bugs: music spam · water/Lv overlap · Decorate bg · 2026-06-12 · ux · done
- **Asked:** (board screenshot) music console errors; "water is overlapping with player level"; "decorate button background hidden behind the fence."
- **Problem:** music add_child during _ready; water chip + Lv chip at identical coords; btn_leaf nine-patch transparent over the fence.
- **Type:** regression (in-flight S work)
- **LLM-reliability:** high (root-caused from logs + code).
- **Human-in-loop:** none.
- **Verification:** captures — no errors, chips stacked, solid Decorate pill.
- **Iterations:** 1
- **Result:** commit cb5cbd7. *(water/Lv recurred → T10.)*

### T6 — ⚡AF: re-warm the board + HUD legibility · 2026-06-12 · ux/feel · done (AF5 owner-gated)
- **Asked:** "what part of your directions caused the background … to be completely bland and void of any colors?"; "the font is illegible."
- **Problem:** my AC pass over-bleached (light veil erased the meadow + backing off + grey tray); AC4 left the global dark text-outline on the cream pill → blobbed numbers.
- **Type:** regression (of my own AC: AC2/AC3/AC4)
- **LLM-reliability:** low — "warm/relaxing" is the owner's eye; the legibility blob was a concrete fix once diagnosed.
- **Human-in-loop:** required (AF5 "relaxing" call + warm `tray v4` is the artist's).
- **Verification:** captures (colored bg, legible HUD); grove 234.
- **Iterations:** 1 (eng parts); owner caught the original bleach.
- **Result:** commit 2521e46 (re-warm), correcting the AC commits.

### T10 — Water/Lv chip overlap (recurrence) · 2026-06-12 · ux · done
- **Asked:** "water and level are overlapping."
- **Problem:** I cleared only 64px under the Lv chip, but it renders **76px** (font line-height > the icon) — I estimated the height instead of measuring it.
- **Type:** regression (of my entry-85 stacking, part of T3).
- **LLM-reliability:** low when estimated, high when measured — lesson: measure the rect, don't eyeball-estimate.
- **Human-in-loop:** none (owner caught the recurrence).
- **Verification:** measure probe (LV rect S=(128,76)) → `lv_clear` 84 + a permanent **non-overlap assert**.
- **Iterations:** 2 (owner caught 1)
- **Result:** commit eae2a9e.

### T11 — Wallet/HUD icons too small · 2026-06-12 · ux · done
- **Asked:** "these icons are too small."
- **Problem:** wallet icons (24–34px) dwarfed by the 34px numbers.
- **Type:** new (tuning)
- **LLM-reliability:** med — size is judgment; verifiable on-screen + the existing on-screen assert.
- **Human-in-loop:** recommended (final size is taste; owner approved by not re-flagging).
- **Verification:** capture (icons read clearly) + grove 238 wallet-on-screen assert.
- **Iterations:** 1
- **Result:** commit c491ced.

### T14 — Map upgrade / placement / unlock satisfaction · 2026-06-13 · ux/feel · open (eval)
- **Asked:** "make the map upgrade and placement look nice and fun to interact with and satisfying when things are unlocked … evaluate the current state and tell me what's wrong or missing."
- **Problem:** (diagnosed) the END states are lovely (a fully-furnished room) but the JOURNEY is flat — finishing a zone barely changes the map (`_poi_art` keys saturation on `open`/unlocked, NOT `done`/restored, home.gd:275,398-401 → restored vs in-progress differ only by one pill's text/colour); the bought object never animates in (buy juice fires at the TAP point, then a silent `_build_interior/_build_vista` rebuild blinks the sprite in — fx.gd has pop_in/scatter_in unused on the reward); "placement" is dev-only (Debug-gated editor, T1/T2) so the player has no placement agency — they tap a fixed pin to fill a fixed slot. Fails the spec pillar "**visibly restore the homestead / visible renovation**" (TIDY_UP_V2_SPEC.md:10,463).
- **Type:** new (feel/juice) — touches mechanics if placement becomes a player verb
- **LLM-reliability:** **low** — "looks nice / fun / satisfying" is perceptual; verify by capture/composite + owner eyeball, never assert. Sibling low-rel: T6 (re-warm), T11 (icon size).
- **Human-in-loop:** **required** — two Dev design calls before build: (1) is placement a PLAYER verb (drag-to-arrange) or tap-to-fill? (2) how far to push "restored zones come alive" given lux-juice is v2-deferred (MILESTONES.md:217). Reported the eval; awaiting the Dev's steer.
- **Verification:** _(open)_
- **Iterations:** _(open)_
- **Result:** _(open)_
