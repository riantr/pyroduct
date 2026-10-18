# CLI Request Processing Flow - Evidence

**Date**: 2026-10-11  
**Skill**: flow-visualizer + graphviz  
**Scope**: CLI 请求处理流程（cmd/main 的参数解析与路由分发）

---

## Flow Summary

**触发**：`moon run cmd/main -- <subcommand>`

**主路径**：
1. 获取命令行参数：`@env.args()`
2. 提取子命令：`format = args[1] || "report"`
3. 路由分发：`match format` → 调用对应渲染函数
4. 输出结果：`println(result)`

**结果**：打印到 stdout

---

## Implementation Details

### Entry Point (入口)

**位置**：`cmd/main/main.mbt:40-96`  
**证据**：代码第 40 行

```moonbit
fn main raise {
  let args = @env.args()
  let format = if args.length() > 1 { args[1] } else { "report" }
  match format {
    // ... 36 个命名子命令 + 1 个默认分支
  }
}
```

**函数签名**：`fn main raise { ... }`  
**包类型**：`pkgtype(kind: "executable")`  
**支持目标**：`native+wasm+wasm-gc+js`

---

### Argument Parsing (参数解析)

**位置**：`cmd/main/main.mbt:41-42`  
**证据**：代码第 41-42 行

```moonbit
let args = @env.args()
let format = if args.length() > 1 { args[1] } else { "report" }
```

**逻辑**：
- `@env.args()` 返回命令行参数数组
- `args[0]` 是程序名
- `args[1]` 是第一个参数（子命令）
- 无参数时默认 `"report"`

**特点**：
- 只取 `args[1]`，忽略后续参数
- 无复杂参数解析（无 flags、无 options）
- 单参数路由

---

### Routing (路由分发)

**位置**：`cmd/main/main.mbt:43-95`  
**证据**：代码第 43-95 行

```moonbit
match format {
  "mermaid" => println(@sm.render_mermaid())
  "dot" => println(@sm.render_dot())
  // ... 36 个命名子命令
  _ => println(@sm.render_report())
}
```

**路由表**（36 个命名子命令）：

| 类别 | 子命令 | 渲染函数 | 包 |
|------|--------|----------|-----|
| **主体机** | report | `@sm.render_report()` | src |
| | mermaid | `@sm.render_mermaid()` | src |
| | dot | `@sm.render_dot()` | src |
| | genesis | `@sm.render_genesis()` | src |
| | course | `@sm.render_course()` | src |
| | naming | `@sm.render_naming_table()` | src |
| | slots | `@sm.render_slots()` | src |
| | loop | `@sm.render_loop_report()` | src |
| | principle | `@sm.revision_principle()` | src |
| | nested-mermaid | `@sm.render_mermaid_nested()` | src |
| | spec | `@sm.spec_json()` | src |
| **分析面** | pathsum | `@sm.render_pathsum_report()` | src |
| | algebra | `@sm.render_algebra_report()` | src |
| | petri | `@sm.render_petri_report()` | src |
| | aho | `@sm.render_aho_report()` | src |
| | buchi | `@sm.render_buchi_report()` | src |
| **多主体** | multi | `@multi.render_multi_report()` | multi |
| | group | `@group.render_group_report()` | group |
| | group-mermaid | `@group.render_mermaid()` | group |
| | society | `@society.render_report()` | society |
| | society-mermaid | `@society.render_mermaid()` | society |
| **演化层** | evolution | `@evolution.render_report()` | evolution |
| | cycle | `@evolution.render_cycle_report(@evolution.demo_cycle())` | evolution |
| | intuition | `@evolution.intuition_principle()` | evolution |
| | association | `@evolution.render_association_report()` | evolution |
| **ML/因果** | ml | `@ml.render_ml_report(@ml.default_ml_plan())` | ml |
| | ml-export | `@ml.csv_preview(@ml.make_dataset(200, 1.5, 7), 12)` | ml |
| | dmlref | `@dmlref.render_report()` | dmlref |
| | causal | `@causal.render_report()` | causal |
| **审计** | audit | `@audit.render_report()` | audit |
| | fleet | `@audit.render_fleet_report()` | audit |
| | mutants | `@audit.render_mutation_report()` | audit |
| | mbti | `@audit.render_iface_report(@audit.scan_snapshot())` | audit |
| **其他** | coordinator | `@coordinator.render_report()` | coordinator |
| | journey | `@viz.journey()` | viz |
| | viz | `@viz.page()` | viz |
| **组合** | all | 组合 report + course + genesis + mermaid | src |
| **默认** | _ | `@sm.render_report()` | src |

---

### Rendering Functions (渲染函数)

**调用模式**：`@pkg.render_xxx() -> String`

**特点**：
- 所有渲染函数返回 `String`
- 纯函数：无副作用，不修改全局状态
- 同步执行：无异步/流式输出
- 直接打印：`println(result)`

**示例**：
```moonbit
"mermaid" => println(@sm.render_mermaid())
"cycle" => println(@evolution.render_cycle_report(@evolution.demo_cycle()))
"ml" => println(@ml.render_ml_report(@ml.default_ml_plan()))
// ... 共 36 个命名分支
_ => println(@sm.render_report())  // "report" 与未知子命令均走此默认分支
```

**特殊案例**：
- `cycle`：先调用 `demo_cycle()` 生成示范循环，再渲染
- `ml`：先调用 `default_ml_plan()` 生成默认计划，再渲染
- `ml-export`：先调用 `make_dataset(200, 1.5, 7)` 生成数据集，再 `csv_preview(..., 12)` 导出前 12 行
- `all`：组合多个报告，用空行分隔

---

### Output (输出)

**位置**：`cmd/main/main.mbt` 各分支  
**证据**：每个分支都有 `println(...)`

**方式**：`println(result)`  
**目标**：stdout（标准输出）  
**格式**：纯文本（Markdown / Mermaid / DOT / JSON / CSV）

---

## Subcommand Categories (子命令类别)

### 1. Subject Machine (主体机) - 11 个

**包**：`src`  
**功能**：主体状态机的各种视图

| 子命令 | 视图类型 | 输出格式 |
|--------|----------|----------|
| report | 文字报告 | Markdown |
| mermaid | 状态图 | Mermaid |
| dot | 依赖图 | Graphviz DOT |
| genesis | 主线 | 原文顺序 |
| course | 历程 | 环节序列 |
| naming | 定名对照 | 表格 |
| slots | 驱动槽 | 对照表 |
| loop | 执行契约 | 位置×槽矩阵 |
| principle | 修订原则 | 文字说明 |
| nested-mermaid | 嵌套视图 | Mermaid（复合状态） |
| spec | 规格导出 | JSON |

---

### 2. Analysis Faces (分析面) - 5 个

**包**：`src`  
**功能**：主体机的不同理论镜像（模型整理）

| 子命令 | 理论镜像 | 来源 |
|--------|----------|------|
| pathsum | 泛半环路径和 | FiniteStateTransducers.jl |
| algebra | 机器代数 | Ragel |
| petri | Petri 网 | CarlAdam |
| aho | Aho-Corasick | pyahocorasick |
| buchi | ω-自动机 | Büchi |

---

### 3. Multi-Agent (多主体) - 5 个

**包**：`multi`, `group`, `society`  
**功能**：多主体规范、群体机、社会机

| 子命令 | 包 | 内容 |
|--------|-----|------|
| multi | multi | 规范规则 R1-R14 |
| group | group | 群体状态机 |
| group-mermaid | group | 群体机 Mermaid |
| society | society | 社会交往模型 |
| society-mermaid | society | 社会机 Mermaid |

---

### 4. Evolution (演化层) - 4 个

**包**：`evolution`  
**功能**：变异、闸门、账本、循环

| 子命令 | 内容 |
|--------|------|
| evolution | 演化层报告 |
| cycle | 主体循环（demo_cycle） |
| intuition | 直觉读法（备忘录→直觉） |
| association | 未定软关联（JPDA） |

---

### 5. ML & Causal (机器学习/因果) - 4 个

**包**：`ml`, `dmlref`, `causal`  
**功能**：DoubleML、交叉验证、因果诊断

| 子命令 | 包 | 内容 |
|--------|-----|------|
| ml | ml | DoubleML 接口 |
| ml-export | ml | 数据集导出 (CSV) |
| dmlref | dmlref | 外部参考对照 |
| causal | causal | 因果诊断（0.163.3深用） |

---

### 6. Audit (审计) - 4 个

**包**：`audit`  
**功能**：三鉴自审计

| 子命令 | 内容 |
|--------|------|
| audit | 主体机三鉴 |
| fleet | 群体机+社会机三鉴 |
| mutants | 变异网压力测试 |
| mbti | 接口面扫描（.mbti） |

---

### 7. Other (其他) - 3 个

**包**：`coordinator`, `viz`  
**功能**：协调器、可视化

| 子命令 | 包 | 内容 |
|--------|-----|------|
| coordinator | coordinator | 科研协调器 |
| journey | viz | 行程视图 |
| viz | viz | 三台机 HTML |

---

### 8. Composite (组合) - 1 个

**子命令**：`all`  
**内容**：组合 report + course + genesis + mermaid  
**用途**：一次性查看所有主体机视图

---

## Key Characteristics (关键特征)

### 1. 纯路由

**证据**：`cmd/main/main.mbt` 无业务逻辑  
**实现**：只做参数解析和函数调用  
**意义**：所有业务逻辑在下层包，CLI 层无状态

---

### 2. 单参数

**证据**：`args[1]` 只取第一个参数  
**实现**：忽略后续参数  
**意义**：简化命令行接口，无复杂参数解析

---

### 3. 同步输出

**证据**：`println(result)` 直接打印  
**实现**：无异步/流式  
**意义**：简单直接，适合报告生成

---

### 4. 无状态

**证据**：每次运行独立  
**实现**：无持久化（与 `cmd/coord` 不同）  
**意义**：幂等，可重复运行

---

### 5. 多目标

**证据**：`supported_targets = "native+wasm+wasm-gc+js"`  
**实现**：可编译为多种目标  
**意义**：跨平台运行

---

## Comparison with Other CLIs (与其他 CLI 对比)

| CLI | 目标 | 特点 | 持久化 |
|-----|------|------|--------|
| `cmd/main` | native+wasm+wasm-gc+js | 纯路由，36子命令 | 无 |
| `cmd/coord` | native only | 真实磁盘 IO，落盘 | 有（checkpoint） |
| `cmd/ifacescan` | native only | .mbti 扫描，磁盘 IO | 无 |
| `cmd/jsoncli` | js | JSON 桥接，MCP | 无 |

---

## Artifacts

| File | Format | Purpose |
|------|--------|---------|
| `flow-cli-request.dot` | Graphviz DOT | 完整 CLI 请求流程图（含所有子命令） |
| `flow-cli-main-path.dot` | Graphviz DOT | 主路径流程图（聚焦参数解析与路由） |
| `flow-cli-evidence.md` | Markdown | 本文档——逐步证据与代码引用 |

---

## Validation Steps

### 验证 CLI 行为

```bash
# 默认报告
moon run cmd/main

# 各子命令
moon run cmd/main -- report
moon run cmd/main -- mermaid
moon run cmd/main -- cycle
moon run cmd/main -- all

# 未知子命令（应回退到 report）
moon run cmd/main -- unknown
```

### 验证输出格式

```bash
# Mermaid 输出（应可渲染）
moon run cmd/main -- mermaid | head -20

# JSON 输出（应可解析）
moon run cmd/main -- spec | jq .

# CSV 输出（应可导入）
moon run cmd/main -- ml-export | head -5
```

---

## Maintenance Note

本文档基于 2026-10-11 的代码状态。当以下情况发生时需更新：
- 新增子命令
- 修改路由逻辑
- 改变参数解析方式
- 调整渲染函数签名

**生成技能**：`flow-visualizer` + `graphviz`  
**证据来源**：`cmd/main/main.mbt`, `cmd/main/moon.pkg`
