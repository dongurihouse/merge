# Tidy Up — Scripted Icon Generation Runbook

> **CHATGPT-ONLY (current, user directive 2026-06-10).** Generate exclusively on the fixed ChatGPT
> thread `https://chatgpt.com/c/6a2a1e89-13fc-83e8-9035-42c9ba931433` (Blocks A/B/C). Do NOT use
> Gemini. No A/B picks — process each result directly; spot-Read outputs and re-roll (same prompt
> + one constraint) only on clear failures.
>
> *(Dual-provider mode was tried 2026-06-10 and retired the same day. The working Gemini blocks
> (GEM-A/B/C) remain in `tools/icon_gen_browser.js` marked deprecated, in case it returns. Gemini
> gotchas learned: fresh gens are blob: imgs inside the last `<model-response>` — poll that
> container, NOT global img counts; `fetch()` throws on blob: — download via canvas; first
> multi-download hits Chrome's per-origin permission gate needing one manual Allow.)*

**Goal:** Generate one icon end-to-end without clicking, screenshotting, or any in-between interactive step. Trigger the prompt → poll until the file lands → process and import. ~1–3 min per icon.

**Inputs required per icon:** `<prompt>` text + `<asset_path>` (e.g. `assets/ui/drawer_books.png`).

**Tools used (3 only):**
- `mcp__Claude_in_Chrome__navigate` — one call at the start of the session
- `mcp__Claude_in_Chrome__javascript_tool` — all browser-side work
- `Bash` — local processing + import

**No `computer.left_click`, no `computer.type`, no `computer.screenshot` between trigger and result.**

---

## 0. One-time session setup (browser side)

```
1. mcp__Claude_in_Chrome__tabs_context_mcp { createIfEmpty: true }
   → get a tabId
2. mcp__Claude_in_Chrome__navigate { url: FIXED_THREAD, tabId }
   FIXED_THREAD = "https://chatgpt.com/c/6a2a1e89-13fc-83e8-9035-42c9ba931433"
   ── ALWAYS use this one thread for every generation (keep them all together); do NOT
      open a fresh chat per icon. Block A snapshots the CURRENT image count as the
      baseline before each submit, so a growing thread is fine — the new image pushes
      count past that baseline. If a gen hangs, just resubmit in THIS same thread.
   ── DO NOT add ?temporary-chat=true (image gen is DISABLED in temp chats) and DO NOT
      add ?model=gpt-4o (chatgpt strips it and falls back to the default, usually "Thinking").
3. wait ~3-4s for the page to settle
```

(Use Browser 2 if multiple browsers are connected — that's the logged-in one.)

---

## 1. Per-icon loop

Helper JS lives at [`tools/icon_gen_browser.js`](../tools/icon_gen_browser.js) — INSTALL it once per page load (cat the file into one `javascript_tool` call), then drive with one-liners: `window.tu.submit(...)` / `window.tu.poll()` / `window.tu.download(name)`. Never hand-write inline JS for these steps.

### 1A. Submit the prompt
Paste the **submit** block from `icon_gen_browser.js`, replacing `__PROMPT__` with the icon's prompt (escape any backticks/backslashes).

Returns: `{ ok: true, method: "send-btn", baseline_count: N }` — remember `N`.

### 1B. Poll until the new image appears (every ~10s, max ~36 tries / 6 min)
Paste the **poll** block, replacing `__BASELINE__` with the `baseline_count` from 1A.

- Returns `null` → still generating. Wait 10s and re-call.
- Returns `{ ready: true, w, h, alt, ... }` → image is in the DOM.

**Wait at least 6 minutes before assuming failure.** The "Thinking" model often takes 2–4 minutes (saw 4:13 from submit-to-image on the books drawer). If you've been polling >2 min and want a sanity check **without** taking over, call this diagnostic JS:

```js
({ tail: document.body.innerText.slice(-300), elapsed: Date.now() - window.tu_t0 })
```

If `tail` contains "Thought for Xs" and "Thinking" alternating, gen is in progress — keep polling. If `tail` says "I don't have access to image generation" or asks for clarification, you have to intervene (see Failure modes).

### 1C. Download the bytes to `~/Downloads/`
Paste the **download** block, replacing `__NAME__` with the raw filename (e.g. `"drawer_books_raw.png"`).

Returns: `{ ok: true, size, w, h, type: "image/png" }`. The file is now at `~/Downloads/<name>`.

### 1D. Process + save into the project (host side)

```bash
godot --headless --path /Users/xup/mobile_game -s res://tools/process_icon.gd -- \
  ~/Downloads/<raw_name>.png \
  res://assets/ui/<final_name>.png \
  512
```

`process_icon.gd` flood-fills the background from every border (handles both real-transparent and the ChatGPT "checkerboard preview" RGB output), trims to ink + 14px padding, centers on a square, downsamples to 512×512 RGBA.

Sizes other than 512 are supported — e.g. `256` for `coin.png`.

### 1E. Import (host side)

```bash
godot --headless --path /Users/xup/mobile_game --import
```

Done — the asset is wired into the engine (no code change needed if `assets/ui/<file>.png` is what the engine expects).

---

## Per-icon templates

These wrap §1 with the right prompt/filename per pending icon. Order = highest-leverage first.

### Drawers (per family)

**`assets/ui/drawer_books.png`** (512×512)
> Closed wooden book chest / slipcase with a brass clasp, warm teak wood with teal accent panels, a single book spine peeking out the top. Cozy mobile-game 3D bubble render, ¾ angle, soft cream highlights, gentle drop shadow, transparent background, single object centered. No fantasy, no swords, no armor.

**`assets/ui/drawer_toys.png`** (512×512)
> Closed wooden toy chest with a domed lid and rope handles, warm honey-wood with sunny yellow trim, a stuffed teddy ear or star-block corner peeking from the lid gap. Cozy mobile-game 3D bubble render, ¾ angle, soft cream highlights, gentle drop shadow, transparent background, single object centered. No fantasy.

### Job Ticket

**`assets/ui/ticket_card.png`** (512×320)
> A cute illustrated work-order card — cream paper with rounded corners, a torn-perforation top edge, a folded peach corner, soft warm drop shadow. Empty interior (the game stamps items + checkboxes on top procedurally). Cozy mobile-game 3D bubble render, transparent background, single object centered. No text, no writing.

**`assets/ui/ticket_stamp_done.png`** (256×256)
> A round "JOB DONE" rubber stamp in warm peach with a slight rotation tilt, ink-edge texture. Cozy mobile-game 3D bubble render, transparent background, single object centered.

**`assets/ui/ticket_checkmark.png`** (128×128)
> A chunky cute peach checkmark with a cream outline, slight wobble. Cozy mobile-game 3D bubble render, transparent background, single object centered.

### Fill the Shelf

**`assets/ui/shelf_books.png`** (512×768)
> A warm teak 3-shelf bookcase, ¾ angle, with ghosted book-shaped silhouettes on each shelf (3 per row, dim cream outlines hinting at where books will go). Cozy mobile-game 3D bubble render, soft drop shadow, transparent background, single object centered.

**`assets/ui/dresser_clothes.png`** (512×768)
> A warm coral-painted 4-drawer dresser, ¾ angle, with ghosted folded-clothes silhouettes peeking from each drawer (dim cream outlines). Brass cup handles. Cozy mobile-game 3D bubble render, transparent background, single object centered.

**`assets/ui/toybin_toys.png`** (512×768)
> A round honey-wood toy bin with rope-trim rim, ¾ angle, with ghosted star-block / teddy silhouettes hinting at contents. Cozy mobile-game 3D bubble render, soft drop shadow, transparent background, single object centered.

### Economy

**`assets/ui/coin.png`** (256×256)
> A cute chunky gold coin with a soft tilted ¾ angle, glossy highlight, peach/cream rim, a tiny embossed star or "T" in the center. Cozy mobile-game 3D bubble render, transparent background, single object centered.

**`assets/ui/coin_pile.png`** (512×512)
> A small pile of 4–5 cute gold coins stacked at varied angles, the top one sparkling. Cozy mobile-game 3D bubble render, soft warm shadow, transparent background, single object centered.

**`assets/ui/wallet.png`** (320×320)
> A small coral leather coin pouch with a brass clasp and one gold coin peeking out the top. Cozy mobile-game 3D bubble render, ¾ angle, transparent background, single object centered.

### Narrator

**`assets/ui/wren_bust.png`** (512×512)
> A cute round barn owl from the shoulders up, warm cream + peach feathers, big friendly eyes, tiny bowtie or a clipboard tucked under one wing, soft smile. Cozy mobile-game 3D bubble render, ¾ angle facing slightly right, soft drop shadow, transparent background, warm and approachable.

### Bedroom decor (full prompts in `ROOM_PROMPTS.md`; loop them through the same scripts)

All 8 files are **1024×1280** transparent PNGs except `bedroom_base.png` which is opaque. Drop in `assets/rooms/`. **For consistency: generate the finished room first as a reference, then each piece as a same-position cutout.**

- `bedroom_base.png` — the bare room (walls, floor, window with morning light, no furniture)
- `bedroom_glow.png` — warm light overlay (sun rays + soft glow, semi-transparent)
- `decor_rug.png` — round braided rug, lower-center floor
- `decor_bed.png` — single bed with quilt, mid-left against the wall
- `decor_lamp.png` — small nightstand + cozy round lamp, beside the bed
- `decor_shelf.png` — small bookshelf with books and a tiny toy, right wall
- `decor_plant.png` — friendly potted leafy plant in a corner
- `decor_art.png` — a couple of cute framed pictures above the bed

When processing decor pieces with `process_icon.gd`, **pass the canvas size 1024 1280** as the last two args instead of 512 (or use the default square mode and accept square output for non-base files; the cleanest call is to write a one-line `process_decor.gd` that skips trim/center and just keys out the background — I'll add it when the assets land).

### Helper items (each 256×256)

**`assets/ui/helper_key.png`** — *A chunky cute brass skeleton key with a heart-shaped bow and a soft glossy highlight. Cozy mobile-game 3D bubble render, transparent background, single object centered.*

**`assets/ui/helper_wild.png`** — *A cute rainbow-swirl gem / candy shape with sparkles around it, peachy + mint + coral, glossy. Cozy mobile-game 3D bubble render, transparent background, single object centered.*

**`assets/ui/helper_sweep.png`** — *A cute mini broom-and-dustpan combo, soft honey wood handle, peach bristles, a few dust sparkles. Cozy mobile-game 3D bubble render, transparent background, single object centered.*

**`assets/ui/helper_hint.png`** — *A cute glowing lightbulb with a heart-shaped filament, warm gold inside, soft mint outline. Cozy mobile-game 3D bubble render, transparent background, single object centered.*

**`assets/ui/helper_shuffle.png`** — *Two cute curved arrows chasing each other in a circle, peach + mint two-tone, soft sparkles. Cozy mobile-game 3D bubble render, transparent background, single object centered.*

---

## Failure modes & recoveries

| Symptom | Cause | Fix |
|---|---|---|
| Submit returns `{ ok:false, reason:"NO_EDITOR" }` | Wrong page (login screen, error) | Re-navigate and retry; check Browser 2 is logged in |
| Submit returns `method: "enter-key"` and nothing happens | Send button selector drifted | Open the page and re-find the button (it may have a new `data-testid`); update Block A |
| Poll always returns `null` past ~6 min | Model is slow ("Thinking" can take 5–7 min) or returned text only | Read the chat: `({tail: document.body.innerText.slice(-500)})`. If still "Thinking" past ~6.5 min it's hung → **resubmit the same prompt in the fixed thread** (re-snapshot baseline). If "I don't have access…" → wrong page, navigate back to the FIXED_THREAD url. |
| Submit looks fine but `tail` says "I don't have access to image generation in this temporary chat" | Landed in a temp chat | Navigate back to the FIXED_THREAD url (no `?temporary-chat`) and resubmit. Image gen does NOT work in temp chats. |
| Image `alt` text says "Generated image: Viking helmet…" or some other wrong subject | Model fell back to a stock image instead of calling the gen tool | Send a follow-up: *"That's wrong. Use the image generation tool now and produce: \<prompt\>"*. The third try usually works. |
| `process_icon.gd` says "nothing opaque left" | The icon's main color matched the bg key (e.g. a cream-on-cream subject) | Tighten `BG_MAX_VAL` / `BG_MAX_SAT` in `process_icon.gd`, OR re-prompt asking for a darker outline |
| Downloaded PNG is RGB (no alpha) but bg is *not* a flat checker | ChatGPT served a flattened-on-white version | `process_icon.gd` still handles flat-white bg the same way (bright + achromatic = bg) |

---

## Why this design

- **No clicks/screenshots between trigger and finish** → the loop is reproducible and resumable. If a step fails, re-run that single block; no UI state to recover.
- **Three small JS calls** → each is small enough that `javascript_tool`'s timeout never bites.
- **One shared Godot processor** → all icons go through the exact same flood-fill / trim / center / resize path; no per-icon scripts.
- **Browser → ~/Downloads → res://** → uses the OS download path the browser already trusts; no MCP file-permission issues (which blocked uploading reference images in the pilot).
