# Deployment Topology — Summary

> **Project**: riantr/pyroduct v0.1.29
> **Type**: Pure MoonBit library + local plugin (no cloud hosting, no containers, no microservices)
> **Date**: 2026-10-11

---

## Where the System Runs

pyroduct 是一个**纯库/插件项目**，运行在四个环境里：

### 1. 开发者工作站（本地）
- **工具链**：moon CLI (check/test/fmt/build/run) + Node.js (插件工具) + git (双远端)
- **构建目标**：wasm（注册中心制品）、js（插件桥）、native（本地工具/实验）
- **运行方式**：`moon run cmd/main`（36 面 CLI）、`moon run cmd/coord`（协调器落盘）、`node tools/face.mjs`（面运行器）

### 2. GitHub Actions（CI/CD）
- **gate.yml**：push/PR 触发，ubuntu-latest，跑完整门禁（check + fmt + test + build + 5 个 native 包）
- **publish.yml**：v* tag 触发，重跑门禁 + `moon publish` + `gh release create`
- **认证**：`MOONCAKES_RIANTR_TOKEN`（GitHub Secret，格式是 `~/.moon/credentials.json` 的完整内容）

### 3. mooncakes.io（包注册中心）
- **制品**：wasm artifact（`moon build --target wasm`）
- **消费者**：moonx、skills.mooncakes.io
- **发布**：`moon publish`（从 publish.yml 触发）

### 4. MiniMax Desktop（本地插件）
- **安装路径**：`~/.minimax/plugins/pyroduct-model/`
- **运行时**：MCP Server (Node.js stdio) → spawn jsoncli.js (Node.js, MoonBit 编译) → 调用模型包
- **桥路径**：优先 checkout（`PYRODUCT_PROJECT_DIR`），回落内置快照（`vendor/jsoncli.js`，SHA-256 钉住）
- **部署**：手动（`update-bundle.mjs` → `sync-install.mjs push` → validate）

---

## How Releases Move

```
commit → push gitee (日常) + github (CI)
              ↓
         gate.yml (push/PR)
              ↓
         门禁通过 ✓
              ↓
    git tag v0.1.29 → push github v0.1.29
              ↓
         publish.yml (v* tag)
              ↓
    重跑门禁 + moon publish + gh release create
              ↓
    mooncakes.io (wasm 制品) + GitHub Release
```

**插件部署**（独立于注册中心发布）：
```
moon build --target js → update-bundle.mjs → sync-install.mjs push → validate → 插件生效
```

---

## Key Evidence

| Item | Source | Confidence |
|------|--------|------------|
| 双远端（Gitee + GitHub） | `git remote -v`, `AGENTS.md` | high |
| gate.yml 跑 5 个 native 包 | `.github/workflows/gate.yml:92-126` | high |
| publish.yml 断言版本一致 | `.github/workflows/publish.yml:108-123` | high |
| moon publish 退出码不可信 | `publish.yml` header (lines 17-27), 实测 | high |
| 插件桥 SHA-256 钉住 | `plugin/vendor/BUILD.json`, `validate-plugin.mjs` | high |
| 插件部署是手动的 | `plugin/tools/*.mjs` 注释, `AGENTS.md` | high |
| 回落时标注警告 | `plugin/server.mjs:callTool()` | high |

---

## Top Risks

1. **双远端同步遗漏**（中）：标签只推一个远端等于没推。缓解：文档化纪律。
2. **插件部署纯手动**（中）：多步操作，容易遗漏。缓解：`update-bundle.mjs` 串成单命令 + `validate-plugin.mjs` 兜底。
3. **桥快照与活模型不一致**（低-中）：回落时加 `⚠` 警告，但读者可能忽略。
4. **native 包在 wasm 门禁下不可见**（低，已处理）：gate.yml 显式列出所有 5 个；新增必须同步加。

---

## Governance Rules

1. 双远端必须都推（Gitee 日常，GitHub CI）
2. 插件部署是手动的（`update-bundle.mjs` → `sync-install.mjs push` → validate）
3. 桥快照必须钉住（SHA-256 + bytes + version in BUILD.json）
4. 版本必须一致（moon.mod = tag；plugin.json = server.mjs SERVER_VERSION）
5. native 包必须显式列在 CI（gate.yml 命名所有 5 个）
6. moon publish 退出码不可信（断言 `Server status:` 行）
7. 回落必须标注（响应带 `⚠` 警告）

---

## Artifacts

| File | Purpose |
|------|---------|
| `architecture/deployment-topology.dot` | 完整部署拓扑图（Graphviz DOT） |
| `architecture/release-path.dot` | CI/CD 发布路径图（Graphviz DOT） |
| `architecture/runtime-evidence.md` | 证据索引（所有声明的源引用） |
| `architecture/deployment-risks.md` | 风险与缺口（7 风险 + 4 缺口 + 治理规则） |

---

## Validation Steps

```bash
# 检查双远端
git remote -v

# 本地模拟 CI
moon check --deny-warn && moon fmt --check && moon test --deny-warn

# 验证插件包
node plugin/tools/validate-plugin.mjs

# 检查 native 包计数
grep -c "native ·" .github/workflows/gate.yml  # 应返回 5

# 验证发布 token（dry run）
# Actions → publish → Run workflow (dry run default)
```

---

## What This Project Does NOT Have

- **云托管**：不是 SaaS，没有服务器
- **容器/编排**：没有 Dockerfile、docker-compose、Kubernetes
- **微服务拓扑**：纯库/插件，不是分布式系统
- **运行时监控**：本地插件，没有遥测
- **自动插件部署**：纯手动流程

These are not gaps — they are design choices. pyroduct is a library and local plugin, not a hosted service.

---

**Generated**: 2026-10-11
**Skill**: `architecture-visualization:deployment-topology-analyzer`
**Verified against**: `.github/workflows/*.yml`, `plugin/tools/*.mjs`, `plugin/vendor/BUILD.json`, `moon.mod`, `git remote -v`
