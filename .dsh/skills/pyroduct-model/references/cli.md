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
| `audit` | 三棱镜自审计（模型整理）：34 状态·53 迁移·49 触发→8 槽·228 无路·31 站历程进 MachineSpec；结构／类型／行为三棱镜；4 条已知设计（无忆／无筹只出不进）+ 0 条未预期（活的绊线：篡改历程一步立刻报警） |
| —（native 示例） | `moon run --target native examples/sediment`：脉冲沉淀实验——49 触发 → spike trains → Gerstner STDP → 能否恢复驱动槽八分（模型整理；`snn_mbt` 只支持 native） |
| `mermaid` / `dot` | 状态图源码（可直接粘进渲染器） |
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
let slot = @src.Trigger::FeelFinitude.slot()          // 处境
let back = @src.step(@src.Standing, @src.Occasion)    // 迁（落到 自由）
let gaps = @src.gaps()                                // 无路组合
let led  = @evolution.evolve(@evolution.default_agent(), @evolution.default_world(),
                             @evolution.Weighted(@evolution.truth_objective()), 3)
```
