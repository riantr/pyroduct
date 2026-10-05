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
/// 上面那条只验了真表为真的一面。真表上它恒为 `true`，所以只看真表的判据分不出
/// 「检查在跑」与「检查恒真」——把 `every_phase_has_non_act` 改成恒真照样过。这条
/// 给 `every_phase_has_non_act_of` 一份**造出来的**阶段清单：一个阶段不在覆盖
/// 清单里，那个 `false` 才验得住。
test "阶段覆盖的检查在造的缺档阶段上确实返回 false" {
  let all : Array[@src.Phase] = @src.all_phases()
  let all_phases = all
  assert_true(all_phases.length() > 1)
  // 全覆盖：成立
  assert_true(@src.every_phase_has_non_act_of(all_phases, all_phases))
  // 少一个阶段的覆盖：那个阶段整段被还原成目的—手段回路
  let p = all_phases[0]
  let partial : Array[@src.Phase] = []
  for q in all_phases {
    if q != p {
      partial.push(q)
    }
  }
  assert_false(@src.every_phase_has_non_act_of(all_phases, partial))
  // 覆盖清单落在表外：同样不成立
  let none : Array[@src.Phase] = []
  assert_false(@src.every_phase_has_non_act_of(all_phases, none))
  // 没有阶段：空集平凡成立
  assert_true(@src.every_phase_has_non_act_of(none, none))
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
