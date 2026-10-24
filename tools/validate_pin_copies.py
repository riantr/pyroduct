#!/usr/bin/env python3
"""Assert every dependency-version literal in the tree matches the pin in moon.mod.

Why this exists: `moon.mod` names the versions the release builds against, but
the repository also *states* those versions in prose -- 46 places as of
2026-10-24, across 19 files: the two READMEs, AGENTS.md, the architecture DOT
and DSL files, the package doc comments, the rendered face text ("依赖：
`riantr/moonbit_doubleML@0.164.34`"), the plugin's face catalog, and both
skill copies. Every one of those is a SECOND COPY of the pin.

Nothing bound the copies to the pin, so the release policy ("bump the
dependencies, then run the gate") silently created a trap: bump the pin in
`moon.mod`, and every copy still says the old version. The gate stays green --
`validate_resolved_deps.py` only compares the pin against the RESOLVED tree,
never against what the repository says -- and the repository starts lying about
which version it was built against. It has already happened in this repo: the
`multi` face catalog said `R1-R12` while the module printed `R1-R14`, and the
four dependency versions are restated in 19 files by hand.

So: every `package@version` literal in a tracked file must equal the version
`moon.mod` pins for that package. For a transitive dependency (one we do not
pin, e.g. `riantr/moonbit_image`, which `riantr/snn_mbt` pulls in), the
literal must equal the version the resolved tree reports.

What this check does NOT claim: that a stale version elsewhere in the prose is
caught. Only literals written as `package@version` are attributable; a version
mentioned in words ("0.163.3 深用", a deliberate feature-depth marker) is left
alone on purpose. The unwrapped scan below catches literals that a wrapped
line splits in two.

Usage:
    python tools/validate_pin_copies.py
    python tools/validate_pin_copies.py --tree-json path/to/tree.json
    python tools/validate_pin_copies.py --verbose

Exit 0 if every version literal matches, exit 1 if any does not.
"""
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from validate_resolved_deps import read_moon_mod, resolved_tree  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Files whose contents are generated or vendored; their version strings are
# the generator's business, not the pin's.
SKIP_SUFFIXES = (".zip", ".wasm", ".js.map", ".png", ".jpg", ".pdf", ".mbti")


def fail(message):
    print("ERROR  " + message)
    sys.exit(1)


def tracked_files():
    """Return the repo's tracked files, as paths relative to ROOT."""
    try:
        proc = subprocess.run(
            ["git", "ls-files", "-z"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if proc.returncode == 0 and proc.stdout.strip():
            return [name for name in proc.stdout.split("\0") if name]
    except OSError:
        pass
    # No git (or an empty index): walk the tree instead, skipping the usual
    # build and vendor directories.
    skip_dirs = {".git", "_build", "_depdiff", "node_modules", "target"}
    found = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        for name in filenames:
            full = os.path.join(dirpath, name)
            found.append(os.path.relpath(full, ROOT).replace(os.sep, "/"))
    return sorted(found)


def flatten(text):
    """Return (flat_text, line_of_index).

    Lines are joined WITHOUT a separator, so a literal that a wrapped line
    splits in two ("...`riantr/" on one line, "moonbit_static_analysis@0.4.33`"
    on the next) is still found as one string. The cost is that adjacent lines
    are treated as continuous text; every match is reported with its line
    number, so a false join is visible rather than silent.
    """
    chars = []
    lines = []
    line = 1
    for char in text:
        chars.append(char)
        lines.append(line)
        if char == "\n":
            line += 1
    return "".join(chars), lines


def scan_file(rel_path, packages):
    """Return (matches, skipped) for one file.

    matches: list of (package, version, line)
    skipped: True when the file is binary or unreadable as text
    """
    full = os.path.join(ROOT, rel_path)
    try:
        with open(full, "rb") as handle:
            raw = handle.read()
    except OSError:
        return [], True
    if b"\0" in raw:
        return [], True
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        return [], True
    flat, lines = flatten(text)
    found = []
    for package in packages:
        pattern = re.escape(package) + r"@(\d+\.\d+\.\d+)"
        for match in re.finditer(pattern, flat):
            index = min(match.start(), len(lines) - 1) if lines else 0
            found.append((package, match.group(1), lines[index] if lines else 1))
    return found, False


def main():
    verbose = "--verbose" in sys.argv
    tree_json_path = None
    if "--tree-json" in sys.argv:
        tree_json_path = sys.argv[sys.argv.index("--tree-json") + 1]

    _, pins = read_moon_mod()

    # Transitive packages are the ones the resolved tree reports that we do not
    # pin ourselves. Their literals must match what actually resolved.
    resolved = resolved_tree(tree_json_path)
    transitive = {
        name: info["version"]
        for name, info in resolved.items()
        if name not in pins and name != "riantr/pyroduct"
    }

    expected = {}
    for name, pinned in pins.items():
        if pinned is None:
            continue
        expected[name] = pinned
    for name, version in transitive.items():
        if version:
            expected[name] = version

    problems = []
    checked = 0
    per_package = {name: 0 for name in expected}

    print("=== Dependency version literals ===")
    print("pins from moon.mod: %s" % (", ".join(
        "%s@%s" % (n, v) for n, v in sorted(expected.items()))))
    print("scanning tracked files for `package@version` literals\n")

    for rel_path in tracked_files():
        if rel_path.endswith(SKIP_SUFFIXES):
            continue
        matches, skipped = scan_file(rel_path, expected)
        if skipped:
            continue
        for package, version, line in matches:
            checked += 1
            per_package[package] += 1
            want = expected[package]
            if version != want:
                problems.append(
                    "%s:%d says %s@%s but the pin is %s" % (rel_path, line, package, version, want)
                )
                print("FAIL  %s:%d  %s@%s  (pin: %s)" % (rel_path, line, package, version, want))
            elif verbose:
                print("ok    %s:%d  %s@%s" % (rel_path, line, package, version))

    print("\n--- coverage ---")
    for name in sorted(expected):
        print("  %-36s pin %-12s %d literal(s) checked" % (name, expected[name], per_package[name]))
    print("  %d literal(s) in total" % checked)

    if not checked:
        # A scan that found nothing is a scan that found nothing, not a pass.
        fail("no `package@version` literal was found in the tracked tree -- the scan is broken, not the tree")

    if problems:
        print("\nFAILURES: %d" % len(problems))
        for problem in problems:
            print("  - " + problem)
        return 1

    print("\nEvery dependency version literal matches the pin it copies.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
