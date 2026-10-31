#!/usr/bin/env python3
"""Positive control for the dependency-literal detector.

`tools/mutate_review.py` breaks the MoonBit source and asks whether the
criteria go red. This does the same for `tools/validate_pin_copies.py`, the
detector that watches the copies of the dependency pins.

Two criteria live in that detector, and both are the kind that rot silently:

  1. every `package@version` literal in the tree matches the pin, and
  2. every claim of HOW MANY literals the tree holds matches the tree.

The second one exists because the first is not enough. A release bumps a pin
and the copies move with it, but the *count* of those copies is a number
written in prose somewhere else, and nothing was watching it: three places in
the tree said 53 while the scan measured something else, and the drift went
unnoticed for a whole release.

The first case below also guards a hole that was found in the same file. The
detector's docstring claimed it caught a literal "that a wrapped line splits
in two", but its text-flattening step kept the newline, so a literal broken
across two lines was two strings and never matched -- measured: 0 found,
while the same literal on one line was found once. Case 2 splits a literal
across two lines and makes it stale; before the fix the detector was green on
it, which is the shape of a criterion that cannot fail.

Case 3 covers a blind spot the other two could not: a file that is not staged
yet is not in `git ls-files`, so a detector whose subject is the tracked tree
cannot see it. The gap is exactly the size of "the file you just wrote" -- the
local gate was green on a file that CI then found stale, because the file only
became tracked when it was committed.

WHY THIS FILE BUILDS ITS OWN STRINGS
-------------------------------------
Every string this control breaks is assembled at RUN TIME, never written out
here. Two reasons, both learned the hard way:

  - a version written as `package@version` in this file's source is an
    attributable literal, and the detector would flag it -- so the control
    would be the thing breaking the tree it is meant to test;
  - a phrase like "N literals" in this file's source is a COUNT CLAIM, and
    the detector checks every count claim in the tree.

So the package name and the versions are kept in separate variables, and the
count claims are formatted from numbers. A previous version of this file broke
both rules at once, and the CI run caught it: the control was red before it
had ever been run.

Each case here breaks ONE thing and requires three things of the detector
that is supposed to catch it:

  1. it goes RED (a non-zero exit),
  2. it NAMES the place it caught (a criterion that fails without saying
     where is a criterion nobody can act on), and
  3. the file comes back byte-for-byte (sha256 before and after).

Discipline, same as the Loop battery: a criterion that cannot be red is not a
criterion. "The detector passed" is not a review.

The tool edits real files, so it takes a backup first (under `_build/`, which
is gitignored) and restores from the in-memory copy on every exit path,
including an exception. It does NOT refuse to run against a dirty tree: the
criterion it exercises lives in the Python detector, and the file it breaks
is restored to whatever it was -- committed or not. A tool that could not be
run in the moment it was needed would be a worse problem than the one it
solves.

Usage:
    python tools/pin_copies_control.py
    python tools/pin_copies_control.py --verbose

Exit 0 if every control went red and every file was restored, exit 1
otherwise.
"""
import hashlib
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP_DIR = os.path.join(ROOT, "_build", "pin_copies_control")
sys.path.insert(0, os.path.join(ROOT, "tools"))

from validate_resolved_deps import read_moon_mod  # noqa: E402

CRITERION = "tools/validate_pin_copies.py"

# The package whose pin this control breaks. The version is NEVER written
# next to it in this file -- see the note above the imports.
PINNED_PACKAGE = "riantr/moonbit_doubleML"

# The tree's own count of its literals, as the tree states it today. A
# release that moves the count must move this too: the `old` text has to
# occur exactly once in AGENTS.md, and the control says so out loud when it
# does not, because a control that quietly does not apply is not a control.
TREE_LITERALS = 56
TREE_FILES = 19


def pin_version(package):
    """The version moon.mod pins for `package`, read at run time.

    Read from moon.mod rather than written here, so the control survives a
    pin bump: the README's copy of the literal moves with the pin, and this
    file reads whichever version is current.
    """
    _, pins = read_moon_mod()
    return pins[package]


GOOD_VERSION = pin_version(PINNED_PACKAGE)
# A version that cannot be the pin, so the detector must reject it.
STALE_VERSION = "0.0.1"

GOOD_LITERAL = "%s@%s" % (PINNED_PACKAGE, GOOD_VERSION)
STALE_LITERAL = "%s@%s" % (PINNED_PACKAGE, STALE_VERSION)

# The count claim under test, and the broken one. Both are formatted from
# numbers, so this file states no count claim of its own.
GOOD_COUNT_CLAIM = "%d literals, %d files" % (TREE_LITERALS, TREE_FILES)
BROKEN_COUNT_CLAIM = "%d literals, %d files" % (TREE_LITERALS - 1, TREE_FILES)
COUNT_MISMATCH = "claims %d literals, the tree has %d" % (
    TREE_LITERALS - 1,
    TREE_LITERALS,
)

# The README sentence that carries the literal, and the same sentence with the
# literal broken across two lines and made stale.
README_OLD = "`%s` → `dmlref`" % GOOD_LITERAL
README_NEW = "`%s` → `dmlref`" % (
    "%s@\n  %s" % (PINNED_PACKAGE, STALE_VERSION),
)

# (description, file, [(old, new), ...], criterion, [required substrings])
#
# The `old` text must occur EXACTLY ONCE in the file, or the case is skipped
# and counted as a failure: a control that quietly does not apply is not a
# control. The tool asserts the uniqueness rather than assuming it.
CASES = [
    (
        "the tree's own count of its literals",
        "AGENTS.md",
        [(GOOD_COUNT_CLAIM, BROKEN_COUNT_CLAIM)],
        CRITERION,
        ["AGENTS.md:", COUNT_MISMATCH],
    ),
    (
        "a literal split across two lines -- the wrap the docstring promised to catch",
        "README.mbt.md",
        [(README_OLD, README_NEW)],
        CRITERION,
        ["README.mbt.md:", STALE_LITERAL],
    ),
]

# The probe for the third case: a file that is NOT tracked, holding a stale
# literal. The detector must see it anyway.
PROBE_REL = "tools/_pin_copies_probe.txt"
PROBE_NAME = "pin_copies_probe"


def sha256(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def dirty_files():
    """The tracked files this tool would edit that already carry a change."""
    proc = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proc.returncode != 0:
        return []
    dirty = set()
    for line in proc.stdout.splitlines():
        name = line[3:].strip().strip('"')
        if " -> " in name:
            name = name.split(" -> ")[-1]
        dirty.add(name)
    return dirty


def run_criterion(script):
    proc = subprocess.run(
        [sys.executable, script],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return proc.returncode, proc.stdout + proc.stderr


def take_backup(name, data):
    """A second copy on disk, so even a hard kill leaves a way back."""
    os.makedirs(BACKUP_DIR, exist_ok=True)
    path = os.path.join(BACKUP_DIR, name)
    with open(path, "wb") as handle:
        handle.write(data)
    return path


def run_untracked_case(verbose):
    """The third case: a stale literal in a file that is not staged yet.

    The probe file is created, the detector must go red and name it, and the
    file is removed again -- on every exit path, including an exception.
    """
    probe = os.path.join(ROOT, PROBE_REL)
    body = ("a stale literal in a file that is not staged yet: %s\n" % STALE_LITERAL).encode("utf-8")
    existed = os.path.exists(probe)
    previous = None
    if existed:
        with open(probe, "rb") as handle:
            previous = handle.read()
    try:
        with open(probe, "wb") as handle:
            handle.write(body)
        code, out = run_criterion(CRITERION)
    finally:
        if existed:
            with open(probe, "wb") as handle:
                handle.write(previous)
        elif os.path.exists(probe):
            os.remove(probe)

    red = code != 0
    named = PROBE_NAME in out and STALE_LITERAL in out
    status = "CAUGHT" if (red and named) else "SURVIVED"
    print(
        "[%s] a stale literal in a file that is not staged yet -> %s exit=%d named=%s"
        % (status, CRITERION, code, named)
    )
    if verbose or status != "CAUGHT":
        for line in out.splitlines():
            if "FAIL" in line or "claims" in line or "says" in line:
                print("        " + line.strip())
    return status == "CAUGHT"


def main():
    verbose = "--verbose" in sys.argv

    touched = {case[1] for case in CASES}
    dirty = dirty_files()
    for name in sorted(touched & dirty):
        print("note: %s has uncommitted changes; it will be restored to exactly those bytes" % name)

    backups = {}
    for name in sorted(touched):
        path = os.path.join(ROOT, name)
        data = open(path, "rb").read()
        backups[name] = (data, sha256(path))
        take_backup(name, data)

    failures = []
    for description, name, edits, script, expected in CASES:
        path = os.path.join(ROOT, name)
        original, before = backups[name]
        text = original.decode("utf-8")

        applied = True
        for old, new in edits:
            count = text.count(old)
            if count != 1:
                print("[SKIP] %s: %r occurs %d times in %s" % (description, old, count, name))
                failures.append(description)
                applied = False
                break
            text = text.replace(old, new)
        if not applied:
            continue

        try:
            with open(path, "wb") as handle:
                handle.write(text.encode("utf-8"))
            code, out = run_criterion(script)
        finally:
            with open(path, "wb") as handle:
                handle.write(original)

        after = sha256(path)
        restored = after == before
        red = code != 0
        named = all(wanted in out for wanted in expected)
        status = "CAUGHT" if (red and named and restored) else "SURVIVED"
        if status != "CAUGHT":
            failures.append(description)
        print(
            "[%s] %s -> %s exit=%d named=%s restored=%s"
            % (status, description, script, code, named, restored)
        )
        if verbose or status != "CAUGHT":
            for line in out.splitlines():
                if "FAIL" in line or "claims" in line or "says" in line:
                    print("        " + line.strip())

    if not run_untracked_case(verbose):
        failures.append("a stale literal in a file that is not staged yet")

    # The tree must be exactly as it was, whatever happened above.
    for name, (_, before) in backups.items():
        now = sha256(os.path.join(ROOT, name))
        if now != before:
            print("[FAIL] %s was not restored (sha256 %s != %s)" % (name, now, before))
            failures.append(name)
    shutil.rmtree(BACKUP_DIR, ignore_errors=True)

    print()
    if failures:
        print("FAILED: %d of %d control(s): %s" % (len(failures), len(CASES) + 1, failures))
        return 1
    print(
        "all %d controls went red, named the place they caught, and left the tree byte-for-byte"
        % (len(CASES) + 1)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
