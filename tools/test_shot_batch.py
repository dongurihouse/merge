#!/usr/bin/env python3
"""Guard: `make shot-batch` must produce the same pixels as `make shot`, not merely similar ones.

WHY THIS EXISTS. shot_batch runs many captures in ONE Godot process by re-pointing the live
SceneTree at each tool in turn (engine/tools/shot_batch_runner.gd). That saves ~1.3 s of boot and one
application launch per capture, and it is only worth having if the PNGs are the same ones the
per-capture path produced — a batch that quietly renders something slightly different would be worse
than the launches it saves, because captures get believed.

It is not a theoretical worry. The first working version of the batch already produced two wrong
files: the cozy UI theme installs itself once per process onto the root, so widget_shot — which never
asks for it — came out with the game font behind a grove item and the engine default on its own.
Nothing about the run looked wrong; only the bytes said so.

WHAT IT ASSERTS
  1. POSITION INDEPENDENCE — the same request captured twice in one batch, with other items in
     between, gives byte-identical PNGs. This is the property that makes a batch trustworthy at all.
  2. AGREEMENT WITH THE SINGLE-SHOT PATH — the batch's first item equals the same capture taken in
     its own process.
  3. THE CASCADE GLOW'S PINNED PHASE — `grove cascade` draws light that TRAVELS around the chain's
     contour, so where in its loop the light sits depends on how many frames have gone by, which
     differs between a warm batch process and a fresh boot. engine/scripts/ui/cascade_outline.gd's
     `forced_phase` (set by shot_base.begin) is what makes it capturable at all, and this is the
     guard on it: the batched cascade shot must equal both its twin later in the same batch AND the
     same shot taken alone. Without the pin the two paths differ, so a regression that unpins it
     fails here rather than silently rewriting every cascade capture's bytes.
  4. CLEAN WARM HANDOFF — a later item cannot print a SCRIPT ERROR at exit code 0. The
     cascade-guide → mastery-reveal pair exercises the root-owned audio voice pool across reset.

WHAT IT DELIBERATELY DOES NOT ASSERT. Every item of a long batch is NOT byte-identical to its cold
single-shot twin. A mode whose fixture is still ANIMATING at the capture instant (measured:
`grove ladder`, whose generator twinkle is mid-cycle) lands on a different phase in a warm process
than in a freshly booted one — 1726 pixels of a 2.07-million-pixel image, by at most 30/255. Such a
mode is self-consistent inside the batch path (the same hash at position 3 and position 6) and
self-consistent inside the single path; it is the two paths that disagree. So: compare like with
like — a before/after pair must be captured the same way, both batched or both single. `grove
cascade` is in the compared set precisely because its animation is PINNED, not exempt.

SKIPS (exit 0) when there is nothing to measure: no `godot`, no GUI session, or another quiet run
already owns override.cfg. The real renderer is required — the batch is about pixels.
"""

import hashlib
import os
import platform
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUIET = ROOT / "engine" / "tools" / "quiet_godot.sh"
BATCH = "res://engine/tools/shot_batch.gd"
WIDGET = "res://games/grove/tools/widget_shot.gd"
GROVE = "res://games/grove/tools/grove_shot.gd"
TIMEOUT_S = 300


def skip(reason: str) -> None:
    print(f"SKIP test_shot_batch: {reason}")
    sys.exit(0)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def has_display() -> bool:
    """A GUI session, i.e. something a real-renderer capture can draw into."""
    if platform.system() != "Darwin":
        return True                      # only macOS is checked here; elsewhere let the run speak
    out = subprocess.run(["/usr/sbin/system_profiler", "-json", "SPDisplaysDataType"],
                         capture_output=True, text=True, timeout=60)
    return "spdisplays" in out.stdout.lower()


def run(args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run([str(QUIET), "--path", str(ROOT), *args],
                          capture_output=True, text=True, cwd=str(ROOT), timeout=TIMEOUT_S)


def main() -> int:
    if not shutil.which(os.environ.get("GODOT", "godot")):
        skip("no godot on PATH")
    if not QUIET.exists():
        skip(f"{QUIET} is missing")
    if (ROOT / "override.cfg").exists():
        skip("override.cfg is already present — another quiet run owns it")
    if not has_display():
        skip("no GUI session — the real renderer cannot draw")

    tmp = Path(tempfile.mkdtemp(prefix="tu_shotbatch_"))
    # widget first (it is the cheapest tool, and item 1 is the one compared against a single shot),
    # then a grove item to make the process warm and to change the global state a batch has to
    # reset, then the SAME two again to check position independence. The final cascade→mastery
    # pair makes audio in one Grove scene and uses it in the next, covering the root voice pool.
    plan = tmp / "plan.txt"
    plan.write_text(
        f"widget {tmp}/widget_1.png 104 104:glow\n"
        f"grove hud {tmp}/grove_1.png\n"
        f"grove cascade {tmp}/cascade_1.png phase=staircase\n"
        f"widget {tmp}/widget_2.png 104 104:glow\n"
        f"grove hud {tmp}/grove_2.png\n"
        f"grove cascade {tmp}/cascade_2.png phase=staircase\n"
        f"grove cascade {tmp}/cascade_guide.png phase=guide\n"
        f"grove mastery {tmp}/mastery_reveal.png phase=reveal\n")

    batched = run(["-s", BATCH, "--", str(plan)])
    single = run(["-s", WIDGET, "--", str(tmp / "widget_single.png"), "104", "104:glow"])
    cascade_single = run(["-s", GROVE, "--", "cascade", str(tmp / "cascade_single.png"), "phase=staircase"])

    failures = []
    for name, proc in (("batch", batched), ("single", single), ("cascade single", cascade_single)):
        if proc.returncode != 0:
            failures.append(f"the {name} run exited {proc.returncode} — this guard proves nothing\n"
                            f"{proc.stdout[-2000:]}{proc.stderr[-2000:]}")
        combined = proc.stdout + proc.stderr
        if "SCRIPT ERROR" in combined:
            failures.append(
                f"the {name} run printed a SCRIPT ERROR despite exiting zero — warm-process "
                f"singleton state survived between capture items\n{combined[-2000:]}")
    wanted = ["widget_1.png", "widget_2.png", "grove_1.png", "grove_2.png",
              "cascade_1.png", "cascade_2.png", "cascade_single.png",
              "cascade_guide.png", "mastery_reveal.png", "widget_single.png"]
    missing = [w for w in wanted if not (tmp / w).exists()]
    if missing:
        failures.append(f"missing capture(s): {missing} — nothing was rendered to compare")

    if not failures:
        pairs = [("widget", "widget_1.png", "widget_2.png"),
                 ("grove hud", "grove_1.png", "grove_2.png"),
                 ("grove cascade", "cascade_1.png", "cascade_2.png")]
        for label, a, b in pairs:
            if sha(tmp / a) != sha(tmp / b):
                failures.append(
                    f"`{label}` captured twice in ONE batch gave different bytes ({a} vs {b}). A "
                    f"batch item is leaking state into the next one — see _reset in "
                    f"engine/tools/shot_batch_runner.gd. Files kept at {tmp}.")
        if sha(tmp / "widget_1.png") != sha(tmp / "widget_single.png"):
            failures.append(
                f"the batch's first item does not match the same capture taken on its own "
                f"(widget_1.png vs widget_single.png). `make shot-batch` is meant to be a drop-in "
                f"for `make shot`. Files kept at {tmp}.")
        if sha(tmp / "cascade_1.png") != sha(tmp / "cascade_single.png"):
            failures.append(
                f"a batched `grove cascade` does not match the same capture taken on its own "
                f"(cascade_1.png vs cascade_single.png). The cascade glow's travelling light is "
                f"landing on a different phase in a warm process — check that shot_base.begin still "
                f"pins engine/scripts/ui/cascade_outline.gd's `forced_phase`. Files kept at {tmp}.")

    if failures:
        for f in failures:
            print(f"FAIL: {f}")
        return 1
    shutil.rmtree(tmp, ignore_errors=True)
    print("PASS test_shot_batch: batched captures are position-independent and match the single-shot path")
    return 0


if __name__ == "__main__":
    sys.exit(main())
