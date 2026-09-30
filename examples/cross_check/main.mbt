///|
/// 示例 3 —— 拿**它的** DGP 数据，同时喂给它的估计器与我们的自研估计器。
///
///   moon run examples/cross_check
///
/// 两边都用最小二乘 nuisance，差异只来自交叉拟合的折划分；因此这一行是
/// 「实现互校」，与「谁更接近真值」是两回事。
fn main {
  let c = @dmlref.external_plr(500, 20, 1.0, 3141, 5, 0.2)
  println(
    "=== 实现互校：外部 DGP（plr_CCDDHNR2018），n = \{c.n}，\{c.folds} 折 ===",
  )
  println("真值 θ            = \{c.truth}")
  println(
    "参考实现 θ̂        = \{c.theta_ref}（se \{c.se_ref}，95% CI [\{c.ci_low}, \{c.ci_high}]）",
  )
  println("自研实现 θ̂        = \{c.theta_ours}（se \{c.se_ours}）")
  println(
    "两者之差 |Δθ̂|     = \{c.d_theta}｜标准误之差 = \{c.d_se}",
  )
  println("容差内一致        = \{c.agree}")
  println("")
  println(
    "说明：CCDDHNR2018 的 g(X)／m(X) 含非线性的 logistic 形式，线性 nuisance",
  )
  println(
    "对真值本来就有偏；两实现**同样**偏，正是「同一估计量、两套实现」的体现。",
  )
}
