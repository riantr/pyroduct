# Pyroduct Architecture Summary

**Date**: 2026-10-11  
**Skill**: system-modeler + c4model/graphviz  
**Version**: 0.1.29

---

## Architecture Overview

Pyroduct 是一个纯 MoonBit 模块，把两部中国哲学文本建模为可运行、可测试的状态机族，加上演化层和科研协调器。

### System Boundary

```
┌─────────────────────────────────────────────────────────────┐
│                     Pyroduct Module                          │
│  riantr/pyroduct@0.1.29                                      │
│  https://gitee.com/ren-yongxiang/pyroduct.git               │
├─────────────────────────────────────────────────────────────┤
│  状态机家族    │  智能体层    │  分析工具    │  CLI/插件     │
│  src           │  evolution   │  ml          │  cmd/main     │
│  multi         │  coordinator │  dmlref      │  cmd/coord    │
│  group         │              │  causal      │  cmd/ifacescan│
│  society       │              │  audit       │  cmd/jsoncli  │
│                │              │  snnref      │  plugin/      │
│                │              │  viz         │               │
└─────────────────────────────────────────────────────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
   moonbitlang/*   moonbitlang/*  moonbit_doubleML  MiniMax Desktop
                                  moonbit_snn
                                  moonbit_static_analysis
```

---

## Key Containers

### 1. State Machine Family (核心)

四个包构成状态机族，共享类型词汇表，三个尺度：

| Package | Scale | States | Transitions | Phases | Drive Slots | Imports |
|---------|-------|--------|-------------|--------|-------------|---------|
| `src` | 主体 | 34 | 53 | 11 | 8 | 零import |
| `multi` | 规范 | - | - | - | R1-R14 rules | src |
| `group` | 群体 | 20 | 44 | 9 | 0 (trigger-driven) | src, multi |
| `society` | 社会 | 13 | 28 | 8 | 0 (trigger-deterministic) | 零import |

**关键约束**：
- `src` 和 `society` 都是零 import 的基础包
- `multi` 依赖 `src`；`group` 依赖 `src` + `multi`
- `group`/`society` 无驱动槽——触发即驱动
- 所有状态/阶段名严格两字符

### 2. Agent Layer (智能体层)

**evolution**：变异空间 / 适应度 / 闸门 / 只追加账本 / 遗传
- 依赖：`src` (位置×驱动槽), `multi` (行为规则), `group` (Open裁决), `ml` (DoubleML闸门)
- 主体循环 `run_cycle` 把驱动槽接到真迁移表，修习与开放候选都过同一个闸门

**coordinator**：任务 / 制品 / 规划 / 外部证据 / 内容记忆 / 署名 / 可重放运行时
- 依赖：`multi`, `ml`, `evolution`
- 商谈段/决策段分离；运行时可落盘、往返一致

### 3. Analysis & Tools (分析工具)

| Package | Purpose | Imports | External Dependency |
|---------|---------|---------|---------------------|
| `ml` | 自研 DoubleML (PLR/交叉拟合/正交分数) | src, core/math | 无——完全自包含 |
| `dmlref` | 与 `moonbit_doubleML@0.75.0` 互校 | ml | `riantr/moonbit_doubleML` |
| `causal` | 敏感性/多重检验/异质性 (0.75.0深用) | ml | `riantr/moonbit_doubleML` |
| `audit` | 三鉴自审计 (结构/类型/行为) | src, group, society | `riantr/moonbit_static_analysis@0.3.4` |
| `snnref` | 脉冲沉淀实验 (native only) | src | `riantr/snn_mbt@0.84.0` |
| `viz` | Mermaid/HTML 可视化 | src, group, society | 无 |

**依赖隔离规则**：
- 每个第三方依赖严格限制在指定消费者
- `ml` 永不 import 数值库（仅 core/math）
- `audit`/`causal` 只读——不改判据、不修表

### 4. CLI Entry Points (命令行入口)

| Executable | Target | Purpose |
|------------|--------|---------|
| `cmd/main` | native+wasm+wasm-gc+js | 36 命名子命令 (report/slots/multi/group/...) |
| `cmd/coord` | native only | 科研协调器——真实磁盘 IO——往返一致 |
| `cmd/ifacescan` | native only | `.mbti` 漂移绊线——扫每个真实 `pkg.generated.mbti` |
| `cmd/jsoncli` | js | JSON 桥接——DeepSeek Harness 插件 + MiniMax 插件 (31 face) |

### 5. Plugin (MiniMax 插件)

- **源码**：`plugin/` (`.minimax-plugin/plugin.json` + `server.mjs` + `pyroduct-model` skill)
- **安装副本**：`~/.minimax/plugins/pyroduct-model/`
- **桥接**：通过 `cmd/jsoncli` (MCP → JSON-RPC → JSON 响应)
- **约束**：插件不持有任何模型事实——所有事实来自模块

---

## Key Relationships

### Dependency Flow

```
              ┌─────────┐              ┌─────────┐
              │   src   │ ← 零import   │ society │ ← 零import
              └────┬────┘              └────┬────┘
                   │                        │
         ┌─────────┼─────────┐              │
         │         │         │              │
         ▼         ▼         ▼              │
    ┌─────────┐ ┌─────┐ ┌───────┐          │
    │  multi  │ │ ml  │ │ snnref│          │
    └────┬────┘ └──┬──┘ └───────┘          │
         │         │                        │
         │    ┌────┼────┐                   │
         │    │    │    │                   │
         │    ▼    ▼    ▼                   │
         │ ┌──────┐ ┌────────┐ ┌─────────┐ │
         │ │dmlref│ │ causal │ │  audit  │◄┘
         │ └──────┘ └────────┘ └─────────┘
         │
         ▼
    ┌─────────┐
    │  group  │ ← src + multi
    └────┬────┘
         │
         ├─────────────┐
         │             │
         ▼             ▼
    ┌───────────┐ ┌─────────┐
    │ evolution │ │   viz   │ ← src + group + society
    └─────┬─────┘ └─────────┘
          │
          │ ← src + multi + group + ml
          ▼
   ┌─────────────┐
   │ coordinator │ ← multi + ml + evolution
   └──────┬──────┘
          │
   ┌──────┼──────┐
   │      │      │
   ▼      ▼      ▼
cmd/main cmd/coord cmd/jsoncli
```

### Third-Party Isolation

```
第三方库                    消费者
─────────────────────────────────────────
moonbitlang/async      →   cmd/coord, cmd/ifacescan
moonbit_doubleML       →   dmlref, causal
moonbit_snn_mbt        →   snnref
moonbit_static_analysis→   audit
─────────────────────────────────────────
其余所有包              →   仅 moonbitlang/*
```

---

## Evidence Strength

### High Confidence (直接证据)

- ✅ 所有包结构和依赖关系 (来自 `moon.pkg` 文件)
- ✅ 第三方依赖隔离 (来自 `moon.mod` + `AGENTS.md`)
- ✅ CLI 入口和目标平台 (来自 `cmd/*/moon.pkg`)
- ✅ 插件架构 (来自 `plugin/` + `AGENTS.md`)
- ✅ 状态机规模和约束 (来自 `README.mbt.md` + `AGENTS.md`)
- ✅ `src` 和 `society` 是零 import 的基础包
- ✅ `ml` 依赖 `src` + `core/math`
- ✅ `viz` 依赖 `src` + `group` + `society`

### Unknowns (已验证)

- [x] `multi` import `src` (@sm)
- [x] `group` import `src` (@sm) + `multi`
- [x] `society` 零 import
- [x] `ml` import `src` (@sm) + `core/math`
- [x] `viz` import `src` (@sm) + `group` + `society`

---

## Artifacts

| File | Format | Purpose |
|------|--------|---------|
| `system-context.dsl` | Structurizr DSL | 系统上下文图——参与者、外部系统、主要关系 |
| `system-model.dsl` | Structurizr DSL | 容器级系统模型——内部模块、依赖、边界 |
| `module-dependencies.dot` | Graphviz DOT | 模块依赖图——密集关系可视化 |
| `system-model.evidence.md` | Markdown | 证据索引——节点、边、置信度、来源 |
| `system-model.summary.md` | Markdown | 本文档——可读解释、关键关系、验证缺口 |

---

## Next Actions

1. **验证未知项**：读取 `multi`/`group`/`society`/`snnref`/`viz` 的 moon.pkg 文件确认依赖
2. **深入分析**：如需理解数据流或调用流，使用 `flow-visualizer` skill
3. **依赖影响分析**：如需评估变更影响，使用 `dependency-impact-analyzer` skill
4. **架构健康检查**：如需验证图表与代码一致性，使用 `architecture-health` skill
5. **风险评审**：如需识别技术债或风险，使用 `risk-quality-reviewer` skill

---

## Maintenance Note

本架构模型基于 2026-10-11 的代码状态。当以下情况发生时需更新：
- 新增/删除包
- 修改依赖关系
- 改变目标平台
- 调整依赖隔离规则

**生成技能**：`system-modeler` + `c4model` + `graphviz`  
**证据来源**：`AGENTS.md`, `README.mbt.md`, `moon.mod`, `*/moon.pkg`
