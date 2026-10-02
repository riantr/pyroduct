# Pyroduct 仓库总览（skill 参考）

模块 `riantr/pyroduct`，15 个包一个模块。完整文档在仓库根 `README.mbt.md` 与
`AGENTS.md`（后者面向维护者，含门禁与纪律）。

## 包布局

| 包 | 单位 | 内容 |
|---|---|---|
| `src` | 一个主体 | 主体状态机（34 状态 · 53 迁移 · 11 阶段）+ 驱动槽八分（`slot.mbt`）+ 执行契约（`loop.mbt`：`step` → 迁/守/未定/无路）+ 渲染 |
| `multi` | 两个主体 | 规范规则 R1–R14、`TruthRegime`、有效性主张 schema、`encounter` 判词 |
| `group` | 一个群体 | 涌现状态机（20 状态），成员配置 → 群体状态，R7 回写 |
| `society` | 一个社会 | 双层次社会交往模型（13 状态），生活世界 vs 系统 |
| `ml` | — | 自研 DoubleML（PLR、交叉拟合、正交分数、推断）、RNG、线性代数 |
| `evolution` | 一个 agent | `Genome`、变异、`Objective`、更新闸门（加权或 DoubleML 因果）、只追加 `Ledger`、遗传；主体循环（`cycle.mbt`） |
| `coordinator` | 科研 agent | 任务/制品、规划、按置信区间的外部证据、内容记忆、署名、商谈/决策分段、可重放运行时 |
| `dmlref` | — | 自研 DoubleML 与 `riantr/moonbit_doubleML@0.64.0` 的互校 |
| `cmd/main` | — | wasm CLI（十七个子命令） |
| `cmd/coord` | — | native CLI，真实落盘（`supported_targets = "+native"`） |
| `tools/pdfdump` | — | 源 PDF 的只读勘察记录 |
| `examples/*` | — | 每包一个可运行示例 |

## 依赖规则（按约定执行）

- 官方 `moonbitlang/*` 之外只允许 `riantr/*`。
- `moonbitlang/async@0.22.4` 唯一消费者 `cmd/coord`；`riantr/moonbit_doubleML@0.64.0`
  唯一消费者 `dmlref`。
- `src/moon.pkg` **零 import**——永不给 `src` 加环境、RNG 或数值依赖；槽内容的
  生产者在其上的层。
- 一方依赖只向下指（`evolution` 以 `@sm` 引 `src`）。

## 门禁

```console
moon check                              # 类型/告警检查
moon test                               # 全部测试（wasm），当前 95/95
moon fmt --check                        # 格式必须干净
moon run --target native cmd/coord      # 检查点落盘往返（往返一致 true）
```

## 确定性

全部随机性走固定种子（`ml` 的 splitmix64、evolution 回合种子、外部 `seed=3141`）。
同一数据、同一超参永远同一结果——引用输出时无需担心波动。
