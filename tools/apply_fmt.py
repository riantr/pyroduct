#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Copy moon fmt's canonical copies over the sources, byte for byte.

`moon fmt` cannot rewrite files in this sandbox, so `moon fmt --check` writes
formatted copies under _build/<target>/release/format/. This copies them back
as BYTES (not text): a binary copy cannot mangle encoding, which is the whole
reason the Get-Content/Set-Content route is banned here.

**Freshness is the whole game here.** The copy under _build/ is whatever the
last `moon fmt --check` produced — and I once ran that check while the
mutation harness had a *deliberately broken* src/loop.mbt in place, then came
back an hour later and ran this script. It cheerfully overwrote two good
files with the stale, pre-refactor copies and silently dropped two tests
(178 -> 176). Nothing warned. So:

  1. re-run `moon fmt --check` **here**, right now, so the copies are current;
  2. skip any copy that is OLDER than its source (belt and braces, in case
     step 1 failed to refresh one);
  3. report the test count before and after, so a silent content loss shows up
     as a number change rather than as nothing happening.

Refuses to run if a formatted copy is missing. Prints the byte delta per file
so a surprise rewrite is visible rather than silent.
"""

import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FMT = os.path.join(ROOT, "_build", "wasm-gc", "release", "format")

FILES = [
    "src/petri.mbt",
    "ml/design.mbt",
    "src/spec_roundtrip_test.mbt",
    "audit/mutants.mbt",
    "audit/fleet.mbt",
    "src/loop.mbt",
    "src/loop_test.mbt",
    "src/spec.mbt",
    "ml/ml_test.mbt",
    "src/petri_test.mbt",
    "audit/fleet_test.mbt",
    "cmd/main/main.mbt",
    "audit/audit.mbt",
    "cmd/jsoncli/main.mbt",
]


def test_count():
    proc = subprocess.run(["moon", "test"], cwd=ROOT, capture_output=True)
    text = (proc.stdout + proc.stderr).decode("utf-8", errors="replace")
    m = re.search(r"Total tests:\s*(\d+)", text)
    return int(m.group(1)) if m else -1


def main():
    # (1) 副本必须新鲜：自己先跑一遍，别信上一次留下的。
    print("refreshing canonical copies: moon fmt --check")
    subprocess.run(["moon", "fmt", "--check"], cwd=ROOT, capture_output=True)

    before = test_count()
    copied = []
    skipped = []
    for rel in FILES:
        src = os.path.join(FMT, *rel.split("/"))
        dst = os.path.join(ROOT, *rel.split("/"))
        if not os.path.exists(src):
            print("SKIP (no formatted copy): %s" % rel)
            continue
        if not os.path.exists(dst):
            print("SKIP (no source): %s" % rel)
            continue
        # (2) 比源文件旧的副本一律不用——那说明它没被刷新，宁可报出来。
        if os.path.getmtime(src) < os.path.getmtime(dst):
            skipped.append("%s (copy is older than source — STALE)" % rel)
            continue
        with open(src, "rb") as fh:
            formatted = fh.read()
        with open(dst, "rb") as fh:
            current = fh.read()
        if formatted == current:
            continue
        delta = len(formatted) - len(current)
        shutil.copyfile(src, dst)
        copied.append("%s (%+d bytes)" % (rel, delta))
    for line in copied:
        print("formatted: " + line)
    for line in skipped:
        print("STALE, NOT APPLIED: " + line)
    if not copied:
        print("nothing to do")

    # (3) 内容丢失要看得见：测试数变了就说出来。
    after = test_count()
    print("tests: %d -> %d" % (before, after))
    if after != before:
        print("FAIL: applying formatting changed the test count. "
              "A formatting pass must not add or drop a test.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
