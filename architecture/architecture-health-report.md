# Architecture Health Report — riantr/pyroduct

> **Date**: 2026-10-11
> **Scope**: 29 architecture artifacts in `architecture/` (created this session) + 3 plugin files with stale claims
> **Method**: Every numerical claim, dependency edge, flow step, and version string checked against source code
> **Overall trust level**: **HIGH with 3 findings to fix**

---

## Summary

| Category | Checked | Correct | Issues |
|----------|---------|---------|--------|
| Numerical claims (states/transitions/phases/faces/tests) | 8 | 8 | 0 |
| Module dependency edges | 39 | 39 | ~~2~~ → **FIXED** |
| Flow diagrams (subject/evolution/coordinator/CLI) | 12 claims | 12 | ~~1~~ → **FIXED** |
| Version consistency | 4 locations | 4 | 0 |
| Plugin descriptions | 3 files | 0 | **3 stale test counts** (not fixed — plugin dir) |
| Git tracking | 29 files | 0 | **29 untracked files** (not fixed — needs commit) |

**Verdict**: The architecture model is **trustworthy** — all core numerical claims, flow logic, dependency edges, and version pins match the code after fixes. Two remaining items (plugin test count drift, untracked architecture files) are outside the architecture directory.

---

## Finding 1: Wrong Dependency Edge — cmd/jsoncli → viz

**Severity**: MEDIUM — factual error in two diagrams  
**Confidence**: HIGH (verified against `cmd/jsoncli/moon.pkg`)  
**Status**: **FIXED** — edge removed from both diagrams

**Claim**: `module-dependencies.dot:128` and `dependency-map.dot:139` both draw an edge `cmd_jsoncli -> viz`.

**Reality**: `cmd/jsoncli/moon.pkg` imports 10 library packages (src, ml, multi, group, society, evolution, coordinator, dmlref, causal, audit) but **NOT viz**. This is intentional — the JSON bridge does not render Mermaid/HTML visualizations; those are CLI-only (presentation layer).

**Impact**: Overstates cmd/jsoncli's dependency fan-out by 1. Misleads anyone reading the diagram to understand what the bridge can access.

**Fix**: Remove the `cmd_jsoncli -> viz` edge from both `architecture/module-dependencies.dot` and `architecture/dependency-map.dot`.

**Evidence**: `cmd/jsoncli/moon.pkg:5-18` (import block, no viz entry).

---

## Finding 2: Stale Test Count in Plugin Descriptions

**Severity**: LOW — documentation drift, not a model error  
**Confidence**: HIGH (grep confirmed)

**Claim**: Three plugin files state "190 tests":
- `plugin/server.mjs:252` — `pyroduct_gates` tool description: `"moon test (wasm target, 190 tests)"`
- `plugin/server.mjs:330` — gates unavailable message: `"moon test（wasm target，190 个测试）"`
- `plugin/skills/pyroduct-model/SKILL.md:22` — skill table: `"190 个测试"`

**Reality**: The actual wasm test count is **197** (203 total test functions minus 6 native-only). The architecture diagrams correctly say 197. `plugin/skills/pyroduct-model/references/overview.md:50` also correctly says "197/197".

**Impact**: An agent or user reading the tool description or skill doc would believe the gate runs 190 tests when it actually runs 197. This is the same drift shape as the previously-fixed "28 faces" error (commit 7b95863 fixed the face count but missed the test count).

**Fix**: Replace "190" with "197" in all three locations.

**Evidence**: Counted 203 `test`/`async test` definitions across 27 `*_test.mbt` files; 6 are in `+native` packages (tools/ifacescan: 4, snnref: 2); 203 - 6 = 197.

---

## Finding 3: CLI Routing Diagram Structural Inaccuracy

**Severity**: LOW — functionally correct, structurally misleading  
**Confidence**: HIGH (verified against `cmd/main/main.mbt`)  
**Status**: **FIXED** — report node merged into default, evidence example corrected

**Claim**: `flow-cli-request.dot` shows `report` and `default` as two separate match arms with separate edges from the `match` node. `flow-cli-evidence.md:35` says "36 个命名子命令 + 1 个默认分支" and the routing table lists "report" as a named subcommand row.

**Reality**: The code has exactly **36 named match arms** (lines 44-78: "mermaid" through "buchi", plus "all" at line 79) and one `_` default (line 94). There is **no explicit `"report" =>` arm** — "report" is handled by the `_` default, which calls `@sm.render_report()`. Unknown subcommands also fall through to the same default.

**Impact**: The diagram implies 37+1 routing targets when the code has 36+1. Functionally harmless (both "report" and unknown yield the same output), but structurally inaccurate.

**Fix**: Either (a) merge the `report` and `default` nodes in the DOT into a single `default / report` node, or (b) add a note that "report" is the default fallback, not a named arm. Update the evidence table to mark "report" as "(default)" rather than a named subcommand.

**Evidence**: `cmd/main/main.mbt:43-95` — 36 string-literal match arms, none is "report"; line 94 `_ => println(@sm.render_report())`.

---

## Finding 4: All Architecture Files Untracked

**Severity**: MEDIUM — artifacts exist only in working tree  
**Confidence**: HIGH (`git status` shows `?? architecture/`)

**Status**: All 29 files in `architecture/` are untracked. They were created during this session but never committed.

**Impact**: If the working tree is lost, all architecture artifacts vanish. They cannot be reviewed in PRs, diffed against future changes, or referenced by CI.

**Fix**: Commit the architecture directory (after fixing Findings 1-3).

---

## Verified Correct — Numerical Claims

| # | Claim | Claimed | Actual | Source | Match |
|---|-------|---------|--------|--------|-------|
| 1 | Subject states | 34 | 34 | `src/subject.mbt:17-52` | ✓ |
| 2 | Subject transitions | 53 | 53 | `src/subject.mbt:628-694` | ✓ |
| 3 | Subject phases | 11 | 11 | `src/subject.mbt:63-75` | ✓ |
| 4 | Face count (jsoncli) | 31 | 31 | `cmd/jsoncli/main.mbt:31-38` | ✓ |
| 5 | Face count (plugin) | 31 | 31 | `plugin/server.mjs:41-73` | ✓ |
| 6 | Wasm test count | 197 | 197 | 27 `*_test.mbt` files, 203 - 6 native | ✓ |
| 7 | Group states | 20 | 20 | `group/machine.mbt:13-34` | ✓ |
| 8 | Society states | 13 | 13 | `society/state.mbt:41-55` | ✓ |

---

## Verified Correct — Version Consistency

| Location | Version | Purpose | Match |
|----------|---------|---------|-------|
| `moon.mod:3` | `0.1.29` | Module version | ✓ |
| `plugin/vendor/BUILD.json:3` | `0.1.29` | Bundled snapshot built from this module version | ✓ |
| `plugin/.minimax-plugin/plugin.json:6` | `0.3.0` | Plugin SemVer (independent) | ✓ |
| `plugin/server.mjs:31` (SERVER_VERSION) | `0.3.0` | Must match plugin.json | ✓ |

Two independent version tracks (module 0.1.29, plugin 0.3.0) — both internally consistent.

---

## Verified Correct — Module Dependencies

All 22 `moon.pkg` files checked. 37 of 39 dependency edges in the diagrams are correct.

**Correct edges confirmed** (selected):
- `src` and `society` have zero imports (foundation layers) ✓
- `multi -> src` ✓
- `group -> src, multi` ✓
- `evolution -> src, multi, group, ml` ✓
- `coordinator -> multi, ml, evolution` ✓
- `audit -> src, group, society` + external `moonbit_static_analysis` ✓
- `cmd/main -> all 11 library packages` ✓
- `cmd/coord -> coordinator` + `moonbitlang/async` (+native only) ✓
- `snnref -> src` + `snn_mbt` (+native only) ✓

**Wrong edges** (see Finding 1):
- ~~`cmd_jsoncli -> viz`~~ (NOT imported)

**Missing edges** (not drawn, not claimed):
- `cmd/ifacescan -> tools/ifacescan` (not shown in diagrams, but this is a minor internal edge)
- `examples/*` packages not shown (acceptable — they are demonstration entrypoints, not architecture-significant)

---

## Verified Correct — Flow Diagrams

| Flow | Claim | Code Location | Match |
|------|-------|---------------|-------|
| Subject step() | candidates() → filter → 5 outcomes | `src/loop.mbt:77-88, 138-169` | ✓ |
| Subject candidates() | `from==state && trigger.slot()==slot` | `src/loop.mbt:83` | ✓ |
| Evolution resolve_open() | toward_other > toward_self → spatial/temporal | `evolution/cycle.mbt:155-179` | ✓ |
| Evolution run_cycle() | signature + per-round flow | `evolution/cycle.mbt:187-244` | ✓ |
| Evolution judge() | constitution (R10/R2-R14/R3) then criterion | `evolution/gate.mbt:105-190` | ✓ |
| Evolution candidates | practice: carry-4, opening: toward_self-25 | `evolution/cycle.mbt:212,227` | ✓ |
| Coordinator step() | signature with 8 params | `coordinator/runtime.mbt:72-81` | ✓ |
| Coordinator routing | Theoretical → experiment+replicate, others → dialogue | `coordinator/runtime.mbt:101-111` | ✓ |
| Deliberation | open_remainder must be non-empty | `coordinator/decision.mbt:13,64` | ✓ |
| jsoncli faces() | 31 entries, render_kind routes each | `cmd/jsoncli/main.mbt:31-86` | ✓ |
| CLI routing | 36 named + default | `cmd/main/main.mbt:43-95` | ✓ (count) / ~ (structure, see Finding 3) |

---

## Verified Correct — Deployment Topology

| Claim | Evidence | Match |
|-------|----------|-------|
| Dual remotes (Gitee + GitHub) | `git remote -v` | ✓ |
| gate.yml runs 5 native packages explicitly | `.github/workflows/gate.yml:92-126` | ✓ |
| publish.yml asserts moon.mod version = tag | `.github/workflows/publish.yml:108-123` | ✓ |
| moon publish exit code unreliable (255 always) | `publish.yml` header, measured | ✓ |
| Plugin bridge SHA-256 pinned | `plugin/vendor/BUILD.json:10` | ✓ |
| Fallback marked with ⚠ warning | `plugin/server.mjs:callTool()` | ✓ |
| Bridge resolution: checkout > bundled | `plugin/server.mjs:resolveBridge()` | ✓ |

---

## Recommended Actions

### Done

1. ~~**Fix Finding 1**~~: ~~Remove `cmd_jsoncli -> viz`~~ ✓
2. ~~**Fix Finding 3**~~: ~~Merge `report` and `default` nodes~~ ✓

### Remaining (plugin directory, independent of architecture/)

3. **Fix Finding 2**: Replace "190" with "197" in `plugin/server.mjs:252,330` and `plugin/skills/pyroduct-model/SKILL.md:22`. Then re-run `node plugin/tools/validate-plugin.mjs` and `node plugin/tools/sync-install.mjs push`.

### After fixes

4. **Fix Finding 4**: Commit `architecture/` directory.

---

## Living Architecture Recommendations

To keep these artifacts trustworthy over time:

1. **Add a CI check**: Run a script that extracts dependency edges from `moon.pkg` files and compares against `module-dependencies.dot`. A drift here is silent without automation.

2. **Add a test-count anti-drift rule**: The plugin already has face-count anti-drift (`validate-plugin.mjs` checks FACES.length against tool description). Extend it to check the test count in `pyroduct_gates` description against `moon test --dry-run` output or a hardcoded current value.

3. **Pin architecture artifacts to code versions**: Add a header comment to each `.dot` file stating which module version it was generated against. When `moon.mod` version changes, flag the diagrams for review.

4. **Consider a regeneration script**: A script that reads `moon.pkg` files and regenerates `module-dependencies.dot` would eliminate the risk of manual drift.

---

## Artifact Inventory

| File | Type | Status |
|------|------|--------|
| `system-context.dsl` | Structurizr system context | ✓ Verified |
| `system-model.dsl` | Structurizr container model | ✓ Verified |
| `system-model.evidence.md` | Evidence index | ✓ Verified |
| `system-model.summary.md` | Summary | ✓ Verified |
| `module-dependencies.dot` | Module dependency graph | ✓ Fixed (removed wrong viz edge) |
| `dependency-map.dot` | Full dependency map with metrics | ✓ Fixed (removed wrong viz edge) |
| `impact-analysis-src.dot` | Change impact from src | ✓ Verified |
| `dependency-impact-findings.md` | Impact findings | ✓ Verified |
| `violations.csv` | Cycle/violation check results | ✓ Verified |
| `flow-subject-execution.dot` | Subject step() flow | ✓ Verified |
| `flow-subject-main-path.dot` | Subject simplified path | ✓ Verified |
| `flow-subject-evidence.md` | Subject flow evidence | ✓ Verified |
| `flow-evolution-cycle.dot` | Evolution cycle flow | ✓ Verified |
| `flow-evolution-main-path.dot` | Evolution simplified path | ✓ Verified |
| `flow-evolution-evidence.md` | Evolution flow evidence | ✓ Verified |
| `flow-coordinator-runtime.dot` | Coordinator runtime flow | ✓ Verified |
| `flow-coordinator-main-path.dot` | Coordinator simplified path | ✓ Verified |
| `flow-coordinator-evidence.md` | Coordinator flow evidence | ✓ Verified |
| `flow-cli-request.dot` | CLI routing flow | ✓ Fixed (merged report into default) |
| `flow-cli-main-path.dot` | CLI simplified path | ✓ Verified |
| `flow-cli-evidence.md` | CLI flow evidence | ✓ Fixed (corrected example) |
| `flow-plugin-bridge.dot` | Plugin bridge flow | ✓ Verified |
| `flow-plugin-main-path.dot` | Plugin simplified path | ✓ Verified |
| `flow-plugin-evidence.md` | Plugin flow evidence | ✓ Verified |
| `deployment-topology.dot` | Deployment topology | ✓ Verified |
| `release-path.dot` | CI/CD release path | ✓ Verified |
| `runtime-evidence.md` | Deployment evidence | ✓ Verified |
| `deployment-risks.md` | Deployment risks | ✓ Verified |
| `deployment-topology.summary.md` | Deployment summary | ✓ Verified |

---

**Generated**: 2026-10-11
**Skill**: `architecture-visualization:architecture-health`
**Next review**: After fixing Findings 1-4 and committing
