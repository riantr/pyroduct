# Pyroduct

![pyroduct](pyroduct.png)

一个可运行、可测试的 MoonBit 状态机族，以两部中文哲学文本为模——《通往宁静
之路：个体道德发生论纲要》及其母本《伽达默尔与哈贝马斯真理观比较》（上海社会
科学院，2008）——外加一个过闸进化的 Agent 状态机与一个科研 Agent 协调器。

一个主体：34 位置 · 53 迁移 · 11 阶段。一个群体：20 · 44 · 9。一个社会：
13 · 28 · 8。两个主体：14 条规范规则。

## 特性

* 纸面可执行，不是转述

  每个状态、迁移、阶段都是带出处的字面数据：`gloss()` 载原文措辞，每个构造都标注
  原文直述 或 模型整理。页码不在此列——`P.xx` 只在勘察记录真记下的地方出现
  （`multi`／`group`／`society`），主体机自己的表没有页码字段。

* 一种语言，四种单位

  主体／群体／社会 在三个尺度上共享同一套「状态 + 触发 + 迁移」词汇：
  `src`（34·53·11）、`group`（20·44·9，成员配置 → 涌现，R7 回写）、`society`
  （13·28·8，生活世界 vs 系统）。`multi` 是规范面：两个主体的 R1–R14——
  体制优先、有效性主张时序、两诚区分、解蔽—遮蔽——每条规则都引论文出处。

* 只用两字定名

  位置与阶段的定名只命名结构关系——不命名别的。这条纪律由测试锁定，并由
  `render_naming_table()` 打印。

* 驱动槽与执行契约

  `Trigger::slot` 用穷尽匹配把 49 个触发归入八个槽（处境／取向／先行／行动／
  反馈／持存／共在／揭蔽）——一个未归位的触发即编译失败。`step(位置, 槽)`
  只回答 迁／守／未定／同归／无路；在 272 个位置 × 槽组合中，228 个如实回答 无路。
  机器从不编造一个动作。

* 更新必须过闸门的 Agent

  `evolution` 把 Agent 的配置当作 `Genome`，枚举单步候选（提示／策略／记忆／
  代码），把「更好」写成 `Objective`，用宪法不变量圈起边界，并把每次
  接受／拒绝／回退连同理由记进一个只追加、可序列化的 `Ledger`。闸门有两档：
  手写权重，或 DoubleML 因果效应（θ̂ > 0 且 95% 下界 > 0）。主体循环
  `run_cycle` 按驱动槽驱动真实位置，把修习与开放送进同一个闸门——
  没有证据就不前进。

* 拒绝闭合的协调器

  `coordinator` 补上了状态机之外科研 Agent 需要的东西：任务与制品、依赖图上的
  规划、按置信区间（而非投票）判断的外部证据、保留被取代发现的内容记忆、
  带 IP 出处的署名，以及商谈／决策分段——交付物带修订标记、残余归属与重开
  条件。运行时可重放、可落盘。（「想」这一步仍是确定性替身，暂无 LLM。）

* 依赖隔离

  四个具名的第三方依赖，各自限于其消费者：`moonbitlang/async@0.22.4` →
  `cmd/coord`（native 落盘）；`riantr/moonbit_doubleML@0.75.0` → `dmlref` /
  `causal`；`riantr/snn_mbt@0.84.0` → `snnref`（native）；`riantr/
  moonbit_static_analysis@0.2.0` → `audit`。其余包只用官方 `moonbitlang/*`。

## 术语表

每个构造都带一个两字中文定名、一个英文枚举标识符，以及它所命名的原文。下表
是全部词汇的英文转译，覆盖三个尺度（主体／群体／社会）与规范层。

### 阶段——主体（11）

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

### 位置——主体（34）

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

### 驱动槽（8）与 49 个触发

| English | 定名 | 数 | Triggers |
|---|---|---|---|
| Occasion | 处境 | 6 | TakeStand, FeelFinitude, FeelBoundlessness, FuseFeelings, MustBeBusy, ColdHard |
| Orientation | 取向 | 6 | ChooseMoreLasting, Complexify, SeekMoreJoy, SeekBalance, SeekGoal, TakeModel |
| Antecedent | 先行 | 4 | TouchFuture, TryMethods, Approximate, WaitNext |
| Act | 行动 | 9 | ActInFreedom, BindSelf, Avoid, CutPast, SummonIdol, MarkGoodBad, RedrawMap, Endure, RemoveReefs |
| Feedback | 反馈 | 8 | Sting, BlameSelf, EnactOrder, AbsorbGlory, Reward, Dread, WidenFrontier, Ascend |
| Hold | 持存 | 8 | KeepContinuity, Deposit, TurnToResidue, Interweave, Surprise, Doubt, Linger, Habituate |
| CoBeing | 共在 | 3 | MeetOther, GoodFaith, OpenArms |
| Unveil | 揭蔽 | 5 | AttributeSelf, FillEmptiness, CoolDown, DoubtOneself, ReopenByHorizon |

### 执行契约（四种结果）

迁 Moved · 守 Held · 未定 Undecided · 无路 No-way

### 群体——阶段（9）

| 定名 | English | 读法 |
|---|---|---|
| 聚散 | Gathering | 众人只是一群，彼此尚无关联；群体还不是主体 |
| 成体 | Bodied | 共同的语言与商谈给群体一个身体 |
| 立序 | Ordering | 由理由或传统立起共同规矩 |
| 分歧 | Diverging | 差异被承认、体制相左、界域关闭 |
| 失度 | Excess | 第三者交给绝对者——投射、独白 |
| 自缚 | SelfBound | 群体把自己与成员一起束缚；隐成了不许问 |
| 受损 | Impaired | 集体的创伤与离散 |
| 修习 | Cultivating | 复归、忍受、扩界 |
| 宁定 | Resting | 每一对成员都双诚俱足；不再绝对化任何结论 |

### 群体——状态（20）

| 定名 | English | 阶段 |
|---|---|---|
| 散在 | Scattered | 聚散 |
| 趋同 | Converging | 聚散 |
| 共语 | CommonTongue | 成体 |
| 商谈 | Discourse | 成体 |
| 规范 | Normed | 立序 |
| 共识 | Consensus | 立序 |
| 歧见 | Dissensus | 分歧 |
| 对峙 | Confronting | 分歧 |
| 割据 | Partitioned | 分歧 |
| 投射 | Projected | 失度 |
| 独白 | Monologic | 失度 |
| 规训 | Disciplined | 自缚 |
| 遮蔽 | Concealed | 自缚 |
| 创伤 | Wounded | 受损 |
| 离散 | Dispersed | 受损 |
| 复归 | Returning | 修习 |
| 修习 | Practicing | 修习 |
| 扩界 | Widening | 修习 |
| 相契 | Attuned | 宁定 |
| 宁定 | Settled | 宁定 |

群体触发（22）：Appear, Attention, SharedMedium, RaiseClaims, NormFromTradition,
NormFromReason, Agree, Differ, Clash, CloseHorizon, Absolutize, OneVoice, Bind,
Suppress, Reopen, BreakUp, TurnBack, RemoveReefs, Widen, MutualCheng, Settle,
Reenter。

### 社会——阶段（8）

| 定名 | English | 读法 |
|---|---|---|
| 生活 | Life | 以语言组织的生活世界 |
| 语言 | Language | 超主体性（伽达默尔）对 主体间性（哈贝马斯） |
| 商谈 | Speech | 主张被提出、过滤、辩护、转为共识 |
| 规范 | Rule | 实践商谈立起的规范贴着「过去时」标签 |
| 缺口 | Aporia | 第三者在现实中不可能——乌托邦的命运 |
| 系统 | Instrument | 以金钱与权力为中介的系统 |
| 殖民 | Domination | 对生活世界的内在殖民化；被扭曲的交往 |
| 复建 | Rebuild | 重建被扭曲的交往领域 |

### 社会——状态（13）

| 定名 | English | 阶段 |
|---|---|---|
| 世界 | World | 生活 |
| 超体 | Suprasubjective | 语言 |
| 间性 | Intersubjective | 语言 |
| 主张 | Claim | 商谈 |
| 商谈 | Discourse | 商谈 |
| 辩护 | Justification | 商谈 |
| 共识 | Consensus | 商谈 |
| 规范 | Norm | 规范 |
| 缺口 | Gap | 缺口 |
| 系统 | System | 系统 |
| 殖民 | Colony | 殖民 |
| 扭曲 | Distortion | 殖民 |
| 重建 | Reconstruction | 复建 |

社会触发（18）：SpeakLanguage, BuildIntersubjective, RaiseClaims, EnterDiscourse,
Filter, Justify, Subsume, Store, EnactNorm, LabelPast, DemandThird, Serve,
Expand, Colonize, Distort, Hinder, Reconstruct, Circulate。

### 真理体制（5）· 商谈类型（4）· 有效性主张（4）

| 定名 | English | 读法 |
|---|---|---|
| 内在秩序 | Immanent | 真理是内在于世界的永恒秩序（古埃及） |
| 逻各斯 | Logos | 真理是永恒的言说，靠理性灵魂保障（古希腊） |
| 超主体性 | SuperSubjective | 伽达默尔：理解与语言是超主体事件 |
| 主体间性 | InterSubjective | 哈贝马斯：真理即主体间有效性主张，横纵成网 |
| 诚然 | ChengRan | 作者方案：诚然的诠释学，统于自性内照 |

| 定名 | English |
|---|---|
| 理论商谈 | Theoretical |
| 实践商谈 | Practical |
| 表达性商谈 | Aesthetic |
| 信仰商谈 | Faith |

| 定名 | English | 主张 |
|---|---|---|
| 真实性 | Truthfulness | 命题真实性——客观世界 |
| 正当性 | Legitimacy | 规范正确性——社会世界 |
| 他之诚 | Authenticity | 言语内容之契合（本真性） |
| 己之诚 | Sincerity | 行为与意向之契合（真诚性） |

主张时序：事前 Before · 事中 During · 事后 After。

### 规范规则 R1–R14

| 编号 | 定名 | English |
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

### 包

`src`（主体机）· `multi`（规范规则）· `group`（群体涌现）· `society`（双层
社会模型）· `ml`（自研 DoubleML）· `evolution`（Agent 状态机）· `coordinator`
（科研 Agent 运行时）· `dmlref`（外部互校）· `causal`（因果诊断）· `audit`
（三鉴静态审计，0.1.28 起扩到群体机与社会机，另有 `fleet`／`mutants` 两个面
——变异网用 18 处故意的破坏证明「0 条发现」不是「什么都看不见」）· `snnref`
（脉冲沉淀实验）。

### 纪律用语

原文直述 *verbatim from the source* · 模型整理 *model reconstruction* · 两诚
*two sincerities* · 解蔽—遮蔽 *unconcealment–concealment* · 没有证据就不前进
*no evidence, no advance* · 双诚之比 *two-sincerity ratio* · 同判·不重裁
*same verdict, not re-adjudicated* · 三鉴 *three mirrors (structure / type /
behavior)* · 往返一致 *round-trips identically*。

## 快速开始

添加模块，然后跑测试套件：

```
moon add riantr/pyroduct
moon test             # Total tests: 192, passed: 192, failed: 0.
```

在本仓库里，每一层都打印一份报告：

```
moon run cmd/main -- report        # 主体状态机
moon run cmd/main -- slots         # 驱动槽：49 个触发 → 8 个槽
moon run cmd/main -- multi         # 规范规则 R1–R14 + 场景
moon run cmd/main -- group         # 群体状态机
moon run cmd/main -- society       # 双层次社会交往模型
moon run cmd/main -- evolution     # 变异／适应度／闸门／持久化／遗传
moon run cmd/main -- cycle         # 主体循环：位置 × 驱动槽 × 因果反馈
moon run cmd/main -- coordinator   # 科研 Agent 协调器
moon run --target native cmd/coord # 真实落盘：检查点往返一致
```

## 示例

```moonbit nocheck
// 主体：位置、主线、驱动槽、执行契约
let states : Array[@src.SubjectState] = @src.all_states()      // 34 个
let ok     : Bool = @src.reachable(@src.initial(), @src.terminal())
let moved  : @src.Outcome = @src.step(@src.Standing, @src.Occasion) // 迁

// 两个主体的一次遭遇：体制、两诚、有效性主张的时序都参与裁决
let me    = @multi.subject(1, @multi.rendezvous(), @multi.InterSubjective, 70, 70, 9)
let other = @multi.subject(2, @multi.rendezvous(), @multi.ChengRan, 80, 80, 9)
let claim : @multi.ValidityClaim = { kind: @multi.Truthfulness, phase: @multi.During }
let out   = @multi.encounter(me, other, @multi.Theoretical, claim)

// 社会：两条不变量由测试锁定
let never_closes : Bool = @society.no_final_closure()

// Agent 状态机：枚举候选 → 过闸 → 只追加记账
let agent  = @evolution.default_agent()
let ledger = @evolution.evolve(agent, @evolution.default_world(),
                               @evolution.Weighted(@evolution.truth_objective()), 3)

// 协调器：跑一段示例研究，检查点写下 / 读回
let rt   = @coordinator.new_runtime()
ignore(rt.step(@coordinator.demo_tasks(), @coordinator.demo_questions(),
               @coordinator.demo_workers(), @coordinator.demo_datasets(),
               @coordinator.demo_world(), @coordinator.demo_parent(),
               @coordinator.demo_candidate()))
let restored = @coordinator.restore(rt.checkpoint())
let same : Bool = restored.round_trips()
```

## 被谁使用

- `cmd/main` — 上面每一层的报告入口：`report` / `slots` / `multi` / `group` /
  `society` / `evolution` / `cycle` / `coordinator`，外加 `mermaid` / `dot` /
  `genesis` / `course` / `naming` / `principle` / `all`。
- `cmd/coord` — 一个 native 二进制，运行协调器并把其检查点经真实磁盘 I/O
  往返（`.openseek/`，gitignored）。

## 出处

- 源文本：任勇祥《伽达默尔与哈贝马斯真理观比较》（上海社会科学院，2008）及其
  附录《通往宁静之路：个体道德发生论纲要》。模型中的每个构造都标注了该文的
  章／节／页，并对 原文直述 与 模型整理 做了明确区分。
- License: MIT（见 `LICENSE`）。
