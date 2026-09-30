///|
/// 黑盒测试：只通过 `@dmlref.…` 公开 API。

///|
test "同 nuisance 互校：两实现 θ̂ 与 se 一致" {
  let (y, d, x, truth) = @dmlref.demo_dataset()
  let c = @dmlref.compare_matched(y, d, x, truth, 5, 0.05)
  assert_true(c.agree)
  assert_true(c.d_theta < 0.05)
  assert_true(c.d_se < 0.01)
  assert_eq(c.n, 400)
  assert_eq(c.folds, 5)
}

///|
test "异 nuisance：柔性筛更接近真值" {
  let (y, d, x, truth) = @dmlref.demo_dataset()
  let r = @dmlref.compare_rich(y, d, x, truth, 5, 0.05)
  // 线性 nuisance（参考实现用的）偏开真值，柔性筛把它拿回来
  assert_true((r.theta_ours - truth).abs() < (r.theta_ref - truth).abs())
  // 参考实现的置信区间自洽
  assert_true(r.ci_low < r.theta_ref)
  assert_true(r.theta_ref < r.ci_high)
}

///|
test "参考实现可独立调用（外部依赖真的接进来了）" {
  let (y, d, x, _) = @dmlref.demo_dataset()
  let f = @dmlref.fit_reference(y, d, x, 5)
  assert_eq(f.n, 400)
  assert_eq(f.folds, 5)
  assert_true(f.se > 0.0)
  assert_true(f.theta > 0.0)
}

///|
test "报告覆盖对照结论" {
  let r = @dmlref.render_report()
  for
    k in [
      "riantr/moonbit_doubleML", "同 nuisance（OLS）", "自研用 3 次筛", "更接近真值",
    ] {
    assert_true(r.contains(k))
  }
}
