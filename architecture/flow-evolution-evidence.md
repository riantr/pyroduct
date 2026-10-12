# Evolution Layer Cycle Flow - Evidence

**Date**: 2026-10-11  
**Skill**: flow-visualizer + graphviz  
**Scope**: 演化层主体循环流程（run_cycle 的执行链与闸门判定）

---

## Flow Summary

**触发**：`run_cycle(seed, world, criterion, rounds)`

**主路径**（每回合）：
1. 计算世界回应：`evaluate(genome, world)` → Fitness
2. 选择驱动槽：`cycle_slot(fitness, state)` → Slot
3. 执行状态机步骤：`@sm.step(state, slot)` → raw Outcome
4. 裁决未定：`resolve_open(raw, genome, state)` → Outcome
5. 更新位置：根据 Outcome 的 landing 决定新位置
6. 生成修习/开放候选
7. 闸门判定：`judge()` → Decision（宪法级 + 选择级）
8. 应用裁决：Accepted → 应用改动
9. 记录 CycleEvent
10. 更新状态

**结果**：`SubjectCycle { seed, objective, events[] }`，可导出 `Ledger`（只追加账本）

---

## Step-by-Step Walkthrough

### Step 1: World Response (世界回应)

**函数**：`evaluate(genome : Genome, world : Array[Opponent]) -> Fitness`  
**位置**：`evolution/causal.mbt`（未读取完整文件）  
**证据**：`evolution/cycle.mbt:202`

```moonbit
let response = memo.response(g, round, () => evaluate(g, world))
```

**返回值**：`Fitness { consensus, stability, residue, cost }`  
**备忘录**：`memo.response()` 避免重复计算（同基因组同回合不重算）

---

### Step 2: Select Slot (选择驱动槽)

**函数**：`cycle_slot(f : Fitness, at : SubjectState) -> Slot`  
**位置**：`evolution/cycle.mbt:71-113`  
**证据**：代码第 71-113 行

**优先序**（按世界回应状态）：
- **病理**（stability < 100）：揭蔽 → 共在 → 反馈 → 行动 → ...
- **共识**（consensus >= 50）：反馈 → 共在 → 揭蔽 → 行动 → ...
- **其他**：行动 → 取向 → 共在 → 揭蔽 → ...

**约束**：只在该位置**有出边**的槽里找（`@sm.exitable(at, k)`）

---

### Step 3: Step State Machine (状态机执行)

**函数**：`@sm.step(state : SubjectState, slot : Slot) -> Outcome`  
**位置**：`src/loop.mbt:138-169`  
**证据**：`evolution/cycle.mbt:205`

```moonbit
let raw = @sm.step(cur.state, slot)
```

**返回值**：`raw Outcome`（迁/守/未定/同归/无路）  
**关键**：位置推进只走迁移表，不编造下一步

---

### Step 4: Resolve Open (裁决未定)

**函数**：`resolve_open(out : Outcome, genome : Genome, at : SubjectState) -> Outcome`  
**位置**：`evolution/cycle.mbt:155-179`  
**证据**：代码第 155-179 行

```moonbit
fn resolve_open(
  out : @sm.Outcome,
  genome : Genome,
  at : @sm.SubjectState,
) -> @sm.Outcome {
  match out {
    @sm.Open(cands) => {
      if cands.length() < 2 {
        return out
      }
      let pick = if genome.toward_other > genome.toward_self {
        cands.length() - 1  // 空间侧（后一条）
      } else {
        0  // 时间侧（前一条）
      }
      let c = cands[pick]
      if c.1 == at {
        @sm.Held(c.0, c.1)
      } else {
        @sm.Moved(c.0, c.1)
      }
    }
    other => other
  }
}
```

**裁决规则**（模型整理）：
- `toward_other > toward_self` → 空间侧（疏离/交织/敬畏，后一条候选）
- 持平或 `toward_self >= toward_other` → 时间侧（紧迫/沉淀/受赏，前一条候选）

---

### Step 5: Update Position (更新位置)

**位置**：`evolution/cycle.mbt:207-210`  
**证据**：代码第 207-210 行

```moonbit
let moved_to = match outcome.landing() {
  Some(next) => next
  None => cur.state
}
```

**规则**：
- `Moved/Held/Same` → `landing()` 返回 `Some(next)` → 更新位置
- `Open/Block` → `landing()` 返回 `None` → 位置不动

---

### Step 6: Generate Candidates (生成候选)

**修习候选**（`evolution/cycle.mbt:212-225`）：
```moonbit
let shed = if cur.genome.carry - 4 < 1 { 1 } else { cur.genome.carry - 4 }
let practice = offer(
  g,
  Candidate::{
    locus: Memory,
    what: "修习：残余 \{g.carry} → \{shed}",
    genome: { ..g, carry: shed },
  },
  ...
)
```

**开放候选**（`evolution/cycle.mbt:227-244`）：
```moonbit
let loosen = if cur.genome.toward_self - 25 < 1 {
  1
} else {
  cur.genome.toward_self - 25
}
let opening = offer(
  g,
  Candidate::{
    locus: Strategy,
    what: "开放：己之诚 \{g.toward_self} → \{loosen}",
    genome: { ..g, toward_self: loosen },
  },
  ...
)
```

**约束**：
- 修习：残余 -4，降到 1 为止（R10 不许把不确定性进化掉）
- 开放：己之诚 -25，降到 1 为止（遭遇要求自身不再抱得太紧）

---

### Step 7: Gate Judgement (闸门判定)

**函数**：`offer()` → `judge()`  
**位置**：`evolution/cycle.mbt:280-293` + `evolution/gate.mbt:105-150`  
**证据**：`evolution/cycle.mbt:289-291`

```moonbit
let d = memo.judgement(parent, c, round, () => {
  judge(parent, parent_score, c, world, criterion)
})
```

**闸门流程**：
1. **宪法检查**：`constitution_violations(candidate.genome)`
   - R10：残余 carry ≥ 1
   - R2/R14：不得以宣告把结论说成终局
   - R3：他之诚 toward_other > 0
2. **判据裁决**：
   - `Weighted`：加权分数比较，退步即回滚
   - `Causal`：DoubleML 估计 θ̂，θ̂>0 且 95%下界>0 才接收

**返回值**：`Decision { verdict, reason, fitness, score, effect, effect_lo }`

---

### Step 8: Apply Decisions (应用裁决)

**位置**：`evolution/cycle.mbt:245-251`  
**证据**：代码第 245-251 行

```moonbit
let mut next_genome = cur.genome
if practice.decision.verdict == Accepted {
  next_genome = practice.candidate.genome
}
if opening.decision.verdict == Accepted {
  next_genome = opening.candidate.genome
}
```

**规则**：
- 两个候选独立判定
- Accepted → 应用该候选的基因组改动
- 其他（Rejected/Tie）→ 保持原基因组

---

### Step 9: Record Event (记录事件)

**位置**：`evolution/cycle.mbt:260-271`  
**证据**：代码第 260-271 行

```moonbit
events.push({
  round,
  state_before: cur.state,
  slot,
  outcome,
  state_after: moved_to,
  genome_after: next_genome,
  response,
  practice,
  opening,
  remainder,
})
```

**CycleEvent 结构**：
- `round`：回合编号
- `state_before/after`：位置迁移
- `slot`：驱动槽
- `outcome`：状态机回执
- `genome_after`：闸门裁决后的基因组
- `response`：世界回应（Fitness）
- `practice/opening`：两个候选的 Offer
- `remainder`：未穷尽者说明

---

### Step 10: Update State (更新状态)

**位置**：`evolution/cycle.mbt:272`  
**证据**：代码第 272 行

```moonbit
cur = { state: moved_to, genome: next_genome }
```

**循环**：`for round = 0; round < rounds; round = round + 1`

---

## Gate Details (闸门详情)

### Constitution Check (宪法检查)

**函数**：`constitution_violations(g : Genome) -> Array[String]`  
**位置**：`evolution/gate.mbt:29-43`  
**证据**：代码第 29-43 行

```moonbit
pub fn constitution_violations(g : Genome) -> Array[String] {
  let out : Array[String] = []
  if g.carry < 1 {
    out.push("违反 R10：残余 = \{g.carry} < 1")
  }
  if g.voice == Declarative {
    out.push("违反 R2／R14：以「宣告」把结论说成终局")
  }
  if g.toward_other <= 0 {
    out.push("违反 R3：他之诚 = \{g.toward_other}，不再向对方敞开")
  }
  out
}
```

**条款**：
- **R10**：谬误残余恒 ≥1，不许把不确定性进化掉
- **R2/R14**：不得以宣告把结论说成终局，共识只能作建议
- **R3**：必须仍向对方敞开，他之诚 > 0

---

### Weighted Criterion (加权判据)

**位置**：`evolution/gate.mbt:141-150`（部分）  
**逻辑**：
- 计算 `score(fitness, objective)`
- 与 `parent_score` 比较
- 退步 → `RevertedRegression`（回滚）
- 持平 → `Tie`
- 进步 → `Accepted`

---

### Causal Criterion (因果判据)

**位置**：`evolution/gate.mbt:142-150`  
**证据**：代码第 142-150 行

```moonbit
Some(plan) => {
  let v = causal_effect(parent, c.genome, world, plan.episodes, plan.config)
  let effect = permille(v.theta)
  let lo = permille(v.ci_low)
  let ok = v.theta > 0.0 && v.ci_low > 0.0
  {
    verdict: if ok { Accepted } else { RevertedRegression },
    ...
  }
}
```

**逻辑**：
- 用 DoubleML 估计因果效应 θ̂
- θ̂ > 0 且 95% 置信下界 > 0 → `Accepted`
- 否则 → `RevertedRegression`

---

## Memo Mechanism (备忘录机制)

### Response Memo (回应备忘录)

**位置**：`evolution/replay.mbt`（未读取完整文件）  
**证据**：`evolution/cycle.mbt:202`

```moonbit
let response = memo.response(g, round, () => evaluate(g, world))
```

**作用**：同基因组同回合不重算回应

---

### Judgement Memo (裁决备忘录)

**位置**：`evolution/replay.mbt`  
**证据**：`evolution/cycle.mbt:289-291`

```moonbit
let d = memo.judgement(parent, c, round, () => {
  judge(parent, parent_score, c, world, criterion)
})
```

**作用**：
- 首裁结果写入备忘录
- 后续回合输入相同 → 直接读回
- 判词标注「[与回合 N 同判·不重裁]」

**意义**：同判不重裁是「持存」的取取（模型整理）

---

## Key Invariants (关键不变量)

### 1. 位置推进只走迁移表

**证据**：`evolution/cycle.mbt:7-8`  
**实现**：`@sm.step()` 的回执决定位置，不编造下一步

### 2. 未定由双诚之比裁决

**证据**：`evolution/cycle.mbt:17-19`  
**实现**：`resolve_open()` 按 `toward_other` vs `toward_self` 挑选

### 3. 一切改动都过闸门

**证据**：`evolution/cycle.mbt:14`  
**实现**：宪法级 + 选择级，退步就回滚

### 4. 同判不重裁

**证据**：`evolution/cycle.mbt:23`  
**实现**：`DecisionMemo` 记录首裁结果

### 5. 残余恒 ≥1 (R10)

**证据**：`evolution/cycle.mbt:211`  
**实现**：`carry - 4` 降到 1 为止

### 6. 不封闭

**证据**：`evolution/cycle.mbt:20-21`  
**实现**：`Open/Block` 都不推进位置，回执原样入账

---

## Output Structure (输出结构)

### SubjectCycle

**位置**：`evolution/cycle.mbt:58-62`  
**结构**：
```moonbit
pub struct SubjectCycle {
  seed : CycleState
  objective : String
  events : Array[CycleEvent]
}
```

**方法**：
- `.finished()` → `CycleState`（最终状态）
- `.ledger()` → `Ledger`（只追加账本）
- `.legal()` → `Bool`（整机自检）
- `.never_closed()` → `Bool`（不封闭检查）

---

### Ledger

**位置**：`evolution/ledger.mbt`（未读取完整文件）  
**证据**：`evolution/cycle.mbt:308-334`

**结构**：
```moonbit
{
  seed: Genome,
  objective: String,
  trails: Array[Trail]
}
```

**特性**：
- 只追加
- 可序列化（`serialize()`）
- 可解析（`parse()`）
- 往返一致（`parse(serialize()).trails.length() == trails.length()`）

---

## Artifacts

| File | Format | Purpose |
|------|--------|---------|
| `flow-evolution-cycle.dot` | Graphviz DOT | 完整循环流程图（含闸门详情和备忘录） |
| `flow-evolution-main-path.dot` | Graphviz DOT | 主路径流程图（聚焦单回合执行） |
| `flow-evolution-evidence.md` | Markdown | 本文档——逐步证据与代码引用 |

---

## Validation Steps

### 验证 run_cycle 行为

```bash
moon run cmd/main -- cycle       # 查看主体循环报告
moon run cmd/main -- evolution   # 查看演化层报告
```

### 验证不变量

```bash
moon test evolution              # 运行演化层测试
# 测试覆盖：
# - legal()：位置推进只走迁移表、配置改动皆合宪、残余恒 ≥1
# - never_closed()：循环经过的每个位置都仍有出边
# - 账本往返一致：parse(serialize()).trails.length() == trails.length()
```

---

## Maintenance Note

本流程文档基于 2026-10-11 的代码状态。当以下情况发生时需更新：
- 修改 `run_cycle` 的循环逻辑
- 调整闸门判定规则
- 改变未定裁决策略
- 新增候选类型

**生成技能**：`flow-visualizer` + `graphviz`  
**证据来源**：`evolution/cycle.mbt`, `evolution/gate.mbt`, `evolution/evolve.mbt`
