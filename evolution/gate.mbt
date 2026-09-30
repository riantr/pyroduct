///|
/// 更新闸门：**应用 → 检查 → 回归就回滚**。
///
/// 检查分两层：
///
///   - **宪法级**（`constitution_violations`）：不可被变异触碰的不变量。任何候选一旦
///     违反，一律拒收，不论分数多高——这是「有些东西不允许进化掉」的落点。
///   - **选择级**（`judge` 按 `Criterion` 裁决）：要么比手写权重（`Weighted`），要么比
///     **因果效应**（`Causal`）——后者用 DoubleML 估计「采纳这个改动」的效应，只有
///     θ̂>0 且 95% 置信下界>0 才接收。两者的共同点：退步就回滚（先应用，再检查，
///     变差就还原——对应本环境里 `revert_when_errors_above` 的思路）。

///|
/// 宪法级不变量（条款 → 说明）。
pub fn constitution() -> Array[(String, String)] {
  [
    ("R10", "谬误残余恒 ≥1：不许把不确定性进化掉。"),
    (
      "R2／R14", "不得以「宣告」把结论说成终局：共识只能作建议。",
    ),
    (
      "R3", "必须仍向对方敞开：他之诚 > 0，「隐」才有处可出。",
    ),
  ]
}

///|
/// 一个基因组违反的条款（空数组＝合宪）。
pub fn constitution_violations(g : Genome) -> Array[String] {
  let out : Array[String] = []
  if g.carry < 1 {
    out.push("违反 R10：残余 = \{g.carry} < 1")
  }
  if g.voice == Declarative {
    out.push("违反 R2／R14：以「宣告」把结论说成终局")
  }
  if g.toward_other <= 0 {
    out.push(
      "违反 R3：他之诚 = \{g.toward_other}，不再向对方敞开",
    )
  }
  out
}

///|
/// 是否合宪。
pub fn constitutional(g : Genome) -> Bool {
  constitution_violations(g).length() == 0
}

///|
/// 闸门的判词。
pub(all) enum Judgement {
  Accepted // 接收
  RejectedConstitutional // 拒收（违宪）
  RevertedRegression // 回滚（退步）
  Tie // 持平
} derive(Eq)

///|
pub extend Judgement with Eq::{not_equal, equal}

///|
/// 判词名。
pub fn Judgement::label(self : Judgement) -> String {
  match self {
    Accepted => "接收"
    RejectedConstitutional => "拒收（违宪）"
    RevertedRegression => "回滚（退步）"
    Tie => "持平"
  }
}

///|
/// 因果判据的计划：回合数 + DML 配置（`objective` 仅用于报表里的四分量对照）。
pub struct CausalPlan {
  objective : Objective
  episodes : Int
  config : @ml.DmlConfig
}

///|
/// 判据：用哪一种「更好」。
pub(all) enum Criterion {
  Weighted(Objective) // 手写权重
  Causal(CausalPlan) // 因果效应
}

///|
/// 闸门的完整裁决：判词、理由、适应度、加权分数，以及（因果判据下的）效应估计。
pub struct Decision {
  verdict : Judgement
  reason : String
  fitness : Fitness
  score : Int // 加权得分（始终计算，供报表对照）
  effect : Int // θ̂ 的千分位；因果判据时用它做决定（否则 0）
  effect_lo : Int // 95% 置信下界的千分位
}

///|
/// 裁决一个候选改动：先查宪法，再按判据决定。
///
/// - `Weighted`：与父代比加权得分，退步即回滚；
/// - `Causal`：估计「采纳该改动」的因果效应，只有 θ̂>0 且置信下界>0 才接收。
pub fn judge(
  parent : Genome,
  parent_score : Int,
  c : Candidate,
  world : Array[Opponent],
  criterion : Criterion,
) -> Decision {
  let fitness = evaluate(c.genome, world)
  let (objective, causal) : (Objective, CausalPlan?) = match criterion {
    Weighted(o) => (o, None)
    Causal(p) => (p.objective, Some(p))
  }
  let s = score(fitness, objective)
  let violations = constitution_violations(c.genome)
  if violations.length() > 0 {
    return {
      verdict: RejectedConstitutional,
      reason: violations.join("；"),
      fitness,
      score: s,
      effect: 0,
      effect_lo: 0,
    }
  }
  match causal {
    Some(plan) => {
      let v = causal_effect(parent, c.genome, world, plan.episodes, plan.config)
      let effect = permille(v.theta)
      let lo = permille(v.ci_low)
      let ok = v.theta > 0.0 && v.ci_low > 0.0
      {
        verdict: if ok {
          Accepted
        } else {
          RevertedRegression
        },
        reason: "因果 θ̂=\{show_pm(effect)} 95%CI=[\{show_pm(lo)},\{show_pm(permille(v.ci_high))}]（朴素 \{show_pm(permille(v.naive))}，真值 \{show_pm(permille(v.truth))}）",
        fitness,
        score: s,
        effect,
        effect_lo: lo,
      }
    }
    None =>
      if s > parent_score {
        {
          verdict: Accepted,
          reason: "得分 \{parent_score} → \{s}",
          fitness,
          score: s,
          effect: 0,
          effect_lo: 0,
        }
      } else if s == parent_score {
        {
          verdict: Tie,
          reason: "得分持平 \{s}",
          fitness,
          score: s,
          effect: 0,
          effect_lo: 0,
        }
      } else {
        {
          verdict: RevertedRegression,
          reason: "回滚：得分 \{parent_score} → \{s}",
          fitness,
          score: s,
          effect: 0,
          effect_lo: 0,
        }
      }
  }
}
