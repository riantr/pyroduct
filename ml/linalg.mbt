///|
/// 数值底座：矩阵求解、OLS/岭回归、多项式特征筛、正态分布函数。
/// 全部自实现，不引入外部数值/统计库——这是把机器学习纳入状态机所需的最小底座。

///|
/// 解 A x = b（A 为方阵）：列主元高斯—约当消元。奇异分量给 0，避免 panic。
fn solve(a : Array[Array[Double]], b : Array[Double]) -> Array[Double] {
  let n = b.length()
  let m : Array[Array[Double]] = []
  for i = 0; i < n; i = i + 1 {
    let row : Array[Double] = []
    for j = 0; j < n; j = j + 1 {
      row.push(a[i][j])
    }
    row.push(b[i])
    m.push(row)
  }
  for col = 0; col < n; col = col + 1 {
    let mut piv = col
    let mut best = m[col][col].abs()
    for r = col + 1; r < n; r = r + 1 {
      let v = m[r][col].abs()
      if v > best {
        best = v
        piv = r
      }
    }
    if piv != col {
      let t = m[col]
      m[col] = m[piv]
      m[piv] = t
    }
    let d = m[col][col]
    if d.abs() < 1.0e-12 {
      continue
    }
    for r = 0; r < n; r = r + 1 {
      if r != col {
        let f = m[r][col] / d
        if f != 0.0 {
          for c = col; c <= n; c = c + 1 {
            m[r][c] = m[r][c] - f * m[col][c]
          }
        }
      }
    }
  }
  let x : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    let d = m[i][i]
    x.push(if d.abs() < 1.0e-12 { 0.0 } else { m[i][n] / d })
  }
  x
}

///|
/// X'X + λI（对称，只算上三角再镜像）与 X'y。
fn gram(
  design : Array[Array[Double]],
  y : Array[Double],
  lambda : Double,
) -> (Array[Array[Double]], Array[Double]) {
  let n = design.length()
  let p = if n == 0 { 0 } else { design[0].length() }
  let xtx : Array[Array[Double]] = []
  for i = 0; i < p; i = i + 1 {
    let row : Array[Double] = []
    for j = 0; j < p; j = j + 1 {
      row.push(0.0)
    }
    xtx.push(row)
  }
  let xty : Array[Double] = []
  for i = 0; i < p; i = i + 1 {
    xty.push(0.0)
  }
  for k = 0; k < n; k = k + 1 {
    let row = design[k]
    let yk = y[k]
    for i = 0; i < p; i = i + 1 {
      let xi = row[i]
      xty[i] += xi * yk
      for j = i; j < p; j = j + 1 {
        xtx[i][j] += xi * row[j]
      }
    }
  }
  for i = 0; i < p; i = i + 1 {
    for j = 0; j < i; j = j + 1 {
      xtx[i][j] = xtx[j][i]
    }
    xtx[i][i] += lambda + 1.0e-10
  }
  (xtx, xty)
}

///|
/// 线性回归系数（design 已含所需全部列，不自动加截距）。
fn ols_core(
  design : Array[Array[Double]],
  y : Array[Double],
  lambda : Double,
) -> Array[Double] {
  let (xtx, xty) = gram(design, y, lambda)
  solve(xtx, xty)
}

///|
/// 第 `col` 个系数的经典标准误。
fn ols_se(
  design : Array[Array[Double]],
  y : Array[Double],
  lambda : Double,
  col : Int,
) -> Double {
  let (xtx, xty) = gram(design, y, lambda)
  let beta = solve(xtx, xty)
  let n = y.length()
  let p = if n == 0 { 0 } else { design[0].length() }
  let mut sse = 0.0
  for i = 0; i < n; i = i + 1 {
    let mut pred = 0.0
    for j = 0; j < p; j = j + 1 {
      pred += design[i][j] * beta[j]
    }
    let r = y[i] - pred
    sse += r * r
  }
  let dof = (n - p).to_double()
  let s2 = if dof > 0.0 { sse / dof } else { 0.0 }
  let e : Array[Double] = []
  for j = 0; j < p; j = j + 1 {
    e.push(if j == col { 1.0 } else { 0.0 })
  }
  let inv_col = solve(xtx, e)
  (s2 * inv_col[col]).sqrt()
}

///|
/// 带截距的岭回归：`x` 每行是自变量取值，返回长度 p+1 的系数（第 0 位为截距）。
fn ridge_fit(
  x : Array[Array[Double]],
  y : Array[Double],
  lambda : Double,
) -> Array[Double] {
  let p = if x.length() == 0 { 0 } else { x[0].length() }
  let design : Array[Array[Double]] = []
  for i = 0; i < x.length(); i = i + 1 {
    let row : Array[Double] = [1.0]
    for j = 0; j < p; j = j + 1 {
      row.push(x[i][j])
    }
    design.push(row)
  }
  ols_core(design, y, lambda)
}

///|
/// 用 `ridge_fit` 的系数预测。
fn ridge_predict(
  x : Array[Array[Double]],
  beta : Array[Double],
) -> Array[Double] {
  let out : Array[Double] = []
  for i = 0; i < x.length(); i = i + 1 {
    let mut v = beta[0]
    for j = 0; j < x[i].length(); j = j + 1 {
      v += beta[j + 1] * x[i][j]
    }
    out.push(v)
  }
  out
}

///|
/// 多项式特征筛（sieve）：把 d 维协变量展开为全部 1…`degree` 次单项式。
/// 它扮演 DoubleML 中"任意灵活的机器学习 nuisance"的角色：维数随 degree 上升，
/// 而 Neyman 正交 + 交叉拟合保证 nuisance 的误差不会一阶地污染 θ。
fn poly_features(x : Array[Double], degree : Int) -> Array[Double] {
  let out : Array[Double] = []
  fn gen(
    start : Int,
    left : Int,
    acc : Double,
    x : Array[Double],
    out : Array[Double],
  ) -> Unit {
    for j = start; j < x.length(); j = j + 1 {
      let p = acc * x[j]
      out.push(p)
      if left > 1 {
        gen(j, left - 1, p, x, out)
      }
    }
  }
  for k = 1; k <= degree; k = k + 1 {
    gen(0, k, 1.0, x, out)
  }
  out
}

///|
/// 对全体样本做特征筛。
fn sieve(x : Array[Array[Double]], degree : Int) -> Array[Array[Double]] {
  let out : Array[Array[Double]] = []
  for i = 0; i < x.length(); i = i + 1 {
    out.push(poly_features(x[i], degree))
  }
  out
}

///|
/// 误差函数（Abramowitz–Stegun 7.1.26，绝对误差 ~1.5e-7）。
fn erf(x : Double) -> Double {
  let sign = if x < 0.0 { -1.0 } else { 1.0 }
  let ax = x.abs()
  let t = 1.0 / (1.0 + 0.3275911 * ax)
  let poly = (
      (((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) *
      t +
      0.254829592
    ) *
    t
  sign * (1.0 - poly * @math.exp(-ax * ax))
}

///|
/// 标准正态分布函数 Φ。
fn normal_cdf(z : Double) -> Double {
  0.5 * (1.0 + erf(z / 1.4142135623730951))
}

///|
/// 定点格式化，用于报告。
fn fmt(x : Double, digits : Int) -> String {
  let scale = @math.pow(10.0, digits.to_double())
  let r = (x * scale).round() / scale
  "\{r}"
}
