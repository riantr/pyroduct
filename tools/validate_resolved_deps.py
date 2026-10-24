#!/usr/bin/env python3
"""Assert the RESOLVED dependency tree matches the pins written in moon.mod.

Why this exists: the pins in `moon.mod` are a promise about what the gate
builds. Two commands look like they might keep that promise honest, and
neither does:

  * `moon update` refreshes the REGISTRY INDEX. It does not touch moon.mod
    and does not touch what gets resolved.
  * `moon upgrade` upgrades the TOOLCHAIN (the MoonBit compiler itself) --
    it is not a dependency command at all.

So nothing in the build asserted that the versions actually resolved are the
versions the release names. If the registry served something else, or a
version could not be resolved at all, the gate would still be green -- on a
tree that is not the one the tag claims.

What this check does NOT claim: that editing a pin is an error. Measured
2026-10-24: `moon tree --json` re-resolves and FOLLOWS the pin (change the
pin to another published version and the tree reports that version), so a
pin edit moves both sides of this comparison and the check stays green. That
is correct -- a pin edit is a developer's legitimate action, and the tree
tracking it is the tree doing its job. What must never happen is the two
sides drifting apart, or the resolution failing quietly.

This check closes that gap: every pin in moon.mod must appear in the resolved
tree at exactly that version, and the root module must resolve at the version
moon.mod declares. Transitive dependencies are listed for information: we do
not pin them, so they are not ours to assert.

Usage:
    python tools/validate_resolved_deps.py
    python tools/validate_resolved_deps.py --tree-json path/to/tree.json
    python tools/validate_resolved_deps.py --verbose

Exit 0 if the resolved tree matches the pins, exit 1 if it does not.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOON_MOD = os.path.join(ROOT, "moon.mod")


def fail(message):
    print("ERROR  " + message)
    sys.exit(1)


def read_moon_mod():
    """Return (version, {module: pinned_version}) from moon.mod."""
    try:
        with open(MOON_MOD, "r", encoding="utf-8") as handle:
            text = handle.read()
    except OSError as error:
        fail("cannot read moon.mod: %s" % error)

    version_match = re.search(r'^version\s*=\s*"([^"]+)"', text, re.MULTILINE)
    if not version_match:
        fail("moon.mod has no `version = \"...\"` line")
    version = version_match.group(1)

    pins = {}
    block = re.search(r"^import\s*\{(.*?)\}", text, re.MULTILINE | re.DOTALL)
    if block:
        for entry in block.group(1).split(","):
            entry = entry.strip().strip('"').strip("'")
            if not entry:
                continue
            if "@" in entry:
                name, pinned = entry.rsplit("@", 1)
            else:
                name, pinned = entry, None
            pins[name.strip()] = pinned.strip() if pinned else None
    return version, pins


def resolved_tree(tree_json_path=None):
    """Return the resolved module -> version map, or fail loudly."""
    if tree_json_path:
        try:
            with open(tree_json_path, "r", encoding="utf-8") as handle:
                payload = json.load(handle)
        except (OSError, ValueError) as error:
            fail("cannot read tree json %s: %s" % (tree_json_path, error))
    else:
        try:
            proc = subprocess.run(
                ["moon", "tree", "--json"],
                cwd=ROOT,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
        except OSError as error:
            fail("cannot run `moon tree --json`: %s" % error)
        if proc.returncode != 0:
            fail(
                "`moon tree --json` failed (exit %d):\n%s"
                % (proc.returncode, (proc.stderr or proc.stdout or "").strip()[:600])
            )
        try:
            payload = json.loads(proc.stdout)
        except ValueError as error:
            fail("`moon tree --json` did not return JSON: %s" % error)

    if payload.get("status") != "success":
        fail("`moon tree --json` reported status=%r error=%r" % (payload.get("status"), payload.get("error")))

    resolved = {}
    for module in payload.get("modules", []):
        resolved[module["name"]] = {
            "version": module.get("version"),
            "source": (module.get("source") or {}).get("kind"),
        }
    return resolved


def main():
    verbose = "--verbose" in sys.argv
    tree_json_path = None
    if "--tree-json" in sys.argv:
        tree_json_path = sys.argv[sys.argv.index("--tree-json") + 1]

    version, pins = read_moon_mod()
    resolved = resolved_tree(tree_json_path)

    root_name = "riantr/pyroduct"
    if root_name not in resolved:
        fail("the resolved tree has no %s root module" % root_name)
    if resolved[root_name]["version"] != version:
        fail(
            "moon.mod says %s@%s but the resolved root is %s@%s"
            % (root_name, version, root_name, resolved[root_name]["version"])
        )

    problems = []
    print("=== Resolved dependency pins ===")
    for name in sorted(pins):
        pinned = pins[name]
        actual = resolved.get(name)
        if actual is None:
            problems.append("%s is pinned at %s but did not resolve" % (name, pinned))
            print("FAIL  %-36s pinned %-12s  NOT RESOLVED" % (name, pinned))
            continue
        actual_version = actual["version"]
        if pinned is None:
            print("ok    %-36s unpinned       resolved %s" % (name, actual_version))
            continue
        if actual_version != pinned:
            problems.append(
                "%s is pinned at %s but resolved at %s" % (name, pinned, actual_version)
            )
            print("FAIL  %-36s pinned %-12s  resolved %s" % (name, pinned, actual_version))
        else:
            print("ok    %-36s pinned %-12s  resolved %s" % (name, pinned, actual_version))

    transitive = sorted(
        name
        for name, info in resolved.items()
        if name != root_name and name not in pins
    )
    if transitive:
        print("\n(not pinned by us -- resolved through the pins above)")
        for name in transitive:
            print("      %-36s %s" % (name, resolved[name]["version"]))

    if problems:
        print("\nFAILURES: %d" % len(problems))
        for problem in problems:
            print("  - " + problem)
        return 1

    if verbose:
        print("\nresolved edges:")
        print(json.dumps(resolved, indent=2, ensure_ascii=False, sort_keys=True))
    print("\nAll pins resolved to exactly the versions moon.mod names.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
