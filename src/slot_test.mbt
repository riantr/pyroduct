///|
/// 黑盒测试：驱动槽层。只通过公开 API（`@src.…`）验证归位的完整性与两条归位纪律。

///|
fn has_text(xs : Array[String], s : String) -> Bool {
  for x in xs {
    if x == s {
      return true
    }
  }
  false
}

///|
test "八个驱动槽定名一律两字，且各带结构说明与出处层" {
  let slots = @src.all_slots()
  assert_eq(slots.length(), 8)
  let seen : Array[String] = []
  for k in slots {
    assert_eq(k.designation().length(), 2)
    assert_true(k.gloss().length() > 0)
    assert_true(k.source().length() > 0)
    assert_true(k.provenance().length() > 0)
    assert_true(k.qualified().contains("（"))
    assert_true(!has_text(seen, k.designation()))
    seen.push(k.designation())
  }
}

///|
test "表内全部触发都已归槽，八个槽无一空置" {
  let tally = @src.slot_tally()
  let mut total = 0
  for entry in tally {
    assert_true(entry.1 > 0)
    total += entry.1
  }
  assert_eq(total, @src.all_triggers().length())
  assert_eq(@src.all_triggers().length(), 49)
  assert_true(@src.render_slot_tally().contains("共在 3"))
}

///|
test "共在独立成槽：相遇、善意的假设、敞开双臂不并入处境或行动" {
  let meet : @src.Trigger = @src.MeetOther
  let faith : @src.Trigger = @src.GoodFaith
  let arms : @src.Trigger = @src.OpenArms
  assert_true(meet.slot() == @src.CoBeing)
  assert_true(faith.slot() == @src.CoBeing)
  assert_true(arms.slot() == @src.CoBeing)
  assert_true(meet.slot() != @src.Occasion)
  assert_true(arms.slot() != @src.Act)
}

///|
test "机器不是纯 agent 回路：每阶段有非行动的出边，只能由行动离开的位置恰为四个" {
  assert_true(@src.every_phase_has_non_act())
  let only = @src.only_act_exits()
  assert_eq(only.length(), 4)
  assert_true(only[0] == @src.Standing)
  assert_true(only[1] == @src.Guilt)
  assert_true(only[2] == @src.Binding)
  assert_true(only[3] == @src.Loss)
}

///|
test "先行槽只收原文的接触未来、尝试与静待，不给数值" {
  let touch : @src.Trigger = @src.TouchFuture
  let wait : @src.Trigger = @src.WaitNext
  let probe : @src.Trigger = @src.TryMethods
  assert_true(touch.slot() == @src.Antecedent)
  assert_true(wait.slot() == @src.Antecedent)
  assert_true(probe.slot() == @src.Antecedent)
  assert_true(@src.render_slot_tally().contains("先行 4"))
}
