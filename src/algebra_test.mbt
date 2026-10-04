///|
/// 黑盒测试：机器代数（Ragel 面）。锁定——最小商（31 块 + 三对孪生是设计）、
/// 主线是一条真实的链（30 站 + 重入）、差集恰为四处设计状态。

///|
test "algebra：最小商——31 块，三对孪生（成双是设计）" {
  let (count, classes) = @src.minimal_quotient()
  assert_eq(count, 31)
  assert_eq(classes.length(), 3)
  assert_eq(
    classes.join("|"),
    "受赏 ≡ 畏怖|无忆 ≡ 无筹|紧迫 ≡ 疏离",
  )
  // is_minimal 与最小商一致：31 != 34，故 false——孪生对不合并
  assert_false(@src.is_minimal())
}

///|
test "algebra：主线是链，差集恰为四处设计状态" {
  let course = @src.course()
  // 主线 31 项 = 30 站 + 重入的反顾；无重复；首尾锚定
  assert_eq(course.length(), 31)
  let seen : Map[String, Bool] = Map([])
  for s in course {
    seen[s.designation()] = true
  }
  assert_eq(seen.length(), 30)
  assert_eq(course[0], @src.Standing)
  assert_eq(course[course.length() - 2], @src.Tranquility)
  assert_eq(course[course.length() - 1], @src.Reflection) // 重入
  // 主线是一条真实的链：相邻两项之间必有迁移边（含末对宁静→反顾）
  for i = 0; i < course.length() - 1; i = i + 1 {
    let from = course[i]
    let to = course[i + 1]
    let mut linked = false
    for t in @src.transitions() {
      if t.from == from && t.to == to {
        linked = true
      }
    }
    assert_true(linked)
  }
  // 差集：全状态 − 主线 = 无忆／无筹（退化入口）+ 疏离／畏怖（空间侧支路）
  let on_course : Map[String, Bool] = Map([])
  for s in course {
    on_course[s.designation()] = true
  }
  let missing : Array[String] = []
  for s in @src.all_states() {
    match on_course.get(s.designation()) {
      Some(_) => ()
      None => missing.push(s.designation())
    }
  }
  missing.sort()
  assert_eq(missing.join(","), "无忆,无筹,畏怖,疏离")
}
