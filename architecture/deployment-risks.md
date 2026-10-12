# Deployment Topology — Risks & Gaps

> **Scope**: Operational risks, missing evidence, scaling gaps, release hazards
> **Date**: 2026-10-11
> **Status**: Current-state analysis based on CI/CD workflows, plugin tools, and project documentation

---

## Executive Summary

pyroduct 是一个**纯库/插件项目**，没有云托管、容器编排或微服务拓扑。它的部署拓扑围绕三个轴心：

1. **mooncakes.io 注册中心**（wasm 制品，自动发布）
2. **MiniMax Desktop 本地插件**（Node.js MCP server + JS bridge，手动部署）
3. **DeepSeek Harness 插件**（独立仓库，同一桥协议）

关键风险集中在**手动插件部署链**和**双远端同步纪律**上，而非基础设施复杂性。

---

## Risk 1: 双远端同步遗漏

**风险等级**: 中  
**影响**: 标签只推到 Gitee 不触发 CI；只推到 GitHub 则 Gitee 落后  
**描述**: 项目维护两个远端（Gitee 日常，GitHub CI）。`publish.yml` 只在 GitHub 的 `v*` tag 上触发。如果标签只推到 Gitee，发布不会发生；如果只推到 GitHub，Gitee 的日常提交历史会落后。  
**证据**: `AGENTS.md` "CI" 节："Both remotes must be pushed: gitee is the daily remote, github is where CI runs. A tag pushed to gitee alone triggers nothing."  
**缓解**: 文档化纪律（AGENTS.md）；无自动化同步。  
**验证步骤**: `git remote -v` 确认两个远端存在；`git log origin/master..github/master` 检查分歧。

---

## Risk 2: 插件部署是纯手动流程

**风险等级**: 中  
**影响**: 插件更新需要多步手动操作，容易遗漏或顺序错误  
**描述**: MiniMax 插件的部署链是：
1. `moon build --target js`（在 checkout 里）
2. `node tools/update-bundle.mjs <checkout>`（复制 + 钉 + 验证）
3. `node tools/sync-install.mjs push`（安装到 ~/.minimax）
4. MiniMax Desktop 重载（MCP server 需要重启才能加载新代码）

任何一步失败或跳过都会导致插件携带过时快照。  
**证据**: `plugin/tools/update-bundle.mjs` 注释（lines 7-18），`plugin/tools/sync-install.mjs` 注释（lines 9-19）。  
**缓解**: `update-bundle.mjs` 把构建-复制-钉-验证串成单命令；`sync-install.mjs push` 验证 SHA-256 钉后才安装；`validate-plugin.mjs` 跑 27+ 检查。  
**残余风险**: 没有 CI 自动触发插件重建；`plugin.json` 的 SemVer 需要手动提升（`update-bundle.mjs` 只提醒不代劳）。  
**验证步骤**: `node plugin/tools/validate-plugin.mjs` 应全绿。

---

## Risk 3: 桥快照与活模型不一致

**风险等级**: 低-中  
**影响**: 用户可能把内置快照的报告误认为活模型的最新输出  
**描述**: 插件有两路桥路径：checkout（活模型）和 bundled（内置快照）。如果 `PYRODUCT_PROJECT_DIR` 未设置或指向无效路径，插件回落到快照并在响应里加 `⚠` 警告。但警告是否足够醒目取决于读者。  
**证据**: `plugin/server.mjs:resolveBridge()` 返回 `{source, warning}`；`plugin/server.mjs:callTool()` 在 `pyroduct_face` 里把 warning  prepend 到报告前。  
**缓解**: 回落时在报告前加 `⚠ 以下是内置快照的 X 面：`；`pyroduct_faces` 目录页也标注来源。  
**残余风险**: 如果读者忽略 `⚠` 行，可能误判模型版本。  
**验证步骤**: 不设 `PYRODUCT_PROJECT_DIR`，调用 `pyroduct_face{kind: "report"}`，确认输出首行含 `⚠`。

---

## Risk 4: moon publish 退出码不可信

**风险等级**: 低（已测量并文档化）  
**影响**: 如果按退出码判断发布成功/失败，会误判  
**描述**: `moon publish` 的退出码在所有四种情况下都是 255（包括成功）。CI 用 `Server status:` 行判断，不用退出码。  
**证据**: `publish.yml` header comments (lines 17-27)；`publish.yml:189-201` 用 bash pattern match 而非 `grep -q`（避免 pipefail 下的 SIGPIPE 问题）。  
**缓解**: 已文档化并实测；CI 断言状态行而非退出码。  
**验证步骤**: `Actions → publish → Run workflow` (dry run) 验证 token 而不发布。

---

## Risk 5: native 包在 wasm 门禁下不可见

**风险等级**: 低（已显式处理）  
**影响**: 如果 gate.yml 只跑 wasm 测试，5 个 native 包的回归会被静默跳过  
**描述**: `snnref`、`tools/ifacescan`、`cmd/ifacescan`、`cmd/coord`、`examples/sediment` 都是 `+native`，wasm 目标跳过它们。`gate.yml` 显式列出每个 native 包的测试/运行命令。  
**证据**: `gate.yml:92-126` 注释解释为什么不能 blanket `moon test --target native`（会把 entrypoint 包当 test target 构建）；`AGENTS.md` "CI" 节。  
**缓解**: gate.yml 显式命名所有 5 个 native 包；注释警告"新增第六个 +native 包必须同步加到 CI"。  
**残余风险**: 如果新增 native 包但忘记加到 gate.yml，它的唯一执行就是某人的终端。  
**验证步骤**: `grep -c "native ·" .github/workflows/gate.yml` 应返回 5。

---

## Risk 6: plugin.json 与 server.mjs 版本不同步

**风险等级**: 低  
**影响**: 插件版本声明不一致，validate-plugin.mjs 会报错  
**描述**: `plugin/.minimax-plugin/plugin.json` 的 `version` 和 `plugin/server.mjs` 的 `SERVER_VERSION` 必须一致。`update-bundle.mjs` 提醒手动提升 plugin.json 版本，但不代劳；如果只改了 server.mjs 而忘了 plugin.json（或反之），validate 会失败。  
**证据**: `plugin/tools/validate-plugin.mjs:47-52` 检查两者一致；`plugin/tools/update-bundle.mjs:127-128` 打印提醒。  
**缓解**: validate-plugin.mjs 在每次刷新后跑，版本不一致会报错。  
**验证步骤**: `node plugin/tools/validate-plugin.mjs` 应通过 "plugin.json version = server.mjs version" 检查。

---

## Risk 7: MOONCAKES_RIANTR_TOKEN 格式错误

**风险等级**: 低（已实测并文档化）  
**影响**: `moon publish` 报 credentials 解析错误，发布失败  
**描述**: Secret 的值必须是 `~/.moon/credentials.json` 的**完整内容**（JSON 对象），不是裸 token。如果只复制了 token 字段，`moon publish` 会报 `failed to parse credentials file`。  
**证据**: `publish.yml` header comments (lines 11-16)；`publish.yml:169` 用 `printf '%s'` 写入文件。  
**缓解**: 已文档化；dry run 可以验证 token 而不发布。  
**验证步骤**: `Actions → publish → Run workflow` (dry run) → 检查输出含 `Server status: 200` 或 `202`。

---

## Gap 1: 无自动化插件回归

**描述**: `validate-plugin.mjs` 是手动跑的。没有 CI 在每次 push 后自动验证插件包。  
**影响**: 如果桥快照过时或不变量漂移，可能在发布后才发现。  
**建议**: 考虑在 gate.yml 里加一步 `node plugin/tools/validate-plugin.mjs`（需要 checkout + build js 先完成）。  
**优先级**: 中（当前有 publish.yml 的门禁重跑兜底，但不验证插件包本身）。

---

## Gap 2: 无 DSH 插件部署文档

**描述**: `riantr/dsh-plugin-pyroduct` 是独立仓库，AGENTS.md 只提到它存在，没有部署步骤。  
**影响**: 如果 DSH 插件需要更新桥，操作步骤不明。  
**建议**: 在 dsh-plugin-pyroduct 仓库里文档化桥更新流程，或在 pyroduct 的 AGENTS.md 里加一节。  
**优先级**: 低（DSH 插件可能不活跃维护）。

---

## Gap 3: 无运行时监控或遥测

**描述**: 插件是纯本地的，没有上报、日志聚合或错误追踪。  
**影响**: 如果插件在某用户环境失败，开发者无法主动发现。  
**建议**: 不适用——这是本地库/插件，不是 SaaS。用户通过 GitHub Issues 或 MiniMax 反馈报告问题。  
**优先级**: 无（设计如此）。

---

## Gap 4: 无容器化或云部署

**描述**: 项目没有 Dockerfile、docker-compose、Kubernetes manifest 或云配置。  
**影响**: 不适用——这是库/插件项目，不是服务。  
**建议**: 不需要。  
**优先级**: 无（设计如此）。

---

## Governance Rules (Observed)

1. **双远端必须都推**：Gitee 日常，GitHub CI。标签只推一个远端等于没推。
2. **插件部署是手动的**：`update-bundle.mjs` → `sync-install.mjs push` → validate。没有自动触发。
3. **桥快照必须钉住**：`vendor/BUILD.json` 记录 SHA-256 + bytes + version；`validate-plugin.mjs` 验证。
4. **版本必须一致**：`moon.mod` version = git tag = `plugin.json` version = `server.mjs` SERVER_VERSION（后两者是插件 SemVer，独立于模块版本）。
5. **native 包必须显式列在 CI**：gate.yml 命名所有 5 个；新增第六个必须同步加。
6. **moon publish 退出码不可信**：断言 `Server status:` 行，不是退出码。
7. **回落必须标注**：插件回落到内置快照时，响应必须带 `⚠` 警告。

---

## Validation Commands

```bash
# 检查双远端
git remote -v

# 检查门禁状态（本地模拟 CI）
moon check --deny-warn
moon fmt --check
moon test --deny-warn
moon test --target native snnref
moon test --target native tools/ifacescan

# 验证插件包
node plugin/tools/validate-plugin.mjs

# 验证桥钉
cat plugin/vendor/BUILD.json | jq '.bundleSha256, .version'

# 检查 native 包计数
grep -c "native ·" .github/workflows/gate.yml  # 应返回 5

# 验证发布 token（dry run）
# Actions → publish → Run workflow (dry run default)
```

---

## Related Artifacts

- `architecture/deployment-topology.dot` — Full deployment topology diagram
- `architecture/release-path.dot` — CI/CD release path diagram
- `architecture/runtime-evidence.md` — Evidence index
- `AGENTS.md` — Project guidance (CI, plugin sections)
- `.github/workflows/gate.yml` — CI gate workflow
- `.github/workflows/publish.yml` — Publish workflow

---

**Generated**: 2026-10-11
**Next review**: After next plugin version bump or CI workflow change
