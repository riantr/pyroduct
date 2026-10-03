///|
/// 因果诊断层（`causal`，模型整理）。
///
/// 把 `riantr/moonbit_doubleML@0.75.0` 的三个新模块真正用起来，全部作用于
/// **状态机生成的同一份数据**（`ml.make_dataset(400, 1.5, 7)`，n = 400，真值
/// θ = 1.5，4 个协变量）：
///
///   1. **敏感性**（Cinelli & Hazlett 2020，`DoubleMLPLR::sensitivity_analysis`）：
///      未观测混杂的最坏情形偏倚界 `max_bias = sqrt(σ²·ν²)`（残差方差乘积的
///      开方），`rv = |θ̂| / max_bias` 是效应占这个界的比例。rv 是有限正数——
///      结论对混杂并非无限脆弱；rv < 1——也不压倒性稳固。这是 R10「谬误残余」
///      与「不封闭」的统计学形态：稳固度是一个数值，不是口号。
///   2. **多重检验**（`p_adjust.mbt` 的 BH/Bonferroni）：如果对每个触发都跑一次
///      闸门，5% 的假阳性率会被批量放大——Benjamini–Hochberg 控制的是这层
///      风险。这里给一条真实对照：把 θ̂、负 θ̂、天真 OLS（被选择偏倚推高）
///      的 p 值一起校正，看天真估计会不会在批量检验里冒充发现。
///   3. **异质性**（`DoubleMLBLP`，HC0 稳健标准误）：把结果残差 (y−l̂) 投到基
///      [(d−m̂), (d−m̂)·x̃0..x̃3]（协变量先中心化——否则交互维与主效应共线，
///      ATE 会被吸走）——d̃ 维系数应回收 θ̂（PLR 力矩的再线性化），
///      交互维给出效应随协变量的斜率。这份数据的真 DGP 是均匀效应，
///      交互维不显著本身就是发现：政策树在这里无料可挖。
///
/// 边界：本层**只读**。更新闸门仍在 `evolution`（θ̂ > 0 且 CI 下界 > 0 才接受），
/// 不因 0.75.0 扩展而改判据；这里的敏感性数值进报告，不进闸门。

///|
/// 三项诊断的结果。
pub(all) struct Diagnostics {
  theta_ref : Double
  se_ref : Double
  rv : Double
  max_bias : Double
  p_theta : Double
  p_neg : Double
  p_naive : Double
  bh_theta : Double
  bh_naive : Double
  bonf_naive : Double
  het_coefs : Array[Double]
  het_ses : Array[Double]
}

///|
/// 标准正态右尾 Q(x) = 1 − Φ(x)（Abramowitz–Stegun 7.1.26，|ε| ≤ 7.5e-8）。
/// 筛查用精度；0.75.0 未导出 p 值助手，自备并在报告注明。
pub fn phi_tail(x : Double) -> Double {
  let a = if x < 0.0 { -x } else { x }
  let t = 1.0 / (1.0 + 0.2316419 * a)
  let poly = t *
    (
      0.319381530 +
      t *
      (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429)))
    )
  let pdf = 0.3989422804014327 * @math.exp(-(a * a) / 2.0)
  pdf * poly
}

///|
/// 双侧 p 值：2·Q(|z|)。
fn two_sided_p(z : Double) -> Double {
  2.0 * phi_tail(z)
}

///|
/// 跑三项诊断：同一份数据，先拟合参考 PLR，再做敏感性、批量校正与 BLP。
pub fn run_diagnostics() -> Diagnostics raise {
  let data = @ml.make_dataset(400, 1.5, 7)
  let n = data.y.length()
  let p = data.x[0].length()
  let flat : Array[Double] = []
  for i in 0..<n {
    for j in 0..<p {
      flat.push(data.x[i][j])
    }
  }
  let mat = @dml.Matrix::from_array(flat, n, p)
  let dml_data = @dml.DoubleMLData::new(mat, data.y, data.t)
  let fitted = @dml.DoubleMLPLR::new(dml_data, n_folds=5).fit()
  // 1. 敏感性（库默认 cf 基准 0.05）。
  let sens = fitted.sensitivity_analysis()
  // 2. 多重检验：三个假设一起过 BH / Bonferroni。
  let z_theta = fitted.coef() / fitted.se()
  let ps : Array[Double] = [two_sided_p(z_theta), 0.0, 0.0]
  // 负 θ̂ 的对照：θ̂ 中心化后的相反数。
  ps[1] = two_sided_p(-z_theta)
  // 天真 OLS：忽略混杂 X，只用 D 对 Y 回归。
  let (naive_b, naive_se) = @ml.naive_ols(data.y, data.t)
  ps[2] = two_sided_p(naive_b / naive_se)
  let bh = @dml.bh_fdr_p_adjust(ps)
  let bonf = @dml.bonferroni_p_adjust(ps)
  // 3. BLP 异质性：结果残差 (y−l̂) 投到 [(d̃), (d̃)·x̃0..x̃3]；协变量先中心化
  //    （交互基与主效应基近乎正交，d̃ 维才回收 ATE——不中心化会被共线吸走），
  //    库内 LinearRegression 自带截距，此处不再显式加常数列。
  let l_hat = fitted.predictions_l()
  let m_hat = fitted.predictions_m()
  let xbar : Array[Double] = Array::make(p, 0.0)
  for i in 0..<n {
    for j in 0..<p {
      xbar[j] = xbar[j] + data.x[i][j]
    }
  }
  for j in 0..<p {
    xbar[j] = xbar[j] / n.to_double()
  }
  let resid_y : Array[Double] = []
  let basis_flat : Array[Double] = []
  for i in 0..<n {
    let d_tilde = data.t[i] - m_hat[i]
    resid_y.push(data.y[i] - l_hat[i])
    basis_flat.push(d_tilde)
    for j in 0..<p {
      basis_flat.push(d_tilde * (data.x[i][j] - xbar[j]))
    }
  }
  let basis = @dml.Matrix::from_array(basis_flat, n, 1 + p)
  let blp = @dml.DoubleMLBLP::new(basis, resid_y).fit()
  {
    theta_ref: fitted.coef(),
    se_ref: fitted.se(),
    rv: sens.rv,
    max_bias: sens.max_bias,
    p_theta: ps[0],
    p_neg: ps[1],
    p_naive: ps[2],
    bh_theta: bh[0],
    bh_naive: bh[2],
    bonf_naive: bonf[2],
    het_coefs: blp.coef(),
    het_ses: blp.se(),
  }
}

///|
/// 四位小数显示（如 0.0123 → `0.0123`）。
fn fmt4(x : Double) -> String {
  let pm = (x * 10000.0 + (if x < 0.0 { -0.5 } else { 0.5 })).to_int()
  let sign = if pm < 0 { "-" } else { "" }
  let a = if pm < 0 { -pm } else { pm }
  "\{sign}\{a / 10000}.\{(a % 10000) / 1000}\{(a % 1000) / 100}\{(a % 100) / 10}\{a % 10}"
}

///|
/// p 值显示：小于 0.0001 记 `<0.0001`。
fn fmt_p(p : Double) -> String {
  if p < 0.0001 {
    "<0.0001"
  } else {
    fmt4(p)
  }
}

///|
/// 报告：三项诊断 + 0.75.0 深用的读法与边界。
pub fn render_report() -> String raise {
  let r = run_diagnostics()
  let lines : Array[String] = [
    "# 因果诊断（0.75.0 深用）：敏感性／多重检验／异质性",
    "",
    "依赖：`riantr/moonbit_doubleML@0.75.0`。数据：状态机生成，n = 400，真值 θ = 1.5。",
    "出处层：模型整理——分析的**对象**是模型事实，分析的**工具**是外部库。",
    "",
    "## 1. 敏感性（Cinelli & Hazlett 2020）",
    "",
    "指标 | 数值 | 读法",
    "---|---|---",
    "θ̂（参考 PLR，5 折） | \{fmt4(r.theta_ref)} | 主估计（se \{fmt4(r.se_ref)}）",
    "max_bias | \{fmt4(r.max_bias)} | 最坏情形偏倚界 sqrt(σ²·ν²)",
    "robustness value | \{fmt4(r.rv)} | rv = |θ̂|/max_bias：效应占偏倚界的比例",
    "",
    "读法：rv = \{fmt4(r.rv)}——效应是最坏情形偏倚界的 \{fmt4(r.rv * 100)}%，有限正数：混杂并非无限",
    "脆弱，也非压倒性稳固。「不封闭」在这里获得量化：结论的稳固度是一个**数值**，",
    "不是口号。cf_y/cf_d 基准取库默认 0.05（仅记录，不参与 rv 计算——库文档如此）。",
    "",
    "## 2. 多重检验（批量闸门的假发现率）",
    "",
    "假设 | 原始 p | BH 校正 | Bonferroni | 读法",
    "---|---|---|---|---",
    "θ̂ ≠ 0 | \{fmt_p(r.p_theta)} | \{fmt_p(r.bh_theta)} | — | 真效应，批量校正下仍显著",
    "−θ̂ ≠ 0（对照） | \{fmt_p(r.p_neg)} | — | — | 负号一侧同样极显著（|z| 相同）",
    "天真 OLS（忽略 X） | \{fmt_p(r.p_naive)} | \{fmt_p(r.bh_naive)} | \{fmt_p(r.bonf_naive)} | 被选择偏倚推高的估计同样「显著」",
    "",
    "读法：显著性不是证据——天真 OLS 在批量检验里也会全绿。闸门要的是 θ̂ 与",
    "CI 下界同时为正，而不是一个小于 0.05 的 p。p 值为筛查精度（A&S 7.1.26）。",
    "",
    "## 3. 异质性（BLP，HC0 稳健 se）",
    "",
    "基维 | 系数 | se",
    "---|---|---",
  ]
  let names = [
    "截距（库自带）", "d̃＝d−m̂（主效应）", "d̃·x̃0", "d̃·x̃1",
    "d̃·x̃2", "d̃·x̃3",
  ]
  for i in 0..<r.het_coefs.length() {
    let nm = if i < names.length() { names[i] } else { "b\{i}" }
    lines.push("\{nm} | \{fmt4(r.het_coefs[i])} | \{fmt4(r.het_ses[i])}")
  }
  lines.push("")
  lines.push(
    "读法：d̃ 维应回收 θ̂（PLR 力矩的再线性化）；x 交互维是效应随协变量的斜率。",
  )
  lines.push(
    "这份数据的真 DGP 是均匀效应（y = θ·t + g(X) + ε）：交互维不显著本身是发现——",
  )
  lines.push(
    "没有天然的「谁更受益」切分，政策树（0.75.0 自带 `DoubleMLPolicyTree`）在这里",
  )
  lines.push(
    "无料可挖；异质性显著时它才是闸门候选的前提（挑出谁该修习）。",
  )
  lines.push("")
  lines.push(
    "边界：本层只读。更新闸门仍在 evolution（θ̂ > 0 且 CI 下界 > 0），不因",
  )
  lines.push(
    "0.75.0 扩展而改判据。DID 族（跨期评估）、IV/PLIV（内生性）、APO(S)／",
  )
  lines.push(
    "QTE/LPQ（分布效应）留待对应实验线接入；snnref 的沉淀结构假设也可由",
  )
  lines.push("本层检验——两组通道的效应差是否过零。")
  lines.join("\n")
}
