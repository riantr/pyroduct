# Migration Roadmap — Model Fact Registry Evolution

> **Goal**: Extract model facts from source code once, cross-check every consumer
> **Timeline**: 4 slices, each independently valuable
> **Date**: 2026-10-11
> **Status**: Proposed

---

## Slice 1: Model Fact Extractor

**Goal**: Create a single script that extracts all model facts from source code
**Duration**: ~45 minutes
**Deliverable**: `tools/extract_model_facts.py`

### Steps

1. Write `tools/extract_model_facts.py`:
   - Parse `src/subject.mbt`:
     - Count `SubjectState` enum variants (expect 34)
     - Count `Phase` enum variants (expect 11)
     - Count `Trigger` enum variants (expect 49)
     - Count `transitions()` function rows (expect 53)
   - Parse `src/slot.mbt`:
     - Count `Slot` enum variants (expect 8)
   - Parse `group/machine.mbt`:
     - Count `GroupState` enum variants (expect 20)
     - Count `GroupPhase` enum variants (expect 9)
     - Count `GroupTrigger` enum variants (expect 22)
     - Count `transitions()` function rows (expect 44)
   - Parse `society/state.mbt`:
     - Count `State` enum variants (expect 13)
     - Count `Phase` enum variants (expect 8)
     - Count `Trigger` enum variants (expect 18)
     - Count `transitions()` function rows (expect 28)
   - Compute derived facts:
     - `combinations.total` = states × slots = 34 × 8 = 272
     - `combinations.no_way` = 228 (hardcoded, from step() output)
   - Output JSON to stdout:
     ```json
     {
       "subject": {"states": 34, "transitions": 53, "phases": 11, "triggers": 49, "slots": 8},
       "group": {"states": 20, "transitions": 44, "phases": 9, "triggers": 22},
       "society": {"states": 13, "transitions": 28, "phases": 8, "triggers": 18},
       "combinations": {"total": 272, "no_way": 228}
     }
     ```

2. Test against current codebase:
   ```bash
   python tools/extract_model_facts.py
   # Should output JSON matching the table above
   ```

3. Introduce a deliberate change:
   - Add a dummy variant to `SubjectState` enum (e.g., `Dummy`)
   - Run extractor, confirm `subject.states` = 35
   - Revert the change

### Acceptance Criteria

- [ ] Script runs in < 2 seconds
- [ ] Outputs valid JSON to stdout
- [ ] All 15 facts match known values (34, 53, 11, 49, 8, 20, 44, 9, 22, 13, 28, 8, 18, 272, 228)
- [ ] Detects when a variant is added to any enum
- [ ] No external dependencies (Python stdlib only)
- [ ] Includes a `--help` flag explaining usage

### Validation Signal

```bash
# Baseline: should pass
python tools/extract_model_facts.py | python -m json.tool

# Introduce drift: add a dummy variant to SubjectState
echo "  | Dummy" >> src/subject.mbt  # after the last variant
python tools/extract_model_facts.py | grep '"states": 35'  # should match
git checkout src/subject.mbt  # revert
```

---

## Slice 2: README Cross-Checker

**Goal**: Detect when README files contain stale model facts
**Duration**: ~30 minutes
**Deliverable**: `tools/validate_readme_facts.py`

### Steps

1. Write `tools/validate_readme_facts.py`:
   - Run `tools/extract_model_facts.py` and parse its JSON output
   - For each README file (`README.mbt.md`, `README.zh.mbt.md`):
     - Extract numerical claims using regex:
       - `\*\*(\d+)\*\*` (markdown bold numbers)
       - `(\d+) 位置` / `(\d+) positions`
       - `(\d+) 迁移` / `(\d+) transitions`
       - `(\d+) 阶段` / `(\d+) phases`
       - etc.
     - Compare each claim against extracted facts
     - Report mismatches with file, line number, expected, actual
   - Exit 0 if all match, exit 1 if any drift

2. Test against current codebase:
   ```bash
   python tools/validate_readme_facts.py
   # Should exit 0 (READMEs are currently correct)
   ```

3. Introduce deliberate drift:
   - Change "**34**" to "**35**" in README.mbt.md line 12
   - Run validator, confirm it reports the mismatch
   - Revert the change

### Acceptance Criteria

- [ ] Script runs in < 3 seconds
- [ ] Checks both README.mbt.md and README.zh.mbt.md
- [ ] Detects stale numbers in markdown bold (`**34**`) and plain (`34`)
- [ ] Reports file, line number, expected value, actual value
- [ ] Exit code 0 on clean, 1 on drift
- [ ] No external dependencies (Python stdlib only)

### Validation Signal

```bash
# Baseline: should pass
python tools/validate_readme_facts.py && echo "README facts OK"

# Introduce drift
sed -i 's/\*\*34\*\*/\*\*35\*\*/' README.mbt.md  # line 12
python tools/validate_readme_facts.py  # should exit 1, report line 12
git checkout README.mbt.md  # revert
```

---

## Slice 3: Plugin Description Cross-Checker

**Goal**: Detect when plugin face descriptions contain stale model facts
**Duration**: ~30 minutes
**Deliverable**: Extension to `plugin/tools/validate-plugin.mjs`

### Steps

1. Extend `plugin/tools/validate-plugin.mjs`:
   - Add a new check block after the existing test count check:
     ```javascript
     // --- model fact anti-drift ---
     const expectedFacts = {
       subject: { states: 34, transitions: 53, phases: 11, triggers: 49, slots: 8 },
       group: { states: 20, transitions: 44, phases: 9, triggers: 22 },
       society: { states: 13, transitions: 28, phases: 8, triggers: 18 },
       combinations: { total: 272, no_way: 228 }
     }
     
     // Check face descriptions for model facts
     const faceDescChecks = [
       { face: 'report', pattern: /(\d+) 位置 . (\d+) 迁移 . (\d+) 阶段/, 
         expected: [34, 53, 11] },
       { face: 'slots', pattern: /(\d+) 条触发句 -> (\d+) 个驱动槽/, 
         expected: [49, 8] },
       { face: 'group', pattern: /(\d+) 状态/, expected: [20] },
       { face: 'society', pattern: /(\d+) 状态/, expected: [13] },
       { face: 'fleet', pattern: /群体 (\d+) 状态 . (\d+) 迁移、社会 (\d+) 状态 . (\d+) 迁移/,
         expected: [20, 44, 13, 28] },
       // ... more checks
     ]
     
     for (const { face, pattern, expected } of faceDescChecks) {
       const faceObj = FACES.find(f => f.kind === face)
       const match = faceObj?.description?.match(pattern)
       if (!match) {
         check(`${face} description contains model facts`, false, 'pattern not found')
         continue
       }
       const actual = match.slice(1).map(Number)
       check(`${face} description model facts match code`,
         JSON.stringify(actual) === JSON.stringify(expected),
         `expected ${expected}, got ${actual}`)
     }
     ```

2. Test against current codebase:
   ```bash
   node plugin/tools/validate-plugin.mjs
   # Should pass (descriptions are currently correct)
   ```

3. Introduce deliberate drift:
   - Change "34 位置" to "35 位置" in server.mjs line 42
   - Run validator, confirm it reports the mismatch
   - Revert the change

### Acceptance Criteria

- [ ] New checks in validate-plugin.mjs verify model facts in face descriptions
- [ ] Checks at least: report, slots, group, society, fleet faces
- [ ] Detects when a number in a description doesn't match code
- [ ] Existing checks still pass
- [ ] Total validation time < 10 seconds

### Validation Signal

```bash
# Baseline: should pass
node plugin/tools/validate-plugin.mjs && echo "plugin OK"

# Introduce drift
sed -i 's/34 位置/35 位置/' plugin/server.mjs  # line 42
node plugin/tools/validate-plugin.mjs  # should fail on report description check
git checkout plugin/server.mjs  # revert
```

---

## Slice 4: Version Pinning + CI Integration

**Goal**: Pin architecture diagrams to module version, integrate all validators into CI
**Duration**: ~20 minutes
**Deliverable**: Version pins in DOT files, updated CI workflows

### Steps

1. Add version pin to all 15 DOT files in `architecture/`:
   ```dot
   // model-version: 0.1.29
   digraph G {
     ...
   }
   ```
   
   Files to update:
   - `module-dependencies.dot`
   - `dependency-map.dot`
   - `impact-analysis-src.dot`
   - `flow-subject-execution.dot`
   - `flow-subject-main-path.dot`
   - `flow-evolution-cycle.dot`
   - `flow-evolution-main-path.dot`
   - `flow-coordinator-runtime.dot`
   - `flow-coordinator-main-path.dot`
   - `flow-cli-request.dot`
   - `flow-cli-main-path.dot`
   - `flow-plugin-bridge.dot`
   - `flow-plugin-main-path.dot`
   - `deployment-topology.dot`
   - `release-path.dot`

2. Extend `tools/validate_dependencies.py` (or create `tools/validate_version_pins.py`):
   - Read `moon.mod` version
   - For each `.dot` file in `architecture/`, extract `// model-version: X.Y.Z`
   - Report files where pin ≠ `moon.mod` version
   - Exit 0 if all match, exit 1 if any drift

3. Update `.github/workflows/gate.yml`:
   ```yaml
   - name: architecture · dependency edges + model facts + version pins
     run: |
       python tools/validate_dependencies.py
       python tools/validate_readme_facts.py
       python tools/validate_version_pins.py

   - name: plugin · anti-drift (faces, versions, test count, descriptions, invariants)
     run: node plugin/tools/validate-plugin.mjs
   ```

4. Update `.github/workflows/publish.yml` similarly (in the Gate step).

5. Update `LIVING_ARCHITECTURE.md`:
   - Add section "3. Model Facts in READMEs"
   - Add section "4. Architecture Diagram Version Pins"
   - Update the commands section

6. Test version pinning:
   - Change `moon.mod` version to 0.1.30 (don't commit)
   - Run validator, confirm it reports all 15 DOT files as stale
   - Revert `moon.mod`

### Acceptance Criteria

- [ ] All 15 DOT files carry `// model-version: 0.1.29` header
- [ ] Validator detects when `moon.mod` version ≠ DOT pin
- [ ] `gate.yml` runs all 3 Python validators + 1 Node validator
- [ ] `publish.yml` runs the same validators
- [ ] `LIVING_ARCHITECTURE.md` documents the new invariants
- [ ] Total CI time increase < 10 seconds

### Validation Signal

```bash
# Baseline: should pass
python tools/validate_version_pins.py && echo "version pins OK"

# Introduce drift: bump moon.mod version
sed -i 's/"version": "0.1.29"/"version": "0.1.30"/' moon.mod
python tools/validate_version_pins.py  # should exit 1, report 15 files
git checkout moon.mod  # revert
```

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

- **Slice 1** is the foundation (extractor)
- **Slice 2** and **Slice 3** are independent (consumers)
- **Slice 4** depends on all three (CI integration)

---

## Risk Mitigation

| Risk | Slice | Mitigation |
|------|-------|------------|
| Regex parsing misses edge cases | 1 | Test against all 3 machine files; enum definitions are highly regular |
| README uses markdown formatting | 2 | Parser strips markdown before matching |
| Node script can't call Python | 3 | Hardcode facts in Node (same numbers, two extraction paths) |
| Version pinning is noisy | 4 | That's the point — diagrams should be reviewed on version bump |
| False positives block CI | All | Each slice includes deliberate-error testing before CI integration |

---

## Success Metrics

After all 4 slices:

1. **Model facts extracted**: `tools/extract_model_facts.py` outputs JSON with 15+ facts
2. **READMEs checked**: `tools/validate_readme_facts.py` exits 0 on clean code, 1 on drift
3. **Plugin descriptions checked**: `validate-plugin.mjs` verifies model facts in face descriptions
4. **Diagrams versioned**: All DOT files carry `// model-version:` matching `moon.mod`
5. **CI-enforced**: All validators run in CI; drift is a build failure
6. **Fast**: Total validation time < 20 seconds

---

## Out of Scope (Future)

- **Auto-update READMEs**: Detects drift, doesn't fix it. Human judgment is needed.
- **Check architecture diagram labels**: Version pinning flags the file for review but doesn't parse every label.
- **Compute 228 at runtime**: Hardcoded for now; can be computed later if needed.
- **Cross-repo consistency**: If dsh-plugin-pyroduct develops its own descriptions, a cross-repo check could be added.

---

**Generated**: 2026-10-11
**Status**: Proposed — awaiting implementation
**Next action**: Start with Slice 1 (extract_model_facts.py)
