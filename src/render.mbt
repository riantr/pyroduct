///|
/// 渲染层：把状态机导出成文字报告、Mermaid 状态图与 Graphviz DOT。

///|
/// 把阐释性的自由刻度渲染成带正负号的字符串。
pub fn freedom_text(f : Int) -> String {
  if f >= 0 {
    "+\{f}"
  } else {
    "\{f}"
  }
}

///|
/// 从立位到宁静的一条主线（原文顺序，不含自环与并列分支），以通用定名书写。
/// 可重入的环节序列见 `render_course`。
pub fn render_genesis() -> String {
  genesis_path().map(s => s.designation()).join(" → ")
}

///|
/// 人可读的文字报告：按阶段列出状态，并给出主线历程。
pub fn render_report() -> String {
  let lines : Array[String] = []
  lines.push(
    "# 《通往宁静之路：个体道德发生论纲要》· 主体状态机",
  )
  lines.push("")
  lines.push(
    "初始状态：\{initial().qualified()}　静定极：\{terminal().qualified()}",
  )
  lines.push(
    "状态 \{all_states().length()} 个 · 迁移 \{transitions().length()} 条 · 阶段 \{all_phases().length()} 个",
  )
  lines.push(
    "退化起点：无忆（失忆）、无筹（浑噩）——只出不进：各有一条出边汇入立位，从立位不可达。这是设计：起点是抛入的境况，不是历程的一站；机器不编造进入它们的边。",
  )
  lines.push("")
  for p in all_phases() {
    lines.push("## \{p.qualified()}")
    for s in all_states() {
      if s.phase() == p {
        lines.push(
          "- \{s.designation()}　[自由 \{freedom_text(s.freedom())}]　\{s.gloss()}",
        )
      }
    }
    lines.push("")
  }
  lines.push("## 历程（可重入的环节序列）")
  lines.push("")
  lines.push(render_course())
  lines.push("")
  lines.push("## 主线（原文顺序）")
  lines.push("")
  lines.push(render_genesis())
  lines.push("")
  lines.push(
    "## 驱动槽（\{all_triggers().length()} 个触发 · \{all_slots().length()} 个槽）",
  )
  lines.push("")
  lines.push(render_slot_tally())
  lines.push("")
  let combos = all_states().length() * all_slots().length()
  lines.push(
    "执行契约：位置 × 槽共 \{combos} 个组合，其中 \{gaps().length()} 组无路可走——无路是合法回执，机器不编造下一步。逐条归位见 `slots`，缺口分布与示范见 `loop`。",
  )
  lines.push("")
  lines.push("## 派生表与持久度")
  lines.push("")
  for entry in durability_manifest() {
    lines.push("- \{entry.0}　消费 \{entry.1}　〔\{entry.2}〕")
  }
  lines.join("\n")
}

///|
/// Mermaid `stateDiagram-v2` 源文本，可直接粘进支持 Mermaid 的编辑器。
pub fn render_mermaid() -> String {
  let lines : Array[String] = ["stateDiagram-v2"]
  for s in all_states() {
    lines.push("    state \"\{s.qualified()}\" as \{Repr(s)}")
  }
  lines.push("    [*] --> \{Repr(initial())}")
  lines.push("    [*] --> \{Repr(NoPast)}")
  lines.push("    [*] --> \{Repr(NoFuture)}")
  for t in transitions() {
    lines.push("    \{Repr(t.from)} --> \{Repr(t.to)} : \{t.trigger.label()}")
  }
  lines.push(
    "    %% \{terminal().qualified()} 是静定极；界域重开时经 ReopenByHorizon 重入反顾",
  )
  lines.join("\n")
}

///|
/// Graphviz DOT 源文本；节点用中文状态名，边标注触发。
pub fn render_dot() -> String {
  let lines : Array[String] = [
    "digraph subject_state_machine {", "  rankdir=LR;", "  node [shape=box];", "  edge [fontsize=10];",
  ]
  for s in all_states() {
    lines.push(
      "  \"\{s.designation()}\" [label=\"\{s.designation()}\\n[\{s.phase().designation()}]\"];",
    )
  }
  for t in transitions() {
    lines.push(
      "  \"\{t.from.designation()}\" -> \"\{t.to.designation()}\" [label=\"\{t.trigger.label()}\"];",
    )
  }
  lines.push("}")
  lines.join("\n")
}
