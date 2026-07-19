#!/usr/bin/env python3
"""Run headless Godot test suites in parallel and print a per-suite timing table.

Usage:   engine/tools/run_suites.py <suite> [<suite> ...]
  where <suite> is a res:// path without the leading "res://" or trailing ".gd",
  e.g.  engine/tests/save_tests

Env:
  GODOT   godot binary (default: godot)
  JOBS    max concurrent suites (default: 4 — over-subscription thrashes cores)

Exit code is non-zero if ANY suite fails. A suite PASSES only when it reaches its
"== N passed, M failed ==" line with M==0, exits 0, AND logged no SCRIPT ERROR.
A suite that never reaches that summary line CRASHED (it died early — a real
failure, regardless of exit code).

SCRIPT ERROR IS A FAILURE. It used to be tolerated on the theory that suites
deliberately exercise error paths, but that tolerance hid real breakage: a
`await hx._some_removed_method(...)` aborts the enclosing test function, so its
asserts never run and never print — the suite still reaches its summary and
reports a healthy-looking "all passed". Coverage silently dies while CI stays
green. Measured across every active suite, none legitimately need the tolerance:
a test that means to exercise an error path should assert the guarded no-op
rather than let the engine log an error.

HANG GUARD: each suite is bounded by TIMEOUT seconds (default 120). A SceneTree
test that hits an uncaught SCRIPT ERROR mid-`_initialize()` aborts the function
WITHOUT reaching its `quit()` — so the headless process idles forever and would
block the whole run. The timeout kills it and reports it as a TIMEOUT failure,
surfacing the SCRIPT ERROR + location that caused the hang. So a buggy suite
fails loudly and named; it can never hang the run.

Env:
  GODOT    godot binary (default: godot)
  JOBS     max concurrent suites (default: 4)
  TIMEOUT  per-suite wall-clock budget in seconds (default: 120 — healthy suites
           finish in seconds; this only ever trips on a genuine hang)
"""
import re, sys, os, subprocess, time
from concurrent.futures import ThreadPoolExecutor

GODOT = os.environ.get("GODOT", "godot")
JOBS = int(os.environ.get("JOBS", "4"))
TIMEOUT = float(os.environ.get("TIMEOUT", "120"))
SUITES = sys.argv[1:]

SUMMARY = re.compile(r"== (\d+) passed, (\d+) failed ==")
# the first uncaught error + its location — the usual reason a suite hangs (the
# error aborts _initialize before quit(), so the process never exits). Even when
# the suite survives to its summary, an error here means some test function was
# cut short mid-way, so it counts as a failure on its own.
SCRIPT_ERR = re.compile(r"(SCRIPT ERROR:.*)\n\s*(at: .*)")
ANY_SCRIPT_ERR = re.compile(r"SCRIPT ERROR:")


def run(suite):
    t = time.monotonic()
    timed_out = False
    code = None
    try:
        p = subprocess.run(
            [GODOT, "--headless", "--path", ".", "-s", f"res://{suite}.gd"],
            capture_output=True, text=True, timeout=TIMEOUT,
        )
        out = (p.stdout or "") + (p.stderr or "")
        code = p.returncode
    except subprocess.TimeoutExpired as e:
        timed_out = True
        # partial output captured before the kill — enough to show WHERE it hung
        so, se = e.stdout or "", e.stderr or ""
        if isinstance(so, bytes): so = so.decode("utf-8", "replace")
        if isinstance(se, bytes): se = se.decode("utf-8", "replace")
        out = so + se
    dt = time.monotonic() - t
    lines = out.splitlines()
    npass = sum(1 for ln in lines if ln.startswith("  PASS"))
    # the suite's own summary is authoritative for the failed count; if it never
    # printed one, the suite crashed/hung before finishing (npass is then partial).
    m = SUMMARY.search(out)
    reached_end = m is not None and not timed_out
    nfail = int(m.group(2)) if reached_end else sum(1 for ln in lines if ln.startswith("  FAIL"))
    crashed = not reached_end
    # an error mid-run aborts the enclosing test function — its asserts silently
    # never run, so a clean summary does NOT mean the suite is healthy.
    n_script_err = len(ANY_SCRIPT_ERR.findall(out))
    ok = reached_end and nfail == 0 and code == 0 and n_script_err == 0
    em = SCRIPT_ERR.search(out)
    err = f"{em.group(1).strip()} {em.group(2).strip()}" if em else ""
    return {"suite": suite, "dt": dt, "pass": npass, "fail": nfail,
            "crashed": crashed, "timed_out": timed_out, "code": code,
            "script_err": n_script_err, "ok": ok, "out": out, "err": err}


def main():
    if not SUITES:
        print("no suites given", file=sys.stderr)
        return 2
    wall0 = time.monotonic()
    results = []
    with ThreadPoolExecutor(max_workers=JOBS) as ex:
        for r in ex.map(run, SUITES):
            tag = "ok  " if r["ok"] else "FAIL"
            print(f"  {tag}  {r['dt']:6.2f}s  {r['suite']}  ({r['pass']} passed)")
            results.append(r)
    wall = time.monotonic() - wall0

    results.sort(key=lambda r: r["dt"], reverse=True)
    cpu_sum = sum(r["dt"] for r in results)
    tot_pass = sum(r["pass"] for r in results)
    tot_fail = sum(r["fail"] for r in results)
    failed = [r for r in results if not r["ok"]]

    print("\n" + "=" * 64)
    print(f"  {'time':>8}  {'pass':>5}  {'status':<7} suite")
    print("  " + "-" * 60)
    for r in results:
        if r["ok"]:
            status = "ok"
        elif r["timed_out"]:
            status = "TIMEOUT"
        elif r["crashed"]:
            status = "CRASH"
        elif r["fail"]:
            status = f"FAIL×{r['fail']}"
        elif r["script_err"]:
            status = f"ERR×{r['script_err']}"
        else:
            status = f"exit {r['code']}"
        print(f"  {r['dt']:7.2f}s  {r['pass']:>5}  {status:<7} {r['suite']}")
    print("  " + "-" * 60)
    print(f"  wall {wall:6.2f}s  (sum of suite-times {cpu_sum:6.2f}s, "
          f"speed-up {cpu_sum/wall:.1f}× at JOBS={JOBS})")
    print(f"  {len(results)} suites · {tot_pass} passed · {tot_fail} failed")

    if failed:
        print("\n  FAILURES:")
        for r in failed:
            if r["timed_out"]:
                why = f"HUNG — no exit within {TIMEOUT:.0f}s (killed)"
            elif r["crashed"]:
                why = "crashed before summary"
            elif r["fail"]:
                why = f"{r['fail']} failed"
            elif r["script_err"]:
                why = (f"{r['script_err']} SCRIPT ERROR — a test function was cut "
                       "short, so its asserts never ran")
            else:
                why = f"exit {r['code']}"
            print(f"   • {r['suite']} ({why})")
            if r["timed_out"]:
                # a hang is almost always an uncaught SCRIPT ERROR that aborted
                # _initialize() before quit() — surface it so the cause is obvious.
                if r["err"]:
                    print(f"       cause: {r['err'][:140]}")
                else:
                    print("       (no SCRIPT ERROR captured — likely an infinite loop; check the suite's last PASS)")
                for ln in [x for x in r["out"].splitlines() if x.strip()][-4:]:
                    print(f"       {ln.strip()[:110]}")
            elif r["crashed"]:
                # show the tail — the real error is the last thing before it died
                for ln in [x for x in r["out"].splitlines() if x.strip()][-6:]:
                    print(f"       {ln.strip()[:110]}")
            else:
                for ln in r["out"].splitlines():
                    if ln.startswith("  FAIL"):
                        print(f"       {ln.strip()[:110]}")
                if r["script_err"]:
                    # show each distinct error + the line it fired on: that call site is
                    # where the enclosing test function stopped executing.
                    lines = r["out"].splitlines()
                    seen = set()
                    for i, ln in enumerate(lines):
                        if "SCRIPT ERROR:" not in ln or ln in seen:
                            continue
                        seen.add(ln)
                        print(f"       {ln.strip()[:110]}")
                        at = lines[i + 1].strip() if i + 1 < len(lines) else ""
                        if at.startswith("at:"):
                            print(f"         {at[:110]}")
        return 1
    print("\n  ALL SUITES PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
