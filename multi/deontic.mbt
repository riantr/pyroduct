///|
/// 规范推理的形式化：把 R1–R14 从**散文**变成**可推的规则库**。
///
/// 「模型整理」，非原文直述。原文给的是十四条散文准则（`rules.mbt`）与一条手写的
/// 判词 if 链（`encounter.mbt`）。散文不可推，if 链不可查——链里那些「先判哪条」
/// 的次序从未被写下来，于是它既不能被审，也不能被重排。
///
/// 本文件把这层补上，取的是**可辩逻辑（defeasible logic, DL）与 ASPIC+** 的做法，
/// 而不是标准 deontic logic（SDL）。理由是实测出来的，不是偏好：
///
/// - SDL 的公理 `NC`（`Op → ¬O¬p`，不得同时既当且不当）会把**互相冲突的义务**
///   塌成 `O⊥`（一个做不到的义务）。SEP 补编专有一节讲「拒斥 NC 的冲突容忍
///   deontic 逻辑」。本层的 R1–R14 **允许**相左的准则同时成立，所以 SDL 当
///   规则引擎是错的——它连「哪条赢」都问不出来。
/// - DL 的办法是把**规则强度**与**冲突解决**分开：严格规则永不被击败，可辩规则
///   可被显式击败；冲突解决不是靠一条更大的规则压住，而是靠**优先序**在存活者
///   之间选。这正是本文件的两件东西：`norms()` 给强度，`precedence()` 给次序。
///
/// 最重要的一条区分，来自 DL 文献里反复强调的那句话：
///
/// > **优先 ≠ 击败。**「R1 压住 R5，**除非** R5 的条件成立」这句话**不能**写成
/// > 优先序——优先序只说「两条都成立时谁赢」，不说「某条是否成立」。要表达
/// > 「除非」，必须有一条**显式击败关系**。
///
/// 本层里恰好有这么一处：R9（信仰商谈可纳入共识真理）对 R1/R8（体制相左即冲突）
/// 就是「除非」关系。它是**击败**（硬），不是优先（软）——所以它写在 `defeaters()`
/// 里，不写在 `precedence()` 里。把两者混为一谈，正是良善撒玛利亚悖论与
/// 「例外」被混为一谈的经典来源：原文说 R9 是作者的**例外**（宗教真理亦可纳入
/// 共识真理理论），例外是击败，不是排序。
///
/// 两种冲突解决的后果截然不同，因此推导链把两者**分开记账**：
///
/// - `defeated`（硬）：被显式击败，**退出**这场推演。
/// - `outranked`（软）：前提齐备、无人击败，但按优先序让位——**结论仍然成立**，
///   只是让位给了别的结论。这条信息在手写 if 链里是被扔掉的。
///
/// 判词本身**不由本文件产生**：遭遇层（`encounter`）的判词是模型，本文件是它的
/// **独立读法**，两者必须一致（`agrees_with_encounter`）。这一对「两处副本互相
/// 看着」是本仓一贯的做法：两份 README、桥与 CLI 的面目录、插件目录与工具描述，
/// 都是这么绑的。改了一处而忘了另一处，判据立刻红。

///|
/// 规则强度。照 DL 的惯例分成两类。
pub(all) enum NormStrength {
  Strict // 严格规则：不可被击败（结构性事实）
  Defeasible // 可辩规则：可被显式击败
} derive(Eq)

///|
pub extend NormStrength with Eq::{not_equal, equal}

///|
/// 规则强度名。
pub fn NormStrength::label(self : NormStrength) -> String {
  match self {
    Strict => "严格"
    Defeasible => "可辩"
  }
}

///|
/// 前提：可机读的事实名。规则的「条件」不再是一段散文，而是一个可判的谓词。
///
/// 八个前提覆盖遭遇层的全部判据分支；新增分支必须同时新增前提，否则推不动。
pub(all) enum Premise {
  ClaimOutOfPhase // 主张落在错误的时间位置（R4）
  ClaimNotJointReview // 该主张不进入共同检讨（R5，第四章第五节 P.50）
  ImmanentRegime // 有一方是「内在秩序」体制（R1／R8）
  RegimesDiffer // 双方体制相左（R1／R8）
  FaithDiscourse // 走的是信仰商谈（R9）
  MonologicGap // 逻各斯体制下诚的差距过大（R5）
  BothChengComplete // 诚然体制下双诚俱足（R12）
  SeekingConsensus // 双方体制都寻求共识（R13）
} derive(Eq)

///|
pub extend Premise with Eq::{not_equal, equal}

///|
/// 前提名。
pub fn Premise::label(self : Premise) -> String {
  match self {
    ClaimOutOfPhase => "主张落在错误的时间位置"
    ClaimNotJointReview => "该主张不进入共同检讨"
    ImmanentRegime => "有一方是内在秩序体制"
    RegimesDiffer => "双方体制相左"
    FaithDiscourse => "走的是信仰商谈"
    MonologicGap => "逻各斯体制下诚的差距过大"
    BothChengComplete => "诚然体制下双诚俱足"
    SeekingConsensus => "双方体制都寻求共识"
  }
}

///|
/// 一条裁决规范（决策规则）。
///
/// `basis` 是它依据的 R 编号——**两处副本**：R 编号的权威表在 `rules.mbt`，这里
/// 只记「本条凭什么」，由 `classification_complete` 与 `classification_disjoint`
/// 盯着，不许一条 R 编号悄悄变成两条规范共用而不被记录。
pub(all) struct Norm {
  id : String
  basis : Array[String]
  strength : NormStrength
  premises : Array[Premise]
  verdict : Verdict
  effect : String
}

///|
/// 一次显式击败（硬关系）。
///
/// `by` 击败 `target`，条件是 `when` 成立。**击败者自己也得先成立**——一条没被
/// 触发的击败规则不击败任何东西。
pub(all) struct Defeater {
  by : String
  target : String
  when : Premise
}

///|
/// 一次让位（软关系）：`loser` 前提齐备、无人击败，却按优先序让给了 `winner`。
pub(all) struct Outranked {
  loser : String
  winner : String
  loser_verdict : Verdict
} derive(Eq)

///|
pub extend Outranked with Eq::{not_equal, equal}

///|
/// 一次被击败（硬关系）：`target` 退出推演。
pub(all) struct Defeated {
  target : String
  by : String
} derive(Eq)

///|
pub extend Defeated with Eq::{not_equal, equal}

///|
/// 一次遭遇的推导链。
///
/// `fired` 是前提齐备的规范；`defeated` 是被显式击败的；`outranked` 是让位的；
/// `accepted` 是**判词一致**的存活规范（可能不止一条——两条规范给出同一个判词时，
/// 它们互相印证，不是冲突）；`verdict` 是胜出者的判词。
pub(all) struct Derivation {
  fired : Array[String]
  defeated : Array[Defeated]
  outranked : Array[Outranked]
  accepted : Array[String]
  verdict : Verdict
  winner : String
  note : String
} derive(Eq)

///|
pub extend Derivation with Eq::{not_equal, equal}

///|
/// 裁决规范库（模型整理：把遭遇层的判词分支写成数据）。
///
/// 编号 D1–D8 与遭遇层 if 链的分支一一对应。`precedence()` 给出的次序**照抄**
/// if 链的判定次序——但**显式化**了：写下来才能被审，才能被问「为什么是这条」。
pub fn norms() -> Array[Norm] {
  [
    {
      id: "D1",
      basis: ["R4"],
      strength: Strict,
      premises: [ClaimOutOfPhase],
      verdict: OutOfPhase,
      effect: "有效性主张错位：提出者让位，归责于己",
    },
    {
      id: "D2",
      basis: ["R5", "R13"],
      strength: Strict,
      premises: [ClaimNotJointReview],
      verdict: Provisional,
      effect: "他之诚只由言语者自担，不进入共同检讨",
    },
    {
      id: "D3",
      basis: ["R1", "R8"],
      strength: Defeasible,
      premises: [ImmanentRegime],
      verdict: NotSought,
      effect: "真理被当作内在于世界的永恒秩序，既不提出也不接受主张",
    },
    {
      id: "D4",
      basis: ["R1", "R8"],
      strength: Defeasible,
      premises: [RegimesDiffer],
      verdict: RegimeClash,
      effect: "体制相左：一边的「主体间性」在另一边看来是加倍的主观主义",
    },
    {
      id: "D5",
      basis: ["R9"],
      strength: Defeasible,
      premises: [FaithDiscourse],
      verdict: Provisional,
      effect: "走的是信仰商谈：宗教真理可纳入共识真理理论",
    },
    {
      id: "D6",
      basis: ["R13"],
      strength: Defeasible,
      premises: [SeekingConsensus],
      verdict: Provisional,
      effect: "横（相互检讨）纵（共同理性）交织成网，共识是网上的临时节点",
    },
    {
      id: "D7",
      basis: ["R5"],
      strength: Defeasible,
      premises: [MonologicGap],
      verdict: Monologic,
      effect: "诚的差距让一方把逻各斯收归己有，另一方的言说被消音",
    },
    {
      id: "D8",
      basis: ["R12"],
      strength: Defeasible,
      premises: [BothChengComplete],
      verdict: Attuned,
      effect: "他之诚与己之诚俱足：统于自性内照，入于无人我、齐万物之境",
    },
  ]
}

///|
/// 优先序（软关系）：两条规范都成立且判词相左时，这条次序决定谁赢。
///
/// 它是**总序**，因为遭遇层的 if 链本来就是一条总序——把隐含的次序显式化，
/// 比假装存在一个偏序更诚实。若某日改成偏序，`outranked` 会开始出现「互不
/// 让位却判词相左」的情形，那时才需要谈 ASPIC+ 那种多接受集。
pub fn precedence() -> Array[String] {
  ["D1", "D2", "D3", "D7", "D8", "D5", "D4", "D6"]
}

///|
/// 显式击败关系（硬关系）。
///
/// 只有一处：D5（信仰商谈的例外）击败 D4（体制相左即冲突）。这是 DL 里的
/// `s1 => r` 形状——「除非」关系**不可**写成优先序。
pub fn defeaters() -> Array[Defeater] {
  [{ by: "D5", target: "D4", when: FaithDiscourse, }]
}

///|
/// 不直接裁决遭遇、但约束遭遇层的规则（附不裁决的理由）。
///
/// 「不参与裁决」本身也是一个要交代的决定：把 R2／R3／R10 这类准则硬塞进裁决
/// 链，只会让判词依赖与判词无关的事实。所以它们列在这里，并且**逐条写明为什么
/// 不裁决**——由 `classification_complete` 盯着，不许有规则悄悄不露面。
pub fn background() -> Array[(String, String)] {
  [
    (
      "R2", "不独断：判词永不带终局性——由「永远可修订」保证",
    ),
    (
      "R3", "解蔽—遮蔽：「隐」永远非空——由「未穷尽者非空」保证",
    ),
    (
      "R6", "弃符合论、存方法：裁决不靠命题与事态相符，故没有符合论判据可查",
    ),
    (
      "R7", "构成性：实践结果回写进认识状态——遭遇层改写双方位置即为回写",
    ),
    ("R10", "谬误残余：残余只被削减、恒不为零"),
    ("R11", "不可闭合：共识不冻结，历史不封存"),
    (
      "R14", "共识即建议：共识只能以建议形式发布，不得替对方作结",
    ),
  ]
}

///|
/// 前提是否成立。
fn holds(
  p : Premise,
  a : Subject,
  b : Subject,
  discourse : DiscourseType,
  claim : ValidityClaim,
) -> Bool {
  match p {
    ClaimOutOfPhase => !in_phase(claim)
    ClaimNotJointReview => !requires_joint_review(claim.kind)
    ImmanentRegime => a.regime == Immanent || b.regime == Immanent
    RegimesDiffer => a.regime != b.regime
    FaithDiscourse => discourse == Faith
    MonologicGap =>
      a.regime == Logos && b.regime == Logos && cheng_gap(a, b) > 20
    BothChengComplete =>
      a.regime == ChengRan &&
      b.regime == ChengRan &&
      a.cheng.is_complete() &&
      b.cheng.is_complete()
    SeekingConsensus => a.regime.seeks_consensus() && b.regime.seeks_consensus()
  }
}

///|
/// 按编号取一条规范。
pub fn norm_of(id : String) -> Norm? {
  for n in norms() {
    if n.id == id {
      return Some(n)
    }
  }
  None
}

///|
/// 优先序里的名次（越小越优先）。不在表里返回一个大数——它**不在**任何次序里，
/// 不能悄悄排在最后一位冒充有优先权。
fn rank_of(id : String) -> Int32 {
  let order = precedence()
  for i = 0; i < order.length(); i = i + 1 {
    if order[i] == id {
      return i
    }
  }
  9999
}

///|
/// 推导一次遭遇：前提 → 击败 → 优先 → 判词。
///
/// 返回 `None` 表示**没有一条规范的前提齐备**——那不是「随便给个判词」，而是
/// 「这套规则库判不了这件事」。宁可说判不了，也不编一个出来。
pub fn derive_chain(
  a : Subject,
  b : Subject,
  discourse : DiscourseType,
  claim : ValidityClaim,
) -> Derivation? {
  let table = norms()
  // 1. 前提齐备者。
  let fired : Array[String] = []
  for n in table {
    let mut all = true
    for p in n.premises {
      if !holds(p, a, b, discourse, claim) {
        all = false
      }
    }
    if all {
      fired.push(n.id)
    }
  }
  // 2. 显式击败（硬）。击败者自己也得成立，否则它不击败任何东西。
  let defeated : Array[Defeated] = []
  for d in defeaters() {
    if !fired.contains(d.by) {
      continue
    }
    if !holds(d.when, a, b, discourse, claim) {
      continue
    }
    if fired.contains(d.target) {
      defeated.push({ target: d.target, by: d.by, })
    }
  }
  // 3. 存活者：前提齐备且未被击败。
  let survivors : Array[String] = []
  for id in fired {
    let mut killed = false
    for d in defeated {
      if d.target == id {
        killed = true
      }
    }
    if !killed {
      survivors.push(id)
    }
  }
  // 4. 优先序选胜出者。
  let mut winner = ""
  for id in survivors {
    if winner.length() == 0 || rank_of(id) < rank_of(winner) {
      winner = id
    }
  }
  if winner.length() == 0 {
    return None
  }
  let wn = match norm_of(winner) {
    Some(n) => n
    None => return None
  }
  // 5. 接受集：存活者中与胜出者判词一致者（判词相左者让位，记在 `outranked`）。
  let accepted : Array[String] = []
  let outranked : Array[Outranked] = []
  for id in survivors {
    let n = match norm_of(id) {
      Some(x) => x
      None => continue
    }
    if n.verdict == wn.verdict {
      accepted.push(id)
    } else {
      outranked.push({ loser: id, winner, loser_verdict: n.verdict, })
    }
  }
  Some({
    fired,
    defeated,
    outranked,
    accepted,
    verdict: wn.verdict,
    winner,
    note: wn.effect,
  })
}

///|
/// 形式化的判词与遭遇层的判词是否一致。
///
/// 这是两份副本之间的那道锁：改了遭遇层的 if 链却忘了规则库（或反之），这里
/// 立刻返回 false。两边一致时，`derive` 就是遭遇层的**独立读法**。
pub fn agrees_with_encounter(
  a : Subject,
  b : Subject,
  discourse : DiscourseType,
  claim : ValidityClaim,
) -> Bool {
  match derive_chain(a, b, discourse, claim) {
    Some(d) => d.verdict == encounter(a, b, discourse, claim).verdict
    None => false
  }
}

///|
/// 优先序是总序：每条规范都恰有一个名次，且互不相同。
pub fn precedence_is_total() -> Bool {
  let order = precedence()
  let table = norms()
  if order.length() != table.length() {
    return false
  }
  for id in order {
    let mut seen = 0
    for other in order {
      if other == id {
        seen += 1
      }
    }
    if seen != 1 {
      return false
    }
  }
  for n in table {
    if !order.contains(n.id) {
      return false
    }
  }
  true
}

///|
/// 击败关系无环：一条规范不能经击败链回到自己（否则「谁击败谁」无解）。
pub fn defeaters_acyclic() -> Bool {
  let ds = defeaters()
  for d in ds {
    if d.by == d.target {
      return false
    }
    for e in ds {
      if e.by == d.target && e.target == d.by {
        return false
      }
    }
  }
  true
}

///|
/// 每条 R 编号都被归了类：要么在某条裁决规范里，要么在 `background()` 里。
pub fn classification_complete() -> Bool {
  let all = rules()
  for r in all {
    if !classified(r.code) {
      return false
    }
  }
  true
}

///|
/// 归类互斥：一条 R 编号不能既裁决遭遇、又不裁决遭遇。
pub fn classification_disjoint() -> Bool {
  let all = rules()
  for r in all {
    let mut in_norm = false
    for n in norms() {
      if n.basis.contains(r.code) {
        in_norm = true
      }
    }
    let mut in_bg = false
    for bg in background() {
      if bg.0 == r.code {
        in_bg = true
      }
    }
    if in_norm && in_bg {
      return false
    }
  }
  true
}

///|
/// 该 R 编号是否已被归类。
pub fn classified(code : String) -> Bool {
  for n in norms() {
    if n.basis.contains(code) {
      return true
    }
  }
  for bg in background() {
    if bg.0 == code {
      return true
    }
  }
  false
}

///|
/// 推导链（人读）。
pub fn render_derivation(d : Derivation) -> String {
  let lines : Array[String] = ["# 推导链", ""]
  lines.push("触发：\{d.fired.length()} 条规范前提齐备")
  for id in d.fired {
    lines.push("- 触发 \{id}")
  }
  if d.defeated.length() > 0 {
    lines.push("")
    lines.push("## 击败（硬）")
    for x in d.defeated {
      lines.push("- \{x.target} 被 \{x.by} 击败")
    }
  }
  if d.outranked.length() > 0 {
    lines.push("")
    lines.push("## 让位（软）")
    for x in d.outranked {
      lines.push(
        "- \{x.loser}（\{x.loser_verdict.label()}）让位于 \{x.winner}",
      )
    }
  }
  lines.push("")
  lines.push("## 接受")
  for id in d.accepted {
    lines.push("- \{id}")
  }
  lines.push("")
  lines.push("判词：\{d.verdict.label()}")
  lines.push("理由：\{d.note}")
  lines.join("\n")
}
