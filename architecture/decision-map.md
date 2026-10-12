# Decision Map — Living Architecture Automation

> **Date**: 2026-10-11
> **Decision**: How to prevent architecture artifacts from drifting away from code

---

## Decision 1: What to check — dependency edges vs numerical claims vs both

### Context

Architecture artifacts can drift in multiple dimensions:
- **Dependency edges**: A `moon.pkg` import changes but the DOT diagram isn't updated
- **Numerical claims**: Test count changes (190→197) but plugin descriptions aren't updated
- **Structural claims**: State count changes but architecture docs aren't updated

### Options

| Option | Scope | Cost | Coverage |
|--------|-------|------|----------|
| A: Dependency edges only | Extract from `moon.pkg`, compare against DOT | Low | Catches import drift |
| B: Numerical claims only | Count states/tests/faces, compare against docs | Low | Catches count drift |
| C: Both | Full extraction + comparison | Medium | Catches all structural drift |
| D: Full regeneration | Auto-generate DOT from `moon.pkg` | High | No drift possible |

### Chosen: **C (Both)**

**Rationale**:
- Option A misses the test-count drift that already happened (190→197)
- Option B misses dependency edge errors (cmd_jsoncli→viz that we just fixed)
- Option D is overkill: DOT files carry semantic annotations (colors, clusters, labels) that auto-generation would lose
- Option C catches both known failure modes at moderate cost

**Rejected**: D (full regeneration) — the architecture diagrams carry human-curated semantic information (clusters by layer, colors by concern, labels with context) that auto-generation cannot reproduce. The goal is drift detection, not auto-generation.

---

## Decision 2: Where to run checks — local script vs CI vs both

### Context

Drift can be caught at different points:
- **Local**: Developer runs validation before committing
- **CI**: Gate rejects push if drift detected
- **Both**: Local feedback + CI enforcement

### Options

| Option | Feedback loop | Enforcement | Overhead |
|--------|---------------|-------------|----------|
| A: Local only | Fast (pre-commit) | None (can be skipped) | Low |
| B: CI only | Slow (post-push) | Strong (blocks merge) | Low |
| C: Both | Fast + strong | Strong | Medium |

### Chosen: **B (CI only, initially)**

**Rationale**:
- Local scripts require every developer to remember to run them — exactly the failure mode that produced the 190→197 drift
- CI enforcement makes drift impossible to merge, not just possible to miss
- `validate-plugin.mjs` already exists as a local script; adding it to CI is one line
- A future "both" phase can add a pre-commit hook, but CI-first gives enforcement immediately

**Rejected**: A (local only) — already proven insufficient. C (both) is a natural follow-up but not needed for initial value.

---

## Decision 3: How to extract test count — run `moon test` vs parse test files

### Context

The test count can be obtained by:
- Running `moon test` and parsing output (authoritative but slow)
- Counting `test "..."` definitions in `*_test.mbt` files (fast but might miss dynamic tests)

### Options

| Option | Speed | Accuracy | Dependencies |
|--------|-------|----------|--------------|
| A: Run `moon test` | Slow (~30s) | 100% accurate | Needs moon toolchain |
| B: Parse test files | Fast (<1s) | 99% accurate (misses `async test` edge cases) | Needs only file access |
| C: Hardcode current value | Instant | Stale by definition | None |

### Chosen: **B (Parse test files)**

**Rationale**:
- CI already runs `moon test` separately; adding a second full test run just for the count is wasteful
- Parsing `test "..."` and `async test "..."` in `*_test.mbt` files gives the same count (verified: 203 total, 6 native-only, 197 wasm)
- The 1% accuracy gap is acceptable because `moon test` in the same CI run is the real oracle — this check is for the *description*, not the actual count
- Option C is exactly the drift we're trying to prevent

**Implementation**: `grep -c '^\s*\(async \)\?test "' **/*_test.mbt` then subtract native-only package tests.

---

## Decision 4: How to extract dependency edges — parse moon.pkg vs query moon

### Context

Module dependencies can be extracted by:
- Parsing `moon.pkg` import blocks (fast, no toolchain needed)
- Running `moon info` or similar query (authoritative but heavier)

### Options

| Option | Speed | Accuracy | Dependencies |
|--------|-------|----------|--------------|
| A: Parse moon.pkg | Fast (<1s) | 100% for imports | Python/Node script |
| B: Query moon | Slow (~5s) | 100% including transitive | Needs moon toolchain |

### Chosen: **A (Parse moon.pkg)**

**Rationale**:
- The architecture diagrams only show direct imports (first-party + external), not transitive dependencies
- Parsing `import { ... }` blocks from `moon.pkg` files is trivial and deterministic
- CI already has moon installed, so option B is feasible, but option A is faster and equally correct for this purpose

---

## Decision 5: What to do about architecture/ being untracked

### Context

All 29 architecture files are currently untracked (`?? architecture/`). This means:
- They can be lost if the working tree is wiped
- They can't be reviewed in PRs
- CI can't check them

### Options

| Option | Risk | Effort |
|--------|------|--------|
| A: Commit as-is | Low (after fixing known issues) | `git add architecture/` |
| B: Add to .gitignore | None (give up on versioning) | One line |
| C: Move to separate repo | Medium (sync overhead) | New repo + sync script |

### Chosen: **A (Commit)**

**Rationale**:
- These files are the architecture model; not tracking them is the same as not having them
- Known issues (wrong edge, stale test count) have been fixed or documented
- A separate repo adds sync overhead with no benefit — the diagrams are about *this* codebase
- .gitignore would be admitting defeat

---

## Decision 6: Scope of validate-architecture.py — what facts to extract

### Context

The script needs to extract facts from code and compare against architecture artifacts. What facts?

### Chosen facts (Slice 1)

| Fact | Source | Checked against | Priority |
|------|--------|-----------------|----------|
| Module dependency edges | `*/moon.pkg` import blocks | `module-dependencies.dot`, `dependency-map.dot` | High |
| Package count | `find . -name moon.pkg` | Architecture docs | Medium |
| `+native` package list | `supported_targets = "+native"` in moon.pkg | `gate.yml` native block | High |

### Deferred facts (future slices)

| Fact | Source | Checked against | Priority |
|------|--------|-----------------|----------|
| State/transition/phase counts | `src/subject.mbt` | Architecture docs, README | Medium |
| Face count | `cmd/jsoncli/main.mbt faces()` | `plugin/server.mjs FACES` | Already done by validate-plugin.mjs |
| Test count | `*_test.mbt` files | Plugin descriptions | Slice 2 |

**Rationale**: Start with the two failure modes that already happened (dependency edge error, test count drift). Numerical claims about the state machine are less likely to drift silently because they're embedded in code that's exercised by tests.

---

## Constraints

1. **No new dependencies**: Validation scripts must use Python stdlib or Node stdlib only (matching the project's dependency discipline)
2. **Deterministic**: Checks must produce the same result on every run (no timestamps, no random seeds)
3. **Fast**: Total validation time < 5 seconds (excluding `moon test` which CI runs separately)
4. **Actionable error messages**: Each failure must name the file, line, and expected vs actual value
5. **Non-blocking for architecture/ creation**: The CI check should warn on first run (since files are being committed for the first time), not block

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| False positives from DOT format variations | Medium | Low (annoying) | Parse edges semantically, not textually |
| New moon.pkg added but not to check script | Low | Medium (silent gap) | Check script discovers all moon.pkg files automatically |
| validate-plugin.mjs breaks on Node version | Low | Medium (CI red) | Pin Node version in CI (already ubuntu-latest default) |
| Architecture files become stale despite CI | Medium | Low (CI catches it) | That's the whole point of the check |

---

## Reversibility

All four slices are fully reversible:
- Slice 1 (validate-architecture.py): Delete the script, remove from CI
- Slice 2 (test count check): Remove from validate-plugin.mjs
- Slice 3 (CI integration): Remove steps from gate.yml
- Slice 4 (LIVING_ARCHITECTURE.md + commit): Delete file, git rm architecture/

No slice creates irreversible state or external dependencies.

---

**Generated**: 2026-10-11
**Status**: Proposed — awaiting implementation
