///|
/// 黑盒测试：只通过 `@society.…` 公开 API。

///|
test "规模与构成" {
  assert_eq(@society.all_states().length(), 13)
  assert_eq(@society.all_phases().length(), 8)
  assert_eq(@society.transitions().length(), 28)
  assert_eq(@society.initial().designation(), "世界")
  assert_eq(@society.gap().designation(), "缺口")
}

///|
/// 两相之间的震荡：**以波粒二象性等量齐观**——超主体性与主体间性同为常态的两相，
/// 由交往行为的结果判定，谁也不比谁更根本。自环延续当前相位，跨态边换相。
test "两相震荡：超体与间体双向可通，且触发粒度上仍确定" {
  // 跨相：超体上冒出有效性主张 → 间体
  let to_inter = @society.step(@society.Suprasubjective, @society.RaiseClaims)
  assert_true(to_inter.label() == "迁")
  assert_true(to_inter.landing() == Some(@society.Intersubjective))
  // 跨相：主体间性本就「是用语言建立起来的」，语言承担理解 → 超体
  let to_supra = @society.step(@society.Intersubjective, @society.SpeakLanguage)
  assert_true(to_supra.label() == "迁")
  assert_true(to_supra.landing() == Some(@society.Suprasubjective))
  // 自环保留（延续当前相位）
  assert_true(
    @society.step(@society.Suprasubjective, @society.SpeakLanguage).landing() ==
    Some(@society.Suprasubjective),
  )
  // 来回闭合
  match to_inter.landing() {
    Some(g) => {
      let back = @society.step(g, @society.SpeakLanguage)
      assert_true(back.landing() == Some(@society.Suprasubjective))
    }
    None => assert_true(false)
  }
  // 加了震荡边**不**破坏触发确定性：两相各有两句不同触发、各一个去处，故
  // `one_edge_per_trigger` 仍恒真、`Open` 在这台机上仍不可达。这是它与 `group`
  // 机结构上的差别，别混。
  assert_true(@society.one_edge_per_trigger())
  assert_eq(@society.open_pairs().length(), 0)
  assert_true(@society.no_dead_end())
}

///|
test "两字纪律：状态名与阶段名一律两字，且各自互异" {
  let seen : Array[String] = []
  for s in @society.all_states() {
    assert_eq(s.designation().length(), 2)
    assert_true(!seen.contains(s.designation()))
    seen.push(s.designation())
    assert_true(s.gloss().length() > 0)
    assert_true(s.gloss().contains("P."))
  }
  let phases : Array[String] = []
  for p in @society.all_phases() {
    assert_eq(p.label().length(), 2)
    assert_true(!phases.contains(p.label()))
    phases.push(p.label())
  }
}

///|
test "每个状态都可由「世界」抵达，且都有阶段" {
  for s in @society.all_states() {
    assert_true(@society.reachable(@society.initial(), s))
    assert_true(@society.all_phases().contains(s.phase()))
  }
}

///|
test "不封闭：无终态，且「缺口」处处可达" {
  assert_true(@society.no_final_closure())
  for s in @society.all_states() {
    assert_true(@society.successors(s).length() > 0)
    assert_true(@society.reachable(s, @society.gap()))
  }
}

///|
test "谬误残余恒正（R10 的集体形态）" {
  for s in @society.all_states() {
    assert_true(s.residue() > 0)
  }
}

///|
test "主线与病理路径的每一步都由真实迁移连接" {
  for path in [@society.course(), @society.ailment()] {
    let mut i = 0
    while i + 1 < path.length() {
      let a = path[i]
      let b = path[i + 1]
      let mut connected = false
      for entry in @society.successors(a) {
        if entry.1 == b {
          connected = true
        }
      }
      assert_true(connected)
      i += 1
    }
  }
}

///|
test "文本依据非空且带出处分节" {
  let b = @society.basis()
  assert_true(b.length() >= 10)
  for e in b {
    assert_true(e.0.length() > 0)
    assert_true(e.1.contains("P."))
  }
}

///|
test "渲染覆盖全部状态与阶段，并给出两条不变量" {
  let r = @society.render_report()
  for s in @society.all_states() {
    assert_true(r.contains(s.designation()))
  }
  for p in @society.all_phases() {
    assert_true(r.contains(p.label()))
  }
  assert_true(
    r.contains("不变量") || r.contains("双层次社会交往模型"),
  )
  assert_true(r.contains("不封闭"))
  assert_true(r.contains("谬误残余恒正"))
}

///|
test "Mermaid 图含首尾状态" {
  let m = @society.render_mermaid()
  assert_true(m.has_prefix("stateDiagram-v2"))
  assert_true(m.contains("世界"))
  assert_true(m.contains("缺口"))
}
