# 工具与面目录（skill 参考）

插件的 MCP server 名 `pyroduct`，三个工具全是只读、无副作用。

## 桥的形状

每次调用都是 spawn 一次 `cmd/jsoncli` 的 JS bundle：

1. 传**一个** JSON 请求参数，例如 `{"kind":"petri"}`；
2. 从 stdout 读**一行** JSON 回信 `{ok, kind, rendered, faces}`；
3. 把 `rendered` 当作工具文本输出。

答案来源两种，回信里会写明：

| 来源 | 条件 | 含义 |
|---|---|---|
| 内置快照 | 没配 `PYRODUCT_PROJECT_DIR` | `vendor/jsoncli.js`，随插件定版（见 `vendor/BUILD.json`）；不需要 MoonBit 工具链，机器是只读的 |
| 本地 checkout | 设了 `PYRODUCT_PROJECT_DIR` | 该 checkout 的 `_build/js/.../jsoncli.js`，缺则自动 `moon build --target js`；`pyroduct_gates` 也在这个 checkout 里跑 |

环境变量：`PYRODUCT_PROJECT_DIR`（checkout 根）、`PYRODUCT_MOON`（moon 可执行）、
`PYRODUCT_NODE`（跑 bundle 的 Node；默认用当前解释器）。

## 三个工具

### `pyroduct_faces()`

无参数。返回 30 面目录（每面一行读法）、模型版本与本次来源。**这是索引，不是内容**——
想知道机器说了什么，还是得调 `pyroduct_face`。

### `pyroduct_face(kind)`

`kind` 必填，取下面目录里的名字；名字不对时工具回 `isError` 并列出全部合法名
（不回 Python traceback，也不猜一个相近的面跑）。

### `pyroduct_gates()`

无参数。在配置的 checkout 里依次跑 `moon check`、`moon fmt --check`、`moon test`，
返回每条命令的退出码与输出末尾四行，末尾给一句门禁结论。没有 checkout 时它**不报错**，
而是说门禁不可用、需要设哪个环境变量——门禁不存在与门禁不通过是两件事，不要混读。

## 30 面速查（按提问选面）

| 提问长这样 | 取哪个面 |
|---|---|
| 「这台机器有多大／叫什么／出处」 | `report`（34 位置 · 53 迁移 · 11 阶段，各阶段下列位置与原文措辞，末节「派生表与持久度」给出处层） |
| 「这句话归哪个槽」 | `slots`（49 触发 → 8 槽） |
| 「在这个位置，这个槽推得动吗」 | `loop`（272 组合：迁／守／未定／同归／无路，228 无路；末节列 3 处同归组合，7 条触发句同归一处） |
| 「两人相遇会怎样判」 | `multi`（R1–R14，体制 × 两诚 × 主张时序 → 判词） |
| 「一群人会涌现出什么状态」 | `group`（20 状态，R7 回写） |
| 「生活世界与系统怎么交往」 | `society`（13 状态，双层次） |
| 「这个 agent 怎么变／过不过闸」 | `evolution` |
| 「主体走一轮为什么停住」 | `cycle`（位置 × 槽 → 修习／开放两候选过同一闸门） |
| 「科研 agent 怎么裁决」 | `coordinator` |
| 「自研 DoubleML 靠不靠谱」 | `dmlref`（与外部 0.75.0 互校） |
| 「这个估计有多稳／多重检验怎么看」 | `causal`（敏感性 rv、BH/Bonferroni、BLP 异质性；模型整理） |
| 「把机器当程序审一遍」 | `audit`（结构鉴／类型鉴／行为鉴；未预期必须 0） |
| 「群体／社会那两台机审过没有」 | `fleet`（同一套三鉴；两台机无槽无终点，口径不同） |
| 「这审计真能看见问题吗／0 条发现可信吗」 | `mutants`（18 处故意的破坏，逐处被抓） |
| 「机器的图」 | `mermaid`（状态图）／`dot`（Graphviz） |
| 「主线／环节／定名／原则」 | `genesis`／`course`／`naming`（定名｜原文名｜原文措辞）／`principle` |
| 「裁决备忘录怎么读」 | `intuition`（背景直觉仓库；模型整理） |
| 「ML 接口与数据集长什么样」 | `ml`／`ml-export` |
| 「要机器的 JSON／词汇表」 | `spec` |
| 「未定的那几条出路有多像」 | `association`（β 权重／熵／argmax 一致性；不采样不推进） |
| 「离宁静还有几步」 | `pathsum`（tropical 最短路阶梯＋三条性质） |
| 「机器能合并成几个等价类」 | `algebra`（算子映射／主线分解／最小商 31 块） |
| 「并发与冲突怎么看」 | `petri`（库所 34／变迁 53／托肯守恒／发火） |
| 「回忆是怎么被读回来的」 | `aho`（前缀树／失败链／输出合并） |
| 「这台机器会不会停死」 | `buchi`（非空性／活性潜势／停滞词） |

呈现层（`viz` 合成页、`journey` 行程视图、`nested-mermaid`、`all`）**不在桥里**——
它们是渲染不是模型事实，要跑用 CLI（见 [CLI 全表](cli.md)）。

## 出处层在哪儿读

**不是每面都印出处层。** 可读的标注只有两处：`report` 末节「派生表与持久度」逐表给
`消费 原文直述 / 原文直述＋混合＋模型整理`，`slots` 逐槽给同一组标注。`naming` 只给
定名｜原文名｜原文措辞，`multi`／`cycle` 等面不带层标注——要交代出处层，回前两面读。

- **原文直述**：34 位置、53 迁移、11 阶段、两字定名、49 条触发句、R1–R14 措辞。
- **模型整理**：驱动槽八分（8 分 49 句的归位是本仓库的选择）、位置 × 槽的循环映射、
  五条分析面（pathsum／algebra／petri／aho／buchi）、三鉴自审计、因果诊断。

两层混起来读是本模型最容易出的错：`slots` 的归位是模型整理，但 49 条句子本身是原文。

## 页码在哪儿

**页码出处只印在四处**：`multi`、`group`、`society` 的 gloss 带
`P.xx`（连 `P.49-50` 这样的跨页），`intuition` 印出 evolution 那三处。主体机自己的表**没有页码
字段**——`report`／`slots`／`naming`／`spec` 与五条分析面给得出处层与原文措辞，
给不出页码。要页码就去那四面，别在主体机的报告里找，也别自己补一个。

