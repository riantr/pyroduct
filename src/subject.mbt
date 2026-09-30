///|
/// 主体状态机 —— 《通往宁静之路：个体道德发生论纲要》
///
/// 原文描写的是同一个"人"从本然站立，经由自由、与他者相遇、恶感—耻感—
/// 罪感—自缚、痛苦与失落、偶像崇拜、反思与和谐、榜样与修养，最终抵达
/// 宁静的历程。这里把它编码成一个离散状态机；按“主体通用性原则”修订后的
/// 定名、阶段与历程见 `general.mbt`：
///
/// - `SubjectState`：状态，人此刻所处的位置；
/// - `Trigger`：触发，推动人离开当前状态的事件或动机；
/// - `Transition`：迁移，形如 `from --trigger--> to`。
///
/// 每个状态都附有一段取自原文的文本依据（`gloss`）；`freedom` 是阐释性的
/// "自由刻度"（可为负，表示受缚），是为阅读方便所加，并非原文原有。
///
/// 主体所处的状态。通用定名（修订后）见 `designation`，原文名见 `label`。
pub(all) enum SubjectState {
  NoPast // 失忆的人没有过去
  NoFuture // 浑浑噩噩的人无所谓未来
  Standing // 双脚站在地上，一脚踏过去，一脚向未来
  Freedom // 自由：以行动反驳历史与界域，即创造
  Urgency // 紧迫感：出自时间的有限无界性
  Alienation // 疏离感：出自空间的无限有界性
  Emptiness // 空虚：紧迫感与疏离感交融
  Busyness // 忙碌：世界随之生动
  Selfhood // 独立的自身：连续性中的吸入与沉淀
  Weaving // 图画：新旧交织，仿佛有着无限的可能
  Choosing // 拣选：在可能联系中选取更持久者
  Encounter // 相遇：他者，惊喜—疑惑—流连
  Opening // 敞开：战战兢兢敞开双臂
  Evil // 恶感：坚硬冰冷，退缩，界域出现
  Shame // 耻感：将责任归于自己
  Guilt // 罪感：耻感填满空虚，第一次失去自由
  Binding // 束缚：将自己束缚起来
  Secret // 秘密：回避刻意要遗忘的
  Suffering // 痛苦：伤疤被刺痛
  Loss // 失落：下一刻的普遍失落
  Idol // 偶像：斩断过去，把偶像呼唤出来
  Ordered // 秩序：由偶像颁布，痛苦消失，世界有根基
  Sublime // 崇高感：被偶像的荣光照彻
  Passion // 激情：为获得更多而循先前之路
  Honor // 荣誉：偶像给予嘉奖
  Awe // 敬畏：偶像不予嘉奖
  Habit // 习惯：习惯了自身所背负的
  Reflection // 审视：重又冷静下来审视过去
  Dizziness // 眩晕：下一刻与死亡的威胁不断涌来
  Harmony // 和谐：过去与未来的平衡
  Model // 榜样：他者中于己有益者
  Marking // 标记：好坏路标与地图
  Discipline // 修养：忍受暂时的痛苦，消除暗礁
  Tranquility // 宁静：暗礁不再成其为暗礁，一片光明
} derive(Eq, Debug)

///|
/// 让 `==` 在 SubjectState 上以方法形式可用（显式 extend，避免隐式提升）。
pub extend SubjectState with Eq::{not_equal, equal}

///|
pub extend SubjectState with Debug::{to_repr}

///|
/// 道德发生的阶段：把状态聚成原文的若干段落，便于分组阅读与渲染。
pub(all) enum Phase {
  Natural // 本然
  Release // 自由的发生
  Becoming // 自身与拣选
  Otherness // 与他者相遇
  Bondage // 恶感·耻感·罪感·自缚
  Anguish // 痛苦与失落
  Idolatry // 偶像与根基
  Glory // 崇高·激情·荣誉·敬畏
  Recollection // 反思
  Upbringing // 修养之路
  Serenity // 宁静
} derive(Eq, Debug)

///|
pub extend Phase with Eq::{not_equal, equal}

///|
pub extend Phase with Debug::{to_repr}

///|
/// 推动主体迁移的触发。构造子的名字即原文的动作，`Trigger::label` 给出
/// 原文措辞。
pub(all) enum Trigger {
  TakeStand // 立足现在
  ActInFreedom // 基于行动的自由，反驳即创造
  FeelFinitude // 时间的有限无界 → 紧迫感
  FeelBoundlessness // 空间的无限有界 → 疏离感
  FuseFeelings // 紧迫与疏离交融
  MustBeBusy // 不得不忙碌
  KeepContinuity // 活动无片刻歇息
  Deposit // 吸入、沉淀所经历的
  TurnToResidue // 过往化为残渣与虚线
  TouchFuture // 与未来接触，拉回残渣
  Interweave // 新旧交织成画
  ChooseMoreLasting // 拣选更持久的关系
  MeetOther // 与他者遭遇
  Surprise // 惊喜
  Doubt // 疑惑
  Linger // 流连
  GoodFaith // 善意的假设
  OpenArms // 敞开双臂
  Complexify // 目标被复杂化
  ColdHard // 触碰坚硬冰冷之物
  AttributeSelf // 责任归于自己
  FillEmptiness // 耻感填满空虚
  BindSelf // 将自己束缚
  Avoid // 回避刻意要遗忘的
  Sting // 伤疤被刺痛
  BlameSelf // 责怪自己
  CutPast // 斩断与过去的关联
  SummonIdol // 把偶像呼唤出来
  EnactOrder // 偶像颁布秩序
  AbsorbGlory // 被荣光照彻
  SeekMoreJoy // 为获得更多而循先前之路
  Reward // 偶像的嘉奖
  Dread // 偶像的威慑
  Habituate // 习惯所背负的
  CoolDown // 重又冷静下来
  DoubtOneself // 自身是感觉还是其他
  TryMethods // 尝试方法看清来路
  SeekBalance // 企及过去与未来的平衡
  SeekGoal // 为和谐寻求目标
  TakeModel // 以他者中于己有益者为榜样
  Approximate // 接近目标，不断尝试
  MarkGoodBad // 标记好与坏
  RedrawMap // 地图失效，重新标记
  WidenFrontier // 界域扩大，暗礁孤立
  Endure // 忍受暂时的痛苦
  RemoveReefs // 消除暗礁
  Ascend // 自由再次提升
  WaitNext // 静待下一刻
  ReopenByHorizon // 界域重开：新的下一刻重新打开整个环节
} derive(Eq, Debug)

///|
pub extend Trigger with Eq::{not_equal, equal}

///|
pub extend Trigger with Debug::{to_repr}

///|
/// 一个状态的元信息：中文名、所属阶段、阐述性的自由刻度，以及文本依据。
pub struct StateInfo {
  state : SubjectState
  label : String
  phase : Phase
  freedom : Int
  gloss : String
}

///|
/// 一条迁移：从 `from` 出发，由 `trigger` 推动，迁到 `to`。
pub struct Transition {
  from : SubjectState
  trigger : Trigger
  to : SubjectState
}

///|
/// 状态的全部元信息。
pub fn SubjectState::info(self : SubjectState) -> StateInfo {
  match self {
    NoPast =>
      StateInfo::{
        state: NoPast,
        label: "失忆",
        phase: Natural,
        freedom: 0,
        gloss: "失忆的人没有过去。",
      }
    NoFuture =>
      StateInfo::{
        state: NoFuture,
        label: "浑噩",
        phase: Natural,
        freedom: 0,
        gloss: "浑浑噩噩的人无所谓未来。",
      }
    Standing =>
      StateInfo::{
        state: Standing,
        label: "站立",
        phase: Natural,
        freedom: 1,
        gloss: "人双脚站在地上，一脚踏在过去，一脚迈向未来；对待过去与筹措未来是现在要做的事情。",
      }
    Freedom =>
      StateInfo::{
        state: Freedom,
        label: "自由",
        phase: Release,
        freedom: 3,
        gloss: "对待和筹措乃是基于行动的自由的；自由是一种反驳，这反驳就是创造，要创立自我的时空。",
      }
    Urgency =>
      StateInfo::{
        state: Urgency,
        label: "紧迫感",
        phase: Release,
        freedom: 0,
        gloss: "人自一出生便是向死的；自这种时间的有限无界性中生出的乃是一种紧迫感。",
      }
    Alienation =>
      StateInfo::{
        state: Alienation,
        label: "疏离感",
        phase: Release,
        freedom: 0,
        gloss: "茫茫天宇尽是他畅游之所，但他所占有的空间亦仅数尺而已；自这种空间的无限有界性中生出的乃是疏离感。",
      }
    Emptiness =>
      StateInfo::{
        state: Emptiness,
        label: "空虚",
        phase: Release,
        freedom: -1,
        gloss: "当紧迫感和疏离感相互交融，人的自由体验就由此变为无处不在的空虚。",
      }
    Busyness =>
      StateInfo::{
        state: Busyness,
        label: "忙碌",
        phase: Release,
        freedom: 0,
        gloss: "人从此不得不忙碌起来，世界也因此而变得生动。",
      }
    Selfhood =>
      StateInfo::{
        state: Selfhood,
        label: "独立的自身",
        phase: Becoming,
        freedom: 1,
        gloss: "在连续性中人发现了独立的自身；这个自身不随周遭的变动而消灭，并不断将所经历的吸入、沉淀。",
      }
    Weaving =>
      StateInfo::{
        state: Weaving,
        label: "图画",
        phase: Becoming,
        freedom: 2,
        gloss: "过往的一切变成残渣，拖在身后是一条渐渐暗淡的虚线；与未来接触时其中一些被拉回，新旧交织成画，仿佛有着无限的可能。",
      }
    Choosing =>
      StateInfo::{
        state: Choosing,
        label: "拣选",
        phase: Becoming,
        freedom: 1,
        gloss: "在无限可能性中人并非无所拣选：哪一块土地更坚实，怎样的关系更持久一些？",
      }
    Encounter =>
      StateInfo::{
        state: Encounter,
        label: "相遇",
        phase: Otherness,
        freedom: 2,
        gloss: "无法避免的，人与他者遭遇了；孤独者的相遇，最初是惊喜，随之而来的是疑惑，他们在相互之间流连。",
      }
    Opening =>
      StateInfo::{
        state: Opening,
        label: "敞开",
        phase: Otherness,
        freedom: 3,
        gloss: "无法确定对方是否和自身一样，但做一个善意的假设又何妨；战战兢兢的向彼此敞开双臂。",
      }
    Evil =>
      StateInfo::{
        state: Evil,
        label: "恶感",
        phase: Bondage,
        freedom: 0,
        gloss: "当触碰到的是坚硬冰冷之物时，人一下子退缩了回来；一幅新的画面产生，这就是恶感，空间缩小，界域出现。",
      }
    Shame =>
      StateInfo::{
        state: Shame,
        label: "耻感",
        phase: Bondage,
        freedom: -1,
        gloss: "面对这一变故，人将责任归于自己，于是耻感就产生了。",
      }
    Guilt =>
      StateInfo::{
        state: Guilt,
        label: "罪感",
        phase: Bondage,
        freedom: -2,
        gloss: "当耻感填满了空虚，人就第一次失去了自由，这乃是罪感。",
      }
    Binding =>
      StateInfo::{
        state: Binding,
        label: "束缚",
        phase: Bondage,
        freedom: -3,
        gloss: "人于是将自己束缚起来，不得不重新审视过去，清晰的和不清晰的浮现在眼前。",
      }
    Secret =>
      StateInfo::{
        state: Secret,
        label: "秘密",
        phase: Bondage,
        freedom: -3,
        gloss: "他急于甩掉这一包袱，除了回避它别无他法；他从此不再提起这些刻意要遗忘的——秘密。",
      }
    Suffering =>
      StateInfo::{
        state: Suffering,
        label: "痛苦",
        phase: Anguish,
        freedom: -3,
        gloss: "如果正在来临的下一刻肆无忌惮的刺痛了伤疤，痛苦就摆在眼前了；痛苦难以终结，毕竟这是由人自己所造成。",
      }
    Loss =>
      StateInfo::{
        state: Loss,
        label: "失落",
        phase: Anguish,
        freedom: -4,
        gloss: "痛苦所造成的结果便是下一刻的普遍失落；当他的世界一天天沉沦下去，人开始责怪自己。",
      }
    Idol =>
      StateInfo::{
        state: Idol,
        label: "偶像",
        phase: Idolatry,
        freedom: 1,
        gloss: "为了重获自由，他力图斩断自己与过去关联；偶像最初是作为一个目标出现的，人从内心里把偶像呼唤出来。",
      }
    Ordered =>
      StateInfo::{
        state: Ordered,
        label: "秩序",
        phase: Idolatry,
        freedom: 2,
        gloss: "因为偶像的缘故，一切开始有了秩序，这秩序是由偶像所颁布的；痛苦奇迹般的消失了，世界重又有了更为牢固的根基。",
      }
    Sublime =>
      StateInfo::{
        state: Sublime,
        label: "崇高感",
        phase: Glory,
        freedom: 3,
        gloss: "人在偶像之中看到了荣光，当他自觉被这荣光照彻之时，崇高感便油然而生了。",
      }
    Passion =>
      StateInfo::{
        state: Passion,
        label: "激情",
        phase: Glory,
        freedom: 1,
        gloss: "为了获得更多欢乐，他循着先前的路继续走下去，每一个下一刻都随所获的加速来临；此时的人被激情所笼罩。",
      }
    Honor =>
      StateInfo::{
        state: Honor,
        label: "荣誉",
        phase: Glory,
        freedom: 2,
        gloss: "当偶像给予他嘉奖，这时便生出了荣誉。",
      }
    Awe =>
      StateInfo::{
        state: Awe,
        label: "敬畏",
        phase: Glory,
        freedom: -1,
        gloss: "反之则是敬畏。",
      }
    Habit =>
      StateInfo::{
        state: Habit,
        label: "习惯",
        phase: Glory,
        freedom: 0,
        gloss: "人在这荣誉和敬畏中度过了一段好时光；当他习惯了自身所背负的，他便重又冷静下来审视过去。",
      }
    Reflection =>
      StateInfo::{
        state: Reflection,
        label: "审视",
        phase: Recollection,
        freedom: -1,
        gloss: "他为了追逐各种感觉几乎已经遗忘了那最初的目标；自身是一连串的感觉呢还是其他的什么？人的世界重又岌岌可危起来。",
      }
    Dizziness =>
      StateInfo::{
        state: Dizziness,
        label: "眩晕",
        phase: Recollection,
        freedom: 0,
        gloss: "他开始尝试各种方法把来路看得更清楚；但时间并未停歇，下一刻和死亡的威胁不断涌上来，人在眩晕中企及自身的和谐。",
      }
    Harmony =>
      StateInfo::{
        state: Harmony,
        label: "和谐",
        phase: Recollection,
        freedom: 2,
        gloss: "这种和谐是过去和未来的平衡。",
      }
    Model =>
      StateInfo::{
        state: Model,
        label: "榜样",
        phase: Upbringing,
        freedom: 1,
        gloss: "当他为和谐寻求一个目标时，人将他者中于己有益的当作了自身的榜样。",
      }
    Marking =>
      StateInfo::{
        state: Marking,
        label: "标记",
        phase: Upbringing,
        freedom: 1,
        gloss: "他把好的和坏的各作了标记以指导下一刻的朝向，在前方标上路标，尽量避开暗礁；而每一次变迁都令上一刻的地图不再有效。",
      }
    Discipline =>
      StateInfo::{
        state: Discipline,
        label: "修养",
        phase: Upbringing,
        freedom: 2,
        gloss: "界域不断扩大，暗礁不再孤立；人试着忍受暂时的痛苦来换取更大的自由，消除这些暗礁的活动便是修养。",
      }
    Tranquility =>
      StateInfo::{
        state: Tranquility,
        label: "宁静",
        phase: Serenity,
        freedom: 4,
        gloss: "暗礁越来越少，界域越来越宽广，人的自由再一次被提升；苦痛减轻，暗礁也不再成其为暗礁，双目所视十指所指无非一片光明。",
      }
  }
}

///|
/// 状态的原文名（取自原文的措辞）；通用定名见 `designation`。
pub fn SubjectState::label(self : SubjectState) -> String {
  self.info().label
}

///|
/// 状态所属的阶段。
pub fn SubjectState::phase(self : SubjectState) -> Phase {
  self.info().phase
}

///|
/// 阐述性的自由刻度；负数表示受缚。
pub fn SubjectState::freedom(self : SubjectState) -> Int {
  self.info().freedom
}

///|
/// 取自原文的文本依据。
pub fn SubjectState::gloss(self : SubjectState) -> String {
  self.info().gloss
}

///|
/// 阶段的原文名（取自原文的分段）；通用定名见 `designation`。
pub fn Phase::label(self : Phase) -> String {
  match self {
    Natural => "本然"
    Release => "自由的发生"
    Becoming => "自身与拣选"
    Otherness => "与他者相遇"
    Bondage => "恶感·耻感·罪感·自缚"
    Anguish => "痛苦与失落"
    Idolatry => "偶像与根基"
    Glory => "崇高·激情·荣誉·敬畏"
    Recollection => "反思"
    Upbringing => "修养之路"
    Serenity => "宁静"
  }
}

///|
/// 触发的原文措辞。
pub fn Trigger::label(self : Trigger) -> String {
  match self {
    TakeStand => "双脚站在地上，一脚踏在过去，一脚迈向未来"
    ActInFreedom =>
      "对待和筹措基于行动的自由；自由是对历史与界域的反驳，这反驳就是创造"
    FeelFinitude => "时间的有限无界性生出的紧迫感"
    FeelBoundlessness => "空间的无限有界性生出的疏离感"
    FuseFeelings =>
      "紧迫感与疏离感交融，自由的体验变为无处不在的空虚"
    MustBeBusy => "人不得不忙碌起来，世界也因此而变得生动"
    KeepContinuity =>
      "活动着的并不曾做片刻歇息，在连续性中人发现了独立的自身"
    Deposit => "不断将所经历的吸入、沉淀"
    TurnToResidue =>
      "过往的一切变成残渣，拖在身后是一条渐渐暗淡的虚线"
    TouchFuture => "与未来接触，其中的一些重又被拉了过来"
    Interweave =>
      "新旧交织成一幅图画，并随每一个新的下一刻不断变换"
    ChooseMoreLasting =>
      "在一切可能的联系中选取更持久一些的关系"
    MeetOther => "无法避免的，人与他者遭遇了"
    Surprise => "最初是惊喜"
    Doubt => "随之而来的是疑惑"
    Linger => "他们在相互之间流连"
    GoodFaith =>
      "无法确定对方是否和自身一样，但做一个善意的假设又何妨"
    OpenArms => "战战兢兢的向彼此敞开双臂"
    Complexify => "这同一个目标在不经意间又被复杂化了"
    ColdHard =>
      "触碰到的是坚硬冰冷之物，人一下子退缩了回来"
    AttributeSelf => "面对这一变故，人将责任归于自己"
    FillEmptiness => "耻感填满了空虚，人第一次失去自由"
    BindSelf => "人于是将自己束缚起来"
    Avoid => "除了回避它，还能做些什么呢"
    Sting => "正在来临的下一刻肆无忌惮的刺痛了伤疤"
    BlameSelf => "当他的世界一天天沉沦下去，人开始责怪自己"
    CutPast => "为了重获自由，他力图斩断自己与过去关联"
    SummonIdol => "人从内心里把偶像呼唤出来"
    EnactOrder => "一切开始有了秩序，这秩序是由偶像所颁布的"
    AbsorbGlory => "当他自觉被这荣光照彻之时"
    SeekMoreJoy => "为了获得更多他循着先前的路继续走下去"
    Reward => "当偶像给予他嘉奖"
    Dread => "反之则是敬畏"
    Habituate => "当他习惯了自身所背负的"
    CoolDown => "他便重又冷静下来审视过去"
    DoubtOneself => "自身是一连串的感觉呢还是其他的什么"
    TryMethods =>
      "他开始尝试各种方法，以使自己把来路看得更清楚一些"
    SeekBalance => "人在眩晕中企及自身的和谐"
    SeekGoal => "当他为和谐寻求一个目标时"
    TakeModel => "将他者中于己有益的当作了自身的榜样"
    Approximate => "他试图接近这个目标，他不断尝试"
    MarkGoodBad =>
      "他把好的和坏的各作了标记，以此来指导下一刻的朝向"
    RedrawMap =>
      "每一次下一刻的变迁都令上一刻的地图不再有效，标记又要重新再做过"
    WidenFrontier =>
      "随着界域的不断扩大，周遭便渐渐明朗起来，暗礁也不再是孤立的"
    Endure => "他试着忍受暂时的痛苦来换取更大的自由"
    RemoveReefs => "消除这些暗礁的活动便是修养"
    Ascend =>
      "暗礁越来越少，界域也越来越宽广，人的自由就再一次被提升"
    WaitNext => "他所需要做的，只是静待下一刻的来临"
    ReopenByHorizon =>
      "界域继续扩大，新的下一刻令既有的地图失效，整个环节重新打开"
  }
}

///|
/// 全部状态，按主线阅读顺序排列。
pub fn all_states() -> Array[SubjectState] {
  [
    NoPast,
    NoFuture,
    Standing,
    Freedom,
    Urgency,
    Alienation,
    Emptiness,
    Busyness,
    Selfhood,
    Weaving,
    Choosing,
    Encounter,
    Opening,
    Evil,
    Shame,
    Guilt,
    Binding,
    Secret,
    Suffering,
    Loss,
    Idol,
    Ordered,
    Sublime,
    Passion,
    Honor,
    Awe,
    Habit,
    Reflection,
    Dizziness,
    Harmony,
    Model,
    Marking,
    Discipline,
    Tranquility,
  ]
}

///|
/// 全部阶段。
pub fn all_phases() -> Array[Phase] {
  [
    Natural,
    Release,
    Becoming,
    Otherness,
    Bondage,
    Anguish,
    Idolatry,
    Glory,
    Recollection,
    Upbringing,
    Serenity,
  ]
}

///|
/// 初始状态：本然站立。
pub fn initial() -> SubjectState {
  Standing
}

///|
/// 终态：宁静。
pub fn terminal() -> SubjectState {
  Tranquility
}

///|
/// 状态机的全部迁移。
pub fn transitions() -> Array[Transition] {
  let ts : Array[Transition] = [
    // 本然：两条退化起点汇入站立，站立生出自由。
    { from: NoPast, trigger: TakeStand, to: Standing, },
    { from: NoFuture, trigger: TakeStand, to: Standing, },
    { from: Standing, trigger: ActInFreedom, to: Freedom, },
    // 自由的发生：时间与空间生出的两种感受交融为空虚。
    { from: Freedom, trigger: FeelFinitude, to: Urgency, },
    { from: Freedom, trigger: FeelBoundlessness, to: Alienation, },
    { from: Urgency, trigger: FuseFeelings, to: Emptiness, },
    { from: Alienation, trigger: FuseFeelings, to: Emptiness, },
    { from: Emptiness, trigger: MustBeBusy, to: Busyness, },
    // 自身与拣选。
    { from: Busyness, trigger: KeepContinuity, to: Selfhood, },
    { from: Selfhood, trigger: Deposit, to: Selfhood, },
    { from: Selfhood, trigger: TurnToResidue, to: Weaving, },
    { from: Weaving, trigger: TouchFuture, to: Weaving, },
    { from: Weaving, trigger: Interweave, to: Weaving, },
    { from: Weaving, trigger: ChooseMoreLasting, to: Choosing, },
    // 与他者相遇。
    { from: Choosing, trigger: MeetOther, to: Encounter, },
    { from: Encounter, trigger: Surprise, to: Encounter, },
    { from: Encounter, trigger: Doubt, to: Encounter, },
    { from: Encounter, trigger: Linger, to: Encounter, },
    { from: Encounter, trigger: GoodFaith, to: Opening, },
    { from: Opening, trigger: OpenArms, to: Opening, },
    { from: Opening, trigger: Complexify, to: Opening, },
    { from: Opening, trigger: ColdHard, to: Evil, },
    // 恶感·耻感·罪感·自缚。
    { from: Evil, trigger: AttributeSelf, to: Shame, },
    { from: Shame, trigger: FillEmptiness, to: Guilt, },
    { from: Guilt, trigger: BindSelf, to: Binding, },
    { from: Binding, trigger: Avoid, to: Secret, },
    // 痛苦与失落。
    { from: Secret, trigger: Sting, to: Suffering, },
    { from: Suffering, trigger: BlameSelf, to: Loss, },
    { from: Loss, trigger: CutPast, to: Idol, },
    // 偶像与根基。
    { from: Idol, trigger: SummonIdol, to: Idol, },
    { from: Idol, trigger: EnactOrder, to: Ordered, },
    { from: Ordered, trigger: EnactOrder, to: Ordered, },
    { from: Ordered, trigger: AbsorbGlory, to: Sublime, },
    // 崇高·激情·荣誉·敬畏。
    { from: Sublime, trigger: SeekMoreJoy, to: Passion, },
    { from: Passion, trigger: Reward, to: Honor, },
    { from: Passion, trigger: Dread, to: Awe, },
    { from: Honor, trigger: Habituate, to: Habit, },
    { from: Awe, trigger: Habituate, to: Habit, },
    // 反思。
    { from: Habit, trigger: CoolDown, to: Reflection, },
    { from: Reflection, trigger: DoubtOneself, to: Reflection, },
    { from: Reflection, trigger: TryMethods, to: Dizziness, },
    { from: Dizziness, trigger: SeekBalance, to: Harmony, },
    // 修养之路。
    { from: Harmony, trigger: SeekGoal, to: Harmony, },
    { from: Harmony, trigger: TakeModel, to: Model, },
    { from: Model, trigger: Approximate, to: Marking, },
    { from: Marking, trigger: MarkGoodBad, to: Marking, },
    { from: Marking, trigger: RedrawMap, to: Marking, },
    { from: Marking, trigger: WidenFrontier, to: Discipline, },
    { from: Discipline, trigger: Endure, to: Discipline, },
    { from: Discipline, trigger: RemoveReefs, to: Discipline, },
    { from: Discipline, trigger: Ascend, to: Tranquility, },
    // 宁静：静待下一刻。
    { from: Tranquility, trigger: WaitNext, to: Tranquility, },
    // 主体通用性：静定不是终点——界域重开，环节序列可重入。
    { from: Tranquility, trigger: ReopenByHorizon, to: Reflection, },
  ]
  ts
}

///|
/// 从 `state` 出发的全部出边。
pub fn successors(state : SubjectState) -> Array[(Trigger, SubjectState)] {
  let out : Array[(Trigger, SubjectState)] = []
  for t in transitions() {
    if t.from == state {
      out.push((t.trigger, t.to))
    }
  }
  out
}

///|
/// 指向 `state` 的全部入边。
pub fn predecessors(state : SubjectState) -> Array[(SubjectState, Trigger)] {
  let out : Array[(SubjectState, Trigger)] = []
  for t in transitions() {
    if t.to == state {
      out.push((t.from, t.trigger))
    }
  }
  out
}

///|
/// 从 `from` 出发，沿迁移是否可达 `to`（含 `from == to`）。
pub fn reachable(from : SubjectState, to : SubjectState) -> Bool {
  let seen : Array[SubjectState] = [from]
  let mut i = 0
  while i < seen.length() {
    let cur = seen[i]
    if cur == to {
      return true
    }
    for t in transitions() {
      if t.from == cur && !contains_state(seen, t.to) {
        seen.push(t.to)
      }
    }
    i += 1
  }
  false
}

///|
/// 线性查找，避免为一个小的枚举引入哈希集合。
fn contains_state(xs : Array[SubjectState], s : SubjectState) -> Bool {
  for x in xs {
    if x == s {
      return true
    }
  }
  false
}

///|
/// 从站立到宁静的一条主线（不含自环与并列分支，如疏离感）。
pub fn genesis_path() -> Array[SubjectState] {
  [
    Standing,
    Freedom,
    Urgency,
    Emptiness,
    Busyness,
    Selfhood,
    Weaving,
    Choosing,
    Encounter,
    Opening,
    Evil,
    Shame,
    Guilt,
    Binding,
    Secret,
    Suffering,
    Loss,
    Idol,
    Ordered,
    Sublime,
    Passion,
    Honor,
    Habit,
    Reflection,
    Dizziness,
    Harmony,
    Model,
    Marking,
    Discipline,
    Tranquility,
  ]
}
