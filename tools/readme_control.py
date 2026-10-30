#!/usr/bin/env python3
"""Positive control for the README criteria.

`tools/mutate_review.py` breaks the MoonBit source and asks whether the
criteria go red. This does the same for the criteria that read the two
READMEs, which are the ones most likely to rot silently: a number in prose
that no detector measures.

The gap this fills is not hypothetical. The English README's position x slot
claim was never checked at all, because the detector matched one physical
line and the sentence was hard-wrapped across two. The Chinese copy was
checked -- only because it happened to fit. A criterion whose result depends
on where the text was wrapped is not a criterion, so that one was rewritten to
read logical lines, and the two criteria below were added for the counts the
READMEs quote.

Each case here breaks ONE number and requires three things of the criterion
that is supposed to catch it:

  1. it goes RED (a non-zero exit),
  2. it NAMES the line it caught (a criterion that fails without saying
     where is a criterion nobody can act on), and
  3. the file comes back byte-for-byte (sha256 before and after).

Discipline, same as the Loop battery: a criterion that cannot be red is not a
criterion. "The test suite passed" is not a review.

The tool edits real files, so it takes a backup first (under `_build/`, which
is gitignored) and restores from the in-memory copy on every exit path,
including an exception. It does NOT refuse to run against a dirty tree: the
criterion it exercises lives in the Python detector, and the README it breaks
is restored to whatever it was -- committed or not. A tool that could not be
run in the moment it was needed would be a worse problem than the one it
solves.

Usage:
    python tools/readme_control.py
    python tools/readme_control.py --verbose

Exit 0 if every control went red and every file was restored, exit 1
otherwise.
"""
import hashlib
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP_DIR = os.path.join(ROOT, "_build", "readme_control")

FACTS = "tools/validate_readme_facts.py"
FACES = "tools/validate_cli_faces.py"

# (description, file, [(old, new), ...], criterion, expected substring)
#
# The `old` text must occur EXACTLY ONCE in the file, or the case is skipped
# and counted as a failure: a control that quietly does not apply is not a
# control. The tool asserts the uniqueness rather than assuming it.
CASES = [
    (
        "english: the position x slot no-way count",
        "README.mbt.md",
        [("228 honestly answer No-way", "229 honestly answer No-way")],
        FACTS,
        "combinations: expected (272, 228), got (272, 229)",
    ),
    (
        "english: the same count in the new agent section",
        "README.mbt.md",
        [("228 answer `Block`", "229 answer `Block`")],
        FACTS,
        "combinations: expected (272, 228), got (272, 229)",
    ),
    (
        "english: the position x slot total",
        "README.mbt.md",
        [("of 272 position × slot", "of 273 position × slot")],
        FACTS,
        "combinations: expected (272, 228), got (273, 228)",
    ),
    (
        "chinese: the position x slot no-way count",
        "README.zh.mbt.md",
        [("228 个如实回答 无路。", "229 个如实回答 无路。")],
        FACTS,
        "combinations: expected (272, 228), got (272, 229)",
    ),
    (
        "english: both claims deleted -- the criterion must say it cannot see it",
        "README.mbt.md",
        [
            ("combinations, 228 honestly answer No-way.", "combinations, no count here."),
            ("228 answer `Block`", "many answer `Block`"),
        ],
        FACTS,
        "no position x slot combination claim found",
    ),
    (
        "english: the quoted face count",
        "README.mbt.md",
        [("(31 faces)", "(30 faces)")],
        FACES,
        "claims 30 faces, the code has 31",
    ),
    (
        "english: the quoted subcommand count",
        "README.mbt.md",
        [("37 subcommands", "38 subcommands")],
        FACES,
        "claims 38 subcommands, the code has 37",
    ),
    (
        "chinese: the quoted face count",
        "README.zh.mbt.md",
        [("31 个面", "30 个面")],
        FACES,
        "claims 30 faces, the code has 31",
    ),
    (
        "chinese: the quoted subcommand count",
        "README.zh.mbt.md",
        [("37 个子命令", "38 个子命令")],
        FACES,
        "claims 38 subcommands, the code has 37",
    ),
]


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
        named = expected in out
        status = "CAUGHT" if (red and named and restored) else "SURVIVED"
        if status != "CAUGHT":
            failures.append(description)
        print(
            "[%s] %s -> %s exit=%d named=%s restored=%s"
            % (status, description, script, code, named, restored)
        )
        if verbose or status != "CAUGHT":
            for line in out.splitlines():
                if "combinations" in line or "claims" in line or "no position" in line:
                    print("        " + line.strip())

    # The tree must be exactly as it was, whatever happened above.
    for name, (_, before) in backups.items():
        now = sha256(os.path.join(ROOT, name))
        if now != before:
            print("[FAIL] %s was not restored (sha256 %s != %s)" % (name, now, before))
            failures.append(name)
    shutil.rmtree(BACKUP_DIR, ignore_errors=True)

    print()
    if failures:
        print("FAILED: %d of %d control(s): %s" % (len(failures), len(CASES), failures))
        return 1
    print(
        "all %d controls went red, named the line they caught, and left the tree byte-for-byte"
        % len(CASES)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
