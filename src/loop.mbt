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
///
/// 五个回执：`Moved`（唯一出路）／`Held`（出路回到自身，即 17 条自环）／
/// `Open`（多条**去处**并存，未定）／`Same`（多条**来处**归到同一个去处——
/// 去处确定，来的那句不确定，机器不点名）／`Block`（缺口）。
///
/// `Same` 与 `Open` 分开是必要的：两者的「不确定」不在一个维度上。
/// `Open` 是**去哪儿**没定，要主体决断；`Same` 是**从哪句来**没定而去哪儿已定，
/// 无需决断，只需不编造（0.1.26 增；此前 `step` 在这种组合上直接报出迁移表
/// 里第一条，等于替环境说了一句它没说过的话）。
pub(all) enum Outcome {
  Moved(Trigger, SubjectState) // 唯一出路：由该触发迁到该位置
  Held(Trigger, SubjectState) // 出路回到自身：位置不变（沉淀、静待）
  Open(Array[(Trigger, SubjectState)]) // 多条出路并存：未定，不替主体决断
  Same(Slot, Array[Trigger], SubjectState) // 同归：多条触发归到同一目标，只给槽与目标
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
    Same(_, _, _) => "同归"
    Block(_) => "无路"
  }
}

///|
/// 回执落到的位置；`Open` 与 `Block` 无定位（返回 `None`，由调用方决定如何记录）。
///
/// `Same` **有**定位：它的目标就是确定的（多条来处同归一处），只有来处不名，
/// 所以行程照常推进——不确定的是「为什么」，不是「到哪儿」。
pub fn Outcome::landing(self : Outcome) -> SubjectState? {
  match self {
    Moved(_, to) => Some(to)
    Held(_, s) => Some(s)
    Open(_) => None
    Same(_, _, to) => Some(to)
    Block(_) => None
  }
}

///|
/// 位置 × 槽上的全部候选边：迁移表里从 `state` 出发、由 `slot` 推动的边，
/// 按表的书写顺序收集（故结果可重放）。
///
/// 这是「此处此槽可能发生什么」的**唯一**取料处：`step` 的候选、`expand` 的
/// 分叉、`after_open` 的起点都走它。分开各写一份等于给同一件事留几个说法，
/// 迟早对不上。
pub fn candidates(
  state : SubjectState,
  slot : Slot,
) -> Array[(Trigger, SubjectState)] {
  let out : Array[(Trigger, SubjectState)] = []
  for t in transitions() {
    if t.from == state && t.trigger.slot() == slot {
      out.push((t.trigger, t.to))
    }
  }
  out
}

///|
/// 把回执拆成它**允许的每一条**确定走法。`at` 是该回执的出发位置（用来分
/// 「迁」与「守」：候选若是自环，那一步仍是守）。
///
/// 拆开**不引入任何新事实**：`Open` 的每个候选、`Same` 的每条触发句都是迁移
/// 表里真实存在的那条边，拆开后逐条点名不算编造——它说的是「**若是**这一句，
/// 则到这儿」，条件与结论都摆在明面上。这与 `step` 拒绝点名同归触发不矛盾：
/// 那里是**无条件**点名（把表里排第一的那条当成了发生过的话），这里是**条件**
/// 点名。调用方拿到这份清单即可自己定策——这就是「未定可编程」的落点：
/// 决断权在主体（`evolution` 的双诚之比）与上层，不在 `src`。
///
/// `Block`（缺口）不给任何走法：此处无路，展开不能凭空造一条——缺口一旦能被
/// 展开，缺口就名存实亡。
pub fn Outcome::forks_from(self : Outcome, at : SubjectState) -> Array[Outcome] {
  let out : Array[Outcome] = []
  match self {
    Moved(tr, to) => out.push(Moved(tr, to))
    Held(tr, s) => out.push(Held(tr, s))
    Open(cands) =>
      for c in cands {
        out.push(resolved(c.0, c.1, at))
      }
    Same(_, named, to) =>
      for tr in named {
        out.push(resolved(tr, to, at))
      }
    Block(_) => ()
  }
  out
}

///|
/// 边落回自身则记「守」，否则记「迁」——与 `step` 同一判据，不另立一套。
fn resolved(tr : Trigger, to : SubjectState, at : SubjectState) -> Outcome {
  if to == at {
    Held(tr, to)
  } else {
    Moved(tr, to)
  }
}

///|
/// 走一步：取 `state` 出发、由 `slot` 驱动的全部边，据其数目给回执。
///
/// 槽粒度**认不出是哪一句**——同一槽在这个位置可能挂着多条触发句。所以只有
/// 候选恰好一条时它才点名（`Moved`／`Held`）；多条归到同一目标时给 `Same`
/// （去处确定、来处不名），多条归到不同目标时给 `Open`。要知道是哪一句，
/// 调 `step_by_trigger`。
pub fn step(state : SubjectState, slot : Slot) -> Outcome {
  let cands = candidates(state, slot)
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
    return Open(cands)
  }
  if cands.length() > 1 {
    // 同归：多条不同的触发句归到同一个目标。报出其中一条就是编造——`Block`
    // 存在的全部意义是不许编造下一步，同一条纪律不许编造上一步的触发。
    let named : Array[Trigger] = []
    for entry in cands {
      named.push(entry.0)
    }
    return Same(slot, named, first.1)
  }
  if first.1 == state {
    Held(first.0, state)
  } else {
    Moved(first.0, first.1)
  }
}

///|
/// 触发粒度走一步：只认这一句。
///
/// 槽粒度的 `step` 在多条触发同归一个目标时无从知道是哪一条发生过，于是不
/// 点名（`Same`）；本函数把「是哪一句」交给调用方：这一句确实是此处的出边，
/// 就给确定的回执（位置若回自身则是 `Held`），不是则如实报缺口。
///
/// 前提：同一位置的同一条触发句不出现两次（`one_edge_per_trigger` 锁住）。
/// 万一表有歧义，也不猜——报缺口而不是替表挑一条。
pub fn step_by_trigger(state : SubjectState, trigger : Trigger) -> Outcome {
  let hits : Array[SubjectState] = []
  for t in transitions() {
    if t.from == state && t.trigger == trigger {
      hits.push(t.to)
    }
  }
  if hits.length() == 0 {
    return Block(
      "「\{trigger.label()}」不是「\{state.designation()}」的出边",
    )
  }
  if hits.length() > 1 {
    return Block(
      "「\{trigger.label()}」从「\{state.designation()}」出发有多条出边——表有歧义，不猜",
    )
  }
  let to = hits[0]
  if to == state {
    Held(trigger, state)
  } else {
    Moved(trigger, to)
  }
}

///|
/// 同一位置的同一条触发句不出现两次（`step_by_trigger` 的前提；表若有歧义，
/// 那处本身就该复查，不该由机器替它选一条）。
pub fn one_edge_per_trigger() -> Bool {
  for s in all_states() {
    let seen : Array[Trigger] = []
    for t in transitions() {
      if t.from == s && !contains_trigger(seen, t.trigger) {
        seen.push(t.trigger)
      } else if t.from == s {
        return false
      }
    }
  }
  true
}

///|
/// 槽粒度下「多条触发同归一个目标」的组合：`step` 对这些组合不再点名触发。
/// 报告与测试都从这里取料，不另写一份清单。
pub fn same_target_pairs() -> Array[
  (SubjectState, Slot, Array[Trigger], SubjectState),
] {
  let out : Array[(SubjectState, Slot, Array[Trigger], SubjectState)] = []
  for s in all_states() {
    for k in all_slots() {
      let cands : Array[(Trigger, SubjectState)] = []
      for t in transitions() {
        if t.from == s && t.trigger.slot() == k {
          cands.push((t.trigger, t.to))
        }
      }
      if cands.length() < 2 {
        continue
      }
      let targets : Array[SubjectState] = []
      for entry in cands {
        if !contains_state(targets, entry.1) {
          targets.push(entry.1)
        }
      }
      if targets.length() == 1 {
        let named : Array[Trigger] = []
        for entry in cands {
          named.push(entry.0)
        }
        out.push((s, k, named, targets[0]))
      }
    }
  }
  out
}

///|
/// 全部未定点：位置 × 槽中**去处**不止一个的组合，即 `step` 给 `Open` 的那些
/// （带候选边条数）。
///
/// 与 `same_target_pairs` 是一对：那一个列「来处多而去处一」，这一个列「去处
/// 多」，两者互斥且并集恰是全部多候选组合。报告与测试都从这里取料。
pub fn open_points() -> Array[(SubjectState, Slot, Int)] {
  let out : Array[(SubjectState, Slot, Int)] = []
  for s in all_states() {
    for k in all_slots() {
      match step(s, k) {
        Open(cands) => out.push((s, k, cands.length()))
        _ => ()
      }
    }
  }
  out
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
/// 一批走法的展开结果。
///
/// `truncated` 为真表示撞上了 `limit` 上界，故 `leaves` **不是全部**。这
/// 件事写在结果里而不是只写在文档里：静默截断的结果会被读成「所有可能的后续」，
/// 而它其实不是——这正是本层一路在防的那类误读（不编造下一步、不编造上一步、
/// 不把「停住」说成「走完了」）。
pub(all) struct Expansion {
  leaves : Array[Trace]
  truncated : Bool
} derive(Eq, Debug)

///|
pub extend Expansion with Eq::{not_equal, equal}

///|
pub extend Expansion with Debug::{to_repr}

///|
/// 展开：自 `start` 起按给定的槽序列走一段，遇到**未定**就按表里的候选分叉。
///
/// `walk` 收一条固定槽序列，走过未定点就停在原处（`Open` 无落点，位置不变）。
/// 本函数回答的是那句没答上的话——未定之后**所有**可能的后续是什么：同一个
/// 槽序列，路径按 `Open` 的候选数扇出，每个叶子是一条把每个未定点都选定好的
/// 完整行程。
///
/// 三条纪律：
///
/// - **只在 `Open` 处分叉。** `Same` 的去处已定，分叉只会造出 N 条位置完全相同、
///   只差一句「没说是哪句」的走法，等于在树上把「来处不名」又点名了一次；来处
///   要逐条看，`Outcome::forks_from` 单给。
/// - **缺口不终止行程。** `Block` 之后位置不动、接着走下一个槽，与 `walk` 同一
///   读法；若在缺口处截断分支，`expand` 与 `walk` 就会对同一段脚本给出不同长度
///   的行程，缺的那些后续才是被藏起来的。
/// - **分叉不增事实。** 每个叶子都由表里的真实边组成，故叶子数必等于沿途
///   `Open` 候选数之积——这条是判据，不是设计愿望。
/// - **上界要说出来。** 机器有意成环（`is_acyclic` 恒 `false`），故展开必然要
///   有界；`limit` 是走法条数上限，撞上了就置 `truncated`。
pub fn expand(
  start : SubjectState,
  slots : Array[Slot],
  limit : Int,
) -> Expansion {
  let (leaves, truncated) = expand_from(start, start, [], slots, 0, limit)
  { leaves, truncated, }
}

///|
/// 展开的递归内芯。返回（叶子，是否撞上界）。`budget` 是还能产出的走法条数。
fn expand_from(
  origin : SubjectState,
  at : SubjectState,
  steps : Array[(Slot, Outcome)],
  slots : Array[Slot],
  i : Int,
  budget : Int,
) -> (Array[Trace], Bool) {
  if budget <= 0 {
    return ([], true)
  }
  if i >= slots.length() {
    return ([{ start: origin, steps, }], false)
  }
  let slot = slots[i]
  let out = step(at, slot)
  match out {
    // 未定：按候选扇出。`forks_from` 给的每一条都是表里的真实边。
    Open(_) => {
      let leaves : Array[Trace] = []
      let mut left = budget
      let mut truncated = false
      for one in out.forks_from(at) {
        let next = match one.landing() {
          Some(s) => s
          None => at
        }
        let (sub, cut) = expand_from(
          origin,
          next,
          push_step(steps, slot, one),
          slots,
          i + 1,
          left,
        )
        for t in sub {
          leaves.push(t)
        }
        left -= sub.length()
        if cut {
          truncated = true
          break
        }
      }
      (leaves, truncated)
    }
    // 同归／迁／守：去处确定，单线继续（`forks_from` 于此处恰给一条）。
    _ => {
      let advanced = push_step(steps, slot, out)
      let next = match out.landing() {
        Some(s) => s
        // 无路：位置不动，接着走下一个槽——与 `walk` 同一读法。缺口不是终点，
        // 只是这一步走不出去；在这里终止分支会让 `expand` 与 `walk` 对同一段
        // 脚本给出不同长度的行程，那才是真正的「不编造后续」。
        None => at
      }
      expand_from(origin, next, advanced, slots, i + 1, budget)
    }
  }
}

///|
/// 追加一步并另存一份：展开里每条分支各持一份行程，不得互相看见。
fn push_step(
  steps : Array[(Slot, Outcome)],
  slot : Slot,
  outcome : Outcome,
) -> Array[(Slot, Outcome)] {
  let out : Array[(Slot, Outcome)] = []
  for entry in steps {
    out.push(entry)
  }
  out.push((slot, outcome))
  out
}

///|
/// `after_open` 的取料：`state` 处 `slot` 的未定点逐条候选边。
///
/// 「未定之后所有可能的后续」的字面回答：逐条候选边出发，**不预设后续的槽**
/// （未定之后推不推、推哪一槽，本来就还没定，故对全部八槽都算），至多 `depth`
/// 步内够得着的位置与各自的最少步数。
///
/// 与近邻三者的分工：`expand` 守着给定的槽序列往下走；`min_steps` 问「到某一个
/// 指定位置要几步」；本函数问「未定之后够得着的地方有哪些」。未定点本身不算
/// 后续——除非某条候选边绕回了它，那时它以自己的身份出现在清单里。
pub fn after_open(
  state : SubjectState,
  slot : Slot,
  depth : Int,
) -> Array[(SubjectState, Int)] {
  let dist : Map[String, Int] = Map([])
  let queue : Array[SubjectState] = []
  for c in candidates(state, slot) {
    if !dist.contains(c.1.designation()) {
      dist[c.1.designation()] = 1
      queue.push(c.1)
    }
  }
  let mut head = 0
  while head < queue.length() {
    let cur = queue[head]
    head += 1
    let d = match dist.get(cur.designation()) {
      Some(d) => d
      None => 1
    }
    if d >= depth {
      continue
    }
    for t in successors(cur) {
      if !dist.contains(t.1.designation()) {
        dist[t.1.designation()] = d + 1
        queue.push(t.1)
      }
    }
  }
  let out : Array[(SubjectState, Int)] = []
  for s in all_states() {
    match dist.get(s.designation()) {
      Some(d) => out.push((s, d))
      None => ()
    }
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
  lines.push("## 同归：去处确定，来处不名")
  lines.push(
    "槽粒度认不出是哪一句——下列组合在同一个位置挂着多条触发句且同归一个目标，",
  )
  lines.push(
    "故 `step` 给 `Same`（只给槽与目标，不点名）；要知道是哪一句，用 `step_by_trigger`。",
  )
  for pair in same_target_pairs() {
    let (s, k, named, to) = pair
    lines.push(
      "- \{s.designation()} × \{k.designation()} → \{to.designation()}（\{named.length()} 条）",
    )
    for tr in named {
      lines.push("    · \{tr.label()}")
    }
  }
  lines.push("")
  lines.push("## 未定的展开：去处未定时的所有可能后续")
  lines.push(
    "`walk` 只走一条给定的槽序列，撞上未定就停在原处。「所有可能的后续」是另一句问，",
  )
  lines.push(
    "由 `expand`（守着给定槽序列分叉）与 `after_open`（不预设后续的槽）两个函数回答；",
  )
  lines.push(
    "两者都不引入新事实——每个分支都是迁移表里真实存在的边。",
  )
  lines.push("")
  for op in open_points() {
    let (s, k, n) = op
    let reach = after_open(s, k, 3)
    lines.push(
      "- \{s.designation()} × \{k.designation()}　\{n} 条候选边；不预设后续的槽时，三步内够得着 \{reach.length()} 处",
    )
  }
  lines.push("")
  lines.push("### 示范：把下面那次八槽巡回展开成所有走法")
  let plan : Array[Slot] = []
  for round = 0; round < 3; round = round + 1 {
    for k in all_slots() {
      plan.push(k)
    }
  }
  let fan = expand(initial(), plan, 64)
  for leaf in fan.leaves {
    let marks : Array[String] = []
    for d in leaf.detailed() {
      if candidates(d.from, d.slot).length() > 1 {
        marks.push("\{d.from.designation()}〔\{d.slot.designation()}〕→")
      } else {
        marks.push("\{d.from.designation()}-\{d.slot.designation()}→")
      }
    }
    lines.push(
      "- \{marks.join(" ")} \{leaf.at().designation()}（\{leaf.steps.length()} 步）",
    )
  }
  lines.push("")
  lines.push(
    "\{fan.leaves.length()} 条走法，撞界 \{fan.truncated}。每条走法里都不再有「未定」——分叉时机器没有替主体择一，是把表里那几条并排摆出来，让人去选。",
  )
  lines.push("")
  lines.push("## 示范：从立位起，按八槽巡回走三轮")
  let trace = walk(initial(), plan)
  let mut moved = 0
  let mut held = 0
  let mut open = 0
  let mut same = 0
  let mut blocked_count = 0
  for entry in trace.steps {
    match entry.1 {
      Moved(_, _) => moved += 1
      Held(_, _) => held += 1
      Open(_) => open += 1
      Same(_, _, _) => same += 1
      Block(_) => blocked_count += 1
    }
  }
  lines.push("")
  lines.push("行走：\{trace.outcome_labels().join(" → ")}")
  lines.push("")
  lines.push(
    "共 \{trace.steps.length()} 步：迁 \{moved} · 守 \{held} · 未定 \{open} · 同归 \{same} · 无路 \{blocked_count}；起于 \{trace.start.designation()}，止于 \{trace.at().designation()}。",
  )
  lines.push("")
  lines.push(
    "巡回走不出这条历程：立位只有「行动」一条出边，到自由之后，处境同时给出紧迫与疏离两条路，机器停在「未定」而不替主体择其一。缺口与未定都是合法回执——宁可停在原处，不编造下一步。",
  )
  lines.join("\n")
}
