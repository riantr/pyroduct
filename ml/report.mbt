///|
/// 报告层：把设计图、单次估计与重复实验拼成一份可打印的报告。

///|
/// 一次报告的全部超参数。
pub struct MlPlan {
  theta : Double
  single_n : Int
  single : DmlConfig
  rep_n : Int
  reps : Int
  rep : DmlConfig
}

///|
/// 默认计划：单次用高维筛（展示「不交叉拟合」的正则化偏误），
/// 重复用 3 次筛跑覆盖率。
pub fn default_ml_plan() -> MlPlan {
  MlPlan::{
    theta: 1.5,
    single_n: 200,
    single: DmlConfig::{ degree: 4, lambda: 0.02, folds: 5, seed: 12345, },
    rep_n: 400,
    reps: 40,
    rep: DmlConfig::{ degree: 3, lambda: 0.02, folds: 5, seed: 20260920, },
  }
}

///|
/// 报告文本。
pub fn render_ml_report(plan : MlPlan) -> String {
  let lines : Array[String] = []
  lines.push("# DoubleML × 主体状态机")
  lines.push("")
  lines.push(render_ml_design())
  lines.push("")
  lines.push("## 实验：练习对自由度的因果效应")
  lines.push("")
  lines.push(
    "真值 θ = \{fmt(plan.theta, 2)}。数据由状态机生成：协变量取自状态的自由刻度 /",
  )
  lines.push(
    "阶段 / 出度 / 到宁静的距离，处置强度含一项来自随机游走的练习计数。",
  )
  lines.push("")
  lines.push(
    "### 单次估计（n = \{plan.single_n}，多项式筛 \{plan.single.degree} 次）",
  )
  lines.push("")
  lines.push("估计量 | θ̂ | 标准误 | 95% 置信区间 | 偏误")
  lines.push("---|---|---|---|---")
  for r in single_run(plan.single_n, plan.theta, plan.single) {
    lines.push(
      "\{r.name} | \{fmt(r.theta, 3)} | \{fmt(r.se, 3)} | [\{fmt(r.ci_low, 3)}, \{fmt(r.ci_high, 3)}] | \{fmt(r.bias, 3)}",
    )
  }
  lines.push("")
  lines.push(
    "### 重复 \{plan.reps} 次（n = \{plan.rep_n}，多项式筛 \{plan.rep.degree} 次，\{plan.rep.folds} 折）",
  )
  lines.push("")
  lines.push("估计量 | 平均偏误 | RMSE | 95% 区间覆盖率")
  lines.push("---|---|---|---")
  for s in replicate(plan.reps, plan.rep_n, plan.theta, plan.rep) {
    lines.push(
      "\{s.name} | \{fmt(s.mean_bias, 3)} | \{fmt(s.rmse, 3)} | \{fmt(s.coverage, 3)}",
    )
  }
  lines.push("")
  lines.push(
    "覆盖率的名义值是 0.95。朴素回归与线性调整**即使样本很大也不相合**：前者完全不调整，",
  )
  lines.push(
    "后者把非线性的 g(X) 当成了线性；单向残差化只处理了一边，混淆从 T 里漏了回来。",
  )
  lines.push(
    "只有两边都残差化、且分数 Neyman 正交的 DoubleML 把 θ 还原出来。这里的覆盖率略低于",
  )
  lines.push(
    "名义值，是有限样本效应：nuisance 用了 35 维筛，一阶方差公式忽略了 O(p/n) 的膨胀",
  )
  lines.push(
    "（n 越大越接近 0.95）；交叉拟合在 nuisance 高维、易过拟合的场合才会成为关键一环。",
  )
  lines.join("\n")
}

///|
/// CSV 前若干行（供 CLI 展示，或导出给 Python 的 DoubleML / EconML 复核）。
pub fn csv_preview(data : Dataset, rows : Int) -> String {
  let all = export_csv(data).split("\n").collect()
  let out : Array[String] = []
  let mut i = 0
  while i < all.length() && i <= rows {
    out.push(all[i].to_owned())
    i += 1
  }
  out.join("\n")
}
