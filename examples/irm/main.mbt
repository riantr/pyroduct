///|
/// 示例 2 —— 同一个「一例一包」的样式，换成第二个估计器：`DoubleMLIRM`。
///
///   moon run examples/irm
///
/// 用来印证它的 README 那句话：`DoubleMLXxx::new(...).fit()` 与 `.coef()/.se()/.confint()`
/// 在所有估计器上形状一致。
///
/// 注意 IRM 的**倾向得分**要传 logistic 学习器：处理变量是 0/1，用线性回归去拟合
/// 倾向得分会让 m̂ 越出 [0,1]，权重随之爆炸（第一次跑出 −1520 就是这么来的）。
fn main {
  let data = @dml.make_irm_data(500, 5, 1.0, 3141)
  let dml_data = @dml.DoubleMLData::new(
    data.x_get(),
    data.y_get(),
    data.d_get(),
  )
  let fitted = @dml.DoubleMLIRM::new(
    dml_data,
    n_folds=5,
    ml_m=@dml.LearnerDispatch::logistic_regression(
      @dml.LogisticRegression::new(),
    ),
  ).fit()
  let (lo, hi) = fitted.confint()
  println(
    "=== MoonBit DML IRM（数据取自 riantr/moonbit_doubleML 的 DGP）===",
  )
  println("true theta_0      = \{data.theta_get()}")
  println("estimated theta   = \{fitted.coef()}")
  println("standard error    = \{fitted.se()}")
  println("95% CI            = [\{lo}, \{hi}]")
}
