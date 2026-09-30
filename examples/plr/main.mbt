///|
/// 示例 1 —— 用 `riantr/moonbit_doubleML` 自带的 DGP 驱动它的 `DoubleMLPLR`。
///
///   moon run examples/plr
///
/// 形状照它的 README：打印真值、估计、标准误与 95% 置信区间。
fn main {
  let n = 500
  let dim_x = 20
  let truth = 1.0
  let data = @dml.make_plr_CCDDHNR2018(n, dim_x, truth, 3141)
  let dml_data = @dml.DoubleMLData::new(
    data.x_get(),
    data.y_get(),
    data.d_get(),
  )
  let fitted = @dml.DoubleMLPLR::new(dml_data, n_folds=5).fit()
  let (lo, hi) = fitted.confint()
  println(
    "=== MoonBit DML PLR（数据取自 riantr/moonbit_doubleML 的 DGP）===",
  )
  println("true theta_0      = \{data.theta_get()}")
  println("estimated theta   = \{fitted.coef()}")
  println("standard error    = \{fitted.se()}")
  println("95% CI            = [\{lo}, \{hi}]")
  println("n_obs             = \{fitted.n_obs()}")
  println("n_features        = \{fitted.n_features()}")
}
