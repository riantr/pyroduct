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
/// 群体层裁决与主体层同一根轴：己之诚（朝向已往／传统）更盛或持平取共见，他之诚
/// 更盛取共辩。表不动——群体机仍给「未定」，只是本层递了一个偏向下去。
///
/// 判定本体吃两个整数，造得出来，所以两轴换位与边界（相等）都验得到。`Genome`
/// 在包外是只读类型、构造不了，故这里不靠造基因组来验。
test "群体层：双诚之比决定共见／共辩，且表仍如实给未定" {
  // 他之诚更盛：愿意付商谈的代价 ⇒ 共辩
  assert_true(@evolution.group_lean_of(90, 10) == @g.Inter)
  // 己之诚更盛：朝向多代积累的基础共识 ⇒ 共见
  assert_true(@evolution.group_lean_of(10, 90) == @g.Supra)
  // 边界：两轴相等（缺省基因组 70:70 就是这样）⇒ 共见，无必要不付代价
  assert_true(@evolution.group_lean_of(70, 70) == @g.Supra)
  assert_true(@evolution.group_lean_of(0, 0) == @g.Supra)
  // 差一就该翻面——证明判的是大小，不是某个阈值常量
  assert_true(@evolution.group_lean_of(50, 49) == @g.Inter)
  assert_true(@evolution.group_lean_of(49, 50) == @g.Supra)
  // 读取器与本体一致
  assert_true(@evolution.group_lean(@evolution.default_agent()) == @g.Supra)
  // 表那一步仍然只给未定：裁决不在机器里
  let raw = @g.step(@g.Converging, @g.Attention)
  assert_true(raw.label() == "未定")
  // 走一步并递偏向：缺省基因组落在基础共识那一侧
  let stepped = @evolution.group_step(
    @g.Converging,
    @g.Attention,
    @evolution.default_agent(),
  )
  assert_true(stepped.landing() == Some(@g.CommonTongue))
  // 两个去处都还在表里——裁决没删边
  assert_eq(@g.open_pairs().length(), 1)
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
/// 树形：账本是父子结构——无环、父在子前、深度不超世代号。
test "树形：账本是一棵无环的树" {
  for o in [@evolution.truth_objective(), @evolution.thrifty_objective()] {
    let ledger = @evolution.evolve(
      @evolution.default_agent(),
      @evolution.default_world(),
      @evolution.Weighted(o),
      4,
    )
    let faults = ledger.tree_faults()
    assert_eq(faults.length(), 0) // 带理由，才知道是哪一条被破坏
    assert_true(ledger.tree_ok())
  }
}

///|
/// 遗传：`evolve` 记的父必须是上一代**被接收**的那条记录，且与它恰好差一处。
///
/// 这两条是承重的。只查「父下标合法」的话，把父写成**世代号**（而一代有十四条
/// 候选，那个编号根本不是下标）照样能过——下标在范围内，只是指错了记录。父指向的
/// 那条是不是下一代真正的起点，只有拿基因组去比才知道。
///
/// `evolve` 修好之前这条是红的（一条四代的账本报出 26 条），那是判据自己有牙的证据。
test "遗传：父子关系是真遗传，不是把世代号当成了下标" {
  for o in [@evolution.truth_objective(), @evolution.thrifty_objective()] {
    let ledger = @evolution.evolve(
      @evolution.default_agent(),
      @evolution.default_world(),
      @evolution.Weighted(o),
      4,
    )
    let faults = ledger.descent_faults()
    assert_eq(faults.length(), 0)
    assert_true(ledger.descent_ok())
    let n = ledger.trails.length()
    for i in 0..<n {
      match ledger.trails[i].parent {
        Some(p) => {
          let par = ledger.trails[p]
          assert_true(par.verdict == @evolution.Accepted)
          assert_eq(
            @evolution.diff_count(par.genome, ledger.trails[i].genome),
            1,
          )
        }
        None =>
          assert_eq(
            @evolution.diff_count(ledger.seed, ledger.trails[i].genome),
            1,
          )
      }
    }
  }
}

///|
/// 树形：树高 = 实际跑到的代数 + 1；根就是第一代的全部候选。
///
/// 这两个数都**从账本自己推**，不写死：`evolve` 在没有可接收的改动时就停（`break`），
/// 所以跑了四代参数不代表账本里有四代——写死 4 会把「爬到哪儿算哪儿」这个行为
/// 当成偶然。
test "树形：树高随代数增长，根就是第一代那批候选" {
  let ledger = @evolution.evolve(
    @evolution.default_agent(),
    @evolution.default_world(),
    @evolution.Weighted(@evolution.truth_objective()),
    4,
  )
  assert_true(ledger.descent_ok())
  let mut max_gen = 0
  for t in ledger.trails {
    if t.generation > max_gen {
      max_gen = t.generation
    }
  }
  assert_true(max_gen >= 1) // 至少爬了一代，否则这棵树没有可测的形状
  assert_eq(ledger.height(), max_gen + 1)
  // 第 0 代全部起根：它们都是种子的单步改动，且此后每一代都挂在被接收的那条下。
  assert_eq(
    ledger.roots().length(),
    @evolution.mutations(@evolution.default_agent()).length(),
  )
}

///|
/// 主体循环的账本**只是**结构上成树，不主张真遗传。
///
/// 它每回合有两个 F_t（修习、开放），而账本只记了修习一个。当被接下的是开放时，
/// 下一回合候选所从出发的那份基因组没有对应记录，父子关系只能断在那里。故
/// `descent_ok` 对它不成立——这是口径不同，不是判据失效，故只断言结构那一半。
///
/// 顺带把口径钉死：判据不是「见红就错」。`descent_ok` 在这本账上为假，
/// 正是它没有对所有账本一律放行的证据。
test "树形：主体循环的账本结构成树，但不主张真遗传" {
  let led = small_cycle(3).ledger()
  assert_true(led.tree_ok())
  assert_eq(led.tree_faults().length(), 0)
  assert_true(!led.descent_ok()) // 记的是尝试的先后，不是遗传
}

///|
/// 树形：世系可读——从根到某条记录，每一步都是「从被接收的父代改一处」。
test "树形：世系串起来是一条可读的改法链" {
  let ledger = @evolution.evolve(
    @evolution.default_agent(),
    @evolution.default_world(),
    @evolution.Weighted(@evolution.truth_objective()),
    4,
  )
  assert_true(ledger.descent_ok())
  // 取任意一条非根记录：世系长度 = 深度 + 1，末两条正是它与它的父。
  let n = ledger.trails.length()
  for i in 0..<n {
    match ledger.trails[i].parent {
      Some(p) => {
        let chain = ledger.ancestry(i)
        assert_eq(chain.length(), ledger.depth(i) + 1)
        assert_eq(chain[chain.length() - 1], i)
        assert_eq(chain[chain.length() - 2], p)
        assert_true(ledger.lineage(i).length() > 0)
        break
      }
      None => ()
    }
  }
}

///|
/// 树形：往返之后仍然是同一棵树（序列化不能把父子关系压平）。
test "树形：序列化往返后父子关系不变" {
  let ledger = @evolution.evolve(
    @evolution.default_agent(),
    @evolution.default_world(),
    @evolution.Weighted(@evolution.truth_objective()),
    4,
  )
  let back = @evolution.parse(ledger.serialize())
  assert_true(back.tree_ok())
  assert_true(back.descent_ok())
  assert_eq(back.height(), ledger.height())
  assert_eq(back.roots(), ledger.roots())
  let last = ledger.trails.length() - 1
  assert_eq(back.lineage(last), ledger.lineage(last))
}

///|
/// 树形：**写坏的账本不能把进程挂住**。
///
/// `ancestry` 向上走，若不设上限，一本把父指到自己或指到后面的账本会让它绕圈到
/// 天荒地老——CI 上就是一个挂到超时的作业，而不是一条报错。所以这里拿两种畸形账本
/// 真跑一遍：一条自指，一条前指。测试跑完本身就是「没挂」的证据。
///
/// 另外验证判据**说得出**坏在哪：不是「不 ok」，而是点名那条记录与那个下标。
///
/// 还要压住一个更隐蔽的失效：早先的 `descent_faults` 在父下标不可分析时**直接跳过**，
/// 于是自指／前指的账本 `descent_ok` 会**真空地成立**——恰恰是结构那一层要抓的畸形，
/// 遗传这一层却报「没问题」。不可分析不等于没问题，所以这两种账本必须两层都红。
test "树形：畸形账本（自指／前指）不挂死，且两层判据都点名" {
  let seed_line = "seed\tsugg|inter|70|70|3|70"
  let obj_line = "objective\t求真"
  let mk = fn(gen : String, parent : String) -> String {
    "trail\t" +
    gen +
    "\t0\t" +
    parent +
    "\tprompt\tacc\t120\t0\t0\t10,20,10,35\tdecl|inter|70|70|3|70\tX\tY"
  }
  // 自指：第 0 条的父就是自己。
  let self_ref = @evolution.parse(
    [seed_line, obj_line, mk("0", "0"), mk("1", "0")].join("\n"),
  )
  assert_eq(self_ref.trails.length(), 2)
  assert_true(!self_ref.tree_ok())
  // 判据要报出**具体几条**坏，而不是给一个布尔了事。
  assert_true(self_ref.tree_faults().length() > 0)
  for f in self_ref.tree_faults() {
    assert_true(f.length() > 0) // 每条都带得动它的下标
  }
  // 父不可分析时遗传层不许「沉默地通过」。
  assert_true(!self_ref.descent_ok())
  assert_true(self_ref.descent_faults().length() > 0)
  // 前指：第 0 条的父指向尚不存在的第 1 条。
  let forward = @evolution.parse(
    [seed_line, obj_line, mk("0", "1"), mk("1", "1")].join("\n"),
  )
  assert_true(!forward.tree_ok())
  assert_true(forward.tree_faults().length() > 0)
  assert_true(!forward.descent_ok())
  // 无论哪种畸形，读它都得有结果（而不是卡住），且祖先里不含越界的下标。
  for bad in [self_ref, forward] {
    for k in 0..<bad.trails.length() {
      for a in bad.ancestry(k) {
        assert_true(a >= 0 && a < bad.trails.length())
      }
    }
  }
}

///|
/// 树形：坏掉的账本要能**说**出哪儿坏了，不能只是「不 ok」。
test "树形：判据只抓真的坏，不抓好的" {
  let ok = @evolution.evolve(
    @evolution.default_agent(),
    @evolution.default_world(),
    @evolution.Weighted(@evolution.truth_objective()),
    4,
  )
  assert_true(ok.tree_ok())
  assert_true(ok.descent_ok())
  assert_eq(ok.descent_faults().length(), 0)
  // 空的账本没有可破坏的东西，不该红。
  let empty = @evolution.parse("seed\tdecl|logos|70|70|3|70")
  assert_true(empty.tree_ok())
  assert_eq(empty.tree_faults().length(), 0)
}

///|
/// 判据要能抓住「下标合法、深度合法、但世代号没往前走」的那本账。
///
/// 早先只查「父在子前」与「深度 ≤ 世代」，于是 `gen3(根) → gen3 → gen4` 能同时骗过
/// 两层：下标在范围内，深度也够。一代只推进一格，所以父必须来自**更早**的世代。
/// 这条判据就是补那个缝的，故必须有它自己会红的证据。
test "树形：同代的父子骗不过世代邻接判据" {
  let seed_line = "seed\tsugg|inter|70|70|3|70"
  let obj_line = "objective\t求真"
  let mk = fn(gen : String, parent : String) -> String {
    "trail\t" +
    gen +
    "\t0\t" +
    parent +
    "\tprompt\tacc\t120\t0\t0\t10,20,10,35\tdecl|inter|70|70|3|70\tX\tY"
  }
  // 世代 3 的根 → 世代 3 的子（同代）→ 世代 4 的孙。
  let same_gen = @evolution.parse(
    [seed_line, obj_line, mk("3", "-"), mk("3", "0"), mk("4", "1")].join("\n"),
  )
  assert_eq(same_gen.trails.length(), 3)
  assert_true(!same_gen.tree_ok()) // 早先这一本是绿的
  assert_true(same_gen.tree_faults().length() > 0)
  // 对照：把中间那条挪到世代 2（父更早），这本就是合法的。
  let ok = @evolution.parse(
    [seed_line, obj_line, mk("2", "-"), mk("3", "0"), mk("4", "1")].join("\n"),
  )
  assert_true(ok.tree_ok())
  assert_eq(ok.tree_faults().length(), 0)
}

///|
/// 判据不能把**合法的**账本判红。`mutations()` 用 `clamp100` 夹取两诚，于是某一层
/// 触底之后再加同一个方向的改动就是**原地踏步**——候选与父代逐字节相同。
///
/// 这不是假想的边界：省力目标、8 代（实际跑到第 7 代）就能撞上，账本里那条候选的
/// 「他／己之诚」写作 `0 → 0`。所以「与父恰好差一处」写死了 `== 1`，而事实是
/// 差 0 处也是合法的。判据红了健康账本，比判据漏了坏账本更糟——它会让人开始忽略它。
test "判据不把原地踏步的合法候选判红" {
  let ledger = @evolution.evolve(
    @evolution.default_agent(),
    @evolution.default_world(),
    @evolution.Weighted(@evolution.thrifty_objective()),
    8,
  )
  assert_true(ledger.tree_ok())
  let faults = ledger.descent_faults()
  assert_eq(faults.length(), 0) // 带理由
  assert_true(ledger.descent_ok())
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
fn small_cycle(rounds : Int32) -> @evolution.SubjectCycle {
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

///|
test "同一份证据不重裁：被拒后的重复回合以首裁判词入账，标注首裁回合" {
  let c = small_cycle(4)
  // 首裁无标注。
  assert_true(!c.events[0].practice.decision.reason.contains("同判"))
  assert_true(!c.events[0].opening.decision.reason.contains("同判"))
  // 上述参数下全部被拒：回合 1 起的输入与回合 0 逐字节相同，判词取自备忘录。
  for i = 1; i < c.events.length(); i = i + 1 {
    let p = c.events[i].practice.decision
    let o = c.events[i].opening.decision
    assert_true(p.reason.contains("[与回合 0 同判·不重裁]"))
    assert_true(o.reason.contains("[与回合 0 同判·不重裁]"))
    assert_true(p.verdict == c.events[0].practice.decision.verdict)
    assert_true(o.verdict == c.events[0].opening.decision.verdict)
    assert_true(p.fitness == c.events[0].practice.decision.fitness)
  }
  // 备忘录不改变结果：两次运行的账本逐字节相同。
  let again = small_cycle(4)
  assert_eq(again.ledger().serialize(), c.ledger().serialize())
}

///|
test "回溯：候选与父代相同则持平，不重跑因果估计" {
  // 残余已在 1：修习触底，候选就是父代本身。
  let g = @evolution.genome(
    @evolution.Suggestive,
    @evolution.all_regimes()[3],
    70,
    70,
    1,
    70,
  )
  let c = @evolution.run_cycle(
    @evolution.cycle_state(@evolution.default_cycle_seed().state, g),
    @evolution.default_world(),
    @evolution.causal_criterion(200),
    1,
  )
  let d = c.events[0].practice.decision
  assert_true(d.verdict == @evolution.Tie)
  assert_true(d.reason.contains("先比较输出，未重跑估计"))
  assert_eq(d.effect, 0)
  // 开放候选（己之诚 70 → 45）是真实改动，仍走因果估计。
  assert_true(c.events[0].opening.decision.reason.contains("因果 θ̂"))
}

///|
test "直觉读法：四条纪律齐备，读法全文覆盖纪律与两极" {
  let ds = @evolution.intuition_disciplines()
  assert_eq(ds.length(), 4)
  let seen : Array[String] = []
  for row in ds {
    assert_true(row.0.length() > 0)
    assert_true(row.1.length() > 0)
    assert_true(!seen.contains(row.0))
    seen.push(row.0)
  }
  let t = @evolution.intuition_principle()
  assert_true(t.contains("模型整理"))
  assert_true(t.contains("背景直觉"))
  assert_true(t.contains("P.43-44"))
  assert_true(t.contains("不是第九个槽"))
  for row in ds {
    assert_true(t.contains(row.0))
  }
  assert_true(t.contains("伽达默尔"))
  assert_true(t.contains("哈贝马斯"))
  assert_true(t.contains("不封闭"))
}

///|
test "报告对称：循环报告指向直觉读法，直觉读法标注出处层" {
  let report = @evolution.render_cycle_report(small_cycle(2))
  assert_true(report.contains("直觉读法（模型整理）"))
  assert_true(report.contains("intuition"))
  let t = @evolution.intuition_principle()
  assert_true(t.contains("持存"))
  assert_true(t.contains("揭蔽"))
}
