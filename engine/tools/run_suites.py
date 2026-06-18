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
"""
import re, sys, os, subprocess, time
from concurrent.futures import ThreadPoolExecutor

GODOT = os.environ.get("GODOT", "godot")
JOBS = int(os.environ.get("JOBS", "4"))
SUITES = sys.argv[1:]

SUMMARY = re.compile(r"== (\d+) passed, (\d+) failed ==")


def run(suite):
    t = time.monotonic()
    p = subprocess.run(
        [GODOT, "--headless", "--path", ".", "-s", f"res://{suite}.gd"],
        capture_output=True, text=True,
    )
    dt = time.monotonic() - t
    out = (p.stdout or "") + (p.stderr or "")
    lines = out.splitlines()
    npass = sum(1 for ln in lines if ln.startswith("  PASS"))
    # the suite's own summary is authoritative for the failed count; if it never
    # printed one, the suite crashed before finishing (npass is then partial).
    m = SUMMARY.search(out)
    reached_end = m is not None
    nfail = int(m.group(2)) if reached_end else sum(1 for ln in lines if ln.startswith("  FAIL"))
    crashed = not reached_end
    ok = reached_end and nfail == 0 and p.returncode == 0
    return {"suite": suite, "dt": dt, "pass": npass, "fail": nfail,
            "crashed": crashed, "code": p.returncode, "ok": ok, "out": out}


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
        status = "ok" if r["ok"] else ("CRASH" if r["crashed"] else f"FAIL×{r['fail']}")
        print(f"  {r['dt']:7.2f}s  {r['pass']:>5}  {status:<7} {r['suite']}")
    print("  " + "-" * 60)
    print(f"  wall {wall:6.2f}s  (sum of suite-times {cpu_sum:6.2f}s, "
          f"speed-up {cpu_sum/wall:.1f}× at JOBS={JOBS})")
    print(f"  {len(results)} suites · {tot_pass} passed · {tot_fail} failed")

    if failed:
        print("\n  FAILURES:")
        for r in failed:
            why = "crashed before summary" if r["crashed"] else (f"{r['fail']} failed" if r["fail"] else f"exit {r['code']}")
            print(f"   • {r['suite']} ({why})")
            if r["crashed"]:
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
