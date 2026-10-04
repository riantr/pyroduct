///|
/// 黑盒测试：Büchi 面（ω-视角）。锁定——验收集、非空性（lasso）、
/// 活性潜势、停滞词（关键的否定结果：结构不强迫活性）。

///|
test "buchi：验收集与非空性——重入环给出 lasso" {
  let acc = @src.buchi_accepting()
  assert_eq(acc.length(), 1)
  assert_eq(acc[0], @src.Tranquility) // 静定极：本环节的静定极，不是终态
  // 非空性：从宁静走 ≥1 步可达的位置里有一个能回到宁静（宁静→反顾→…）
  assert_true(@src.buchi_nonempty())
  assert_eq(@src.min_steps(@src.Tranquility, @src.Reflection), Some(1)) // 重入边（R11）
  match @src.min_steps(@src.Reflection, @src.Tranquility) {
    Some(_) => () // 环闭合：lasso 的环上有接受态
    None => assert_true(false)
  }
}

///|
test "buchi：活性潜势——每个位置都可达宁静（0 处不可达）" {
  assert_true(@src.buchi_live_potential())
  for s in @src.all_states() {
    match @src.min_steps(s, @src.Tranquility) {
      Some(_) => ()
      None => assert_true(false) // 死端即违背 ω-设计的「不封闭」
    }
  }
}

///|
test "buchi：停滞词——结构不强迫活性的否定结果" {
  let stalls = @src.buchi_stalls()
  // 守（自环）存在：同一守句无限重复 = 停在原地不动的 ω-词
  assert_true(stalls.length() >= 1)
  // 每个停滞位置确有自环迁移（停滞词的见证）
  for s in stalls {
    let mut has_loop = false
    for t in @src.transitions() {
      if t.from == s && t.to == s {
        has_loop = true
      }
    }
    assert_true(has_loop)
    // 且每个停滞位置仍有出口（活性潜势对它们也成立）——守不是死端
    match @src.min_steps(s, @src.Tranquility) {
      Some(_) => ()
      None => assert_true(false)
    }
  }
  // 宁静自己的守是唯一被接受的停滞：静待下一刻的自环让宁静无限次被访
  let mut quiet_loop = false
  for t in @src.transitions() {
    if t.from == @src.Tranquility && t.to == @src.Tranquility {
      quiet_loop = true
    }
  }
  assert_true(quiet_loop)
  // 其余 10 处守词不被接受（位置≠宁静，自环词零次访问宁静）
  assert_eq(stalls.length(), 11)
}
