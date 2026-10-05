# 变异表判定记录（生成物，勿手改）

这张表是 `python tools/mutate_review.py` 的**输出留档**，为的是让
「每条变异都被判据抓住」这句话不必靠重跑一次破坏工作树的运行来核对。
重跑方式：`python tools/mutate_review.py`（30 条变异 × 全量测试，约 20-30 分钟；
`python tools/mutate_review.py loop3` 只跑一组）。

判读四态：
- `CAUGHT` + 失败数 > 0 —— 判据真的变红了。这是要的结果。
- `COMPILE-ERROR` —— 变异在**编译期**被拒。这**不是**抓取：它证明的是语法，
  不是判据有牙齿。首版四条 `arr[..n]` 切片死在这里，全部重写后才算数。
- `ANCHOR-ERROR` —— 源码形状与表里记的不符（改动导致锚点漂移）。不是抓取，
  得先修表。
- `SURVIVED` —— 变异活着。必须归类为「等价」或「具名缺口」，不能悬着。

纪律两条：变异必须**编译得过**（见上）；每条结束时校验 sha256 与开跑前一致
——改源码的脚本要自己证明没留痕迹。



机 | 变异 | 判定 | 详情 |
|---|---|---|---|
| BASELINE (no mutation) | 0 | Total tests: 178, passed: 178, failed: 0 |
| A1 step 在同归组合上点名第一条（旧行为） | CAUGHT | Total tests: 178, passed: 170, failed: 8 |
| A2 Same 不给落点（回执不再推进行程） | CAUGHT | Total tests: 178, passed: 175, failed: 3 |
| A3 有歧义时替表挑一条（不猜→猜） | CAUGHT | Total tests: 178, passed: 177, failed: 1 |
| A4 去重检查恒真（表有歧义也不报） | CAUGHT | Total tests: 178, passed: 177, failed: 1 |
| A5 same_target_pairs 把未定也算成同归 | CAUGHT | Total tests: 178, passed: 175, failed: 3 |
| RESTORED src/loop.mbt | OK | 09490167ca99485f |
