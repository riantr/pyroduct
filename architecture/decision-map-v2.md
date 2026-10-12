# Decision Map — Model Fact Registry Evolution

> **Date**: 2026-10-11
> **Context**: Second evolution plan for pyroduct living architecture

---

## Decision D1: Fact Extraction Method

### Options

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A: Run moon test** | Execute `moon test` and parse output for counts | Uses authoritative runtime output | Slow (full test run), requires toolchain, overkill |
| **B: Parse source files** | Regex-extract enum variants and transition rows from `.mbt` files | Fast (<2s), stdlib-only, no toolchain needed | Assumes regular formatting; could miss edge cases |
| **C: Add JSON dump face** | Create a new `moon run cmd/main -- facts-json` subcommand | Elegant, single source of truth, reusable | Adds a new face (scope creep), requires build |

### Decision

**Chosen: B (Parse source files)**

### Rationale

- **Consistency with first evolution**: `validate_dependencies.py` and the test count check in `validate-plugin.mjs` both parse files rather than running tools. This keeps the validation approach uniform.
- **Speed**: Parsing 3 source files takes <2 seconds. Running `moon test` takes 30+ seconds and is already done separately in CI.
- **Simplicity**: Enum definitions in MoonBit are highly regular:
  ```moonbit
  pub enum SubjectState {
    NoPast | NoFuture | Standing | ...  // one variant per line
  }
  ```
  A regex like `^\s+(\w+)\s*(?:\(|\||,|$)` reliably counts variants.
- **No new surface area**: Option C adds a new CLI subcommand and JSON renderer. That's a feature, not a validator. Validators should be minimal and focused.

### Constraints

- Enum definitions must remain one-variant-per-line (current convention).
- Transition tables must remain one-row-per-line in `transitions()` functions (current convention).
- If these conventions change, the extractor must be updated.

### Reversibility

**High**: Switching to option C later (adding a JSON dump face) is additive. The parser can be replaced without affecting consumers.

---

## Decision D2: Validator Architecture

### Options

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A: One mega-validator** | Single Python script checks READMEs + plugin descriptions | Simpler invocation, one codebase | Mixes Python (good at text parsing) with Node (good at JSON/MCP) |
| **B: Split by domain** | Python checks READMEs, Node checks plugin | Matches existing split, each validator uses best tool | Two scripts instead of one |
| **C: All Node** | Move README checking into validate-plugin.mjs | One language, one invocation | Node is worse at regex-heavy text parsing than Python |

### Decision

**Chosen: B (Split by domain)**

### Rationale

- **Existing architecture**: The project already has two validators:
  - `tools/validate_dependencies.py` (Python) — checks code-level facts (imports)
  - `plugin/tools/validate-plugin.mjs` (Node) — checks plugin-level facts (faces, versions, test count)
  
  Extending this split is cheaper than consolidating.
  
- **Tool strengths**:
  - Python excels at regex-heavy text parsing (README markdown files)
  - Node excels at JSON manipulation and MCP protocol (plugin descriptions)
  
- **CI integration**: Both validators are already in `gate.yml`. Adding a new Python script and extending the Node script is two small changes, not one large refactor.

### Constraints

- Both validators must be fast enough to run in CI (<10s each).
- Both must use stdlib only (no pip/npm dependencies).

### Reversibility

**High**: Consolidating into one validator later is a refactor, not a redesign. The extraction logic (Slice 1) is independent of the consumer (Slice 2/3).

---

## Decision D3: README Checking Scope

### Options

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A: Skip READMEs** | Only check code and plugin, not docs | Less work, docs are allowed to drift | README is the first thing visitors see; stale numbers are lies |
| **B: Check READMEs** | Cross-check all numerical claims in README.mbt.md and README.zh.mbt.md | Catches drift in the most-visible artifacts | More validation logic, potential for false positives |
| **C: Check only summary lines** | Check line 12 of each README (the "34 states · 53 transitions · 11 phases" line) | Minimal scope, catches the most important drift | Misses drift in section headings and tables |

### Decision

**Chosen: B (Check READMEs)**

### Rationale

- **The README is a factual claim**: Line 12 of README.mbt.md says "One subject: **34** positions . **53** transitions . **11** phases." This is not opinion or summary — it's a verifiable fact about the module. If it's wrong, the README is lying.
- **The drift shape already happened**: The "190 tests" incident was in plugin descriptions, which are also documentation. The same drift can happen in READMEs.
- **Visitors read the README first**: Before running `moon test` or reading source code, a visitor reads the README. If it says 34 but the code has 35, the visitor's mental model is wrong from the start.
- **Mechanical checking is feasible**: The numbers are formatted consistently (markdown bold `**34**`, or plain `34`). A regex can extract them.

### Scope

Check all numerical claims that can be extracted from source code:
- Subject: states, transitions, phases, triggers, slots
- Group: states, transitions, phases, triggers
- Society: states, transitions, phases, triggers
- Derived: 272 combinations (34×8)

Do NOT check:
- Prose descriptions (subjective)
- Phase names (too many, low drift risk)
- State names (too many, low drift risk)

### Reversibility

**High**: If README checking proves too noisy, it can be disabled by removing the CI step. The validator script can remain for manual use.

---

## Decision D4: Architecture Diagram Version Pinning

### Options

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A: No versioning** | Diagrams are timeless; health check reviews them | Zero overhead | No signal when a diagram is stale |
| **B: Version pin in header** | Each DOT file carries `// model-version: 0.1.29`; validator checks pins match `moon.mod` | Low-tech, visible, enforceable | Manual update on version bump |
| **C: Auto-regenerate on version bump** | CI regenerates all DOT files when `moon.mod` version changes | Zero manual work | Loses semantic annotations (clusters, colors, labels) |

### Decision

**Chosen: B (Version pin in header)**

### Rationale

- **Diagrams carry human judgment**: The DOT files have semantic annotations (cluster labels, concern colors, contextual notes) that auto-generation cannot reproduce. Option C would destroy this information.
- **Version bump = review signal**: When `moon.mod` version changes, it means the model changed. Diagrams should be reviewed at that point, not auto-regenerated. The pin forces a human to look at the diagram and decide whether it needs updating.
- **Low-tech and visible**: A comment at the top of each DOT file is visible in any text editor or code review. No special tooling needed to see the version.
- **Enforceable**: A validator can check that all pins match `moon.mod`. Drift is a CI failure.

### Implementation

Add to each DOT file:
```dot
// model-version: 0.1.29
digraph G {
  ...
}
```

Validator (`tools/validate_dependencies.py` extended, or new script):
- Read `moon.mod` version
- For each `.dot` file in `architecture/`, extract `// model-version: X.Y.Z`
- Report files where pin ≠ `moon.mod` version

### Workflow on Version Bump

1. Developer bumps `moon.mod` version (e.g., 0.1.29 → 0.1.30)
2. CI runs, version pin validator fails: "15 DOT files have pin 0.1.29, expected 0.1.30"
3. Developer reviews each diagram, updates if needed, bumps pin to 0.1.30
4. CI passes

This ensures diagrams are reviewed on every model change, not just when someone remembers.

### Reversibility

**High**: Pins are comments. Removing them is a no-op. Switching to option C later is possible if a smart regeneration tool is built.

---

## Decision D5: Derived Facts (272, 228)

### Problem

Two facts are not directly extractable from enums:
- **272** = 34 states × 8 slots (computable)
- **228** = number of (state, slot) pairs where `step()` returns `NoWay` (not trivially computable)

### Options

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A: Hardcode 228** | Treat it as a known constant, update manually when it changes | Simple, fast | Manual update |
| **B: Compute 228** | Run a `moon run` command that counts NoWay outcomes | Authoritative | Requires toolchain, slow |
| **C: Skip 228** | Only check 272 (computable), skip 228 | Less work | Misses drift in one fact |

### Decision

**Chosen: A (Hardcode 228)**

### Rationale

- **272 is trivially computable**: 34 × 8 = 272. The extractor can compute this from the extracted state and slot counts.
- **228 requires execution**: Counting NoWay outcomes requires running `step()` for all 272 pairs. That's a runtime check, not a static parse.
- **228 changes rarely**: The NoWay count only changes when the step function's behavior changes (new transitions, new slots). This is a model-level change, not a frequent occurrence.
- **Hardcode with a comment**: The extractor can hardcode 228 with a comment explaining what it represents. If it drifts, the health check will catch it (the health check already verified 228 is correct today).

### Implementation

```python
# tools/extract_model_facts.py
facts = {
    "subject": {"states": 34, "slots": 8, ...},
    "combinations": {
        "total": 34 * 8,  # 272, computed
        "no_way": 228      # hardcoded, from src/loop.mbt step() output
    }
}
```

If 228 changes, the developer updates the hardcoded value. The README checker will catch drift if the README is updated but the extractor is not (or vice versa).

### Reversibility

**High**: Switching to option B later (computing 228 at runtime) is a performance tradeoff, not a redesign.

---

## Decision D6: CI Integration Strategy

### Options

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A: Add to existing steps** | Extend `validate_dependencies.py` and `validate-plugin.mjs` | Fewer CI steps, reuses existing infrastructure | Validators grow in scope |
| **B: New CI steps** | Add 2 new steps to `gate.yml`: one for README check, one for version pin | Clear separation of concerns | More CI steps |
| **C: Single new step** | Add one step that runs all validators | One step, clear | Loses granularity (which validator failed?) |

### Decision

**Chosen: A (Add to existing steps)**

### Rationale

- **Existing infrastructure**: `gate.yml` already runs:
  ```yaml
  - name: architecture · dependency edges must match code
    run: python tools/validate_dependencies.py
  - name: plugin · anti-drift (faces, versions, test count, invariants)
    run: node plugin/tools/validate-plugin.mjs
  ```
  
- **Natural extension**:
  - README checking is Python → extend `validate_dependencies.py` (or create a sibling `validate_readme_facts.py` and call it from the same CI step)
  - Plugin description checking is Node → extend `validate-plugin.mjs`
  - Version pinning is Python → extend `validate_dependencies.py` (it already parses DOT files)

- **CI step count**: Keeping the step count at 2 (Python validator + Node validator) is cleaner than adding 2 more steps. Each step's name describes its domain ("architecture" and "plugin"), not its individual checks.

### Implementation

Update `gate.yml`:
```yaml
- name: architecture · dependency edges + model facts + version pins
  run: |
    python tools/validate_dependencies.py
    python tools/validate_readme_facts.py
    python tools/validate_version_pins.py

- name: plugin · anti-drift (faces, versions, test count, descriptions, invariants)
  run: node plugin/tools/validate-plugin.mjs
```

The step names are updated to reflect the expanded scope.

### Reversibility

**High**: CI steps can be split or merged without affecting the validators themselves.

---

## Summary of Decisions

| ID | Decision | Chosen | Rationale |
|----|----------|--------|-----------|
| D1 | Fact extraction method | Parse source files (B) | Fast, stdlib, consistent with first evolution |
| D2 | Validator architecture | Split by domain (B) | Matches existing Python/Node split |
| D3 | README checking scope | Check all numerical claims (B) | README is a factual claim, visitors read it first |
| D4 | Diagram version pinning | Version pin in header (B) | Forces review on version bump, preserves annotations |
| D5 | Derived facts (272, 228) | Hardcode 228 (A) | 228 requires execution, changes rarely |
| D6 | CI integration | Extend existing steps (A) | Fewer steps, natural domain split |

---

## Constraints

- All validators must run in <10s each (CI performance).
- All validators must use stdlib only (no pip/npm dependencies).
- All validators must produce actionable error messages (name the file, line, expected, actual).
- All validators must exit 0 on success, 1 on failure (CI convention).

---

## Risks

| Risk | Mitigation |
|------|------------|
| Regex parsing misses edge cases | Test against all 3 machine files; enum definitions are highly regular |
| README uses markdown formatting (`**34**`) | Parser strips markdown before matching |
| Node script can't call Python | Hardcode facts in Node (same numbers, two extraction paths) |
| Version pinning is noisy | That's the point — diagrams should be reviewed on version bump |
| Derived fact 228 needs manual update | Hardcode with comment; health check catches drift |

---

**Generated**: 2026-10-11
**Status**: Proposed — awaiting implementation
**Next action**: Start with Slice 1 (extract_model_facts.py)
