# Putting Tidy Up on your iPhone

This is the manual-but-mechanical path. A **free Apple ID is enough** to run on your
own device (apps signed this way expire after 7 days — just re-run from Xcode to
refresh). What I've already done for you:

- ✅ Wrote a starter **`export_presets.cfg`** (an "iOS" preset, bundle id
  `com.example.reachzero` — change it, see step 3).
- ⚠️ **Export templates: you'll install these (one click).** My automated download
  kept getting hard-killed by this shell's resource limit at ~400 MB. No problem —
  the Godot editor installs them reliably with its own downloader (step 0).

What's left is on your machine (Xcode is the long pole). Do these in order.

## 0. Install Godot export templates (one-time, ~1.2 GB)

- Open the project in the Godot editor (`godot --path .` then it opens, or open the
  folder from the Project Manager).
- Top menu: **Editor → Manage Export Templates… → Download and Install**.
- Wait for it to finish (a few minutes). This is required for *any* export.

## 1. Install Xcode
- App Store → install **Xcode** (~7 GB, full IDE — not just Command Line Tools).
- After it finishes, open it once (accept the license / let it install components), then:
  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -license accept
  ```

## 2. Add your Apple ID to Xcode
- Xcode → **Settings → Accounts → +** → Apple ID → sign in.
- This creates a free "Personal Team" used to sign the app for your device.

## 3. Set a unique bundle identifier
Bundle ids must be globally unique. Edit `export_presets.cfg` (or do it in step 4's
dialog) and change:
```
application/bundle_identifier="com.example.reachzero"
```
to something like `com.<yourname>.reachzero`.

## 4. Export the Xcode project from Godot
> Godot's iOS export needs Xcode present, so do this **after** step 1.

- Open the project in Godot: `godot --path .` (or open the folder in the editor).
- **Project → Export…** — you'll see the **iOS** preset already there.
- Confirm the **Bundle Identifier** (step 3). Leave **App Store Team ID** blank
  (you'll pick the Team in Xcode for free signing).
- Click **Export Project** → save to `build/ios/ReachZero.xcodeproj`.
- (CLI alternative, once Xcode is installed:
  `godot --headless --path . --export-debug "iOS" build/ios/ReachZero.xcodeproj`)

## 5. Build & run from Xcode
- Open `build/ios/ReachZero.xcodeproj` in Xcode.
- Select the app target → **Signing & Capabilities** → check **Automatically manage
  signing** → choose your **Team** (your name – Personal Team). If Xcode says the
  bundle id is taken, tweak it until it's unique.
- Plug in your iPhone via USB (tap **Trust** on the phone if prompted).
- Pick your iPhone as the run destination (top bar) → press **▶ Run**.

## 6. First-launch trust (one time)
- **iOS 16+:** on the iPhone, Settings → **Privacy & Security → Developer Mode → On**
  (it reboots).
- After the first install, if the app won't open: Settings → General → **VPN & Device
  Management** → tap your developer profile → **Trust**.

The app should now launch on your phone. Re-run from Xcode anytime; with a free
account the signing lasts ~7 days, then just hit Run again.

## Gotchas
- **Free account limits:** ~3 sideloaded apps at once, 7-day cert lifetime.
- **Min iOS version:** preset is set to 13.0; if the build complains, raise it to
  match your device's iOS.
- **What you're testing right now:** the full Tidy Up grove loop — drag-any-to-any
  merging, jobs, and the hand-painted art — so this is a real on-device feel check
  (touch targets, performance, art on a phone screen). After any change, re-export
  (step 4) and Run (step 5) — no re-setup needed.
