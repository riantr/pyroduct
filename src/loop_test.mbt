///|
/// 黑盒测试：执行契约层。验证五种合法回执、缺口的所在层面，以及「不封闭」未被削弱。
/// 0.1.26 增：触发粒度（`step_by_trigger`）与「同归不点名」这条反编造判据。

///|
test "step 给五种合法回执：迁、守、未定、同归、无路" {
  let moved = @src.step(@src.Standing, @src.Act)
  assert_true(moved.label() == "迁")
  match moved.landing() {
    Some(to) => assert_true(to == @src.Freedom)
    None => assert_true(false)
  }
  // 相遇 × 持存挂着三条触发句且同归相遇：去处确定、来处不名，故不报「守」。
  let same = @src.step(@src.Encounter, @src.Hold)
  assert_true(same.label() == "同归")
  match same.landing() {
    Some(to) => assert_true(to == @src.Encounter)
    None => assert_true(false)
  }
  match same {
    @src.Same(slot, named, to) => {
      assert_true(slot == @src.Hold)
      assert_eq(named.length(), 3)
      assert_true(to == @src.Encounter)
    }
    _ => assert_true(false)
  }
  // 单触发自环仍是「守」：宁静 × 先行只有「静待下一刻」一条来处，可点名
  // （也正是 buchi 面认定的那个「被接受的停滞」）。
  let held = @src.step(@src.Tranquility, @src.Antecedent)
  assert_true(held.label() == "守")
  match held {
    @src.Held(tr, at) =>
      assert_true(tr == @src.WaitNext && at == @src.Tranquility)
    _ => assert_true(false)
  }
  match held.landing() {
    Some(to) => assert_true(to == @src.Tranquility)
    None => assert_true(false)
  }
  let open = @src.step(@src.Freedom, @src.Occasion)
  assert_true(open.label() == "未定")
  assert_true(open.landing() == None)
  let blocked = @src.step(@src.Tranquility, @src.CoBeing)
  assert_true(blocked.label() == "无路")
  assert_true(blocked.landing() == None)
}

///|
/// step_by_trigger 的前提：同一位置的同一条触发句不出现两次。否则「是哪一句」
/// 本身就没有答案，表该复查，而不是让机器替它挑。
test "表无歧义：同一位置的同一条触发句只出现一次" {
  assert_true(@src.one_edge_per_trigger())
}

///|
/// 三处同归、七条触发句：每一条单独驱动都必须被认出来，且回执里点名的正是它
/// 自己——不是同组里碰巧排在最前的那一条。
test "同归的每条触发句各自驱动：回执点名的就是那一句" {
  let pairs = @src.same_target_pairs()
  assert_eq(pairs.length(), 3)
  let mut seen = 0
  for pair in pairs {
    let (s, k, named, to) = pair
    // 槽给出的回执是同归：不点名任何一句。
    match @src.step(s, k) {
      @src.Same(_, all, landing) => {
        assert_eq(all.length(), named.length())
        assert_true(landing == to)
      }
      _ => assert_true(false)
    }
    for tr in named {
      seen += 1
      assert_true(tr.slot() == k)
      let out = @src.step_by_trigger(s, tr)
      assert_true(out.label() == "守")
      match out {
        @src.Held(named_tr, landing) => {
          assert_true(named_tr == tr)
          assert_true(landing == to)
        }
        _ => assert_true(false)
      }
      match out.landing() {
        Some(at) => assert_true(at == to)
        None => assert_true(false)
      }
    }
  }
  assert_eq(seen, 7)
}

///|
/// 不是此处的出边就报缺口，不替表猜另一条。槽位也要对上：那句若属别的槽，
/// 照样不是「这个位置的这个槽」的边。
test "step_by_trigger 认不得就说缺口" {
  let missed = @src.step_by_trigger(@src.Tranquility, @src.Surprise)
  assert_true(missed.label() == "无路")
  assert_true(missed.landing() == None)
  // 属别的槽、也不是此处的边：同样报缺口（并把槽名说清楚）。
  let wrong_slot = @src.step_by_trigger(@src.Tranquility, @src.Endure)
  assert_true(wrong_slot.label() == "无路")
}

///|
/// 反编造判据（这条能抓住 0.1.26 之前的行为）：凡是**点名**了触发的回执
/// （迁／守），那个位置的该槽必须**恰好只有一条**出边——多一条就必须给同归，
/// 不许挑第一条报出来。逐个组合扫，不靠清单。
test "凡点名触发的回执，该槽在该位置恰有一条出边（不编造触发）" {
  for s in @src.all_states() {
    for k in @src.all_slots() {
      let out = @src.step(s, k)
      let mut cands = 0
      for t in @src.transitions() {
        if t.from == s && t.trigger.slot() == k {
          cands += 1
        }
      }
      match out {
        @src.Moved(_, _) => assert_eq(cands, 1)
        @src.Held(_, _) => assert_eq(cands, 1)
        @src.Same(_, named, _) => {
          assert_eq(named.length(), cands)
          assert_true(cands > 1)
        }
        @src.Open(cands_in) => {
          assert_eq(cands_in.length(), cands)
          assert_true(cands > 1)
        }
        @src.Block(_) => assert_eq(cands, 0)
      }
    }
  }
}

///|
/// 同归的目标与逐条驱动的落点一致：槽粒度说「去这儿」，触发粒度逐条说也是
/// 「去这儿」。两边对不上就是表与回执打架。
test "同归：槽粒度的目标与逐条驱动的落点一致" {
  for pair in @src.same_target_pairs() {
    let (s, k, named, to) = pair
    for tr in named {
      match @src.step_by_trigger(s, tr).landing() {
        Some(at) => assert_true(at == to)
        None => assert_true(false)
      }
    }
    match @src.step(s, k).landing() {
      Some(at) => assert_true(at == to)
      None => assert_true(false)
    }
  }
}

///|
/// 同归要能被画出来：行程视图那条 `Same` 分支不能是没人走过的死码。走
/// 「择取 × 共在 → 相遇」，再用「持存」撞上同归组合，图上应有「同归」二字，
/// 且那条边**不带触发句**（来处不名就不许在边上点名）。
test "行程视图能画出同归：边照画，边上不写触发句" {
  let trace = @src.walk(@src.Choosing, [@src.CoBeing, @src.Hold])
  assert_eq(trace.steps.length(), 2)
  assert_true(trace.steps[1].1.label() == "同归")
  assert_true(trace.at() == @src.Encounter)
  let journey = @src.render_mermaid_journey(trace)
  assert_true(journey.contains("同归"))
  assert_true(!journey.contains("最初是惊喜"))
}

///|
test "detailed：每步带上出发位置，与重放一致" {
  let trace = @src.walk(@src.Standing, [
    @src.Act,
    @src.Occasion,
    @src.Occasion,
    @src.CoBeing,
  ])
  let d = trace.detailed()
  assert_eq(d.length(), 4)
  // 第一步：立位 × 行动 → 迁到自由
  assert_true(d[0].from == @src.Standing)
  assert_true(d[0].slot == @src.Act)
  match d[0].outcome.landing() {
    Some(to) => assert_true(to == @src.Freedom)
    None => assert_true(false)
  }
  // 第二步出发位置是自由（上一步落点）
  assert_true(d[1].from == @src.Freedom)
  // 未定之后位置不变：第三、四步出发位置仍是自由
  assert_true(d[2].from == @src.Freedom)
  assert_true(d[3].from == @src.Freedom)
  // 明细与重放互证：at() 等于最后落点（或最后出发位）
  assert_true(trace.at() == @src.Freedom)
}

///|
test "缺口只在槽的组合层面，不在位置层面：每个位置都有出边，宁静之后仍可重入反顾" {
  for s in @src.all_states() {
    assert_true(@src.successors(s).length() > 0)
  }
  assert_true(@src.gaps().length() > 0)
  assert_true(@src.reachable(@src.Tranquility, @src.Reflection))
}

///|
test "行走不替主体决断：未定与无路之后位置不变" {
  let stalled = @src.walk(@src.Freedom, [@src.Occasion, @src.Occasion])
  assert_eq(stalled.steps.length(), 2)
  assert_true(stalled.at() == @src.Freedom)
  let blocked_walk = @src.walk(@src.Tranquility, [@src.CoBeing])
  assert_true(blocked_walk.at() == @src.Tranquility)
  // 到自由之后没有第二次「行动」可走：下一步只能由处境推动，故位置停在自由。
  let act_twice = @src.walk(@src.Standing, [@src.Act, @src.Act])
  assert_true(act_twice.at() == @src.Freedom)
  // 连由揭蔽推动，则一路走归责三步：受挫 → 自归 → 失权。
  let unveil_twice = @src.walk(@src.Evil, [@src.Unveil, @src.Unveil])
  assert_true(unveil_twice.at() == @src.Guilt)
}

///|
test "执行契约与迁移表一致：每条边由其槽走得出，报告可打印" {
  for t in @src.transitions() {
    assert_true(@src.exitable(t.from, t.trigger.slot()))
  }
  let report = @src.render_loop_report()
  assert_true(report.contains("执行契约"))
  assert_true(report.contains("未定"))
  assert_true(report.contains("无路"))
}
