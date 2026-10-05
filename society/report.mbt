///|
/// 报告层：把双层次社会交往模型渲染成可读文本。

///|
/// 模型的总报告。
pub fn render_report() -> String {
  let lines = [
    "# 双层次社会交往模型（论文自身的理论构造）",
    "",
    "从《伽达默尔与哈贝马斯真理观比较》（任勇祥，上海社会科学院，2008）提取的集体层面理论。",
    "论文的集体单位是「社会」：骨架为哈贝马斯的「两个层次的社会」——以语言组织的生活世界",
    "（语言层）与以金钱、权力为中介的系统（权力层）；使两层发生关系、并在生活世界内产生",
    "真理的，则是「交往」——以商谈为过滤机制，从有效性主张走向「值得认可的、基于理由的共识」。",
    "伽达默尔以「超主体性」相抗，且否认生活世界可以构造——这构成本模型的固有缺口。",
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
  lines.push("## 主线历程（论文所描述的正路）")
  lines.push("")
  lines.push(course().map(s => s.designation()).join(" → "))
  lines.push("")
  lines.push("## 病理路径（论文所描述的现代病）")
  lines.push("")
  lines.push(ailment().map(s => s.designation()).join(" → "))
  lines.push("")
  lines.push(
    "## 文本依据（章／节／页；页号取自 truth.pdf 正文）",
  )
  for b in basis() {
    lines.push("- \{b.0}：\{b.1}")
  }
  lines.push("")
  lines.push("## 两条不变量")
  lines.push(
    "- 不封闭（论文：商谈理论逃不脱「乌托邦」命运，P.46；真理问题无最终结论，P.53）：",
  )
  lines.push(
    "  模型中无一终态，且「缺口」自任一状态皆可达（`no_final_closure`）。",
  )
  lines.push(
    "- 谬误残余恒正（论文：任何个人的见解中始终都有谬误的残余，P.51）：",
  )
  lines.push("  每一状态的残余都不为零（`State::residue`）。")
  lines.push("")
  lines.push("## 两相的震荡：超体与间性")
  lines.push(
    "**以波粒二象性等量齐观**——超主体性与主体间性不是「正确／错误」「高级／低级」",
  )
  lines.push(
    "的两级，而是如同波粒二象性那样互为不可偏废的两相：同一个交往行为，在不同的",
  )
  lines.push(
    "相位上读出不同的取向。哪个相位当下显影，**由交往行为的结果判定**，不由模型预设。",
  )
  lines.push("")
  lines.push(
    "  表里两相各有自环（延续当前相位），且有**双向**跨态边（换相）：",
  )
  lines.push(
    "- `超体 --提出有效性主张--> 间性`：超体上冒出有效性主张 → 主体间性显影。",
  )
  lines.push(
    "- `间性 --语言在言说我们--> 超体`：主体间性本就是「用语言建立起来的」，",
  )
  lines.push("  语言承担理解即回到超体。")
  lines.push("")
  lines.push(
    "  与 `group` 机「成体」同构（那边用 `提出有效性主张`／`共同语言传统承担理解`），",
  )
  lines.push(
    "但**触发名不必对齐**：两台机各用自己的词汇。结构上仍有一处差别别混——`group`",
  )
  lines.push(
    "  是「一句触发两个去处」故 `Open` 在那台机真会出现；本表是两个不同触发各通一处，",
  )
  lines.push(
    "  触发粒度上确定，`Open` 不可达（`one_edge_per_trigger` 恒真）。",
  )
  lines.push("")
  lines.push("## 与论文的边界")
  lines.push(
    "- 「世界／超体／间性／主张／商谈／辩护／共识／规范／缺口／系统／殖民／扭曲／重建」皆为论文原文所描述的构造。",
  )
  lines.push(
    "- 状态之间的具体连线，以及「缺口处处可达」这类不变量，是对论文叙述的整理（模型化），并非论文逐字列出。",
  )
  lines.join("\n")
}

///|
/// 社会状态的英文标识（图节点 id；中文定名做标签）。mermaid 对非 ASCII 的
/// 节点 id 支持不稳，故一律先声明 `state "定名" as 英文标识` 再连边。
fn repr(s : State) -> String {
  match s {
    World => "World"
    Suprasubjective => "Suprasubjective"
    Intersubjective => "Intersubjective"
    Claim => "Claim"
    Discourse => "Discourse"
    Justification => "Justification"
    Consensus => "Consensus"
    Norm => "Norm"
    Gap => "Gap"
    System => "System"
    Colony => "Colony"
    Distortion => "Distortion"
    Reconstruction => "Reconstruction"
  }
}

///|
/// Mermaid `stateDiagram-v2` 源文本：声明式节点（中文定名做标签、英文标识做
/// id），初始态 `[*] --> 世界`，迁移以触发词做边标。
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
    "    %% 缺口自任一状态皆可达（no_final_closure）；模型无一终态",
  )
  lines.join("\n")
}
