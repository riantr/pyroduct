# Living Architecture — Invariants & Enforcement

> This file declares which architecture invariants are enforced by CI, what each
> validator checks, and how to extend the system. It is the contract between the
> architecture artifacts and the code they describe.

---

## Enforced Invariants

### 1. Module Dependency Edges + Version Pins

**Validator**: `python tools/validate_dependencies.py`
**CI**: `gate.yml` step "architecture · dependency edges + version pins must match code"
**What it checks**:
- Every first-party import in `*/moon.pkg` has a matching edge in `architecture/module-dependencies.dot` and `architecture/dependency-map.dot`
- Every edge in those DOT files corresponds to a real import in code
- Reports both **false edges** (in diagram, not in code) and **missing edges** (in code, not in diagram)
- Every DOT file in `architecture/` carries a `// model-version: X.Y.Z` header matching the current `moon.mod` version

**Scope**:
- All `riantr/pyroduct/*` imports
- Excludes external dependencies (`moonbitlang/*`, `riantr/moonbit_doubleML`, etc.)
- Excludes `examples/*` and `tools/*` (intentionally absent from architecture diagrams)
- All 17 DOT files in `architecture/`

**When it fires**:
- Adding/removing an import in any `moon.pkg` without updating the DOT files
- Editing a DOT file to add/remove an edge that doesn't match code
- Bumping `moon.mod` version without updating DOT file version pins
- Adding a new DOT file without a version pin header

**How to fix a failure**:
- If code changed: update the DOT files to match
- If DOT changed: revert the DOT edit or update the code to match
- If version bumped: update all DOT file headers to match the new version

---

### 2. README Model Facts

**Validator**: `python tools/validate_readme_facts.py`
**CI**: `gate.yml` step "architecture · README model facts must match code"
**What it checks**:
- Numerical claims in `README.mbt.md` and `README.zh.mbt.md` match source code
- Checks: subject/group/society states, transitions, phases, triggers, slots
- Checks: combinations (272 total, 228 no-way)
- Extracts ground truth from source code via `tools/extract_model_facts.py`

**Scope**:
- Both README files (English and Chinese)
- All numerical claims about the three state machines

**When it fires**:
- Adding/removing a state, transition, phase, or trigger without updating READMEs
- Changing model facts in code but not in documentation

**How to fix a failure**:
- Update the README files to match the source code
- Or revert the source code change if the README was correct

---

### 3. Plugin Description Consistency

**Validator**: `node plugin/tools/validate-plugin.mjs`
**CI**: `gate.yml` step "plugin · anti-drift (faces, versions, test count, model facts, invariants)"
**What it checks** (the harness prints its own count — one check is skipped when it cannot see a MoonBit module, which is not the same as that check passing):

| Check | What it catches |
|-------|-----------------|
| Pin SHA-256 + bytes | `vendor/jsoncli.js` matches `vendor/BUILD.json` |
| Version consistency | `plugin.json` version = `server.mjs` SERVER_VERSION |
| MCP handshake | initialize, ping, tools/list work |
| Face count (FACES array) | All 31 faces in harness match catalog output |
| Face count (description) | `pyroduct_faces` description says "31 runnable views" |
| Face rendering | All 31 faces render non-empty, non-stub output |
| Content invariants | Report says "34 states · 53 transitions · 11 phases", audit says "未预期 0 条", etc. |
| Page citations | Exactly 4 faces print P.xx (group, intuition, multi, society) |
| Page citation anti-drift | Catalog doesn't claim page refs for faces without them |
| **Test count** | `pyroduct_gates` description says the real wasm test count (197) |
| **Model facts** | Face descriptions match actual state/transition/phase counts (8 checks) |
| Checkout guard | Gates hard-fail on bad path, face falls back to snapshot |

**When it fires**:
- Changing a number in a tool description without updating the code
- Adding/removing a face without updating the FACES array and description
- Changing the test count without updating the gates description
- Editing `vendor/jsoncli.js` without re-pinning
- Changing model facts (states, transitions, phases) without updating face descriptions

**How to fix a failure**:
- Read the check label — it names exactly what drifted
- Update the description/text to match the code, or vice versa
- Re-run `node plugin/tools/validate-plugin.mjs` locally to confirm

---

## Architecture Artifacts

All files in `architecture/` are version-controlled. They fall into three categories:

### System Model (Structurizr DSL)
- `system-context.dsl` — System context diagram (users, external systems)
- `system-model.dsl` — Container-level model (packages, plugins, registries)
- `system-model.evidence.md` — Evidence index for all nodes/edges
- `system-model.summary.md` — Architecture summary

### Dependency & Impact (Graphviz DOT)
- `module-dependencies.dot` — Module dependency graph (43 first-party edges)
- `dependency-map.dot` — Full dependency map with fan-in/fan-out metrics
- `impact-analysis-src.dot` — Change blast radius from modifying `src`
- `dependency-impact-findings.md` — Impact analysis findings
- `violations.csv` — Cycle/violation check results (currently clean)

### Flow Diagrams (Graphviz DOT + Evidence)
- `flow-subject-*.dot/.md` — Subject state machine execution flow (step function)
- `flow-evolution-*.dot/.md` — Evolution layer cycle flow (run_cycle)
- `flow-coordinator-*.dot/.md` — Coordinator runtime flow (runtime.step)
- `flow-cli-*.dot/.md` — CLI request routing (cmd/main, 36 subcommands)
- `flow-plugin-*.dot/.md` — Plugin bridge flow (MCP → jsoncli → model)

### Deployment Topology (Graphviz DOT)
- `deployment-topology.dot` — Full deployment topology (dev → CI → registry → plugin)
- `release-path.dot` — CI/CD release path (commit → gate → publish)
- `runtime-evidence.md` — Deployment evidence index
- `deployment-risks.md` — Deployment risks and gaps
- `deployment-topology.summary.md` — Deployment summary

### Health & Evolution
- `architecture-health-report.md` — Health check results (all claims verified)
- `architecture-evolution.dot` — Current vs target state for living architecture
- `decision-map.md` — Design decisions for living architecture automation
- `migration-roadmap.md` — 4-slice migration plan
- `evolution-summary.md` — Evolution narrative

---

## Confidence Levels

| Artifact | Confidence | Basis |
|----------|------------|-------|
| Module dependency edges | **HIGH** | CI-enforced by `validate_dependencies.py` |
| DOT file version pins | **HIGH** | CI-enforced by `validate_dependencies.py` |
| README model facts | **HIGH** | CI-enforced by `validate_readme_facts.py` |
| Face count & list | **HIGH** | CI-enforced by `validate-plugin.mjs` |
| Test count in descriptions | **HIGH** | CI-enforced by `validate-plugin.mjs` |
| Model facts in descriptions | **HIGH** | CI-enforced by `validate-plugin.mjs` |
| Version consistency | **HIGH** | CI-enforced by `validate-plugin.mjs` |
| State/transition/phase counts | **HIGH** | Verified by health check; embedded in tested code |
| Flow diagram logic | **HIGH** | Verified by health check against source code |
| Deployment topology | **MEDIUM** | Verified by health check; no CI enforcement (changes rarely) |

---

## How to Add a New Invariant

### If it's about the plugin:

1. Add a `check('label', condition, detail)` call to `plugin/tools/validate-plugin.mjs`
2. Test locally: `node plugin/tools/validate-plugin.mjs`
3. The CI step already runs this script — no gate.yml change needed

### If it's about architecture diagrams:

1. Extend `tools/validate_dependencies.py` to extract the new fact from code
2. Add comparison logic against the relevant DOT file(s)
3. Test locally: `python tools/validate_dependencies.py`
4. The CI step already runs this script — no gate.yml change needed

### If it's a new diagram or new file:

1. Create the file in `architecture/`
2. If it makes verifiable claims, add a check to an existing validator or create a new one
3. Update this file's "Architecture Artifacts" section
4. Commit both the artifact and the validator

---

## What This Does NOT Enforce

- **Auto-regeneration**: Diagrams are not auto-generated from code. They carry semantic annotations (colors, clusters, labels) that need human judgment. Drift is detected, not auto-fixed.
- **Every numerical claim**: State counts, transition counts, etc. are embedded in tested code and unlikely to drift silently. If they do, the health check will catch them.
- **Cross-repo consistency**: If `dsh-plugin-pyroduct` develops its own descriptions, a cross-repo check could be added later.
- **Diagram aesthetics**: Layout, colors, and label wording are human judgment. CI only checks structural claims.

---

## Commands

```bash
# Extract model facts from source code
python tools/extract_model_facts.py

# Check dependency edges + version pins
python tools/validate_dependencies.py
python tools/validate_dependencies.py --verbose

# Check README model facts
python tools/validate_readme_facts.py
python tools/validate_readme_facts.py --verbose

# Check plugin consistency (the harness prints its own count)
node plugin/tools/validate-plugin.mjs

# Full health check (manual, not in CI)
# See architecture/architecture-health-report.md for methodology
```

---

## History

- **2026-10-11**: Living architecture system created. Four drift failures motivated it:
  1. `module-dependencies.dot` had false edge `cmd_jsoncli -> viz` (found by health check)
  2. `module-dependencies.dot` and `dependency-map.dot` missing 3 edges for `cmd/jsoncli` (causal, dmlref, ml)
  3. `plugin/server.mjs` said "190 tests" but actual count was 197 (found by health check)
  4. `plugin/skills/pyroduct-model/SKILL.md` said "190 个测试" (same drift)

  Slices 1-4 implemented: dependency validator, test count anti-drift, CI integration, this contract.

- **2026-10-11**: Model fact registry added (second evolution). Three new drift shapes identified:
  1. README files contain hardcoded model facts (34 states, 53 transitions, etc.) that could drift when enums change
  2. Plugin face descriptions contain hardcoded model facts that could drift
  3. Architecture diagrams had no version pinning — when `moon.mod` version bumps, diagrams should be reviewed

  Slices 1-4 implemented: model fact extractor, README cross-checker, plugin description cross-checker (8 new checks, now 36 total), version pinning for all 17 DOT files.

---

**This file is the contract. If an invariant matters enough to complain about when it drifts, it belongs here.**
