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
count of literals the tree claims is DISCOVERED at run time -- measured from
the detector's own output and located with the detector's own pattern -- rather
than written here. A previous version of this file broke both rules at once,
and the CI run caught it: the control was red before it had ever been run.

That discovery is not cosmetic. This file used to carry the tree's literal
count as a number of its own, on the reasoning that "a release that moves the
count must move this too". That reasoning is the rot the detector exists to
catch, one layer up: the number here was a SECOND COPY of a measured number,
it was not covered by any detector, and it went stale -- the control's first
case then stopped applying, because the text it looks for no longer existed
anywhere in the tree. The case did not fail; it vanished. Now the count is
measured, so it cannot rot, and if the tree's claim cannot be found at all
the control says so out loud instead of skipping quietly.

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
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP_DIR = os.path.join(ROOT, "_build", "pin_copies_control")
sys.path.insert(0, os.path.join(ROOT, "tools"))

from validate_resolved_deps import read_moon_mod  # noqa: E402
from validate_pin_copies import LITERAL_COUNT_CLAIM  # noqa: E402

CRITERION = "tools/validate_pin_copies.py"

# The package whose pin this control breaks. The version is NEVER written
# next to it in this file -- see the note above the imports.
PINNED_PACKAGE = "riantr/moonbit_doubleML"

# Where the tree states how many dependency literals it holds. The NUMBER is
# not written in this file: it is measured at run time from the detector's
# own output (see `measured_counts`), so a release that moves the count does
# not have to move this file for the control to keep applying.
COUNT_CLAIM_FILE = "AGENTS.md"


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

# The count claim under test is NOT built here -- it is measured at run time
# and located in the tree by `build_count_case`. It used to be written in this
# file as a pair of numbers, which is how it went stale without anybody
# noticing: the control's first case then looked for text that no longer
# existed anywhere in the tree, so it did not fail -- it vanished.

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
#
# The count-claim case is NOT in this list: it is built at run time by
# `build_count_case()` and prepended to it, because it needs the measured
# count before it can break anything.
CASES = [
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


class ControlSetupError(Exception):
    """The control cannot be set up against the tree as it stands.

    Reported loudly and never skipped silently: a control that quietly does
    not apply is not a control, and one that applies to the wrong thing
    (here: a claim that was already stale) is worse -- the detector would go
    red for the wrong reason and the control would look like it works.
    """


def measured_counts():
    """Ask the detector how many literals the tracked tree holds.

    The counts are READ FROM THE DETECTOR'S OWN OUTPUT, never written in
    this file. A hard-coded count here would be exactly the rot the detector
    exists to catch, one layer up: the number moves whenever a release adds
    or removes a copy, and a control that has to be edited in the same commit
    as the tree is a control that quietly stops applying -- which is what
    happened here once already.

    Returns (literals, files); either is None when the output did not carry
    it.
    """
    _, out = run_criterion(CRITERION)
    literals = None
    files = None
    for line in out.splitlines():
        found = re.search(r"(\d+)\s+literal\(s\)\s+in\s+total", line)
        if found:
            literals = int(found.group(1))
        found = re.search(r"across\s+(\d+)\s+file\(s\)", line)
        if found:
            files = int(found.group(1))
    return literals, files


def build_count_case():
    """Build the case that breaks the tree's own claim of how many literals it holds.

    The claims are LOCATED with the detector's own pattern, and the number
    that is broken is the number the detector MEASURED. Both halves matter:

      - locating them with the detector's pattern means the control and the
        detector agree on what a claim looks like, so a change to the
        detector's notion of a claim cannot strand the control;
      - breaking the MEASURED number means the case can only go red because
        the claim now disagrees with the tree. Breaking a claim that was
        already stale would go red for the wrong reason, and the control
        would report success while testing nothing.

    EVERY claim in the file is broken, not just the first one. The detector's
    own rule is "by pattern over EVERY occurrence, not by reading one blessed
    location"; a control that broke only the first claim would pass even if
    the detector had been narrowed to look at one place. So the control
    requires the detector to name EACH broken line -- that is the property
    under test, not a detail.

    Returns a case tuple, the same shape as the static cases.
    """
    literals, files = measured_counts()
    if not literals or not files:
        raise ControlSetupError(
            "the detector did not report its literal and file counts, so the "
            "count-claim case cannot be set up"
        )

    path = os.path.join(ROOT, COUNT_CLAIM_FILE)
    with open(path, "rb") as handle:
        text = handle.read().decode("utf-8")

    edits = []
    expected = []
    for number, line in enumerate(text.splitlines(), 1):
        claim = LITERAL_COUNT_CLAIM.search(line)
        if not claim or int(claim.group(1)) != literals:
            continue
        broken = LITERAL_COUNT_CLAIM.sub(
            lambda match: "%d literals" % (literals - 1), line, count=1
        )
        if broken == line:
            raise ControlSetupError(
                "the count claim in %s:%d did not change when it was broken"
                % (COUNT_CLAIM_FILE, number)
            )
        edits.append((line, broken))
        expected.append(
            "%s:%d claims %d literals, the tree has %d"
            % (COUNT_CLAIM_FILE, number, literals - 1, literals)
        )

    if not edits:
        raise ControlSetupError(
            "no line in %s claims %d literals, so the count-claim case cannot "
            "be set up" % (COUNT_CLAIM_FILE, literals)
        )

    return (
        "the tree's own count of its literals",
        COUNT_CLAIM_FILE,
        edits,
        CRITERION,
        expected,
    )


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

    try:
        count_case = build_count_case()
    except ControlSetupError as exc:
        print("[FAIL] %s" % exc)
        return 1
    cases = [count_case] + CASES

    touched = {case[1] for case in cases}
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
    for description, name, edits, script, expected in cases:
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
        print("FAILED: %d of %d control(s): %s" % (len(failures), len(cases) + 1, failures))
        return 1
    print(
        "all %d controls went red, named the place they caught, and left the tree byte-for-byte"
        % (len(cases) + 1)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
