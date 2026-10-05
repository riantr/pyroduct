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
/// 非空性与活性潜势在真表上恒为 `true`（重入环使它成立），所以只看真表的判据
/// 分不出「检查在跑」与「检查恒真」。这两条给纯函数**造出来的**清单：一个回不到
/// 起点的集合、一个到不了验收集的位置，那两条 `false` 才验得住。
test "ω 面的两条判定在造的集合上确实返回 false" {
  // 非空性：可达集合里没有能回到起点的位置 ⇒ 空 ω 语言
  let none_back : Array[@src.SubjectState] = []
  assert_false(@src.any_returns_to([@src.Standing], none_back))
  // 同一个位置，但标成回得到 ⇒ 交集非空，成立
  assert_true(@src.any_returns_to([@src.Standing], [@src.Standing]))
  // 交集在第二个元素上：不能只看头一个
  assert_true(@src.any_returns_to([@src.Standing, @src.Guilt], [@src.Guilt]))
  // 可达集合为空：无环
  assert_false(@src.any_returns_to(none_back, [@src.Standing]))
  assert_false(@src.any_returns_to(none_back, none_back))
  // 活性潜势：缺一个位置的覆盖 ⇒ 那个位置是 ω-语言的死端
  let states = @src.all_states()
  assert_true(states.length() > 1)
  assert_true(@src.all_covered(states, states))
  let partial : Array[@src.SubjectState] = []
  for s in states {
    if s != states[0] {
      partial.push(s)
    }
  }
  assert_false(@src.all_covered(states, partial))
  let none : Array[@src.SubjectState] = []
  assert_false(@src.all_covered(states, none))
  assert_true(@src.all_covered(none, none))
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
