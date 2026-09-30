///|
/// 黑盒测试：只通过 `@multi.…` 公开 API，验证十二条规则确实被执行，
/// 以及多主体层不破坏单一主体状态机的可达性。

///|
/// 便捷：造一个从「相遇」出发的主体。
fn at(
  id : Int,
  regime : @multi.TruthRegime,
  other : Int,
  self_ : Int,
) -> @multi.Subject {
  @multi.subject(id, @multi.rendezvous(), regime, other, self_, 9)
}

///|
test "规则表：十四条，编号与依据齐备" {
  let rs = @multi.rules()
  assert_eq(rs.length(), 14)
  for i = 0; i < rs.length(); i = i + 1 {
    assert_true(rs[i].code == "R\{i + 1}")
    assert_true(rs[i].name.length() > 0)
    assert_true(rs[i].text.length() > 0)
    assert_true(rs[i].basis.length() > 0)
  }
  assert_true(@multi.rule("R4") is Some(_))
  assert_true(@multi.rule("R99") is None)
}

///|
test "R4：三种主张各有其时间正位" {
  assert_true(@multi.phase_of(@multi.Sincerity) == @multi.Before)
  assert_true(@multi.phase_of(@multi.Truthfulness) == @multi.During)
  assert_true(@multi.phase_of(@multi.Legitimacy) == @multi.After)
  assert_true(
    @multi.in_phase(@multi.ValidityClaim::{
      kind: @multi.Sincerity,
      phase: @multi.Before,
    }),
  )
  assert_true(
    !@multi.in_phase(@multi.ValidityClaim::{
      kind: @multi.Sincerity,
      phase: @multi.During,
    }),
  )
}

///|
test "R1／R8：超主体性 × 主体间性 → 体制冲突，双方退入受挫" {
  let mid = @multi.ValidityClaim::{
    kind: @multi.Truthfulness,
    phase: @multi.During,
  }
  let out = @multi.encounter(
    at(1, @multi.SuperSubjective, 70, 70),
    at(2, @multi.InterSubjective, 70, 70),
    @multi.Theoretical,
    mid,
  )
  assert_true(out.verdict == @multi.RegimeClash)
  assert_eq(out.a.state.designation(), "受挫")
  assert_eq(out.b.state.designation(), "受挫")
  assert_true(@multi.is_coherent(out))
}

///|
test "同体制：超主体性 / 主体间性 都落到暂时共识与敞开" {
  let mid = @multi.ValidityClaim::{
    kind: @multi.Truthfulness,
    phase: @multi.During,
  }
  for regime in [@multi.SuperSubjective, @multi.InterSubjective] {
    let out = @multi.encounter(
      at(1, regime, 70, 70),
      at(2, regime, 70, 70),
      @multi.Theoretical,
      mid,
    )
    assert_true(out.verdict == @multi.Provisional)
    assert_eq(out.a.state.designation(), "敞开")
    assert_eq(out.b.state.designation(), "敞开")
    assert_true(@multi.is_coherent(out))
  }
}

///|
test "R12：诚然且双诚俱足 → 相契；诚未具足 → 只在暂时共识" {
  let before = @multi.ValidityClaim::{
    kind: @multi.Sincerity,
    phase: @multi.Before,
  }
  let tuned = @multi.encounter(
    at(1, @multi.ChengRan, 80, 80),
    at(2, @multi.ChengRan, 75, 85),
    @multi.Aesthetic,
    before,
  )
  assert_true(tuned.verdict == @multi.Attuned)
  assert_eq(tuned.a.state.designation(), "宁静")
  assert_eq(tuned.b.state.designation(), "宁静")
  // 即便相契，也不冻结历史（R2／R11），残余也不为零（R10）。
  assert_true(tuned.revisable)
  assert_eq(tuned.a.residue, 1)
  assert_true(@multi.is_coherent(tuned))
  let not_yet = @multi.encounter(
    at(1, @multi.ChengRan, 80, 80),
    at(2, @multi.ChengRan, 40, 90),
    @multi.Aesthetic,
    before,
  )
  assert_true(not_yet.verdict == @multi.Provisional)
  assert_eq(not_yet.a.state.designation(), "敞开")
  assert_true(@multi.is_coherent(not_yet))
}

///|
test "古希腊体制的退化：诚差过大 → 独白化（一方投射、一方受挫）" {
  let mid = @multi.ValidityClaim::{
    kind: @multi.Truthfulness,
    phase: @multi.During,
  }
  let out = @multi.encounter(
    at(1, @multi.Logos, 90, 90),
    at(2, @multi.Logos, 30, 30),
    @multi.Theoretical,
    mid,
  )
  assert_true(out.verdict == @multi.Monologic)
  assert_eq(out.a.state.designation(), "投射")
  assert_eq(out.b.state.designation(), "受挫")
  assert_true(
    @multi.cheng_gap(at(1, @multi.Logos, 90, 90), at(2, @multi.Logos, 30, 30)) ==
    60,
  )
  assert_true(@multi.is_coherent(out))
}

///|
test "内在秩序：不寻求——双方位置不动" {
  let mid = @multi.ValidityClaim::{
    kind: @multi.Truthfulness,
    phase: @multi.During,
  }
  let out = @multi.encounter(
    at(1, @multi.Immanent, 70, 70),
    at(2, @multi.Logos, 70, 70),
    @multi.Theoretical,
    mid,
  )
  assert_true(out.verdict == @multi.NotSought)
  assert_eq(out.a.state.designation(), out.b.state.designation())
  assert_true(@multi.is_coherent(out))
}

///|
test "相位错置：主张者归责于己，另一方不动" {
  let mistimed = @multi.ValidityClaim::{
    kind: @multi.Sincerity,
    phase: @multi.During,
  }
  let out = @multi.encounter(
    at(1, @multi.InterSubjective, 70, 70),
    at(2, @multi.InterSubjective, 70, 70),
    @multi.Aesthetic,
    mistimed,
  )
  assert_true(out.verdict == @multi.OutOfPhase)
  assert_eq(out.a.state.designation(), "自归")
  assert_eq(out.b.state.designation(), "相遇")
  assert_true(@multi.is_coherent(out))
}

///|
test "R9：体制相左但走信仰商谈 → 暂时共识（作者构想，仍可修订）" {
  let mid = @multi.ValidityClaim::{
    kind: @multi.Truthfulness,
    phase: @multi.During,
  }
  let out = @multi.encounter(
    at(1, @multi.SuperSubjective, 70, 70),
    at(2, @multi.InterSubjective, 70, 70),
    @multi.Faith,
    mid,
  )
  assert_true(out.verdict == @multi.Provisional)
  assert_true(out.revisable)
  assert_true(@multi.is_coherent(out))
}

///|
test "所有场景都满足多主体层不变量" {
  let sc = @multi.scenarios()
  assert_true(sc.length() >= 8)
  for s in sc {
    let (name, out) = s
    assert_true(name.length() > 0)
    assert_true(@multi.is_coherent(out))
  }
}

///|
test "网络：横边、纵边与共识可达性" {
  let a = at(1, @multi.InterSubjective, 70, 70)
  let b = at(2, @multi.InterSubjective, 70, 70)
  let c = at(3, @multi.InterSubjective, 70, 70)
  let net = @multi.network([a, b, c])
  assert_eq(net.peer_edges, 3)
  assert_eq(net.clashing_pairs, 0)
  assert_true(net.consensus_possible)
  let mixed = @multi.network([
    a,
    b,
    @multi.subject(4, @multi.rendezvous(), @multi.SuperSubjective, 70, 70, 9),
  ])
  assert_eq(mixed.clashing_pairs, 2)
  assert_true(!mixed.consensus_possible)
  // 内在秩序者不进入商谈，因此不构成冲突。
  let with_immanent = @multi.network([
    a,
    b,
    @multi.subject(5, @multi.rendezvous(), @multi.Immanent, 70, 70, 9),
  ])
  assert_eq(with_immanent.clashing_pairs, 0)
  assert_true(with_immanent.consensus_possible)
}

///|
test "谱系与未解难题都被登记，且四类商谈各有其名" {
  let g = @multi.genealogy()
  assert_eq(g.length(), 5)
  for entry in g {
    assert_true(entry.tradition.length() > 0)
    assert_true(entry.view.length() > 0)
  }
  let p = @multi.open_problems()
  assert_eq(p.length(), 3)
  for entry in p {
    assert_true(entry.question.length() > 0)
    assert_true(entry.note.length() > 0)
  }
  assert_eq(@multi.Faith.label(), "信仰商谈")
  assert_eq(@multi.ChengRan.label(), "诚然")
  assert_true(@multi.ChengRan.seeks_consensus())
  assert_true(!@multi.Immanent.seeks_consensus())
  assert_true(@multi.ChengRan.needs_cheng())
  assert_true(!@multi.InterSubjective.needs_cheng())
  assert_eq(
    @multi.SuperSubjective.third(),
    "上帝／绝对者：超脱性只能由它扮演",
  )
}

///|
test "四条有效性主张与「共同检讨」的例外（P.50）" {
  let authentic : @multi.ClaimKind = @multi.Authenticity
  let sincere : @multi.ClaimKind = @multi.Sincerity
  assert_eq(authentic.label(), "他之诚")
  assert_eq(sincere.label(), "己之诚")
  assert_true(@multi.phase_of(authentic) == @multi.Before)
  assert_true(!@multi.requires_joint_review(authentic))
  for k in [sincere, @multi.Truthfulness, @multi.Legitimacy] {
    assert_true(@multi.requires_joint_review(k))
  }
  assert_eq(@multi.citations().length(), 14)
  assert_true(@multi.citation_of("R5").contains("P.23-24"))
  assert_true(@multi.citation_of("R11").contains("P.53"))
}

///|
test "R5／R13：他之诚不进入共同检讨（P.50）" {
  let claim = @multi.ValidityClaim::{
    kind: @multi.Authenticity,
    phase: @multi.Before,
  }
  let out = @multi.encounter(
    at(1, @multi.InterSubjective, 70, 70),
    at(2, @multi.InterSubjective, 70, 70),
    @multi.Aesthetic,
    claim,
  )
  assert_true(out.verdict == @multi.Provisional)
  assert_eq(out.a.state.designation(), "敞开")
  assert_true(@multi.is_coherent(out))
  // 其余主张仍须共同检讨。
  let shared = @multi.ValidityClaim::{
    kind: @multi.Truthfulness,
    phase: @multi.During,
  }
  let out2 = @multi.encounter(
    at(1, @multi.InterSubjective, 70, 70),
    at(2, @multi.InterSubjective, 70, 70),
    @multi.Theoretical,
    shared,
  )
  assert_true(out2.verdict == @multi.Provisional)
  assert_true(@multi.is_coherent(out2))
}

///|
test "R13：纵向的共同理性是可检验的成员属性" {
  let low = @multi.with_reason(at(1, @multi.InterSubjective, 70, 70), 20)
  let ok = at(2, @multi.InterSubjective, 70, 70)
  assert_true(!@multi.vertical_ready([low, ok]))
  assert_true(@multi.vertical_ready([ok, @multi.with_reason(low, 60)]))
  let net = @multi.network([low, ok])
  assert_true(!net.vertical_ok)
  assert_eq(net.min_reason, 20)
  assert_true(!net.consensus_possible)
  assert_true(
    @multi.network([ok, @multi.with_reason(low, 60)]).consensus_possible,
  )
}

///|
test "R14：共识只能以建议的形式发布" {
  assert_true(@multi.rule("R14") is Some(_))
  assert_true(@multi.citation_of("R14").contains("P.50"))
  assert_true(@multi.citation_of("R13").contains("P.50"))
}
