///|
/// 黑盒测试：只通过 `@ml.…` 公开 API，验证三件事——
/// (1) 数据确实由状态机生成；(2) DoubleML 还原因果效应而朴素回归不能；
/// (3) 伪随机数可复现、导出可交给外部生态。

///|
test "状态机侧的协变量表取自 34 个状态" {
  let features = @ml.state_features()
  assert_eq(features.length(), 34)
  let mut resting = false
  for entry in features {
    let (name, x) = entry
    assert_true(name.length() > 0)
    assert_eq(x.length(), 4)
    assert_true(x[0] >= -4.0 && x[0] <= 4.0)
    assert_true(x[1] >= 1.0 && x[1] <= 11.0)
    assert_true(x[2] >= 1.0 && x[2] <= 34.0)
    assert_true(x[3] >= 0.0 && x[3] <= 40.0)
    if name == "宁静" {
      resting = true
      assert_eq(x[3], 0.0)
    }
  }
  assert_true(resting)
}

///|
test "数据集由状态机生成，尺度与状态机元数据一致" {
  let data = @ml.make_dataset(400, 1.5, 11)
  assert_eq(data.y.length(), 400)
  assert_eq(data.t.length(), 400)
  assert_eq(data.x.length(), 400)
  assert_eq(data.theta_true, 1.5)
  for i = 0; i < data.x.length(); i = i + 1 {
    assert_true(data.x[i][0] >= -4.0 && data.x[i][0] <= 4.0)
    assert_true(data.x[i][1] >= 1.0 && data.x[i][1] <= 11.0)
    assert_true(data.x[i][3] >= 0.0 && data.x[i][3] <= 40.0)
  }
}

///|
test "DoubleML 还原因果效应，朴素回归与线性调整都不行" {
  let theta = 1.5
  let config = @ml.default_dml_config()
  let data = @ml.make_dataset(4000, theta, 424242)
  let dml = @ml.dml_plr(data.y, data.t, data.x, config)
  let (naive, _) = @ml.naive_ols(data.y, data.t)
  let (linear, _) = @ml.linear_adjust_ols(data.y, data.t, data.x)
  let one = @ml.one_sided_residual(data.y, data.t, data.x, config)
  assert_true(dml.se > 0.0)
  assert_true((dml.theta - theta).abs() < 0.10)
  assert_true(dml.ci_low < theta && theta < dml.ci_high)
  assert_true((naive - theta).abs() > 0.15)
  assert_true((linear - theta).abs() > 0.05)
  assert_true((one.theta - theta).abs() > 0.05)
}

///|
test "重复实验：DoubleML 的区间覆盖率达标，朴素回归不达标" {
  let theta = 1.5
  let config = @ml.default_dml_config()
  let rows = @ml.replicate(30, 400, theta, config)
  assert_eq(rows.length(), 5)
  let naive = rows[0]
  let dml = rows[4]
  assert_true(dml.coverage >= 0.8)
  assert_true(dml.mean_bias.abs() < 0.06)
  assert_true(naive.coverage <= 0.5)
}

///|
test "伪随机数可复现（同种子同序列）" {
  let a = @ml.Rng::new(7)
  let b = @ml.Rng::new(7)
  assert_eq(a.next_u64(), b.next_u64())
  assert_true(a.uniform() == b.uniform())
  let c = @ml.Rng::new(8)
  assert_true(c.next_u64() != b.next_u64())
}

///|
test "CSV 导出可直接交给 Python 的 DoubleML" {
  let data = @ml.make_dataset(50, 1.5, 5)
  let lines = @ml.export_csv(data).split("\n").collect()
  assert_eq(lines.length(), 51)
  assert_eq(lines[0].to_owned(), "y,t,x1,x2,x3,x4")
  let preview = @ml.csv_preview(data, 3).split("\n").collect()
  assert_eq(preview.length(), 4)
}

///|
/// 设计图九条接口的实现状态是**数据表**不是散文：`design_status_table` 九条、
/// 三条已实现六条设计点，且报告里那九行「状态：」由表生成。
/// 这一条把 0.1.28 之前「第 1 条写『本包未实现』、其余只写『设计点』」的
/// 不一致钉死——同一件事两种说法，读者无从判断哪个是特例。
test "设计图：九条接口的实现状态由表生成，3 实现 6 设计点" {
  let table = @ml.design_status_table()
  assert_eq(table.length(), 9)
  let mut done = 0
  let mut todo = 0
  for entry in table {
    if entry.1 == "已实现" {
      done += 1
    } else if entry.1 == "设计点" {
      todo += 1
    } else {
      assert_true(false)
    }
  }
  assert_eq(done, 3)
  assert_eq(todo, 6)
  // 报告里九行状态逐条对上表，且没有一行是散文另写的
  let report = @ml.render_ml_design()
  let mut seen = 0
  for entry in table {
    assert_true(report.contains("### " + entry.0))
    seen += 1
  }
  assert_eq(seen, 9)
  assert_eq(count_occurrences(report, "- 状态："), 9)
  assert_true(report.contains("范围判断，非欠账"))
}

///|
fn count_occurrences(haystack : String, needle : String) -> Int {
  haystack.split(needle).collect().length() - 1
}
