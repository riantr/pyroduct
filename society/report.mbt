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
/// Mermaid 状态图。
pub fn render_mermaid() -> String {
  let lines = ["stateDiagram-v2"]
  for t in transitions() {
    lines.push(
      "  \{t.from.designation()} --> \{t.to.designation()}: \{t.trigger.label()}",
    )
  }
  lines.join("\n")
}
