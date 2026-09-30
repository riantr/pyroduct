///|
/// 多主体行为规则的执行层：两个主体的遭遇（encounter）。
///
/// 单一主体状态机里的"相遇—敞开—受挫—自归—…"在这里被展开为**联合迁移**：
/// 结果同时取决于双方的**真理体制**（如何对待主体性）、**商谈类型**、
/// **有效性主张的时间位置**，以及两种"诚"的配置。每一次遭遇都落回单一主体
/// 状态机已有的状态，因此多主体层不会凭空造出主体自己到不了的位置。

///|
/// 一个主体在某次交互中的完整面貌。
///
/// `reason` 是**纵向的主体间性**：参与商谈者所共同具备的理性（第四章第五节，P.50）。
/// 横向（各有效性主张之间的相互检讨）与纵向（共同理性）织成那张网，才构成达成
/// 无强制共识的基础；因此它是一个可被检验的成员属性，而不是背景假设。
pub struct Subject {
  id : Int
  state : @sm.SubjectState
  regime : TruthRegime
  cheng : Cheng
  reason : Int // 共同理性，0..100（纵向的主体间性）
  residue : Int // 谬误的残余，恒 > 0
}

///|
/// 构造一个主体。共同理性取 70 作为缺省；需要时用 `with_reason` 显式设定。
pub fn subject(
  id : Int,
  state : @sm.SubjectState,
  regime : TruthRegime,
  toward_other : Int,
  toward_self : Int,
  residue : Int,
) -> Subject {
  {
    id,
    state,
    regime,
    cheng: { toward_other, toward_self, },
    reason: 70,
    residue,
  }
}

///|
/// 设定一个主体的「共同理性」（纵向的主体间性）。
pub fn with_reason(s : Subject, reason : Int) -> Subject {
  {
    id: s.id,
    state: s.state,
    regime: s.regime,
    cheng: s.cheng,
    reason,
    residue: s.residue,
  }
}

///|
/// R13（纵向）：进入商谈者是否**共同具备理性**。低于 50 的人无法与他人在
/// 同一张网里商谈——此时没有共识可言，只有各说各话。
pub fn vertical_ready(subjects : Array[Subject]) -> Bool {
  for s in subjects {
    if s.regime.seeks_consensus() && s.reason < 50 {
      return false
    }
  }
  true
}

///|
/// 遭遇的决断。
pub(all) enum Verdict {
  OutOfPhase // 相位越界：主张落错了时间
  NotSought // 不寻求：真理已在世界之中
  RegimeClash // 体制冲突：超主体性 vs 主体间性
  Monologic // 独白化：对话退化为独白
  Provisional // 暂时共识（可修订）
  Attuned // 相契：双诚俱足
} derive(Eq)

///|
pub extend Verdict with Eq::{not_equal, equal}

///|
/// 决断名。
pub fn Verdict::label(self : Verdict) -> String {
  match self {
    OutOfPhase => "相位越界"
    NotSought => "不寻求"
    RegimeClash => "体制冲突"
    Monologic => "独白化"
    Provisional => "暂时共识"
    Attuned => "相契"
  }
}

///|
/// 一次遭遇的结果。
pub struct EncounterOutcome {
  verdict : Verdict
  a : Subject
  b : Subject
  disclosed : String
  concealed : String
  revisable : Bool
  note : String
}

///|
/// 双方"诚"的差距。
pub fn cheng_gap(a : Subject, b : Subject) -> Int {
  let d1 = (a.cheng.toward_other - b.cheng.toward_other).abs()
  let d2 = (a.cheng.toward_self - b.cheng.toward_self).abs()
  if d1 > d2 {
    d1
  } else {
    d2
  }
}

///|
/// 迁移到新状态；谬误的残余只被削减，**永不为零**（R10）。
fn moved(s : Subject, st : @sm.SubjectState) -> Subject {
  {
    id: s.id,
    state: st,
    regime: s.regime,
    cheng: s.cheng,
    reason: s.reason,
    residue: if s.residue > 1 {
      s.residue - 1
    } else {
      1
    },
  }
}

///|
/// 相契之后的迁移：双诚具足，残余压到最低——但仍不为零（R10）。
fn attuned(s : Subject, st : @sm.SubjectState) -> Subject {
  {
    id: s.id,
    state: st,
    regime: s.regime,
    cheng: { toward_other: 100, toward_self: 100, },
    reason: s.reason,
    residue: 1,
  }
}

///|
/// 组装结果。R2／R3／R11 在这里被固化：永远可修订，「隐」永远非空。
fn outcome(
  verdict : Verdict,
  a2 : Subject,
  b2 : Subject,
  concealed : String,
  note : String,
) -> EncounterOutcome {
  {
    verdict,
    a: a2,
    b: b2,
    disclosed: "已可共享的表述：\{a2.state.designation()} ／ \{b2.state.designation()}",
    concealed,
    revisable: true,
    note,
  }
}

///|
/// 一次遭遇：多主体行为规则的总入口。
pub fn encounter(
  a : Subject,
  b : Subject,
  discourse : DiscourseType,
  claim : ValidityClaim,
) -> EncounterOutcome {
  let concealed = "未穷尽者：\{a.state.gloss()}；\{b.state.gloss()}；以及双方都尚未说出的"
  // R4：有效性主张的时间位置。
  if !in_phase(claim) {
    return outcome(
      OutOfPhase,
      moved(a, @sm.Shame),
      b,
      concealed,
      "在\{discourse.label()}中以\{claim.phase.label()}的位置提出\{claim.kind.label()}，而它的正位是\{phase_of(claim.kind).label()}：主张者让位、归责于己。",
    )
  }
  // R5／R13：他之诚**不进入共同检讨**（第四章第五节，P.50）——它是言语者对自己
  //「内心所言与诉说之言」的担保，只能由他自己承担。因此这一次遭遇不是一次相互
  // 检讨，只把双方推向敲开。
  if !requires_joint_review(claim.kind) {
    return outcome(
      Provisional,
      moved(a, @sm.Opening),
      moved(b, @sm.Opening),
      concealed,
      "\{claim.kind.label()}不进入共同检讨：它是言语者对自己内心与言说之契合的担保，只能由他自己承担（第四章第五节，P.50）。",
    )
  }
  // R1／R8：内在秩序体制根本不进入主张与商谈。
  if a.regime == Immanent || b.regime == Immanent {
    return outcome(
      NotSought,
      a,
      b,
      concealed,
      "真理被当作内在于世界的永恒秩序：人本来就在其中，不必寻求——既不提出主张，也不接受主张。",
    )
  }
  // R1／R8：体制相左。R9 给出信仰商谈这一条作者构想的例外。
  if a.regime != b.regime {
    if discourse == Faith {
      return outcome(
        Provisional,
        moved(a, @sm.Opening),
        moved(b, @sm.Opening),
        concealed,
        "体制相左，但走的是信仰商谈：宗教真理可纳入共识真理理论——（作者构想，尚未成形，故此决断仍带可修订标记）。",
      )
    }
    return outcome(
      RegimeClash,
      moved(a, @sm.Evil),
      moved(b, @sm.Evil),
      concealed,
      "\{a.regime.label()} 对 \{b.regime.label()}：一边说「主体间性」是加倍了的主观主义，一边说对方仍保留着主体哲学遗产。",
    )
  }
  // 同体制。
  match a.regime {
    Immanent =>
      outcome(
        NotSought,
        a,
        b,
        concealed,
        "同上：秩序已在世界之中。",
      )
    Logos =>
      if cheng_gap(a, b) > 20 {
        outcome(
          Monologic,
          moved(a, @sm.Idol),
          moved(b, @sm.Evil),
          concealed,
          "对话之路退化为独白逻辑：诚的差距让一方把逻各斯收归己有，另一方的言说被消音。",
        )
      } else {
        outcome(
          Provisional,
          moved(a, @sm.Opening),
          moved(b, @sm.Opening),
          concealed,
          "对话尚在：双方以理性灵魂互相担保，暂时共享一个逻各斯。",
        )
      }
    SuperSubjective =>
      outcome(
        Provisional,
        moved(a, @sm.Opening),
        moved(b, @sm.Opening),
        concealed,
        "理解与语言是超主体事件——是语言在言说我们；第三者（上帝／绝对者）尚未被任何一方独占。",
      )
    InterSubjective =>
      outcome(
        Provisional,
        moved(a, @sm.Opening),
        moved(b, @sm.Opening),
        concealed,
        "真理即主体间有效性主张：横（主体之间）纵（对理性）交织成网，共识是网上的临时节点。",
      )
    ChengRan =>
      if a.cheng.is_complete() && b.cheng.is_complete() {
        outcome(
          Attuned,
          attuned(a, @sm.Tranquility),
          attuned(b, @sm.Tranquility),
          concealed,
          "他之诚与己之诚俱足：澄然与诚然统于自性内照，入于无人我、齐万物之境。",
        )
      } else {
        outcome(
          Provisional,
          moved(a, @sm.Opening),
          moved(b, @sm.Opening),
          concealed,
          "诚未具足：向他的意向或意向—行为的契合尚缺其一，先停在暂时共识上。",
        )
      }
  }
}

///|
/// 主体间网络：横边＝同体制主体之间的对称关联；纵边＝主体与共同规范轴（理性）的关联。
pub struct NetworkReport {
  peer_edges : Int
  norm_edges : Int
  clashing_pairs : Int
  consensus_possible : Bool
  vertical_ok : Bool
  min_reason : Int
}

///|
/// 由一组主体算出一张「横纵交织」的网。
pub fn network(subjects : Array[Subject]) -> NetworkReport {
  let n = subjects.length()
  let mut peer = 0
  let mut norm = 0
  let mut clash = 0
  let mut seeking = 0
  for s in subjects {
    if s.regime.seeks_consensus() {
      seeking += 1
    }
    if s.regime == Logos || s.regime == InterSubjective || s.regime == ChengRan {
      norm += 1
    }
  }
  // R13（横向 vs 纵向）：纵向看参与者是否共同具备理性。
  let mut min_reason = 100
  for s in subjects {
    if s.regime.seeks_consensus() && s.reason < min_reason {
      min_reason = s.reason
    }
  }
  for i = 0; i < n; i = i + 1 {
    for j = i + 1; j < n; j = j + 1 {
      let ra = subjects[i].regime
      let rb = subjects[j].regime
      if ra == rb {
        if ra.seeks_consensus() {
          peer += 1
        }
      } else if ra.seeks_consensus() && rb.seeks_consensus() {
        clash += 1
      }
    }
  }
  {
    peer_edges: peer,
    norm_edges: norm,
    clashing_pairs: clash,
    consensus_possible: clash == 0 &&
    (seeking <= 1 || peer >= seeking - 1) &&
    vertical_ready(subjects),
    vertical_ok: vertical_ready(subjects),
    min_reason,
  }
}

///|
/// 多主体层的入口状态：遭遇发生处的「相遇」。
pub fn rendezvous() -> @sm.SubjectState {
  @sm.Encounter
}

///|
/// 自洽性检查（多主体层不变量）：
///
/// 1. 结果状态都落在单一主体状态机从「相遇」出发的可达范围内——多主体规则不造新位置；
/// 2. R2／R11：永远可修订；
/// 3. R3：「隐」永远非空；
/// 4. R10：谬误的残余永远不为零。
pub fn is_coherent(out : EncounterOutcome) -> Bool {
  @sm.reachable(@sm.Encounter, out.a.state) &&
  @sm.reachable(@sm.Encounter, out.b.state) &&
  out.revisable &&
  out.concealed.length() > 0 &&
  out.disclosed.length() > 0 &&
  out.a.residue > 0 &&
  out.b.residue > 0
}
