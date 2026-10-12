#!/usr/bin/env python3
"""Validate that architecture dependency diagrams match actual moon.pkg imports.

Usage:
    python tools/validate_dependencies.py
    python tools/validate_dependencies.py --verbose

Exit 0 if all edges match, exit 1 if drift detected.

Checks:
  - Edges in DOT but not in code (false edges: diagram claims a dependency that doesn't exist)
  - Edges in code but not in DOT (missing edges: diagram omits a real dependency)

Only first-party (riantr/pyroduct/*) imports are checked. External dependencies
(moonbitlang/*, riantr/moonbit_doubleML, etc.) are excluded because the DOT files
represent them as boundary nodes with different naming conventions.

Scope: module-dependencies.dot and dependency-map.dot in architecture/.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DOT_FILES = [
    os.path.join(ROOT, "architecture", "module-dependencies.dot"),
    os.path.join(ROOT, "architecture", "dependency-map.dot"),
]

EXTERNAL_PREFIXES = (
    "moonbitlang/",
    "riantr/moonbit_doubleML",
    "riantr/snn_mbt",
    "riantr/moonbit_image",
    "riantr/moonbit_static_analysis",
)

PYRODUCT_PREFIX = "riantr/pyroduct/"

DIRS_NOT_IN_ARCH_DIAGRAMS = (
    "examples/",
    "tools/",
)


def pkg_path_to_dir(pkg_path):
    """Strip the riantr/pyroduct/ prefix to get the local directory."""
    if pkg_path.startswith(PYRODUCT_PREFIX):
        return pkg_path[len(PYRODUCT_PREFIX):]
    return None


def dir_to_dot_node(d):
    """Map a package directory to its DOT node name.

    Simple packages: src -> src, multi -> multi
    Nested packages: cmd/main -> cmd_main, cmd/jsoncli -> cmd_jsoncli
    """
    return d.replace("/", "_")


def discover_moon_pkgs():
    """Find all moon.pkg files, excluding build artifacts and dependencies."""
    pkgs = []
    skip_dirs = {"_build", ".mooncakes", "node_modules", ".git"}
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        if "moon.pkg" in filenames:
            pkgs.append(dirpath)
    return pkgs


def parse_moon_pkg(pkg_dir):
    """Parse a moon.pkg file and return the list of first-party imports.

    Returns list of (imported_dir, alias_or_None) tuples.
    Only riantr/pyroduct/* imports are returned; external deps are skipped.
    """
    path = os.path.join(pkg_dir, "moon.pkg")
    if not os.path.exists(path):
        return []

    with open(path, encoding="utf-8") as f:
        content = f.read()

    imports = []
    in_import_block = False
    for line in content.split("\n"):
        stripped = line.strip()
        if stripped.startswith("import"):
            in_import_block = True
            continue
        if in_import_block:
            if stripped == "}":
                in_import_block = False
                continue
            if stripped.startswith("//") or not stripped:
                continue
            m = re.match(r'"([^"]+)"(?:\s+@(\w+))?', stripped)
            if m:
                full_path = m.group(1)
                alias = m.group(2)
                local_dir = pkg_path_to_dir(full_path)
                if local_dir is not None:
                    imports.append((local_dir, alias))

    return imports


def parse_dot_edges(dot_path):
    """Parse a DOT file and extract first-party dependency edges.

    Returns list of (from_dir, to_dir) tuples.
    Only edges between known pyroduct packages are returned.
    """
    if not os.path.exists(dot_path):
        return []

    with open(dot_path, encoding="utf-8") as f:
        content = f.read()

    known_dirs = set()
    for pkg_dir in discover_moon_pkgs():
        rel = os.path.relpath(pkg_dir, ROOT).replace(os.sep, "/")
        known_dirs.add(rel)

    known_nodes = {dir_to_dot_node(d) for d in known_dirs}

    edges = []
    edge_pattern = re.compile(r"(\w+)\s*->\s*(\w+)\s*\[")
    for line in content.split("\n"):
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        m = edge_pattern.search(stripped)
        if m:
            from_node = m.group(1)
            to_node = m.group(2)
            if from_node in known_nodes and to_node in known_nodes:
                from_dir = from_node.replace("_", "/", 1) if "_" in from_node else from_node
                to_dir = to_node.replace("_", "/", 1) if "_" in to_node else to_node
                if from_dir in known_dirs and to_dir in known_dirs:
                    edges.append((from_dir, to_dir))

    return edges


def node_to_dir(node_name, known_dirs):
    """Convert a DOT node name back to a package directory.

    Handles both simple names (src -> src) and compound names (cmd_main -> cmd/main).
    Falls back to checking all known dirs for a match.
    """
    simple = node_name.replace("_", "/")
    if simple in known_dirs:
        return simple
    if node_name in known_dirs:
        return node_name
    for d in known_dirs:
        if dir_to_dot_node(d) == node_name:
            return d
    return None


def get_moon_mod_version():
    """Read the version from moon.mod."""
    moon_mod_path = os.path.join(ROOT, "moon.mod")
    with open(moon_mod_path, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip().startswith("version"):
                # version = "0.1.29"
                match = re.search(r'version\s*=\s*"([^"]+)"', line)
                if match:
                    return match.group(1)
    return None


def check_version_pins():
    """Check that all DOT files carry the current moon.mod version pin."""
    expected_version = get_moon_mod_version()
    if not expected_version:
        print("FAIL  Could not read version from moon.mod")
        return False

    arch_dir = os.path.join(ROOT, "architecture")
    if not os.path.exists(arch_dir):
        print("SKIP  architecture/ directory not found")
        return True

    dot_files = [f for f in os.listdir(arch_dir) if f.endswith(".dot")]
    if not dot_files:
        print("SKIP  No DOT files found in architecture/")
        return True

    all_ok = True
    for dot_file in sorted(dot_files):
        dot_path = os.path.join(arch_dir, dot_file)
        with open(dot_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Look for // model-version: X.Y.Z
        match = re.search(r"^// model-version:\s*(\S+)", content, re.MULTILINE)
        if not match:
            print(f"FAIL  {dot_file}: missing version pin (expected // model-version: {expected_version})")
            all_ok = False
        else:
            actual_version = match.group(1)
            if actual_version != expected_version:
                print(f"FAIL  {dot_file}: version pin mismatch (expected {expected_version}, got {actual_version})")
                all_ok = False
            else:
                print(f"OK    {dot_file}: pinned to {actual_version}")

    return all_ok


def main():
    verbose = "--verbose" in sys.argv

    # Check version pins first
    print("=== Version Pin Check ===")
    pins_ok = check_version_pins()
    print()

    # Then check dependency edges
    print("=== Dependency Edge Check ===")
    pkg_dirs = discover_moon_pkgs()
    known_dirs = set()
    for pkg_dir in pkg_dirs:
        rel = os.path.relpath(pkg_dir, ROOT).replace(os.sep, "/")
        known_dirs.add(rel)

    code_edges = set()
    for pkg_dir in pkg_dirs:
        rel = os.path.relpath(pkg_dir, ROOT).replace(os.sep, "/")
        for imported_dir, _alias in parse_moon_pkg(pkg_dir):
            if any(rel.startswith(p) or imported_dir.startswith(p) for p in DIRS_NOT_IN_ARCH_DIAGRAMS):
                continue
            code_edges.add((rel, imported_dir))

    if verbose:
        print(f"Found {len(pkg_dirs)} packages, {len(code_edges)} first-party import edges")
        for frm, to in sorted(code_edges):
            print(f"  {frm} -> {to}")
        print()

    all_ok = True

    for dot_path in DOT_FILES:
        dot_name = os.path.relpath(dot_path, ROOT)
        if not os.path.exists(dot_path):
            print(f"SKIP  {dot_name} (not found)")
            continue

        dot_edges = set(parse_dot_edges(dot_path))

        false_edges = dot_edges - code_edges
        missing_edges = code_edges - dot_edges

        if not false_edges and not missing_edges:
            print(f"OK    {dot_name} ({len(dot_edges)} edges match code)")
        else:
            all_ok = False
            if false_edges:
                print(f"FAIL  {dot_name}: {len(false_edges)} false edge(s) (in diagram, not in code):")
                for frm, to in sorted(false_edges):
                    print(f"        {frm} -> {to}")
            if missing_edges:
                print(f"FAIL  {dot_name}: {len(missing_edges)} missing edge(s) (in code, not in diagram):")
                for frm, to in sorted(missing_edges):
                    print(f"        {frm} -> {to}")

    if all_ok and pins_ok:
        print(f"\nAll checks passed: {len(DOT_FILES)} diagram(s) match code ({len(code_edges)} edges), all version pins correct.")
        return 0
    else:
        if not all_ok:
            print(f"\nDependency drift detected. Update the DOT files or fix the imports.")
        if not pins_ok:
            print(f"\nVersion pin drift detected. Update the DOT file headers to match moon.mod version.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
