#!/usr/bin/env python3
"""Keep the three copies of the face/subcommand list in agreement.

There are three lists of the same names, in three files, and nothing compared
them:

  1. `cmd/jsoncli/main.mbt`  `faces()` — the 31 model-facing faces, returned
     in every bridge reply and read by the plugins;
  2. `cmd/main/main.mbt`      the `match` arms — the CLI's dispatch, which
     also carries the six viz-composite subcommands the bridge does not;
  3. `cmd/main/main.mbt`      the usage header — the list a human reads to
     learn what the CLI can do.

A face added to one and forgotten in another is invisible until someone runs
the missing spelling and gets the wrong answer. This asserts the three agree,
and that the count the CLI's own error message publishes is the real one --
a published count that nothing measures is a number that rots.

The plugin's copy (`plugin/server.mjs` FACES) is held to the bridge by
`plugin/tools/validate-plugin.mjs`; this file covers the CLI side.

Usage:
    python tools/validate_cli_faces.py
    python tools/validate_cli_faces.py --verbose

Exit 0 if the lists agree, exit 1 if they drift.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CMD_MAIN = os.path.join(ROOT, "cmd", "main", "main.mbt")
BRIDGE = os.path.join(ROOT, "cmd", "jsoncli", "main.mbt")

# The CLI can also render the viz composites, which are presentation rather
# than model facts and therefore deliberately absent from the bridge's list.
CLI_ONLY = {"society-mermaid", "group-mermaid", "nested-mermaid", "journey", "viz", "all"}


def read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def bridge_faces(text):
    """The names in the bridge's `faces()` array."""
    block = re.search(r"fn faces\(\)\s*->\s*Array\[String\]\s*\{(.*?)\n\}", text, re.DOTALL)
    if not block:
        return None
    return re.findall(r'"([a-z][a-z-]*)"', block.group(1))


def cli_arms(text):
    """The names the CLI's `match format` actually dispatches on."""
    block = re.search(r"match format\s*\{(.*?)\n  \}\n\}", text, re.DOTALL)
    if not block:
        return None
    return re.findall(r'^\s{4}"([a-z][a-z-]*)"\s*=>', block.group(1), re.MULTILINE)


def cli_usage_list(text):
    """The names the usage header tells a human to type.

    Only the file's leading doc block counts: the header is the list a human
    reads. Scanning the whole file would also pick up the names quoted in
    explanatory comments (and in the error message), which are prose about
    the CLI, not the CLI's own list.
    """
    header = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped == "":
            header.append("")
            continue
        if stripped.startswith("///"):
            header.append(stripped)
            continue
        break
    return re.findall(r"moon run cmd/main -- ([a-z][a-z-]*)", "\n".join(header))


def published_count(text):
    """The count the CLI's own error message publishes."""
    match = re.search(r"共\s*(\d+)\s*个", text)
    return int(match.group(1)) if match else None


def main():
    verbose = "--verbose" in sys.argv
    cmd_text = read(CMD_MAIN)
    bridge_text = read(BRIDGE)

    faces = bridge_faces(bridge_text)
    arms = cli_arms(cmd_text)
    usage = cli_usage_list(cmd_text)
    count = published_count(cmd_text)

    if faces is None:
        print("ERROR  could not find the bridge's faces() list")
        return 1
    if arms is None:
        print("ERROR  could not find the CLI's match arms")
        return 1

    problems = []
    print("=== the face lists ===")
    print(f"bridge faces()        : {len(faces)}")
    print(f"CLI match arms        : {len(arms)}")
    print(f"CLI usage header      : {len(usage)}")
    print(f"CLI error message says: {count}")

    expected_arms = set(faces) | CLI_ONLY
    missing = sorted(expected_arms - set(arms))
    extra = sorted(set(arms) - expected_arms)
    if missing:
        problems.append(f"the CLI cannot dispatch: {', '.join(missing)}")
    if extra:
        problems.append(f"the CLI dispatches names the bridge does not know: {', '.join(extra)}")
    if len(arms) != len(set(arms)):
        problems.append("the CLI has a duplicated arm")

    missing_usage = sorted(set(arms) - set(usage))
    extra_usage = sorted(set(usage) - set(arms))
    if missing_usage:
        problems.append(f"the usage header does not mention: {', '.join(missing_usage)}")
    if extra_usage:
        problems.append(f"the usage header mentions arms that do not exist: {', '.join(extra_usage)}")

    if count is None:
        problems.append("the CLI's error message publishes no subcommand count")
    elif count != len(arms):
        problems.append(
            f"the CLI's error message says {count} subcommands but it dispatches {len(arms)}"
        )

    if verbose:
        print("\nbridge faces:", " ".join(faces))
        print("CLI arms    :", " ".join(arms))
        print("usage header:", " ".join(usage))

    if problems:
        print("\nFAILURES:")
        for problem in problems:
            print("  - " + problem)
        return 1

    print("\nThe bridge, the CLI dispatch, the usage header and the published count all agree.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
