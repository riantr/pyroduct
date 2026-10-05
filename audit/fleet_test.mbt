///|
/// 黑盒测试：另两台机的三鉴（0.1.28 新增）与迁移表变异网。
///
/// 两条绊线：
/// - **未预期必须为零**，且本层**不设已知设计豁免**——真表上一次发现都没有，
///   就没有可豁免者，预留口子等于给未来的改坏留后门；
/// - **变异网每处破坏都要被抓到**，且报出的家族必须是对应那一族。三鉴报
///   「0 条」与三鉴什么都看不见在报告上长得一样，变异网就是后者的排除法。

///|
/// 规格转写：群体机与社会机的真表原样进入 MachineSpec。
test "规格转写：群体机与社会机的真表原样进入 MachineSpec" {
  let group = @audit.build_group_spec()
  assert_eq(group.states.length(), 20)
  assert_eq(group.transitions.length(), 44)
  assert_eq(group.trigger_slots.length(), 22)
  assert_eq(group.course.length(), 19)
  assert_eq(group.initial, @g.initial().designation())
  // 无槽、无终点：见文件头的两条口径
  assert_eq(group.slot_names.length(), 0)
  assert_eq(group.terminal, "")
  let society = @audit.build_society_spec()
  assert_eq(society.states.length(), 13)
  assert_eq(society.transitions.length(), 28)
  assert_eq(society.trigger_slots.length(), 18)
  assert_eq(society.course.length(), 10)
  assert_eq(society.initial, @so.initial().designation())
  assert_eq(society.slot_names.length(), 0)
  assert_eq(society.terminal, "")
}

///|
/// 迁移逐条相等：规格里的 (from, event, to) 与真表一条不差（含顺序）。
test "规格转写：两台机的迁移逐条与真表相等" {
  let group = @audit.build_group_spec()
  let gt = @g.transitions()
  assert_eq(group.transitions.length(), gt.length())
  for i = 0; i < gt.length(); i = i + 1 {
    let (from, event, to) = group.transitions[i]
    assert_true(from == gt[i].from.designation())
    assert_true(event == gt[i].trigger.label())
    assert_true(to == gt[i].to.designation())
  }
  let society = @audit.build_society_spec()
  let st = @so.transitions()
  assert_eq(society.transitions.length(), st.length())
  for i = 0; i < st.length(); i = i + 1 {
    let (from, event, to) = society.transitions[i]
    assert_true(from == st[i].from.designation())
    assert_true(event == st[i].trigger.label())
    assert_true(to == st[i].to.designation())
  }
}

///|
/// 绊线：两台机的真表上未预期发现必须为零，且**已知设计也必须为零**（不设豁免）。
test "三鉴在两台机真表上：未预期 0 条，已知设计也 0 条（不设豁免）" {
  let verdicts = @audit.run_fleet_audit()
  assert_eq(verdicts.length(), 2)
  for v in verdicts {
    assert_eq(v.fresh.length(), 0)
    // 没有豁免口子：真表上一次发现都没有，就不该留一个「已知设计」分类
    assert_eq(v.known.length(), 0)
  }
}

///|
/// 「无终点」是**选择**不是**失灵**：把终点填进去，三鉴立刻报不可达。
/// 这一条替 `is_known_fleet` 的空豁免作证——留空 terminal 没有让任何报警闭嘴。
/// （规格的字段不可改，故这一族从变异网里取现成的破坏副本，不在本测试里现搭。）
test "不留豁免也没让报警闭嘴：填一个不可达终点，两台机都报" {
  for v in @audit.run_fleet_audit() {
    // 真表留空 ⇒ 不报终点不可达（真表上一次发现都没有，这一项当然没有）
    let spec = if v.machine == "群体" {
      @audit.build_group_spec()
    } else {
      @audit.build_society_spec()
    }
    for f in @audit.families_of(spec) {
      assert_false(f == "方法错")
    }
    // 同一个位置填进去 ⇒ 立刻报
    let mut hit = false
    for m in @audit.table_mutants() {
      if m.machine == v.machine && m.label == "填一个不可达终点" {
        for f in @audit.families_of(m.spec) {
          if f == "方法错" {
            hit = true
          }
        }
      }
    }
    assert_true(hit)
  }
}

///|
/// 无路全部说出口：两台机的每一个 (位置, 触发) 无出边组合都带非空理由。
test "无路全部说出口：群体 397 条、社会 206 条理由逐条非空" {
  let group = @audit.build_group_spec()
  assert_eq(group.blocks.length(), 397)
  for b in group.blocks {
    let (_, _, reason) = b
    assert_true(!reason.is_empty())
  }
  let society = @audit.build_society_spec()
  assert_eq(society.blocks.length(), 206)
  for b in society.blocks {
    let (_, _, reason) = b
    assert_true(!reason.is_empty())
  }
}

///|
/// 变异网：三台机 × 六族破坏 = 18 处，每一处都要被抓到，且报出的家族必须
/// 落在该族对应的家族上（比「报了些什么」更强：报了别的家族不算数）。
test "迁移表变异网：18 处破坏逐处被抓，且家族对得上" {
  let mutants = @audit.table_mutants()
  assert_eq(mutants.length(), 18)
  let machines : Array[String] = []
  for m in mutants {
    let mut fresh = false
    for name in machines {
      if name == m.machine {
        fresh = true
      }
    }
    if !fresh {
      machines.push(m.machine)
    }
  }
  assert_eq(machines.length(), 3)
  for m in mutants {
    let found = @audit.families_of(m.spec)
    assert_true(found.length() > 0)
    if m.expect != "任意" {
      let mut hit = false
      for f in found {
        if f == m.expect {
          hit = true
        }
      }
      assert_true(hit)
    }
  }
}

///|
/// 变异网是只读的：它改的是现搭的副本，真表一个字节都不动。
/// 判据是「跑完变异网之后，真表的发现数与跑之前一样」。
test "变异网只读：跑完一遍，真表的三鉴结果不变" {
  let before = @audit.families_of(@audit.build_group_spec())
  let _ = @audit.table_mutants()
  let after = @audit.families_of(@audit.build_group_spec())
  assert_eq(before.length(), after.length())
  let group_before = @audit.families_of(@audit.build_spec())
  let _ = @audit.table_mutants()
  let group_after = @audit.families_of(@audit.build_spec())
  assert_eq(group_before.length(), group_after.length())
}

///|
/// 分层本身要能测。真表上一次发现都没有，所以在真表上「全塞已知设计」与「正确
/// 分层」输出完全一致——只在真表上验分层，等于没验。拿**试造的发现**来验：
/// 两个家族都必进未预期（两台机不设豁免），任何往「已知设计」里塞的改动都变红。
test "分层：不设豁免 ⇒ 试造的发现全部进未预期" {
  let findings = [
    @audit.probe_finding(
      @sacore.FUnusedLocal,
      "试造：某位置从未被进入",
    ),
    @audit.probe_finding(
      @sacore.FUnreachable,
      "试造：某位置从起点不可达",
    ),
    @audit.probe_finding(@sacore.FCondBool, "试造：某处无路没说出口"),
    @audit.probe_finding(@sacore.FMethodError, "试造：某处方法错"),
  ]
  let v = @audit.split_fleet("试造机", findings)
  assert_eq(v.machine, "试造机")
  // 四个家族一个都不豁免：已知设计必须为空
  assert_eq(v.known.length(), 0)
  assert_eq(v.fresh.length(), 4)
}

///|
/// 报告对称：两台机的口径说明、计数表、发现分层都在。
test "报告对称：群体面与变异网报告口径齐全" {
  let fleet = @audit.render_fleet_report()
  assert_true(fleet.contains("三鉴"))
  assert_true(fleet.contains("没有驱动槽"))
  assert_true(fleet.contains("没有终点"))
  assert_true(fleet.contains("未预期"))
  assert_true(fleet.contains("群体"))
  assert_true(fleet.contains("社会"))
  let mutants = @audit.render_mutation_report()
  assert_true(mutants.contains("变异网"))
  assert_true(mutants.contains("期望"))
  assert_true(mutants.contains("6／6"))
}
