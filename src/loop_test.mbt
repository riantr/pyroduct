///|
/// 黑盒测试：执行契约层。验证四种合法回执、缺口的所在层面，以及「不封闭」未被削弱。

///|
test "step 给四种合法回执：迁、守、未定、无路" {
  let moved = @src.step(@src.Standing, @src.Act)
  assert_true(moved.label() == "迁")
  match moved.landing() {
    Some(to) => assert_true(to == @src.Freedom)
    None => assert_true(false)
  }
  let held = @src.step(@src.Encounter, @src.Hold)
  assert_true(held.label() == "守")
  match held.landing() {
    Some(to) => assert_true(to == @src.Encounter)
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
