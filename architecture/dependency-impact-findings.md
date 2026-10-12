# Pyroduct Dependency Impact Analysis Findings

**Date**: 2026-10-11  
**Skill**: dependency-impact-analyzer + graphviz  
**Grain**: MoonBit package level  
**Scope**: Internal dependencies, change impact, risk assessment

---

## Executive Summary

Pyroduct 的依赖结构呈现清晰的**分层架构**，两个零 import 的基础包（`src` 和 `society`）是整个系统的稳定锚点。`src`（主体机）拥有最高的扇入（8个包依赖它），是最关键的稳定抽象；同时也是变更影响范围最大的包——任何对 `src` 的修改都会波及 11 个包中的 10 个。

**关键发现**：
- ✅ **无循环依赖**：依赖图是有向无环图（DAG）
- ✅ **依赖隔离规则执行良好**：第三方依赖严格限制在指定消费者
- ⚠️ **`src` 是单点风险**：高扇入（8）意味着变更影响范围广
- ✅ **`society` 是独立基础包**：零 import，可独立演进
- ⚠️ **`cmd/main` 和 `cmd/jsoncli` 是高扇出节点**：聚合所有包，但这是设计意图

---

## Dependency Metrics

### Fan-in / Fan-out Analysis

| Package | Fan-in | Fan-out | Role | Risk Level |
|---------|--------|---------|------|------------|
| `src` | **8** | 0 | 稳定抽象 | ⚠️ 高影响 |
| `society` | 3 | 0 | 稳定抽象 | ✅ 低风险 |
| `multi` | 4 | 1 | 中间层 | ✅ 中等 |
| `group` | 4 | 2 | 中间层 | ✅ 中等 |
| `ml` | 4 | 1 | 中间层 | ✅ 中等 |
| `evolution` | 2 | 4 | 高层 | ✅ 中等 |
| `coordinator` | 2 | 3 | 高层 | ✅ 中等 |
| `audit` | 2 | 3 | 工具层 | ✅ 低风险 |
| `viz` | 2 | 3 | 工具层 | ✅ 低风险 |
| `dmlref` | 1 | 1 | 工具层 | ✅ 低风险 |
| `causal` | 1 | 1 | 工具层 | ✅ 低风险 |
| `snnref` | 0 | 1 | 叶子节点 | ✅ 低风险 |
| `cmd/main` | 0 | **11** | 入口聚合 | ℹ️ 设计意图 |
| `cmd/jsoncli` | 0 | **8** | 入口聚合 | ℹ️ 设计意图 |
| `cmd/coord` | 0 | 1 | 入口 | ✅ 低风险 |
| `cmd/ifacescan` | 0 | 1 | 入口 | ✅ 低风险 |

**解读**：
- **高扇入（≥4）**：`src`, `multi`, `group`, `ml` 是核心抽象，修改需谨慎
- **高扇出（≥8）**：`cmd/main`, `cmd/jsoncli` 是聚合入口，高扇出是设计意图
- **零扇入**：`snnref` 是叶子节点，可独立修改
- **零扇出**：`src`, `society` 是基础包，不依赖其他内部包

---

## Cycle Detection

**结果**：✅ **无循环依赖**

依赖图是有向无环图（DAG），分层清晰：
```
Layer 0 (基础): src, society
Layer 1 (规范): multi → src
Layer 2 (群体): group → src, multi
Layer 3 (工具): ml → src
Layer 4 (智能体): evolution → src, multi, group, ml
Layer 5 (协调): coordinator → multi, ml, evolution
Layer 6 (入口): cmd/* → all
```

---

## Layer Violation Analysis

**结果**：✅ **无层违规**

依赖方向严格遵循自下而上的分层：
- 基础包（`src`, `society`）不依赖任何内部包
- 规范层（`multi`）只依赖基础层
- 群体层（`group`）依赖基础层 + 规范层
- 工具层（`ml`, `audit`, `viz`）依赖基础层 + 中间层
- 智能体层（`evolution`, `coordinator`）依赖下层所有层
- 入口层（`cmd/*`）聚合所有层

**依赖规则执行良好**：
- ✅ `src` 零 import（无第三方、无兄弟包）
- ✅ 第三方依赖隔离在指定消费者
- ✅ `ml` 不 import 数值库（仅 `core/math`）
- ✅ `audit`/`causal` 只读——不改判据

---

## Change Impact Analysis

### Scenario 1: `src` (主体机) 变更

**影响范围**：⚠️ **最大**

| Impact Level | Packages | Count |
|--------------|----------|-------|
| Direct (L1) | multi, group, ml, audit, snnref, viz, evolution | 7 |
| Indirect (L2) | coordinator, dmlref, causal | 3 |
| Indirect (L3) | cmd/coord, cmd/ifacescan | 2 |
| Entry Points | cmd/main, cmd/jsoncli | 2 |
| **Total Affected** | - | **14/15** |
| **No Impact** | society | 1 |

**传播路径**：
```
src (changed)
├─→ multi ──→ evolution ──→ coordinator ──→ cmd/coord
│           └─→ group ──→ evolution
│                     └─→ audit ──→ cmd/ifacescan
│                     └─→ viz
├─→ ml ──→ evolution
│        └─→ coordinator
│        └─→ dmlref
│        └─→ causal
├─→ audit ──→ cmd/ifacescan
├─→ snnref
├─→ viz
└─→ evolution ──→ coordinator
```

**风险**：
- ⚠️ 任何对 `src` 的公共 API 修改都需要更新 7 个直接依赖包
- ⚠️ 状态/迁移/阶段的变更会波及整个系统
- ✅ `society` 独立，不受影响

**缓解措施**：
- `src` 的公共 API 应视为**稳定契约**
- 变更需进行全量测试（`moon test`）
- 考虑使用版本化或弃用周期

---

### Scenario 2: `society` (社会机) 变更

**影响范围**：✅ **最小**

| Impact Level | Packages | Count |
|--------------|----------|-------|
| Direct (L1) | audit, viz | 2 |
| Indirect (L2) | cmd/main, cmd/jsoncli, cmd/ifacescan | 3 |
| **Total Affected** | - | **5/15** |
| **No Impact** | src, multi, group, ml, evolution, coordinator, dmlref, causal, snnref, cmd/coord, plugin | 10 |

**传播路径**：
```
society (changed)
├─→ audit ──→ cmd/ifacescan
│           └─→ cmd/main
│           └─→ cmd/jsoncli
└─→ viz ──→ cmd/main
          └─→ cmd/jsoncli
```

**风险**：
- ✅ `society` 是零 import 的基础包，变更影响有限
- ✅ 只影响审计和可视化层
- ✅ 不影响核心状态机家族（src/multi/group）

---

### Scenario 3: `ml` (自研 DoubleML) 变更

**影响范围**：✅ **中等**

| Impact Level | Packages | Count |
|--------------|----------|-------|
| Direct (L1) | evolution, dmlref, causal | 3 |
| Indirect (L2) | coordinator, cmd/main, cmd/jsoncli | 3 |
| **Total Affected** | - | **6/15** |
| **No Impact** | src, multi, group, society, audit, snnref, viz, cmd/coord, cmd/ifacescan, plugin | 9 |

**传播路径**：
```
ml (changed)
├─→ evolution ──→ coordinator ──→ cmd/main
│                               └─→ cmd/jsoncli
├─→ dmlref ──→ cmd/main
│            └─→ cmd/jsoncli
└─→ causal ──→ cmd/main
             └─→ cmd/jsoncli
```

**风险**：
- ✅ 影响范围可控
- ⚠️ 数值算法变更需验证 `dmlref` 交叉验证
- ⚠️ `causal` 依赖 `ml` 的内部实现

---

### Scenario 4: `evolution` (演化层) 变更

**影响范围**：✅ **中等**

| Impact Level | Packages | Count |
|--------------|----------|-------|
| Direct (L1) | coordinator | 1 |
| Indirect (L2) | cmd/main, cmd/jsoncli, cmd/coord | 3 |
| **Total Affected** | - | **4/15** |
| **No Impact** | src, multi, group, society, ml, dmlref, causal, audit, snnref, viz, cmd/ifacescan, plugin | 11 |

**传播路径**：
```
evolution (changed)
└─→ coordinator ──→ cmd/main
                  └─→ cmd/jsoncli
                  └─→ cmd/coord
```

**风险**：
- ✅ 影响范围有限
- ✅ 不影响底层状态机和工具层

---

## Risk Assessment

### High-Risk Nodes (需要谨慎变更)

| Node | Risk Factor | Reason | Mitigation |
|------|-------------|--------|------------|
| `src` | ⚠️⚠️⚠️ | Fan-in=8，变更影响 14/15 包 | 视为稳定契约；全量测试；版本化 API |
| `multi` | ⚠️⚠️ | Fan-in=4，变更影响 10+ 包 | 规范规则变更需审查所有消费者 |
| `group` | ⚠️⚠️ | Fan-in=4，变更影响 10+ 包 | 群体机变更需审查 evolution/audit/viz |
| `ml` | ⚠️⚠️ | Fan-in=4，数值算法敏感 | 变更需交叉验证（dmlref）；回归测试 |

### Low-Risk Nodes (可独立修改)

| Node | Risk Factor | Reason |
|------|-------------|--------|
| `society` | ✅ | Fan-in=3，零 import，独立基础包 |
| `snnref` | ✅ | Fan-in=0，叶子节点 |
| `dmlref` | ✅ | Fan-in=1，只被 cmd/main 使用 |
| `causal` | ✅ | Fan-in=1，只被 cmd/main 使用 |
| `cmd/coord` | ✅ | Fan-in=0，入口节点 |
| `cmd/ifacescan` | ✅ | Fan-in=0，入口节点 |

### Stable Abstractions (高扇入，零/低扇出)

| Node | Fan-in | Fan-out | Stability |
|------|--------|---------|-----------|
| `src` | 8 | 0 | ⚠️ 高影响但稳定 |
| `society` | 3 | 0 | ✅ 稳定抽象 |
| `multi` | 4 | 1 | ✅ 稳定抽象 |
| `ml` | 4 | 1 | ✅ 稳定抽象 |

---

## Dependency Governance Rules

### Current Rules (Enforced by Convention)

1. **`src` 零 import 规则**：
   - ✅ 不依赖任何第三方包
   - ✅ 不依赖任何兄弟包
   - 理由：主体机是核心抽象，必须保持独立

2. **第三方依赖隔离规则**：
   - ✅ `moonbitlang/async` → 仅 `cmd/coord`, `cmd/ifacescan`
   - ✅ `moonbit_doubleML` → 仅 `dmlref`, `causal`
   - ✅ `moonbit_snn_mbt` → 仅 `snnref`
   - ✅ `moonbit_static_analysis` → 仅 `audit`
   - 理由：防止第三方依赖污染核心包

3. **`ml` 自包含规则**：
   - ✅ 不 import 数值库（仅 `core/math`）
   - 理由：DoubleML 实现必须完全自包含

4. **只读审计规则**：
   - ✅ `audit`/`causal` 不改判据、不修表
   - 理由：审计层必须保持客观

### Recommended Rules (Not Yet Enforced)

1. **`src` API 版本化**：
   - 建议：为 `src` 的公共 API 引入版本标记
   - 理由：高扇入意味着变更成本高
   - 实施：在 doc comment 中标记 `@since` 版本

2. **变更影响检查**：
   - 建议：CI 中添加依赖影响分析
   - 理由：自动识别高风险变更
   - 实施：`git diff` → 映射到包 → 计算影响范围

3. **`society` 独立性保护**：
   - 建议：明确 `society` 的零 import 规则
   - 理由：当前是约定，未显式声明
   - 实施：在 `society/moon.pkg` 注释中声明

---

## Validation Steps

### For High-Risk Changes (`src`, `multi`, `group`, `ml`)

1. **运行全量测试**：
   ```bash
   moon test                    # 所有测试
   moon test --target native    # native 专属测试
   ```

2. **检查格式**：
   ```bash
   moon fmt --check
   ```

3. **验证依赖隔离**：
   - 检查 `moon.pkg` 文件的 import 块
   - 确认未引入新的第三方依赖

4. **运行审计**：
   ```bash
   moon run cmd/main -- audit   # 三鉴审计
   ```

5. **交叉验证（如修改 `ml`）**：
   ```bash
   moon run cmd/main -- dmlref  # 外部参考交叉验证
   ```

### For Low-Risk Changes (`snnref`, `dmlref`, `causal`, `viz`)

1. **运行相关测试**：
   ```bash
   moon test <package>
   ```

2. **检查格式**：
   ```bash
   moon fmt --check
   ```

---

## Artifacts

| File | Format | Purpose |
|------|--------|---------|
| `dependency-map.dot` | Graphviz DOT | 完整依赖图（扇入扇出标注） |
| `impact-analysis-src.dot` | Graphviz DOT | `src` 变更影响传播图 |
| `dependency-impact-findings.md` | Markdown | 本文档——发现、风险、规则 |

---

## Next Actions

1. **如需分析其他包的变更影响**：可创建类似的 impact-analysis 图
2. **如需深入理解调用流**：使用 `flow-visualizer` skill
3. **如需评估重构方案**：使用 `evolution-planner` skill
4. **如需架构健康检查**：使用 `architecture-health` skill

---

## Maintenance Note

本分析基于 2026-10-11 的代码状态。当以下情况发生时需更新：
- 新增/删除包
- 修改依赖关系
- 调整依赖隔离规则

**生成技能**：`dependency-impact-analyzer` + `graphviz`  
**证据来源**：`*/moon.pkg`, `moon.mod`, `AGENTS.md`
