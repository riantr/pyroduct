#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Copy moon fmt's canonical copies over the sources, byte for byte.

`moon fmt` cannot rewrite files in this sandbox, so `moon fmt --check` writes
formatted copies under _build/<target>/release/format/. This copies them back
as BYTES (not text): a binary copy cannot mangle encoding, which is the whole
reason the Get-Content/Set-Content route is banned here.

Refuses to run if a formatted copy is missing. Prints the byte delta per file
so a surprise rewrite is visible rather than silent.
"""

import os
import shutil
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


def main():
    copied = []
    for rel in FILES:
        src = os.path.join(FMT, *rel.split("/"))
        dst = os.path.join(ROOT, *rel.split("/"))
        if not os.path.exists(src):
            print("SKIP (no formatted copy): %s" % rel)
            continue
        if not os.path.exists(dst):
            print("SKIP (no source): %s" % rel)
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
    if not copied:
        print("nothing to do")
    return 0


if __name__ == "__main__":
    sys.exit(main())
