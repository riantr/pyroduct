# Pyroduct

A runnable, tested MoonBit state-machine family modelled from two Chinese
philosophy texts — 《通往宁静之路：个体道德发生论纲要》 (*The Road to
Tranquility: An Outline of the Genesis of Individual Morality*) and its parent
thesis 《伽达默尔与哈贝马斯真理观比较》 (*Gadamer and Habermas on Truth: A
Comparison*, Shanghai Academy of Social Sciences, 2008) — plus a gated agent
state machine and a research-agent coordinator.

One subject: 34 positions · 53 transitions · 11 phases. One group: 20 · 42 · 9.
One society: 13 · 26 · 8. Two subjects: 14 normative rules.

## Features

* Paper-executable, not paraphrased

  Every state, transition and phase is literal data with a page citation:
  `gloss()` ends in `P.xx`, and each construct is tagged 原文直述 (verbatim from
  the source) or 模型整理 (model reconstruction).

* One language, four units

  Subject (主体) / group (群体) / society (社会) share the same state + trigger +
  transition vocabulary at three scales: `src` (34·53·11), `group` (20·42·9,
  member config → emergence with R7 write-back), `society` (13·26·8, lifeworld
  vs. system). `multi` is the normative face: rules R1–R14 for two subjects —
  regime precedence, validity-claim timing, the two-sincerity distinction
  (两诚区分), unconcealment–concealment (解蔽—遮蔽) — each rule citing the thesis.

* Two-character names only

  Position and phase designations name a structural relation — nothing else.
  The discipline is locked by tests and printed by `render_naming_table()`.

* Drive slots and a step contract

  `Trigger::slot` sorts all 49 triggers into eight slots (Occasion 处境 /
  Orientation 取向 / Antecedent 先行 / Act 行动 / Feedback 反馈 / Hold 持存 /
  CoBeing 共在 / Unveil 揭蔽) with an exhaustive match — an unplaced trigger
  fails the build. `step(position, slot)` answers only Moved (迁) / Held (守) /
  Undecided (未定) / No-way (无路); of 272 position × slot combinations, 228
  honestly answer No-way. The machine never invents a move.

* An agent whose updates must clear a gate

  `evolution` treats an agent's config as `Genome`, enumerates single-step
  candidates (prompt / strategy / memory / code), writes "better" as an
  `Objective`, fences off constitutional invariants, and records every
  accept / reject / revert with its reason in an append-only, serializable
  `Ledger`. Gates come in two grades: hand-written weights, or a DoubleML
  causal effect (θ̂ > 0 and the 95% lower bound > 0). The subject cycle
  `run_cycle` drives real positions by drive slot and puts Cultivation (修习)
  and Opening (开放) through the same gate — no evidence, no advance
  (没有证据就不前进).

* A coordinator that refuses to close

  `coordinator` adds what a research agent needs beyond a state machine: tasks
  and artifacts, planning over a dependency graph, external evidence judged by
  confidence interval (not by votes), content memory that keeps superseded
  findings, credit with IP provenance, and a deliberation / decision split —
  deliverables carry revision marks, residue ownership and reopen conditions.
  The runtime is replayable and persists to disk. (The "think" step is still a
  deterministic stand-in, no LLM yet.)

* Dependency isolation

  Four named third-party dependencies, each confined to its consumer:
  `moonbitlang/async@0.22.4` → `cmd/coord` (native disk I/O);
  `riantr/moonbit_doubleML@0.75.0` → `dmlref` / `causal`;
  `riantr/snn_mbt@0.84.0` → `snnref` (native); `riantr/moonbit_static_analysis@0.1.0`
  → `audit`. Every other package uses official `moonbitlang/*` only.

## Terminology

Every construct carries a two-character Chinese designation, an English enum
identifier, and the original wording (原文) it designates. The tables below are
the complete English rendering of the vocabulary.

### Phases — subject (11)

| 定名 | English | 原文 |
|---|---|---|
| 立位 | Natural | 本然 |
| 自决 | Release | 自由的发生 |
| 自成 | Becoming | 自身与拣选 |
| 遭遇 | Otherness | 与他者相遇 |
| 归责 | Bondage | 恶感·耻感·罪感·自缚 |
| 受创 | Anguish | 痛苦与失落 |
| 奠基 | Idolatry | 偶像与根基 |
| 献身 | Glory | 崇高·激情·荣誉·敬畏 |
| 反顾 | Recollection | 反思 |
| 范导 | Upbringing | 修养之路 |
| 安位 | Serenity | 宁静 |

### Positions — subject (34)

| 定名 | English | 原文 |
|---|---|---|
| 无忆 | NoPast | 失忆 |
| 无筹 | NoFuture | 浑噩 |
| 立位 | Standing | 站立 |
| 自由 | Freedom | 自由 |
| 紧迫 | Urgency | 紧迫感 |
| 疏离 | Alienation | 疏离感 |
| 空虚 | Emptiness | 空虚 |
| 忙碌 | Busyness | 忙碌 |
| 自身 | Selfhood | 独立的自身 |
| 交织 | Weaving | 图画 |
| 择取 | Choosing | 拣选 |
| 相遇 | Encounter | 相遇 |
| 敞开 | Opening | 敞开 |
| 受挫 | Evil | 恶感 |
| 自归 | Shame | 耻感 |
| 失权 | Guilt | 罪感 |
| 自缚 | Binding | 束缚 |
| 隐没 | Secret | 秘密 |
| 痛苦 | Suffering | 痛苦 |
| 沉落 | Loss | 失落 |
| 投射 | Idol | 偶像 |
| 立序 | Ordered | 秩序 |
| 崇奉 | Sublime | 崇高感 |
| 激情 | Passion | 激情 |
| 受赏 | Honor | 荣誉 |
| 畏怖 | Awe | 敬畏 |
| 惯习 | Habit | 习惯 |
| 反顾 | Reflection | 审视 |
| 眩晕 | Dizziness | 眩晕 |
| 平衡 | Harmony | 和谐 |
| 范型 | Model | 榜样 |
| 图绘 | Marking | 标记 |
| 修习 | Discipline | 修养 |
| 宁静 | Tranquility | 宁静 |

### Drive slots (8) and the 49 triggers

| English | 定名 | Count | Triggers |
|---|---|---|---|
| Occasion | 处境 | 6 | TakeStand, FeelFinitude, FeelBoundlessness, FuseFeelings, MustBeBusy, ColdHard |
| Orientation | 取向 | 6 | ChooseMoreLasting, Complexify, SeekMoreJoy, SeekBalance, SeekGoal, TakeModel |
| Antecedent | 先行 | 4 | TouchFuture, TryMethods, Approximate, WaitNext |
| Act | 行动 | 9 | ActInFreedom, BindSelf, Avoid, CutPast, SummonIdol, MarkGoodBad, RedrawMap, Endure, RemoveReefs |
| Feedback | 反馈 | 8 | Sting, BlameSelf, EnactOrder, AbsorbGlory, Reward, Dread, WidenFrontier, Ascend |
| Hold | 持存 | 8 | KeepContinuity, Deposit, TurnToResidue, Interweave, Surprise, Doubt, Linger, Habituate |
| CoBeing | 共在 | 3 | MeetOther, GoodFaith, OpenArms |
| Unveil | 揭蔽 | 5 | AttributeSelf, FillEmptiness, CoolDown, DoubtOneself, ReopenByHorizon |

### Step contract (4 outcomes)

迁 Moved · 守 Held · 未定 Undecided · 无路 No-way

### Truth regimes (5) · discourse types (4) · validity claims (4)

| 定名 | English | Gloss |
|---|---|---|
| 内在秩序 | Immanent | truth as an eternal order already in the world (ancient Egypt) |
| 逻各斯 | Logos | truth as eternal speech, guaranteed by the rational soul (ancient Greece) |
| 超主体性 | SuperSubjective | Gadamer: understanding and language are supra-subjective events |
| 主体间性 | InterSubjective | Habermas: truth is intersubjective validity claims, woven into a net |
| 诚然 | ChengRan | the author's own scheme: a hermeneutics of sincerity, unified in self-illumination |

| 定名 | English |
|---|---|
| 理论商谈 | Theoretical |
| 实践商谈 | Practical |
| 表达性商谈 | Aesthetic |
| 信仰商谈 | Faith |

| 定名 | English | Claim |
|---|---|---|
| 真实性 | Truthfulness | propositional truth — objective world |
| 正当性 | Legitimacy | normative rightness — social world |
| 他之诚 | Authenticity | speech-content congruence (other-sincerity) |
| 己之诚 | Sincerity | act–intention congruence (self-sincerity) |

Claim phases: 事前 Before · 事中 During · 事后 After.

### Normative rules R1–R14

| Code | 定名 | English |
|---|---|---|
| R1 | 体制优先 | Regime precedence |
| R2 | 不独断 | No dogmatism |
| R3 | 解蔽—遮蔽 | Unconcealment–concealment |
| R4 | 有效性时序 | Validity-claim timing |
| R5 | 两诚区分 | Two-sincerity distinction |
| R6 | 弃符合论、存方法 | Drop correspondence, keep method |
| R7 | 构成性 | Constitutivity |
| R8 | 第三者 | The third party |
| R9 | 商谈类型 | Discourse types |
| R10 | 谬误残余 | Error residue |
| R11 | 不可闭合 | Never closed |
| R12 | 诚然相契 | ChengRan resonance |
| R13 | 横检纵共 | Horizontal review, vertical commonality |
| R14 | 共识即建议 | Consensus as suggestion |

### Packages

`src` (subject machine) · `multi` (normative rules) · `group` (group emergence) ·
`society` (two-level social model) · `ml` (from-scratch DoubleML) · `evolution`
(agent state machine) · `coordinator` (research-agent runtime) · `dmlref`
(external cross-check) · `causal` (causal diagnostics) · `audit` (three-mirror
static audit) · `snnref` (spike-sediment experiment).

### Discipline terms

原文直述 *verbatim from the source* · 模型整理 *model reconstruction* · 两诚
*two sincerities* · 解蔽—遮蔽 *unconcealment–concealment* · 没有证据就不前进
*no evidence, no advance* · 双诚之比 *two-sincerity ratio* · 同判·不重裁
*same verdict, not re-adjudicated* · 三鉴 *three mirrors (structure / type /
behavior)* · 往返一致 *round-trips identically*.

## Quick Start

Add the module, then run the suite:

```
moon add riantr/pyroduct
moon test             # Total tests: 105, passed: 105, failed: 0.
```

From this repository, every layer prints a report:

```
moon run cmd/main -- report        # subject state machine
moon run cmd/main -- slots         # drive slots: 49 triggers → 8 slots
moon run cmd/main -- multi         # normative rules R1–R14 + scenarios
moon run cmd/main -- group         # group state machine
moon run cmd/main -- society       # two-level social model
moon run cmd/main -- evolution     # mutation / fitness / gate / persistence / heredity
moon run cmd/main -- cycle         # subject cycle: position × slot × causal feedback
moon run cmd/main -- coordinator   # research-agent coordinator
moon run --target native cmd/coord # real disk I/O: checkpoint round-trips identically
```

## Example

```moonbit nocheck
// Subject: positions, main line, drive slots, step contract
let states : Array[@src.SubjectState] = @src.all_states()      // 34 of them
let ok     : Bool = @src.reachable(@src.initial(), @src.terminal())
let moved  : @src.Outcome = @src.step(@src.Standing, @src.Occasion) // Moved

// One encounter of two subjects: regime, two sincerities, and claim timing all adjudicate
let me    = @multi.subject(1, @multi.rendezvous(), @multi.InterSubjective, 70, 70, 9)
let other = @multi.subject(2, @multi.rendezvous(), @multi.ChengRan, 80, 80, 9)
let claim : @multi.ValidityClaim = { kind: @multi.Truthfulness, phase: @multi.During }
let out   = @multi.encounter(me, other, @multi.Theoretical, claim)

// Society: two invariants locked by tests
let never_closes : Bool = @society.no_final_closure()

// Agent state machine: enumerate candidates → gate → append-only ledger
let agent  = @evolution.default_agent()
let ledger = @evolution.evolve(agent, @evolution.default_world(),
                               @evolution.Weighted(@evolution.truth_objective()), 3)

// Coordinator: run a demo study, write / read back the checkpoint
let rt   = @coordinator.new_runtime()
ignore(rt.step(@coordinator.demo_tasks(), @coordinator.demo_questions(),
               @coordinator.demo_workers(), @coordinator.demo_datasets(),
               @coordinator.demo_world(), @coordinator.demo_parent(),
               @coordinator.demo_candidate()))
let restored = @coordinator.restore(rt.checkpoint())
let same : Bool = restored.round_trips()
```

## Used By

- `cmd/main` — the report entry for every layer above: `report` / `slots` /
  `multi` / `group` / `society` / `evolution` / `cycle` / `coordinator`, plus
  `mermaid` / `dot` / `genesis` / `course` / `naming` / `principle` / `all`.
- `cmd/coord` — a native binary that runs the coordinator and round-trips its
  checkpoint through real disk I/O (`.openseek/`, gitignored).

## Attribution

- Source text: 任勇祥《伽达默尔与哈贝马斯真理观比较》(Shanghai Academy of
  Social Sciences, 2008) and its appendix 《通往宁静之路：个体道德发生论纲要》.
  Every construct in the model cites the chapter / section / page of that text
  and explicitly distinguishes 原文直述 (verbatim from the source) from 模型整理
  (model reconstruction).
- License: MIT (see `LICENSE`).
