///|
/// 实验层：单次估计的对照表，与重复实验的偏误 / 覆盖率。

///|
/// 单次实验中一行估计结果。
pub struct EstimateRow {
  name : String
  theta : Double
  se : Double
  ci_low : Double
  ci_high : Double
  bias : Double
}

///|
/// 汇总一行（重复实验）。
pub struct RepSummary {
  name : String
  mean_bias : Double
  rmse : Double
  coverage : Double
}

///|
/// 95% 正态分位点。
fn z95() -> Double {
  1.959963984540054
}

///|
/// 组装一行估计结果。
fn row(
  name : String,
  theta_hat : Double,
  se : Double,
  lo : Double,
  hi : Double,
  truth : Double,
) -> EstimateRow {
  {
    name,
    theta: theta_hat,
    se,
    ci_low: lo,
    ci_high: hi,
    bias: theta_hat - truth,
  }
}

///|
/// 同一份数据上的五种估计：朴素、线性调整、单向残差化、同一样本内灵活拟合、DoubleML。
pub fn single_run(
  n : Int,
  theta : Double,
  config : DmlConfig,
) -> Array[EstimateRow] {
  let data = make_dataset(n, theta, config.seed + 1)
  let rows : Array[EstimateRow] = []
  let (bn, sen) = naive_ols(data.y, data.t)
  rows.push(
    row(
      "朴素 OLS（不调整）",
      bn,
      sen,
      bn - z95() * sen,
      bn + z95() * sen,
      theta,
    ),
  )
  let (bl, sel) = linear_adjust_ols(data.y, data.t, data.x)
  rows.push(
    row("线性调整 OLS", bl, sel, bl - z95() * sel, bl + z95() * sel, theta),
  )
  let one = one_sided_residual(data.y, data.t, data.x, config)
  rows.push(
    row(
      "单向残差化（只对 Y）",
      one.theta,
      one.se,
      one.ci_low,
      one.ci_high,
      theta,
    ),
  )
  let ins = dml_in_sample(data.y, data.t, data.x, config)
  rows.push(
    row(
      "同一样本内灵活拟合（不交叉）",
      ins.theta,
      ins.se,
      ins.ci_low,
      ins.ci_high,
      theta,
    ),
  )
  let dml = dml_plr(data.y, data.t, data.x, config)
  rows.push(
    row(
      "DoubleML（正交 + 交叉拟合）",
      dml.theta,
      dml.se,
      dml.ci_low,
      dml.ci_high,
      theta,
    ),
  )
  rows
}

///|
/// 重复 `reps` 次实验，统计平均偏误、RMSE 与 95% 置信区间覆盖率。
pub fn replicate(
  reps : Int,
  n : Int,
  theta : Double,
  config : DmlConfig,
) -> Array[RepSummary] {
  let names : Array[String] = [
    "朴素 OLS（不调整）", "线性调整 OLS", "单向残差化（只对 Y）",
    "同一样本内灵活拟合（不交叉）", "DoubleML（正交 + 交叉拟合）",
  ]
  let sum_bias : Array[Double] = [0.0, 0.0, 0.0, 0.0, 0.0]
  let sum_sq : Array[Double] = [0.0, 0.0, 0.0, 0.0, 0.0]
  let cover : Array[Int] = [0, 0, 0, 0, 0]
  let seed_rng = Rng::new(config.seed)
  for r = 0; r < reps; r = r + 1 {
    let cfg : DmlConfig = {
      degree: config.degree,
      lambda: config.lambda,
      folds: config.folds,
      seed: seed_rng.next_u64(),
    }
    let data = make_dataset(n, theta, seed_rng.next_u64())
    let ests : Array[(Double, Double, Double)] = []
    let (bn, sen) = naive_ols(data.y, data.t)
    ests.push((bn, bn - z95() * sen, bn + z95() * sen))
    let (bl, sel) = linear_adjust_ols(data.y, data.t, data.x)
    ests.push((bl, bl - z95() * sel, bl + z95() * sel))
    let one = one_sided_residual(data.y, data.t, data.x, cfg)
    ests.push((one.theta, one.ci_low, one.ci_high))
    let ins = dml_in_sample(data.y, data.t, data.x, cfg)
    ests.push((ins.theta, ins.ci_low, ins.ci_high))
    let dml = dml_plr(data.y, data.t, data.x, cfg)
    ests.push((dml.theta, dml.ci_low, dml.ci_high))
    for k = 0; k < 5; k = k + 1 {
      let (th, lo, hi) = ests[k]
      let b = th - theta
      sum_bias[k] += b
      sum_sq[k] += b * b
      if lo <= theta && theta <= hi {
        cover[k] += 1
      }
    }
  }
  let out : Array[RepSummary] = []
  let rd = reps.to_double()
  for k = 0; k < 5; k = k + 1 {
    out.push({
      name: names[k],
      mean_bias: sum_bias[k] / rd,
      rmse: (sum_sq[k] / rd).sqrt(),
      coverage: cover[k].to_double() / rd,
    })
  }
  out
}
