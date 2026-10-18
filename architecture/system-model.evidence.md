# Pyroduct Architecture Evidence Index

**Date**: 2026-10-11  
**Skill**: system-modeler + c4model/graphviz  
**Scope**: Current-state architecture model

---

## Node Evidence

### State Machine Family

| Node ID | Label | Type | Confidence | Source Refs | Notes |
|---------|-------|------|------------|-------------|-------|
| `src` | 主体状态机 | module | high | `src/moon.pkg`, `src/*.mbt` | 34状态·53迁移·11阶段·8驱动槽；零import |
| `multi` | 多主体规范 | module | high | `multi/moon.pkg`, `multi/*.mbt` | R1-R14·5真理体制·4商谈类型·4有效性主张 |
| `group` | 群体状态机 | module | high | `group/moon.pkg`, `group/*.mbt` | 20状态·44迁移·9阶段；无驱动槽 |
| `society` | 社会状态机 | module | high | `society/moon.pkg`, `society/*.mbt` | 13状态·28迁移·8阶段；trigger-deterministic |

### Agent Layer

| Node ID | Label | Type | Confidence | Source Refs | Notes |
|---------|-------|------|------------|-------------|-------|
| `evolution` | 演化层 | module | high | `evolution/moon.pkg`, `evolution/*.mbt` | 变异/闸门/账本/遗传；依赖src/multi/group/ml |
| `coordinator` | 科研协调器 | module | high | `coordinator/moon.pkg`, `coordinator/*.mbt` | 任务/制品/规划/证据/记忆/署名/运行时 |

### Analysis & Tools

| Node ID | Label | Type | Confidence | Source Refs | Notes |
|---------|-------|------|------------|-------------|-------|
| `ml` | 自研DoubleML | module | high | `ml/moon.pkg`, `ml/*.mbt` | PLR/交叉拟合/正交分数；完全自包含 |
| `dmlref` | 外部交叉验证 | module | high | `dmlref/moon.pkg` | 与moonbit_doubleML@0.163.3互校 |
| `causal` | 因果诊断 | module | high | `causal/moon.pkg` | 敏感性/多重检验/异质性；只读 |
| `audit` | 三鉴审计 | module | high | `audit/moon.pkg` | 结构鉴/类型鉴/行为鉴；参考消费者 |
| `snnref` | 脉冲沉淀实验 | module | high | `snnref/moon.pkg` | native only；49触发→泊松→STDP |
| `viz` | 可视化 | module | high | `viz/moon.pkg` | Mermaid/HTML；三台机+嵌套视图 |

### CLI Entry Points

| Node ID | Label | Type | Confidence | Source Refs | Notes |
|---------|-------|------|------------|-------------|-------|
| `cmd/main` | WASM CLI | executable | high | `cmd/main/moon.pkg` | 36子命令；native+wasm+wasm-gc+js |
| `cmd/coord` | Native CLI | executable | high | `cmd/coord/moon.pkg` | 真实磁盘IO；native only |
| `cmd/ifacescan` | .mbti扫描 | executable | high | `cmd/ifacescan/moon.pkg` | 漂移绊线；native only |
| `cmd/jsoncli` | JSON桥接 | executable | high | `cmd/jsoncli/moon.pkg` | 31 face；js target |

### Plugin

| Node ID | Label | Type | Confidence | Source Refs | Notes |
|---------|-------|------|------------|-------------|-------|
| `plugin` | MiniMax插件 | component | high | `plugin/.minimax-plugin/plugin.json`, `plugin/server.mjs` | MCP server；源码在plugin/ |

### External Systems

| Node ID | Label | Type | Confidence | Source Refs | Notes |
|---------|-------|------|------------|-------------|-------|
| `moonbitlang/core` | 官方标准库 | external | high | `moon.mod` | 所有包可用 |
| `moonbitlang/async@0.22.5` | 异步库 | external | high | `moon.mod` | 仅cmd/coord, tools/ifacescan, cmd/ifacescan |
| `riantr/moonbit_doubleML@0.163.3` | 外部DoubleML | external | high | `moon.mod` | 仅dmlref, causal |
| `riantr/snn_mbt@0.155.0` | 脉冲神经网络 | external | high | `moon.mod` | 仅snnref；native only |
| `riantr/moonbit_static_analysis@0.4.29` | 静态分析库 | external | high | `moon.mod` | 仅audit |
| `MiniMax Code Desktop` | 插件宿主 | external | high | `AGENTS.md` | 加载本地插件 |

---

## Edge Evidence

### Internal Dependencies

| Edge ID | From | To | Type | Confidence | Source Refs | Notes |
|---------|------|----|------|------------|-------------|-------|
| `e-multi-src` | multi | src | depends-on | high | `multi/moon.pkg` | @sm别名 |
| `e-group-src` | group | src | depends-on | high | `group/moon.pkg` | @sm别名 |
| `e-group-multi` | group | multi | depends-on | high | `group/moon.pkg` | 引用规范规则 |
| `e-society-none` | society | (none) | - | high | `society/moon.pkg` | 零import——基础包 |
| `e-ml-src` | ml | src | depends-on | high | `ml/moon.pkg` | @sm别名 |
| `e-evolution-src` | evolution | src | depends-on | high | `evolution/moon.pkg` | @sm别名 |
| `e-evolution-multi` | evolution | multi | depends-on | high | `evolution/moon.pkg` | 行为规则 |
| `e-evolution-group` | evolution | group | depends-on | high | `evolution/moon.pkg` | @g别名；Open裁决 |
| `e-evolution-ml` | evolution | ml | depends-on | high | `evolution/moon.pkg` | DoubleML闸门 |
| `e-coord-multi` | coordinator | multi | depends-on | high | `coordinator/moon.pkg` | - |
| `e-coord-ml` | coordinator | ml | depends-on | high | `coordinator/moon.pkg` | - |
| `e-coord-evolution` | coordinator | evolution | depends-on | high | `coordinator/moon.pkg` | - |
| `e-dmlref-ml` | dmlref | ml | depends-on | high | `dmlref/*.mbt` | 交叉验证 |
| `e-causal-ml` | causal | ml | depends-on | high | `causal/*.mbt` | - |
| `e-audit-src` | audit | src | depends-on | high | `audit/moon.pkg` | @sm别名 |
| `e-audit-group` | audit | group | depends-on | high | `audit/moon.pkg` | @g别名 |
| `e-audit-society` | audit | society | depends-on | high | `audit/moon.pkg` | @so别名 |
| `e-snnref-src` | snnref | src | depends-on | high | `snnref/*.mbt` | - |
| `e-viz-src` | viz | src | depends-on | high | `viz/moon.pkg` | @sm别名 |
| `e-viz-group` | viz | group | depends-on | high | `viz/moon.pkg` | - |
| `e-viz-society` | viz | society | depends-on | high | `viz/moon.pkg` | - |

### External Dependencies

| Edge ID | From | To | Type | Confidence | Source Refs | Notes |
|---------|------|----|------|------------|-------------|-------|
| `e-src-core` | src | moonbitlang/core | depends-on | high | `moon.mod` | 官方标准库 |
| `e-cmdcoord-async` | cmd/coord | moonbitlang/async | depends-on | high | `cmd/coord/moon.pkg` | native磁盘IO |
| `e-cmdifacescan-async` | cmd/ifacescan | moonbitlang/async | depends-on | high | `cmd/ifacescan/moon.pkg` | - |
| `e-dmlref-doubleml` | dmlref | riantr/moonbit_doubleML | depends-on | high | `dmlref/*.mbt` | 外部参考 |
| `e-causal-doubleml` | causal | riantr/moonbit_doubleML | depends-on | high | `causal/*.mbt` | 0.163.3深用 |
| `e-snnref-snn` | snnref | riantr/snn_mbt | depends-on | high | `snnref/*.mbt` | native only |
| `e-audit-sa` | audit | riantr/moonbit_static_analysis | depends-on | high | `audit/moon.pkg` | 三鉴库 |

### Actor Relationships

| Edge ID | From | To | Type | Confidence | Notes |
|---------|------|----|------|------------|-------|
| `e-researcher-cli` | 研究者 | cmd/main | uses | high | 运行CLI命令 |
| `e-developer-jsoncli` | Agent开发者 | cmd/jsoncli | uses | high | JSON-RPC/MCP |
| `e-minimax-plugin` | MiniMax Desktop | plugin | loads | high | 加载本地插件 |
| `e-plugin-jsoncli` | plugin | cmd/jsoncli | calls | high | MCP桥接 |

---

## Assumptions & Unknowns

### Confirmed Architecture

- **状态机家族**：src/multi/group/society 四个包构成核心状态机族，依赖关系清晰
  - `src` 和 `society` 都是零 import 的基础包
  - `multi` 依赖 `src`
  - `group` 依赖 `src` + `multi`
- **智能体层**：evolution 依赖 src/multi/group/ml；coordinator 依赖 multi/ml/evolution
- **分析工具层**：ml 依赖 src；viz 依赖 src/group/society
- **依赖隔离**：第三方依赖严格限制在指定消费者——async→cmd/coord+ifacescan；doubleML→dmlref+causal；snn→snnref；static_analysis→audit
- **CLI 入口**：cmd/main 聚合所有包；cmd/coord/cmd/ifacescan 是 native-only；cmd/jsoncli 是 js target
- **插件架构**：plugin/ 是源码，安装副本在 Desktop 数据目录；通过 cmd/jsoncli 桥接

### Validation Tasks

- [x] 确认 `multi` 是否 import `src` → ✅ 确认（@sm别名）
- [x] 确认 `group` 是否 import `src`/`multi` → ✅ 确认（@sm + multi）
- [x] 确认 `society` 的依赖 → ✅ 确认（零import，基础包）
- [x] 确认 `ml` 的依赖 → ✅ 确认（src + core/math）
- [x] 确认 `viz` 的依赖 → ✅ 确认（src + group + society）

---

## Evidence Sources

| Source | Type | Coverage |
|--------|------|----------|
| `AGENTS.md` | document | 项目约定、命令、布局、依赖规则 |
| `README.mbt.md` | document | 功能特性、术语、快速开始 |
| `moon.mod` | config | 模块定义、版本、依赖声明 |
| `*/moon.pkg` | config | 包级依赖、目标平台、格式化规则 |
| `src/*.mbt` | code | 主体状态机实现 |
| `evolution/*.mbt` | code | 演化层实现 |
| `coordinator/*.mbt` | code | 协调器实现 |
