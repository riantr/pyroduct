///|
/// 闸门审计：**相信重裁出来的判词，而不是相信记下来的判词。**
///
/// 账本记的是「当时裁了什么」，但**没有记「当时用哪把尺子裁的」**——而尺子会动：
/// 手写权重可以改，DoubleML 那一档的样本量与**种子**也可以改；种子一变，数据就变了，
/// 尺子也就变了，而账本看上去还是老样子。两本账可以在同一句话下用不同的尺子裁出
/// 不同的判词，而行数、字段、树形全都不变。
///
/// 所以这里做三件事：
///
///   1. **指纹**：每一行带着它被裁时那把尺子的指纹（`gate_fingerprint`）。指纹是可读的
///      参数字符串而不是哈希——审计的人要能一眼看出「换的是种子还是权重」。
///   2. **重裁**：审计时拿账本里封好的输入（父代基因组、父代得分、候选基因组）**重新
///      裁一遍**，逐行与记下来的判词比对。父代得分不存——它是父代基因组与世界的一个
///      纯函数，可以重算。
///   3. **失败闭合**：尺子动过、判词对不上、或者行里根本没记尺子——都算**失败**。
///      「没看见」不等于「没问题」。
///
/// 这条纪律是别处付过代价换来的：那个闸门才是产品，而一个**数据依赖**的闸门
/// （这里是 DoubleML 那一档）如果不把尺子钉住，两次裁决可以各用一把尺子，而账本
/// 看起来一模一样。

///|
/// 闸门的指纹：这条判词是按哪把尺子裁出来的。
///
/// 手写权重那一档，尺子就是四个权重；因果那一档，尺子是「回合数 + DML 配置」，
/// 其中**种子**决定了合成数据——所以种子也是尺子的一部分。
pub fn gate_fingerprint(criterion : Criterion) -> String {
  match criterion {
    Weighted(o) =>
      "W|\{o.name}|\{o.w_consensus}|\{o.w_stability}|\{o.w_residue}|\{o.w_cost}"
    Causal(p) =>
      "C|\{p.objective.name}|\{p.episodes}|\{p.config.degree}|\{p.config.lambda}|\{p.config.folds}|\{p.config.seed}"
  }
}

///|
/// 判据里的目标（两档都有，只是因果那档藏在计划里）。
pub fn criterion_objective(criterion : Criterion) -> Objective {
  match criterion {
    Weighted(o) => o
    Causal(p) => p.objective
  }
}

///|
/// 闸门审计的结果。
///
/// `checked` 是被重裁的行数；`agreed` 是重裁后判词与账本一致的行数；`disagreed`
/// 是不一致的行数；`moved_bar` 是**记下的尺子与本次尺子不同**的行数；`unbarred` 是
/// 压根没记尺子的行数。后三者只要有一个不为零，审计就不通过。
pub struct GateAudit {
  checked : Int32
  agreed : Int32
  disagreed : Int32
  moved_bar : Int32
  unbarred : Int32
  faults : Array[String]
}

///|
/// 审计是否通过：四道门都要干净。
pub fn GateAudit::ok(self : GateAudit) -> Bool {
  self.disagreed == 0 && self.moved_bar == 0 && self.unbarred == 0
}

///|
/// 一行判词：第几代第几个候选、父代是谁、改了哪里、判了什么。
fn trail_line(t : Trail, i : Int32) -> String {
  let parent = match t.parent {
    Some(p) => "\{p}"
    None => "种子"
  }
  "第\{t.generation}代第\{t.step}个候选（账本第\{i}行，父=\{parent}，改\{locus_code(t.locus)}）"
}

///|
/// 重放闸门：拿账本里封好的输入重新裁一遍，逐行与记下来的判词比对。
///
/// 三件事都做：**重裁**（判词对不对得上）、**比尺子**（当时那把尺子是不是现在这把）、
/// **失败闭合**（缺输入算失败，不算通过）。父代基因组从账本的树里取，父代得分由
/// 父代基因组与世界重算——它不是一个需要信任的存量数字。
pub fn replay_gate(
  ledger : Ledger,
  world : Array[Opponent],
  criterion : Criterion,
) -> GateAudit {
  let objective = criterion_objective(criterion)
  let bar = gate_fingerprint(criterion)
  let mut checked = 0
  let mut agreed = 0
  let mut disagreed = 0
  let mut moved = 0
  let mut unbarred = 0
  let faults : Array[String] = []
  for i = 0; i < ledger.trails.length(); i = i + 1 {
    let t = ledger.trails[i]
    checked += 1
    // 尺子。
    if t.gate.length() == 0 {
      unbarred += 1
      faults.push(
        "尺子未记：\{trail_line(t, i)} 没有记下它被裁时用的尺子——无法认证",
      )
    } else if t.gate != bar {
      moved += 1
      faults.push(
        "尺子已动：\{trail_line(t, i)} 记的是「\{t.gate}」，现在这把是「\{bar}」",
      )
    }
    // 父代：账本里的下标必须指向**已经存在**的一行（遗传不许指向前方）。
    let parent_genome = match t.parent {
      None => ledger.seed
      Some(p) =>
        if p < 0 || p >= i || p >= ledger.trails.length() {
          faults.push(
            "父代不可解析：\{trail_line(t, i)} 的父下标 \{p} 不是一条已存在的记录",
          )
          ledger.seed
        } else {
          ledger.trails[p].genome
        }
    }
    let parent_score = score(evaluate(parent_genome, world), objective)
    let candidate : Candidate = {
      locus: t.locus,
      what: t.what,
      genome: t.genome,
    }
    let again = judge(parent_genome, parent_score, candidate, world, criterion)
    if again.verdict == t.verdict {
      agreed += 1
    } else {
      disagreed += 1
      faults.push(
        "判词对不上：\{trail_line(t, i)} 记的是「\{t.verdict.label()}」，重裁是「\{again.verdict.label()}」",
      )
    }
  }
  { checked, agreed, disagreed, moved_bar: moved, unbarred, faults, }
}

///|
/// 审计报告（人读）。
pub fn render_gate_audit(a : GateAudit) -> String {
  let lines : Array[String] = ["# 闸门审计：重裁 vs 账本", ""]
  lines.push("被重裁的行数：\{a.checked}")
  lines.push("判词一致：\{a.agreed}")
  lines.push("判词不一致：\{a.disagreed}")
  lines.push("尺子已动：\{a.moved_bar}")
  lines.push("尺子未记：\{a.unbarred}")
  lines.push(if a.ok() { "结论：通过" } else { "结论：不通过" })
  if a.faults.length() > 0 {
    lines.push("")
    lines.push("## 不通过之处")
    for f in a.faults {
      lines.push("- \{f}")
    }
  }
  lines.join("\n")
}

///|
/// 审计一句话版本（供闸门自检与报告使用）。
pub fn audit_summary(a : GateAudit) -> String {
  if a.ok() {
    "闸门审计通过：\{a.checked} 行全部重裁一致，尺子未动"
  } else {
    "闸门审计不通过：判词不一致 \{a.disagreed} 行，尺子已动 \{a.moved_bar} 行，尺子未记 \{a.unbarred} 行"
  }
}
