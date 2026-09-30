///|
/// 双重机器学习（Double / Debiased Machine Learning）的部分线性模型估计。
///
/// 结构模型（partially linear regression, PLR）：
///
///   Y = θ·T + g(X) + ε        E[ε | X, T] = 0
///   T = m(X) + v              E[v | X] = 0
///
/// Neyman 正交分数：
///
///   ψ(W; θ, η) = (Y − g(X) − θ·(T − m(X))) · (T − m(X))
///
/// 交叉拟合（K 折）：每一折的 nuisances ĝ、m̂ 都用**其余折**训练（本仓库用
/// 多项式筛 + 岭回归作为"任意灵活的 ML nuisance"的替身），再预测本折，于是
/// nuisance 的过拟合/正则化偏误不会一阶地进入 θ。估计量为
///
///   θ̂ = Σ ṽ·ỹ / Σ ṽ²,   ṽ = T − m̂(X),  ỹ = Y − ĝ(X)
///
/// 渐近正态：√n(θ̂ − θ) ⇒ N(0, σ²/J²)，σ² = (1/n)Σψ², J = (1/n)Σṽ²。
/// 于是可以给出置信区间与 p 值——这正是"融进状态机"的关键：**状态机给出可识别
/// 的因果结构与时间顺序，DoubleML 给出带有效推断的效应估计**。若只把 X 线性地
/// 塞进回归（或干脆不调整），θ 会因混淆与函数形式误设而有偏。

///|
/// 一次 DML 估计的结果。
pub struct DmlResult {
  theta : Double
  se : Double
  ci_low : Double
  ci_high : Double
  z : Double
  p_value : Double
  n : Int
  folds : Int
  degree : Int
}

///|
/// DML 配置：nuisance 用几次多项式筛、岭惩罚多大、几折交叉、随机种子。
pub struct DmlConfig {
  degree : Int
  lambda : Double
  folds : Int
  seed : UInt64
}

///|
/// 默认配置：3 次多项式筛、λ=0.02、5 折交叉拟合。
pub fn default_dml_config() -> DmlConfig {
  { degree: 3, lambda: 0.02, folds: 5, seed: 20260920, }
}

///|
/// 交叉拟合的 nuisances；返回 (ĝ, m̂)。
fn cross_fit(
  y : Array[Double],
  t : Array[Double],
  x : Array[Array[Double]],
  config : DmlConfig,
) -> (Array[Double], Array[Double]) {
  let n = y.length()
  let order : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    order.push(i)
  }
  let rng = Rng::new(config.seed)
  rng.shuffle(order)
  let ghat : Array[Double] = []
  let mhat : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    ghat.push(0.0)
    mhat.push(0.0)
  }
  let feats = sieve(x, config.degree)
  let folds = if config.folds < 2 { 2 } else { config.folds }
  for f = 0; f < folds; f = f + 1 {
    let xtr : Array[Array[Double]] = []
    let xte : Array[Array[Double]] = []
    let ytr : Array[Double] = []
    let ttr : Array[Double] = []
    let held : Array[Int] = []
    for k = 0; k < n; k = k + 1 {
      let i = order[k]
      if k % folds == f {
        xte.push(feats[i])
        held.push(i)
      } else {
        xtr.push(feats[i])
        ytr.push(y[i])
        ttr.push(t[i])
      }
    }
    let bg = ridge_fit(xtr, ytr, config.lambda)
    let bm = ridge_fit(xtr, ttr, config.lambda)
    let pg = ridge_predict(xte, bg)
    let pm = ridge_predict(xte, bm)
    for u = 0; u < held.length(); u = u + 1 {
      ghat[held[u]] = pg[u]
      mhat[held[u]] = pm[u]
    }
  }
  (ghat, mhat)
}

///|
/// 用**全部样本**拟合 nuisance（不做交叉拟合）——用来演示正则化/过拟合偏误。
fn in_sample_nuisances(
  y : Array[Double],
  t : Array[Double],
  x : Array[Array[Double]],
  config : DmlConfig,
) -> (Array[Double], Array[Double]) {
  let feats = sieve(x, config.degree)
  let bg = ridge_fit(feats, y, config.lambda)
  let bm = ridge_fit(feats, t, config.lambda)
  (ridge_predict(feats, bg), ridge_predict(feats, bm))
}

///|
/// 由 (y, t, ĝ, m̂) 组装正交估计量与推断。
fn estimate(
  y : Array[Double],
  t : Array[Double],
  ghat : Array[Double],
  mhat : Array[Double],
  config : DmlConfig,
) -> DmlResult {
  let n = y.length()
  let mut s_vv = 0.0
  let mut s_vy = 0.0
  for i = 0; i < n; i = i + 1 {
    let v = t[i] - mhat[i]
    s_vv += v * v
    s_vy += v * (y[i] - ghat[i])
  }
  let theta = if s_vv == 0.0 { 0.0 } else { s_vy / s_vv }
  let mut s_psi2 = 0.0
  for i = 0; i < n; i = i + 1 {
    let v = t[i] - mhat[i]
    let psi = (y[i] - ghat[i] - theta * v) * v
    s_psi2 += psi * psi
  }
  let nd = n.to_double()
  let jac = s_vv / nd
  let variance = if jac == 0.0 { 0.0 } else { s_psi2 / nd / (nd * jac * jac) }
  let se = variance.sqrt()
  let z = if se == 0.0 { 0.0 } else { theta / se }
  let p = 2.0 * (1.0 - normal_cdf(z.abs()))
  {
    theta,
    se,
    ci_low: theta - 1.959963984540054 * se,
    ci_high: theta + 1.959963984540054 * se,
    z,
    p_value: p,
    n,
    folds: config.folds,
    degree: config.degree,
  }
}

///|
/// 交叉拟合的 DoubleML / PLR 估计（本层的主入口）。
pub fn dml_plr(
  y : Array[Double],
  t : Array[Double],
  x : Array[Array[Double]],
  config : DmlConfig,
) -> DmlResult {
  let (ghat, mhat) = cross_fit(y, t, x, config)
  estimate(y, t, ghat, mhat, config)
}

///|
/// 同一估计量但不做交叉拟合（对照：正则化偏误）。
pub fn dml_in_sample(
  y : Array[Double],
  t : Array[Double],
  x : Array[Array[Double]],
  config : DmlConfig,
) -> DmlResult {
  let (ghat, mhat) = in_sample_nuisances(y, t, x, config)
  estimate(y, t, ghat, mhat, config)
}

///|
/// 朴素 OLS：Y ~ T，完全不调整 X。返回 (θ̂, 标准误)。
pub fn naive_ols(y : Array[Double], t : Array[Double]) -> (Double, Double) {
  let n = y.length()
  let design : Array[Array[Double]] = []
  for i = 0; i < n; i = i + 1 {
    design.push([1.0, t[i]])
  }
  (ols_core(design, y, 0.0)[1], ols_se(design, y, 0.0, 1))
}

///|
/// 线性调整 OLS：Y ~ [1, X, T]，只把 X 线性地放进去。返回 (θ̂, 标准误)。
pub fn linear_adjust_ols(
  y : Array[Double],
  t : Array[Double],
  x : Array[Array[Double]],
) -> (Double, Double) {
  let n = y.length()
  let p = if n == 0 { 0 } else { x[0].length() }
  let design : Array[Array[Double]] = []
  for i = 0; i < n; i = i + 1 {
    let row : Array[Double] = [1.0]
    for j = 0; j < p; j = j + 1 {
      row.push(x[i][j])
    }
    row.push(t[i])
    design.push(row)
  }
  let col = p + 1
  (ols_core(design, y, 0.0)[col], ols_se(design, y, 0.0, col))
}

///|
/// 单向残差化：只把 Y 对 X 残差化，T 保持原样，θ̂ = Σ ỹ·T / Σ T²。
/// 这是常见的错误——**两边都**要残差化，否则 T 里残留的 X 成分会把混淆带回来
/// （即所谓的 omitted-variable 通道），正交性也就无从谈起。
pub fn one_sided_residual(
  y : Array[Double],
  t : Array[Double],
  x : Array[Array[Double]],
  config : DmlConfig,
) -> DmlResult {
  let (ghat, _) = cross_fit(y, t, x, config)
  let n = y.length()
  let mut s_tt = 0.0
  let mut s_ty = 0.0
  for i = 0; i < n; i = i + 1 {
    s_tt += t[i] * t[i]
    s_ty += t[i] * (y[i] - ghat[i])
  }
  let theta = if s_tt == 0.0 { 0.0 } else { s_ty / s_tt }
  let mut s_psi2 = 0.0
  for i = 0; i < n; i = i + 1 {
    let psi = (y[i] - ghat[i] - theta * t[i]) * t[i]
    s_psi2 += psi * psi
  }
  let nd = n.to_double()
  let jac = s_tt / nd
  let variance = if jac == 0.0 { 0.0 } else { s_psi2 / nd / (nd * jac * jac) }
  let se = variance.sqrt()
  let z = if se == 0.0 { 0.0 } else { theta / se }
  {
    theta,
    se,
    ci_low: theta - 1.959963984540054 * se,
    ci_high: theta + 1.959963984540054 * se,
    z,
    p_value: 2.0 * (1.0 - normal_cdf(z.abs())),
    n,
    folds: config.folds,
    degree: config.degree,
  }
}

///|
/// 构造一个 DML 配置（字段只读，故包外经由本函数构造）。
pub fn DmlConfig::new(
  degree : Int,
  lambda : Double,
  folds : Int,
  seed : UInt64,
) -> DmlConfig {
  { degree, lambda, folds, seed, }
}
