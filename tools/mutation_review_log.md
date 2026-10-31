# 变异表判定记录（生成物，勿手改）

这张表是 `python tools/mutate_review.py` 的**输出留档**，为的是让
「每条变异都被判据抓住」这句话不必靠重跑一次破坏工作树的运行来核对。
重跑方式：`python tools/mutate_review.py`（88 条变异 × 全量测试，约 11-13 分钟）。
本文件**只由全量跑生成**。`python tools/mutate_review.py loop3` 这样的单组跑会
另写 `mutation_review_log.loop3.md`，不会碰这份——单组跑曾经把这份全量记录
覆盖成自己那几行，而我把截断版提交了；工具静默毁掉自己的记录比没有工具更糟。

判读五态：
- `CAUGHT` + 失败数 > 0 —— 判据真的变红了。这是要的结果。
- `COMPILE-ERROR` —— 变异在**编译期**被拒。这**不是**抓取：它证明的是语法，
  不是判据有牙齿。首版四条 `arr[..n]` 切片死在这里，全部重写后才算数。
- `ANCHOR-ERROR` —— 源码形状与表里记的不符（改动导致锚点漂移）。不是抓取，
  得先修表。
- `LEAK-ERROR` —— 施加这条之前工作树就不干净，说明上一条没还原。不是判定，
  是 harness 的错；它存在是为了让那种错当场炸，而不是静默产出假数字。
- `SURVIVED` —— 变异活着。必须归类为「等价」或「具名缺口」，不能悬着。

纪律三条：变异必须**编译得过**（见上）；每条必须在**干净**的工作树上测
（换文件的条目不还原上一条，失败会算到别人头上——B4 曾记着 A5 的 failed=3）；
每条结束时校验 sha256 与开跑前一致——改源码的脚本要自己证明没留痕迹。



机 | 变异 | 判定 | 详情 |
|---|---|---|---|
| BASELINE (no mutation) | 0 | Total tests: 250, passed: 250, failed: 0 |
| A1 step 在同归组合上点名第一条（旧行为） | CAUGHT | Total tests: 250, passed: 240, failed: 10 |
| A2 Same 不给落点（回执不再推进行程） | CAUGHT | Total tests: 250, passed: 247, failed: 3 |
| A3 有歧义时替表挑一条（不猜→猜） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| A4 去重检查恒真（表有歧义也不报） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| A5 same_target_pairs 把未定也算成同归 | CAUGHT | Total tests: 250, passed: 247, failed: 3 |
| B1 group::step 去掉并列分支（一句触发两个去处被抹平） | CAUGHT | Total tests: 250, passed: 244, failed: 6 |
| B2 group::step 给缺口编造一条出边 | CAUGHT | Total tests: 250, passed: 246, failed: 4 |
| B3 group::open_pairs 返回空（那句数据问题被藏起来） | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| B4 group::no_dead_end_of 恒真（不封闭的检查不再跑） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| B5 society::one_edge_each 去掉去重（触发粒度的确定性不再被锁） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| B6 society::no_dead_end_of 恒真（不封闭的检查不再跑） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| M1 缺口被编造出一条边 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| M2 同归只点名第一条 | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| M3 同归被当成未定展开 | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| M4 缺口处终止分支 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| M5 after_open 起点步数偏一 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| M6 after_open 去掉深度闸 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| M7 push_step 共用同一份行程（别名） | CAUGHT | Total tests: 250, passed: 246, failed: 4 |
| M8 撞界不报 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| M9 open_points 把同归也算成未定点 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| S1 状态少导出一个 | CAUGHT | Total tests: 250, passed: 247, failed: 3 |
| S2 迁移少导出一条 | CAUGHT | Total tests: 250, passed: 246, failed: 4 |
| S3 迁移的 from 写成 to | CAUGHT | Total tests: 250, passed: 247, failed: 3 |
| S4 原文名写成定名 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| S5 阶段成员漏一个 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| S6 槽少导出一个 | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| L1 群体规格少导一条迁移 | CAUGHT | Total tests: 250, passed: 246, failed: 4 |
| L2 群体规格起点写错 | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| L3 三鉴发现不分层（全部塞进已知设计） | CAUGHT | Total tests: 250, passed: 247, failed: 3 |
| L4 变异网少一族 | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| L5 「填一个不可达终点」这一族变成空操作 | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| L6 变异网期望家族写错（条件布尔 → 方法错） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| L7 「删掉一条迁移」这一族不再删 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| L8 设计图少一条接口 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| L9 着色声明去掉「不实现」 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| E1 修习 读回 Discipline（与群体规训 Disciplined 撞车） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| E2 交织 读回 Weaving（丢掉「互」） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| E3 自缚 读回 Binding（丢掉「自」） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| E4 处境 读回 Occasion（occasion 是特定场合，不是境况） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| E5 先行 读回 Anticipation（说的是心态，不是结构关系） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| E6 阶段 读回描述短语（会随成员变化悄悄过期） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| E7 无路 读回 No Edge（edge 与「界域 frontier」撞车） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| E8 群体修习阶段 读回 Cultivating（一个定名两个英文词） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| E9 成体 读回 Coming to a Body（阶段名里唯一的长句） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| E10 群体自缚 读回 Self-bound（与主体侧 Self-binding 不同源） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| E11 修习位置 gloss 退回 discipline（与本次改名自相矛盾） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| E12 群体修习 gloss 退回 discipline（与 group/en.mbt 的规则相矛盾） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| P1 src::exitable 恒真（缺口那侧不再被认出来） | CAUGHT | Total tests: 250, passed: 246, failed: 4 |
| P2 src::every_phase_has_non_act_of 恒真 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| P3 src::any_returns_to 恒真（非空性不再被检查） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| P4 src::all_covered 恒真（活性潜势不再被检查） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| P5 src::is_deterministic 反相（答案不是来自那次检查） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| P6 society::no_final_closure_of 恒真（两条 false 臂都不再跑） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| P7 group::resolve_open 两种偏向取同一条（能耗原则不成立） | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| P8 evolution::group_lean_of 偏向反相（双诚之比读反了） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| P9 震荡边只剩单向（共语上不再冒出有效性主张） | CAUGHT | Total tests: 250, passed: 244, failed: 6 |
| P10 震荡边接反（超体与间体倒置） | CAUGHT | Total tests: 250, passed: 245, failed: 5 |
| P11 社会两相震荡只剩单向（超体上不再冒出有效性主张） | CAUGHT | Total tests: 250, passed: 245, failed: 5 |
| P12 社会两相震荡边接反（超体与间体倒置） | CAUGHT | Total tests: 250, passed: 246, failed: 4 |
| P13 society::ambiguous 恒假（并列永远看不见） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| A1 闸门指纹恒定（两条不同的尺子算出同一串） | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| A2 尺子比较恒不成立（尺子动过也看不见） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| A3 重裁不比对判词（重裁结果从不与账本对照） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| A4 没记尺子不算失败（缺输入按通过处理） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| A5 审计结论恒真（永远判通过） | CAUGHT | Total tests: 250, passed: 246, failed: 4 |
| N1 优先序反了（相位越界那条被排到最后） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| N2 击败关系被抹掉（例外退化成普通优先） | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| N3 让位关系被抹掉（被压过的规范不再让位） | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| N4 击败被记成让位（硬关系与软关系混成一笔账） | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| N5 少一条背景规则（有一条 R 编号没被归类） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| C1 回执核验恒真（回执说什么都算相符） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| C2 回执核验恒假（一切回执都被判违约） | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| C3 孤立位置判据恒空（有来路却到不了，不再被点出来） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| C4 覆盖统计把走过的行算少一行 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| C5 契约表少一条（判据清单与契约表不再吻合） | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| Y1 指纹不读内容（只按长度变化） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| Y2 指纹核验被去掉（内容被改过也看不出来） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| Y3 坏数字不记降级（猜出来的值悄悄留下） | CAUGHT | Total tests: 250, passed: 248, failed: 2 |
| Y4 未知的商谈类型码不记降级 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| Y5 被整行丢掉的发现不再说话 | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| Y6 重放闸门恒真（内容不同也判为一致） | CAUGHT | Total tests: 250, passed: 249, failed: 1 |
| X1 可推动的槽恒空（下游拿到一份空清单） | CAUGHT | Total tests: 250, passed: 247, failed: 3 |
| X2 可推动的槽恒真（八槽全给，缺口被抹平） | CAUGHT | Total tests: 250, passed: 247, failed: 3 |
| X3 可挪动的槽恒空（位置永远不动） | CAUGHT | Total tests: 250, passed: 247, failed: 3 |
| X4 把未定也算成挪动（位置其实挪不动） | CAUGHT | Total tests: 250, passed: 247, failed: 3 |
| X5 是否未定恒假（五处未定点不再被点名） | CAUGHT | Total tests: 250, passed: 247, failed: 3 |
| X6 把同归也算成未定（两个维度混成一种不确定） | CAUGHT | Total tests: 250, passed: 247, failed: 3 |
| X7 有边与挪动混为一谈（可推动的槽只给会挪动的那几根） | CAUGHT | Total tests: 250, passed: 247, failed: 3 |
| RESTORED src/loop.mbt | OK | 20a630911309adac |
| RESTORED group/loop.mbt | OK | 0aaad459c0a9fe3f |
| RESTORED society/loop.mbt | OK | 531318c2eda055b9 |
| RESTORED src/spec.mbt | OK | 9a2fd03641fccd42 |
| RESTORED audit/fleet.mbt | OK | 91f37693e3e15266 |
| RESTORED audit/mutants.mbt | OK | b90e294c8dffe26c |
| RESTORED ml/design.mbt | OK | fc0d26c9f8b898f7 |
| RESTORED src/petri.mbt | OK | f70a47da197ab09b |
| RESTORED src/en.mbt | OK | 6c3fead6beb5a2bc |
| RESTORED group/en.mbt | OK | 148d9fb456ec08cc |
| RESTORED src/buchi.mbt | OK | 9dc87ccf3eb376c8 |
| RESTORED src/paths.mbt | OK | d5e9f180d2e5e64a |
| RESTORED society/state.mbt | OK | f1da179cc86377d4 |
| RESTORED evolution/cycle.mbt | OK | 8f3f8ceb94db6e0f |
| RESTORED group/machine.mbt | OK | 5fb036c76f123d02 |
| RESTORED evolution/audit.mbt | OK | 09275377c01f96ad |
| RESTORED multi/deontic.mbt | OK | e1c5617f06cb0cae |
| RESTORED src/contract.mbt | OK | 590cc982d66ff9d5 |
| RESTORED coordinator/replay.mbt | OK | d6e5b5af689b0635 |
| RESTORED coordinator/runtime.mbt | OK | b1ef34379c0c1fdf |
| RESTORED coordinator/memory.mbt | OK | aa5671f417cec80c |
| RESTORED generated interfaces | OK | 21 files |
