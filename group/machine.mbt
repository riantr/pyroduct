///|
/// 群体状态机 —— 主体状态机的上一层。
///
/// 单位从「一个主体」换成「一个群体」：一群主体因彼此的遭遇（multi 包的 R1–R12）
/// 而聚成一个有自身状态的群体，并在群体尺度上重演同一段节奏——聚、立序、分歧、
/// 失度、自缚、受损、修习、宁定。规则不变，尺度改变；群体的"投射"对应主体的
/// 「投射」，群体的"自缚"对应主体的「自缚」，群体的"宁定"对应主体的「宁静」。
///
/// 命名沿用两条既定纪律：**主体通用性**（只指称结构关系）与**一律两字**。

///|
/// 群体所处的状态（20 个，两字）。
pub(all) enum GroupState {
  Scattered // 散在：众人只是一群，尚无关联
  Converging // 趋同：注意开始汇聚，尚未成体
  CommonTongue // 共语：以共同语言／传统相承（超主体性的群体形态）
  Discourse // 商谈：相互提出有效性主张，横纵成网（主体间性的群体形态）
  Normed // 规范：由理由或传统立起共同规矩
  Consensus // 共识：可修订的暂时一致
  Dissensus // 歧见：差异被承认为差异
  Confronting // 对峙：体制相左，双方受挫
  Partitioned // 割据：界域关闭，各守一方
  Projected // 投射：群体把第三者交给绝对者
  Monologic // 独白：众声退化为一个声音
  Disciplined // 规训：群体把自己与成员束缚起来
  Concealed // 遮蔽：隐被压制，不许再问
  Wounded // 创伤：集体伤口反复被揭开
  Dispersed // 离散：群体分解
  Returning // 复归：有人回头重新打开追问
  Practicing // 修习：集体消除暗礁
  Widening // 扩界：界域扩大，新的东西被纳入
  Attuned // 相契：每一对成员皆双诚俱足
  Settled // 宁定：不再把任何结论绝对化，静待下一刻
} derive(Eq)

///|
pub extend GroupState with Eq::{not_equal, equal}

///|
/// 群体阶段（九个，两字）。
pub(all) enum GroupPhase {
  Gathering // 聚散
  Bodied // 成体
  Ordering // 立序
  Diverging // 分歧
  Excess // 失度
  SelfBound // 自缚
  Impaired // 受损
  Cultivating // 修习
  Resting // 宁定
} derive(Eq)

///|
pub extend GroupPhase with Eq::{not_equal, equal}

///|
/// 推动群体迁移的触发。
pub(all) enum GroupTrigger {
  Appear // 众人出现
  Attention // 注意汇聚
  SharedMedium // 共同语言／传统承担理解
  RaiseClaims // 相互提出有效性主张
  NormFromTradition // 由传统立规
  NormFromReason // 由理由立规
  Agree // 达成暂时一致
  Differ // 差异被承认为差异
  Clash // 体制相左
  CloseHorizon // 界域关闭
  Absolutize // 把第三者交给绝对者
  OneVoice // 众声归一
  Bind // 群体把成员束缚
  Suppress // 压制未穷尽者
  Reopen // 旧伤被重新揭开
  BreakUp // 群体分解
  TurnBack // 有人回头重新追问
  RemoveReefs // 集体消除暗礁
  Widen // 界域扩大
  MutualCheng // 双诚俱足
  Settle // 不再绝对化，静待下一刻
  Reenter // 界域重开，环节重入
} derive(Eq)

///|
pub extend GroupTrigger with Eq::{not_equal, equal}

///|
/// 一条群体迁移。
pub struct GroupTransition {
  from : GroupState
  trigger : GroupTrigger
  to : GroupState
}

///|
/// 状态的中文名（两字）。
pub fn GroupState::designation(self : GroupState) -> String {
  match self {
    Scattered => "散在"
    Converging => "趋同"
    CommonTongue => "共语"
    Discourse => "商谈"
    Normed => "规范"
    Consensus => "共识"
    Dissensus => "歧见"
    Confronting => "对峙"
    Partitioned => "割据"
    Projected => "投射"
    Monologic => "独白"
    Disciplined => "规训"
    Concealed => "遮蔽"
    Wounded => "创伤"
    Dispersed => "离散"
    Returning => "复归"
    Practicing => "修习"
    Widening => "扩界"
    Attuned => "相契"
    Settled => "宁定"
  }
}

///|
/// 所属阶段。
pub fn GroupState::phase(self : GroupState) -> GroupPhase {
  match self {
    Scattered => Gathering
    Converging => Gathering
    CommonTongue => Bodied
    Discourse => Bodied
    Normed => Ordering
    Consensus => Ordering
    Dissensus => Diverging
    Confronting => Diverging
    Partitioned => Diverging
    Projected => Excess
    Monologic => Excess
    Disciplined => SelfBound
    Concealed => SelfBound
    Wounded => Impaired
    Dispersed => Impaired
    Returning => Cultivating
    Practicing => Cultivating
    Widening => Cultivating
    Attuned => Resting
    Settled => Resting
  }
}

///|
/// 阶段名（两字）。
pub fn GroupPhase::label(self : GroupPhase) -> String {
  match self {
    Gathering => "聚散"
    Bodied => "成体"
    Ordering => "立序"
    Diverging => "分歧"
    Excess => "失度"
    SelfBound => "自缚"
    Impaired => "受损"
    Cultivating => "修习"
    Resting => "宁定"
  }
}

///|
/// 触发名。
pub fn GroupTrigger::label(self : GroupTrigger) -> String {
  match self {
    Appear => "众人出现"
    Attention => "注意汇聚"
    SharedMedium => "共同语言与传统承担理解"
    RaiseClaims => "相互提出有效性主张"
    NormFromTradition => "由传统立起规矩"
    NormFromReason => "由理由立起规矩"
    Agree => "达成暂时一致"
    Differ => "差异被承认为差异"
    Clash => "体制相左，双方受挫"
    CloseHorizon => "界域关闭"
    Absolutize => "把第三者交给绝对者"
    OneVoice => "众声归一"
    Bind => "群体把成员束缚起来"
    Suppress => "压制未穷尽者"
    Reopen => "旧伤被重新揭开"
    BreakUp => "群体分解"
    TurnBack => "有人回头重新追问"
    RemoveReefs => "集体消除暗礁"
    Widen => "界域扩大"
    MutualCheng => "双诚俱足"
    Settle => "不再绝对化，静待下一刻"
    Reenter => "界域重开，环节重入"
  }
}

///|
/// 状态说明。
pub fn GroupState::gloss(self : GroupState) -> String {
  match self {
    Scattered =>
      "众人只是一群，彼此尚无关联；群体还不是主体。"
    Converging =>
      "注意开始汇聚，但还没有共同的语言、主张或规矩。"
    CommonTongue =>
      "理解与语言被当作超主体事件：是语言在言说我们。"
    Discourse =>
      "真理被当作主体间有效性主张，横（成员之间）纵（对规范）交织成网。"
    Normed =>
      "由理由或由传统立起共同规矩；群体的秩序第一次成形。"
    Consensus =>
      "达成的只是暂时一致；可修订标记始终没有摘掉。"
    Dissensus =>
      "差异被承认为差异——这是还能继续商谈的状态。"
    Confronting =>
      "体制相左：一边说对方是加倍的主观主义，一边说对方保留着主体哲学的遗产。"
    Partitioned =>
      "界域关闭，各守一方；不可涉足区在群体尺度上出现。"
    Projected =>
      "群体把第三者交给绝对者（领袖、偶像、意识形态、被神化的语言）。"
    Monologic =>
      "众声退化成一个声音：对话之路走到了独白逻辑。"
    Disciplined =>
      "群体把自己与成员一起束缚起来，行动的自由被收起。"
    Concealed =>
      "未穷尽者被压制：隐不再是隐，而成了不许问。"
    Wounded =>
      "集体的伤口反复被揭开，痛苦由群体自己造成，难以终结。"
    Dispersed => "群体分解，成员各自离散。"
    Returning => "有人回头重新追问：环节重新打开。"
    Practicing =>
      "集体忍受暂时之痛以消除暗礁——修养在群体尺度上重演。"
    Widening => "界域扩大，新的成员与新的内容被纳入。"
    Attuned =>
      "每一对成员都双诚俱足：他之诚与己之诚同时成立。"
    Settled =>
      "不再把任何结论绝对化；静待下一刻，界域随时可以再开。"
  }
}

///|
/// 全部状态，按主线阅读顺序。
pub fn all_states() -> Array[GroupState] {
  [
    Scattered,
    Converging,
    CommonTongue,
    Discourse,
    Normed,
    Consensus,
    Dissensus,
    Confronting,
    Partitioned,
    Projected,
    Monologic,
    Disciplined,
    Concealed,
    Wounded,
    Dispersed,
    Returning,
    Practicing,
    Widening,
    Attuned,
    Settled,
  ]
}

///|
/// 全部阶段。
pub fn all_phases() -> Array[GroupPhase] {
  [
    Gathering,
    Bodied,
    Ordering,
    Diverging,
    Excess,
    SelfBound,
    Impaired,
    Cultivating,
    Resting,
  ]
}

///|
/// 群体的起始状态。
pub fn initial() -> GroupState {
  Scattered
}

///|
/// 群体的静定极（不是终点：见 `Settled --Reenter--> Returning`）。
pub fn resting() -> GroupState {
  Settled
}

///|
/// 全部迁移。
pub fn transitions() -> Array[GroupTransition] {
  let ts : Array[GroupTransition] = [
    // 聚散 → 成体
    { from: Scattered, trigger: Appear, to: Converging, },
    { from: Converging, trigger: Attention, to: CommonTongue, },
    { from: Converging, trigger: Attention, to: Discourse, },
    { from: CommonTongue, trigger: SharedMedium, to: CommonTongue, },
    { from: Discourse, trigger: RaiseClaims, to: Discourse, },
    // 成体 → 立序
    { from: CommonTongue, trigger: NormFromTradition, to: Normed, },
    { from: Discourse, trigger: NormFromReason, to: Normed, },
    { from: Normed, trigger: Agree, to: Consensus, },
    // 分歧
    { from: Consensus, trigger: Differ, to: Dissensus, },
    { from: Dissensus, trigger: Differ, to: Dissensus, },
    { from: Dissensus, trigger: Clash, to: Confronting, },
    { from: Confronting, trigger: Differ, to: Dissensus, },
    { from: Confronting, trigger: CloseHorizon, to: Partitioned, },
    { from: Partitioned, trigger: CloseHorizon, to: Partitioned, },
    // 失度
    { from: Confronting, trigger: Absolutize, to: Projected, },
    { from: Partitioned, trigger: Absolutize, to: Projected, },
    { from: Projected, trigger: Absolutize, to: Projected, },
    { from: CommonTongue, trigger: OneVoice, to: Monologic, },
    { from: Discourse, trigger: OneVoice, to: Monologic, },
    // 自缚
    { from: Projected, trigger: Bind, to: Disciplined, },
    { from: Monologic, trigger: Bind, to: Disciplined, },
    { from: Disciplined, trigger: Suppress, to: Concealed, },
    { from: Concealed, trigger: Suppress, to: Concealed, },
    // 受损
    { from: Disciplined, trigger: Reopen, to: Wounded, },
    { from: Concealed, trigger: Reopen, to: Wounded, },
    { from: Wounded, trigger: Reopen, to: Wounded, },
    { from: Wounded, trigger: BreakUp, to: Dispersed, },
    { from: Concealed, trigger: BreakUp, to: Dispersed, },
    { from: Dispersed, trigger: BreakUp, to: Dispersed, },
    // 修习
    { from: Dispersed, trigger: TurnBack, to: Returning, },
    { from: Wounded, trigger: TurnBack, to: Returning, },
    { from: Returning, trigger: TurnBack, to: Returning, },
    { from: Returning, trigger: RemoveReefs, to: Practicing, },
    { from: Practicing, trigger: RemoveReefs, to: Practicing, },
    { from: Practicing, trigger: Widen, to: Widening, },
    { from: Widening, trigger: Widen, to: Widening, },
    { from: Widening, trigger: MutualCheng, to: Attuned, },
    { from: Consensus, trigger: MutualCheng, to: Attuned, },
    { from: Attuned, trigger: MutualCheng, to: Attuned, },
    // 宁定（可重入）
    { from: Attuned, trigger: Settle, to: Settled, },
    { from: Settled, trigger: Settle, to: Settled, },
    { from: Settled, trigger: Reenter, to: Returning, },
  ]
  ts
}

///|
/// 从 `state` 出发的出边。
pub fn successors(state : GroupState) -> Array[(GroupTrigger, GroupState)] {
  let out : Array[(GroupTrigger, GroupState)] = []
  for t in transitions() {
    if t.from == state {
      out.push((t.trigger, t.to))
    }
  }
  out
}

///|
/// 从 `from` 沿迁移是否可达 `to`。
pub fn reachable(from : GroupState, to : GroupState) -> Bool {
  let seen : Array[GroupState] = [from]
  let mut i = 0
  while i < seen.length() {
    let cur = seen[i]
    if cur == to {
      return true
    }
    for t in transitions() {
      if t.from == cur && !contains(seen, t.to) {
        seen.push(t.to)
      }
    }
    i += 1
  }
  false
}

///|
fn contains(xs : Array[GroupState], s : GroupState) -> Bool {
  for x in xs {
    if x == s {
      return true
    }
  }
  false
}

///|
/// 主线历程。
pub fn course() -> Array[GroupState] {
  [
    Scattered,
    Converging,
    Discourse,
    Normed,
    Consensus,
    Dissensus,
    Confronting,
    Partitioned,
    Projected,
    Disciplined,
    Concealed,
    Wounded,
    Dispersed,
    Returning,
    Practicing,
    Widening,
    Attuned,
    Settled,
    Returning,
  ]
}

///|
/// 该状态是否假装把真理封了口（只有病态状态才这样）。
pub fn GroupState::claims_closure(self : GroupState) -> Bool {
  match self {
    Projected => true
    Monologic => true
    _ => false
  }
}

///|
/// 群体状态机的文本依据（章／节／页；页号取自 truth.pdf 正文）。
pub fn textual_basis() -> Array[(String, String)] {
  [
    (
      "共语／商谈", "第四章第五节（P.50）：伽达默尔取超主体性——是语言在言说我们；哈贝马斯取主体间性——横纵交织成网",
    ),
    (
      "对峙", "第四章第一节（P.29）与第五节（P.49）：体制相左；一边说对方是加倍了的主观主义",
    ),
    (
      "投射", "第四章第五节（P.48）：对伽达默尔来说，第三者由于其超脱性只能由上帝来扮演",
    ),
    (
      "独白", "第一章（P.13-14）：对话之路→回忆辩证→独白逻辑的退化史",
    ),
    (
      "歧见", "第四章第六节（P.52）：争论一直都是哲学研究前进的手段",
    ),
    (
      "共识", "第四章第五节（P.50）：真理只不过是一种表达，用它建议话语伙伴接受我们认为是正确的观念",
    ),
    (
      "宁定", "第四章第六节（P.53）：文字还在生长——真理问题果真有一个最终的结论吗？",
    ),
    (
      "相契", "第五章余论（P.55）：澄然与诚然尚可统于自性内照，其后乃能入于无人我、齐万物之境",
    ),
    (
      "修习／扩界", "附录二《通往宁静之路》：以修养消除暗礁、拓展界域、趋向和谐",
    ),
    (
      "散在", "第五章余论（P.54）：个体道德学以众生中之一个体为观照对象——群体不是个体的简单相加",
    ),
  ]
}
