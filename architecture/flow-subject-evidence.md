# Subject State Machine Execution Flow - Evidence

**Date**: 2026-10-11  
**Skill**: flow-visualizer + graphviz  
**Scope**: 主体状态机执行流程（step 函数的调用链与回执判定）

---

## Flow Summary

**触发**：用户调用 `step(state, slot)` 或 `step_by_trigger(state, trigger)`

**主路径**：
1. 调用 `candidates(state, slot)` 收集候选边
2. 判定候选数量 → 决定回执类型
3. 返回 `Outcome`（Moved/Held/Open/Same/Block）

**结果**：五种回执之一，每种都有明确的语义约束

---

## Step-by-Step Walkthrough

### Step 1: Entry Point (入口)

**函数**：`step(state : SubjectState, slot : Slot) -> Outcome`  
**位置**：`src/loop.mbt:138-169`  
**证据**：代码第 138 行

```moonbit
pub fn step(state : SubjectState, slot : Slot) -> Outcome {
  let cands = candidates(state, slot)
  // ...
}
```

**替代入口**：`step_by_trigger(state, trigger)` (`src/loop.mbt:211-219`)  
- 触发粒度执行，直接查询特定触发
- 前提：同一位置的同一触发不出现两次（`one_edge_per_trigger` 锁住）

---

### Step 2: Collect Candidates (收集候选)

**函数**：`candidates(state : SubjectState, slot : Slot) -> Array[(Trigger, SubjectState)]`  
**位置**：`src/loop.mbt:77-88`  
**证据**：代码第 77-88 行

```moonbit
pub fn candidates(
  state : SubjectState,
  slot : Slot,
) -> Array[(Trigger, SubjectState)] {
  let out : Array[(Trigger, SubjectState)] = []
  for t in transitions() {
    if t.from == state && t.trigger.slot() == slot {
      out.push((t.trigger, t.to))
    }
  }
  out
}
```

**数据源**：`transitions()` 返回 53 条迁移边  
**过滤条件**：
- `t.from == state`：从当前状态出发
- `t.trigger.slot() == slot`：触发属于指定槽

**关键约束**：这是"此处此槽可能发生什么"的**唯一**取料处（`src/loop.mbt:71-76` 注释）

---

### Step 3: Check Empty (检查空候选)

**位置**：`src/loop.mbt:140-144`  
**证据**：代码第 140-144 行

```moonbit
if cands.length() == 0 {
  return Block(
    "\{state.designation()} 处没有「\{slot.designation()}」的出边",
  )
}
```

**回执**：`Block(msg)`  
**语义**：此槽在此位置无路可走  
**约束**：不许编造下一步（`src/loop.mbt:9-10` 注释）

**统计**：272 个 (位置×槽) 组合中，228 个是 Block（`src/loop.mbt:687`）

---

### Step 4: Count Targets (计算目标数)

**位置**：`src/loop.mbt:145-150`  
**证据**：代码第 145-150 行

```moonbit
let targets : Array[SubjectState] = []
for entry in cands {
  if !contains_state(targets, entry.1) {
    targets.push(entry.1)
  }
}
```

**目的**：统计不同的目标状态数量  
**用途**：区分 Open（多目标）vs Same/Moved/Held（单目标）

---

### Step 5: Check Multiple Targets (检查多目标)

**位置**：`src/loop.mbt:152-154`  
**证据**：代码第 152-154 行

```moonbit
if targets.length() > 1 {
  return Open(cands)
}
```

**回执**：`Open(candidates)`  
**语义**：多条去处并存，未定  
**约束**：不替主体决断（`src/loop.mbt:11-12` 注释）

**示例**：自由 (Freedom) × 处境 (Occasion) → 紧迫 (Urgency) 或 疏离 (Alienation)

---

### Step 6: Check Multiple Candidates (检查多候选)

**位置**：`src/loop.mbt:155-163`  
**证据**：代码第 155-163 行

```moonbit
if cands.length() > 1 {
  // 同归：多条不同的触发句归到同一个目标
  let named : Array[Trigger] = []
  for entry in cands {
    named.push(entry.0)
  }
  return Same(slot, named, first.1)
}
```

**回执**：`Same(slot, triggers, to)`  
**语义**：多条触发归到同一目标，去处确定，来处不名  
**约束**：不编造上一步（`src/loop.mbt:156-157` 注释）

**示例**：无忆 (NoPast) × 处境 (Occasion) → 立位 (Standing)  
- 多条触发（TakeStand, FeelFinitude, FeelBoundlessness）都到立位
- 槽粒度认不出是哪一句，故不点名

---

### Step 7: Check Self-Loop (检查自环)

**位置**：`src/loop.mbt:164-168`  
**证据**：代码第 164-168 行

```moonbit
if first.1 == state {
  Held(first.0, state)
} else {
  Moved(first.0, first.1)
}
```

**回执**：
- `Held(trigger, state)`：出路回到自身（自环）
- `Moved(trigger, to)`：唯一出路，迁到新位置

**统计**：17 条自环（`src/loop.mbt:14` 注释）

---

## Outcome Usage (回执使用)

### landing() - 读回落点

**位置**：`src/loop.mbt:60-68`  
**证据**：代码第 60-68 行

```moonbit
pub fn Outcome::landing(self : Outcome) -> SubjectState? {
  match self {
    Moved(_, to) => Some(to)
    Held(_, s) => Some(s)
    Open(_) => None
    Same(_, _, to) => Some(to)
    Block(_) => None
  }
}
```

**用途**：`walk` 和 `expand` 用来更新当前位置

---

### forks_from() - 展开为确定走法

**位置**：`src/loop.mbt:103-119`  
**证据**：代码第 103-119 行

```moonbit
pub fn Outcome::forks_from(self : Outcome, at : SubjectState) -> Array[Outcome] {
  let out : Array[Outcome] = []
  match self {
    Moved(tr, to) => out.push(Moved(tr, to))
    Held(tr, s) => out.push(Held(tr, s))
    Open(cands) =>
      for c in cands {
        out.push(resolved(c.0, c.1, at))
      }
    Same(_, named, to) =>
      for tr in named {
        out.push(resolved(tr, to, at))
      }
    Block(_) => ()
  }
  out
}
```

**用途**：`expand` 在 Open 处分叉时调用  
**约束**：不引入新事实——每个分支都是迁移表里真实存在的边

---

### walk() - 按槽序列走一段

**位置**：`src/loop.mbt:326-338`  
**证据**：代码第 326-338 行

```moonbit
pub fn walk(start : SubjectState, slots : Array[Slot]) -> Trace {
  let mut at = start
  let steps : Array[(Slot, Outcome)] = []
  for s in slots {
    let out = step(at, s)
    steps.push((s, out))
    match out.landing() {
      Some(next) => at = next
      None => ()
    }
  }
  { start, steps, }
}
```

**行为**：
- 遇到 Open → 停在原处（Open 无落点）
- 遇到 Block → 停在原处（Block 无落点）
- 遇到 Moved/Held/Same → 更新位置

---

### expand() - 展开所有可能

**位置**：`src/loop.mbt:432-439`  
**证据**：代码第 432-439 行

```moonbit
pub fn expand(
  start : SubjectState,
  slots : Array[Slot],
  limit : Int,
) -> Expansion {
  let (leaves, truncated) = expand_from(start, start, [], slots, 0, limit)
  { leaves, truncated, }
}
```

**行为**：
- 遇到 Open → 按候选分叉（`src/loop.mbt:461-487`）
- 遇到 Block → 不终止，继续下一个槽（`src/loop.mbt:494-497`）
- 遇到 Same → 单线继续（`src/loop.mbt:490-499`）

**约束**：
- 只在 Open 处分叉（`src/loop.mbt:422-424`）
- 分叉不增事实（`src/loop.mbt:428-429`）
- 上界要说出来（`src/loop.mbt:430-431`）

---

## Key Invariants (关键不变量)

### 1. 不编造下一步

**证据**：`src/loop.mbt:9-10`  
**实现**：Block 是一等回执，无路时返回 Block 而不是猜测

### 2. 不编造上一步

**证据**：`src/loop.mbt:156-157`  
**实现**：Same 回执不点名触发，只给槽与目标

### 3. 不替主体决断

**证据**：`src/loop.mbt:11-12`  
**实现**：Open 回执返回全部候选，不择其一

### 4. 候选唯一取料处

**证据**：`src/loop.mbt:71-76`  
**实现**：`candidates` 是 `step`、`expand`、`after_open` 的唯一数据源

---

## Data Sources (数据源)

### transitions()

**位置**：`src/subject.mbt`（未读取完整文件）  
**内容**：53 条迁移边  
**结构**：`Transition { from: SubjectState, trigger: Trigger, to: SubjectState }`

### Trigger::slot()

**位置**：`src/slot.mbt`  
**内容**：49 个触发 → 8 个槽的映射  
**约束**：穷尽匹配（编译器检查缺臂）

---

## Artifacts

| File | Format | Purpose |
|------|--------|---------|
| `flow-subject-execution.dot` | Graphviz DOT | 完整执行流程图（含所有函数调用） |
| `flow-subject-main-path.dot` | Graphviz DOT | 主路径流程图（聚焦 step 判定逻辑） |
| `flow-subject-evidence.md` | Markdown | 本文档——逐步证据与代码引用 |

---

## Validation Steps

### 验证 step() 行为

```bash
moon run cmd/main -- report    # 查看执行契约报告
moon run cmd/main -- slots     # 查看驱动槽分布
moon run cmd/main -- loop      # 查看位置×槽的执行契约
```

### 验证不变量

```bash
moon test src                  # 运行主体机测试
# 测试覆盖：
# - one_edge_per_trigger()：同一位置的同一触发不出现两次
# - gaps()：228 个 Block 组合
# - open_points()：未定点清单
# - same_target_pairs()：同归组合清单
```

---

## Maintenance Note

本流程文档基于 2026-10-11 的代码状态。当以下情况发生时需更新：
- 修改 `step` 函数的判定逻辑
- 新增回执类型
- 改变 `candidates` 的过滤条件
- 调整 `expand` 的分叉策略

**生成技能**：`flow-visualizer` + `graphviz`  
**证据来源**：`src/loop.mbt`, `src/subject.mbt`, `src/slot.mbt`
