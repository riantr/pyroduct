#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""The two .mbti skip lists must be the same list and the same RULE.

`tools/gen_iface_data.py` writes the embedded snapshot; `tools/ifacescan` scans
the disk.  The criterion they serve is "snapshot == disk", in BOTH directions.
So the two must see the same file set -- and that is two copies of one rule,
which is exactly the shape that drifts.

What went wrong on 2026-11-24, measured rather than argued:

  * the dependency tree is fetched into `.mooncakes/` (gitignored -- the
    toolchain's extraction root; `moon fetch` drops one in `.repos/`) the moment
    the build runs, and the dependency carries its own `.mbti` files;
  * the filesystem walk therefore saw 88 `.mbti` files, 67 of them belonging to
    the dependency tree, while the module owns 21;
  * the snapshot was regenerated with all 88, so the local native gate went
    green -- and CI, which has no fetched tree, would have compared an 88-row
    snapshot against a 21-file disk and gone red.

A count that moves with whatever is lying in the working directory is not a
fact about the tree.  Both sides now skip every dot-prefixed directory, and
this detector holds the two sides to that one rule.

Exit 0 when they agree, 1 when they do not -- and it says WHICH side drifted
and where.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY_SKIP = os.path.join(ROOT, "tools", "gen_iface_data.py")
MBT_SKIP = os.path.join(ROOT, "tools", "ifacescan", "scan.mbt")


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def python_names(text):
    """The quoted names inside the SKIP = { ... } set literal."""
    m = re.search(r"^SKIP\s*=\s*\{(.*?)\}", text, re.DOTALL | re.MULTILINE)
    if not m:
        return None
    return set(re.findall(r'"([^"]+)"', m.group(1)))


def mbt_names(text):
    """The quoted names inside the `let skip = [ ... ]` array literal."""
    m = re.search(r"let\s+skip\s*=\s*\[(.*?)\]", text, re.DOTALL)
    if not m:
        return None
    return set(re.findall(r'"([^"]+)"', m.group(1)))


def has_rule(text, needle):
    return needle in text


def main():
    problems = []

    py_text = read(PY_SKIP)
    mbt_text = read(MBT_SKIP)

    py = python_names(py_text)
    mbt = mbt_names(mbt_text)
    if py is None:
        problems.append("tools/gen_iface_data.py: no SKIP = { ... } set literal found")
    if mbt is None:
        problems.append("tools/ifacescan/scan.mbt: no `let skip = [ ... ]` array literal found")

    if py is not None and mbt is not None:
        only_py = sorted(py - mbt)
        only_mbt = sorted(mbt - py)
        if only_py:
            problems.append(
                "tools/gen_iface_data.py skips %s but tools/ifacescan/scan.mbt does not"
                % ", ".join(only_py))
        if only_mbt:
            problems.append(
                "tools/ifacescan/scan.mbt skips %s but tools/gen_iface_data.py does not"
                % ", ".join(only_mbt))

    # The dot-prefix rule is the one that actually keeps the two sides equal in
    # the presence of a fetched dependency tree.  If either side loses it, the
    # explicit names alone are not enough -- and the failure is invisible until
    # a dependency happens to ship .mbti files.
    if not has_rule(py_text, 'startswith(".")') and not has_rule(py_text, "startswith('.')"):
        problems.append(
            "tools/gen_iface_data.py: the dot-prefix rule is gone "
            '(expected a startswith(".") test); a fetched dependency tree '
            "would come back into the snapshot")
    if not has_rule(mbt_text, 'has_prefix(".")'):
        problems.append(
            'tools/ifacescan/scan.mbt: the dot-prefix rule is gone '
            '(expected a has_prefix(".") test); the scan would see files the '
            "snapshot does not")

    if problems:
        print("FAIL  the two .mbti skip lists disagree:", file=sys.stderr)
        for p in problems:
            print("  - " + p, file=sys.stderr)
        print("", file=sys.stderr)
        print("Both sides must skip the same directories by the same rule;", file=sys.stderr)
        print("tools/validate_iface_skip_lists.py is what keeps them that way.", file=sys.stderr)
        return 1

    print("[OK] tools/gen_iface_data.py and tools/ifacescan/scan.mbt skip the same "
          "directories by the same rule (%d explicit name(s) + every dot-prefixed dir)"
          % len(py))
    return 0


if __name__ == "__main__":
    sys.exit(main())
