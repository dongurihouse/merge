# Mail Dialog Mock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate and preserve one high-fidelity portrait mail-dialog mock using the approved inbox-card composition.

**Architecture:** Treat the legacy screenshot as content authority and the approved Meadow Sky references as palette, material, and scale authorities. Save the native output and a deterministic `1080x1920` review copy beside the exact prompt under the dialog concept library.

**Tech Stack:** Built-in image generation, ImageMagick for deterministic sizing, Git.

## Global Constraints

- Use the fixed Meadow Sky + Cut-Paper Playground style from `docs/design/art-style-guide.md`.
- Generate a `9:16` portrait source and export the review copy at exactly `1080x1920`.
- Include only the exact UI copy specified by the prompt.
- Do not modify runtime UI.

---

### Task 1: Generate and archive the mail-dialog mock

**Files:**
- Create: `games/grove/assets/_concepts/dialogs/mail_dialog_v1/mail_dialog_v1.prompt.txt`
- Create: `games/grove/assets/_concepts/dialogs/mail_dialog_v1/mail_dialog_v1_source.png`
- Create: `games/grove/assets/_concepts/dialogs/mail_dialog_v1/mail_dialog_v1_1080x1920.png`
- Create: `games/grove/assets/_concepts/dialogs/mail_dialog_v1/README.md`
- Modify: `games/grove/assets/_concepts/dialogs/README.md`

**Interfaces:**
- Consumes: legacy mail screenshot and the tracked Meadow Sky reference images.
- Produces: a self-contained review mock and reusable generation prompt.

- [ ] **Step 1: Generate the portrait source**

  Use the built-in image generator with the exact saved prompt and all references assigned explicit roles.

- [ ] **Step 2: Inspect the generated source**

  Confirm the dialog has one title, three message cards, individual claim actions, one claim-all action, no bottom navigation, and no obvious style drift.

- [ ] **Step 3: Export the review copy**

  Run `magick mail_dialog_v1_source.png -resize 1080x1920^ -gravity center -extent 1080x1920 mail_dialog_v1_1080x1920.png`.

- [ ] **Step 4: Verify the archive**

  Run `identify mail_dialog_v1_source.png mail_dialog_v1_1080x1920.png` and confirm the review copy is exactly `1080x1920`.

- [ ] **Step 5: Commit**

  Run `git add docs/superpowers/specs/2026-07-19-mail-dialog-mock-design.md docs/superpowers/plans/2026-07-19-mail-dialog-mock.md games/grove/assets/_concepts/dialogs && git commit -m "art: add Meadow Sky mail dialog mock"`.
