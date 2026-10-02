///|
/// 主体循环（`cycle.mbt`）：位置 × 驱动槽 × 因果反馈。
///
/// 六槽模式（S／O／G／P／A／F）里可取的部分是**执行契约**，不是本体。本文件把它
/// 接到仓库已有的机制上，三条对应关系：
///
///   - **位置**＝`@sm.SubjectState`（发生论位置，不是内部变量）；推进只走
///     `@sm.step(位置, 槽)`，其回执（迁／守／未定／无路）是迁移表给的，不是这里算的。
///   - **世界回应**＝`@multi.encounter` 的真决断（复用 `evaluate`）——不造
///     `感知(环境, S_t)` 这样的函数，回应就是遭遇的判词，且**回应只能在该位置可走的
///     槽里挑**（`cycle_slot`）：回应不编造出路。
///   - **因果反馈**＝两个候选改动过**同一个闸门**（`judge`）：修习（残余 −4，
///     「消除暗礁」）与开放（己之诚 −25，「不再把自身抱得太紧」）。因果判据下由
///     DoubleML 给 θ̂ 与 95% 置信下界，两者皆正才接收——修养不是意愿问题，是证据问题。
///
/// 两条要紧的取舍：
/// - **「未定」不掷骰子，也不由感知决断**：`@sm.step` 给出 `Open` 时，按主体的
///   **双诚之比**裁决（`resolve_open`）。他之诚更盛取向空间侧（疏离／交织／敬畏），
///   持平或更弱取向时间侧（紧迫／沉淀／受赏）。这是**模型整理**，非原文直述。
/// - **不封闭照旧守住**：`Open`／`Block` 都不推进位置，回执原样入账；残余由宪法
///   （R10）拦在 ≥1，永不进化掉。
///
/// 记账复用 `Ledger`（只追加、可序列化、可读回）：每回合的修习裁决写成一条 `Trail`。

///|
/// 循环里一个瞬间的主体：机器上的位置 + 可变配置。
pub struct CycleState {
  state : @sm.SubjectState
  genome : Genome
} derive(Eq)

///|
pub extend CycleState with Eq::{not_equal, equal}

///|
/// 构造一个瞬间：起点位置与起始基因组。
pub fn cycle_state(state : @sm.SubjectState, genome : Genome) -> CycleState {
  { state, genome, }
}

///|
/// 一个回合的全部记录。
pub struct CycleEvent {
  round : Int
  state_before : @sm.SubjectState
  slot : @sm.Slot // 这一步由哪类结构关系驱动
  outcome : @sm.Outcome // 迁／守／未定→已裁决／无路
  state_after : @sm.SubjectState
  genome_after : Genome // 闸门裁决后的配置：改动全部过闸，绝不绕行
  response : Fitness // 世界回应：真跑遭遇得到的四分量
  practice : Offer // F_t 之一：修习候选（残余 −4）及其裁决
  opening : Offer // F_t 之二：开放候选（己之诚 −25）及其裁决
  remainder : String // 未穷尽者，恒非空
}

///|
/// 一次主体循环。
pub struct SubjectCycle {
  seed : CycleState
  objective : String
  events : Array[CycleEvent]
}

///|
/// 世界回应的形状 → 该位置的驱动槽。
///
/// 只在该位置**有出边**的槽里按优先序找（`@sm.exitable`）：有病理先看揭蔽（遮蔽被
/// 撑破）、再看共在（把善意递给对方）；无病理而有共识先看反馈（好的返回）；两者都
/// 无则先看行动（只能自己动手）。次序是模型整理，出处依 R3（解蔽—遮蔽）、
/// R7／R8（他者）与原文的「不得不」「静待下一刻」。
fn cycle_slot(f : Fitness, at : @sm.SubjectState) -> @sm.Slot {
  let order = if f.stability < 100 {
    [
      @sm.Unveil,
      @sm.CoBeing,
      @sm.Feedback,
      @sm.Act,
      @sm.Orientation,
      @sm.Occasion,
      @sm.Hold,
      @sm.Antecedent,
    ]
  } else if f.consensus >= 50 {
    [
      @sm.Feedback,
      @sm.CoBeing,
      @sm.Unveil,
      @sm.Act,
      @sm.Orientation,
      @sm.Occasion,
      @sm.Hold,
      @sm.Antecedent,
    ]
  } else {
    [
      @sm.Act,
      @sm.Orientation,
      @sm.CoBeing,
      @sm.Unveil,
      @sm.Feedback,
      @sm.Occasion,
      @sm.Hold,
      @sm.Antecedent,
    ]
  }
  let out = @sm.Act // 兜底：每位置都有出边，出边必有槽，循环内必被覆盖
  for k in order {
    if @sm.exitable(at, k) {
      return k
    }
  }
  out
}

///|
/// 「未定」的裁决：由主体的**双诚之比**在并存的路里挑一条（模型整理）。
///
/// 他之诚更盛→空间侧（后一条：疏离／交织／敬畏，朝向他者与未来）；
/// 持平或己之诚更盛→时间侧（先一条：紧迫／沉淀／受赏，朝向自身与已往，即原文主线）。
fn resolve_open(
  out : @sm.Outcome,
  genome : Genome,
  at : @sm.SubjectState,
) -> @sm.Outcome {
  match out {
    @sm.Open(cands) => {
      if cands.length() < 2 {
        return out
      }
      let pick = if genome.toward_other > genome.toward_self {
        cands.length() - 1
      } else {
        0
      }
      let c = cands[pick]
      if c.1 == at {
        @sm.Held(c.0, c.1)
      } else {
        @sm.Moved(c.0, c.1)
      }
    }
    other => other
  }
}

///|
/// 跑 `rounds` 回合主体循环：真跑遭遇得回应 → 挑可走的驱动槽 → `@sm.step` 得回执
/// → 修习与开放各过一个闸门 → 位置按回执、配置按裁决推进。
///
/// 裁决先问备忘录（`replay.mbt`）：被拒不推进配置，后续回合的输入与首裁逐字节
/// 相同——同一份证据不重裁，判词以「[与回合 N 同判·不重裁]」标注入账。
pub fn run_cycle(
  seed : CycleState,
  world : Array[Opponent],
  criterion : Criterion,
  rounds : Int,
) -> SubjectCycle {
  let objective = match criterion {
    Weighted(o) => o
    Causal(p) => p.objective
  }
  let events : Array[CycleEvent] = []
  let memo = DecisionMemo::new()
  let mut cur = seed
  for round = 0; round < rounds; round = round + 1 {
    let g = cur.genome
    let response = memo.response(g, round, () => evaluate(g, world))
    let parent_score = score(response, objective)
    let slot = cycle_slot(response, cur.state)
    let raw = @sm.step(cur.state, slot)
    let outcome = resolve_open(raw, g, cur.state)
    let moved_to = match outcome.landing() {
      Some(next) => next
      None => cur.state
    }
    // 修习：残余再降 4，降到 1 为止（R10 不许把不确定性进化掉）。
    let shed = if cur.genome.carry - 4 < 1 { 1 } else { cur.genome.carry - 4 }
    let practice = offer(
      g,
      Candidate::{
        locus: Memory,
        what: "修习：残余 \{g.carry} → \{shed}",
        genome: { ..g, carry: shed, },
      },
      world,
      parent_score,
      criterion,
      memo,
      round,
    )
    // 开放：己之诚降 25（遭遇要求自身不再抱得太紧），降到 1 为止。
    let loosen = if cur.genome.toward_self - 25 < 1 {
      1
    } else {
      cur.genome.toward_self - 25
    }
    let opening = offer(
      g,
      Candidate::{
        locus: Strategy,
        what: "开放：己之诚 \{g.toward_self} → \{loosen}",
        genome: { ..g, toward_self: loosen, },
      },
      world,
      parent_score,
      criterion,
      memo,
      round,
    )
    let mut next_genome = cur.genome
    if practice.decision.verdict == Accepted {
      next_genome = practice.candidate.genome
    }
    if opening.decision.verdict == Accepted {
      next_genome = opening.candidate.genome
    }
    let raw_note = match raw {
      @sm.Open(_) => "并存未定，已按双诚之比裁决"
      @sm.Block(_) => "此槽在此位置无路，位置不动"
      _ => "回执唯一"
    }
    let remainder = "\{cur.state.designation()}由「\{slot.designation()}」驱动：\{raw_note}；残余 \{next_genome.carry}、他之诚 \{next_genome.toward_other}、己之诚 \{next_genome.toward_self}——界域随时重开，本步未穷尽。"
    events.push({
      round,
      state_before: cur.state,
      slot,
      outcome,
      state_after: moved_to,
      genome_after: next_genome,
      response,
      practice,
      opening,
      remainder,
    })
    cur = { state: moved_to, genome: next_genome, }
  }
  { seed, objective: objective.name, events, }
}

///|
/// 把候选送进闸门，成对返回（复用 `breed` 里的 `Offer`）；裁决先问备忘录——
/// 同一份证据不重裁（见 `replay.mbt`）。
fn offer(
  parent : Genome,
  c : Candidate,
  world : Array[Opponent],
  parent_score : Int,
  criterion : Criterion,
  memo : DecisionMemo,
  round : Int,
) -> Offer {
  let d = memo.judgement(parent, c, round, () => {
    judge(parent, parent_score, c, world, criterion)
  })
  { candidate: c, decision: d, }
}

///|
/// 走完之后的主体（无回合即原样返回种子）。
pub fn SubjectCycle::finished(self : SubjectCycle) -> CycleState {
  let n = self.events.length()
  if n == 0 {
    return self.seed
  }
  let last = self.events[n - 1]
  { state: last.state_after, genome: last.genome_after, }
}

///|
/// 全部回合的修习裁决，只追加成一本账（可 `serialize`／`parse` 往返）。
pub fn SubjectCycle::ledger(self : SubjectCycle) -> Ledger {
  let trails : Array[Trail] = []
  let mut i = 0
  for e in self.events {
    let d = e.practice.decision
    trails.push({
      generation: e.round,
      step: 0,
      parent: if i == 0 {
        None
      } else {
        Some(i - 1)
      },
      locus: e.practice.candidate.locus,
      what: e.practice.candidate.what,
      why: d.reason,
      verdict: d.verdict,
      score: d.score,
      effect: d.effect,
      effect_lo: d.effect_lo,
      fitness: d.fitness,
      genome: e.practice.candidate.genome,
    })
    i += 1
  }
  { seed: self.seed.genome, objective: self.objective, trails, }
}

///|
/// 一行回合摘要：位置迁移、世界回应、两个 F_t 裁决。
fn event_line(e : CycleEvent) -> String {
  let f = e.response
  let p = e.practice.decision
  let o = e.opening.decision
  "\{e.state_before.designation()} --\{e.slot.designation()}--> \{e.state_after.designation()}（\{e.outcome.label()}）｜共识 \{f.consensus} · 稳定 \{f.stability} · 残余 \{f.residue} · 代价 \{f.cost}｜修习 \{p.verdict.label()} · 开放 \{o.verdict.label()}"
}

///|
/// 主体循环的文字报告。
pub fn render_cycle_report(c : SubjectCycle) -> String {
  let lines : Array[String] = [
    "# 主体循环 · 位置 × 驱动槽 × 因果反馈", "",
  ]
  lines.push(
    "种子：\{c.seed.state.qualified()}｜判据：\{c.objective}｜回合 \{c.events.length()}",
  )
  lines.push("")
  lines.push("## 逐回合")
  for e in c.events {
    lines.push("- \{event_line(e)}")
    lines.push("  判词·修习：\{e.practice.decision.reason}")
    lines.push("  判词·开放：\{e.opening.decision.reason}")
    lines.push("  未穷尽：\{e.remainder}")
  }
  let visited : Array[String] = []
  for e in c.events {
    let d = e.state_before.designation()
    let mut seen = false
    for x in visited {
      if x == d {
        seen = true
      }
    }
    if !seen {
      visited.push(d)
    }
  }
  lines.push("")
  lines.push("足迹（不重复）：\{visited.join(" → ")}")
  let fin = c.finished()
  lines.push("")
  lines.push(
    "止于 \{fin.state.qualified()}｜残余 \{fin.genome.carry} · 他之诚 \{fin.genome.toward_other} · 己之诚 \{fin.genome.toward_self}",
  )
  let led = c.ledger()
  lines.push("")
  lines.push(
    "账本：\{led.trails.length()} 条只追加；接收 \{led.accepted_count()} 条 · 拒收 \{led.rejected_count()} 条；往返一致 = \{(parse(led.serialize()).trails.length() == led.trails.length())}",
  )
  lines.push("")
  lines.push(
    "位置推进只由「位置 × 驱动槽」的迁移表给；「未定」由双诚之比裁决；一切配置改动都过闸门——反馈不由标签给出。",
  )
  lines.push("")
  lines.push(
    "直觉读法（模型整理）：同判不重裁是「持存」的取回，回溯持平是「揭蔽」的通过；出处见账本的首裁回合。全文见 `intuition`。",
  )
  lines.join("\n")
}

///|
/// 示范循环：默认主体从立位起，在默认世界里走 12 回合（因果判据）。
pub fn demo_cycle() -> SubjectCycle {
  run_cycle(
    cycle_state(@sm.Standing, default_agent()),
    default_world(),
    causal_criterion(200),
    12,
  )
}

///|
/// 缺省起点：立位上的默认主体。
pub fn default_cycle_seed() -> CycleState {
  cycle_state(@sm.Standing, default_agent())
}

///|
/// 整机自检：位置推进只走迁移表、每步都有未穷尽者、配置改动皆合宪、残余恒 ≥1。
pub fn SubjectCycle::legal(self : SubjectCycle) -> Bool {
  for e in self.events {
    if e.remainder.length() == 0 {
      return false
    }
    if e.genome_after.carry < 1 || !constitutional(e.genome_after) {
      return false
    }
    let label = e.outcome.label()
    if label == "未定" || label == "无路" {
      if e.state_after != e.state_before {
        return false
      }
    } else {
      let mut found = e.state_after == e.state_before
      for entry in @sm.successors(e.state_before) {
        if entry.1 == e.state_after {
          found = true
        }
      }
      if !found {
        return false
      }
    }
  }
  true
}

///|
/// 不封闭：循环经过的每个位置都仍有出边——没有哪一步抵达「不必再走」的地方。
pub fn SubjectCycle::never_closed(self : SubjectCycle) -> Bool {
  for e in self.events {
    if @sm.successors(e.state_before).length() == 0 {
      return false
    }
    if @sm.successors(e.state_after).length() == 0 {
      return false
    }
  }
  true
}
