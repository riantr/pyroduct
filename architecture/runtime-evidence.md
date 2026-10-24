# Deployment Topology — Runtime Evidence Index

> **Scope**: Where pyroduct runs, how it gets released, how plugins are deployed
> **Status**: Verified against CI/CD workflows, plugin tools, build configuration
> **Date**: 2026-10-11

---

## 1. Source Code Repositories

| Remote | URL | Role | Evidence |
|--------|-----|------|----------|
| Gitee | `https://gitee.com/ren-yongxiang/pyroduct` | 日常远端 (daily remote) | `git remote -v`, `moon.mod:7` |
| GitHub | `ssh://git@ssh.github.com:443/riantr/pyroduct.git` | CI 远端 (CI remote) | `git remote -v` |

**Key fact**: Both remotes must be pushed. A tag pushed to Gitee alone triggers nothing — CI runs on GitHub only.

**Source**: `AGENTS.md` "CI" section, `publish.yml` header comments (lines 46-50).

---

## 2. CI/CD Workflows

### 2.1 gate.yml

| Item | Value | Source |
|------|-------|--------|
| Trigger | push to master/main, PR | `.github/workflows/gate.yml:28-32` |
| Runner | `ubuntu-latest` | `.github/workflows/gate.yml:36` |
| Install | `curl -fsSL https://cli.moonbitlang.com/install/unix.sh \| bash` | `.github/workflows/gate.yml:44-53` |
| Steps | `moon update` → `moon check --deny-warn` → `moon fmt --check` → `moon test --deny-warn` → `moon build --target js` → `moon build --target wasm` → native tests (5 packages) | `.github/workflows/gate.yml:55-126` |

**Native packages gated explicitly** (lines 92-126):
1. `moon test --target native snnref`
2. `moon test --target native tools/ifacescan`
3. `moon run --target native cmd/ifacescan`
4. `moon run --target native cmd/coord`
5. `moon run --target native examples/sediment`

**Why not `moon check --target native`**: Red by design — `tools/ifacescan/moon.pkg` imports `moonbitlang/async` for test-only `async test`, and moon's unused-package scan doesn't read test files. Adding native check would turn the gate red over a documented, non-defective import.

**Source**: `.github/workflows/gate.yml` (full file, 127 lines).

### 2.2 publish.yml

| Item | Value | Source |
|------|-------|--------|
| Trigger | `v*` tag push, `workflow_dispatch` (manual) | `.github/workflows/publish.yml:57-71` |
| Runner | `ubuntu-latest` | `.github/workflows/publish.yml:82` |
| Timeout | 20 minutes | `.github/workflows/publish.yml:83` |
| Secret | `MOONCAKES_RIANTR_TOKEN` (GitHub Secret) | `.github/workflows/publish.yml:86` |
| Dry run default | `true` (manual runs) | `.github/workflows/publish.yml:70-71` |

**Steps** (lines 89-215):
1. Checkout
2. Install moon
3. `moon update`
4. Assert `moon.mod` version = tag
5. Assert exactly one `moon.mod` in repo
6. Re-run gate (fmt + check + test + native + js + wasm)
7. Write `~/.moon/credentials.json` from secret
8. `moon publish --dry-run` (if manual) or `moon publish` (if tag)
9. `gh release create` (tag push only)
10. Trap: remove credentials on exit

**Authentication facts** (header comments, lines 11-27):
- `moon publish` reads `$HOME/.moon/credentials.json`, NOT an environment variable
- The secret's VALUE is the whole file contents (JSON object: `{ "token": "...", "username": "riantr" }`), not the bare token
- Exit code is 255 in ALL cases (including successes) — assert on `Server status:` line, not exit code
- Failure modes measured: malformed file → parse error, bad token → 401, dry run → 202 Accepted, real → 200 OK

**Source**: `.github/workflows/publish.yml` (full file, 216 lines).

---

## 3. Build Targets

| Target | Purpose | Output | Consumer | Evidence |
|--------|---------|--------|----------|----------|
| `wasm` | Registry artifact | `_build/wasm/...` | mooncakes.io, moonx, skills.mooncakes.io | `gate.yml:77-78`, `publish.yml:158` |
| `js` | Plugin bridge | `_build/js/debug/build/cmd/jsoncli/jsoncli.js` | MiniMax plugin, DSH plugin | `gate.yml:74-75`, `publish.yml:157` |
| `native` | Local tools/experiments | `_build/native/...` | Developer workstation, CI gate | `gate.yml:102-126` |

**Source**: `moon.mod`, `AGENTS.md` "Commands" section.

---

## 4. Package Registry

| Item | Value | Source |
|------|-------|--------|
| Registry | mooncakes.io | `moon.mod:1`, `publish.yml:204` |
| Module | `riantr/pyroduct` | `moon.mod:1` |
| Version | `0.1.29` | `moon.mod:3` |
| License | MIT | `moon.mod:9` |
| Skills link | skills.mooncakes.io | `AGENTS.md` "CI" section |

**Publishing flow**: `moon publish` → mooncakes.io accepts wasm artifact → skills.mooncakes.io links to it → moonx downloads it.

**Source**: `moon.mod`, `.github/workflows/publish.yml`.

---

## 5. Plugin Deployment

### 5.1 MiniMax Desktop Plugin

| Item | Value | Source |
|------|-------|--------|
| Plugin name | `pyroduct-model` | `plugin/.minimax-plugin/plugin.json:3` |
| Plugin version | `0.3.0` | `plugin/.minimax-plugin/plugin.json:6` |
| Install path | `~/.minimax/plugins/pyroduct-model/` | `plugin/tools/sync-install.mjs:42` |
| MCP config | `pyroduct.mcp.json` | `plugin/.minimax-plugin/plugin.json:14` |
| MCP server | `server.mjs` (stdio JSON-RPC) | `plugin/pyroduct.mcp.json:5-8` |
| Bridge | `vendor/jsoncli.js` (1.38 MB) | `plugin/vendor/BUILD.json:4` |
| Pin | SHA-256 in `vendor/BUILD.json` | `plugin/vendor/BUILD.json:10` |
| Built with | `moon 0.1.20260920 / moonc v0.10.14+7d59c7ec9` | `plugin/vendor/BUILD.json:5` |

**Deployment steps** (manual):
1. `node plugin/tools/update-bundle.mjs <checkout>` — rebuild bridge, re-pin SHA-256, run validate-plugin.mjs
2. `node plugin/tools/sync-install.mjs push` — copy repo → install dir, verify pin
3. MiniMax Desktop reloads plugin (no restart needed for text changes; MCP server restart needed for code changes)

**Bridge resolution** (runtime):
- If `PYRODUCT_PROJECT_DIR` is set → use `<checkout>/_build/js/.../jsoncli.js` (live model)
- Else → use `vendor/jsoncli.js` (bundled snapshot)
- Fallback is marked with `warning` in response so reader knows which model answered

**Source**: `plugin/tools/sync-install.mjs`, `plugin/tools/update-bundle.mjs`, `plugin/server.mjs`, `plugin/vendor/BUILD.json`.

### 5.2 DeepSeek Harness Plugin

| Item | Value | Source |
|------|-------|--------|
| Plugin repo | `riantr/dsh-plugin-pyroduct` (separate) | `AGENTS.md` "cmd/jsoncli" section |
| Bridge | Same `jsoncli.js` protocol | `cmd/jsoncli/main.mbt` |
| Spawner | Node.js, spawns `jsoncli.js` with JSON arg | `AGENTS.md` |

**Source**: `AGENTS.md`, `cmd/jsoncli/main.mbt`.

---

## 6. Validation Harness

| Tool | Purpose | Checks | Source |
|------|---------|--------|--------|
| `validate-plugin.mjs` | Plugin regression net | 27+ checks: pin, MCP handshake, 31 faces, invariants, anti-drift, page citations, checkout guard | `plugin/tools/validate-plugin.mjs` |
| `mutate_review.py` | Mutation testing | 48 mutations across 5 Loops + predicate census | `tools/mutate_review.py`, `AGENTS.md` |

**validate-plugin.mjs checks** (lines 116-371):
- Pin: SHA-256 + bytes match BUILD.json
- Version: plugin.json = server.mjs SERVER_VERSION
- MCP: initialize, ping, tools/list, tools/call
- Faces: all 31 render non-empty, catalog matches FACES list
- Invariants: report states 34 states · 53 transitions · 11 phases, audit states 未预期 0 条, etc.
- Page citations: exactly 4 faces print P.xx (group, intuition, multi, society)
- Anti-drift: catalog doesn't claim page refs for faces without them
- Checkout guard: gates hard-fail on bad path, face falls back to snapshot

**Source**: `plugin/tools/validate-plugin.mjs` (full file, 372 lines).

---

## 7. External Dependencies

| Dependency | Version | Consumer | Target | Source |
|------------|---------|----------|--------|--------|
| `moonbitlang/async` | `0.22.5` | `cmd/coord`, `tools/ifacescan`, `cmd/ifacescan` | native | `moon.mod:39` |
| `riantr/moonbit_doubleML` | `0.164.34` | `dmlref`, `causal` | wasm + native | `moon.mod:40` |
| `riantr/snn_mbt` | `0.166.2` | `snnref`, `examples/sediment` | native only | `moon.mod:41` |
| `riantr/moonbit_image` | `0.3.9` | (via snn_mbt) | native only | `AGENTS.md` |
| `riantr/moonbit_static_analysis` | `0.4.33` | `audit` | wasm + native | `moon.mod:42` |

**Dependency isolation**: Each third-party dep is confined to specific consumers. `src` (the base package) has zero imports. `ml` is fully self-contained (no numerics library).

**Source**: `moon.mod`, `AGENTS.md` "Dependency rule" section.

---

## 8. Runtime Environments

### 8.1 Developer Workstation

| Component | Command | Purpose |
|-----------|---------|---------|
| moon CLI | `moon check/test/fmt/build/run` | Build, test, format |
| Node.js | `node plugin/tools/*.mjs` | Plugin toolchain |
| git | `git push origin/github` | Dual-remote push |
| moon run cmd/main | 36 subcommands | CLI reports |
| moon run cmd/coord | native | Coordinator with disk I/O |
| node tools/face.mjs | `<kind>` | Face runner for humans |

### 8.2 GitHub Actions Runner

| Component | Runner | Purpose |
|-----------|--------|---------|
| gate.yml | ubuntu-latest | CI gate on push/PR |
| publish.yml | ubuntu-latest | Publish to mooncakes on v* tag |

### 8.3 MiniMax Desktop (Local Plugin)

| Component | Runtime | Purpose |
|-----------|---------|---------|
| MCP Server | Node.js (stdio) | JSON-RPC protocol |
| Bridge | Node.js (child process) | Spawn jsoncli.js |
| jsoncli.js | Node.js (MoonBit-compiled) | Route to model packages |
| Model | MoonBit (compiled to JS) | Render reports |

### 8.4 mooncakes.io Registry

| Component | Format | Purpose |
|-----------|--------|---------|
| wasm artifact | MoonBit wasm | Downloaded by moonx, linked by skills.mooncakes.io |

---

## 9. Authentication & Secrets

| Secret | Location | Format | Purpose | Source |
|--------|----------|--------|---------|--------|
| `MOONCAKES_RIANTR_TOKEN` | GitHub Secret (repo settings) | JSON object: `{ "token": "...", "username": "riantr" }` | `moon publish` authentication | `publish.yml:86`, header comments |
| `~/.moon/credentials.json` | Runner filesystem (ephemeral) | Same JSON object | Written from secret, removed by trap | `publish.yml:169-170` |

**Verification**: Actions → publish → Run workflow (dry run default) → token is validated against registry without publishing anything.

---

## 10. Trust Boundaries

| Boundary | Description | Evidence |
|----------|-------------|----------|
| Source → CI | GitHub Actions pulls from github remote | `gate.yml:38`, `publish.yml:91` |
| CI → Registry | `moon publish` authenticates with credentials | `publish.yml:204` |
| Plugin → Bridge | MCP server spawns jsoncli.js as child process | `plugin/server.mjs:callBridge()` |
| Bridge → Model | jsoncli.js calls `@pkg.render_xxx()` | `cmd/jsoncli/main.mbt:render_kind()` |
| Checkout → Bundled | Fallback when `PYRODUCT_PROJECT_DIR` is unset or invalid | `plugin/server.mjs:resolveBridge()` |

---

## 11. Network Boundaries

| Boundary | Direction | Protocol | Evidence |
|----------|-----------|----------|----------|
| GitHub Actions → mooncakes.io | Outbound | HTTPS | `publish.yml:204` |
| GitHub Actions → cli.moonbitlang.com | Outbound | HTTPS | `gate.yml:46`, `publish.yml:96` |
| MCP Server → jsoncli.js | Local | stdio (JSON-RPC) | `plugin/pyroduct.mcp.json:5-8` |
| jsoncli.js → Model packages | In-process | Function calls | `cmd/jsoncli/main.mbt:render_kind()` |

**No external network calls from the plugin at runtime** — all model facts are computed locally from the bundled snapshot or checkout.

---

## 12. Artifact Provenance

| Artifact | Built by | Pinned by | Validated by | Source |
|----------|----------|-----------|--------------|--------|
| `vendor/jsoncli.js` | `moon build --target js` | `vendor/BUILD.json` (SHA-256 + bytes) | `validate-plugin.mjs` | `plugin/tools/update-bundle.mjs` |
| wasm registry artifact | `moon build --target wasm` | mooncakes.io (server-side) | `gate.yml` + `publish.yml` | `gate.yml:77-78` |
| GitHub Release | `gh release create` | git tag | `publish.yml` | `publish.yml:206-215` |

---

## 13. Related Artifacts

- `architecture/deployment-topology.dot` — Full deployment topology diagram
- `architecture/release-path.dot` — CI/CD release path diagram
- `architecture/deployment-risks.md` — Deployment risks and gaps
- `AGENTS.md` — Project guidance (CI, plugin, layout sections)
- `.github/workflows/gate.yml` — CI gate workflow
- `.github/workflows/publish.yml` — Publish workflow
- `plugin/tools/sync-install.mjs` — Plugin sync tool
- `plugin/tools/update-bundle.mjs` — Bridge rebuild tool
- `plugin/tools/validate-plugin.mjs` — Plugin validation harness

---

**Generated**: 2026-10-11
**Verified against**: `.github/workflows/gate.yml`, `.github/workflows/publish.yml`, `plugin/tools/*.mjs`, `plugin/vendor/BUILD.json`, `moon.mod`, `git remote -v`
