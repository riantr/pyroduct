///|
/// 报告层：把五个机制逐个演示一遍。

///|
/// 变异空间一览（按位点分组）。
pub fn render_variation() -> String {
  let g = default_agent()
  let ms = mutations(g)
  let lines : Array[String] = []
  for locus in [Prompt, Strategy, Memory, Code] {
    lines.push("### \{locus.label()}")
    for c in ms {
      if c.locus == locus {
        lines.push("- \{c.what}")
      }
    }
  }
  lines.push("")
  lines.push(
    "共 \{ms.length()} 个单步候选，每个只改一处；其中违宪者会被闸门拦下（见下）。",
  )
  lines.join("\n")
}

///|
/// 适应度目标对照：同一世界、同一祖先，只换目标函数。
pub fn render_objectives() -> String {
  let world = default_world()
  let lines : Array[String] = [
    "目标 | 权重(共识,稳定,残余,代价) | 种子得分 | 进化后得分 | 进化后配置",
    "---|---|---|---|---",
  ]
  for o in [truth_objective(), thrifty_objective()] {
    let seed_score = score(evaluate(default_agent(), world), o)
    let ledger = evolve(default_agent(), world, Weighted(o), 4)
    let g = ledger.current()
    let final_score = score(evaluate(g, world), o)
    lines.push(
      "\{o.name} | (\{o.w_consensus},\{o.w_stability},\{o.w_residue},\{o.w_cost}) | \{seed_score} | \{final_score} | 发言=\{g.voice.label()} 体制=\{g.regime.label()} 两诚=(\{g.toward_other},\{g.toward_self}) 残余=\{g.carry} 理性=\{g.reason}",
    )
  }
  lines.join("\n")
}

///|
/// 账本：接收了哪些改动、被宪法拦下了什么。
pub fn render_ledger(ledger : Ledger) -> String {
  let lines : Array[String] = [
    "共 \{ledger.trails.length()} 条记录：接收 \{ledger.accepted_count()}，违宪拒收 \{ledger.rejected_count()}",
  ]
  for t in ledger.trails {
    if t.verdict == Accepted {
      lines.push(
        "- 第\{t.generation + 1}代 · \{t.locus.label()} · \{t.what}　→　\{t.why}",
      )
    }
  }
  match ledger.rejected_example() {
    Some(e) => {
      lines.push("")
      lines.push("被宪法拦下的一例：\{e}")
    }
    None => ()
  }
  lines.join("\n")
}

///|
/// 总报告。
pub fn render_report() -> String {
  let world = default_world()
  let ledger = evolve(default_agent(), world, Weighted(truth_objective()), 4)
  let text = ledger.serialize()
  let back = parse(text)
  let head = text.split("\n").collect()
  let round_ok = if back.serialize() == text { "一致" } else { "不一致" }
  let cur_ok = if back.current() == ledger.current() {
    "相同"
  } else {
    "不同"
  }
  let lines : Array[String] = [
    "# 进化：五个机制",
    "",
    "`src`／`multi`／`group`／`society` 说的是「主体如何移动」；本包说的是这些移动如何被",
    "改写、裁决、保留与传下去。五件事各由一处承担，且都可被 `moon test` 检验。",
    "",
    "## 一、变异空间（可枚举的候选改动）",
    "",
    "位点分四类：提示／策略／记忆／代码；每一步只动一处。",
    "",
    render_variation(),
    "",
    "## 二、适应度目标（「更好」由谁定义）",
    "",
    "「更好」不是假定，而是写下来的权重——换目标函数就可能换出不同的基因组。",
    "",
    render_objectives(),
    "",
    "## 三、因果判据（用 DoubleML 代替手写权重）",
    "",
    "把「是否采纳候选」当处置 T、把遭遇成效当结果 Y、把上下文当协变量 X。采纳是**自选**的",
    "（形势好才肯改），于是朴素比较会把「形势好」记到「改动好」账上；DoubleML 把 X 两边",
    "残差化，才把 θ 还原。闸门随之改为：只有 θ̂>0 且 95% 置信下界>0 才接收——下面四个候选",
    "里，有一个朴素说是正的、DoubleML 说是负的。",
    "",
    render_causal(),
    "",
    "## 四、更新闸门（应用 → 检查 → 回滚）",
    "",
    "宪法级条款（不可被变异触碰）：",
  ]
  for c in constitution() {
    lines.push("- \{c.0}：\{c.1}")
  }
  lines.push("")
  lines.push(render_ledger(ledger))
  lines.push("")
  lines.push("## 五、持久化（写下、读回、接着跑）")
  lines.push("")
  lines.push("账本序列化（前 4 行）：")
  for i = 0; i < 4 && i < head.length(); i = i + 1 {
    lines.push("    \{head[i]}")
  }
  lines.push("")
  lines.push(
    "往返校验：序列化 \{round_ok}；读回后的当前基因组与原账本 \{cur_ok}。",
  )
  lines.push("")
  lines.push("## 六、遗传")
  lines.push("")
  lines.push("- 子代 = 父代 + 一处改动（`descend`）；")
  lines.push(
    "- **宪法不在 `Genome` 里**，所以没有任何变异能触到它，每个后代都原样继承；",
  )
  lines.push(
    "- 每条改动连同理由写进账本（`Trail.why`），所以「为什么变成这样」也一起传下去。",
  )
  lines.join("\n")
}

///|
/// 因果判据：四个「体制改动」候选的朴素估计 vs DoubleML（含真值与闸门判词）。
pub fn render_causal() -> String {
  let world = default_world()
  let g = default_agent()
  let cfg = @ml.default_dml_config()
  let lines : Array[String] = [
    "候选（体制改动） | 朴素估计 | DoubleML θ̂ | 95% CI | 真值 | 因果闸门",
    "---|---|---|---|---|---",
  ]
  for c in mutations(g) {
    if c.locus == Strategy && c.what.contains("体制：") {
      let v = causal_effect(g, c.genome, world, 400, cfg)
      lines.push(causal_row(c.what, v))
    }
  }
  lines.join("\n")
}

///|
/// 一行因果对照。
fn causal_row(name : String, v : CausalVerdict) -> String {
  let verdict = if v.theta > 0.0 && v.ci_low > 0.0 {
    "接收"
  } else {
    "回滚"
  }
  "\{name} | \{show_pm(permille(v.naive))} | \{show_pm(permille(v.theta))} | [\{show_pm(permille(v.ci_low))}, \{show_pm(permille(v.ci_high))}] | \{show_pm(permille(v.truth))} | \{verdict}"
}
