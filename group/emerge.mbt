///|
/// 群体状态的涌现：从成员主体（multi 层的 Subject）算出群体状态。
///
/// 这是把 R1–R12 的**两两遭遇**闭合到群体尺度。判定次序本身也是内容：
/// 先看有没有人把第三者绝对化（R8），再看体制是否相左（R1／R8），
/// 再看是不是每一对都双诚俱足（R12），最后才落到共同语言或商谈网络。

///|
/// 成员里是否有人已在主体层「投射」（把第三者交给绝对者）。
fn any_projected(members : Array[@multi.Subject]) -> Bool {
  for m in members {
    if m.state == @sm.Idol {
      return true
    }
  }
  false
}

///|
/// 成员里是否有人已「自缚」或「隐没」。
fn any_bound(members : Array[@multi.Subject]) -> Bool {
  for m in members {
    if m.state == @sm.Binding || m.state == @sm.Secret {
      return true
    }
  }
  false
}

///|
/// 成员里是否有人已在「失权」或「痛苦」。
fn any_wounded(members : Array[@multi.Subject]) -> Bool {
  for m in members {
    if m.state == @sm.Guilt || m.state == @sm.Suffering {
      return true
    }
  }
  false
}

///|
/// 两两体制相左的对数（只有都进入商谈的体制才计入，内在秩序者不算）。
pub fn clashing_pairs(members : Array[@multi.Subject]) -> Int {
  let n = members.length()
  let mut clash = 0
  for i = 0; i < n; i = i + 1 {
    for j = i + 1; j < n; j = j + 1 {
      let a = members[i]
      let b = members[j]
      if a.regime != b.regime &&
        a.regime.seeks_consensus() &&
        b.regime.seeks_consensus() {
        clash += 1
      }
    }
  }
  clash
}

///|
/// 是否每一对成员都同处诚然而双诚俱足（R12 的群体形态）。
pub fn all_attuned(members : Array[@multi.Subject]) -> Bool {
  let n = members.length()
  if n < 2 {
    return false
  }
  for i = 0; i < n; i = i + 1 {
    let a = members[i]
    if a.regime != @multi.ChengRan || !a.cheng.is_complete() {
      return false
    }
    for j = i + 1; j < n; j = j + 1 {
      let b = members[j]
      if b.regime != @multi.ChengRan || !b.cheng.is_complete() {
        return false
      }
      if @multi.cheng_gap(a, b) > 20 {
        return false
      }
    }
  }
  true
}

///|
/// 若全体同处一个体制，返回它。
fn uniform_regime(members : Array[@multi.Subject]) -> @multi.TruthRegime? {
  let n = members.length()
  if n == 0 {
    return None
  }
  let first = members[0].regime
  for i = 1; i < n; i = i + 1 {
    if members[i].regime != first {
      return None
    }
  }
  Some(first)
}

///|
/// 涌现：从成员算出群体状态。
pub fn emerge(members : Array[@multi.Subject]) -> GroupState {
  let n = members.length()
  if n <= 1 {
    return Scattered
  }
  let mut seeking = 0
  for m in members {
    if m.regime.seeks_consensus() {
      seeking += 1
    }
  }
  if seeking <= 1 {
    return Converging
  }
  if any_projected(members) {
    return Projected
  }
  if clashing_pairs(members) > 0 {
    return Confronting
  }
  if all_attuned(members) {
    return Attuned
  }
  if any_bound(members) {
    return Disciplined
  }
  if any_wounded(members) {
    return Wounded
  }
  // R13（纵向）：主体间性还需参与者共同具备理性，否则只是各说各话。
  match uniform_regime(members) {
    Some(@multi.SuperSubjective) => CommonTongue
    Some(@multi.InterSubjective) =>
      if @multi.vertical_ready(members) {
        Discourse
      } else {
        Converging
      }
    Some(@multi.ChengRan) => Normed
    Some(@multi.Logos) => Consensus
    _ => Converging
  }
}

///|
/// 群体尺度上的自洽性：绝不假装封口（R2／R11），且每个成员的谬误残余（R10）仍不为零。
pub fn is_well_formed(g : GroupState, members : Array[@multi.Subject]) -> Bool {
  if g.claims_closure() {
    return false
  }
  if members.length() == 0 {
    return false
  }
  for m in members {
    if m.residue <= 0 {
      return false
    }
  }
  true
}

///|
/// 群体状态回写到成员的认识状态（R7：构成性，而非范导性）。
pub fn feedback(g : GroupState, m : @multi.Subject) -> @multi.Subject {
  @multi.subject(
    m.id,
    member_state_of(g, m.state),
    m.regime,
    m.cheng.toward_other,
    m.cheng.toward_self,
    m.residue,
  )
}

///|
/// 群体状态对应到成员在**主体状态机**里的位置。
fn member_state_of(
  g : GroupState,
  fallback : @sm.SubjectState,
) -> @sm.SubjectState {
  match g {
    Scattered => fallback
    Converging => @sm.Encounter
    CommonTongue => @sm.Opening
    Discourse => @sm.Opening
    Normed => @sm.Ordered
    Consensus => @sm.Harmony
    Dissensus => @sm.Reflection
    Confronting => @sm.Evil
    Partitioned => @sm.Binding
    Projected => @sm.Idol
    Monologic => @sm.Idol
    Disciplined => @sm.Binding
    Concealed => @sm.Secret
    Wounded => @sm.Suffering
    Dispersed => @sm.Loss
    Returning => @sm.Reflection
    Practicing => @sm.Discipline
    Widening => @sm.Marking
    Attuned => @sm.Tranquility
    Settled => @sm.Tranquility
  }
}

///|
/// 演示（R7 构成性，供报告与测试）：把一个群体状态回写到一个「相遇」处的成员，
/// 返回该成员在主体状态机中的新位置名。
pub fn feedback_demo(g : GroupState) -> String {
  let m = @multi.subject(1, @sm.Encounter, @multi.InterSubjective, 70, 70, 9)
  feedback(g, m).state.designation()
}
