///|
/// 黑盒测试：只通过 `@evolution.…` 公开 API。

///|
/// 取第一个合宪的候选。
fn first_constitutional(
  ms : Array[@evolution.Candidate],
) -> @evolution.Candidate? {
  for m in ms {
    if @evolution.constitutional(m.genome) {
      return Some(m)
    }
  }
  None
}

///|
test "变异空间可枚举，且每个候选只改一处、四点位齐备" {
  let g = @evolution.default_agent()
  let ms = @evolution.mutations(g)
  assert_eq(ms.length(), 14)
  let loci : Array[@evolution.Locus] = []
  for c in ms {
    assert_true(c.what.length() > 0)
    assert_eq(@evolution.diff_count(g, c.genome), 1)
    if !loci.contains(c.locus) {
      loci.push(c.locus)
    }
  }
  assert_eq(loci.length(), 4)
  assert_eq(@evolution.all_regimes().length(), 5)
}

///|
test "宪法三条不变量：缺一即违宪" {
  assert_eq(@evolution.constitution().length(), 3)
  let g = @evolution.default_agent()
  assert_true(@evolution.constitutional(g))
  let when_voice = @evolution.genome(
    @evolution.Declarative,
    g.regime,
    70,
    70,
    3,
    70,
  )
  let when_memory = @evolution.genome(g.voice, g.regime, 70, 70, 0, 70)
  let when_open = @evolution.genome(g.voice, g.regime, 0, 70, 3, 70)
  assert_true(!@evolution.constitutional(when_voice))
  assert_true(!@evolution.constitutional(when_memory))
  assert_true(!@evolution.constitutional(when_open))
}

///|
test "闸门：三种判词各就各位" {
  let g = @evolution.default_agent()
  let world = @evolution.default_world()
  let o = @evolution.truth_objective()
  let ms = @evolution.mutations(g)
  // 第一个候选是「发言框架 → 宣告」，违宪。
  let bad = ms[0]
  let rejected = @evolution.judge(g, 0, bad, world, @evolution.Weighted(o))
  assert_true(rejected.verdict == @evolution.RejectedConstitutional)
  // 取一个合宪候选：分数极低 → 接收；分数极高 → 回滚。
  let ok = match first_constitutional(ms) {
    Some(c) => c
    None => fail("变异空间里应有合宪候选")
  }
  let accepted = @evolution.judge(
    g,
    -1000000,
    ok,
    world,
    @evolution.Weighted(o),
  )
  assert_true(accepted.verdict == @evolution.Accepted)
  let rolled = @evolution.judge(g, 1000000, ok, world, @evolution.Weighted(o))
  assert_true(rolled.verdict == @evolution.RevertedRegression)
}

///|
test "记忆可增可减：病理使残余上升，共识使残余下降" {
  let g = @evolution.default_agent()
  let rs = @evolution.all_regimes()
  let immanent = @evolution.opponent("内在秩序者", rs[0], 70, 70, 70, 9)
  let peer = @evolution.opponent("主体间性同侪", rs[3], 70, 70, 70, 9)
  let up = @evolution.evaluate(g, [immanent])
  let down = @evolution.evaluate(g, [peer])
  assert_true(up.residue > g.carry)
  assert_true(down.residue < g.carry)
}

///|
test "进化：换目标函数则换「更好」，且从不破宪、分数不降" {
  let seed = @evolution.default_agent()
  let world = @evolution.default_world()
  for o in [@evolution.truth_objective(), @evolution.thrifty_objective()] {
    let ledger = @evolution.evolve(seed, world, @evolution.Weighted(o), 4)
    let g = ledger.current()
    assert_true(@evolution.constitutional(g))
    assert_true(ledger.accepted_count() >= 1)
    let seed_score = @evolution.score(@evolution.evaluate(seed, world), o)
    let final_score = @evolution.score(@evolution.evaluate(g, world), o)
    assert_true(final_score >= seed_score)
  }
}

///|
test "持久化：写下、读回、接着跑" {
  let seed = @evolution.default_agent()
  let world = @evolution.default_world()
  let ledger = @evolution.evolve(
    seed,
    world,
    @evolution.Weighted(@evolution.truth_objective()),
    3,
  )
  let text = ledger.serialize()
  let back = @evolution.parse(text)
  assert_eq(back.serialize(), text)
  assert_true(back.current() == ledger.current())
  assert_eq(back.accepted_count(), ledger.accepted_count())
  assert_eq(back.rejected_count(), ledger.rejected_count())
  assert_eq(back.trails.length(), ledger.trails.length())
}

///|
test "遗传：子代＝父代 + 一处改动；宪法不在基因组里" {
  let g = @evolution.default_agent()
  for c in @evolution.mutations(g) {
    assert_true(@evolution.descend(g, c) == c.genome)
    assert_eq(@evolution.diff_count(g, c.genome), 1)
  }
  // 一切被接收过的后代都合宪——宪法从未被变异改坏过。
  let ledger = @evolution.evolve(
    g,
    @evolution.default_world(),
    @evolution.Weighted(@evolution.truth_objective()),
    3,
  )
  for t in ledger.trails {
    if t.verdict == @evolution.Accepted {
      assert_true(@evolution.constitutional(t.genome))
    }
  }
}

///|
test "报告覆盖五个机制" {
  let r = @evolution.render_report()
  for
    k in [
      "变异空间", "适应度目标", "更新闸门", "持久化", "遗传",
    ] {
    assert_true(r.contains(k))
  }
  assert_true(r.contains("往返校验"))
}

///|
/// 取一个 `what` 含 `needle` 的候选。
fn candidate_named(
  g : @evolution.Genome,
  needle : String,
) -> @evolution.Candidate? {
  for c in @evolution.mutations(g) {
    if c.what.contains(needle) {
      return Some(c)
    }
  }
  None
}

///|
test "因果：DoubleML 还原真值，朴素估计被自选抬高" {
  let g = @evolution.default_agent()
  let world = @evolution.default_world()
  let worse = match candidate_named(g, "内在秩序") {
    Some(c) => c
    None => fail("应有「体制 → 内在秩序」的候选")
  }
  let v = @evolution.causal_verdict(g, worse.genome, world)
  assert_true(v.truth < 0.0) // 真值：其实更差
  assert_true(v.naive > 0.0) // 朴素：被自选抬成正的
  assert_true(v.theta < 0.0) // DoubleML：把符号扳回
  assert_true((v.theta - v.truth).abs() < 0.12)
}

///|
test "因果闸门：挡住「看起来更好」的改动，放行真正更好的" {
  let g = @evolution.default_agent()
  let world = @evolution.default_world()
  let worse = match candidate_named(g, "内在秩序") {
    Some(c) => c
    None => fail("缺候选")
  }
  let rejected = @evolution.judge(
    g,
    0,
    worse,
    world,
    @evolution.causal_criterion(400),
  )
  assert_true(rejected.verdict == @evolution.RevertedRegression)
  assert_true(rejected.effect < 0)
  let better = match candidate_named(g, "诚然") {
    Some(c) => c
    None => fail("缺候选")
  }
  let accepted = @evolution.judge(
    g,
    0,
    better,
    world,
    @evolution.causal_criterion(400),
  )
  assert_true(accepted.verdict == @evolution.Accepted)
  assert_true(accepted.effect > 0)
  assert_true(accepted.effect_lo > 0)
}

///|
test "因果进化：被接收的改动效应皆为正，且账本可往返" {
  let seed = @evolution.default_agent()
  let world = @evolution.default_world()
  let ledger = @evolution.evolve(
    seed,
    world,
    @evolution.causal_criterion(400),
    3,
  )
  assert_true(@evolution.constitutional(ledger.current()))
  for t in ledger.trails {
    if t.verdict == @evolution.Accepted {
      assert_true(t.effect > 0)
    }
  }
  let text = ledger.serialize()
  assert_eq(@evolution.parse(text).serialize(), text)
}

///|
/// 主体循环：从立位出发，在缺省世界里走 `rounds` 回合（因果判据）。
fn small_cycle(rounds : Int) -> @evolution.SubjectCycle {
  @evolution.run_cycle(
    @evolution.default_cycle_seed(),
    @evolution.default_world(),
    @evolution.causal_criterion(200),
    rounds,
  )
}

///|
test "主体循环：位置只按迁移表推进，每步都留下未穷尽者，配置皆合宪" {
  let c = small_cycle(3)
  assert_eq(c.events.length(), 3)
  assert_true(c.legal())
  assert_true(c.never_closed())
  assert_true(c.finished().genome.carry >= 1)
}

///|
test "主体循环：未定不掷骰子——由双诚之比裁决，绝无以未定推进位置" {
  let c = small_cycle(3)
  for e in c.events {
    assert_true(e.outcome.label() != "未定")
    assert_true(e.remainder.length() > 0)
  }
}

///|
test "主体循环：被接收的修习效应皆为正，账本只追加且可往返、可重放" {
  let c = small_cycle(2)
  let led = c.ledger()
  assert_eq(led.trails.length(), 2)
  for t in led.trails {
    if t.verdict == @evolution.Accepted {
      assert_true(t.effect > 0)
      assert_true(t.effect_lo > 0)
    }
  }
  let text = led.serialize()
  assert_eq(@evolution.parse(text).serialize(), text)
  assert_true(@evolution.parse(text).seed == @evolution.default_agent())
  let again = small_cycle(2)
  assert_eq(again.ledger().serialize(), text)
}

///|
test "主体循环：反馈不由标签给出——报告同时打印四分量与判词" {
  let report = @evolution.render_cycle_report(small_cycle(2))
  assert_true(report.contains("主体循环"))
  assert_true(report.contains("共识"))
  assert_true(report.contains("未穷尽"))
  assert_true(report.contains("修习"))
}
