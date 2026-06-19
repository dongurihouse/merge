#!/usr/bin/env python3
"""Run headless Godot test suites in parallel and print a per-suite timing table.

Usage:   engine/tools/run_suites.py <suite> [<suite> ...]
  where <suite> is a res:// path without the leading "res://" or trailing ".gd",
  e.g.  engine/tests/save_tests

Env:
  GODOT   godot binary (default: godot)
  JOBS    max concurrent suites (default: 4 — over-subscription thrashes cores)

Exit code is non-zero if ANY suite fails. Failure detection is summary-based:
a suite that reaches its "== N passed, M failed ==" line with M==0 and exits 0
PASSED — even if it logged SCRIPT ERROR / GDScript backtrace noise along the way
(the suites deliberately exercise error paths). A suite that never reaches that
summary line CRASHED (it died early — a real failure, regardless of exit code).

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
# error aborts _initialize before quit(), so the process never exits).
SCRIPT_ERR = re.compile(r"(SCRIPT ERROR:.*)\n\s*(at: .*)")


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
    ok = reached_end and nfail == 0 and code == 0
    em = SCRIPT_ERR.search(out)
    err = f"{em.group(1).strip()} {em.group(2).strip()}" if em else ""
    return {"suite": suite, "dt": dt, "pass": npass, "fail": nfail,
            "crashed": crashed, "timed_out": timed_out, "code": code,
            "ok": ok, "out": out, "err": err}


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
        else:
            status = f"FAIL×{r['fail']}"
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
        return 1
    print("\n  ALL SUITES PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
