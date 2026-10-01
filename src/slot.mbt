///|
/// 驱动槽（`Slot`）——「这次迁移由哪一类结构关系推动」。
///
/// ## 为什么要有这一层
///
/// `Trigger` 把几种 causally 不同的东西记成了同一个名字：`FeelFinitude`（时间
/// 与空间生出感受，不由主体发起）、`ActInFreedom`（主体的行动）、`Deposit`（自身
/// 把经历沉淀下来，位置不动）、`DoubtOneself`（既不是输入也不是行动，是解蔽）。
/// 主体通用性原则要求**状态**只由结构关系定名；同一条原则推到**迁移**上，就是：
/// 推动迁移的东西也要按结构关系归位，而不是留在叙事里。本层做这件事。
///
/// 八个槽（定名一律两字）：处境／取向／先行／行动／反馈／持存／共在／揭蔽。
///
/// ## 两条归位纪律
///
/// - **共在独立成槽**：`MeetOther`／`GoodFaith`／`OpenArms` 既不并入处境，也不并入
///   行动。原文说得清楚：「无法确定对方是否和自身一样，但做一个善意的假设又何
///   妨」——「对方是否和自身一样」不是感知的结果，而是另一个主体。把他者降为
///   环境，就等于把 `multi` 整层的对象消掉。
/// - **先行不等于预测**：`TouchFuture`／`WaitNext`／`Approximate` 是文本里的「与
///   未来接触」「静待下一刻」「不断尝试」，是一种先行结构（带着预期移动），不给
///   概率、不引数值——数值属于 `ml`／`evolution`，不属于本包。
///
/// ## 只增不改
///
/// 本层是一个**函数**：`Trigger::slot` 对全部触发穷尽归位（编译器检查缺臂）。
/// `Transition`、状态表、迁移表与 34／53／11 的计数一概不动；槽内容的**生产者**
/// 在 `evolution` 之上，`src` 只给词汇与判关系。

///|
/// 推动一次迁移的结构位置（八槽，定名一律两字）。
pub(all) enum Slot {
  Occasion // 处境：不由主体发起的给予
  Orientation // 取向：目标被立下、复杂化、更换
  Antecedent // 先行：带着预期移动，不给概率
  Act // 行动：原文有动作的那一类
  Feedback // 反馈：来自环境、偶像或自身位置的返回
  Hold // 持存：沉淀与位置不变者
  CoBeing // 共在：他者维度，绝不并入处境或行动
  Unveil // 揭蔽：解蔽—遮蔽（R3）
} derive(Eq, Debug)

///|
/// 让 `==` 在 `Slot` 上以方法形式可用（显式 extend，避免隐式提升）。
pub extend Slot with Eq::{not_equal, equal}

///|
pub extend Slot with Debug::{to_repr}

///|
/// 槽的通用定名（两字，只指称结构关系）。
pub fn Slot::designation(self : Slot) -> String {
  match self {
    Occasion => "处境"
    Orientation => "取向"
    Antecedent => "先行"
    Act => "行动"
    Feedback => "反馈"
    Hold => "持存"
    CoBeing => "共在"
    Unveil => "揭蔽"
  }
}

///|
/// 槽的结构说明。
pub fn Slot::gloss(self : Slot) -> String {
  match self {
    Occasion =>
      "不由主体发起、却把主体搬动的给予：时间与空间、不得不、被刺痛之前的一切"
    Orientation => "目标被立下、被复杂化、被更换的位置"
    Antecedent =>
      "与未来接触、静待下一刻、不断尝试——带着预期移动，但不给概率"
    Act =>
      "原文有动作的推动：束缚自己、斩断过去、忍受、消除暗礁"
    Feedback =>
      "来自环境、偶像或自身先前位置的返回：嘉奖、威慑、颁布、界域扩大"
    Hold =>
      "位置不变者：吸入与沉淀、新旧交织、习惯、惊喜—疑惑—流连"
    CoBeing => "他者维度：遭遇、善意的假设、向彼此敞开双臂"
    Unveil =>
      "解蔽—遮蔽（R3）：冷静下来、追问自身是什么、界域重开"
  }
}

///|
/// 该槽所取的原文措辞。
pub fn Slot::source(self : Slot) -> String {
  match self {
    Occasion =>
      "时间的有限无界性生出的紧迫感；人不得不忙碌起来"
    Orientation =>
      "为和谐寻求一个目标；这同一个目标又被复杂化了"
    Antecedent => "与未来接触；他不断尝试；静待下一刻的来临"
    Act =>
      "对待和筹措乃是基于行动的自由的；人于是将自己束缚起来"
    Feedback => "当偶像给予他嘉奖；随着界域的不断扩大"
    Hold =>
      "不断将所经历的吸入、沉淀；当他习惯了自身所背负的"
    CoBeing => "人与他者遭遇了；战战兢兢的向彼此敞开双臂"
    Unveil =>
      "重又冷静下来审视过去；自身是一连串的感觉呢还是其他的什么"
  }
}

///|
/// 出处层：区分「原文直述」与「模型整理」（本仓库的通行纪律）。
pub fn Slot::provenance(self : Slot) -> String {
  match self {
    Occasion => "原文直述"
    Orientation => "原文直述"
    Antecedent => "原文直述"
    Act => "原文直述"
    Feedback =>
      "混合：嘉奖—威慑—颁布原文直述，「反馈」一名为模型整理"
    Hold =>
      "混合：措辞原文直述，把位置不变者单列为一槽属模型整理"
    CoBeing =>
      "混合：措辞原文直述，把他者独立成槽属模型整理（依 R7、R8）"
    Unveil =>
      "模型整理：依论文第四章第一节「解蔽—遮蔽」，附录原文无此名"
  }
}

///|
/// 「定名（出处层：原文措辞）」；三层命名在本层的对应物。
pub fn Slot::qualified(self : Slot) -> String {
  "\{self.designation()}（\{self.provenance()}）"
}

///|
/// 全部八个槽。
pub fn all_slots() -> Array[Slot] {
  [Occasion, Orientation, Antecedent, Act, Feedback, Hold, CoBeing, Unveil]
}

///|
/// 迁移表里实际出现过的触发，按表的顺序去重。
///
/// 取自迁移表而非枚举：报告与测试要问的是「这条边由什么推动」，未在表中出现的
/// 触发不构成任何迁移。
pub fn all_triggers() -> Array[Trigger] {
  let out : Array[Trigger] = []
  for t in transitions() {
    if !contains_trigger(out, t.trigger) {
      out.push(t.trigger)
    }
  }
  out
}

///|
fn contains_trigger(xs : Array[Trigger], x : Trigger) -> Bool {
  for y in xs {
    if y == x {
      return true
    }
  }
  false
}

///|
/// 触发 → 驱动槽。对 `Trigger` 穷尽匹配；新增触发而未归位，编译即失败。
pub fn Trigger::slot(self : Trigger) -> Slot {
  match self {
    // 处境：不由主体发起的给予。
    TakeStand => Occasion
    FeelFinitude => Occasion
    FeelBoundlessness => Occasion
    FuseFeelings => Occasion
    MustBeBusy => Occasion
    ColdHard => Occasion
    // 取向：目标被立下、复杂化、更换。
    ChooseMoreLasting => Orientation
    Complexify => Orientation
    SeekMoreJoy => Orientation
    SeekBalance => Orientation
    SeekGoal => Orientation
    TakeModel => Orientation
    // 先行：带着预期移动。
    TouchFuture => Antecedent
    TryMethods => Antecedent
    Approximate => Antecedent
    WaitNext => Antecedent
    // 行动：原文有动作。
    ActInFreedom => Act
    BindSelf => Act
    Avoid => Act
    CutPast => Act
    SummonIdol => Act
    MarkGoodBad => Act
    RedrawMap => Act
    Endure => Act
    RemoveReefs => Act
    // 反馈：来自环境、偶像或自身位置的返回。
    Sting => Feedback
    BlameSelf => Feedback
    EnactOrder => Feedback
    AbsorbGlory => Feedback
    Reward => Feedback
    Dread => Feedback
    WidenFrontier => Feedback
    Ascend => Feedback
    // 持存：沉淀与位置不变者。
    KeepContinuity => Hold
    Deposit => Hold
    TurnToResidue => Hold
    Interweave => Hold
    Surprise => Hold
    Doubt => Hold
    Linger => Hold
    Habituate => Hold
    // 共在：他者维度。
    MeetOther => CoBeing
    GoodFaith => CoBeing
    OpenArms => CoBeing
    // 揭蔽：解蔽—遮蔽。
    AttributeSelf => Unveil
    FillEmptiness => Unveil
    CoolDown => Unveil
    DoubtOneself => Unveil
    ReopenByHorizon => Unveil
  }
}

///|
/// 每个槽收到多少触发（表内实际出现者）。
pub fn slot_tally() -> Array[(Slot, Int)] {
  let out : Array[(Slot, Int)] = []
  for s in all_slots() {
    let mut n = 0
    for t in all_triggers() {
      if t.slot() == s {
        n += 1
      }
    }
    out.push((s, n))
  }
  out
}

///|
/// 一行汇总：「处境 6 · 取向 6 · …」。
pub fn render_slot_tally() -> String {
  let parts : Array[String] = []
  for entry in slot_tally() {
    parts.push("\{entry.0.designation()} \{entry.1}")
  }
  parts.join(" · ")
}

///|
/// 驱动槽对照表：按槽分组列出全部触发，含出处层。
pub fn render_slots() -> String {
  let total = all_triggers().length()
  let lines : Array[String] = ["# 驱动槽 · \{total} 个触发的归位", ""]
  lines.push("汇总：\{render_slot_tally()}")
  lines.push("")
  lines.push("## 八个槽")
  for s in all_slots() {
    lines.push("- \{s.designation()}　\{s.gloss()}　〔\{s.provenance()}〕")
  }
  lines.push("")
  lines.push("## 逐条归位（按迁移表顺序）")
  for s in all_slots() {
    let owned : Array[Trigger] = []
    for t in all_triggers() {
      if t.slot() == s {
        owned.push(t)
      }
    }
    if owned.length() == 0 {
      continue
    }
    lines.push("")
    lines.push("### \{s.designation()}（\{owned.length()} 条）")
    for t in owned {
      lines.push("- \{t.label()}")
    }
  }
  lines.join("\n")
}
