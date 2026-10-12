# Evolution Summary — Model Fact Registry

> **Why**: 20+ numerical claims (34 states, 53 transitions, 11 phases, etc.) are scattered
> as hardcoded strings across 5+ files. The first evolution protected dependency edges and
> plugin test counts, but model facts can still drift silently.
> **What**: Extract model facts from source code once, cross-check every consumer.
> **How**: Four migration slices, each independently valuable.
> **Date**: 2026-10-11
> **Status**: Proposed

---

## Current State

The first evolution (living architecture automation) added two CI validators:
1. `tools/validate_dependencies.py` — dependency edges in DOT files match `moon.pkg` imports
2. `plugin/tools/validate-plugin.mjs` — 28 plugin consistency checks including test count

These protect **structural** claims (who imports whom) and **interface** claims (face count,
test count in tool descriptions). But a third category — **model facts** — remains
unprotected:

| Fact | Source of truth | Hardcoded in |
|------|----------------|--------------|
| Subject: 34 states, 53 transitions, 11 phases | `src/subject.mbt` enums + `transitions()` | server.mjs (3 places), README.en (5+), README.zh (5+), DOT labels |
| Group: 20 states, 44 transitions, 9 phases | `group/machine.mbt` | server.mjs, README.en, README.zh |
| Society: 13 states, 28 transitions, 8 phases | `society/state.mbt` | server.mjs, README.en, README.zh |
| 49 triggers, 8 slots | `src/subject.mbt` | server.mjs, README.en, README.zh |
| 272 combinations, 228 no-way | derived (34×8, counted) | server.mjs, README.en, README.zh |
| 14 normative rules | `multi/` | README.en, README.zh |
| 22 group triggers, 18 society triggers | enums | README.en, README.zh |

The plugin's `validate-plugin.mjs` already checks that the `report` face **output** contains
"34 位置 . 53 迁移 . 11 阶段" — but it checks against a hardcoded expected string, not
against the actual enum count. If the enum changes AND the report output changes together,
the check passes. But the README files and server.mjs inline descriptions would still be
stale.

**The drift shape**: Same as the "190 tests" incident. Someone adds a state to
`SubjectState`, updates the report renderer (which auto-generates from the enum), but
forgets to update the 8+ hardcoded strings scattered across descriptions and documentation.

---

## Target State

A single script (`tools/extract_model_facts.py`) extracts all model facts from source code.
Two consumers cross-check against it:

1. **`tools/validate_model_facts.py`** — checks README files (English + Chinese) against
   extracted facts. Reports every stale number with file, line, expected, actual.

2. **Extended `validate-plugin.mjs`** — checks server.mjs inline description strings
   against the same facts. The existing content checks verify face *output*; the new checks
   verify face *descriptions*.

Architecture diagrams carry a version pin in their header comment. A new CI step verifies
the pin matches `moon.mod`.

All three validators run in CI on every push.

---

## Key Decisions

### D1: Extract by parsing, not by running

**Options considered**:
- (A) Run `moon test` and parse output for counts → slow, requires toolchain
- (B) Parse source files with regex → fast, stdlib-only, sufficient
- (C) Add a `moon run` subcommand that dumps facts as JSON → elegant but adds a new face

**Chosen**: (B). Same rationale as the first evolution: parsing is fast (<2s), needs no
toolchain, and the facts are structurally simple (enum variants, transition table rows).

### D2: Two validators, not one mega-validator

**Options considered**:
- (A) One Python script checks everything → simpler but mixes concerns
- (B) Python checks READMEs, Node checks plugin → matches existing split
- (C) Move everything to Node → Python is better for text parsing

**Chosen**: (B). The Python/Node split mirrors the existing architecture: Python handles
code-level checks (dependencies, model facts in docs), Node handles plugin-level checks
(face rendering, description strings, MCP handshake). Each validator is already in CI;
extending them is cheaper than creating a third.

### D3: README checking is worth the effort

**Pushback**: README files are documentation; they're allowed to be slightly stale.

**Rebuttal**: The README is the first thing a visitor reads. "34 positions · 53
transitions" on line 12 of README.mbt.md is a factual claim about the module. If it says
34 but the code has 35, the README is lying — not approximately right, but lying. The
health check already verified all 8 numerical claims are correct *today*; the question is
whether they'll stay correct after the next model change.

### D4: Version pinning for architecture diagrams

Each DOT file gets a header comment: `// model-version: 0.1.29`. A validator checks that
all DOT files in `architecture/` carry the current `moon.mod` version. When the module
version bumps, diagrams without the new pin are flagged for review.

This doesn't auto-regenerate diagrams — it ensures a human reviews them before release.

---

## Migration Slices

### Slice 1: Model Fact Extractor (~45 min)

Create `tools/extract_model_facts.py`:
- Parse `src/subject.mbt` for `SubjectState` enum (34), `Phase` enum (11), `Trigger` enum
  (49), `transitions()` function rows (53)
- Parse `group/machine.mbt` for `GroupState` (20), `GroupPhase` (9), `GroupTrigger` (22),
  transitions (44)
- Parse `society/state.mbt` for `State` (13), `Phase` (8), `Trigger` (18), transitions (28)
- Compute derived facts: 34×8=272 combinations
- Output JSON to stdout:
  ```json
  {
    "subject": {"states": 34, "transitions": 53, "phases": 11, "triggers": 49, "slots": 8},
    "group": {"states": 20, "transitions": 44, "phases": 9, "triggers": 22},
    "society": {"states": 13, "transitions": 28, "phases": 8, "triggers": 18},
    "combinations": {"total": 272, "no_way": 228}
  }
  ```

**Validation**: Run it, confirm output matches known facts. Add a state to a test enum,
confirm count changes.

### Slice 2: README Cross-Checker (~30 min)

Create `tools/validate_readme_facts.py`:
- Run `extract_model_facts.py` to get ground truth
- Parse `README.mbt.md` and `README.zh.mbt.md` for numerical claims
- Compare each claim against extracted facts
- Report stale numbers with file, line number, expected, actual

**Validation**: Change "34" to "35" in a README, confirm detection, revert.

### Slice 3: Plugin Description Cross-Checker (~30 min)

Extend `plugin/tools/validate-plugin.mjs`:
- For each face description string that contains model facts (report, slots, loop, group,
  society, fleet, algebra, petri), extract the numbers
- Compare against the same facts (hardcode the expected values, matching the extractor)
- Report stale numbers in description strings

Alternatively, have the Node script shell out to `python tools/extract_model_facts.py` and
read its JSON output. This avoids duplicating the extraction logic.

**Validation**: Change "34 位置" to "35 位置" in a server.mjs description, confirm
detection, revert.

### Slice 4: Version Pinning + CI Integration (~20 min)

1. Add `// model-version: 0.1.29` header to all 15 DOT files in `architecture/`
2. Extend `tools/validate_dependencies.py` (or create a new script) to verify all DOT files
   carry the current `moon.mod` version
3. Add both new validators to `gate.yml` and `publish.yml`
4. Update `LIVING_ARCHITECTURE.md` with the new invariants

**Validation**: Bump `moon.mod` version without updating DOT pins, confirm CI red.

---

## Slice Dependencies

```
Slice 1 (extract_model_facts.py)
    ↓               ↓
Slice 2            Slice 3
(README check)     (plugin desc check)
    ↓               ↓
       Slice 4 (CI + version pinning)
```

Slice 2 and Slice 3 are independent. Slice 4 depends on both.

---

## Risks

| Risk | Mitigation |
|------|------------|
| Regex parsing misses edge cases | Enum definitions are highly regular; test against all 3 machine files |
| README uses both "34" and "**34**" (markdown bold) | Parser strips markdown formatting before matching |
| Node script can't call Python in CI | CI runners have both; alternatively, hardcode facts in Node (same numbers, two extraction paths) |
| Version pinning is noisy on every version bump | That's the point — diagrams should be reviewed on version bump |
| Derived facts (272, 228) need manual update | 272 = 34×8 is trivially computable; 228 needs counting from step() output — add to extractor as a known constant |

---

## What This Does NOT Do

- **Auto-update READMEs**: Detects drift, doesn't fix it. Human judgment is needed to
  decide whether a model change also changes the README's narrative.
- **Check architecture diagram labels**: DOT files contain counts in node labels (e.g.,
  "src\n34 states"). Version pinning flags the file for review but doesn't parse every
  label. Full label checking would require a DOT parser — overkill for now.
- **Replace the health check**: The health check is broader (versions, flows, deployment).
  This evolution automates the numerical subset that can be mechanically extracted.

---

## Success Criteria

After all 4 slices:

1. `python tools/extract_model_facts.py` outputs JSON with all 15+ model facts
2. `python tools/validate_readme_facts.py` exits 0 on clean code, 1 on stale README
3. `node plugin/tools/validate-plugin.mjs` checks inline description numbers
4. All DOT files carry `// model-version:` matching `moon.mod`
5. CI runs all three validators; drift is a build failure
6. Total validation time < 20 seconds

---

## Artifacts

| File | Purpose |
|------|---------|
| `architecture/architecture-evolution-v2.dot` | Current vs target state for this evolution |
| `architecture/decision-map-v2.md` | Design decisions (this file's D1-D4) |
| `architecture/migration-roadmap-v2.md` | 4-slice plan with acceptance criteria |
| `architecture/evolution-summary-v2.md` | This file |

---

## Relationship to First Evolution

| | First Evolution | Second Evolution |
|---|---|---|
| **Protects** | Structure (imports) + interface (faces, tests) | Model facts (states, transitions, phases) |
| **Validators** | validate_dependencies.py + validate-plugin.mjs (extended) | + validate_readme_facts.py + extract_model_facts.py |
| **CI steps** | 2 new steps in gate.yml | +2 new steps (README check, version pin) |
| **Drift shape caught** | Wrong edge, stale test count | Stale state/transition count in docs |
| **Total CI time** | <15s | <20s |

---

**Next action**: Start with Slice 1 — create `tools/extract_model_facts.py`. It's the
foundation that Slices 2 and 3 depend on.
