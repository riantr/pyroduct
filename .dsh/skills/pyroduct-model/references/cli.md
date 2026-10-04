# Pyroduct CLI 全表（skill 参考）

`moon run cmd/main -- <sub>`（wasm 目标，秒级、零网络、固定种子）。
另一入口 `moon run --target native cmd/coord`：跑协调器并把检查点写入
`.openseek/coordinator-state.txt`，打印「往返一致 true」。

## 子命令

| 子命令 | 输出要点 |
|---|---|
| `report`（默认） | 主体状态机全文报告：34 状态定名表（定名｜原文措辞｜出处层）、11 阶段、53 迁移、驱动槽统计、执行契约摘要 |
| `slots` | 驱动槽归位表：八个槽的定义与出处层，49 个触发逐条归位（按迁移表顺序） |
| `loop` | 执行契约：272 个「位置 × 槽」组合中每槽可推动的位置数、四类回执的统计、缺口表（228 个无路组合，按槽 × 位置列出）、四个仅行动出口 |
| `multi` | R1–R14 规则清单 + 场景：一次遭遇从主张到判词（体制 × 两诚 × 相位） |
| `group` | 群体状态机：成员配置 → 涌现状态（20 状态），R7 回写 |
| `society` | 双层次社会交往模型（13 状态）：生活世界/系统/交往各状态逐条出处 |
| `evolution` | 变异空间、适应度目标、宪法条款、闸门判据、账本样例 |
| `cycle` | 主体循环逐回合：回应 → 驱动槽 → 迁移 → 修习/开放判词（θ̂、95% CI、真值、朴素差）→ 足迹 |
| `coordinator` | 协调器八节：任务/问题/工人/数据集/世界/父任务/候选 → 规划与决策 |
| `dmlref` | 自研与外部 DoubleML 同 nuisance 对照（θ̂ 差、se 差） |
| `causal` | 0.75.0 深用诊断（模型整理）：敏感性 rv＝|θ̂|/max_bias；BH/Bonferroni 校正——天真 OLS 同样「显著」，显著性≠证据；BLP 异质性（d̃ 回收 θ̂，交互维不显著＝均匀效应发现） |
| `audit` | 三鉴自审计（模型整理）：34 状态·53 迁移·49 触发→8 槽·228 无路·31 站历程进 MachineSpec；结构鉴／类型鉴／行为鉴三鉴；4 条已知设计（无忆／无筹只出不进）+ 0 条未预期（活的绊线：篡改历程一步立刻报警） |
| —（native 示例） | `moon run --target native examples/sediment`：脉冲沉淀实验——49 触发 → spike trains → Gerstner STDP → 能否恢复驱动槽八分（模型整理；`snn_mbt` 只支持 native） |
| `mermaid` / `dot` | 状态图源码（可直接粘进渲染器；声明式 ASCII 节点 id + 中文定名） |
| `society-mermaid` / `group-mermaid` | 上者／群体机的 Mermaid 源码 |
| `nested-mermaid` | 嵌套视图：11 阶段为复合状态（容器），迁移照旧跨容器连边（模型整理） |
| `journey` | 行程视图：一次示范行走（从立位按八槽巡回三轮）真正走过的边；未定/无路只以注释说明，当下/缺口/未定位置样式标注（模型整理） |
| `viz` | 三台机 + 嵌套视图 + 行程视图汇成一页自包含 HTML（`moon run cmd/main -- viz > viz.html`，浏览器直开；mermaid.js 仅视时 CDN，构建零网络） |
| `spec` | 规格导出：主体机即 JSON 数据（`$schema` 版本标记；states 按定名键控带原文名与阶段；phases 嵌套；slots；transitions 带 event=原文触发句 + slot=槽归位；`spec_vocabulary` 词汇表防漂移；参照 python-statemachine 的 io/中立 IR，方向反转为机器→规格；模型整理） |
| `association` | 未定的软关联（JPDA 面镜像，模型整理）：机器全部 5 个并存组合逐条给 β 权重（Σ=1）与香农熵（bit）；权重＝双诚分量的归一化（首条=己之诚/时间侧、末条=他之诚/空间侧）；活绊线＝硬裁决（双诚之比挑首/末）与软分布 argmax 逐个一致；诊断面，不采样、不推进位置——「未定不掷骰子」照旧 |
| `pathsum` | 泛半环路径和（参照 FiniteStateTransducers.jl，OpenFST 谱系；模型整理）：机器三性质（`is_deterministic` 触发粒度确定=true、`is_acyclic`=false 有意成环、无 ε 弧＝acceptor）+ 每位置到宁静的最短路阶梯（tropical `min_steps`/`distance_to`，reversed BFS 一次得全表；无忆 30 步 → 修习 1 步 → 宁静 0 步，0 处不可达；`min_steps(宁静, 反顾)=1` 重入边）；半环词汇＝本仓库已横跨 Boolean（reachable/gaps）/ Tropical（本文件）/ Probability（evolution β） |
| `algebra` | 机器代数（Ragel 面；模型整理）：算子映射（相接↔主线 30 站 + 重入反顾、并↔5 处槽粒度并存、星↔17 条自环、环↔宁静→反顾、确定化不需要、err↔Block 缺口诚实版、动作嵌入↔gloss 出处不适用）+ 主线分解（全状态 − 主线 = 无忆/无筹/畏怖/疏离四处）+ 最小商（`minimal_quotient`：31 块恰 = course 长度——主线就是最小商；三对孪生是设计：受赏≡畏怖、无忆≡无筹、紧迫≡疏离，原文以不同触发区分来处、机器以相同行为识别去处） |
| `petri` | Petri 网面（CarlAdam 镜像；模型整理）：库所↔34 位置、变迁↔迁移表 53 行（一对一，托肯守恒）、不可变 `PetriMarking`（`enabled`/`fire` 返回一收一发的 Consume/Produce 效果与新标识）、双托肯并发演示（multi 的结构对准：立位与宁静两个托肯各自走一步）、判读（228 缺口=没有变迁即结构、未定=结构冲突仲裁不在 src、着色=基因组记档不落码） |
| `aho` | 回忆结构（Aho-Corasick 面，参照 pyahocorasick；模型整理）：49 条触发句建成前缀树（833 节点、832 边、最长句 33 字）+ 155 条非平凡失败链（读入失败退回最长的共同过去——回忆的算法形态）+ 输出合并（同一刻涌现多条已往）；结构事实：最深的回忆者是「地图失效」句（31 字），其后缀「过」恰是「过往的一切变成残渣…」的开头（地图被推翻之处正是已往沉积之处）；最深分叉「无法」2 字（遭遇/善意的两句）；49/49 自扫描、句中包含他句 0 处；判读（无忆无筹=根节点失败链指自己、线性扫描=已往不被重过只被换一种读法接住） |
| `genesis` / `course` | 原文顺序主线 / 可重入环节序列 |
| `naming` / `principle` | 定名对照表 / 主体通用性原则（R1–R3） |
| `intuition` | 直觉读法：裁决备忘录读成背景直觉的仓库（模型整理；四条纪律：出处可查、在接触中存活或破碎、出处层即稳固度、不编造命中） |
| `ml` / `ml-export` | DoubleML 接口与因果实验说明 / 数据集 CSV |
| `all` | 报告 + 历程 + Mermaid |

## 典型输出行（引用时可照抄格式）

- `汇总：处境 6 · 取向 6 · 先行 4 · 行动 9 · 反馈 8 · 持存 8 · 共在 3 · 揭蔽 5`
- `位置 34 × 槽 8 = 272 个组合，其中 228 个无出边（记为 Block，不编造下一步）。`
- `自身 --持存--> 自身（守）`
- `账本：12 条只追加；接收 0 条 · 拒收 0 条；往返一致 = true`

## 从 MoonBit 代码调用（库使用者）

```moonbit nocheck
let ok   = @src.reachable(@src.initial(), @src.terminal())
let slot = @src.FeelFinitude.slot()                   // 处境
let back = @src.step(@src.Standing, @src.Occasion)    // 迁（落到 自由）
let gaps = @src.gaps()                                // 无路组合
let trace = @src.walk(@src.initial(), [@src.Act, @src.Occasion])
let det  = trace.detailed()                           // Step{from, slot, outcome}
let nest = @src.render_mermaid_nested()               // 嵌套视图（阶段为容器）
let jrn  = @src.render_mermaid_journey(trace)         // 行程视图（局部 + 样式）
let led  = @evolution.evolve(@evolution.default_agent(), @evolution.default_world(),
                             @evolution.Weighted(@evolution.truth_objective()), 3)
```
