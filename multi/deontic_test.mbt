///|
/// 黑盒测试：只通过 `@multi.…` 公开 API，验证规范推理的形式化层。
///
/// 这一层与遭遇层（`encounter`）是**两份副本**：遭遇层是模型，本层是它的独立
/// 读法。所以这里最要紧的判据不是「本层自洽」，而是**两份副本对同一批情形给出
/// 同一个判词**——改了其一而忘了其二，这道锁立刻红。

///|
/// 便捷：造一个主体。
fn who(
  id : Int32,
  regime : @multi.TruthRegime,
  other : Int32,
  self_ : Int32,
) -> @multi.Subject {
  @multi.subject(id, @multi.rendezvous(), regime, other, self_, 9)
}

///|
/// 落在正位的主张（真实性＝事中）。
fn timely() -> @multi.ValidityClaim {
  @multi.ValidityClaim::{ kind: @multi.Truthfulness, phase: @multi.During, }
}

///|
/// 错位的主张（真实性被提到事前）。
fn mistimed() -> @multi.ValidityClaim {
  @multi.ValidityClaim::{ kind: @multi.Truthfulness, phase: @multi.Before, }
}

///|
/// 全部判词分支的语料：每一支 if 链都有一例，且期望判词写在这里。
///
/// 十一例覆盖：相位越界、他之诚不共检、内在秩序、体制冲突、信仰商谈例外、
/// 独白化、逻各斯相左、主体间性、超主体性、相契、诚未具足。
fn corpus() -> Array[
  (
    @multi.Subject,
    @multi.Subject,
    @multi.DiscourseType,
    @multi.ValidityClaim,
    @multi.Verdict,
  ),
] {
  [
    // 相位越界：主张错位，判词越界（即便双方同体制、且本可共识）。
    (
      who(1, @multi.Logos, 90, 90),
      who(2, @multi.Logos, 90, 90),
      @multi.Theoretical,
      mistimed(),
      @multi.OutOfPhase,
    ),
    // 他之诚只由言语者自担，不进入共同检讨。
    (
      who(1, @multi.Logos, 90, 90),
      who(2, @multi.Logos, 90, 90),
      @multi.Theoretical,
      @multi.ValidityClaim::{ kind: @multi.Authenticity, phase: @multi.Before, },
      @multi.Provisional,
    ),
    // 内在秩序：真理已在世界之中。
    (
      who(1, @multi.Immanent, 90, 90),
      who(2, @multi.Logos, 90, 90),
      @multi.Theoretical,
      timely(),
      @multi.NotSought,
    ),
    // 体制相左（非信仰商谈）：冲突。
    (
      who(1, @multi.Logos, 90, 90),
      who(2, @multi.SuperSubjective, 90, 90),
      @multi.Theoretical,
      timely(),
      @multi.RegimeClash,
    ),
    // 信仰商谈的例外：宗教真理可纳入共识真理理论。
    (
      who(1, @multi.Logos, 90, 90),
      who(2, @multi.SuperSubjective, 90, 90),
      @multi.Faith,
      timely(),
      @multi.Provisional,
    ),
    // 逻各斯体制下诚的差距过大：独白化。
    (
      who(1, @multi.Logos, 90, 90),
      who(2, @multi.Logos, 20, 90),
      @multi.Theoretical,
      timely(),
      @multi.Monologic,
    ),
    // 逻各斯体制下差距不大：对话尚在。
    (
      who(1, @multi.Logos, 90, 90),
      who(2, @multi.Logos, 80, 85),
      @multi.Theoretical,
      timely(),
      @multi.Provisional,
    ),
    // 超主体性：第三者尚未被任何一方独占。
    (
      who(1, @multi.SuperSubjective, 90, 90),
      who(2, @multi.SuperSubjective, 90, 90),
      @multi.Theoretical,
      timely(),
      @multi.Provisional,
    ),
    // 主体间性：共识是网上的临时节点。
    (
      who(1, @multi.InterSubjective, 90, 90),
      who(2, @multi.InterSubjective, 90, 90),
      @multi.Theoretical,
      timely(),
      @multi.Provisional,
    ),
    // 诚然体制下双诚俱足：相契。
    (
      who(1, @multi.ChengRan, 90, 90),
      who(2, @multi.ChengRan, 90, 90),
      @multi.Theoretical,
      timely(),
      @multi.Attuned,
    ),
    // 诚然体制下诚未具足：先停在暂时共识上。
    (
      who(1, @multi.ChengRan, 90, 40),
      who(2, @multi.ChengRan, 90, 40),
      @multi.Theoretical,
      timely(),
      @multi.Provisional,
    ),
  ]
}

///|
test "形式化层与遭遇层在全部判词分支上给出同一个判词" {
  let cs = corpus()
  assert_eq(cs.length(), 11)
  for c in cs {
    let derived = @multi.derive_chain(c.0, c.1, c.2, c.3)
    assert_true(derived is Some(_))
    let d = derived.unwrap()
    let model = @multi.encounter(c.0, c.1, c.2, c.3)
    assert_true(d.verdict == c.4)
    assert_true(d.verdict == model.verdict)
    assert_true(@multi.agrees_with_encounter(c.0, c.1, c.2, c.3))
  }
}

///|
test "规则库自身自洽：优先序是总序，击败关系无环" {
  assert_true(@multi.precedence_is_total())
  assert_true(@multi.defeaters_acyclic())
}

///|
test "十四条 R 编号各归其类，且没有一条归两次" {
  let rs = @multi.rules()
  assert_eq(rs.length(), 14)
  for r in rs {
    assert_true(@multi.classified(r.code))
    // 归类互斥：既在裁决规范里、又在背景表里，就是归了两次。
    let mut in_norm = false
    for n in @multi.norms() {
      if n.basis.contains(r.code) {
        in_norm = true
      }
    }
    let mut in_bg = false
    for bg in @multi.background() {
      if bg.0 == r.code {
        in_bg = true
      }
    }
    assert_true(!(in_norm && in_bg))
  }
  assert_true(@multi.classification_complete())
  assert_true(@multi.classification_disjoint())
  // 十四条的归属恰好铺满：裁决规范里的编号与背景表里的编号互不相交、并集为十四条。
  // 一条 R 编号**可以**同时是好几条裁决规范的依据（R1 是 D3 与 D4 共同的根据），
  // 所以这里查的是并集与交集，不是「每条只出现一次」。
  let decided : Array[String] = []
  for n in @multi.norms() {
    for c in n.basis {
      if !decided.contains(c) {
        decided.push(c)
      }
    }
  }
  let held : Array[String] = []
  for bg in @multi.background() {
    assert_true(!decided.contains(bg.0))
    held.push(bg.0)
  }
  assert_eq(decided.length() + held.length(), 14)
  for r in rs {
    assert_true(decided.contains(r.code) || held.contains(r.code))
  }
}

///|
test "信仰商谈的例外走的是击败，不是优先" {
  // 这是「除非」关系的形状：优先序只说「两条都成立时谁赢」，说不出「除非」。
  // 所以 D4 必须出现在 `defeated` 里——它**退出**推演，而不是「让位」。
  let c = corpus()[4]
  let d = @multi.derive_chain(c.0, c.1, c.2, c.3).unwrap()
  assert_true(d.verdict == @multi.Provisional)
  let mut beaten = false
  for x in d.defeated {
    if x.target == "D4" && x.by == "D5" {
      beaten = true
    }
  }
  assert_true(beaten)
  // 并且 D4 不许同时出现在让位名单里——那会把「击败」说成「排序」。
  for x in d.outranked {
    assert_true(x.loser != "D4")
  }
  assert_true(d.accepted.contains("D5"))
}

///|
test "让位（软）确实会发生：被压过的规范让位，不是退出" {
  // 内在秩序 × 逻各斯：体制相左那条也前提齐备，但它是被**优先序**压住的，
  // 不是被击败的——它仍然成立，只是结论让位了。
  let c = corpus()[2]
  let d = @multi.derive_chain(c.0, c.1, c.2, c.3).unwrap()
  assert_true(d.verdict == @multi.NotSought)
  let mut lost = false
  for x in d.outranked {
    if x.loser == "D4" && x.winner == "D3" {
      lost = true
    }
  }
  assert_true(lost)
  // 被让位者仍在触发名单里（它前提齐备），但不在接受名单里。
  assert_true(d.fired.contains("D4"))
  assert_true(!d.accepted.contains("D4"))
}

///|
test "硬击败与软让位是两笔不同的账" {
  // 击败与让位都必须可达，否则有一笔永远是空账——空账不是判据。
  let faith = corpus()[4]
  let imm = corpus()[2]
  let df = @multi.derive_chain(faith.0, faith.1, faith.2, faith.3).unwrap()
  let di = @multi.derive_chain(imm.0, imm.1, imm.2, imm.3).unwrap()
  assert_true(df.defeated.length() > 0)
  assert_eq(di.defeated.length(), 0)
  assert_true(di.outranked.length() > 0)
}

///|
test "推导链说得出结论与依据" {
  let c = corpus()[9]
  let d = @multi.derive_chain(c.0, c.1, c.2, c.3).unwrap()
  assert_true(d.verdict == @multi.Attuned)
  assert_true(d.winner.length() > 0)
  assert_true(d.note.length() > 0)
  let text = @multi.render_derivation(d)
  assert_true(text.contains("推导链"))
  assert_true(text.contains("相契"))
  assert_true(text.contains(d.winner))
  // 击败与让位两节只在非空时出现，不许印一个空章节。
  assert_true(!text.contains("## 击败"))
}
