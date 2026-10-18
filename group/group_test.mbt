///|
/// 黑盒测试：只通过 `@group.…` 公开 API。

///|
test "规模与构成" {
  assert_eq(@group.all_states().length(), 20)
  assert_eq(@group.all_phases().length(), 9)
  assert_eq(@group.transitions().length(), 44)
  assert_eq(@group.initial().designation(), "散在")
  assert_eq(@group.resting().designation(), "宁定")
}

///|
/// 定名纪律：中文一律两字、各自互异；英文对照层齐备、不与中文重合、也不重复。
/// 主体机那边（`src/en_test.mbt`）还钉死了具体选了哪些词；这里钉住形状，加上
/// 修习／规训这一对——群体机整层曾无任何判据，改回去不会让任何东西变红。
test "定名纪律：两字互异，英文对照层齐备且不与中文重合" {
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
  let en_states : Array[String] = []
  for s in @group.all_states() {
    let en = s.en_designation()
    assert_true(en.length() > 0)
    assert_true(en != s.designation())
    assert_true(!en_states.contains(en))
    en_states.push(en)
    assert_true(s.en_gloss().length() > 0)
    assert_true(s.en_gloss() != s.gloss())
  }
  assert_eq(en_states.length(), 20)
  let en_phases : Array[String] = []
  for p in @group.all_phases() {
    let en = p.en_label()
    assert_true(en.length() > 0)
    assert_true(en != p.label())
    assert_true(!en_phases.contains(en))
    en_phases.push(en)
  }
  assert_eq(en_phases.length(), 9)
  // 九个阶段名逐个钉死：主体机那边只钉形状时，`Coming to a Body` 这种改法
  // 完全合规（非空、不等于中文、互异），于是「成体 → Bodied」这种决定可以
  // 被无声地改回去。形状合格不等于词选对了。
  let decided_phases = [
    "Gathering", "Bodied", "Ordering", "Diverging", "Excess", "Self-binding", "Impaired",
    "Cultivation", "Resting",
  ]
  assert_eq(decided_phases.length(), en_phases.length())
  for name in decided_phases {
    assert_true(en_phases.contains(name))
  }
  // 修习 is one designation, so it is one English word in both places it occurs
  // — which is the whole reason 修习 gives up `Discipline` here and the group's
  // 规训 keeps `Disciplined`. Reverting either half leaves 修习 wearing two
  // different words, so assert the pair explicitly.
  assert_true(en_states.contains("Cultivation"))
  assert_true(en_phases.contains("Cultivation"))
  assert_true(en_states.contains("Disciplined"))
  assert_true(!en_states.contains("Discipline"))
  assert_true(!en_phases.contains("Discipline"))
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
