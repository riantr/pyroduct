///|
/// 黑盒测试：只通过公开 API（`@src.…`）验证状态机的形状与不变量。

///|
fn has_state(xs : Array[@src.SubjectState], s : @src.SubjectState) -> Bool {
  for x in xs {
    if x == s {
      return true
    }
  }
  false
}

///|
fn has_string(xs : Array[String], s : String) -> Bool {
  for x in xs {
    if x == s {
      return true
    }
  }
  false
}

///|
test "规模与构成" {
  assert_eq(@src.all_states().length(), 34)
  assert_eq(@src.all_phases().length(), 11)
  assert_eq(@src.transitions().length(), 53)
  assert_true(@src.initial() == @src.Standing)
  assert_true(@src.terminal() == @src.Tranquility)
}

///|
test "每个状态都有通用定名、原文名与文本依据，且各自互异" {
  let seen : Array[String] = []
  let sources : Array[String] = []
  for s in @src.all_states() {
    assert_true(s.designation().length() > 0)
    assert_true(s.label().length() > 0)
    assert_true(s.gloss().length() > 0)
    assert_true(!has_string(seen, s.designation()))
    assert_true(!has_string(sources, s.label()))
    seen.push(s.designation())
    sources.push(s.label())
  }
}

///|
test "迁移的端点都是已知状态，且触发都有原文说明" {
  let all = @src.all_states()
  for t in @src.transitions() {
    assert_true(has_state(all, t.from))
    assert_true(has_state(all, t.to))
    assert_true(t.trigger.label().length() > 0)
  }
}

///|
test "主线历程每一步都由真实迁移连接" {
  let path = @src.genesis_path()
  assert_true(path[0] == @src.Standing)
  assert_true(path[path.length() - 1] == @src.Tranquility)
  let mut i = 0
  while i + 1 < path.length() {
    let a = path[i]
    let b = path[i + 1]
    let mut connected = false
    for entry in @src.successors(a) {
      if entry.1 == b {
        connected = true
      }
    }
    assert_true(connected)
    i += 1
  }
}

///|
test "可达性与方向性" {
  assert_true(@src.reachable(@src.Standing, @src.Tranquility))
  assert_true(!@src.reachable(@src.Tranquility, @src.Standing))
  for s in @src.all_states() {
    if s == @src.NoPast || s == @src.NoFuture {
      continue
    }
    assert_true(@src.reachable(@src.Standing, s))
  }
}

///|
test "失忆与浑噩是汇入站立的退化起点" {
  assert_eq(@src.successors(@src.NoPast).length(), 1)
  assert_eq(@src.successors(@src.NoFuture).length(), 1)
  assert_true(!@src.reachable(@src.Standing, @src.NoPast))
  assert_true(!@src.reachable(@src.Standing, @src.NoFuture))
}

///|
test "宁静是静定极：自环之外，界域重开会重入环节" {
  let outs = @src.successors(@src.Tranquility)
  assert_eq(outs.length(), 2)
  assert_true(outs[0].1 == @src.Tranquility)
  assert_true(outs[1].1 == @src.Reflection)
}

///|
test "自由刻度先沉后升：失权与沉落最受缚，宁静最自由" {
  let standing : @src.SubjectState = @src.Standing
  let freedom : @src.SubjectState = @src.Freedom
  let guilt : @src.SubjectState = @src.Guilt
  let loss : @src.SubjectState = @src.Loss
  let tranquility : @src.SubjectState = @src.Tranquility
  assert_eq(standing.freedom(), 1)
  assert_eq(freedom.freedom(), 3)
  assert_true(guilt.freedom() < 0)
  assert_true(loss.freedom() < guilt.freedom())
  assert_true(tranquility.freedom() > freedom.freedom())
}

///|
test "三种渲染都覆盖全部状态的通用定名" {
  let mermaid = @src.render_mermaid()
  let dot = @src.render_dot()
  let report = @src.render_report()
  for s in @src.all_states() {
    assert_true(mermaid.contains(s.qualified()))
    assert_true(dot.contains(s.designation()))
    assert_true(report.contains(s.designation()))
  }
  assert_true(report.contains("通往宁静之路"))
  assert_true(mermaid.contains("stateDiagram-v2"))
  assert_true(dot.contains("digraph"))
}

///|
test "通用定名已按主体通用性原则修订，原文名可回溯" {
  let standing : @src.SubjectState = @src.Standing
  let guilt : @src.SubjectState = @src.Guilt
  let idol : @src.SubjectState = @src.Idol
  let discipline : @src.SubjectState = @src.Discipline
  assert_eq(standing.designation(), "立位")
  assert_eq(standing.label(), "站立")
  assert_eq(guilt.designation(), "失权")
  assert_eq(guilt.label(), "罪感")
  assert_eq(idol.designation(), "投射")
  assert_eq(discipline.designation(), "修习")
  assert_true(standing.qualified().contains("原文：站立"))
  assert_eq(standing.phase().designation(), "立位")
}

///|
test "历程是可重入的环节序列：宁静可重入反顾" {
  let path = @src.course()
  assert_eq(path.length(), 31)
  assert_true(path[0] == @src.Standing)
  assert_true(path[path.length() - 1] == @src.Reflection)
  let mut reentry = false
  for entry in @src.successors(@src.Tranquility) {
    if entry.1 == @src.Reflection {
      reentry = true
    }
  }
  assert_true(reentry)
  assert_true(@src.reachable(@src.Tranquility, @src.Reflection))
  assert_true(@src.render_course().contains("↺"))
}

///|
test "定名对照表与原则文本覆盖全部状态与阶段" {
  let table = @src.render_naming_table()
  for s in @src.all_states() {
    assert_true(table.contains(s.designation()))
    assert_true(table.contains(s.label()))
  }
  for p in @src.all_phases() {
    assert_true(table.contains(p.designation()))
  }
  assert_true(@src.revision_principle().contains("主体通用性"))
}

///|
test "通用定名一律两字" {
  for s in @src.all_states() {
    assert_eq(s.designation().length(), 2)
  }
  for p in @src.all_phases() {
    assert_eq(p.designation().length(), 2)
  }
}

///|
test "派生表持久度清单：消费层由出处自己长出，改动影响可查" {
  let m = @src.durability_manifest()
  assert_true(m.length() >= 4)
  let mut graph_row = ""
  let mut contract_row = ""
  for row in m {
    assert_true(row.0.length() > 0)
    assert_true(row.1.length() > 0)
    assert_true(row.2.length() > 0)
    if row.0.contains("迁移图") {
      graph_row = row.1
    }
    if row.0.contains("执行契约") {
      contract_row = row.1
    }
  }
  // 迁移图只消费原文直述层：改槽映射不触发重算。
  assert_true(graph_row.contains("原文直述"))
  assert_true(!graph_row.contains("模型整理"))
  // 槽派生表必然消费模型整理层——揭蔽槽是模型整理，清单运行时算出。
  assert_true(contract_row.contains("原文直述"))
  assert_true(contract_row.contains("模型整理"))
  // 报告对称：清单渲染进主体报告。
  assert_true(@src.render_report().contains("派生表与持久度"))
}
