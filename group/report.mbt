///|
/// 报告层：群体状态机的渲染与涌现演示。

///|
/// 场景演示用的成员构造（借 multi 层）。
fn person(
  id : Int,
  regime : @multi.TruthRegime,
  other : Int,
  inward : Int,
  state : @sm.SubjectState,
) -> @multi.Subject {
  @multi.subject(id, state, regime, other, inward, 9)
}

///|
/// 涌现演示：几组成员配置 → 群体状态。
pub fn emergence_table() -> Array[(String, GroupState)] {
  let here = @sm.Encounter
  [
    (
      "两个内在秩序者（埃及式：不必寻求）",
      emerge([
        person(1, @multi.Immanent, 70, 70, here),
        person(2, @multi.Immanent, 70, 70, here),
      ]),
    ),
    (
      "两个超主体性者",
      emerge([
        person(1, @multi.SuperSubjective, 70, 70, here),
        person(2, @multi.SuperSubjective, 70, 70, here),
      ]),
    ),
    (
      "两个主体间性者",
      emerge([
        person(1, @multi.InterSubjective, 70, 70, here),
        person(2, @multi.InterSubjective, 70, 70, here),
      ]),
    ),
    (
      "超主体性 × 主体间性（体制相左）",
      emerge([
        person(1, @multi.SuperSubjective, 70, 70, here),
        person(2, @multi.InterSubjective, 70, 70, here),
      ]),
    ),
    (
      "三人的主体间网络",
      emerge([
        person(1, @multi.InterSubjective, 70, 70, here),
        person(2, @multi.InterSubjective, 70, 70, here),
        person(3, @multi.InterSubjective, 70, 70, here),
      ]),
    ),
    (
      "诚然三人，双诚俱足",
      emerge([
        person(1, @multi.ChengRan, 80, 80, @sm.Tranquility),
        person(2, @multi.ChengRan, 85, 85, @sm.Tranquility),
        person(3, @multi.ChengRan, 75, 90, @sm.Tranquility),
      ]),
    ),
    (
      "有人已在主体层投射",
      emerge([
        person(1, @multi.InterSubjective, 70, 70, here),
        person(2, @multi.InterSubjective, 70, 70, @sm.Idol),
      ]),
    ),
    (
      "有人已自缚",
      emerge([
        person(1, @multi.InterSubjective, 70, 70, here),
        person(2, @multi.InterSubjective, 70, 70, @sm.Binding),
      ]),
    ),
    (
      "有人已在痛苦",
      emerge([
        person(1, @multi.InterSubjective, 70, 70, here),
        person(2, @multi.InterSubjective, 70, 70, @sm.Suffering),
      ]),
    ),
  ]
}

///|
/// 涌现演示表。
pub fn render_emergence() -> String {
  let lines = [
    "成员配置 | 涌现出的群体状态 | 阶段", "---|---|---",
  ]
  for e in emergence_table() {
    let (name, st) = e
    lines.push("\{name} | \{st.designation()} | \{st.phase().label()}")
  }
  lines.join("\n")
}

///|
/// 群体状态机总报告。
pub fn render_group_report() -> String {
  let lines = [
    "# 群体状态机（模型延伸：群体重演主体节奏）",
    "",
    "　工作区另有**从论文原文提取**的「双层次社会交往模型」（生活世界／系统／交往），见 `society` 包：",
    "　`moon run cmd/main -- society`。",
    "单位从「一个主体」换成「一个群体」：一群主体因彼此的遭遇（multi 包的 R1–R12）",
    "而聚成有自身状态的群体，并在群体尺度上重演同一段节奏。规则不变，尺度改变。",
    "",
    "状态 \{all_states().length()} 个 · 迁移 \{transitions().length()} 条 · 阶段 \{all_phases().length()} 个",
    "",
  ]
  for p in all_phases() {
    lines.push("## \{p.label()}")
    for s in all_states() {
      if s.phase() == p {
        lines.push("- \{s.designation()}　\{s.gloss()}")
      }
    }
    lines.push("")
  }
  lines.push("## 主线历程")
  lines.push("")
  lines.push(course().map(s => s.designation()).join(" → "))
  lines.push("")
  lines.push("## 涌现：成员 → 群体")
  lines.push(render_emergence())
  lines.push("")
  lines.push("## 文本依据（章／节／页）")
  for b in textual_basis() {
    lines.push("- \{b.0}：\{b.1}")
  }
  lines.push("")
  lines.push("## 两条不变量")
  lines.push(
    "- R2／R11「不独断、不可闭合」：只有「投射」与「独白」两种病态状态假装封口",
  )
  lines.push(
    "  （`claims_closure`），「宁定」不在此列，且 `宁定 --Reenter--> 复归` 恒在。",
  )
  lines.push(
    "- R10「谬误残余」：任何成员、任何群体的残余都不为零（`is_well_formed`）。",
  )
  lines.push("")
  lines.push(
    "## 另见（论文自身的理论构造：双层次社会交往模型）",
  )
  lines.push(
    "- `society` 包：双层次社会交往模型——生活世界／系统／交往（《伽达默尔与哈贝马斯真理观比较》自身的构造）。",
  )
  lines.join("\n")
}

///|
/// 群体状态的英文标识（图节点 id；中文定名做标签）。mermaid 对非 ASCII 的
/// 节点 id 支持不稳，故先声明 `state "定名" as 英文标识` 再连边。
fn repr(s : GroupState) -> String {
  match s {
    Scattered => "Scattered"
    Converging => "Converging"
    CommonTongue => "CommonTongue"
    Discourse => "Discourse"
    Normed => "Normed"
    Consensus => "Consensus"
    Dissensus => "Dissensus"
    Confronting => "Confronting"
    Partitioned => "Partitioned"
    Projected => "Projected"
    Monologic => "Monologic"
    Disciplined => "Disciplined"
    Concealed => "Concealed"
    Wounded => "Wounded"
    Dispersed => "Dispersed"
    Returning => "Returning"
    Practicing => "Practicing"
    Widening => "Widening"
    Attuned => "Attuned"
    Settled => "Settled"
  }
}

///|
/// Mermaid `stateDiagram-v2` 源文本：群体机（20 状态 · 42 迁移 · 9 阶段）。
/// 初始态 `[*] --> 散在`；宁定是静定极而非终点（R11 不可闭合）。
pub fn render_mermaid() -> String {
  let lines : Array[String] = ["stateDiagram-v2"]
  for s in all_states() {
    lines.push("    state \"\{s.designation()}\" as \{repr(s)}")
  }
  lines.push("    [*] --> \{repr(initial())}")
  for t in transitions() {
    lines.push("    \{repr(t.from)} --> \{repr(t.to)} : \{t.trigger.label()}")
  }
  lines.push(
    "    %% 宁定 是静定极而非终点：宁定 --Reenter--> 复归 恒在（R11 不可闭合）",
  )
  lines.join("\n")
}
