///|
/// 黑盒测试：社会机的执行契约层（0.1.27）。只经 `@society.` 公开 API。

///|
test "step 给回执：迁与守" {
  // 生活世界 × 语言在言说我们 → 超主体性
  let moved = @society.step(@society.World, @society.SpeakLanguage)
  assert_true(moved.label() == "迁")
  match moved {
    @society.Moved(tr, to) => {
      assert_true(tr == @society.SpeakLanguage)
      assert_true(to == @society.Suprasubjective)
    }
    _ => assert_true(false)
  }
  // 商谈 × 洗衣机过滤：位置不变
  let held = @society.step(@society.Discourse, @society.Filter)
  assert_true(held.label() == "守")
  match held.landing() {
    Some(at) => assert_true(at == @society.Discourse)
    None => assert_true(false)
  }
}

///|
/// 这张表在触发粒度上确定：同一状态的同一触发只出现一次，故回执只有三种。
/// `Open` 那条臂备而不用——哪天出现一句触发两个去处，这条断言会红，而机器会
/// 如实并列而不是替表挑一个。
test "社会机的表在触发粒度上确定：open_pairs 为空" {
  assert_true(@society.one_edge_per_trigger())
  assert_eq(@society.open_pairs().length(), 0)
}

///|
test "缺口：此处无此事，位置不动" {
  let out = @society.step(@society.Colony, @society.Justify)
  assert_true(out.label() == "无路")
  assert_true(out.landing() == None)
  assert_true(!@society.exitable(@society.Colony, @society.Justify))
}

///|
test "不封闭：13 个状态都有出边" {
  assert_true(@society.no_dead_end())
}

///|
test "凡点名的回执，那个状态的该触发恰有一条边（不编造）" {
  for s in @society.all_states() {
    let triggers : Array[@society.Trigger] = []
    for t in @society.transitions() {
      if t.from == s {
        triggers.push(t.trigger)
      }
    }
    for k in triggers {
      let mut cands = 0
      for t in @society.transitions() {
        if t.from == s && t.trigger == k {
          cands += 1
        }
      }
      match @society.step(s, k) {
        @society.Moved(tr, _) => {
          assert_eq(cands, 1)
          assert_true(tr == k)
        }
        @society.Held(tr, _) => {
          assert_eq(cands, 1)
          assert_true(tr == k)
        }
        @society.Open(tr, tos) => {
          assert_eq(tos.length(), cands)
          assert_true(cands > 1)
          assert_true(tr == k)
        }
        @society.Block(_) => assert_eq(cands, 0)
      }
    }
  }
}

///|
test "每条边都走得出" {
  for t in @society.transitions() {
    assert_true(@society.exitable(t.from, t.trigger))
  }
}

///|
test "walk：缺口之后位置不变；走通的路到得了" {
  let blocked = @society.walk(@society.World, [@society.Justify])
  assert_eq(blocked.steps.length(), 1)
  assert_true(blocked.steps[0].1.label() == "无路")
  assert_true(blocked.at() == @society.World)
  // 一条真路：生活世界 →（语言）→ 超主体性 →（需第三者）→ 缺口
  let ok = @society.walk(@society.World, [
    @society.SpeakLanguage,
    @society.DemandThird,
  ])
  assert_true(ok.steps[0].1.label() == "迁")
  assert_true(ok.steps[1].1.label() == "迁")
  assert_true(ok.at() == @society.Gap)
  let labels = ok.outcome_labels()
  assert_eq(labels.length(), 2)
}

///|
test "不封闭的那条重入边在执行契约下也走得通" {
  // 复建 × 循环过程取代对立关系 → 回到生活世界：不是走完即止
  let out = @society.step(@society.Reconstruction, @society.Circulate)
  match out.landing() {
    Some(at) => assert_true(at == @society.World)
    None => assert_true(false)
  }
  assert_true(@society.no_final_closure())
}
