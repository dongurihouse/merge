# Gold Rounded Badge HTML Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone HTML/CSS drawing of the cream-gold rounded square badge from the reference image.

**Architecture:** The deliverable is one browser-openable HTML document. CSS custom properties define the badge size and color tokens, while pseudo-elements provide the raised rim, inset groove, and surface highlight.

**Tech Stack:** HTML5, CSS3, Node.js built-in modules for verification.

## Global Constraints

- Output file must be `docs/art/gold-rounded-badge.html`.
- Badge must be drawn with HTML and CSS only.
- The file must not reference external images, scripts, fonts, or stylesheets.
- The badge size must be controlled by `--badge-size`.

---

### Task 1: Standalone Badge HTML

**Files:**
- Create: `docs/art/gold-rounded-badge.html`
- Create: `games/tools/verify_gold_badge_html.mjs`

**Interfaces:**
- Consumes: no existing project code.
- Produces: a standalone HTML file and a verifier command: `node games/tools/verify_gold_badge_html.mjs`.

- [x] **Step 1: Write the failing verifier**

```javascript
import { readFile } from "node:fs/promises";
import assert from "node:assert/strict";

const htmlPath = new URL("../../docs/art/gold-rounded-badge.html", import.meta.url);
const html = await readFile(htmlPath, "utf8");

assert.match(html, /class="stage"/);
assert.match(html, /class="badge"/);
assert.match(html, /--badge-size\s*:/);
assert.match(html, /checkerboard/);
assert.match(html, /\.badge::before/);
assert.match(html, /\.badge::after/);
assert.doesNotMatch(html, /<img\b/i);
assert.doesNotMatch(html, /<canvas\b/i);
assert.doesNotMatch(html, /<script\b/i);
assert.doesNotMatch(html, /https?:\/\//i);

console.log("gold badge html verifier passed");
```

- [x] **Step 2: Run verifier to confirm it fails before implementation**

Run: `node games/tools/verify_gold_badge_html.mjs`

Expected: failure because `docs/art/gold-rounded-badge.html` does not exist yet.

- [x] **Step 3: Write the standalone HTML**

Create `docs/art/gold-rounded-badge.html` with the same structure and CSS selectors used by the verifier:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Gold Rounded Badge</title>
  <style>
    :root { --badge-size: min(74vmin, 270px); }
    .checkerboard { background-image: conic-gradient(from 90deg, #efefef 25%, #ffffff 0 50%, #efefef 0 75%, #ffffff 0); }
    .stage { display: grid; min-height: 100vh; place-items: center; }
    .badge { position: relative; width: var(--badge-size); aspect-ratio: 1; border-radius: calc(var(--badge-size) * 0.215); }
    .badge::before { position: absolute; content: ""; }
    .badge::after { position: absolute; content: ""; }
  </style>
</head>
<body class="checkerboard">
  <main class="stage" aria-label="CSS drawing of a gold rounded square badge">
    <div class="badge" role="img" aria-label="Soft gold rounded square badge"></div>
  </main>
</body>
</html>
```

- [x] **Step 4: Run verifier to confirm it passes**

Run: `node games/tools/verify_gold_badge_html.mjs`

Expected: `gold badge html verifier passed`

- [x] **Step 5: Run project checks**

Run: `make test-fast`

Expected: all active engine suites pass.

- [ ] **Step 6: Render-check the HTML**

Open `docs/art/gold-rounded-badge.html` in a browser-capable render path and confirm the badge is centered, rounded, cream-gold, and has visible outer/inset rim layers.
