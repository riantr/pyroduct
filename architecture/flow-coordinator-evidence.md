# Coordinator Runtime Flow - Evidence

**Date**: 2026-10-11  
**Skill**: flow-visualizer + graphviz  
**Scope**: 协调器运行时流程（runtime.step 的执行链与路由机制）

---

## Flow Summary

**触发**：`runtime.step(tasks, questions, agents, datasets, world, parent, candidate)`

**主路径**：
1. 找就绪任务：`ready(tasks, done)` → 依赖已满足的任务
2. 指派工人：`assign(question, agents)` → 按商谈类型适配度
3. 确定主张类型：商谈类型 → ClaimKind
4. 路由：理论商谈→跑实验；其他→停在商谈段
5. 产出：Result + Finding + Artifact + Message
6. 更新状态：done.push + clock += 1
7. 返回 StepReport

**结果**：`StepReport { at, task, agent, discourse, verdict, result, finding }`

---

## Step-by-Step Walkthrough

### Step 1: Find Ready Task (找就绪任务)

**函数**：`ready(tasks : Array[Task], done : Array[Int]) -> Array[Int]`  
**位置**：`coordinator/plan.mbt:77-94`  
**证据**：`coordinator/runtime.mbt:82`

```moonbit
let rd = ready(tasks, self.done)
if rd.length() == 0 {
  return None
}
let t = tasks[rd[0]]
```

**逻辑**：
- 过滤：未完成（`!done.contains(t.id)`）
- 依赖满足：`deps` 都已完成（`done.contains(d)`）
- 取第一个就绪任务

**依赖图**：拓扑序由 `topological(tasks)` 计算（Kahn 算法）

---

### Step 2: Assign Worker (指派工人)

**函数**：`assign(q : Question, agents : Array[Worker]) -> Int?`  
**位置**：`coordinator/plan.mbt:109-124`  
**证据**：`coordinator/runtime.mbt:88-91`

```moonbit
let agent = match assign(q, agents) {
  Some(a) => a
  None => return None
}
```

**适配度**（`fit` 函数）：
- 理论商谈 → `w.reason`（共同理性）
- 实践商谈 → `w.cheng`（两诚）
- 表达性商谈 → `w.cheng`
- 信仰商谈 → 50（固定）

**约束**：预算 > 0（`w.budget <= 0` 跳过）

---

### Step 3: Determine Claim (确定主张类型)

**位置**：`coordinator/runtime.mbt:93-98`  
**证据**：代码第 93-98 行

```moonbit
let claim = match q.discourse {
  @multi.Theoretical => @multi.Truthfulness
  @multi.Practical => @multi.Legitimacy
  @multi.Aesthetic => @multi.Sincerity
  @multi.Faith => @multi.Authenticity
}
let phase = @multi.phase_of(claim)
```

**映射**：
- 理论商谈 → 真实性（Truthfulness）
- 实践商谈 → 正当性（Legitimacy）
- 表达性商谈 → 己之诚（Sincerity）
- 信仰商谈 → 他之诚（Authenticity）

---

### Step 4: Route by Discourse (路由)

**位置**：`coordinator/runtime.mbt:101-111`  
**证据**：代码第 101-111 行

```moonbit
let binding : Binding? = match q.discourse {
  @multi.Theoretical =>
    if datasets.length() > q.id {
      let ds = datasets[q.id]
      let b0 = experiment(q.text, ds, parent, candidate, world)
      Some(replicate(b0, ds, parent, candidate, world))
    } else {
      None
    }
  _ => None
}
```

**路由规则**：
- **理论商谈** → 跑实验（`experiment`）+ 复现（`replicate`）→ `Binding`
- **其他商谈** → `binding = None`，停在商谈段

---

### Step 4a: Run Experiment (跑实验)

**函数**：`experiment(claim_text, ds, parent, candidate, world) -> Binding`  
**位置**：`coordinator/evidence.mbt:87-100`  
**证据**：代码第 87-100 行

```moonbit
pub fn experiment(
  claim_text : String,
  ds : Dataset,
  parent : @evolution.Genome,
  candidate : @evolution.Genome,
  world : Array[@evolution.Opponent],
) -> Binding {
  let (effect, lo, hi) = measure(parent, candidate, world, ds.rows, ds.seed)
  {
    claim_text,
    dataset: ds.id,
    digest: ds.digest,
    effect,
    ci_low: lo,
    ci_high: hi,
    replicas: 0,
    warrant: FromData,
  }
}
```

**返回值**：`Binding { claim_text, dataset, digest, effect, ci_low, ci_high, replicas, warrant }`

**关键**：真跑 DoubleML，效应与区间以千分位整数存放

---

### Step 4b: Replicate (复现)

**函数**：`replicate(binding, ds, parent, candidate, world) -> Binding`  
**位置**：`coordinator/evidence.mbt`（未读取完整文件）  
**证据**：`coordinator/runtime.mbt:106`

**作用**：在不同种子上重跑，更新 `replicas` 计数

---

### Step 5: Determine Verdict (判定)

**位置**：`coordinator/runtime.mbt:112-115`  
**证据**：代码第 112-115 行

```moonbit
let verdict = match binding {
  Some(b) => evidence_verdict(b).label()
  None => "仅对话"
}
```

**证据判词**（`evidence_verdict` 函数）：
- `replicas >= 2 && ci_low > 0` → `Replicated`（复现成立）
- `ci_low > 0` → `Supported`（支持）
- `ci_high < 0` → `Refuted`（反驳）
- 区间含 0 → `Inconclusive`（不确定）

---

### Step 6: Produce Result (产出结果)

**位置**：`coordinator/runtime.mbt:129-144`  
**证据**：代码第 129-144 行

```moonbit
let result_id = self.results.length()
self.results.push(
  result(
    result_id,
    t.id,
    q.id,
    claim,
    phase,
    summary,
    dataset_id,
    effect,
    lo,
    hi,
    replicas,
  ),
)
```

**Result 结构**：
```moonbit
pub struct Result {
  id : Int
  task : Int
  question : Int
  claim : @multi.ClaimKind
  phase : @multi.ClaimPhase
  summary : String
  dataset : Int
  effect : Int      // 千分位
  ci_low : Int      // 95% 区间下界
  ci_high : Int     // 95% 区间上界
  replicas : Int    // 复现次数
}
```

---

### Step 7: Produce Finding (产出发现)

**位置**：`coordinator/runtime.mbt:145-157`  
**证据**：代码第 145-157 行

```moonbit
let finding_id = self.notebook.add({
  id: 0,
  question: q.id,
  text: summary,
  claim,
  phase,
  result: result_id,
  residual: 3,
  status,
  supersedes: None,
  author: agent,
  at,
})
```

**Finding 状态**（由证据判词决定）：
- `Supported/Replicated` → `Established`
- `Refuted` → `Overturned`
- `Inconclusive` → `Pending`

---

### Step 8: Produce Artifact (产出制品)

**位置**：`coordinator/runtime.mbt:158-165`  
**证据**：代码第 158-165 行

```moonbit
let artifact_id = self.artifacts.length()
self.artifacts.push({
  id: artifact_id,
  kind: Note,
  name: "\{t.title} 的结论",
  task: t.id,
  digest: "\{result_id}",
})
```

**Artifact 类型**：Paper / Figure / Code / Data / Note

---

### Step 9: Log Message (记录消息)

**位置**：`coordinator/runtime.mbt:166-173`  
**证据**：代码第 166-173 行

```moonbit
self.log.push({
  at,
  from: agent,
  to: -1,  // 广播
  discourse: q.discourse,
  claim,
  body: summary,
})
```

**Message 结构**：
```moonbit
pub struct Message {
  at : Int
  from : Int
  to : Int      // -1 = 广播
  discourse : @multi.DiscourseType
  claim : @multi.ClaimKind
  body : String
}
```

---

### Step 10: Mark Done & Update Clock (标记完成 & 更新时钟)

**位置**：`coordinator/runtime.mbt:174-175`  
**证据**：代码第 174-175 行

```moonbit
self.done.push(t.id)
self.clock = at + 1
```

---

### Step 11: Return Report (返回报告)

**位置**：`coordinator/runtime.mbt:176-184`  
**证据**：代码第 176-184 行

```moonbit
Some({
  at,
  task: t.id,
  agent,
  discourse: q.discourse.label(),
  verdict,
  result: result_id,
  finding: finding_id,
})
```

**StepReport 结构**：
```moonbit
pub struct StepReport {
  at : Int
  task : Int
  agent : Int
  discourse : String
  verdict : String
  result : Int
  finding : Int
}
```

---

## Deliberation / Decision (商谈段 / 决策段)

### Deliberation (商谈段)

**位置**：`coordinator/decision.mbt:10-14`  
**结构**：
```moonbit
pub(all) struct Deliberation {
  question : Int
  options : Array[Int]        // 候选发现（finding id）
  open_remainder : String     // 未穷尽者（R3），恒非空
}
```

**特性**：
- 开放：多个方案并存
- 主张只是建议（R14：共识即建议）
- `open_remainder` 恒非空（不封闭）

---

### Decision (决策段)

**位置**：`coordinator/decision.mbt:41-49`  
**结构**：
```moonbit
pub struct Decision {
  question : Int
  chosen : Int
  commitment : Commitment    // Draft / Adopted / Superseded / Withdrawn
  revisable : Bool           // 可修订标记
  residual_owner : Int       // 残余归属
  reopen_when : String       // 重开条件
  at : Int
}
```

**不变量**（`decision_ok`）：
- `revisable == true`
- `reopen_when.length() > 0`
- `residual_owner >= 0`

---

### Reopen (重开)

**位置**：`coordinator/decision.mbt:89-95`  
**证据**：代码第 89-95 行

```moonbit
pub fn reopen(dec : Decision, extra : Int) -> Deliberation {
  {
    question: dec.question,
    options: [dec.chosen, extra],
    open_remainder: "重开：\{dec.reopen_when}",
  }
}
```

**作用**：交付降为草稿，新方案并进来，缺口可达（`@society.no_final_closure` 的精神）

---

## Checkpoint Mechanism (落盘机制)

### checkpoint()

**位置**：`coordinator/runtime.mbt:249-297`  
**作用**：`Runtime → String`（序列化）

**格式**：
```
clock\t{clock}
done\t{task_id}
msg\t{at}\t{from}\t{to}\t{discourse}\t{claim}\t{body}
result\t{id}\t{task}\t{question}\t{claim}\t{phase}\t{dataset}\t{effect}\t{ci_low}\t{ci_high}\t{replicas}\t{summary}
artifact\t{id}\t{kind}\t{task}\t{digest}\t{name}
finding\t...
```

---

### restore()

**位置**：`coordinator/runtime.mbt:301-364`  
**作用**：`String → Runtime`（反序列化）

**逻辑**：逐行解析 `tag\tfields`，重建 Runtime 状态

---

### round_trips()

**位置**：`coordinator/runtime.mbt:368-374`  
**证据**：代码第 368-374 行

```moonbit
pub fn Runtime::round_trips(self : Runtime) -> Bool {
  let text = self.checkpoint()
  let back = restore(text)
  back.checkpoint() == text &&
  back.clock == self.clock &&
  back.notebook.findings.length() == self.notebook.findings.length()
}
```

**不变量**：往返一致（文本相同 + 状态相同）

---

## Key Invariants (关键不变量)

### 1. 依赖图驱动

**证据**：`coordinator/plan.mbt:39-73`  
**实现**：拓扑序（Kahn 算法），就绪 = deps 都已完成

### 2. 商谈类型路由

**证据**：`coordinator/runtime.mbt:101-111`  
**实现**：理论→证据（DoubleML）；其他→商谈段（仅对话）

### 3. 证据绑定

**证据**：`coordinator/evidence.mbt:30-39`  
**实现**：主张钉在数据集上（效应 + 95% 区间 + 复现）

### 4. 只追加台账

**证据**：`coordinator/runtime.mbt:22-29`  
**实现**：log, done, results, artifacts, notebook 只追加

### 5. 落盘往返一致

**证据**：`coordinator/runtime.mbt:368-374`  
**实现**：`checkpoint() ↔ restore()`

### 6. 决策段三件套

**证据**：`coordinator/decision.mbt:83-85`  
**实现**：可修订 + 残余归属 + 重开条件

---

## Artifacts

| File | Format | Purpose |
|------|--------|---------|
| `flow-coordinator-runtime.dot` | Graphviz DOT | 完整运行时流程图（含路由详情和落盘机制） |
| `flow-coordinator-main-path.dot` | Graphviz DOT | 主路径流程图（聚焦单步执行） |
| `flow-coordinator-evidence.md` | Markdown | 本文档——逐步证据与代码引用 |

---

## Validation Steps

### 验证 runtime.step 行为

```bash
moon run cmd/main -- coordinator   # 查看协调器报告
moon run --target native cmd/coord # 真实磁盘 IO，验证落盘
```

### 验证不变量

```bash
moon test coordinator              # 运行协调器测试
# 测试覆盖：
# - round_trips()：落盘往返一致
# - decision_ok()：决策段三件套
# - ready()：依赖图就绪判定
# - assign()：工人指派
```

---

## Maintenance Note

本流程文档基于 2026-10-11 的代码状态。当以下情况发生时需更新：
- 修改 `runtime.step` 的执行逻辑
- 调整路由规则
- 改变证据判定标准
- 新增商谈类型

**生成技能**：`flow-visualizer` + `graphviz`  
**证据来源**：`coordinator/runtime.mbt`, `coordinator/plan.mbt`, `coordinator/decision.mbt`, `coordinator/evidence.mbt`
