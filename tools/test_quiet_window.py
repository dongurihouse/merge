#!/usr/bin/env python3
"""Guard: a quiet capture must not put a window on the owner's screen, or take their keyboard.

WHY THIS EXISTS. engine/tools/quiet_godot.sh shipped for months claiming the capture window was
"born minimized" and never seen. It was only ever verified against FOCUS (`lsappinfo front`), and
that part was true — the app never became frontmost. Nobody measured VISIBILITY, and the window was
in fact composited at full size for ~1000 ms on every capture (~2900 ms for the workbenches): the
`window/size/mode=1` project setting is not honoured at window creation on macOS, so the only thing
hiding the window was an in-script `window_set_mode(MINIMIZED)` that ran ~460 ms into boot and then
played macOS's synchronous ~560 ms genie animation. A claim nothing tests is a claim that rots.

WHAT IT MEASURES. One real capture is run while this process samples CGWindowListCopyWindowInfo
(`.optionOnScreenOnly`) every 30 ms, keeping only windows owned by the capture's own process tree,
and intersects each window's bounds with the real display rects. The check is on AREA, not presence:
the capture window is born 1x1 just past the screen's bottom-right corner (Godot clamps a BIRTH
position into the usable rect, so the corner is as far out as a window can be born) and macOS reports
its frame one point larger on every side, so a single corner point of shadow fringe touches the
screen for ~200 ms before shot_base parks the window at (-32000, -32000). That is the floor on this
platform. A regression to the old behaviour is a ~1.1-million-point overlap — four orders of
magnitude over the limit here, so this is a wide, non-flaky margin, not a tuned threshold.

AND WHAT IT MEASURES SECOND. Hiding the window was only half of "quiet": the capture also became the
FRONTMOST APPLICATION and stayed there until it exited — measured, 500-1500 ms per launch on a
machine whose owner is typing. The area check above passed throughout, because area is not focus.
That is the same mistake in the other direction, so this run now also samples NSWorkspace's frontmost
application every 2 ms and fails if the capture ever owns the keyboard for longer than
MAX_FOCUS_MS. The residue it tolerates is the one measured after engine/tools/nofocus_shim.m lands
(a single ~15 ms activation that the shim answers from inside the process); the behaviour it exists
to catch is two orders of magnitude larger.

SKIPS (exit 0, with the reason printed) when there is nothing to measure: not macOS, no `godot`, no
GUI session (no active displays), or another quiet run already owns override.cfg. CI is headless, so
it skips there; it is the dev machine — the one with an owner to interrupt — that it protects.
"""

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
# Being Regular is not intermittent: measured, an unshimmed capture is Regular from ~240 ms to exit
# (~1100 ms of a 1.3 s run) and a shimmed one for the ~10 ms of Launch Services' check-in, before
# the shim demotes it again.
MAX_FOREGROUND_MS = 200


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


def on_screen_windows() -> list[tuple[int, str, tuple[float, float, float, float]]]:
    """(pid, owner, (x, y, w, h)) for every window the window server is currently compositing."""
    arr = CG.CGWindowListCopyWindowInfo(ON_SCREEN_ONLY | EXCLUDE_DESKTOP, 0)
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


def main() -> int:
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
    capture_pids: set[int] = set()
    foreground_samples = 0       # 2 ms samples in which a capture process was a Regular app
    deadline = time.monotonic() + 180

    def is_ours(pid: int) -> bool:
        nonlocal tree
        if pid not in ours:
            if pid not in tree:
                tree = parents(proc.pid)          # a pid we have not seen: refresh the map once
            ours[pid] = descends_from(pid, proc.pid, tree)
        return ours[pid]

    def sample_focus(seconds: float) -> None:
        """Watch the frontmost app for `seconds`, at FOCUS_SAMPLE_S. Replaces the plain sleep, so
        the keyboard is under continuous observation while the window list is walked between."""
        nonlocal focus_samples, focus_grabs, had_focus, foreground_samples
        until = time.monotonic() + seconds
        while True:
            pid = frontmost_pid()
            now_ours = pid > 0 and is_ours(pid)
            if now_ours:
                focus_samples += 1
                if not had_focus:
                    focus_grabs += 1
            had_focus = now_ours
            for cap in capture_pids:
                if activation_policy(cap) == POLICY_REGULAR:
                    foreground_samples += 1
            if time.monotonic() >= until:
                return
            time.sleep(FOCUS_SAMPLE_S)

    while time.monotonic() < deadline:
        alive = proc.poll() is None
        for pid, owner, rect in on_screen_windows():
            seen_any_window = True
            if "godot" not in owner.lower():
                continue
            if not is_ours(pid):
                continue                              # the owner's own long-lived godot session
            seen_capture_window = True
            capture_pids.add(pid)
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
    print(f"displays={screens}")
    print(f"capture rc={rc} samples={samples} capture-window-seen={seen_capture_window} "
          f"worst-overlap={worst[0]:.0f}pt^2 rect={worst[1]} on-screen>={visible_ms}ms")
    foreground_ms = int(foreground_samples * FOCUS_SAMPLE_S * 1000)
    print(f"focus: the capture was frontmost for {focus_ms}ms in {focus_grabs} grab(s) "
          f"(limit {MAX_FOCUS_MS}ms); it was a foreground-eligible app for {foreground_ms}ms "
          f"(limit {MAX_FOREGROUND_MS}ms)")

    failures = []
    if rc != 0:
        failures.append(f"the capture itself failed (rc={rc}) — this guard proves nothing")
    if not out_png.exists():
        failures.append(f"no PNG at {out_png} — the capture did not render")
    # A scanner that reports nothing is a bug until it is shown finding something.
    if not seen_any_window:
        failures.append("CGWindowListCopyWindowInfo returned no windows at all — this guard is "
                        "blind, not passing")
    if not seen_capture_window:
        failures.append("never saw a window owned by the capture process — cannot distinguish "
                        "'well hidden' from 'sampling the wrong process'")
    if worst[0] > MAX_OVERLAP_AREA:
        failures.append(
            f"a capture window covered {worst[0]:.0f}pt^2 of the screen (limit {MAX_OVERLAP_AREA}), "
            f"rect={worst[1]}, for >={visible_ms}ms. A quiet capture must not paint over the "
            f"owner's desktop — see engine/tools/quiet_godot.sh and shot_base.hide_offscreen().")
    if focus_ms > MAX_FOCUS_MS:
        failures.append(
            f"the capture owned the keyboard for {focus_ms}ms across {focus_grabs} grab(s) "
            f"(limit {MAX_FOCUS_MS}ms). Everything typed in that window went into the capture "
            f"instead of the owner's editor — see engine/tools/nofocus_shim.m, which quiet_godot.sh "
            f"injects to keep the process out of the foreground.")
    if foreground_ms > MAX_FOREGROUND_MS:
        failures.append(
            f"the capture ran as a REGULAR (foreground-eligible) application for {foreground_ms}ms "
            f"(limit {MAX_FOREGROUND_MS}ms). It may not have taken the keyboard on this run — that "
            f"part is intermittent — but nothing stopped it from doing so. engine/tools/"
            f"nofocus_shim.m is what holds the activation policy at Prohibited; check that "
            f"quiet_godot.sh still injects it (clang missing? TU_NOFOCUS=0 set?).")

    for f in failures:
        print(f"FAIL: {f}")
    if failures:
        return 1
    print("PASS test_quiet_window: the capture never covered the screen or took the keyboard")
    return 0


if __name__ == "__main__":
    sys.exit(main())
