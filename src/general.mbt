///|
/// 主体通用性修订层。
///
/// ## 修订原则：主体通用性
///
/// 一个状态若要属于"任何主体"，就不能由某一主体的偶然内容来定名，只能由
/// "主体之为主体"必然具有的结构关系来定名：与自身持存的关系，与时间（过去—
/// 现在—未来）的关系，与他者的关系，与界域的关系，与自由的关系，与规范的关系。
/// 凡把临床状态（失忆）、特定道德情感（耻、罪）、宗教—文化产物（偶像、崇高）、
/// 专有情景写进名字的，本次都改；已经合于原则的（自由、空虚、相遇、敞开、痛苦、
/// 眩晕、宁静……）保留。
///
/// 据此，命名分三层，互不丢失：
///
/// - `designation`：通用定名（修订后的主名，只指称结构关系）；
/// - `label`：原文名（`subject.mbt` 中的原文措辞，即可回溯的来源层）；
/// - `qualified`："通用定名（原文：原文名）"，渲染层默认使用它。
///
/// 阶段被改写为结构环节（`Phase::designation`）；历程被改写为一条**可重入的
/// 环节序列**（`course`、`render_course`）：静定不是终点，界域一扩大，环节便
/// 重新打开（`Tranquility --ReopenByHorizon--> Reflection`）。

///|
/// 状态的通用定名：只指称任一主体皆具的结构关系，不指称特定主体的心理内容。
pub fn SubjectState::designation(self : SubjectState) -> String {
  match self {
    NoPast => "无忆"
    NoFuture => "无筹"
    Standing => "立位"
    Freedom => "自由"
    Urgency => "紧迫"
    Alienation => "疏离"
    Emptiness => "空虚"
    Busyness => "忙碌"
    Selfhood => "自身"
    Weaving => "交织"
    Choosing => "择取"
    Encounter => "相遇"
    Opening => "敞开"
    Evil => "受挫"
    Shame => "自归"
    Guilt => "失权"
    Binding => "自缚"
    Secret => "隐没"
    Suffering => "痛苦"
    Loss => "沉落"
    Idol => "投射"
    Ordered => "立序"
    Sublime => "崇奉"
    Passion => "激情"
    Honor => "受赏"
    Awe => "畏怖"
    Habit => "惯习"
    Reflection => "反顾"
    Dizziness => "眩晕"
    Harmony => "平衡"
    Model => "范型"
    Marking => "图绘"
    Discipline => "修习"
    Tranquility => "宁静"
  }
}

///|
/// 阶段的通用定名：把原来的情绪—文化分段改写成结构环节。
pub fn Phase::designation(self : Phase) -> String {
  match self {
    Natural => "立位"
    Release => "自决"
    Becoming => "自成"
    Otherness => "遭遇"
    Bondage => "归责"
    Anguish => "受创"
    Idolatry => "奠基"
    Glory => "献身"
    Recollection => "反顾"
    Upbringing => "范导"
    Serenity => "安位"
  }
}

///|
/// "通用定名（原文：原文名）"；两者相同时只写一个。
pub fn SubjectState::qualified(self : SubjectState) -> String {
  let general = self.designation()
  let source = self.label()
  if general == source {
    general
  } else {
    "\{general}（原文：\{source}）"
  }
}

///|
/// "通用阶段名（原文：原文阶段名）"。
pub fn Phase::qualified(self : Phase) -> String {
  let general = self.designation()
  let source = self.label()
  if general == source {
    general
  } else {
    "\{general}（原文：\{source}）"
  }
}

///|
/// 修订后的历程：可重入的环节序列。
///
/// 与 `genesis_path` 同序，但把结尾从"止于宁静"改成"宁静 ↺ 反顾"——静定只是
/// 本环节的静定极，界域继续扩大时，`Tranquility --ReopenByHorizon--> Reflection`
/// 令整个环节重新打开。任何主体都不是一次走完，而是反复经过这条序列。
pub fn course() -> Array[SubjectState] {
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
    Reflection,
  ]
}

///|
/// 历程的通用书写：环节序列，末尾标出重入。
pub fn render_course() -> String {
  let parts = course()
  let body : Array[String] = []
  let mut i = 0
  while i + 1 < parts.length() {
    body.push(parts[i].designation())
    i += 1
  }
  "\{body.join(" → ")} ↺ \{parts[parts.length() - 1].designation()}（界域重开，环节重入）"
}

///|
/// 定名对照表：通用定名 / 原文名 / 文本依据。
pub fn render_naming_table() -> String {
  let lines : Array[String] = ["# 主体通用性修订 · 定名对照表", ""]
  lines.push("## 阶段")
  for p in all_phases() {
    lines.push("- \{p.designation()}　（原文：\{p.label()}）")
  }
  lines.push("")
  lines.push("## 状态")
  for s in all_states() {
    lines.push(
      "- \{s.designation()}　（原文：\{s.label()}）　\{s.gloss()}",
    )
  }
  lines.join("\n")
}

///|
/// 本次修订所依据的原则，供 CLI 直接打印。
pub fn revision_principle() -> String {
  let text =
    #|主体通用性原则：一个状态若要属于"任何主体"，就不能由某一主体的偶然内容定名，
    #|只能由"主体之为主体"必然具有的结构关系定名——与自身持存的关系、与时间（过去—现在—未来）的关系、
    #|与他者的关系、与界域的关系、与自由的关系、与规范的关系。
    #|
    #|据此修订（通用定名 ← 原文名；一律两字）：
    #|  无忆←失忆       无筹←浑噩       立位←站立     交织←图画     择取←拣选
    #|  紧迫←紧迫感     疏离←疏离感     受挫←恶感     自归←耻感     失权←罪感
    #|  自缚←束缚       隐没←秘密       沉落←失落     投射←偶像     立序←秩序
    #|  崇奉←崇高感     受赏←荣誉       畏怖←敬畏     惯习←习惯     反顾←审视
    #|  平衡←和谐       范型←榜样       图绘←标记     修习←修养
    #|
    #|阶段修订（通用环节 ← 原文分段；一律两字）：
    #|  立位←本然   自决←自由的发生   自成←自身与拣选   遭遇←与他者相遇
    #|  归责←恶感·耻感·罪感·自缚   受创←痛苦与失落   奠基←偶像与根基
    #|  献身←崇高·激情·荣誉·敬畏   反顾←反思   范导←修养之路   安位←宁静
    #|
    #|历程修订：由"止于宁静的单程线"改为"可重入的环节序列"——宁静只是静定极，
    #|界域重开时（宁静 --ReopenByHorizon--> 反顾）整个环节重新打开。
    #|
    #|原文名一律保留为可回溯的来源层（`label`），通用定名为 `designation`。
  text
}
