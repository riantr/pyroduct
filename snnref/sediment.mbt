///|
/// 脉冲沉淀实验（`snnref`，模型整理）。
///
/// 引入 `riantr/snn_mbt@0.84.0`（SpikingNeuralNetworks.jl 的 bit-exact 移植，
/// 固定种子）。实验只做一件事：把驱动槽的 49 个触发各编成一个通道，同一情境的
/// 槽内触发以高率放电（Poisson，库自带 `poisson_input_single`，全部随机性只走
/// 固定种子），其余通道保持低背景率；49×49 全连接突触按 CSR 布局交给 Gerstner
/// 配对 STDP（库默认参数）——「一起放电的连在一起」就是「持存」的生理形式：
/// 经历沉淀为结构，取用时不必重放全部历史（与 `evolution/intuition` 的背景直觉
/// 读法同构）。
///
/// 可证伪的对照：沉淀出的权重结构能否恢复驱动槽八分？判据两条——
///   1. 同槽配对的平均权重 > 跨槽配对的平均权重；
///   2. 每个通道最强伙伴的命中率 > 随机基线（基线由实际槽规模算出）。
/// 输入假设是「同槽共现」，机制是 STDP，恢复与否由数据给出——代码只断言实验
/// 确定性可复现，不断言八分一定被恢复；恢复率本身写进报告。

///|
/// 沉淀结果。`slot_rows` 每行（槽名, 通道数, 最强伙伴同槽的通道数）。
pub(all) struct Sediment {
  within_mean : Double
  cross_mean : Double
  hit_rate : Double
  chance_rate : Double
  n_triggers : Int
  n_slots : Int
  n_steps : Int
  recovered : Bool
  slot_rows : Array[(String, Int, Int)]
}

///|
/// 实验配置（模型整理的节奏参数）：全部随机性只走一个种子。
pub(all) struct SedimentConfig {
  episodes : Int
  block_ms : Float
  dt : Float
  rate_high : Float
  rate_low : Float
  seed : UInt64
}

///|
/// 默认配置：4 轮 × 8 情境 × 100ms；槽内 50Hz、背景 1Hz；种子 3141。
pub fn SedimentConfig::new() -> Self {
  {
    episodes: 4,
    block_ms: 100.0,
    dt: 1.0,
    rate_high: 50.0,
    rate_low: 1.0,
    seed: 3141,
  }
}

///|
/// 跑一次沉淀实验：编码 → STDP 仿真 → 与驱动槽八分对照。
pub fn run_sediment(config : SedimentConfig) -> Sediment {
  let rng = @snn.Xoshiro::new(config.seed)
  let triggers = @src.all_triggers()
  let slots = @src.all_slots()
  let n = triggers.length()
  let k = slots.length()
  // 通道 → 槽下标（驱动槽八分就是对照的真值划分）。
  let slot_of : Array[Int] = Array::make(n, 0)
  for j in 0..<n {
    let mut idx = 0
    for m in 0..<k {
      if slots[m].equal(triggers[j].slot()) {
        idx = m
      }
    }
    slot_of[j] = idx
  }
  // 全连接 CSR：行 = 前元（通道 j），列 = 后元（通道 i）。
  let rowptr : Array[Int] = []
  let colptr : Array[Int] = []
  for j in 0..<=n {
    rowptr.push(j * n)
  }
  for _ in 0..<n {
    for i in 0..<n {
      colptr.push(i)
    }
  }
  // 初始权重：小随机（同一种子），让跨槽也有非零值、最强伙伴有意义。
  let w : Array[Float] = []
  for v in @snn.rand_f32(rng, n * n) {
    w.push(v * 0.001F)
  }
  let vars = @snn.STDPVariables::new(n, n)
  let rule = @snn.STDPGerstner::new()
  // 编码：每情境块每通道一条 spike train（Poisson，固定种子）。
  let n_blocks = config.episodes * k
  let n_step_block = (config.block_ms / config.dt).to_int()
  let trains : Array[Array[Array[Bool]]] = []
  for b in 0..<n_blocks {
    let current = b % k
    let block : Array[Array[Bool]] = []
    for j in 0..<n {
      let rate = if slot_of[j] == current {
        config.rate_high
      } else {
        config.rate_low
      }
      block.push(
        @snn.poisson_input_single(rate, config.block_ms, config.dt, rng),
      )
    }
    trains.push(block)
  }
  // STDP 仿真：同一份 fire 同时作 pre 与 post（自环通道），t_now 按 dt 推进。
  let mut t_now = 0.0F
  let mut steps = 0
  for b in 0..<n_blocks {
    for s in 0..<n_step_block {
      let fire : Array[Bool] = []
      for j in 0..<n {
        fire.push(trains[b][j][s])
      }
      @snn.stdp_step(
        w,
        fire,
        fire,
        colptr,
        rowptr,
        vars,
        rule,
        t_now,
        config.dt,
      )
      t_now = t_now + config.dt
      steps = steps + 1
    }
  }
  // 对照 1：同槽 vs 跨槽的平均权重。
  let mut within_sum = 0.0
  let mut within_cnt = 0
  let mut cross_sum = 0.0
  let mut cross_cnt = 0
  for j in 0..<n {
    for i in 0..<n {
      if i != j {
        let v = w[j * n + i].to_double()
        if slot_of[j] == slot_of[i] {
          within_sum = within_sum + v
          within_cnt = within_cnt + 1
        } else {
          cross_sum = cross_sum + v
          cross_cnt = cross_cnt + 1
        }
      }
    }
  }
  // 对照 2：每个通道最强伙伴是否同槽；基线由实际槽规模算出。
  let hits : Array[Int] = Array::make(k, 0)
  let sizes : Array[Int] = Array::make(k, 0)
  for m in 0..<k {
    for j in 0..<n {
      if slot_of[j] == m {
        sizes[m] = sizes[m] + 1
      }
    }
  }
  for j in 0..<n {
    let mut best = -1.0F
    let mut best_i = j
    for i in 0..<n {
      if i != j && w[j * n + i] > best {
        best = w[j * n + i]
        best_i = i
      }
    }
    if best_i != j && slot_of[best_i] == slot_of[j] {
      hits[slot_of[j]] = hits[slot_of[j]] + 1
    }
  }
  let mut total_hits = 0
  for m in 0..<k {
    total_hits = total_hits + hits[m]
  }
  let mut chance = 0.0
  for j in 0..<n {
    chance = chance + (sizes[slot_of[j]] - 1).to_double() / (n - 1).to_double()
  }
  chance = chance / n.to_double()
  let rows : Array[(String, Int, Int)] = []
  for m in 0..<k {
    rows.push((slots[m].designation(), sizes[m], hits[m]))
  }
  let within_mean = within_sum / within_cnt.to_double()
  let cross_mean = cross_sum / cross_cnt.to_double()
  let hit_rate = total_hits.to_double() / n.to_double()
  {
    within_mean,
    cross_mean,
    hit_rate,
    chance_rate: chance,
    n_triggers: n,
    n_slots: k,
    n_steps: steps,
    recovered: within_mean > cross_mean && hit_rate > chance,
    slot_rows: rows,
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
/// 报告：编码、机制、两条判据与分槽命中。
pub fn render_report() -> String {
  let c = SedimentConfig::new()
  let r = run_sediment(c)
  let ratio = r.within_mean / r.cross_mean
  let verdict = if r.recovered { "是" } else { "否" }
  let lines : Array[String] = [
    "# 脉冲沉淀实验：触发 → spike trains → STDP → 驱动槽八分",
    "",
    "依赖：`riantr/snn_mbt@0.84.0`（SpikingNeuralNetworks.jl 的 bit-exact 移植，固定种子）。",
    "出处层：模型整理——机制词汇来自神经科学，对照的真值划分是驱动槽八分。",
    "",
    "编码：\{r.n_triggers} 个触发各成一通道；\{c.episodes} 轮 × \{r.n_slots} 情境 × \{c.block_ms}ms；",
    "槽内触发 \{c.rate_high}Hz、其余 \{c.rate_low}Hz（Poisson，种子 \{c.seed}）；",
    "\{r.n_triggers}×\{r.n_triggers} 全连接突触，Gerstner 配对 STDP（库默认参数），共 \{r.n_steps} 步。",
    "",
    "指标 | 数值 | 读法",
    "---|---|---",
    "同槽平均权重 | \{fmt4(r.within_mean)} | 沉淀出的结构强度",
    "跨槽平均权重 | \{fmt4(r.cross_mean)} | 背景噪声水平",
    "比值 | \{fmt4(ratio)} | >1 即槽结构从放电中长出",
    "最强伙伴命中率 | \{fmt4(r.hit_rate)} | 每通道最强伙伴同槽的占比",
    "随机基线 | \{fmt4(r.chance_rate)} | 由实际槽规模算出",
    "",
    "判据：同槽 > 跨槽 且 命中 > 基线——结构恢复 = \{verdict}。",
    "",
    "分槽命中（槽 | 通道数 | 命中 | 命中率）：",
    "",
  ]
  for row in r.slot_rows {
    let (_, size, hit) = row
    lines.push(
      "\{row.0} | \{size} | \{hit} | \{fmt4(hit.to_double() / size.to_double())}",
    )
  }
  lines.push("")
  lines.push(
    "读法：这是一次实验，不是论断。输入假设（同槽共现率更高）是模型整理，机制",
  )
  lines.push(
    "（一起放电连在一起）是持存的生理形式；恢复与否由数据给出。恢复 ≠ 证明八分",
  )
  lines.push(
    "唯一，未恢复 ≠ 八分错误——只说明这份编码与这套参数下，结构没有从放电中长出。",
  )
  lines.join("\n")
}
