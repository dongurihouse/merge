# Player Interaction — task log

Input & controls: drag/tap/gestures, drop targets, what responds to a touch — how the PLAYER
acts on the game (dev-tool input lives under Tech & Tooling). Format + rules: `../TASKS.md`
(index) → `~/.claude/docs/engineer.md` §"The task log".

---

### T15 — Wayside plot un-clickable (price pin outside the tap target)   ·   2026-06-13   ·   interaction   ·   done
- **Asked:**          After "what is this 🌰46 bird bath / how do I unlock it" → "i can't click on it to unlock it, fix it."
- **Problem:**        NOT the handler or the rect math (both correct). A wayside plot's tap target is only its 92px sprite holder, but the "🌰N" price chip — the obvious buy affordance — renders BELOW that holder (`pin.position.y = px-6`, ~33px tall). Tapping the bowl bought it; tapping the visible price chip landed ~13px below the hit rect → nothing happened → "can't click it." Shipped this small with order Z/#105.
- **Type:**           new (latent since the wayside coin-sink, eng#105)
- **LLM-reliability:** started LOW-feeling (perceptual "can't click", screen state I couldn't see) → resolved HIGH once reproduced: deterministic geometry (point-in-rect), self-verifiable. **Lesson:** my first hypothesis (zero-size free-Control holder) was WRONG — the probe showed size=92×92 and a center tap bought fine. Testing each hypothesis instead of fixing the obvious-looking one found the real cause. Sibling low-reliability kin: any "tap target vs visible affordance" mismatch on small map pins.
- **Human-in-loop:**  none — proven by headless guard + real-input tool; no eyeball needed.
- **Verification:**   `grove_tests` 301→**302**: new guard taps the PRICE-PIN center via `_on_map_tap` and asserts the buy, plus a regression witness ("pin center is outside the bare holder rect"). Real input: `tools/click_wayside.gd` drives press+release on bowl AND pin — pin `bought=false`→`true` (tap @ y=1021.5, holder bottom 1006). Full sweep green: core4 save32 map19 quest20 grove302 engine6 layout21 smoke + sim 40/40, 0 jams.
- **Iterations:**     3 hypotheses — (1) zero-size holder [REFUTED by headless probe], (2) viewport-scale/real-input [a 1495-px minimized-window FAIL was a quiet_godot harness flake, not the bug], (3) price pin below the hit rect [CONFIRMED, deterministic]. Fix landed pass 1 after correct diagnosis; Dev caught the original miss. Also repaired a worktree `.godot/imported`=0 gap that was silently hanging the suite.
- **Result:**         `home.gd` grows the wayside hit rect by `WAYSIDE_TAP_PAD=40` (covers the pin + a finger margin; zones still hit-tested first). New permanent input tool `tools/click_wayside.gd` (joins click_gate/spot/preview). Commit `776ba55`, merged --no-ff to `main`.
