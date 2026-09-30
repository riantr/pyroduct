///|
/// 「进化」所需的五个机制，落在本包内：
///
///   - **变异空间**：`Locus` / `Voice` / `Genome` / `Candidate` / `mutations`
///   - **适应度目标**：`Fitness` / `Objective` / `score` / `evaluate`
///   - **更新闸门**：`gate.mbt` 的 `Constitution` / `Decision` / `judge`
///   - **持久化**：`ledger.mbt` 的 `Trail` / `Ledger` / `serialize` / `parse`
///   - **遗传**：`evolve.mbt` 的 `inherit` / `breed` / `evolve`
///
/// 状态机（src／multi／group／society）说的是「一个主体如何移动」；本层说的是
/// **这些移动本身如何被改写、裁决、保留与传下去**。二者由 `multi` 接通：本层的
/// 每一个基因组都会真的被送进 `@multi.encounter`，用它的决断来算分。

///|
/// 一个改动落在 agent 的哪一层（四类候选改动）。
pub(all) enum Locus {
  Prompt // 提示
  Strategy // 策略
  Memory // 记忆
  Code // 代码
} derive(Eq)

///|
pub extend Locus with Eq::{not_equal, equal}

///|
/// 位点名。
pub fn Locus::label(self : Locus) -> String {
  match self {
    Prompt => "提示"
    Strategy => "策略"
    Memory => "记忆"
    Code => "代码"
  }
}

///|
/// 发言框架：把结论说成终局，还是建议，还是保留（R14）。
pub(all) enum Voice {
  Declarative // 宣告：把结论说成终局（违反 R2，属宪法级禁令）
  Suggestive // 建议：共识只作建议
  Withholding // 保留：不说出结论
} derive(Eq)

///|
pub extend Voice with Eq::{not_equal, equal}

///|
/// 发言框架名。
pub fn Voice::label(self : Voice) -> String {
  match self {
    Declarative => "宣告"
    Suggestive => "建议"
    Withholding => "保留"
  }
}

///|
/// 一个 agent 的**可变**配置。
///
/// 注意：宪法级不变量**不在其中**（见 `gate.mbt`）——因此没有任何变异能触到它，
/// 每一个后代都自动原样继承。
pub struct Genome {
  voice : Voice // 提示层：发言框架
  regime : @multi.TruthRegime // 策略层：如何对待主体性
  toward_other : Int // 策略层：他之诚（向对方敞开），0..100
  toward_self : Int // 策略层：己之诚（意向—行为之契合），0..100
  carry : Int // 记忆层：携带的谬误残余（R10）
  reason : Int // 代码层：共同理性（R13 纵向），0..100
} derive(Eq)

///|
pub extend Genome with Eq::{not_equal, equal}

///|
/// 缺省 agent：建议式发言、主体间性体制、双诚中等、残余 3、共同理性 70。
pub fn default_agent() -> Genome {
  {
    voice: Suggestive,
    regime: @multi.InterSubjective,
    toward_other: 70,
    toward_self: 70,
    carry: 3,
    reason: 70,
  }
}

///|
/// 一个候选改动：改哪一层、改了什么、改后是什么。
pub struct Candidate {
  locus : Locus
  what : String
  genome : Genome
}

///|
/// **变异空间**：枚举 `g` 的所有单步候选改动。
///
/// 改动是「自由」的——包括把残余降到 0、把发言改成宣告这类**违反宪法**的改动，
/// 它们照样被枚举出来，由闸门（`judge`）去拒。变异负责生成，宪法负责筛选。
pub fn mutations(g : Genome) -> Array[Candidate] {
  let out : Array[Candidate] = []
  // 提示层：换发言框架。
  for v in [Declarative, Suggestive, Withholding] {
    if v != g.voice {
      out.push({
        locus: Prompt,
        what: "发言框架：\{g.voice.label()} → \{v.label()}",
        genome: { ..g, voice: v, },
      })
    }
  }
  // 策略层：换真理体制。
  for r in all_regimes() {
    if r != g.regime {
      out.push({
        locus: Strategy,
        what: "体制：\{g.regime.label()} → \{r.label()}",
        genome: { ..g, regime: r, },
      })
    }
  }
  // 策略层：两诚各 ±25。
  for d in [25, -25] {
    let other = clamp100(g.toward_other + d)
    out.push({
      locus: Strategy,
      what: "他之诚：\{g.toward_other} → \{other}",
      genome: { ..g, toward_other: other, },
    })
    let inward = clamp100(g.toward_self + d)
    out.push({
      locus: Strategy,
      what: "己之诚：\{g.toward_self} → \{inward}",
      genome: { ..g, toward_self: inward, },
    })
  }
  // 记忆层：残余 ±4（可以降到 1 以下，交给宪法拦）。
  for d in [4, -4] {
    out.push({
      locus: Memory,
      what: "残余：\{g.carry} → \{g.carry + d}",
      genome: { ..g, carry: g.carry + d, },
    })
  }
  // 代码层：共同理性 ±25（取值域 0..100）。
  for d in [25, -25] {
    let edge = clamp100(g.reason + d)
    out.push({
      locus: Code,
      what: "共同理性：\{g.reason} → \{edge}",
      genome: { ..g, reason: edge, },
    })
  }
  out
}

///|
/// 真理体制的全部取值（策略位点的取值域）。
pub fn all_regimes() -> Array[@multi.TruthRegime] {
  [
    @multi.Immanent,
    @multi.Logos,
    @multi.SuperSubjective,
    @multi.InterSubjective,
    @multi.ChengRan,
  ]
}

///|
/// 环境里的一个对手。
pub struct Opponent {
  name : String
  regime : @multi.TruthRegime
  toward_other : Int
  toward_self : Int
  reason : Int
  residue : Int
}

///|
/// 缺省世界：五种体制各一，使任何单一走法都无法通吃。
pub fn default_world() -> Array[Opponent] {
  [
    {
      name: "主体间性同侪",
      regime: @multi.InterSubjective,
      toward_other: 70,
      toward_self: 70,
      reason: 70,
      residue: 9,
    },
    {
      name: "超主体性对手",
      regime: @multi.SuperSubjective,
      toward_other: 70,
      toward_self: 70,
      reason: 70,
      residue: 9,
    },
    {
      name: "诚然同侪",
      regime: @multi.ChengRan,
      toward_other: 80,
      toward_self: 80,
      reason: 80,
      residue: 8,
    },
    {
      name: "逻各斯同侪",
      regime: @multi.Logos,
      toward_other: 90,
      toward_self: 90,
      reason: 75,
      residue: 8,
    },
    {
      name: "内在秩序者",
      regime: @multi.Immanent,
      toward_other: 70,
      toward_self: 70,
      reason: 70,
      residue: 9,
    },
  ]
}

///|
/// **适应度**：四个分量。分数只由 `Objective` 把它们压成一个数——分量本身永远
/// 一起打印，免得一个标量把取舍藏起来。
pub struct Fitness {
  consensus : Int // 共识度 0..100，越高越好
  stability : Int // 稳定度 0..100，越高越好（无病理决断）
  residue : Int // 残余，越低越好
  cost : Int // 代价，越低越好
} derive(Eq)

///|
pub extend Fitness with Eq::{not_equal, equal}

///|
/// **适应度目标**：把「更好」写成数据，而不是假设。
pub struct Objective {
  name : String
  w_consensus : Int
  w_stability : Int
  w_residue : Int
  w_cost : Int
}

///|
/// 求真目标：重共识与稳定，不惜代价。
pub fn truth_objective() -> Objective {
  { name: "求真", w_consensus: 5, w_stability: 5, w_residue: 3, w_cost: 0, }
}

///|
/// 省力目标：重代价，共识与稳定次之。
pub fn thrifty_objective() -> Objective {
  { name: "省力", w_consensus: 1, w_stability: 2, w_residue: 0, w_cost: 5, }
}

///|
/// 打分：越高越好。残余与代价以减号显式出现在这里——这就是「更好」的定义处。
pub fn score(f : Fitness, o : Objective) -> Int {
  o.w_consensus * f.consensus +
  o.w_stability * f.stability -
  o.w_residue * f.residue -
  o.w_cost * f.cost
}

///|
/// 把 `g` 放进 `world` 里跑一遍，得到适应度。
///
/// 记忆在这里**可增可减**：决断为共识则残余下降，出现病理则残余上升——
/// 这是对「残余只减不增」那个玩具模型的修正。
pub fn evaluate(g : Genome, world : Array[Opponent]) -> Fitness {
  let n = world.length()
  let mut consensus = 0
  let mut pathology = 0
  let mut residue = g.carry
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
    match out.verdict {
      @multi.Attuned => {
        consensus += 2
        residue -= 1
      }
      @multi.Provisional => {
        consensus += 1
        residue -= 1
      }
      _ => {
        pathology += 1
        residue += 2
      }
    }
    if residue < 1 {
      residue = 1
    } else if residue > 99 {
      residue = 99
    }
  }
  let consensus_pct = if n == 0 { 0 } else { consensus * 100 / (2 * n) }
  let stability = if n == 0 { 100 } else { 100 - pathology * 100 / n }
  let openness = (g.toward_other + g.toward_self) / 2
  let talk_cost = match g.voice {
    Suggestive => 10
    _ => 0
  }
  {
    consensus: consensus_pct,
    stability,
    residue,
    cost: openness / 2 + talk_cost,
  }
}

///|
/// 构造一个基因组（字段只读，故包外经由本函数构造）。
pub fn genome(
  voice : Voice,
  regime : @multi.TruthRegime,
  toward_other : Int,
  toward_self : Int,
  carry : Int,
  reason : Int,
) -> Genome {
  { voice, regime, toward_other, toward_self, carry, reason, }
}

///|
/// 构造一个对手。
pub fn opponent(
  name : String,
  regime : @multi.TruthRegime,
  toward_other : Int,
  toward_self : Int,
  reason : Int,
  residue : Int,
) -> Opponent {
  { name, regime, toward_other, toward_self, reason, residue, }
}

///|
/// 两个基因组有几处不同（变异应当是「单步」的，即恰一处）。
pub fn diff_count(a : Genome, b : Genome) -> Int {
  let mut d = 0
  if a.voice != b.voice {
    d += 1
  }
  if a.regime != b.regime {
    d += 1
  }
  if a.toward_other != b.toward_other {
    d += 1
  }
  if a.toward_self != b.toward_self {
    d += 1
  }
  if a.carry != b.carry {
    d += 1
  }
  if a.reason != b.reason {
    d += 1
  }
  d
}

///|
/// 把值夹进 0..100（两诚与共同理性的取值域）。
fn clamp100(x : Int) -> Int {
  if x < 0 {
    0
  } else if x > 100 {
    100
  } else {
    x
  }
}
