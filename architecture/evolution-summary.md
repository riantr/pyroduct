# Evolution Summary — Living Architecture Automation

> **Why**: Architecture artifacts drifted twice (dependency edge error, test count 190→197) without detection. Manual maintenance is insufficient.
> **What**: Add CI-enforced drift detection for module dependencies and plugin descriptions.
> **How**: Four migration slices, each independently valuable, total ~2 hours implementation.
> **Date**: 2026-10-11

---

## Current State

pyroduct has 29 architecture artifacts (diagrams, evidence docs, summaries) that were created this session. They are **substantively correct** — all numerical claims, flow logic, and version pins match the code after two fixes we applied during the health check.

But two drift failures already happened before the health check caught them:

1. **Dependency edge error**: `module-dependencies.dot` and `dependency-map.dot` drew `cmd_jsoncli -> viz`, but `cmd/jsoncli/moon.pkg` does not import `viz`. This was a factual error that no existing check caught.

2. **Test count drift**: `plugin/server.mjs` (2 places) and `plugin/skills/pyroduct-model/SKILL.md` (1 place) say "190 tests" but the actual count is 197. This is the same drift shape as the previously-fixed "28 faces → 31 faces" error (commit 7b95863) — the face count was fixed but the test count was missed.

Both were caught by the architecture health check, not by any standing CI mechanism. Without that check, they would have shipped.

---

## Target State

Every architecture artifact that makes a verifiable claim about the code is checked by CI on every push. Drift is a build failure, not a discovery.

Specifically:
- **Module dependency edges** in DOT files match actual `moon.pkg` imports
- **Test count** in plugin descriptions matches actual test function count
- **Architecture files** are version-controlled and reviewable in PRs
- **Living architecture contract** documents what's enforced and how to extend it

---

## Key Decisions

### What to check: Both dependency edges and numerical claims

We chose to check both because each catches a different failure mode that already happened. Checking only one would leave the other gap open.

Full auto-regeneration of DOT files was rejected because the diagrams carry human-curated semantic information (layer clusters, concern colors, contextual labels) that auto-generation cannot reproduce. Drift detection is sufficient; auto-generation is overkill.

### Where to run: CI only (initially)

Local-only validation was already proven insufficient — the 190→197 drift happened despite `validate-plugin.mjs` existing as a local script. CI enforcement makes drift impossible to merge, not just possible to miss.

Pre-commit hooks can be added later for faster feedback, but CI-first gives enforcement immediately with zero developer overhead.

### How to extract facts: Parse files, don't run tools

Parsing `moon.pkg` import blocks and counting `test "..."` in `*_test.mbt` files is fast (<2 seconds total) and doesn't require the moon toolchain. CI already runs `moon test` separately; we don't need a second full test run just to count tests.

---

## Migration Slices

### Slice 1: Dependency Edge Validator (~1 hour)

Create `tools/validate_dependencies.py` that:
- Discovers all `moon.pkg` files
- Parses import blocks
- Compares against DOT file edges
- Reports false edges (in DOT, not in code) and missing edges (in code, not in DOT)

**Validation**: Reintroduce the `cmd_jsoncli -> viz` error, confirm detection, revert.

### Slice 2: Test Count Anti-Drift (~30 minutes)

Extend `plugin/tools/validate-plugin.mjs` to:
- Count test functions in `*_test.mbt` files
- Subtract native-only tests
- Compare against test count in `pyroduct_gates` description

Fix the three stale "190" references to "197".

**Validation**: Change a description back to "190", confirm detection, revert.

### Slice 3: CI Integration (~15 minutes)

Add two steps to `gate.yml`:
```yaml
- name: Architecture dependency edges must match code
  run: python tools/validate_dependencies.py
- name: Plugin validation (anti-drift)
  run: node plugin/tools/validate-plugin.mjs
```

**Validation**: Push to test branch with deliberate drift, confirm CI red.

### Slice 4: Contract + Commit (~30 minutes)

Write `LIVING_ARCHITECTURE.md` declaring:
- Which invariants are CI-enforced
- What each validator checks
- How to add new invariants
- Confidence level of each artifact

Commit `architecture/`, `tools/validate_dependencies.py`, `LIVING_ARCHITECTURE.md`, and updated `gate.yml`.

Update `AGENTS.md` with new commands and a "Living Architecture" section.

---

## Risks

| Risk | Mitigation |
|------|------------|
| False positives block CI | Each slice includes deliberate-error testing before CI integration |
| Validator itself has bugs | Simple enough to review in PRs; no external dependencies |
| New developers don't know about validators | LIVING_ARCHITECTURE.md + AGENTS.md document them |
| Validators become stale | They're checked by the same CI they enforce |

All slices are fully reversible (delete script, remove CI step, git rm files).

---

## What This Does NOT Do

- **Auto-regenerate diagrams**: The DOT files carry semantic annotations that need human judgment. We detect drift; we don't auto-fix it.
- **Check every numerical claim**: State counts, transition counts, etc. are less likely to drift silently because they're embedded in tested code. We focus on the two failure modes that already happened.
- **Replace code review**: Architecture changes still need human review. The validators catch accidental drift, not intentional changes.

---

## Success Criteria

After all 4 slices:

1. `python tools/validate_dependencies.py` exits 0 on clean code, 1 on drift
2. `node plugin/tools/validate-plugin.mjs` checks test count (currently 197)
3. `gate.yml` runs both validators; CI fails on drift
4. `architecture/` is tracked in git (30+ files)
5. `LIVING_ARCHITECTURE.md` documents the contract
6. Total validation time < 15 seconds

---

## Artifacts

| File | Purpose |
|------|---------|
| `architecture/architecture-evolution.dot` | Current vs target state diagram |
| `architecture/decision-map.md` | 6 decisions with options, rationale, constraints |
| `architecture/migration-roadmap.md` | 4 slices with steps, acceptance criteria, validation signals |
| `architecture/evolution-summary.md` | This file — narrative summary |

---

## Next Action

Start with **Slice 1**: Create `tools/validate_dependencies.py`. It's the most impactful slice because it catches the exact failure mode (wrong dependency edge) that the health check just found and fixed. Once it exists and passes, add it to CI (Slice 3), and that failure mode can never recur.

---

**Generated**: 2026-10-11
**Status**: Proposed — awaiting approval to implement
**Estimated total effort**: ~2 hours
**First deliverable**: `tools/validate_dependencies.py` (Slice 1, ~1 hour)
