///|
/// 多主体行为规则的"体制"层：一个主体**如何对待主体性**。
///
/// 依据：分歧之根不在具体论点，而在对"主体"的态度——伽达默尔取「超主体性」
/// （理解、语言均为超主体事件，"是语言在言说我们"），哈贝马斯取「主体间性」
/// （真理即主体间有效性主张，"横""纵"交织成网）。再加上作者自建的中／西／印
/// 谱系与自己的方案「诚然」，就得到"如何对待主体性"的完整取值域。
///
/// 两种体制都批判主观主义，只是路径不同；真正的分水岭是「第三者」由谁扮演。

///|
/// 真理体制。
pub(all) enum TruthRegime {
  Immanent // 古埃及：真理是内在于世界的永恒秩序，人本来就在其中，不必寻求
  Logos // 古希腊：真理是永恒的言说，靠理性灵魂保障（对话→回忆→独白的退化史）
  SuperSubjective // 伽达默尔：理解与语言均为超主体事件
  InterSubjective // 哈贝马斯：真理即主体间有效性主张，横纵交织成网
  ChengRan // 作者方案：诚然的诠释学，统于「自性内照」
} derive(Eq)

///|
pub extend TruthRegime with Eq::{not_equal, equal}

///|
/// 体制名。
pub fn TruthRegime::label(self : TruthRegime) -> String {
  match self {
    Immanent => "内在秩序"
    Logos => "逻各斯"
    SuperSubjective => "超主体性"
    InterSubjective => "主体间性"
    ChengRan => "诚然"
  }
}

///|
/// 该体制把「第三者」交给谁——这是超主体性与主体间性的真正分水岭（第四章第五节）。
pub fn TruthRegime::third(self : TruthRegime) -> String {
  match self {
    Immanent => "无需第三者：秩序已在世界之中"
    Logos => "理性灵魂（有退化为独白的危险）"
    SuperSubjective => "上帝／绝对者：超脱性只能由它扮演"
    InterSubjective => "理性与关系网络：横纵交织成网"
    ChengRan =>
      "自性（内照），其后乃能入于无人我、齐万物之境"
  }
}

///|
/// 该体制是否可能与他人达成共识（即：是否进入主张与商谈）。
pub fn TruthRegime::seeks_consensus(self : TruthRegime) -> Bool {
  match self {
    Immanent => false
    Logos => true
    SuperSubjective => true
    InterSubjective => true
    ChengRan => true
  }
}

///|
/// 该体制是否把「诚」当作有效性条件。
pub fn TruthRegime::needs_cheng(self : TruthRegime) -> Bool {
  match self {
    ChengRan => true
    _ => false
  }
}

///|
/// 商谈类型。
pub(all) enum DiscourseType {
  Theoretical // 理论商谈：命题真实性
  Practical // 实践商谈：正当性
  Aesthetic // 表达性商谈：真诚性
  Faith // 信仰商谈：宗教真理可纳入共识真理
} derive(Eq)

///|
pub extend DiscourseType with Eq::{not_equal, equal}

///|
/// 商谈类型名。
pub fn DiscourseType::label(self : DiscourseType) -> String {
  match self {
    Theoretical => "理论商谈"
    Practical => "实践商谈"
    Aesthetic => "表达性商谈"
    Faith => "信仰商谈"
  }
}

///|
/// 有效性主张。作者按三个世界分节（第三章第二至四节：真诚性—主观世界、
/// 真实性—客观世界、正当性—社会世界）；结论处则引哈贝马斯德文原句列出四项：
/// 「命题的真实性、规范的正确性、本真性以及真诚性」（第四章第六节，P.51）。
/// 主观世界那一支又可分两部分：「他之诚」（Authentizität）与「己之诚」
/// （Wahrhaftigkeit）（第三章第二节，P.23-24）。本模型把两者分列，以承载 P.50 的
/// 那条区别（见 `requires_joint_review`）。
pub(all) enum ClaimKind {
  Truthfulness // 真实性：客观世界
  Legitimacy // 正当性：社会世界
  Authenticity // 本真性＝他之诚：内心所言与诉说之言契合
  Sincerity // 真诚性＝己之诚：行为与意向契合
} derive(Eq)

///|
pub extend ClaimKind with Eq::{not_equal, equal}

///|
/// 主张名。
pub fn ClaimKind::label(self : ClaimKind) -> String {
  match self {
    Truthfulness => "真实性"
    Legitimacy => "正当性"
    Authenticity => "他之诚"
    Sincerity => "己之诚"
  }
}

///|
/// 时间位置。
pub(all) enum ClaimPhase {
  Before // 事前
  During // 事中
  After // 事后
} derive(Eq)

///|
pub extend ClaimPhase with Eq::{not_equal, equal}

///|
/// 时间位置名。
pub fn ClaimPhase::label(self : ClaimPhase) -> String {
  match self {
    Before => "事前"
    During => "事中"
    After => "事后"
  }
}

///|
/// 一条有效性主张：种类 + 它被提出的时间位置。
pub(all) struct ValidityClaim {
  kind : ClaimKind
  phase : ClaimPhase
}

///|
/// 主张的「正位」（第三章第五节，P.27）：真诚性＝事前判断，真实性＝事中判断，
/// 正当性＝事后判断。本模型把「他之诚」（本真性）也放在事前——它同样是进入商谈
/// 之前的自我担保（第三章第二节，P.23-24），这是对作者三分法的显式延伸。
pub fn phase_of(kind : ClaimKind) -> ClaimPhase {
  match kind {
    Truthfulness => During
    Legitimacy => After
    Authenticity => Before
    Sincerity => Before
  }
}

///|
/// 哪些主张须由主体之间**共同检讨**。第四章第五节（P.50）说得很明确：
/// 进入商谈的有效性主张中，**除「他之诚」外，其它都须由主体之间共同检讨**——
/// 他之诚是言语者对自己「内心所言与诉说之言」的担保，只能由他自己承担。
pub fn requires_joint_review(kind : ClaimKind) -> Bool {
  match kind {
    Authenticity => false
    Sincerity => true
    Truthfulness => true
    Legitimacy => true
  }
}

///|
/// R4：主张是否落在自己的时间位置上。
pub fn in_phase(claim : ValidityClaim) -> Bool {
  claim.phase == phase_of(claim.kind)
}

///|
/// 两种「诚」（第三章第二节，P.23-24）：
///
/// - 他之诚（Authentizität）：**言语内容之契合**——「内心所言与诉说之言」的契合；
///   它是言语者把言语行为本身当作寻求共识的活动之**有效性的首要保证**，
///   并且只能由言语者自己担保（P.50：除他之诚外，其它都须由主体之间共同检讨）。
/// - 己之诚（Wahrhaftigkeit）：**行为与意向之契合**；它把个人所持以为真的陈述
///   **拿到主体间相互讨论**。
///
/// 二者结合，商谈才不致从追求合理共识的论辩沦为「追求在交谈中获胜的诡辩」。
/// 作者指出己之诚近于儒家「中庸」而有别：中庸所求是情感—行为和谐，己之诚所求是
/// 意向—行为契合；并把这种「诚」与哈贝马斯的「真诚性」相会通，以开出「诚然的
/// 诠释学」而别于西方文化的「澄然的诠释学」（第五章余论，P.55）。
pub struct Cheng {
  toward_other : Int // 他之诚，0..100
  toward_self : Int // 己之诚，0..100
}

///|
/// 双诚是否俱足（诚然体制的相契条件）。
pub fn Cheng::is_complete(self : Cheng) -> Bool {
  self.toward_other >= 60 && self.toward_self >= 60
}

///|
/// 每个体制在论文正文里的出处与原文要点。
pub fn TruthRegime::basis(self : TruthRegime) -> String {
  match self {
    Immanent =>
      "第一章（P.13）：真理是内在于世界的秩序；它是永恒的，人本来就身在其中，不必寻求。"
    Logos =>
      "第一章（P.13-14）：真理是永恒的言说（logos），理性灵魂为探寻提供保障；退化史见「对话性的逻各斯被转换为独白性的逻辑」。"
    SuperSubjective =>
      "第二章（P.19-21）与第四章第五节（P.50）：理解与语言是超主体事件；「是语言在言说我们」。"
    InterSubjective =>
      "第三章与第四章第五节（P.50）：真理即主体间有效性主张；横向与纵向织成一张网。"
    ChengRan =>
      "第五章余论（P.55）：澄然与诚然尚可统于自性内照；这是作者自设的开放问题，不是结论。"
  }
}
