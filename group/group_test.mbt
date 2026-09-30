///|
/// 黑盒测试：只通过 `@group.…` 公开 API。

///|
test "规模与构成" {
  assert_eq(@group.all_states().length(), 20)
  assert_eq(@group.all_phases().length(), 9)
  assert_eq(@group.transitions().length(), 42)
  assert_eq(@group.initial().designation(), "散在")
  assert_eq(@group.resting().designation(), "宁定")
}

///|
test "两字纪律：状态名与阶段名一律两字，且各自互异" {
  let seen : Array[String] = []
  for s in @group.all_states() {
    assert_eq(s.designation().length(), 2)
    assert_true(!seen.contains(s.designation()))
    seen.push(s.designation())
    assert_true(s.gloss().length() > 0)
  }
  let phases : Array[String] = []
  for p in @group.all_phases() {
    assert_eq(p.label().length(), 2)
    assert_true(!phases.contains(p.label()))
    phases.push(p.label())
  }
}

///|
test "每个状态都可由「散在」抵达，且都有阶段" {
  for s in @group.all_states() {
    assert_true(@group.reachable(@group.initial(), s))
    assert_true(@group.all_phases().contains(s.phase()))
  }
}

///|
test "R2／R11：只有病态状态假装封口；宁定不封口且可重入" {
  for s in @group.all_states() {
    if s == @group.Projected || s == @group.Monologic {
      assert_true(s.claims_closure())
    } else {
      assert_true(!s.claims_closure())
    }
  }
  assert_eq(@group.successors(@group.resting()).length(), 2)
  assert_true(@group.reachable(@group.resting(), @group.Returning))
}

///|
test "主线历程每一步都由真实迁移连接" {
  let path = @group.course()
  assert_true(path[0] == @group.initial())
  let mut i = 0
  while i + 1 < path.length() {
    let a = path[i]
    let b = path[i + 1]
    let mut connected = false
    for entry in @group.successors(a) {
      if entry.1 == b {
        connected = true
      }
    }
    assert_true(connected)
    i += 1
  }
}

///|
test "涌现：成员体制与主体状态决定群体状态" {
  let rows = @group.emergence_table()
  assert_eq(rows.length(), 9)
  let expected = [
    "趋同", "共语", "商谈", "对峙", "商谈", "相契", "投射", "规训",
    "创伤",
  ]
  for i = 0; i < rows.length(); i = i + 1 {
    let (_, st) = rows[i]
    assert_eq(st.designation(), expected[i])
  }
}

///|
test "R7 构成性：群体状态回写成员的主体状态" {
  assert_eq(@group.feedback_demo(@group.Confronting), "受挫")
  assert_eq(@group.feedback_demo(@group.Projected), "投射")
  assert_eq(@group.feedback_demo(@group.Disciplined), "自缚")
  assert_eq(@group.feedback_demo(@group.Concealed), "隐没")
  assert_eq(@group.feedback_demo(@group.Wounded), "痛苦")
  assert_eq(@group.feedback_demo(@group.Practicing), "修习")
  assert_eq(@group.feedback_demo(@group.Settled), "宁静")
}

///|
test "渲染覆盖全部状态与阶段" {
  let r = @group.render_group_report()
  for s in @group.all_states() {
    assert_true(r.contains(s.designation()))
  }
  for p in @group.all_phases() {
    assert_true(r.contains(p.label()))
  }
}

///|
test "群体状态机的文本依据非空且带出处分节" {
  let b = @group.textual_basis()
  assert_true(b.length() >= 8)
  for e in b {
    assert_true(e.0.length() > 0)
    assert_true(e.1.contains("P.") || e.1.contains("附录"))
  }
}
