///|
/// 执行契约（`step`）：把「位置 + 驱动槽」投影到既有的迁移表上。
///
/// 主体层原先只能被**遍历**（`successors`／`reachable`／`course`），不能被**走一步**：
/// 五层里只有它没有执行契约。本文件补上这一步，同时守住三条界：
///
/// - `src` **不接环境**：槽内容由上层生产，本包只判关系（`src/moon.pkg` 无任何
///   import，`ml`／`multi` 反过来依赖它；环境一旦进来就成环）。
/// - **不是全函数的 S→S'**：`Block` 是一等回执。此槽在此位置无路可走时，不许编造
///   下一步——这正是「不封闭」（`society::no_final_closure` 的精神）在执行层的形态。
/// - **不替主体决断**：多条出路并存时返回 `Open`，不择其一。原文里同一处境确实
///   给出两条路（时间的有限无界与空间的无限有界，谁先到来并非机器的决定）。
///
/// 四个回执：`Moved`（唯一出路）／`Held`（出路回到自身，即 17 条自环）／
/// `Open`（并存未定）／`Block`（缺口）。

///|
/// 一次 `step` 的回执。
pub(all) enum Outcome {
  Moved(Trigger, SubjectState) // 唯一出路：由该触发迁到该位置
  Held(Trigger, SubjectState) // 出路回到自身：位置不变（沉淀、静待）
  Open(Array[(Trigger, SubjectState)]) // 多条出路并存：未定，不替主体决断
  Block(String) // 此槽在此位置无路：缺口，不许强行推进
} derive(Eq, Debug)

///|
/// 让 `==` 在 `Outcome` 上以方法形式可用（显式 extend，避免隐式提升）。
pub extend Outcome with Eq::{not_equal, equal}

///|
pub extend Outcome with Debug::{to_repr}

///|
/// 回执的名。
pub fn Outcome::label(self : Outcome) -> String {
  match self {
    Moved(_, _) => "迁"
    Held(_, _) => "守"
    Open(_) => "未定"
    Block(_) => "无路"
  }
}

///|
/// 回执落到的位置；`Open` 与 `Block` 无定位（返回 `None`，由调用方决定如何记录）。
pub fn Outcome::landing(self : Outcome) -> SubjectState? {
  match self {
    Moved(_, to) => Some(to)
    Held(_, s) => Some(s)
    Open(_) => None
    Block(_) => None
  }
}

///|
/// 走一步：取 `state` 出发、由 `slot` 驱动的全部边，据其数目给回执。
///
/// 候选按迁移表的顺序收集，故结果与表的书写顺序一致、可重放。
pub fn step(state : SubjectState, slot : Slot) -> Outcome {
  let cands : Array[(Trigger, SubjectState)] = []
  for t in transitions() {
    if t.from == state && t.trigger.slot() == slot {
      cands.push((t.trigger, t.to))
    }
  }
  if cands.length() == 0 {
    return Block(
      "\{state.designation()} 处没有「\{slot.designation()}」的出边",
    )
  }
  let targets : Array[SubjectState] = []
  for entry in cands {
    if !contains_state(targets, entry.1) {
      targets.push(entry.1)
    }
  }
  let first = cands[0]
  if targets.length() > 1 {
    Open(cands)
  } else if first.1 == state {
    Held(first.0, state)
  } else {
    Moved(first.0, first.1)
  }
}

///|
/// 一段行走的记录。`steps` 只追加；`Open`／`Block` 之后位置不变——
/// 未定与缺口都不许被写成「已经过去了」。
pub struct Trace {
  start : SubjectState
  steps : Array[(Slot, Outcome)]
} derive(Eq, Debug)

///|
pub extend Trace with Eq::{not_equal, equal}

///|
pub extend Trace with Debug::{to_repr}

///|
/// 按给定的槽序列走一段。
pub fn walk(start : SubjectState, slots : Array[Slot]) -> Trace {
  let mut at = start
  let steps : Array[(Slot, Outcome)] = []
  for s in slots {
    let out = step(at, s)
    steps.push((s, out))
    match out.landing() {
      Some(next) => at = next
      None => ()
    }
  }
  { start, steps, }
}

///|
/// 走完之后的位置。
pub fn Trace::at(self : Trace) -> SubjectState {
  let mut cur = self.start
  for entry in self.steps {
    match entry.1.landing() {
      Some(next) => cur = next
      None => ()
    }
  }
  cur
}

///|
/// 一步的明细：从哪个位置出发、经哪个驱动槽、得到什么回执。
/// `Trace.steps` 只记「槽 + 回执」，位置要靠重放才知道；`detailed` 把重放
/// 一次做完，供行程视图与上层逐条引用（模型整理：出处仍全在迁移表）。
pub(all) struct Step {
  from : SubjectState
  slot : Slot
  outcome : Outcome
} derive(Eq, Debug)

///|
pub extend Step with Eq::{not_equal, equal}

///|
pub extend Step with Debug::{to_repr}

///|
/// 逐步明细（含每步的出发位置），顺序与 `steps` 一致。
pub fn Trace::detailed(self : Trace) -> Array[Step] {
  let out : Array[Step] = []
  let mut at = self.start
  for entry in self.steps {
    out.push({ from: at, slot: entry.0, outcome: entry.1, })
    match entry.1.landing() {
      Some(next) => at = next
      None => ()
    }
  }
  out
}

///|
/// 回执的名。
pub fn Trace::outcome_labels(self : Trace) -> Array[String] {
  let out : Array[String] = []
  for entry in self.steps {
    out.push(entry.1.label())
  }
  out
}

///|
/// 该位置是否存在由该槽驱动的出边。
pub fn exitable(state : SubjectState, slot : Slot) -> Bool {
  let mut found = false
  for t in transitions() {
    if t.from == state && t.trigger.slot() == slot {
      found = true
    }
  }
  found
}

///|
/// 哪些位置有「由该槽驱动」的出边（顺序照 `all_states`；出边取自邻接索引，
/// 见 `index.mbt`）。
pub fn positions_reachable_by(slot : Slot) -> Array[SubjectState] {
  let idx = MovesIndex::build()
  let out : Array[SubjectState] = []
  for s in all_states() {
    let mut found = false
    for entry in idx.edges_from(s) {
      if entry.0.slot() == slot {
        found = true
      }
    }
    if found {
      out.push(s)
    }
  }
  out
}

///|
/// 全部缺口：位置 × 槽 中没有对应出边的组合（一次扫描建索引，272 次查询
/// 不再逐条重扫全表；顺序照 `all_states` × `all_slots`）。
pub fn gaps() -> Array[(SubjectState, Slot)] {
  let idx = MovesIndex::build()
  let out : Array[(SubjectState, Slot)] = []
  for s in all_states() {
    let outs = idx.edges_from(s)
    for k in all_slots() {
      let mut found = false
      for entry in outs {
        if entry.0.slot() == k {
          found = true
        }
      }
      if !found {
        out.push((s, k))
      }
    }
  }
  out
}

///|
/// 只有「行动」出边的位置：机器不是纯 agent 回路，但承认有这几个只能自己动手
/// 脱身的位置——立位（「基于行动的自由」），以及失权、自缚、沉落三步（「人于是
/// 将自己束缚起来」「为了重获自由，他力图斩断」）。
pub fn only_act_exits() -> Array[SubjectState] {
  let out : Array[SubjectState] = []
  for s in all_states() {
    let outs = successors(s)
    if outs.length() > 0 {
      let mut all_act = true
      for entry in outs {
        if entry.0.slot() != Act {
          all_act = false
        }
      }
      if all_act {
        out.push(s)
      }
    }
  }
  out
}

///|
/// 每个阶段都至少有一条非「行动」的出边（否则整段被还原成目的—手段回路）。
pub fn every_phase_has_non_act() -> Bool {
  for p in all_phases() {
    let mut found = false
    for t in transitions() {
      if t.from.phase() == p && t.trigger.slot() != Act {
        found = true
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
/// 执行契约的报告：缺口分布、四个例外位置、一次按八槽巡回的示范行走。
pub fn render_loop_report() -> String {
  let lines : Array[String] = ["# 执行契约 · 位置 × 驱动槽", ""]
  let combos = all_states().length() * all_slots().length()
  let blocked = gaps().length()
  lines.push(
    "位置 \{all_states().length()} × 槽 \{all_slots().length()} = \{combos} 个组合，其中 \{blocked} 个无出边（记为 `Block`，不编造下一步）。",
  )
  lines.push("")
  lines.push("## 每槽可推动的位置数")
  for k in all_slots() {
    lines.push(
      "- \{k.designation()}　\{positions_reachable_by(k).length()} 处",
    )
  }
  lines.push("")
  lines.push("## 只能由「行动」离开的位置")
  for s in only_act_exits() {
    lines.push("- \{s.designation()}　\{s.gloss()}")
  }
  lines.push("")
  lines.push("## 示范：从立位起，按八槽巡回走三轮")
  let plan : Array[Slot] = []
  for round = 0; round < 3; round = round + 1 {
    for k in all_slots() {
      plan.push(k)
    }
  }
  let trace = walk(initial(), plan)
  let mut moved = 0
  let mut held = 0
  let mut open = 0
  let mut blocked_count = 0
  for entry in trace.steps {
    match entry.1 {
      Moved(_, _) => moved += 1
      Held(_, _) => held += 1
      Open(_) => open += 1
      Block(_) => blocked_count += 1
    }
  }
  lines.push("")
  lines.push("行走：\{trace.outcome_labels().join(" → ")}")
  lines.push("")
  lines.push(
    "共 \{trace.steps.length()} 步：迁 \{moved} · 守 \{held} · 未定 \{open} · 无路 \{blocked_count}；起于 \{trace.start.designation()}，止于 \{trace.at().designation()}。",
  )
  lines.push("")
  lines.push(
    "巡回走不出这条历程：立位只有「行动」一条出边，到自由之后，处境同时给出紧迫与疏离两条路，机器停在「未定」而不替主体择其一。缺口与未定都是合法回执——宁可停在原处，不编造下一步。",
  )
  lines.join("\n")
}
