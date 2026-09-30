///|
/// 把状态机本身当作数据生成器的骨架。
///
/// 每个"主体"的协变量 X 全部取自状态机的元数据：
///
///   x1 = freedom(s)      该状态阐释性的自由刻度
///   x2 = phase_index(s)  所属阶段的序号（立位=1 … 安位=11）
///   x3 = outdeg(s)       从 s 出发的出边条数（可选取的动作数）
///   x4 = dist(s)         从 s 沿迁移到宁静的最少步数（界域之远近）
///
/// 处置 T 是"练习强度"，其中一项直接来自状态机的**动力学**：从 s 出发随机走
/// 24 步，数其中"消除暗礁（修习）"这一步出现了几次。处置与 X 强相关——这正是
/// 混淆。结果 Y 是自由度，θ 是**练习对自由度的因果效应**（模拟中的真值）。

///|
/// 一次模拟的数据集。
pub struct Dataset {
  y : Array[Double]
  t : Array[Double]
  x : Array[Array[Double]]
  theta_true : Double
}

///|
/// 阶段序号（1 起；来自状态机自己的阶段划分）。
fn phase_index(p : @sm.Phase) -> Int {
  let ps = @sm.all_phases()
  for i = 0; i < ps.length(); i = i + 1 {
    if ps[i] == p {
      return i + 1
    }
  }
  0
}

///|
/// 从 `s` 沿状态机的迁移到"宁静"的最少步数；到不了给 40 作为上限。
pub fn distance_to_rest(s : @sm.SubjectState) -> Int {
  let goal = @sm.terminal()
  if s == goal {
    return 0
  }
  let seen : Array[@sm.SubjectState] = [s]
  let dist : Array[Int] = [0]
  let mut i = 0
  while i < seen.length() && dist[i] < 40 {
    let u = seen[i]
    let d = dist[i]
    for e in @sm.successors(u) {
      let v = e.1
      if v == goal {
        return d + 1
      }
      let mut known = false
      for w in seen {
        if w == v {
          known = true
        }
      }
      if !known {
        seen.push(v)
        dist.push(d + 1)
      }
    }
    i += 1
  }
  40
}

///|
/// 从 `s` 出发在状态机上随机走 `steps` 步，返回其中"消除暗礁（修习）"出现的次数。
/// 这是把状态机的**迁移结构**直接变成可观测处置的一条路径。
pub fn practice_count(s : @sm.SubjectState, steps : Int, rng : Rng) -> Int {
  let mut cur = s
  let mut count = 0
  let mut k = 0
  while k < steps {
    let outs = @sm.successors(cur)
    if outs.length() == 0 {
      k = steps
    } else {
      let i = (rng.uniform() * outs.length().to_double()).to_int()
      let (trigger, next) = outs[i]
      if trigger == @sm.RemoveReefs {
        count += 1
      }
      cur = next
      k += 1
    }
  }
  count
}

///|
/// 生成数据集：协变量与处置都来自状态机，θ 为真值，`seed` 保证可重放。
pub fn make_dataset(n : Int, theta : Double, seed : UInt64) -> Dataset {
  let rng = Rng::new(seed)
  let states = @sm.all_states()
  let y : Array[Double] = []
  let t : Array[Double] = []
  let x : Array[Array[Double]] = []
  for i = 0; i < n; i = i + 1 {
    let s = states[(rng.uniform() * states.length().to_double()).to_int()]
    let f = s.freedom().to_double()
    let ph = phase_index(s.phase()).to_double()
    let od = @sm.successors(s).length().to_double()
    let dt = distance_to_rest(s).to_double()
    let practice = practice_count(s, 24, rng).to_double()
    // 处置：练习强度（与主体所处的位置强相关 → 混淆）
    let treat = 0.35 * f +
      0.25 * ph -
      0.20 * od +
      0.15 * dt +
      0.40 * practice +
      1.0 * rng.normal()
    // 结果：自由度。g 是"位置"的直接效应（含非线性项），θ 是练习的因果效应。
    let g = 0.9 * f + 0.7 * ph - 0.5 * od + 0.4 * dt + 0.05 * dt * dt
    let outcome = theta * treat + g + 0.5 * rng.normal()
    y.push(outcome)
    t.push(treat)
    x.push([f, ph, od, dt])
  }
  { y, t, x, theta_true: theta, }
}

///|
/// 把数据集导成 CSV（表头 y,t,x1..xk），便于交给 Python 的 `DoubleML` / `EconML`
/// 用同一份数据复核——MoonBit 侧的估计与参考实现可以逐行对上。
pub fn export_csv(data : Dataset) -> String {
  let lines : Array[String] = []
  let k = if data.x.length() == 0 { 0 } else { data.x[0].length() }
  let header : Array[String] = ["y", "t"]
  for j = 0; j < k; j = j + 1 {
    header.push("x\{j + 1}")
  }
  lines.push(header.join(","))
  for i = 0; i < data.y.length(); i = i + 1 {
    let row : Array[String] = [fmt(data.y[i], 6), fmt(data.t[i], 6)]
    for j = 0; j < k; j = j + 1 {
      row.push(fmt(data.x[i][j], 6))
    }
    lines.push(row.join(","))
  }
  lines.join("\n")
}

///|
/// 状态机侧的协变量表：每个状态的 (通用定名, [freedom, phase, outdeg, dist])。
/// 它把「状态机提供什么」直接摊开——既是报告的一节，也是"协变量确实来自状态机"
/// 这一断言的依据。
pub fn state_features() -> Array[(String, Array[Double])] {
  let out : Array[(String, Array[Double])] = []
  for s in @sm.all_states() {
    out.push(
      (
        s.designation(),
        [
          s.freedom().to_double(),
          phase_index(s.phase()).to_double(),
          @sm.successors(s).length().to_double(),
          distance_to_rest(s).to_double(),
        ],
      ),
    )
  }
  out
}
