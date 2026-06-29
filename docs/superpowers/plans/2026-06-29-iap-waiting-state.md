# IAP Waiting State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show immediate in-game feedback after a real-money Confirm tap while StoreKit is requesting products and opening the native purchase sheet.

**Architecture:** Add one small shared UI helper for the blocking purchase-wait overlay, then call it from the shop and piggy-bank vault real-IAP branches. Keep `Iap.buy(key, callback)` as the completion source; the plugin exposes completion statuses but no “native sheet is visible” event, so the local UI owns the in-flight state.

**Tech Stack:** Godot 4.6 GDScript, existing `Look`, `Overlay`, `Strings`, and headless `SceneTree` tests.

## Global Constraints

- Work in `/Users/xup/dh/merge/.worktrees/codex-iap-waiting-state` on `codex/iap-waiting-state`.
- Run `make test-fast` before completion; run targeted tests during the red/green loop.
- Do not grant purchases until `Iap.buy` returns success in real-IAP mode.
- Off-StoreKit test builds keep the existing direct grant behavior.

---

### Task 1: Shared Purchase Wait Overlay

**Files:**
- Create: `engine/scripts/ui/purchase_wait.gd`
- Test: `engine/tests/purchase_wait_tests.gd`
- Modify: `Makefile`

**Interfaces:**
- Produces: `PurchaseWait.show(host: Control, title: String, message: String) -> Control`
- Produces: `PurchaseWait.close(overlay: Control) -> void`

- [ ] **Step 1: Write the failing test**

Create `engine/tests/purchase_wait_tests.gd` with a `SceneTree` test that builds a root `Control`, calls `PurchaseWait.show(root, "Opening App Store", "Please wait...")`, and asserts the overlay is attached, full-rect, named `PurchaseWaitOverlay`, above the modal layer, contains both labels, contains a non-empty spinner glyph, and can be closed by `PurchaseWait.close`.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://engine/tests/purchase_wait_tests.gd`

Expected: FAIL because `engine/scripts/ui/purchase_wait.gd` does not exist.

- [ ] **Step 3: Implement minimal helper**

Create `purchase_wait.gd` as a static helper that builds a full-screen blocking overlay with a veil, centered parchment card, spinner glyph, title, and message. Use ASCII strings; no cancel button; close safely if already freed.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://engine/tests/purchase_wait_tests.gd`

Expected: PASS.

### Task 2: Wire Shop and Vault Real-IAP Branches

**Files:**
- Modify: `engine/scripts/ui/shop.gd`
- Modify: `engine/scripts/ui/vault.gd`
- Test: `engine/tests/purchase_wait_tests.gd`

**Interfaces:**
- Consumes: `PurchaseWait.show(host, title, message) -> Control`
- Consumes: `PurchaseWait.close(overlay) -> void`

- [ ] **Step 1: Extend the failing test**

Add static-source assertions that `shop.gd` and `vault.gd` preload `purchase_wait.gd`, call `PurchaseWait.show` before `Iap.buy`, and call `PurchaseWait.close` inside the purchase callback.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://engine/tests/purchase_wait_tests.gd`

Expected: FAIL because shop/vault are not wired yet.

- [ ] **Step 3: Wire real-IAP branches**

In both confirm handlers, keep the confirm overlay until the wait overlay is created, then free the confirm overlay, call `Iap.buy`, and close the wait overlay in the callback before grant/refresh. Leave the non-charging branch unchanged.

- [ ] **Step 4: Run tests**

Run:
- `godot --headless --path . -s res://engine/tests/purchase_wait_tests.gd`
- `make test-fast`

Expected: all pass.
