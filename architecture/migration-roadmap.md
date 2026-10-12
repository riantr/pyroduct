# Migration Roadmap — Living Architecture Automation

> **Goal**: Prevent architecture artifacts from drifting away from code
> **Timeline**: 4 slices, each independently valuable
> **Date**: 2026-10-11

---

## Slice 1: Dependency Edge Validator

**Goal**: Detect when `moon.pkg` imports change but architecture diagrams don't  
**Duration**: ~1 hour  
**Deliverable**: `tools/validate_dependencies.py`

### Steps

1. Write `tools/validate_dependencies.py`:
   - Discover all `moon.pkg` files (excluding `_build/`, `.mooncakes/`)
   - Parse `import { ... }` blocks to extract (package, imported_package, alias) tuples
   - Parse `architecture/module-dependencies.dot` and `architecture/dependency-map.dot` to extract edges
   - Compare: report edges in DOT but not in code (false edges) and edges in code but not in DOT (missing edges)
   - Exit 0 if match, exit 1 if drift

2. Test against current codebase:
   - Should pass (we just fixed the `cmd_jsoncli -> viz` error)
   - Introduce a deliberate error to confirm detection

3. Document usage:
   ```bash
   python tools/validate_dependencies.py
   # or
   python tools/validate_dependencies.py --dot architecture/module-dependencies.dot
   ```

### Acceptance Criteria

- [ ] Script runs in < 2 seconds
- [ ] Detects the `cmd_jsoncli -> viz` error if reintroduced
- [ ] Reports both false edges and missing edges
- [ ] Exit code 0 on clean, 1 on drift
- [ ] No external dependencies (Python stdlib only)

### Validation Signal

```bash
# Introduce a fake edge, run validator, expect failure
echo '    cmd_jsoncli -> viz [color="#2E7D32"];' >> architecture/module-dependencies.dot
python tools/validate_dependencies.py  # should exit 1
# Revert
git checkout architecture/module-dependencies.dot
python tools/validate_dependencies.py  # should exit 0
```

---

## Slice 2: Test Count Anti-Drift

**Goal**: Detect when test count changes but plugin descriptions don't  
**Duration**: ~30 minutes  
**Deliverable**: Extension to `plugin/tools/validate-plugin.mjs`

### Steps

1. Add to `validate-plugin.mjs`:
   - Count `test "..."` and `async test "..."` in all `*_test.mbt` files (excluding `_build/`, `.mooncakes/`)
   - Subtract tests in `+native` packages (tools/ifacescan, snnref)
   - Extract test count from `pyroduct_gates` tool description in `server.mjs`
   - Compare: report if they differ

2. Fix current drift:
   - `plugin/server.mjs:252`: "190 tests" → "197 tests"
   - `plugin/server.mjs:330`: "190 个测试" → "197 个测试"
   - `plugin/skills/pyroduct-model/SKILL.md:22`: "190 个测试" → "197 个测试"

3. Re-run validation:
   ```bash
   node plugin/tools/validate-plugin.mjs  # should pass with new check
   ```

### Acceptance Criteria

- [ ] New check in validate-plugin.mjs counts tests correctly (197)
- [ ] Detects "190" if reintroduced in descriptions
- [ ] Existing checks still pass
- [ ] Total validation time < 10 seconds

### Validation Signal

```bash
# Temporarily change a description back to 190
sed -i 's/197 tests/190 tests/' plugin/server.mjs
node plugin/tools/validate-plugin.mjs  # should fail on test count check
# Revert
git checkout plugin/server.mjs
```

---

## Slice 3: CI Integration

**Goal**: Make drift a CI failure, not just a local finding  
**Duration**: ~15 minutes  
**Deliverable**: Two new steps in `.github/workflows/gate.yml`

### Steps

1. Add to `gate.yml` after the existing `moon test` steps:

```yaml
      - name: Architecture dependency edges must match code
        run: python tools/validate_dependencies.py

      - name: Plugin validation (anti-drift)
        run: node plugin/tools/validate-plugin.mjs
```

2. Verify locally:
   ```bash
   python tools/validate_dependencies.py && echo "deps OK"
   node plugin/tools/validate-plugin.mjs && echo "plugin OK"
   ```

3. Push and confirm CI passes.

### Acceptance Criteria

- [ ] gate.yml runs both validators
- [ ] CI passes on current codebase
- [ ] CI would fail if dependency edge drift reintroduced
- [ ] CI would fail if test count drift reintroduced
- [ ] Total CI time increase < 15 seconds

### Validation Signal

```bash
# Simulate drift, push to branch, confirm CI red
# (Do this on a test branch, not master)
```

---

## Slice 4: Living Architecture Contract + Commit

**Goal**: Document what the architecture model promises, and commit it  
**Duration**: ~30 minutes  
**Deliverable**: `LIVING_ARCHITECTURE.md` + `git add architecture/`

### Steps

1. Write `LIVING_ARCHITECTURE.md`:
   - Declare which invariants are enforced by CI
   - List the validators and what they check
   - Document how to add new invariants
   - State the confidence level of each architecture artifact

2. Commit architecture/:
   ```bash
   git add architecture/
   git add tools/validate_dependencies.py
   git add LIVING_ARCHITECTURE.md
   git add .github/workflows/gate.yml  # if Slice 3 done
   git commit -m "活架构：入库架构图 + 加依赖边/插件反漂移 CI 检查"
   ```

3. Update AGENTS.md:
   - Add `python tools/validate_dependencies.py` to the commands section
   - Add a "Living Architecture" section explaining the contract

### Acceptance Criteria

- [ ] `LIVING_ARCHITECTURE.md` exists and is accurate
- [ ] `architecture/` is tracked in git
- [ ] AGENTS.md documents the new validators
- [ ] New contributors can understand what's enforced

### Validation Signal

```bash
git ls-files architecture/ | wc -l  # should be 30+ (29 existing + new files)
git ls-files tools/validate_dependencies.py  # should exist
```

---

## Slice Dependencies

```
Slice 1 (validate_dependencies.py)
    ↓
Slice 3 (CI integration) ← Slice 2 (test count check)
    ↓
Slice 4 (contract + commit)
```

- Slice 1 and Slice 2 are independent (can be done in parallel)
- Slice 3 depends on both Slice 1 and Slice 2 (adds both to CI)
- Slice 4 depends on Slice 3 (commits everything after CI is green)

---

## Risk Mitigation

| Risk | Slice | Mitigation |
|------|-------|------------|
| False positives block CI | 3 | Run validators locally first; fix all drift before adding to CI |
| Validator itself has bugs | 1, 2 | Each slice includes a "deliberate error" test to confirm detection |
| New developers don't know about validators | 4 | AGENTS.md + LIVING_ARCHITECTURE.md document them |
| Validators become stale themselves | 4 | The validators are simple enough to review in PRs |

---

## Success Metrics

After all 4 slices:

1. **Zero known drift**: All architecture artifacts match code
2. **CI-enforced**: Any future drift is caught before merge
3. **Documented**: LIVING_ARCHITECTURE.md explains the contract
4. **Fast**: Total validation time < 15 seconds
5. **Maintainable**: Adding a new invariant is a matter of extending a script, not a process change

---

## Out of Scope (Future)

- **Auto-regeneration of DOT files**: The diagrams carry semantic annotations that auto-generation cannot reproduce. Drift detection is sufficient.
- **Pre-commit hooks**: CI enforcement is enough for now. Pre-commit hooks can be added later if developers want faster feedback.
- **Architecture diagram rendering in CI**: The DOT files are source; rendering them to SVG/PNG is a presentation concern, not a validation concern.
- **Cross-repo consistency**: If dsh-plugin-pyroduct develops its own descriptions, a cross-repo check could be added later.

---

**Generated**: 2026-10-11
**Status**: Proposed — awaiting implementation
**Next action**: Start with Slice 1 (validate_dependencies.py)
