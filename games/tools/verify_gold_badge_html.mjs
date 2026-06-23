import { readFile } from "node:fs/promises";
import assert from "node:assert/strict";

const htmlPath = new URL("../../docs/art/gold-rounded-badge.html", import.meta.url);
const html = await readFile(htmlPath, "utf8");

assert.match(html, /class="stage"/);
assert.match(html, /class="badge"/);
assert.match(html, /--badge-size\s*:/);
assert.match(html, /--groove-inset:\s*calc\(var\(--badge-size\) \* 0\.040\);/);
assert.match(html, /checkerboard/);
assert.match(html, /\.badge::before/);
assert.match(html, /\.badge::after/);
assert.match(html, /border:\s*1px solid rgba\(181,\s*116,\s*35,\s*0\.50\);/);
assert.match(html, /0 3px 6px rgba\(117,\s*66,\s*17,\s*0\.30\) inset/);
assert.match(html, /0 -2px 3px rgba\(255,\s*255,\s*255,\s*0\.78\) inset/);
assert.doesNotMatch(html, /rgba\(136,\s*89,\s*30/);
assert.doesNotMatch(html, /0 1px 2px rgba\(136,\s*89,\s*30,\s*0\.16\)/);
assert.doesNotMatch(html, /0 6px 14px rgba\(136,\s*89,\s*30,\s*0\.20\)/);
assert.doesNotMatch(html, /0 8px 16px rgba\(136,\s*89,\s*30,\s*0\.22\)/);
assert.doesNotMatch(html, /0 0 0 4px/);
assert.doesNotMatch(html, /0 0 0 6px/);
assert.doesNotMatch(html, /<img\b/i);
assert.doesNotMatch(html, /<canvas\b/i);
assert.doesNotMatch(html, /<script\b/i);
assert.doesNotMatch(html, /https?:\/\//i);

console.log("gold badge html verifier passed");
