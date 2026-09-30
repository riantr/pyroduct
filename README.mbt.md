# riantr/pyroduct · From a Philosophy Thesis to Runnable Multi-Agent Models

A pure-MoonBit port of two Chinese philosophy texts into **runnable, tested state
machines**: Ren Yongxiang's MA thesis *《伽达默尔与哈贝马斯真理观比较》*
(Shanghai Academy of Social Sciences, 2008) and its appendix
*《通往宁静之路：个体道德发生论纲要》*. The thesis is not merely described —
it is **executed**: every state, transition and page citation is data you can
print, test, evolve and coordinate with.

Targets readers who want (a) a worked example of modelling an argument as a
finite-state machine with page-level citations, (b) a from-scratch DoubleML in
MoonBit with an independent cross-check against a published port, and (c) a
normative skeleton for coordinating research agents — turn protocol, claim
ledger, evidence binding, and a principled refusal to close.

#Status

| Item | Value |
|------|-------|
| Repository | `git@gitee.com:ren-yongxiang/pyroduct.git` |
| Author | `riantr` |
| License | MIT |
| `moon.mod` version | **0.1.1** |
| Module name | `riantr/pyroduct` |
| Source layout | 15 packages in one module（11 个库／CLI + 4 个示例），一个关注点一个包 |
| `.mbt` file count | **41 production files** (+ 8 test files) |
| Packages | 库：`src` · `multi` · `group` · `society` · `ml` · `evolution` · `coordinator` · `dmlref`；CLI：`cmd/main` · `cmd/coord`；其他：`tools/pdfdump` · `examples/{plr,irm,cross_check,consumer}` |
| Third-party deps | `moonbitlang/async@0.22.4` (only `cmd/coord`) · `riantr/moonbit_doubleML@0.64.0` (only `dmlref`) |
| Backends | `wasm` (default `moon test`) · `native` (`cmd/coord`, real disk I/O) — `wasm-gc` / `js` 未实测 |
| Tests | **77 / 77** (`moon test`) |
| Keywords | state machine · hermeneutics · Gadamer · Habermas · multi-agent · DoubleML · causal inference · research coordinator · 语料建模 · 科研协调 |

#Features

**论文可执行，而不是被描述** — 每个状态、每条迁移、每个阶段都带**页码出处**
（`State::gloss()` 末尾的 `P.xx`），`society::basis()` 把构造与章节逐条对齐。模型可以
被打印（`moon run cmd/main -- report`）、被遍历（`reachable`／`successors`）、被断言
（`no_final_closure`），也可以被 `moon test` 检验。

**三层同构的单位：主体／群体／社会** — 同一套「状态 + 触发 + 迁移」的语言在三个尺度上
复用：`src` 是一个人的道德发生（34 状态 · 53 迁移 · 11 阶段），`group` 是一群主体的
涌现（20 状态 · 42 迁移 · 9 阶段，成员配置 → 群体状态，并由 R7 回写成员），`society`
是论文自身的群体层面构造（13 状态 · 26 迁移 · 8 阶段）。命名纪律贯穿三者：状态名与
阶段名**一律两字**，只指称结构关系。

**规范先行：多主体行为规则 R1–R14** — `multi` 把论文里「如何对待主体性」的立场做成
可计算的体制（`TruthRegime`：内在秩序／逻各斯／超主体性／主体间性／诚然），把四类
有效性主张做成带**时间位置**的 schema（`ClaimKind` × `ClaimPhase`，事前／事中／事后），
并给出一次遭遇的完整裁决（`encounter` → `Verdict`：相位越界／不寻求／体制冲突／
独白化／暂时共识／相契）。每条规则都附原文出处。

**双层次社会交往模型（从原文提取）** — 生活世界（语言层：文化再生产／社会整合／
社会化）与系统（金钱与权力层：内在殖民化），以及使两层发生关系的**交往**：主张 →
商谈（「洗衣机」）→ 辩护 → 共识（Einverständnis）→ 规范（贴「过去时」标签）→
第三者缺失（「乌托邦」）。两条不变量由测试锁定：**不封闭**（无终态，缺口处处可达）与
**残余恒正**。

**进化层：变异／适应度／闸门／持久化／遗传** — `evolution` 把一个 agent 的可变配置
做成 `Genome`，枚举单步候选（提示／策略／记忆／代码四个位点），用 `Objective`
把「更好」**写成数据**，用 `constitution()` 划出不可被变异触碰的宪法级不变量，用
`Ledger`（只追加、可序列化）记录每一次接收／拒收／回滚及其理由。闸门有两档判据：
手写权重，或 **DoubleML 因果效应**（θ̂>0 且 95% 置信下界>0 才接收）。

**科研 Agent 协调器** — `coordinator` 补齐协调器真正需要而不在状态机里的七件事：
任务与制品（问题／数据集／产物／结果／引用／复现）、规划与调度（依赖图、拓扑序、
按商谈类型分工、预算与期限）、外部证据绑定（判词由**置信区间**给出，不由投票给出）、
内容记忆（记发现并保留被取代的历史）、署名与信用（IP 溯源）、**商谈段与决策段的分离**
（交付恒带可修订标记、残余归属与重开条件），以及一个**可重放、可落盘**的运行时。

**自研 DoubleML + 外部互校** — `ml` 从零实现部分线性模型的 Double／Debiased ML
（多项式筛 + 岭回归作 nuisance、K 折交叉拟合、Neyman 正交分数、渐近正态推断），
不依赖任何数值库。`dmlref` 把它与已发布的 `riantr/moonbit_doubleML@0.64.0`
逐点对照：同 nuisance 下两实现 θ̂ 相差 **0.017**、标准误 0.153／0.152。

**依赖隔离** — 两个第三方依赖各自被关在单个包里（`moonbitlang/async` 只在
`cmd/coord`，`riantr/moonbit_doubleML` 只在 `dmlref`）；其余九个包只用官方
`moonbitlang/core` 子包，供应链面最小。

#Quick Start

```console
$ moon test
Total tests: 75, passed: 75, failed: 0.

$ moon run cmd/main -- report        # 主体状态机（默认）
$ moon run cmd/main -- multi         # 多主体行为规则 R1–R14 + 场景
$ moon run cmd/main -- group         # 群体状态机
$ moon run cmd/main -- society       # 双层次社会交往模型
$ moon run cmd/main -- evolution     # 变异／适应度／闸门／持久化／遗传
$ moon run cmd/main -- coordinator   # 科研 Agent 协调器（八节）
$ moon run cmd/main -- dmlref        # 与外部参考实现对照

$ moon run examples/plr              # 示例：外部 DGP + 外部 DoubleMLPLR
$ moon run examples/irm              # 示例：外部 DGP + 外部 DoubleMLIRM
$ moon run examples/cross_check      # 示例：外部 DGP 上两实现互校
$ moon run examples/consumer         # 示例：库使用者的最小闭环

$ moon run --target native cmd/coord # 真实落盘
步数 3｜时钟 3｜发现 3 条
已落盘：.openseek/coordinator-state.txt
读回：时钟 3｜往返一致 true｜与写前一致 true
```

#Library Use

```moonbit nocheck
// 主体状态机：枚举、遍历、可达性
let states : Array[@sm.SubjectState] = @sm.all_states()      // 34 个
let path   : Array[@sm.SubjectState] = @sm.genesis_path()    // 主线
let ok     : Bool = @sm.reachable(@sm.initial(), @sm.terminal())

// 一次两主体遭遇（相位、体制、两诚都参与裁决）
let me    = @multi.subject(1, @multi.rendezvous(), @multi.InterSubjective, 70, 70, 9)
let other = @multi.subject(2, @multi.rendezvous(), @multi.ChengRan, 80, 80, 9)
let claim : @multi.ValidityClaim = { kind: @multi.Truthfulness, phase: @multi.During }
let out   = @multi.encounter(me, other, @multi.Theoretical, claim)
let verdict : String = out.verdict.label()

// 双层次社会交往模型：状态、迁移、不变量
let social : Array[@society.State] = @society.all_states()   // 13 个
let never_closes : Bool = @society.no_final_closure()

// 进化：枚举候选 → 过闸 → 记账
let g    = @evolution.default_agent()
let cands = @evolution.mutations(g)                          // 14 个单步候选
let led  = @evolution.evolve(g, @evolution.default_world(),
                             @evolution.Weighted(@evolution.truth_objective()), 3)

// 协调器：跑一段示例研究，并把整机检查点写下 / 读回
let rt = @coordinator.new_runtime()
ignore(rt.step(@coordinator.demo_tasks(), @coordinator.demo_questions(),
               @coordinator.demo_workers(), @coordinator.demo_datasets(),
               @coordinator.demo_world(), @coordinator.demo_parent(),
               @coordinator.demo_candidate()))
let checkpoint : String = rt.checkpoint()
let back = @coordinator.restore(checkpoint)
let same : Bool = back.round_trips()
```

#Models

四套状态机共用「状态 + 触发 + 迁移」的语言，但单位不同：

| Package | 单位 | 状态 | 迁移 | 阶段 | 依据 |
|---------|------|------|------|------|------|
| `src` | 一个主体 | 34 | 53 | 11 | 《通往宁静之路》 |
| `group` | 一个群体 | 20 | 42 | 9 | 模型延伸：成员配置 → 群体涌现，R7 回写 |
| `society` | 一个社会 | 13 | 26 | 8 | 论文第四章（P.22–P.55），逐条出处 |
| `multi` | 两个主体 | — | 14 条规则 | — | 论文第四章第一节至第五节 |

`multi` 的规则（R1–R14）是这套模型的**规范面**：体制优先、不独断、解蔽—遮蔽、
有效性时序、两诚区分、弃符合论存方法、构成性、第三者、商谈类型、谬误残余、
不可闭合、诚然相契、横检纵共、共识即建议。

#CLI

`moon run cmd/main -- <subcommand>`：

| Subcommand | 输出 |
|------------|------|
| `report`（默认） | 主体状态机文字报告 |
| `mermaid` / `dot` | 状态图（Mermaid / Graphviz） |
| `genesis` / `course` | 主线（原文顺序）／可重入的环节序列 |
| `naming` / `principle` | 定名对照表／主体通用性原则 |
| `ml` / `ml-export` | DoubleML 接口与因果实验／数据集 CSV |
| `multi` / `group` / `society` / `evolution` / `coordinator` / `dmlref` | 各层报告 |
| `all` | 报告 + 历程 + Mermaid |

`moon run --target native cmd/coord` 跑协调器并把检查点写入
`.openseek/coordinator-state.txt`（该目录已被 `.gitignore` 忽略）。

#Examples

四个可运行示例，**一例一包**，打印形式照 `riantr/moonbit_doubleML` 的例子
（真值／估计／标准误／95% 置信区间）：

| 示例 | 数据来源 | 估计器 | 命令 |
|------|----------|--------|------|
| `examples/plr` | 外部 `plr_CCDDHNR2018` | 外部 `DoubleMLPLR` | `moon run examples/plr` |
| `examples/irm` | 外部 `make_irm_data` | 外部 `DoubleMLIRM`（倾向得分传 logistic） | `moon run examples/irm` |
| `examples/cross_check` | 外部 `plr_CCDDHNR2018` | 外部 PLR **与** 自研 `ml.dml_plr` 同时跑 | `moon run examples/cross_check` |
| `examples/consumer` | — | 只用本库公开 API | `moon run examples/consumer` |

```console
$ moon run examples/plr
=== MoonBit DML PLR（数据取自 riantr/moonbit_doubleML 的 DGP）===
true theta_0      = 1
estimated theta   = 0.9821170792373195
standard error    = 0.03755880410559667
95% CI            = [0.90850182319035, 1.055732335284289]
n_obs             = 500
n_features        = 20

$ moon run examples/irm
=== MoonBit DML IRM（数据取自 riantr/moonbit_doubleML 的 DGP）===
true theta_0      = 1
estimated theta   = 0.9646539735147219
standard error    = 0.10162091470514976
95% CI            = [0.7654769806926284, 1.1638309663368154]

$ moon run examples/cross_check
=== 实现互校：外部 DGP（plr_CCDDHNR2018），n = 500，5 折 ===
真值 θ            = 1
参考实现 θ̂        = 0.9821170792373195（se 0.03755880410559667）
自研实现 θ̂        = 1.0050224545430984（se 0.038635225992883944）
两者之差 |Δθ̂|     = 0.022905375305778852｜标准误之差 = 0.0010764218872872724
容差内一致        = true
```

`examples/irm` 的**倾向得分**必须传 logistic 学习器：处理变量是 0/1，用线性回归拟合
倾向得分会让 m̂ 越出 [0,1]，权重随之爆炸——这正是第一次跑出 −1520 的原因。

#Project layout

```
pyroduct/                  <- the module (riantr/pyroduct, 11 packages)
  src/                     <- 主体状态机（34 状态）+ 渲染
  multi/                   <- 多主体行为规则 R1–R14 + 遭遇引擎
  group/                   <- 群体状态机（涌现 + R7 回写）
  society/                 <- 双层次社会交往模型（从论文原文提取）
  ml/                      <- 自研 DoubleML（PLR / 交叉拟合 / 正交分数 / 推断）
  evolution/               <- 变异空间 / 适应度目标 / 更新闸门 / 持久化 / 遗传
  coordinator/             <- 科研 Agent 协调器（七件事）
  dmlref/                  <- 与 riantr/moonbit_doubleML 的对照层
  cmd/main/                <- CLI（wasm）
  cmd/coord/               <- CLI（native，真实落盘）
  tools/pdfdump/           <- 对 truth.pdf 的零依赖只读勘察记录
  examples/                <- 可运行示例（一例一包）
    plr/                   <- 外部 DGP + 外部 DoubleMLPLR
    irm/                   <- 外部 DGP + 外部 DoubleMLIRM
    cross_check/           <- 外部 DGP 上两实现互校
    consumer/              <- 库使用者的最小闭环
  moon.pkg                 <- 根包（只承载本 README；mooncakes 的 docs 按包渲染文档）
  moon.mod                 <- module manifest（riantr/pyroduct@0.1.1）
  README.mbt.md            <- this file
```

#Dependency rule

- 官方 `moonbitlang/*` 之外，只允许 `riantr/*`（本仓库）。
- 第三方依赖必须**隔离在单个包内**，并写明用途：
  - `moonbitlang/async@0.22.4` — 唯一消费者 `cmd/coord`（native，真实落盘）。
  - `riantr/moonbit_doubleML@0.64.0` — 唯一消费者 `dmlref`（互校自研 DoubleML）。
- 其余九个包不引入任何第三方库；`ml` 的 DoubleML 完全自研。

#Determinism & validation

- 全部随机性走固定种子（`ml` 的 splitmix64 `Rng`、`evolution` 的回合种子、外部包
  自己的 `seed=3141`）；同一份数据、同一组超参给出同一结果。
- 不变量由测试锁定：`society::no_final_closure()`（无终态且缺口处处可达）、
  `State::residue > 0`（残余恒正）、`evolution::constitutional()`（三条宪法级条款）、
  `coordinator::decision_ok()`（可修订 + 重开条件非空 + 残余归属有效）。
- 版本验证计数：`moon test` **77 / 77**（`wasm`）；`moon check` 与
  `moon fmt --check` 干净；`moon run --target native cmd/coord` 落盘往返一致。
- 外部互校：同 nuisance 下 `dmlref` 比对自研与 `riantr/moonbit_doubleML` 的 PLR，
  θ̂ 相差 0.017（se 0.153／0.152）。

#Attribution

- 文本来源：任勇祥《伽达默尔与哈贝马斯真理观比较》（上海社会科学院，2008）及其附录
  《通往宁静之路：个体道德发生论纲要》。模型中的每个构造都标注了该文的章／节／页，
  并对「原文直述」与「模型整理」做了明确区分（见 `society::render_report()` 的
  「与论文的边界」一节）。
- 外部参考实现：[`riantr/moonbit_doubleML`](https://gitee.com/ren-yongxiang/moonbit_doubleml)
  —— `doubleml-for-py` 的纯 MoonBit 移植（MIT；上游 BSD-3-Clause）。本仓库只在
  `dmlref` 中使用它的 `DoubleMLPLR` 做互校，不构成对其代码的再分发依赖。
- 本仓库 License：MIT（见仓库根目录 `LICENSE`）。

#Used By

- `cmd/main` —— 十四个子命令的报告入口。
- `cmd/coord` —— 把协调器运行时检查点写进磁盘的 native 样例。

#Caveats

- `wasm-gc` 与 `js` 后端**未实测**；`cmd/coord` 只在 `native` 上构建。
- `coordinator` 的「想」这一步是**确定性替身**，尚未接入 LLM；示例证据来自模拟回合，
  不是真实科研轨迹。
- `cmd/coord` 依赖 `moonbitlang/async` 仅为落盘；若要去掉该依赖，落盘可退化为
  「检查点字符串 + 重定向」。
