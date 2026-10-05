# 变异表判定记录（生成物，勿手改）

这张表是 `python tools/mutate_review.py` 的**输出留档**，为的是让
「每条变异都被判据抓住」这句话不必靠重跑一次破坏工作树的运行来核对。
重跑方式：`python tools/mutate_review.py`（45 条变异 × 全量测试，约 20-30 分钟）。
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
| BASELINE (no mutation) | 0 | Total tests: 188, passed: 188, failed: 0 |
| A1 step 在同归组合上点名第一条（旧行为） | CAUGHT | Total tests: 188, passed: 180, failed: 8 |
| A2 Same 不给落点（回执不再推进行程） | CAUGHT | Total tests: 188, passed: 185, failed: 3 |
| A3 有歧义时替表挑一条（不猜→猜） | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| A4 去重检查恒真（表有歧义也不报） | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| A5 same_target_pairs 把未定也算成同归 | CAUGHT | Total tests: 188, passed: 185, failed: 3 |
| B1 group::step 去掉并列分支（一句触发两个去处被抹平） | CAUGHT | Total tests: 188, passed: 182, failed: 6 |
| B2 group::step 给缺口编造一条出边 | CAUGHT | Total tests: 188, passed: 184, failed: 4 |
| B3 group::open_pairs 返回空（那句数据问题被藏起来） | CAUGHT | Total tests: 188, passed: 186, failed: 2 |
| B4 group::no_dead_end_of 恒真（不封闭的检查不再跑） | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| B5 society::one_edge_each 去掉去重（触发粒度的确定性不再被锁） | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| B6 society::no_dead_end_of 恒真（不封闭的检查不再跑） | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| M1 缺口被编造出一条边 | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| M2 同归只点名第一条 | CAUGHT | Total tests: 188, passed: 186, failed: 2 |
| M3 同归被当成未定展开 | CAUGHT | Total tests: 188, passed: 186, failed: 2 |
| M4 缺口处终止分支 | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| M5 after_open 起点步数偏一 | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| M6 after_open 去掉深度闸 | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| M7 push_step 共用同一份行程（别名） | CAUGHT | Total tests: 188, passed: 184, failed: 4 |
| M8 撞界不报 | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| M9 open_points 把同归也算成未定点 | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| S1 状态少导出一个 | CAUGHT | Total tests: 188, passed: 185, failed: 3 |
| S2 迁移少导出一条 | CAUGHT | Total tests: 188, passed: 184, failed: 4 |
| S3 迁移的 from 写成 to | CAUGHT | Total tests: 188, passed: 185, failed: 3 |
| S4 原文名写成定名 | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| S5 阶段成员漏一个 | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| S6 槽少导出一个 | CAUGHT | Total tests: 188, passed: 186, failed: 2 |
| L1 群体规格少导一条迁移 | CAUGHT | Total tests: 188, passed: 184, failed: 4 |
| L2 群体规格起点写错 | CAUGHT | Total tests: 188, passed: 186, failed: 2 |
| L3 三鉴发现不分层（全部塞进已知设计） | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| L4 变异网少一族 | CAUGHT | Total tests: 188, passed: 186, failed: 2 |
| L5 「填一个不可达终点」这一族变成空操作 | CAUGHT | Total tests: 188, passed: 186, failed: 2 |
| L6 变异网期望家族写错（条件布尔 → 方法错） | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| L7 「删掉一条迁移」这一族不再删 | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| L8 设计图少一条接口 | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| L9 着色声明去掉「不实现」 | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| P1 src::exitable 恒真（缺口那侧不再被认出来） | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| P2 src::every_phase_has_non_act_of 恒真 | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| P3 src::any_returns_to 恒真（非空性不再被检查） | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| P4 src::all_covered 恒真（活性潜势不再被检查） | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| P5 src::is_deterministic 反相（答案不是来自那次检查） | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| P6 society::no_final_closure_of 恒真（两条 false 臂都不再跑） | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| P7 group::resolve_open 两种偏向取同一条（能耗原则不成立） | CAUGHT | Total tests: 188, passed: 186, failed: 2 |
| P8 evolution::group_lean_of 偏向反相（双诚之比读反了） | CAUGHT | Total tests: 188, passed: 187, failed: 1 |
| P9 震荡边只剩单向（共语上不再冒出有效性主张） | CAUGHT | Total tests: 188, passed: 182, failed: 6 |
| P10 震荡边接反（超体与间体倒置） | CAUGHT | Total tests: 188, passed: 184, failed: 4 |
| RESTORED src/loop.mbt | OK | a99bf951fe25380c |
| RESTORED group/loop.mbt | OK | 0aaad459c0a9fe3f |
| RESTORED society/loop.mbt | OK | bb3c9e323179bff0 |
| RESTORED src/spec.mbt | OK | 9a2fd03641fccd42 |
| RESTORED audit/fleet.mbt | OK | 99c8da93f7d07397 |
| RESTORED audit/mutants.mbt | OK | f4e24fecfc64bf4f |
| RESTORED ml/design.mbt | OK | fc0d26c9f8b898f7 |
| RESTORED src/petri.mbt | OK | 39257fdd439616cb |
| RESTORED src/buchi.mbt | OK | 9dc87ccf3eb376c8 |
| RESTORED src/paths.mbt | OK | 7392a0326a0f4d50 |
| RESTORED society/state.mbt | OK | 5e5dff58e838e1d1 |
| RESTORED evolution/cycle.mbt | OK | 486dde36d13ef369 |
| RESTORED group/machine.mbt | OK | de6411a96b1811d9 |
