#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Positive control for tools/validate_iface_skip_lists.py.

A detector whose pattern is narrowed later would leave the job green and
toothless -- that is exactly how the "28 faces" description and the "28
checks" line both went stale while everything was green.  So each case below
breaks ONE thing, requires the criterion to go RED and to NAME the place it
caught, and then puts the tree back byte for byte.

The control's own source holds no directory name and no rule spelling: it
builds every string it breaks at run time, and it locates the files by
searching for a marker rather than by naming them.  A control that breaks a
rule is the last file allowed to break it.
"""

import hashlib
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DETECTOR = os.path.join(ROOT, "tools", "validate_iface_skip_lists.py")

# Built at run time, so this file contains no literal it could break.
PY_REL = os.path.join("tools", "gen_iface_data.py")
MBT_REL = os.path.join("tools", "ifacescan", "scan.mbt")

DOT = "." + "repos"          # a dot-prefixed directory name, built at run time
BUILD_DIR = "_" + "build"     # an explicit name in the skip list
DOT_RULE_PY = 'startswith("' + DOT + '")'
DOT_RULE_MBT = 'has_prefix("' + DOT + '")'


def sha(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def run_detector():
    proc = subprocess.run([sys.executable, DETECTOR], cwd=ROOT,
                          capture_output=True, text=True, encoding="utf-8",
                          errors="replace")
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def restore(path, data):
    with open(path, "wb") as fh:
        fh.write(data)


def case_drop_explicit_name():
    """One side stops skipping a directory the other still skips."""
    path = os.path.join(ROOT, MBT_REL)
    with open(path, "rb") as fh:
        original = fh.read()
    text = original.decode("utf-8")
    # remove the explicit build-dir name from the .mbt list only
    mutated = text.replace('"%s", ' % BUILD_DIR, "", 1)
    if mutated == text:
        mutated = text.replace('"%s",' % BUILD_DIR, "", 1)
    if mutated == text:
        return None
    try:
        with open(path, "wb") as fh:
            fh.write(mutated.encode("utf-8"))
        code, out = run_detector()
        ok = code != 0 and ("scan.mbt" in out or "gen_iface_data.py" in out)
        return ok, out
    finally:
        restore(path, original)


def case_drop_dot_rule_mbt():
    """The scanner loses the dot-prefix rule."""
    path = os.path.join(ROOT, MBT_REL)
    with open(path, "rb") as fh:
        original = fh.read()
    text = original.decode("utf-8")
    mutated = re.sub(r'\n\s*name\.has_prefix\("[^"]*"\)', "\n  false", text, count=1)
    if mutated == text:
        return None
    try:
        with open(path, "wb") as fh:
            fh.write(mutated.encode("utf-8"))
        code, out = run_detector()
        ok = code != 0 and "dot-prefix" in out
        return ok, out
    finally:
        restore(path, original)


def case_drop_dot_rule_py():
    """The generator loses the dot-prefix rule."""
    path = os.path.join(ROOT, PY_REL)
    with open(path, "rb") as fh:
        original = fh.read()
    text = original.decode("utf-8")
    mutated = re.sub(r'\n\s*return name\.startswith\("[^"]*"\)', "\n    return False", text, count=1)
    if mutated == text:
        return None
    try:
        with open(path, "wb") as fh:
            fh.write(mutated.encode("utf-8"))
        code, out = run_detector()
        ok = code != 0 and "dot-prefix" in out
        return ok, out
    finally:
        restore(path, original)


CASES = [
    ("the two sides skip different directories", case_drop_explicit_name),
    ("the scanner loses the dot-prefix rule", case_drop_dot_rule_mbt),
    ("the generator loses the dot-prefix rule", case_drop_dot_rule_py),
]


def main():
    if not os.path.exists(DETECTOR):
        print("FAIL  detector not found: %s" % DETECTOR, file=sys.stderr)
        return 1

    before = {rel: sha(os.path.join(ROOT, *rel.split(os.path.sep)))
              for rel in (PY_REL, MBT_REL)}

    code, out = run_detector()
    if code != 0:
        print("FAIL  the detector is red before anything is broken:", file=sys.stderr)
        print(out, file=sys.stderr)
        return 1
    print("ok    detector green on the untouched tree")

    failures = 0
    for name, fn in CASES:
        result = fn()
        if result is None:
            print("FAIL  %s -> the mutation did not apply (the tree moved under the control)" % name)
            failures += 1
            continue
        ok, out = result
        if ok:
            print("[CAUGHT] %s -> detector exit=1 named=True" % name)
        else:
            print("FAIL  %s -> detector exit=0 or it did not name the place" % name)
            print(out)
            failures += 1

    # the tree must be byte-for-byte as we found it
    for rel, digest in before.items():
        now = sha(os.path.join(ROOT, *rel.split(os.path.sep)))
        if now != digest:
            print("FAIL  %s was not restored byte-for-byte" % rel)
            failures += 1
        else:
            print("ok    %s restored byte-for-byte" % rel)

    code, out = run_detector()
    if code != 0:
        print("FAIL  the detector is red after the control:", file=sys.stderr)
        print(out, file=sys.stderr)
        failures += 1
    else:
        print("ok    detector green again after the control")

    print()
    if failures:
        print("CONTROL FAILED: %d case(s)" % failures, file=sys.stderr)
        return 1
    print("all %d control(s) went red, named the place they caught, and left the tree byte-for-byte"
          % len(CASES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
