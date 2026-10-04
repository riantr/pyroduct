///|
/// 黑盒测试：泛半环路径和与性质谓词。锁定——最短路的锚点（含重入 1 步）、
/// 触发粒度恒确定、有意成环、距离表覆盖全部 34 位置且全部可达（除起点自身
/// 语义由 0 步表达）。

///|
test "paths：min_steps 的锚点与对称缺席" {
  // 立位→自由 1 步（行动）
  assert_eq(@src.min_steps(@src.Standing, @src.Freedom), Some(1))
  // 立位→宁静：主线不止 1 步但有限（结构事实，上界锁定）
  match @src.min_steps(@src.Standing, @src.Tranquility) {
    Some(n) => assert_true(n > 1 && n <= 33)
    None => assert_true(false)
  }
  // 宁静→反顾恰 1 步（重入边，R11：界域重开）
  assert_eq(@src.min_steps(@src.Tranquility, @src.Reflection), Some(1))
  // 同位置 0 步
  assert_eq(@src.min_steps(@src.Encounter, @src.Encounter), Some(0))
  // 反向不可达：宁静到不了退化起点（无忆只出不进）
  assert_eq(@src.min_steps(@src.Tranquility, @src.NoPast), None)
}

///|
test "paths：distance_to 覆盖全部 34 位置且全部可达；性质谓词锁定" {
  let dist = @src.distance_to(@src.Tranquility)
  assert_eq(dist.length(), 34)
  let mut maxd = 0
  for entry in dist {
    match entry.1 {
      Some(n) => {
        assert_true(n >= 0)
        if n > maxd {
          maxd = n
        }
      }
      None => assert_true(false) // 通往宁静之路：每处皆可达
    }
  }
  assert_true(maxd >= 1 && maxd <= 33)
  // 触发粒度恒确定（「未定」只在槽粒度）
  assert_true(@src.is_deterministic())
  // 有意成环：重入是不封闭的形态
  assert_false(@src.is_acyclic())
}
