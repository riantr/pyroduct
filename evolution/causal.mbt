///|
/// 因果闸门：把「这次自我更新是不是真的更好」变成一个**可识别的因果问题**。
///
/// 处置 T＝本回合是否采纳了候选基因组；结果 Y＝该回合的遭遇成效；协变量 X＝上下文
/// （难度、起始残余）。关键在于**采纳本身是自选的**——主体往往在形势好的时候才肯改
/// （本例 `P(采纳) = 0.15 + 0.7·(1 − 难度)`）。于是直接比较采纳组与未采纳组的结果均值，
/// 会把「形势好」记到「改动好」账上；DoubleML 把 X 的贡献两边都残差化，才把 θ 还原。
///
/// 于是闸门不再问「加权得分涨了吗」，而问「**采纳这个改动的因果效应是否显著为正**」。

///|
/// 一份带混淆的观测数据（一回合一行）。
pub struct Episodes {
  y : Array[Double]
  t : Array[Double]
  x : Array[Array[Double]]
  theta_true : Double
  n : Int
}

///|
/// 一个基因组在一组对手上的平均成效（真跑 `@multi.encounter`）。
/// 成效取值：相契 2、暂时共识 1、其余 0。
pub fn quality(g : Genome, world : Array[Opponent]) -> Double {
  if world.length() == 0 {
    return 0.0
  }
  let mut s = 0.0
  for o in world {
    let me = @multi.subject(
      1,
      @multi.rendezvous(),
      g.regime,
      g.toward_other,
      g.toward_self,
      g.carry,
    )
    let other = @multi.subject(
      2,
      @multi.rendezvous(),
      o.regime,
      o.toward_other,
      o.toward_self,
      o.residue,
    )
    let claim : @multi.ValidityClaim = {
      kind: @multi.Truthfulness,
      phase: @multi.During,
    }
    let out = @multi.encounter(me, other, @multi.Theoretical, claim)
    s += match out.verdict {
      @multi.Attuned => 2.0
      @multi.Provisional => 1.0
      _ => 0.0
    }
  }
  s / world.length().to_double()
}

///|
/// 生成观测数据：`Y = θ·T + g(X) + ε`，其中 θ 是「成效之差」（真值），T 与 X 相关。
pub fn make_episodes(
  parent : Genome,
  candidate : Genome,
  world : Array[Opponent],
  n : Int,
  seed : UInt64,
) -> Episodes {
  let q0 = quality(parent, world)
  let q1 = quality(candidate, world)
  let rng = @ml.Rng::new(seed)
  let y : Array[Double] = []
  let t : Array[Double] = []
  let x : Array[Array[Double]] = []
  for i = 0; i < n; i = i + 1 {
    let difficulty = rng.uniform()
    let start = rng.uniform()
    // 自选：形势越好越肯改（这正是混淆的来源）。
    let adopt = 0.15 + 0.7 * (1.0 - difficulty)
    let treat = if rng.uniform() < adopt { 1.0 } else { 0.0 }
    let q = if treat == 1.0 { q1 } else { q0 }
    let outcome = q - 2.0 * difficulty - 0.5 * start + 0.15 * rng.normal()
    y.push(outcome)
    t.push(treat)
    x.push([difficulty, start])
  }
  { y, t, x, theta_true: q1 - q0, n, }
}

///|
/// 一次因果裁决。
pub struct CausalVerdict {
  theta : Double // DoubleML 估计
  se : Double
  ci_low : Double
  ci_high : Double
  naive : Double // 朴素差（含选择偏误）
  truth : Double // 本例真值（由设计给出，供对照）
  n : Int
}

///|
/// 估计「采纳候选基因组」的因果效应；同时给出朴素对照。
///
/// 所有候选共用同一批上下文（固定回合种子），是配对比较，可降方差。
pub fn causal_effect(
  parent : Genome,
  candidate : Genome,
  world : Array[Opponent],
  episodes : Int,
  config : @ml.DmlConfig,
) -> CausalVerdict {
  let data = make_episodes(parent, candidate, world, episodes, 20260930)
  let (naive, _) = @ml.naive_ols(data.y, data.t)
  let dml = @ml.dml_plr(data.y, data.t, data.x, config)
  {
    theta: dml.theta,
    se: dml.se,
    ci_low: dml.ci_low,
    ci_high: dml.ci_high,
    naive,
    truth: data.theta_true,
    n: data.n,
  }
}

///|
/// 千分位取整（持久化与比较用整数，避开浮点的往返差异）。
pub fn permille(x : Double) -> Int {
  let scaled = x * 1000.0
  (if scaled < 0.0 { scaled - 0.5 } else { scaled + 0.5 }).to_int()
}

///|
/// 千分位数 → 文本（如 `-200` → `-0.200`）。
pub fn show_pm(pm : Int) -> String {
  let sign = if pm < 0 { "-" } else { "" }
  let a = if pm < 0 { -pm } else { pm }
  "\{sign}\{a / 1000}.\{pad3(a % 1000)}"
}

///|
fn pad3(v : Int) -> String {
  "\{v / 100}\{(v % 100) / 10}\{v % 10}"
}

///|
/// 便捷入口：默认 400 回合、默认 DML 配置的因果裁决。
pub fn causal_verdict(
  parent : Genome,
  candidate : Genome,
  world : Array[Opponent],
) -> CausalVerdict {
  causal_effect(parent, candidate, world, 400, @ml.default_dml_config())
}

///|
/// 因果判据（默认 DML 配置；`objective` 仅用于报表里的四分量对照）。
pub fn causal_criterion(episodes : Int) -> Criterion {
  Causal({
    objective: truth_objective(),
    episodes,
    config: @ml.default_dml_config(),
  })
}
