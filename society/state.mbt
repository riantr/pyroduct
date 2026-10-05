///|
/// 双层次社会交往模型 —— 从《伽达默尔与哈贝马斯真理观比较》（任勇祥，上海社会科学院，
/// 2008）提取的集体层面理论。
///
/// 定名的理由：论文的集体单位是**社会**而不是「群体」（全篇「群体」几不出现，主线词是
/// 社会、主体间、交往）。其骨架是哈贝马斯的**两个层次的社会**（第四章第二节 2，P.31）：
///
///   - **生活世界**（Lebenswelt，语言层）：以语言组织，是「言说者与倾听者相遇的先验
///     处所」，也是交往行动者「自我理解或坚定不移信念的仓库」；功能为**文化再生产**、
///     **社会整合**与**社会化**（第四章第四节 5，P.43-44）。
///   - **系统**（金钱与权力层）：以金钱和权力为中介，本该服务于生活世界，却在工具理性的
///     影响下膨胀，造成它对生活世界的**内在殖民化**（P.43）。
///
/// 使两层发生关系、并在生活世界内产生真理的，是**交往**：在生活世界的视域内，交往行动者
/// 提出**有效性主张**（第三章第一节，P.22-23），进入**商谈**——被比作「洗衣机」，「过滤出
/// 对所有人都能合理地接受的东西」——经**辩护**由「理解」转为**共识**，其结果又「存入」
/// 各自的生活世界（第四章第四节 6，P.44-46）。由实践商谈达成的**规范**须贴「过去时」标签；
/// 单一化的他者无法完成双重审核，须引入**第三者**——「但这在现实中是不可能的」，商谈理论
/// 逃不脱「乌托邦」的命运（P.46）：本模型把这一固有缺口记为**缺口**。
///
/// 伽达默尔以**超主体性**相抗（「是语言在言说我们」），并认为「构造生活世界（如主体间性
/// 世界）的任务乃是一项荒谬的任务」（P.44、第四章第五节 P.49-50）。这是两种取向的对照，
/// 也是本模型的入口分歧。
///
/// 本模型是**我们的实现形态**（离散状态机），「双层次社会交往模型」是对**对象**的定名；
/// 它**不是**把主体状态机的节奏抬到群体尺度重演（那是同工作区 `group` 包的模型延伸）。
///
/// 命名纪律：状态名与阶段名一律两字，只指称结构关系（主体通用性原则）；每一状态都附
/// 论文出处（章／节／页，页号取自 `truth.pdf` 正文）。

///|
/// 模型中的状态（13 个，两字）。
pub(all) enum State {
  World // 世界：生活世界（语言层）
  Suprasubjective // 超体：超主体性
  Intersubjective // 间性：主体间性
  Claim // 主张：有效性主张
  Discourse // 商谈
  Justification // 辩护
  Consensus // 共识
  Norm // 规范
  Gap // 缺口
  System // 系统（金钱与权力层）
  Colony // 殖民：内在殖民化
  Distortion // 扭曲：被扭曲的交往
  Reconstruction // 重建
} derive(Eq)

///|
/// 让 `==` 在 `State` 上以方法形式可用（显式 extend，避免隐式提升）。
pub extend State with Eq::{not_equal, equal}

///|
/// 模型的阶段（8 个，两字）。
pub(all) enum Phase {
  Life // 生活
  Language // 语言
  Speech // 商谈
  Rule // 规范
  Aporia // 缺口
  Instrument // 系统
  Domination // 殖民
  Rebuild // 复建
} derive(Eq)

///|
pub extend Phase with Eq::{not_equal, equal}

///|
/// 推动模型迁移的触发。
pub(all) enum Trigger {
  SpeakLanguage // 语言在言说我们（伽达默尔）
  BuildIntersubjective // 主体间性是用语言建立起来的（哈贝马斯）
  RaiseClaims // 交往行动者提出有效性主张
  EnterDiscourse // 进入商谈程序
  Filter // 洗衣机过滤：商谈不断筛出可接受者
  Justify // 经程序化辩论得辩护
  Subsume // 理解被纳入并转变为共识
  Store // 中间结果存入生活世界（视域融合）
  EnactNorm // 实践商谈达成规范
  LabelPast // 受验话语行为贴「过去时」标签
  DemandThird // 需引入第三者，而现实中不可能
  Serve // 系统本该服务于生活世界
  Expand // 系统的控制欲膨胀
  Colonize // 对生活世界的内在殖民化
  Distort // 交往被系统扭曲
  Hinder // 阻碍非强制共识的产生
  Reconstruct // 重建被扭曲的交往领域
  Circulate // 循环过程取代对立关系
} derive(Eq)

///|
pub extend Trigger with Eq::{not_equal, equal}

///|
/// 一条迁移。
pub struct Transition {
  from : State
  trigger : Trigger
  to : State
}

///|
/// 状态的中文名（两字）。
pub fn State::designation(self : State) -> String {
  match self {
    World => "世界"
    Suprasubjective => "超体"
    Intersubjective => "间性"
    Claim => "主张"
    Discourse => "商谈"
    Justification => "辩护"
    Consensus => "共识"
    Norm => "规范"
    Gap => "缺口"
    System => "系统"
    Colony => "殖民"
    Distortion => "扭曲"
    Reconstruction => "重建"
  }
}

///|
/// 状态说明（取自论文，末附出处）。
pub fn State::gloss(self : State) -> String {
  match self {
    World =>
      "生活世界：以语言组织，「言说者与倾听者相遇的先验处所」；交往行动者在此提出有效性主张、批判并认可它们、展现分歧并取得共识。其功能为文化再生产、社会整合与社会化，是「自我理解或坚定不移信念的仓库」（P.43-44）。"
    Suprasubjective =>
      "超主体性（伽达默尔）：理解与语言均为超主体事件——「是语言在言说我们，而不是我们在言说语言」。他并认为「构造生活世界（如主体间性世界）的任务乃是一项荒谬的任务」（P.44、P.49-50）。"
    Intersubjective =>
      "主体间性（哈贝马斯）：伽达默尔替它下过定义——「主体间性是用语言建立起来的」。横向的有效性主张与纵向的共同理性织成一张网，构成达成无强制共识的基础（P.50）。"
    Claim =>
      "有效性主张：交往行动者在各自生活世界的视域中，把相互的要求言语化为命题，这些命题就是「有望成为共识的待受检验者」（P.43）。"
    Discourse =>
      "商谈：被哈贝马斯比作「洗衣机」，「过滤出对所有人都能合理地接受的东西」；其目标是与（功能性的）他者达成主体间的无强制共识（P.44-45）。"
    Justification =>
      "辩护：一个陈述之为真，是指「断定那个陈述的言语活动的有效性主张得到了辩护」；有效性主张须经程序化的辩论才被认可（P.22、P.45）。"
    Consensus =>
      "共识（Einverständnis）：经辩护，被「纳入」共同体的「理解」（Verständnis）「转变」成共识；这是「值得认可」（Akzeptabilität）的「基于理由的共识」（P.23、P.45）。"
    Norm =>
      "规范：实践商谈自动地相互协调，从而设定出「作为相互之间制约之用的规则」，束缚参与者的行为；受验的话语行为因此必定要贴上一种「过去时」的标签（P.45-46）。"
    Gap =>
      "缺口：单一化的他者无法完成（指出可能性的批判的）检察院加（决定正误的判断的）法院的双重审核，于是要引入「第三者」（超脱的反思者）——「但这在现实中是不可能的」，商谈理论逃不脱「乌托邦」的命运（P.46）。"
    System =>
      "系统：以金钱和权力为中介，本该服务于通过语言组织起来的「生活世界」（P.43）。"
    Colony =>
      "内在殖民化：在工具理性的影响下，系统的控制欲愈发膨胀，造成它对生活世界的内在殖民化；「现代病就病在具有交往结构的生活领域听任具有形式结构的独立的系统的摆布」（P.31、P.43）。"
    Distortion =>
      "被扭曲的交往：「被系统所扭曲的交往就是阻碍一种非强制性的共识产生的根源」（P.31）。"
    Reconstruction =>
      "重建：重建被扭曲的交往领域，使经济、政治等系统服务于生活世界；「用生活世界与系统之间的循环过程来取代它们之间的对立关系」（P.31、P.43、P.49）。"
  }
}

///|
/// 所属阶段。
pub fn State::phase(self : State) -> Phase {
  match self {
    World => Life
    Suprasubjective => Language
    Intersubjective => Language
    Claim => Speech
    Discourse => Speech
    Justification => Speech
    Consensus => Speech
    Norm => Rule
    Gap => Aporia
    System => Instrument
    Colony => Domination
    Distortion => Domination
    Reconstruction => Rebuild
  }
}

///|
/// 阶段名（两字）。
pub fn Phase::label(self : Phase) -> String {
  match self {
    Life => "生活"
    Language => "语言"
    Speech => "商谈"
    Rule => "规范"
    Aporia => "缺口"
    Instrument => "系统"
    Domination => "殖民"
    Rebuild => "复建"
  }
}

///|
/// 触发名（原文措辞）。
pub fn Trigger::label(self : Trigger) -> String {
  match self {
    SpeakLanguage => "是语言在言说我们，而不是我们在言说语言"
    BuildIntersubjective => "主体间性是用语言建立起来的"
    RaiseClaims =>
      "交往行动者提出有效性主张，使之成为待受检验的命题"
    EnterDiscourse => "从此视域出发，进入一种商谈程序"
    Filter => "洗衣机过滤出对所有人都能合理地接受的东西"
    Justify => "有效性主张经程序化的辩论被认可"
    Subsume => "被纳入共同体的理解经辩护转变为共识"
    Store =>
      "所达成的一系列中间结果存入各自的生活世界（类似视域融合）"
    EnactNorm => "实践商谈设定出作为相互之间制约之用的规则"
    LabelPast => "受验的话语行为必定要贴上一种过去时的标签"
    DemandThird =>
      "单一化的他者无法完成双重审核，须加入第三者——而现实中不可能"
    Serve => "系统本该服务于通过语言组织起来的生活世界"
    Expand => "系统的控制欲愈发膨胀"
    Colonize => "系统对生活世界的内在殖民化"
    Distort => "交往领域被系统扭曲"
    Hinder => "被扭曲的交往阻碍一种非强制性的共识产生"
    Reconstruct => "重建被扭曲的交往领域"
    Circulate =>
      "用生活世界与系统之间的循环过程取代它们之间的对立关系"
  }
}

///|
/// 该状态的谬误残余（不可消尽的余量）；论文：「任何个人的见解中，始终都有谬误的
/// 残余」（第四章第六节，P.51）。残余恒为正，是 R10 在集体尺度上的形态。
pub fn State::residue(self : State) -> Int {
  match self {
    World => 5
    Suprasubjective => 4
    Intersubjective => 3
    Claim => 3
    Discourse => 2
    Justification => 2
    Consensus => 1
    Norm => 1
    Gap => 9
    System => 3
    Colony => 5
    Distortion => 6
    Reconstruction => 2
  }
}

///|
/// 全部状态，按主线阅读顺序。
pub fn all_states() -> Array[State] {
  [
    World,
    Suprasubjective,
    Intersubjective,
    Claim,
    Discourse,
    Justification,
    Consensus,
    Norm,
    Gap,
    System,
    Colony,
    Distortion,
    Reconstruction,
  ]
}

///|
/// 全部阶段。
pub fn all_phases() -> Array[Phase] {
  [Life, Language, Speech, Rule, Aporia, Instrument, Domination, Rebuild]
}

///|
/// 模型的起始状态：一切从生活世界出发。
pub fn initial() -> State {
  World
}

///|
/// 模型的固有缺口：第三者在现实中不可能，商谈理论逃不脱「乌托邦」的命运。
pub fn gap() -> State {
  Gap
}

///|
/// 全部迁移。
pub fn transitions() -> Array[Transition] {
  let ts : Array[Transition] = [
    // 生活世界：两种取向都从生活世界的视域出发。
    { from: World, trigger: SpeakLanguage, to: Suprasubjective, },
    { from: World, trigger: BuildIntersubjective, to: Intersubjective, },
    { from: World, trigger: RaiseClaims, to: Claim, },
    // 超主体性一系：第三者只能由上帝扮演，于是落入缺口。
    { from: Suprasubjective, trigger: SpeakLanguage, to: Suprasubjective, },
    { from: Suprasubjective, trigger: DemandThird, to: Gap, },
    // 主体间性一系：从主张经辩护到共识。
    { from: Intersubjective, trigger: RaiseClaims, to: Claim, },
    { from: Claim, trigger: RaiseClaims, to: Claim, },
    { from: Claim, trigger: EnterDiscourse, to: Discourse, },
    { from: Discourse, trigger: Filter, to: Discourse, },
    { from: Discourse, trigger: Justify, to: Justification, },
    { from: Justification, trigger: Justify, to: Justification, },
    { from: Justification, trigger: Subsume, to: Consensus, },
    // 共识：存入生活世界（视域融合），或凝为规范。
    { from: Consensus, trigger: Store, to: World, },
    { from: Consensus, trigger: EnactNorm, to: Norm, },
    { from: Norm, trigger: LabelPast, to: Gap, },
    // 系统与内在殖民化。
    { from: World, trigger: Serve, to: System, },
    { from: System, trigger: Serve, to: World, },
    { from: System, trigger: Expand, to: Colony, },
    { from: Colony, trigger: Colonize, to: Colony, },
    { from: Colony, trigger: Distort, to: Distortion, },
    { from: Distortion, trigger: Distort, to: Distortion, },
    { from: Distortion, trigger: Hinder, to: Gap, },
    // 重建：从缺口与被扭曲的交往回到生活世界。
    { from: Gap, trigger: Reconstruct, to: Reconstruction, },
    { from: Distortion, trigger: Reconstruct, to: Reconstruction, },
    { from: Reconstruction, trigger: Reconstruct, to: Reconstruction, },
    { from: Reconstruction, trigger: Circulate, to: World, },
  ]
  ts
}

///|
/// 从 `state` 出发的出边。
pub fn successors(state : State) -> Array[(Trigger, State)] {
  let out : Array[(Trigger, State)] = []
  for t in transitions() {
    if t.from == state {
      out.push((t.trigger, t.to))
    }
  }
  out
}

///|
/// 从 `from` 沿迁移是否可达 `to`（含 `from == to`）。
pub fn reachable(from : State, to : State) -> Bool {
  let seen : Array[State] = [from]
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
fn contains(xs : Array[State], s : State) -> Bool {
  for x in xs {
    if x == s {
      return true
    }
  }
  false
}

///|
/// 纯函数版：给全部位置、终态位置与「能到缺口」位置三份清单，不封闭 = 终态空
/// 且每个位置都在第三份里。
///
/// 取料与判定分开，同 `group::no_dead_end_of` 的理由：真表上恒为 `true`，只看
/// 真表的判据分不出「检查在跑」与「检查恒真」。测试给它**造出来的**清单——
/// 造一个有终态的位置、再造一个到不了缺口的位置，那两条 `false` 才验得住。
pub fn no_final_closure_of(
  states : Array[State],
  terminal : Array[State],
  gap_reachable : Array[State],
) -> Bool {
  if terminal.length() > 0 {
    return false
  }
  for s in states {
    if !gap_reachable.contains(s) {
      return false
    }
  }
  true
}

///|
/// 「不封闭」的判别：模型中没有一个终态，且「缺口」自任一状态皆可达。
/// 论文：「商谈理论逃不脱『乌托邦』的命运」（P.46）；「文字不是已被说出的僵死之物，
/// 它还在生长。对于我们而言，真理问题果真有一个最终的结论吗？」（P.53）。
pub fn no_final_closure() -> Bool {
  let terminal : Array[State] = []
  let gap_reachable : Array[State] = []
  for s in all_states() {
    if successors(s).length() == 0 {
      terminal.push(s)
    }
    if reachable(s, Gap) {
      gap_reachable.push(s)
    }
  }
  no_final_closure_of(all_states(), terminal, gap_reachable)
}

///|
/// 论文所描述的正路：从生活世界出发，经商谈达成共识，再存回生活世界（后经缺口与重建回环）。
pub fn course() -> Array[State] {
  [
    World,
    Intersubjective,
    Claim,
    Discourse,
    Justification,
    Consensus,
    Norm,
    Gap,
    Reconstruction,
    World,
  ]
}

///|
/// 论文所描述的病理路径（现代病）：系统膨胀、内在殖民化、交往被扭曲，直至缺口。
pub fn ailment() -> Array[State] {
  [World, System, Colony, Distortion, Gap, Reconstruction, World]
}

///|
/// 双层次社会交往模型的文本依据（构造 → 章／节／页；页号取自 truth.pdf 正文）。
pub fn basis() -> Array[(String, String)] {
  [
    (
      "两个层次的社会", "第四章第二节 2（P.31）：哈贝马斯围绕「交往理性概念」、「两个层次的社会的概念」与「现代性理论」三个主题展开。",
    ),
    (
      "生活世界", "第四章第四节 5（P.43-44）：「所谓生活世界乃是言说者与倾听者相遇的先验处所」；功能为文化再生产（传统的连续性和知识合理性的连续性）、社会整合（群体同一性的稳定和团结）与社会化；是「自我理解或坚定不移信念的仓库」。",
    ),
    (
      "系统", "第四章第四节 5（P.43）：「以金钱和权力为中介的『系统』本该服务于通过语言组织起来的『生活世界』」。",
    ),
    (
      "内在殖民化", "第四章第四节 5（P.43）：在工具理性的影响下，系统的控制欲愈发膨胀，造成它对生活世界的内在殖民化。",
    ),
    (
      "被扭曲的交往", "第四章第二节 2（P.31）：「被系统所扭曲的交往就是阻碍一种非强制性的共识产生的根源」。",
    ),
    (
      "有效性主张", "第三章第一节（P.22-23）：「真理，是指那种与断定性言语活动相联系的有效性主张」；第四章第四节 5（P.43）：相互的要求被言语化为命题，「这些命题就是有望成为共识的待受检验者」。",
    ),
    (
      "商谈", "第四章第四节 6（P.44-45）：商谈被比作「洗衣机」，它「过滤出对所有人都能合理地接受的东西」；目标是与他者达成主体间的无强制共识。",
    ),
    (
      "辩护", "第三章第一节（P.22）：「我们使用句子来断定那个陈述的言语活动的有效性主张得到了辩护」；第四章第四节 6（P.45）：有效性主张经程序化的辩论被认可。",
    ),
    (
      "共识", "第三章第一节（P.23）：商谈的目的在于达成「值得认可」（Akzeptabilität）的「基于理由的共识」；第四章第四节 6（P.45）：理解（Verständnis）经辩护「转变」成共识（Einverständnis）。",
    ),
    (
      "规范", "第四章第四节 6（P.45-46）：实践商谈设定出作为相互之间制约之用的规则；受验的话语行为「必定要贴上一种『过去时』的标签」。",
    ),
    (
      "第三者与缺口", "第四章第四节 6（P.46）：单一化的他者无法完成双重审核，故引入「第三者」（超脱的反思者）；「但这在现实中是不可能的。在此意义上商谈理论逃不脱『乌托邦』的命运」。",
    ),
    (
      "超主体性", "第四章第五节（P.49-50）：伽达默尔视主体间性为「加倍了的主观主义」；「是语言在言说我们，而不是我们在言说语言」；「构造生活世界的任务乃是一项荒谬的任务」（P.44）。",
    ),
    (
      "主体间性", "第四章第五节（P.50）：伽达默尔说「主体间性是用语言建立起来的」；横向的有效性主张与纵向的共同理性「织成的主体间性之网」构成达成无强制共识的基础。",
    ),
    (
      "重建与循环", "第四章第二节 2（P.31）与第四节 5（P.43）：重建被扭曲的交往领域，使经济、政治等系统服务于生活世界；第四章第五节（P.49）：「用生活世界与系统之间的循环过程来取代它们之间的对立关系」。",
    ),
  ]
}
