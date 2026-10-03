///|
test "敏感性：rv 与 max_bias 确定，rv 是有限正数（有限脆弱）" {
  let a = @causal.run_diagnostics()
  let b = @causal.run_diagnostics()
  // 确定性：同一份数据两次运行逐位一致。
  assert_eq(a.theta_ref, b.theta_ref)
  assert_eq(a.rv, b.rv)
  assert_eq(a.bh_naive, b.bh_naive)
  // rv = |θ̂|/max_bias：有限正数——既非无限脆弱，也不压倒性稳固。
  assert_true(a.rv > 0.0)
  assert_true(a.rv < 1.0)
  assert_true(a.max_bias > 0.0)
}

///|
test "多重检验：BH 校正随原 p 单调不减，真效应与天真估计都过线" {
  let r = @causal.run_diagnostics()
  // 真效应：原始 p 与 BH 校正后都过线（数据真值 θ = 1.5，n = 400）。
  assert_true(r.p_theta < 0.05)
  assert_true(r.bh_theta < 0.05)
  // 天真 OLS 同样「显著」——显著性不是证据。
  assert_true(r.p_naive < 0.05)
  assert_true(r.bh_naive < 0.05)
  assert_true(r.bonf_naive < 0.05)
}

///|
test "phi_tail：筛查用右尾函数对 0 与 1.96 给出教科书值" {
  let half = @causal.phi_tail(0.0)
  assert_true(half > 0.4999 && half < 0.5001)
  let q = @causal.phi_tail(1.96)
  assert_true(q > 0.0249 && q < 0.0251)
  // 对称：Q(−x) = Q(x)。
  assert_eq(q, @causal.phi_tail(-1.96))
}

///|
test "异质性：库截距 + d̃ + 三个交互维，d̃ 系数回收 θ̂，se 全正" {
  let r = @causal.run_diagnostics()
  // 库自带截距 + d̃ + p 个交互维 = 1 + 1 + 4 = 6。
  assert_eq(r.het_coefs.length(), 6)
  assert_eq(r.het_ses.length(), 6)
  for s in r.het_ses {
    assert_true(s > 0.0)
  }
  // d̃ 维是 PLR 力矩的再线性化，应回收主估计。
  let gap = r.het_coefs[1] - r.theta_ref
  assert_true(gap < 0.15 && gap > -0.15)
}

///|
test "报告对称：三项小节与边界齐全，出处层标注" {
  let report = @causal.render_report()
  assert_true(report.contains("敏感性"))
  assert_true(report.contains("多重检验"))
  assert_true(report.contains("异质性"))
  assert_true(report.contains("模型整理"))
  assert_true(report.contains("只读"))
  assert_true(report.contains("Cinelli"))
  assert_true(report.contains("0.75.0"))
}
