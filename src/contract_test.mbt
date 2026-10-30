///|
/// 黑盒测试：只通过 `@src.…` 公开 API，验证契约层。
///
/// 契约层最容易出的两种毛病，都在这里被按住：
///
/// - **空判据**：契约恒真，等于没写。所以纯函数版的判据要拿**造出来的**坏清单
///   喂，确认它会红。
/// - **空转的回执**：回执与表不相符却没人拦。所以要拿一条**编出来的**回执
///   （点名表里没有的边）去撞契约，确认它被拒。

///|
test "契约表良构：判据双向吻合，且求值点与判据相配" {
  assert_true(@src.contracts_cover_all_checks())
  assert_true(@src.contracts_well_formed())
  assert_eq(@src.contracts().length(), 4)
  assert_eq(@src.all_checks().length(), 4)
}

///|
test "全部契约在全部求值点上成立" {
  let r = @src.check_contracts()
  assert_true(r.ok())
  assert_eq(r.broken, 0)
  assert_eq(r.held, r.checked)
  assert_true(r.checked > 0)
  assert_eq(r.faults.length(), 0)
  // 求值点的数目写死：整机 1 次 × 2 条、阶段 11 次 × 1 条、位置 × 槽 272 次 × 1 条。
  assert_eq(r.checked, 2 + 11 + 272)
}

///|
test "求值点覆盖全部位置 × 槽，且五种回执都出现过" {
  let pts = @src.all_points()
  assert_eq(pts.length(), 34 * 8)
  // 契约若只落在一种回执上，就等于没验到其余四种。五种都要在求值点里出现。
  let mut moved = 0
  let mut held = 0
  let mut open = 0
  let mut same = 0
  let mut block = 0
  for p in pts {
    match p.out {
      @src.Moved(_, _) => moved += 1
      @src.Held(_, _) => held += 1
      @src.Open(_) => open += 1
      @src.Same(_, _, _) => same += 1
      @src.Block(_) => block += 1
    }
  }
  assert_true(moved > 0)
  assert_true(held > 0)
  assert_true(open > 0)
  assert_true(same > 0)
  assert_true(block > 0)
}

///|
test "契约不是空转：拿造出来的坏清单喂纯函数版判据，它会红" {
  // 「有入边却自起点不可达」：把一个可达位置从可达清单里拿掉，它就该被点出来。
  let reachable = @src.reachable_designations()
  let sources = @src.inbound_designations()
  assert_eq(@src.unreachable_of(reachable, sources).length(), 0)
  assert_eq(
    @src.incomingless_of(reachable, sources, @src.initial().designation()).length(),
    0,
  )
  // 造一份坏清单：把一个「有入边」的位置从可达清单里拿掉，它就该被点出来。
  let victim = sources[0]
  let broken_reach : Array[String] = []
  for d in reachable {
    if d != victim {
      broken_reach.push(d)
    }
  }
  let bad = @src.unreachable_of(broken_reach, sources)
  assert_eq(bad.length(), 1)
  assert_eq(bad[0], victim)
  // 「可达却没有入边」：把一个位置的入边拿掉，它就该被点出来。
  // 注意拿的是 **designation**（「无忆」那类），不是 label（「失忆」）；
  // 也不能拿起点——起点没有来路是定义，判据本来就把起点排除在外。
  let start = @src.initial().designation()
  let mut victim = ""
  for d in sources {
    if d != start {
      victim = d
      break
    }
  }
  assert_true(victim.length() > 0)
  let thin : Array[String] = []
  for d in sources {
    if d != victim {
      thin.push(d)
    }
  }
  let miss = @src.incomingless_of(reachable, thin, start)
  assert_eq(miss.length(), 1)
  assert_eq(miss[0], victim)
}

///|
test "回执不许编造：点名表里没有的边，契约必须拒绝" {
  let pts = @src.all_points()
  let mut one = -1
  let mut zero = -1
  for i = 0; i < pts.length(); i = i + 1 {
    let cands = @src.candidates(pts[i].at, pts[i].slot)
    if cands.length() == 1 && one < 0 {
      one = i
    }
    if cands.length() == 0 && zero < 0 {
      zero = i
    }
  }
  assert_true(one >= 0)
  assert_true(zero >= 0)
  // 恰好一条出边的点：真的回执相符；换一条表里没有的边，就不相符。
  let p1 = pts[one]
  let c1 = @src.candidates(p1.at, p1.slot)
  assert_eq(@src.receipt_edges(p1.out).length(), 1)
  assert_true(@src.receipt_matches(p1.at, p1.slot, p1.out))
  let mut other = p1.at
  for s in @src.all_states() {
    if s != c1[0].1 {
      other = s
      break
    }
  }
  assert_true(!@src.receipt_matches(p1.at, p1.slot, @src.Moved(c1[0].0, other)))
  // 没有出边的点：说「无路」相符；说「迁」不相符——缺口不许被说成出路。
  let p0 = pts[zero]
  assert_eq(@src.receipt_edges(p0.out).length(), 0)
  assert_true(@src.receipt_matches(p0.at, p0.slot, p0.out))
  assert_true(
    !@src.receipt_matches(p0.at, p0.slot, @src.Moved(c1[0].0, c1[0].1)),
  )
}

///|
test "轨迹覆盖说得清：走过与未走过的加起来就是全表" {
  let cov = @src.course_coverage()
  assert_eq(cov.total, 53)
  assert_eq(cov.exercised + cov.missing.length(), cov.total)
  assert_true(cov.exercised > 0)
  assert_true(cov.exercised < cov.total)
  // 未走过的那些行必须是迁移表里真有的行——不许凭空虚构一个「没走过」。
  for m in cov.missing {
    let mut found = false
    for t in @src.transitions() {
      if t.from == m.0 && t.trigger == m.1 && t.to == m.2 {
        found = true
      }
    }
    assert_true(found)
  }
}

///|
test "主线轨迹自洽：每一步都是表里真有的边" {
  let tr = @src.course_trace()
  assert_eq(tr.steps.length(), @src.course_trace_steps())
  let mut at = tr.start
  for entry in tr.steps {
    match entry.1 {
      @src.Moved(trg, to) => {
        let mut found = false
        for t in @src.transitions() {
          if t.from == at && t.trigger == trg && t.to == to {
            found = true
          }
        }
        assert_true(found)
        at = to
      }
      @src.Held(trg, s) => {
        let mut found = false
        for t in @src.transitions() {
          if t.from == at && t.trigger == trg && t.to == s {
            found = true
          }
        }
        assert_true(found)
        at = s
      }
      _ => assert_true(false)
    }
  }
}
