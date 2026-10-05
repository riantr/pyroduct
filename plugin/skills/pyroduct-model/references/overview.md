# Pyroduct 仓库总览（skill 参考）

模块 `riantr/pyroduct`，20 个包一个模块（含模块根与 5 个示例）。完整文档在仓库根
`README.mbt.md`（英）、`README.zh.mbt.md`（中）——两份都带三尺度中英术语表——
与 `AGENTS.md`（后者面向维护者，含门禁与纪律）。

## 包布局

| 包 | 单位 | 内容 |
|---|---|---|
| `src` | 一个主体 | 主体状态机（34 状态 · 53 迁移 · 11 阶段）+ 驱动槽八分（`slot.mbt`）+ 执行契约（`loop.mbt`：`step` → 迁/守/未定/同归/无路，`step_by_trigger` 认单句）+ 渲染 |
| `multi` | 两个主体 | 规范规则 R1–R14、`TruthRegime`、有效性主张 schema、`encounter` 判词 |
| `group` | 一个群体 | 涌现状态机（20 状态），成员配置 → 群体状态，R7 回写 |
| `society` | 一个社会 | 双层次社会交往模型（13 状态），生活世界 vs 系统 |
| `ml` | — | 自研 DoubleML（PLR、交叉拟合、正交分数、推断）、RNG、线性代数 |
| `evolution` | 一个 agent | `Genome`、变异、`Objective`、更新闸门（加权或 DoubleML 因果）、只追加 `Ledger`、遗传；主体循环（`cycle.mbt`） |
| `coordinator` | 科研 agent | 任务/制品、规划、按置信区间的外部证据、内容记忆、署名、商谈/决策分段、可重放运行时 |
| `dmlref` | — | 自研 DoubleML 与 `riantr/moonbit_doubleML@0.75.0` 的互校 |
| `causal` | 一份数据 | 0.75.0 深用诊断（只读，数据来自状态机）：敏感性（Cinelli–Hazlett rv）、多重检验校正（BH/Bonferroni——天真 OLS 也过线，显著性≠证据）、BLP 异质性（d̃ 回收 θ̂）；标模型整理 |
| `audit` | 一台机器 | 三鉴自审计：真实主体机的表 → 纯数据 MachineSpec → 结构鉴／类型鉴／行为鉴（库的 moon.mod 点名 pyroduct 为参考消费者；「鉴」兼照镜与审察）；发现分已知设计（无忆／无筹只出不进，0.1.2 已验证）与未预期（必须为零——活的绊线）；标模型整理 |
| `snnref` | 一个实验 | 脉冲沉淀实验（native 专属）：49 触发 → Poisson spike trains（槽内共现高率）→ Gerstner STDP → 权重结构能否恢复驱动槽八分（比值、命中率对基线、分槽表）；标模型整理 |
| `audit` 的另两台 | 两台机器 | 0.1.28：同一套三鉴扩到群体机（20 状态·42 迁移）与社会机（13 状态·26 迁移）。两台机**没有驱动槽**（驱动就是触发本身）与**没有终点**（不封闭是结构事实），故类型鉴的槽层整层跳过、`terminal` 留空；真表上未预期 0 条且**不设豁免**。另有 `mutants`：三台机×六族破坏共 18 处，逐处被抓——「0 条发现」需要证据才站得住。标模型整理 |
| `viz` | — | 纯呈现：四台机的 Mermaid 源码 + 一页自包含 HTML（视时才拉 mermaid.js CDN，构建零网络） |
| `cmd/main` | — | wasm CLI（三十五个子命令） |
| `cmd/coord` | — | native CLI，真实落盘（`supported_targets = "+native"`） |
| `cmd/jsoncli` | — | 插件桥（js 目标）：一个 `{kind}` JSON 请求入、一行 `{ok,kind,rendered,faces}` JSON 回信出——本插件与 dsh 插件共用的 spawner 面 |
| `tools/pdfdump` | — | 源 PDF 的只读勘察记录 |
| `examples/*` | — | 每包一个可运行示例（`sediment` 为 native 专属） |

## 依赖规则（按约定执行）

- 官方 `moonbitlang/*` 之外只允许 `riantr/*`。
- `moonbitlang/async@0.22.4` 唯一消费者 `cmd/coord`；`riantr/moonbit_doubleML@0.75.0`
  消费者 `dmlref`（互校）与 `causal`（0.75.0 深用诊断，只读）；
  `riantr/snn_mbt@0.84.0`（连带 `riantr/moonbit_image@0.3.4`）
  唯一消费者 `snnref`——`snn_mbt` 只声明 native 目标，`snnref` 与 `examples/sediment`
  随之 `+native`，wasm 门禁自动跳过，须单独 `moon test --target native snnref`；
  `riantr/moonbit_static_analysis@0.1.0` 唯一消费者 `audit`（三鉴自审计——库的
  moon.mod 点名 pyroduct 为参考消费者，`src` 保持零 import，表在 `audit` 层转
  纯数据）。
- `src/moon.pkg` **零 import**——永不给 `src` 加环境、RNG 或数值依赖；槽内容的
  生产者在其上的层。
- 一方依赖只向下指（`evolution` 以 `@sm` 引 `src`）。

## 门禁

```console
moon check                              # 类型/告警检查
moon test                               # 全部测试（wasm），当前 176/176 + snnref 2（native）
moon test --target native snnref        # 脉冲沉淀实验（native 专属）
moon fmt --check                        # 格式必须干净
moon run --target native cmd/coord      # 检查点落盘往返（往返一致 true）
moon run --target native examples/sediment  # 脉冲沉淀实验报告
```

## 确定性

全部随机性走固定种子（`ml` 的 splitmix64、evolution 回合种子、外部 `seed=3141`）。
同一数据、同一超参永远同一结果——引用输出时无需担心波动。
