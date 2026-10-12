# Plugin Bridge Flow — Evidence Index

> **Flow**: MiniMax plugin bridge (MCP server → jsoncli.js → model packages)
> **Scope**: Plugin request lifecycle from user invocation to rendered report
> **Status**: Verified against plugin/server.mjs, cmd/jsoncli/main.mbt, plugin/.minimax-plugin/plugin.json

---

## 1. Plugin Manifest

| Item | Value | Source |
|------|-------|--------|
| Plugin name | `pyroduct-model` | `plugin/.minimax-plugin/plugin.json:3` |
| Plugin version | `0.3.0` | `plugin/.minimax-plugin/plugin.json:6` |
| MCP server ref | `pyroduct.mcp.json` | `plugin/.minimax-plugin/plugin.json:14` |
| Skill ref | `skills/pyroduct-model/SKILL.md` | `plugin/.minimax-plugin/plugin.json:15` |

**Evidence**: Plugin manifest declares one MCP server and one skill. The MCP server is the bridge entry point.

---

## 2. MCP Server Entry Point

| Step | Code Location | Description |
|------|---------------|-------------|
| Server name | `plugin/server.mjs:1` | `SERVER_NAME = 'pyroduct-model'` |
| Server version | `plugin/server.mjs:2` | `SERVER_VERSION = '0.3.0'` (must match plugin.json) |
| JSON-RPC handler | `plugin/server.mjs:~350` | `handle(message)` routes by `method` |
| Protocol methods | `plugin/server.mjs:~355-390` | `initialize`, `ping`, `tools/list`, `tools/call` |

**Evidence**: The server implements JSON-RPC 2.0 over stdio. `tools/call` dispatches to three tools: `pyroduct_faces`, `pyroduct_face`, `pyroduct_gates`.

---

## 3. MCP Tools Catalog

| Tool | Purpose | Input | Output |
|------|---------|-------|--------|
| `pyroduct_faces` | Return face catalog | `{}` | Text: 31 faces + provenance |
| `pyroduct_face` | Run one face | `{kind: string}` | Text: rendered report |
| `pyroduct_gates` | Run gate suite | `{}` | Text: check/fmt/test results |

**Evidence**: `plugin/server.mjs:~120-180` defines `TOOLS` array with name, description, inputSchema. Each tool is `readOnly: true`.

---

## 4. Bridge Resolution

| Decision | Code Location | Outcome |
|----------|---------------|---------|
| Check `PYRODUCT_PROJECT_DIR` | `plugin/server.mjs:~50` | `projectDirOf()` returns path or `null` |
| Resolve bridge path | `plugin/server.mjs:~60-90` | `resolveBridge(projectDir)` → `{bridge, source, warning}` |
| Checkout path | `plugin/server.mjs:~70` | `<checkout>/_build/js/debug/build/cmd/jsoncli/jsoncli.js` |
| Bundled path | `plugin/server.mjs:~80` | `plugin/vendor/jsoncli.js` |
| Source tag | `plugin/server.mjs:~75,85` | `'checkout'` or `'bundled'` or `'fallback'` |
| Warning | `plugin/server.mjs:~88` | Set when falling back to bundled |

**Evidence**: Bridge resolution prefers a configured checkout (live model) over the bundled snapshot (frozen model). The `source` tag and `warning` field propagate to the response so the reader knows which model version answered.

---

## 5. Bridge Invocation

| Step | Code Location | Description |
|------|---------------|-------------|
| Build request | `plugin/server.mjs:~100` | `request = {kind}` (for `pyroduct_face`) |
| Spawn process | `plugin/server.mjs:~105` | `runProcess(nodePathOf(), [bridge, JSON.stringify(request)], opts)` |
| Working dir | `plugin/server.mjs:~106` | `cwd: projectDir ?? PLUGIN_ROOT` |
| Timeout | `plugin/server.mjs:~107` | `timeoutMs: DEFAULT_TIMEOUT_MS` |
| Signal | `plugin/server.mjs:~108` | `signal` (for cancellation) |
| Capture output | `plugin/server.mjs:~109` | `result.stdout`, `result.stderr`, `result.code` |

**Evidence**: The bridge is a child process spawned with `node`. The request is a single JSON object passed as a command-line argument. The reply is read from stdout.

---

## 6. JSON Bridge (cmd/jsoncli)

| Step | Code Location | Description |
|------|---------------|-------------|
| Entry point | `cmd/jsoncli/main.mbt:125` | `fn main` |
| Find JSON arg | `cmd/jsoncli/main.mbt:120-123` | `find_request_arg(args)` scans for `{` prefix |
| Parse request | `cmd/jsoncli/main.mbt:100` | `@json.from_json(@json.parse(raw))` → `Request` |
| Default kind | `cmd/jsoncli/main.mbt:102` | `request.kind.unwrap_or("report")` |
| Validate kind | `cmd/jsoncli/main.mbt:103` | `faces().contains(k)` |
| Render | `cmd/jsoncli/main.mbt:60-90` | `render_kind(kind)` → `@pkg.render_xxx()` |
| Build reply | `cmd/jsoncli/main.mbt:45-50` | `ok_reply(kind, rendered)` or `err_reply(msg)` |
| Print reply | `cmd/jsoncli/main.mbt:125` | `println(@json.to_json(reply).stringify())` |

**Evidence**: The JSON bridge is a pure formatter — it holds no model facts. All rendering delegates to model packages via `@pkg.render_xxx()`. The reply envelope is `{ok, error, kind, rendered, faces}`.

---

## 7. Face Catalog

| Item | Value | Source |
|------|-------|--------|
| Face count | 31 | `cmd/jsoncli/main.mbt:35-40` |
| Faces list | `faces()` | `cmd/jsoncli/main.mbt:35-40` |
| Faces in plugin | `FACES` array | `plugin/server.mjs:~30-65` |

**Evidence**: The face catalog is the single source of truth for which kinds the bridge accepts. Both `cmd/jsoncli` and `plugin/server.mjs` maintain parallel lists (31 entries each). The `faces` field in the reply lets the caller verify the catalog hasn't drifted.

---

## 8. Render Routing

| Kind | Package | Function |
|------|---------|----------|
| `report` | `@sm` | `render_report()` |
| `slots` | `@sm` | `render_slots()` |
| `loop` | `@sm` | `render_loop_report()` |
| `multi` | `@multi` | `render_multi_report()` |
| `group` | `@group` | `render_group_report()` |
| `society` | `@society` | `render_report()` |
| `evolution` | `@evolution` | `render_report()` |
| `cycle` | `@evolution` | `render_cycle_report(demo_cycle())` |
| `coordinator` | `@coordinator` | `render_report()` |
| `dmlref` | `@dmlref` | `render_report()` |
| `causal` | `@causal` | `render_report()` |
| `audit` | `@audit` | `render_report()` |
| `fleet` | `@audit` | `render_fleet_report()` |
| `mutants` | `@audit` | `render_mutation_report()` |
| `mbti` | `@audit` | `render_iface_report(scan_snapshot())` |
| `mermaid` | `@sm` | `render_mermaid()` |
| `dot` | `@sm` | `render_dot()` |
| `genesis` | `@sm` | `render_genesis()` |
| `course` | `@sm` | `render_course()` |
| `naming` | `@sm` | `render_naming_table()` |
| `principle` | `@sm` | `revision_principle()` |
| `intuition` | `@evolution` | `intuition_principle()` |
| `ml` | `@ml` | `render_ml_report(default_ml_plan())` |
| `ml-export` | `@ml` | `csv_preview(make_dataset(200, 1.5, 7), 12)` |
| `spec` | `@sm` | `spec_json()` |
| `association` | `@evolution` | `render_association_report()` |
| `pathsum` | `@sm` | `render_pathsum_report()` |
| `algebra` | `@sm` | `render_algebra_report()` |
| `petri` | `@sm` | `render_petri_report()` |
| `aho` | `@sm` | `render_aho_report()` |
| `buchi` | `@sm` | `render_buchi_report()` |

**Evidence**: `cmd/jsoncli/main.mbt:60-90` maps each kind to a package-qualified render function. The routing is exhaustive over the 31-face catalog.

---

## 9. Response Parsing

| Step | Code Location | Description |
|------|---------------|-------------|
| Extract last line | `plugin/server.mjs:~110` | `result.stdout.trim().split('\n').pop()` |
| Parse JSON | `plugin/server.mjs:~112` | `JSON.parse(line)` → `reply` |
| Check ok | `plugin/server.mjs:~118` | `reply.ok !== true` → throw error |
| Return result | `plugin/server.mjs:~120` | `{...reply, source, warning}` |

**Evidence**: The bridge prints exactly one JSON line to stdout. The plugin parses it and checks `reply.ok`. If false, it throws with the error message from `reply.error`.

---

## 10. Tool-Specific Flows

### 10.1 pyroduct_faces

| Step | Description |
|------|-------------|
| 1 | Probe with `{kind: 'report'}` to get `source` and `warning` |
| 2 | Render catalog with `renderCatalog(source, warning)` |
| 3 | Return `textResult(catalog_text)` |

**Evidence**: `plugin/server.mjs:~200-205`. The probe ensures the catalog shows which bridge answered (checkout vs bundled).

### 10.2 pyroduct_face

| Step | Description |
|------|-------------|
| 1 | Validate `kind` against `FACE_KINDS` |
| 2 | Call bridge with `{kind}` |
| 3 | Return `textResult(reply.rendered)` or `textResult(warning + rendered)` if fallback |

**Evidence**: `plugin/server.mjs:~210-230`. If the bridge fell back to bundled, the warning is prepended so the reader knows the report is from a snapshot, not the live checkout.

### 10.3 pyroduct_gates

| Step | Description |
|------|-------------|
| 1 | Check `projectDir !== null` (gates require a checkout) |
| 2 | Run `moon check`, `moon fmt --check`, `moon test` sequentially |
| 3 | Collect exit codes and output tails |
| 4 | Return `textResult(gate_summary)` |

**Evidence**: `plugin/server.mjs:~240-280`. Gates are only available when `PYRODUCT_PROJECT_DIR` is set. The bundled snapshot is read-only and cannot run gates.

---

## 11. Error Handling

| Error | Source | Handling |
|-------|--------|----------|
| Missing JSON arg | `cmd/jsoncli` | `err_reply("missing request argument")` |
| JSON parse failure | `cmd/jsoncli` | `err_reply("bad request: ...")` |
| Unknown kind | `cmd/jsoncli` | `err_reply("unknown kind '...'")` |
| Spawn failure | `plugin/server.mjs` | Throw with exit code and stderr |
| Unparseable reply | `plugin/server.mjs` | Throw with partial output |
| `reply.ok === false` | `plugin/server.mjs` | Throw with `reply.error` |
| Timeout | `runProcess` | Abort with signal |

**Evidence**: Errors are caught at each layer and propagated as structured messages. The plugin throws on any failure, which the MCP client surfaces as `toolResult(error, true)`.

---

## 12. Provenance Tracking

| Field | Source | Purpose |
|-------|--------|---------|
| `source` | `resolveBridge()` | `'checkout'` / `'bundled'` / `'fallback'` |
| `warning` | `resolveBridge()` | Set when falling back to bundled |
| `faces` | `cmd/jsoncli` | Catalog snapshot for drift detection |
| `kind` | `cmd/jsoncli` | Echo request kind in reply |

**Evidence**: The reply envelope carries provenance metadata so the caller can verify which model version answered and whether the catalog has changed.

---

## 13. Key Invariants

1. **Plugin holds no model facts**: All facts come from model packages via `cmd/jsoncli`.
2. **Bridge is a pure formatter**: `cmd/jsoncli` only routes and formats; it does not compute.
3. **Face catalog is authoritative**: Both `cmd/jsoncli.faces()` and `plugin/server.mjs.FACES` must stay in sync (31 entries).
4. **Provenance is explicit**: Every reply carries `source` and `warning` so the reader knows which model answered.
5. **Gates require checkout**: The bundled snapshot cannot run gates; `pyroduct_gates` reports unavailability instead of failing.

---

## 14. Architecture Observations

1. **Two-layer bridge**: MiniMax Desktop → MCP server (Node.js) → jsoncli (Node.js, MoonBit-compiled) → model (MoonBit). The MCP server is a thin spawner; all semantics stay in MoonBit.
2. **Fallback resolution**: If the checkout is unavailable, the plugin falls back to a bundled snapshot. This ensures the plugin always works, but the reader must be told which model answered.
3. **Read-only tools**: All three MCP tools are marked `readOnly: true`, matching the project's discipline that the plugin never mutates model state.
4. **Version coupling**: `SERVER_VERSION` in `plugin/server.mjs` must match `version` in `plugin/.minimax-plugin/plugin.json`. A check enforces this.
5. **Build artifact**: `plugin/vendor/jsoncli.js` is a build artifact (gitignored). It is produced by `moon build --target js` and pinned by SHA-256 in `plugin/vendor/BUILD.json`.

---

## 15. Related Artifacts

- `architecture/flow-plugin-bridge.dot` — Complete flow diagram
- `architecture/flow-plugin-main-path.dot` — Simplified main path
- `architecture/system-model.dsl` — Container-level architecture model
- `architecture/system-model.evidence.md` — System model evidence index
- `AGENTS.md` — Plugin section (MiniMax Code plugin)

---

**Generated**: 2026-10-11
**Verified against**: plugin/server.mjs (full), cmd/jsoncli/main.mbt (full), plugin/.minimax-plugin/plugin.json (full)
