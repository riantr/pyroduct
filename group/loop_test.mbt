///|
/// 黑盒测试：群体机的执行契约层（0.1.27）。只经 `@group.` 公开 API。
///
/// 与主体机同纪律：回执如实，不替表挑去处；缺口如实说出口。

///|
test "step 给回执：迁与守" {
  // 共语 × 由传统立规：唯一出路，通向规训
  let moved = @group.step(@group.CommonTongue, @group.NormFromTradition)
  assert_true(moved.label() == "迁")
  match moved {
    @group.Moved(tr, to) => {
      assert_true(tr == @group.NormFromTradition)
      assert_true(to == @group.Normed)
    }
    _ => assert_true(false)
  }
  // 宁定 × 不再绝对化：静待下一刻，回到自身
  let held = @group.step(@group.Settled, @group.Settle)
  assert_true(held.label() == "守")
  match held.landing() {
    Some(at) => assert_true(at == @group.Settled)
    None => assert_true(false)
  }
}

///|
test "一句触发、两个去处：表里真的有一处，机器不替它挑" {
  let pairs = @group.open_pairs()
  assert_eq(pairs.length(), 1)
  let (s, k, to) = pairs[0]
  assert_true(s == @group.Converging)
  assert_true(k == @group.Attention)
  assert_eq(to.length(), 2)
  assert_true(to.contains(@group.CommonTongue) && to.contains(@group.Discourse))
  // 走一步得到并列，不落地：注意汇聚到底通向哪一处，表没定，机器也不定。
  let out = @group.step(@group.Converging, @group.Attention)
  assert_true(out.label() == "未定")
  assert_true(out.landing() == None)
  match out {
    @group.Open(tr, tos) => {
      assert_true(tr == @group.Attention)
      assert_eq(tos.length(), 2)
    }
    _ => assert_true(false)
  }
}

///|
test "缺口：此处无此事，位置不动" {
  let out = @group.step(@group.Dispersed, @group.Agree)
  assert_true(out.label() == "无路")
  assert_true(out.landing() == None)
  assert_true(!@group.exitable(@group.Dispersed, @group.Agree))
}

///|
test "不封闭：20 个状态都有出边，没有走完即止的末态" {
  assert_true(@group.no_dead_end())
}

///|
test "凡点名的回执，那个状态的该触发恰有一条边（不编造）" {
  for s in @group.all_states() {
    let triggers : Array[@group.GroupTrigger] = []
    for t in @group.transitions() {
      if t.from == s {
        triggers.push(t.trigger)
      }
    }
    for k in triggers {
      let mut cands = 0
      for t in @group.transitions() {
        if t.from == s && t.trigger == k {
          cands += 1
        }
      }
      match @group.step(s, k) {
        @group.Moved(tr, _) => {
          assert_eq(cands, 1)
          assert_true(tr == k)
        }
        @group.Held(tr, _) => {
          assert_eq(cands, 1)
          assert_true(tr == k)
        }
        @group.Open(tr, tos) => {
          assert_eq(tos.length(), cands)
          assert_true(cands > 1)
          assert_true(tr == k)
        }
        @group.Block(_) => assert_eq(cands, 0)
      }
    }
  }
}

///|
test "每条边都走得出，且走得出的都能被 exitable 认出来" {
  for t in @group.transitions() {
    assert_true(@group.exitable(t.from, t.trigger))
  }
}

///|
test "walk：未定与无路之后位置不变" {
  let trace = @group.walk(@group.Converging, [@group.Attention, @group.Agree])
  assert_eq(trace.steps.length(), 2)
  assert_true(trace.steps[0].1.label() == "未定")
  assert_true(trace.steps[1].1.label() == "无路")
  assert_true(trace.at() == @group.Converging)
  let labels = trace.outcome_labels()
  assert_eq(labels[0], "未定")
  assert_eq(labels[1], "无路")
}

///|
test "walk：能走的路走得通，且与逐步 step 一致" {
  let trace = @group.walk(@group.initial(), [@group.Appear, @group.Attention])
  assert_true(trace.steps[0].1.label() == "迁")
  assert_true(trace.steps[1].1.label() == "未定")
  // 未定之后位置不变：仍在趋同（注意汇聚那一处两个去处）
  assert_true(trace.at() == @group.Converging)
}

///|
test "emerge 与 step 回答不同问题，互不替代" {
  // 分类函数：成员体制 + 主体状态 → 涌现态（9 行涌现表，与迁移表无关）
  let rows = @group.emergence_table()
  assert_eq(rows.length(), 9)
  let (_, st) = rows[0]
  assert_true(st == @group.Converging)
  let m = [@multi.subject(1, @sm.Standing, @multi.ChengRan, 1, 9, 5)]
  assert_true(@group.is_well_formed(st, m))
  // 执行契约：表上的投影（42 条边，与成员配置无关）
  let out = @group.step(@group.Converging, @group.Attention)
  assert_true(out.label() == "未定")
  assert_eq(@group.transitions().length(), 42)
}
