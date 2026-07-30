#!/usr/bin/env python3
"""Guard: a quiet capture must not put a window on the owner's screen, or take their keyboard.

WHY THIS EXISTS. engine/tools/quiet_godot.sh shipped for months claiming the capture window was
"born minimized" and never seen. It was only ever verified against FOCUS (`lsappinfo front`), and
that part was true — the app never became frontmost. Nobody measured VISIBILITY, and the window was
in fact composited at full size for ~1000 ms on every capture (~2900 ms for the workbenches): the
`window/size/mode=1` project setting is not honoured at window creation on macOS, so the only thing
hiding the window was an in-script `window_set_mode(MINIMIZED)` that ran ~460 ms into boot and then
played macOS's synchronous ~560 ms genie animation. A claim nothing tests is a claim that rots.

WHAT IT MEASURES. One real capture is run while this process walks CGWindowListCopyWindowInfo every
30 ms, keeping only windows owned by the capture's own process tree, and intersects each window's
bounds with the real display rects. The check is on AREA, not presence: the capture window is born
1x1 just past the screen's bottom-right corner (Godot clamps a BIRTH position into the usable rect,
so the corner is as far out as a window can be born) and macOS reports its frame one point larger on
every side, so a single corner point of shadow fringe can touch the screen before shot_base parks the
window at (-32000, -32000). With the shim in place that fringe is composited for <=23 ms of a ~1.5 s
run; with the shim disabled it is on screen for 210 ms. Either way the area is 1 pt^2 — that is the
floor on this platform. A regression to the old behaviour is a ~1.1-million-point overlap — four
orders of magnitude over the limit here, so this is a wide, non-flaky margin, not a tuned threshold.

TWO WINDOW LISTS, TWO JOBS. The on-screen list (`.optionOnScreenOnly`) answers "did this paint over
the owner's desktop", and only it can: a window that exists but is composited nowhere covers nothing,
so the AREA check reads that list and no other. It cannot carry the PRECONDITION, because the fix's
whole point is that the window is hardly ever composited — measured with a 23 ms sampler over 6 runs,
the capture's window appears in the on-screen list in 5 runs, exactly ONE sample each, which the
35 ms walk here misses outright. That is why "never saw a window owned by the capture process" used
to fire on a passing run. The precondition therefore reads the ALL-windows list (the same call with
kCGWindowListExcludeDesktopElements alone, no extra permission), where the same window is present in
6/6 runs for ~60 samples, from ~180 ms to process exit. Windows are attributed to the capture by
PROCESS TREE membership, never by owner name: a Prohibited process is not an app and can report an
empty owner name.

WHERE THE PIDS COME FROM. The capture's pids are enumerated from the process tree (`ps`, refreshed
every 250 ms), not from window sightings. That is what lets the policy sampling below cover the WHOLE
run: the policy is readable from ~65 ms into a ~1.5 s run, while Launch Services' promotion — the
thing that check exists to catch — lands at ~575 ms, and a sightings-driven sampler would not have
started until after it. A run in which no capture process ever had a readable policy is a FAIL, not a
pass: the focus and foreground numbers mean nothing when the instrument was never live.

AND WHAT IT MEASURES SECOND. Hiding the window was only half of "quiet": the capture also became the
FRONTMOST APPLICATION and stayed there until it exited — measured, 500-1500 ms per launch on a
machine whose owner is typing. The area check above passed throughout, because area is not focus.
That is the same mistake in the other direction, so this run now also samples NSWorkspace's frontmost
application every 2 ms and fails if the capture ever owns the keyboard for longer than
MAX_FOCUS_MS. The residue it tolerates is the one measured after engine/tools/nofocus_shim.m lands
(a single ~15 ms activation that the shim answers from inside the process); the behaviour it exists
to catch is two orders of magnitude larger.

It samples the activation POLICY as well, which is the cause rather than the symptom, and the two
are not interchangeable: the run that sent this guard red on 2026-07-30 was frontmost for 0 ms in 0
grabs and foreground-ELIGIBLE for 878 ms. See MAX_FOREGROUND_MS.

NEGATIVE CONTROL, and it is a mode of this guard rather than a note about one:

    TU_NOFOCUS=0 python3 tools/test_quiet_window.py

runs the same capture with the shim disabled (TU_NOFOCUS is the variable quiet_godot.sh reads) and
INVERTS the expectation — the guard must FAIL, and a run that produces no failures is itself the
failure, because a guard that passes an unshimmed capture is measuring nothing. Measured unshimmed:
on screen 210 ms, worst overlap 1 pt^2, foreground-eligible 502 ms and 608 ms over two runs. It is
the FOREGROUND check that fires there, not the area one. On top of that, a pure self-check of the
failure decisions runs on EVERY invocation before any capture launches: the measured-good vector must
produce no failures and the recorded pre-fix defect vector must produce failures naming the area,
focus and foreground checks, or the guard fails without running anything.

SKIPS (exit 0, with the reason printed) when there is nothing to measure: not macOS, no `godot`, no
GUI session (no active displays), or another quiet run already owns override.cfg. CI is headless, so
it skips there; it is the dev machine — the one with an owner to interrupt — that it protects.
"""

import collections
import ctypes
import ctypes.util
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUIET = ROOT / "engine" / "tools" / "quiet_godot.sh"
# The cheapest real-renderer capture (no board fixture, no map scene) — this guard is about the
# window, not about what is drawn in it.
TOOL = "res://games/grove/tools/widget_shot.gd"

SAMPLE_S = 0.030
# How often the process tree is re-read while the capture runs. A `ps` costs 10-15 ms, so it is not
# run on every 30 ms walk once a policy-readable process has been found — before that it is, because
# nothing can be sampled until the tree is known.
TREE_REFRESH_S = 0.250
# Largest on-screen overlap (square points) a capture window may ever have. The measured floor is
# 1 point (the corner of a 1x1 window's fringe); a full-size window is >1_000_000.
MAX_OVERLAP_AREA = 16
GRACE_S = 0.4          # keep sampling briefly after the capture exits

# Focus. Reading the frontmost application costs ~4 us, so it is sampled far finer than the window
# list — fine enough to resolve the single brief activation the shim cannot pre-empt (measured 15 ms)
# instead of averaging it away.
FOCUS_SAMPLE_S = 0.002
# Longest the capture may own the keyboard, in total, across one run. Measured: ~15 ms with
# engine/tools/nofocus_shim.m in place, 500-1500 ms without it. Anything in between is a regression
# worth failing on, so this sits an order of magnitude above the floor and an order below the defect.
MAX_FOCUS_MS = 150
# Longest the capture process may remain a REGULAR (foreground-eligible) application. The theft
# itself is intermittent — the same unshimmed recipe took the keyboard on some runs and not on
# others — so a guard that only watched for it would pass on a bad build about as often as not.
# Being Regular is not intermittent: Launch Services promotes the capture at its check-in (~575 ms
# into a 1.5 s run) on EVERY run, whatever macOS then decides about activating it.
#
# Measured on this machine, widget_shot, one capture, sampled at FOCUS_SAMPLE_S:
#
#     no shim at all                              ~1100 ms of a 1.3 s run
#     shim answering the activation NOTIFICATION    606 ms when macOS declined the activation
#                                                  6-35 ms when it granted it (n=15)
#     shim POLLING the policy (current)                0 ms, n=21, both cases
#
# That middle row is why this limit is 200 and not 40: the notification-only shim's residue was a
# coin flip on something the process does not control, so a threshold tight enough to catch it on a
# lucky run would be inside its own floor. 200 ms sits an order of magnitude above today's residue
# and well below every regression band, and the coin flip itself is gone — see the WHY POLLING
# section of engine/tools/nofocus_shim.m.
MAX_FOREGROUND_MS = 200
# Least time at least one capture process must have had a READABLE activation policy, i.e. how long
# the foreground instrument was actually live. Measured: readable from ~65 ms to process exit, ~1.4 s
# of a ~1.5 s run. 200 ms is a wide margin under that; below it the focus/foreground numbers are not
# evidence of anything and the run must not be reported as a pass.
MIN_POLICY_MS = 200

# The environment variable quiet_godot.sh reads to decide whether to inject the focus shim. Setting
# it to 0 here turns this guard into its own negative control — see the module docstring.
NEGATIVE_CONTROL = os.environ.get("TU_NOFOCUS", "1") == "0"


def skip(reason: str) -> None:
    print(f"SKIP test_quiet_window: {reason}")
    sys.exit(0)


# --- CoreGraphics via ctypes (no pyobjc on this machine, and none should be required) ----------

class CGPoint(ctypes.Structure):
    _fields_ = [("x", ctypes.c_double), ("y", ctypes.c_double)]


class CGSize(ctypes.Structure):
    _fields_ = [("width", ctypes.c_double), ("height", ctypes.c_double)]


class CGRect(ctypes.Structure):
    _fields_ = [("origin", CGPoint), ("size", CGSize)]


def _load(name: str, fallback: str):
    path = ctypes.util.find_library(name) or fallback
    return ctypes.CDLL(path)


try:
    CF = _load("CoreFoundation", "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
    CG = _load("CoreGraphics", "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
except OSError as exc:                                    # pragma: no cover - platform guard
    skip(f"cannot load CoreGraphics ({exc})")

CF.CFStringCreateWithCString.restype = ctypes.c_void_p
CF.CFStringCreateWithCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint32]
CF.CFArrayGetCount.restype = ctypes.c_long
CF.CFArrayGetCount.argtypes = [ctypes.c_void_p]
CF.CFArrayGetValueAtIndex.restype = ctypes.c_void_p
CF.CFArrayGetValueAtIndex.argtypes = [ctypes.c_void_p, ctypes.c_long]
CF.CFDictionaryGetValue.restype = ctypes.c_void_p
CF.CFDictionaryGetValue.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
CF.CFNumberGetValue.restype = ctypes.c_bool
CF.CFNumberGetValue.argtypes = [ctypes.c_void_p, ctypes.c_long, ctypes.c_void_p]
CF.CFStringGetCString.restype = ctypes.c_bool
CF.CFStringGetCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long, ctypes.c_uint32]
CF.CFRelease.argtypes = [ctypes.c_void_p]
CG.CGWindowListCopyWindowInfo.restype = ctypes.c_void_p
CG.CGWindowListCopyWindowInfo.argtypes = [ctypes.c_uint32, ctypes.c_uint32]
CG.CGRectMakeWithDictionaryRepresentation.restype = ctypes.c_bool
CG.CGRectMakeWithDictionaryRepresentation.argtypes = [ctypes.c_void_p, ctypes.POINTER(CGRect)]
CG.CGGetActiveDisplayList.restype = ctypes.c_int32
CG.CGGetActiveDisplayList.argtypes = [ctypes.c_uint32, ctypes.POINTER(ctypes.c_uint32),
                                      ctypes.POINTER(ctypes.c_uint32)]
CG.CGDisplayBounds.restype = CGRect
CG.CGDisplayBounds.argtypes = [ctypes.c_uint32]

UTF8 = 0x08000100
ON_SCREEN_ONLY = 1
EXCLUDE_DESKTOP = 16
NUM_SINT64 = 4

_KEYS: dict[str, ctypes.c_void_p] = {}


def key(name: str) -> ctypes.c_void_p:
    if name not in _KEYS:
        _KEYS[name] = CF.CFStringCreateWithCString(None, name.encode(), UTF8)
    return _KEYS[name]


def cf_int(ref) -> int:
    out = ctypes.c_int64(0)
    if not ref or not CF.CFNumberGetValue(ref, NUM_SINT64, ctypes.byref(out)):
        return -1
    return out.value


def cf_str(ref) -> str:
    if not ref:
        return ""
    buf = ctypes.create_string_buffer(256)
    if not CF.CFStringGetCString(ref, buf, 256, UTF8):
        return ""
    return buf.value.decode(errors="replace")


def displays() -> list[tuple[float, float, float, float]]:
    count = ctypes.c_uint32(0)
    CG.CGGetActiveDisplayList(0, None, ctypes.byref(count))
    ids = (ctypes.c_uint32 * max(1, count.value))()
    CG.CGGetActiveDisplayList(count.value, ids, ctypes.byref(count))
    out = []
    for i in range(count.value):
        r = CG.CGDisplayBounds(ids[i])
        out.append((r.origin.x, r.origin.y, r.size.width, r.size.height))
    return out


def _window_list(option: int) -> list[tuple[int, str, tuple[float, float, float, float]]]:
    """(pid, owner, (x, y, w, h)) for every window the window server reports under `option`."""
    arr = CG.CGWindowListCopyWindowInfo(option, 0)
    if not arr:
        return []
    try:
        out = []
        for i in range(CF.CFArrayGetCount(arr)):
            win = CF.CFArrayGetValueAtIndex(arr, i)
            bounds = CF.CFDictionaryGetValue(win, key("kCGWindowBounds"))
            rect = CGRect()
            if not bounds or not CG.CGRectMakeWithDictionaryRepresentation(bounds, ctypes.byref(rect)):
                continue
            out.append((
                cf_int(CF.CFDictionaryGetValue(win, key("kCGWindowOwnerPID"))),
                cf_str(CF.CFDictionaryGetValue(win, key("kCGWindowOwnerName"))),
                (rect.origin.x, rect.origin.y, rect.size.width, rect.size.height),
            ))
        return out
    finally:
        CF.CFRelease(arr)


def on_screen_windows() -> list[tuple[int, str, tuple[float, float, float, float]]]:
    """Only what the window server is COMPOSITING — the one list that can answer "did this cover
    the owner's screen". It is a poor detector of the capture: with the shim in place the window is
    on this list for a single sample of one run in six."""
    return _window_list(ON_SCREEN_ONLY | EXCLUDE_DESKTOP)


def all_windows() -> list[tuple[int, str, tuple[float, float, float, float]]]:
    """Every window that EXISTS, composited or not. Presence here is the precondition ("the sampler
    is attached to the right process"), never the area measurement — a window that exists off-screen
    covers nothing, and counting it as coverage would be a false FAIL."""
    return _window_list(EXCLUDE_DESKTOP)


def overlap_area(rect, screens) -> float:
    x, y, w, h = rect
    total = 0.0
    for sx, sy, sw, sh in screens:
        ox = max(0.0, min(x + w, sx + sw) - max(x, sx))
        oy = max(0.0, min(y + h, sy + sh) - max(y, sy))
        total += ox * oy
    return total


# --- who owns the keyboard: NSWorkspace via the ObjC runtime (no pyobjc on this machine) -------
#
# objc_msgSend is variadic and its return type changes per selector, so each signature gets its own
# ctypes prototype cast off the same symbol — reassigning `restype` on one shared prototype crashes
# the interpreter. Every call is wrapped in an autorelease pool: this runs thousands of times.

try:
    OBJC = _load("objc", "/usr/lib/libobjc.dylib")
    ctypes.CDLL(ctypes.util.find_library("AppKit") or
                "/System/Library/Frameworks/AppKit.framework/AppKit")
except OSError as exc:                                    # pragma: no cover - platform guard
    skip(f"cannot load the ObjC runtime / AppKit ({exc})")

OBJC.objc_getClass.restype = ctypes.c_void_p
OBJC.objc_getClass.argtypes = [ctypes.c_char_p]
OBJC.sel_registerName.restype = ctypes.c_void_p
OBJC.sel_registerName.argtypes = [ctypes.c_char_p]
_SEND_OBJ = ctypes.cast(OBJC.objc_msgSend,
                        ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p))
_SEND_I32 = ctypes.cast(OBJC.objc_msgSend,
                        ctypes.CFUNCTYPE(ctypes.c_int32, ctypes.c_void_p, ctypes.c_void_p))
_SEND_OBJ_I32 = ctypes.cast(OBJC.objc_msgSend,
                            ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p,
                                             ctypes.c_int32))
_SEND_I64 = ctypes.cast(OBJC.objc_msgSend,
                        ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_void_p, ctypes.c_void_p))
_POOL_CLASS = OBJC.objc_getClass(b"NSAutoreleasePool")
_RUNNING_APP_CLASS = OBJC.objc_getClass(b"NSRunningApplication")
_WORKSPACE = _SEND_OBJ(OBJC.objc_getClass(b"NSWorkspace"), OBJC.sel_registerName(b"sharedWorkspace"))

POLICY_REGULAR = 0      # a normal app: Dock icon, app switcher, and ELIGIBLE to become frontmost


def activation_policy(pid: int) -> int:
    """A process's NSApplicationActivationPolicy: 0 Regular, 1 Accessory, 2 Prohibited, -1 unknown.

    This is the CAUSE behind the focus theft, and unlike the theft itself it is not intermittent: a
    Regular capture is one the window server may hand the keyboard to at any moment, whether or not
    it did on this particular run."""
    pool = _SEND_OBJ(_SEND_OBJ(_POOL_CLASS, OBJC.sel_registerName(b"alloc")),
                     OBJC.sel_registerName(b"init"))
    try:
        app = _SEND_OBJ_I32(_RUNNING_APP_CLASS,
                            OBJC.sel_registerName(b"runningApplicationWithProcessIdentifier:"), pid)
        if not app:
            return -1
        return _SEND_I64(app, OBJC.sel_registerName(b"activationPolicy"))
    finally:
        _SEND_OBJ(pool, OBJC.sel_registerName(b"drain"))


def frontmost_pid() -> int:
    """The pid of the application that would receive the owner's next keystroke (-1 if none)."""
    pool = _SEND_OBJ(_SEND_OBJ(_POOL_CLASS, OBJC.sel_registerName(b"alloc")),
                     OBJC.sel_registerName(b"init"))
    try:
        app = _SEND_OBJ(_WORKSPACE, OBJC.sel_registerName(b"frontmostApplication"))
        if not app:
            return -1
        return _SEND_I32(app, OBJC.sel_registerName(b"processIdentifier"))
    finally:
        _SEND_OBJ(pool, OBJC.sel_registerName(b"drain"))


# --- process-tree attribution ------------------------------------------------------------------

def parents(pid: int) -> dict[int, int]:
    out = {}
    try:
        listing = subprocess.run(["ps", "-eo", "pid=,ppid="], capture_output=True, text=True,
                                 timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return out
    for line in listing.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0].isdigit() and parts[1].isdigit():
            out[int(parts[0])] = int(parts[1])
    return out


def descends_from(pid: int, root: int, tree: dict[int, int]) -> bool:
    seen = 0
    while pid > 1 and seen < 64:
        if pid == root:
            return True
        pid = tree.get(pid, 0)
        seen += 1
    return False


def descendants(root: int, tree: dict[int, int]) -> set[int]:
    """Every live pid in `root`'s subtree, root included. This is how the capture is identified —
    from the PROCESS side, so it works before, after and during the moments its window happens to be
    composited, and so the policy sampling can start at ~65 ms instead of at the first sighting."""
    return {pid for pid in tree if descends_from(pid, root, tree)}


# --- the failure decisions, as a pure function of the measured quantities ------------------------
#
# Split out of main() so the same thresholds that judge a real capture can be judged themselves, at
# startup, against two fixed vectors (see self_check). A guard whose checks have been quietly gutted
# by a threshold edit prints PASS just as convincingly as one that works.

Failure = collections.namedtuple("Failure", "check message")


def evaluate(*, rc: int, png_exists: bool, seen_any_window: bool, seen_capture_window: bool,
             policy_ms: int, worst_area: float, worst_rect, visible_ms: int, focus_ms: int,
             focus_grabs: int, foreground_ms: int) -> list[Failure]:
    failures: list[Failure] = []
    if rc != 0:
        failures.append(Failure("rc", f"the capture itself failed (rc={rc}) — this guard proves "
                                      f"nothing"))
    if not png_exists:
        failures.append(Failure("png", "no PNG was written — the capture did not render"))
    # A scanner that reports nothing is a bug until it is shown finding something.
    if not seen_any_window:
        failures.append(Failure("blind", "CGWindowListCopyWindowInfo returned no windows at all — "
                                         "this guard is blind, not passing"))
    if not seen_capture_window:
        failures.append(Failure("attached", "never saw a window owned by the capture process in the "
                                            "ALL-windows list — cannot distinguish 'well hidden' "
                                            "from 'sampling the wrong process'"))
    if policy_ms < MIN_POLICY_MS:
        failures.append(Failure(
            "instrument",
            f"no capture process had a readable activation policy for more than {policy_ms}ms "
            f"(floor {MIN_POLICY_MS}ms). The focus and foreground-eligible numbers below mean "
            f"NOTHING on this run — the instrument was not live. Look for a capture that died early "
            f"or a process tree this run failed to enumerate."))
    if worst_area > MAX_OVERLAP_AREA:
        failures.append(Failure(
            "area",
            f"a capture window covered {worst_area:.0f}pt^2 of the screen (limit "
            f"{MAX_OVERLAP_AREA}), rect={worst_rect}, for >={visible_ms}ms. A quiet capture must not "
            f"paint over the owner's desktop — see engine/tools/quiet_godot.sh and "
            f"shot_base.hide_offscreen()."))
    if focus_ms > MAX_FOCUS_MS:
        failures.append(Failure(
            "focus",
            f"the capture owned the keyboard for {focus_ms}ms across {focus_grabs} grab(s) "
            f"(limit {MAX_FOCUS_MS}ms). Everything typed in that window went into the capture "
            f"instead of the owner's editor — see engine/tools/nofocus_shim.m, which quiet_godot.sh "
            f"injects to keep the process out of the foreground."))
    if foreground_ms > MAX_FOREGROUND_MS:
        failures.append(Failure(
            "foreground",
            f"the capture ran as a REGULAR (foreground-eligible) application for {foreground_ms}ms "
            f"(limit {MAX_FOREGROUND_MS}ms). It may not have taken the keyboard on this run — that "
            f"part is intermittent — but nothing stopped it from doing so. engine/tools/"
            f"nofocus_shim.m is what holds the activation policy at Prohibited; check that "
            f"quiet_godot.sh still injects it (clang missing? TU_NOFOCUS=0 set?)."))
    return failures


# The numbers a good run produces on this machine, and the ones the pre-fix defect produced. Both are
# measured, not invented: the good vector is a shimmed widget_shot capture; the defect vector is the
# full-size window of the old recipe (~1.1 M pt^2), the 878 ms focus hold, and the 606 ms the
# notification-only shim left the process foreground-eligible.
GOOD_VECTOR = dict(rc=0, png_exists=True, seen_any_window=True, seen_capture_window=True,
                   policy_ms=1400, worst_area=1.0, worst_rect=(1512.0, 944.0, 1.0, 1.0),
                   visible_ms=23, focus_ms=0, focus_grabs=0, foreground_ms=0)
DEFECT_VECTOR = dict(rc=0, png_exists=True, seen_any_window=True, seen_capture_window=True,
                     policy_ms=1400, worst_area=1_100_000.0, worst_rect=(0.0, 0.0, 1193.0, 1051.0),
                     visible_ms=880, focus_ms=878, focus_grabs=3, foreground_ms=606)


def self_check() -> list[str]:
    """Costs microseconds, runs every time, and is the only thing standing between a future
    threshold edit and a guard that prints PASS on the defect it was written for."""
    problems = []
    good = evaluate(**GOOD_VECTOR)
    if good:
        problems.append("the self-check's measured-GOOD vector was failed by " +
                        ", ".join(f.check for f in good) +
                        " — the thresholds now reject a run this guard is meant to accept")
    caught = {f.check for f in evaluate(**DEFECT_VECTOR)}
    missed = {"area", "focus", "foreground"} - caught
    if missed:
        problems.append("the self-check's recorded DEFECT vector was NOT caught by " +
                        ", ".join(sorted(missed)) +
                        " — those checks no longer detect the behaviour they exist for")
    return problems


def main() -> int:
    broken = self_check()
    if broken:
        for problem in broken:
            print(f"FAIL: {problem}")
        print("FAIL test_quiet_window: the guard's own checks are broken — nothing was captured")
        return 1
    if NEGATIVE_CONTROL:
        print("NEGATIVE CONTROL (TU_NOFOCUS=0): the shim is disabled, so this run must FAIL. "
              "A capture with no failures is the failure.")
    if platform.system() != "Darwin":
        skip("not macOS — the quiet-window recipe is macOS-specific")
    if not shutil.which(os.environ.get("GODOT", "godot")):
        skip("no godot on PATH")
    if not QUIET.exists():
        skip(f"{QUIET} is missing")
    screens = displays()
    if not screens:
        skip("no active display — nothing can be shown to interrupt anyone")
    if (ROOT / "override.cfg").exists():
        skip("override.cfg is already present — another quiet run owns it")

    out_png = Path(tempfile.mkdtemp(prefix="tu_quietwin_")) / "widget.png"
    proc = subprocess.Popen(
        [str(QUIET), "--path", str(ROOT), "-s", TOOL, "--", str(out_png)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd=str(ROOT))

    tree = parents(proc.pid)
    ours: dict[int, bool] = {}
    worst = (0.0, None)          # (area, rect)
    onscreen_samples = 0
    seen_any_window = False
    seen_capture_window = False
    samples = 0
    focus_samples = 0            # 2 ms samples in which the capture owned the keyboard
    focus_grabs = 0              # how many separate times it took it
    had_focus = False
    capture_pids: set[int] = set(descendants(proc.pid, tree))
    # The subset of capture_pids that has ever answered runningApplicationWithProcessIdentifier: —
    # i.e. the processes that ARE applications. Only these are polled at 500 Hz; asking Launch
    # Services about a shell pid 500 times a second buys nothing but -1.
    app_pids: set[int] = set()
    foreground_samples = 0       # 2 ms samples in which a capture process was a Regular app
    policy_samples = 0           # 2 ms samples in which SOME capture process had a readable policy
    last_tree_s = time.monotonic()
    deadline = time.monotonic() + 180

    def is_ours(pid: int) -> bool:
        nonlocal tree
        if pid not in ours:
            if pid not in tree:
                tree = parents(proc.pid)          # a pid we have not seen: refresh the map once
            ours[pid] = descends_from(pid, proc.pid, tree)
        return ours[pid]

    def sample_focus(seconds: float) -> None:
        """Watch the frontmost app and the capture's activation policy for `seconds`, at
        FOCUS_SAMPLE_S. Replaces the plain sleep, so both are under continuous observation while the
        window lists are walked between — and both are driven by the process tree, so the watch runs
        for the whole capture rather than starting at the first window sighting."""
        nonlocal focus_samples, focus_grabs, had_focus, foreground_samples, policy_samples
        until = time.monotonic() + seconds
        while True:
            pid = frontmost_pid()
            now_ours = pid > 0 and is_ours(pid)
            if now_ours:
                focus_samples += 1
                if not had_focus:
                    focus_grabs += 1
            had_focus = now_ours
            policies = [activation_policy(cap) for cap in app_pids]
            # At most ONE sample per tick, however many processes the capture has: these are
            # durations in wall-clock milliseconds, not process-milliseconds.
            if any(p != -1 for p in policies):
                policy_samples += 1
            if any(p == POLICY_REGULAR for p in policies):
                foreground_samples += 1
            if time.monotonic() >= until:
                return
            time.sleep(FOCUS_SAMPLE_S)

    while time.monotonic() < deadline:
        alive = proc.poll() is None
        now = time.monotonic()
        # Re-read the tree every pass until something in it is an application (the capture's own
        # process takes ~65 ms to check in), then at TREE_REFRESH_S to pick up late children.
        if not app_pids or now - last_tree_s >= TREE_REFRESH_S:
            tree = parents(proc.pid)
            capture_pids |= descendants(proc.pid, tree)
            last_tree_s = now
        for cap in capture_pids - app_pids:
            if activation_policy(cap) != -1:
                app_pids.add(cap)
        # PRECONDITION channel: every window that exists. The capture's window is here for ~60 of
        # these samples; it reaches the on-screen list below for at most one. It is a boolean, so
        # the extra list walk stops the moment it is answered.
        if not seen_capture_window:
            for pid, _owner, _rect in all_windows():
                if pid in capture_pids:
                    seen_capture_window = True
                    break
        # COVERAGE channel: only what is composited, which is the only thing that can cover the
        # owner's screen. Attribution is by tree membership — the owner's own long-lived godot
        # session is not in the tree, and a Prohibited capture may report no owner name at all.
        for pid, _owner, rect in on_screen_windows():
            seen_any_window = True
            if pid not in capture_pids:
                continue
            area = overlap_area(rect, screens)
            if area > 0:
                onscreen_samples += 1
                if area > worst[0]:
                    worst = (area, rect)
        samples += 1
        if not alive:
            if deadline > time.monotonic() + GRACE_S:
                deadline = time.monotonic() + GRACE_S
        sample_focus(SAMPLE_S)

    rc = proc.wait()
    visible_ms = int(onscreen_samples * SAMPLE_S * 1000)
    focus_ms = int(focus_samples * FOCUS_SAMPLE_S * 1000)
    foreground_ms = int(foreground_samples * FOCUS_SAMPLE_S * 1000)
    policy_ms = int(policy_samples * FOCUS_SAMPLE_S * 1000)
    print(f"displays={screens}")
    print(f"capture rc={rc} samples={samples} capture-window-seen={seen_capture_window} "
          f"pids={sorted(capture_pids)} app-pids={sorted(app_pids)} "
          f"worst-overlap={worst[0]:.0f}pt^2 rect={worst[1]} on-screen>={visible_ms}ms")
    print(f"focus: the capture was frontmost for {focus_ms}ms in {focus_grabs} grab(s) "
          f"(limit {MAX_FOCUS_MS}ms); it was a foreground-eligible app for {foreground_ms}ms "
          f"(limit {MAX_FOREGROUND_MS}ms); its policy was readable — the instrument live — for "
          f"{policy_ms}ms (floor {MIN_POLICY_MS}ms)")

    failures = evaluate(rc=rc, png_exists=out_png.exists(), seen_any_window=seen_any_window,
                        seen_capture_window=seen_capture_window, policy_ms=policy_ms,
                        worst_area=worst[0], worst_rect=worst[1], visible_ms=visible_ms,
                        focus_ms=focus_ms, focus_grabs=focus_grabs, foreground_ms=foreground_ms)
    if not out_png.exists():
        print(f"(expected PNG at {out_png})")

    for f in failures:
        print(f"FAIL: {f.message}")
    if NEGATIVE_CONTROL:
        # Only the checks that measure QUIETNESS count as the control being caught. A broken run
        # (rc, no PNG, blind scanner, dead instrument) fails for reasons that have nothing to do
        # with the shim, and must not be read as the guard working.
        caught = {f.check for f in failures} & {"area", "focus", "foreground"}
        if caught:
            print("PASS test_quiet_window (negative control): the shim was disabled and the guard "
                  "caught it — " + ", ".join(sorted(caught)))
            return 0
        if failures:
            print("FAIL: the negative control did not run cleanly enough to prove anything — the "
                  "failures above are about the run itself, not about the missing shim.")
            return 1
        print("FAIL: the guard passed an unshimmed capture — it is no longer measuring anything. "
              "Every check was satisfied by a run with TU_NOFOCUS=0, so a real regression would "
              "pass too.")
        return 1
    if failures:
        return 1
    print("PASS test_quiet_window: the capture never covered the screen or took the keyboard")
    return 0


if __name__ == "__main__":
    sys.exit(main())
