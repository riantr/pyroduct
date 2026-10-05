///|
/// 执行契约：把「位置 + 交往触发」投影到迁移表上（`src::loop.mbt` 的同构件，
/// 0.1.27）。
///
/// 与群体机一样，社会机**没有驱动槽**，触发就是驱动；所以回执与 `@group` 同形：
/// `Moved`／`Held`／`Block`，外加 `Open`（一句触发、两个去处）。
///
/// 但社会机**用不到 `Open`**：实测 26 条迁移里同一状态的同一触发只出现一次，
/// 即这张表在触发粒度上是确定的。这不是运气，是断言——`one_edge_per_trigger()`
/// 把它锁住；哪天表里出现一句触发两个去处，测试会红，而 `Open` 那条臂已经在那儿
/// 等着了（与群体机的 `Converging × Attention` 形成对照：那处是真并列）。
///
/// 本包保持零依赖（`society/moon.pkg` 无 import）：本文件只用本包自己的表。

///|
/// 一次 `step` 的回执。
pub(all) enum Outcome {
  Moved(Trigger, State) // 唯一出路：由该触发迁到该状态
  Held(Trigger, State) // 出路回到自身：位置不变（沉淀、静待）
  Open(Trigger, Array[State]) // 一句触发、多个去处：不替表挑一个（本表暂无此形）
  Block(String) // 此状态无此触发：缺口，不许编造
} derive(Eq)

///|
pub extend Outcome with Eq::{not_equal, equal}

///|
/// 回执的名。
pub fn Outcome::label(self : Outcome) -> String {
  match self {
    Moved(_, _) => "迁"
    Held(_, _) => "守"
    Open(_, _) => "未定"
    Block(_) => "无路"
  }
}

///|
/// 回执落到的状态；`Open` 与 `Block` 无定位（返回 `None`）。
pub fn Outcome::landing(self : Outcome) -> State? {
  match self {
    Moved(_, to) => Some(to)
    Held(_, s) => Some(s)
    Open(_, _) => None
    Block(_) => None
  }
}

///|
/// 走一步：取 `state` 出发、由 `trigger` 驱动的全部边，据其数目给回执。
pub fn step(state : State, trigger : Trigger) -> Outcome {
  let to : Array[State] = []
  for t in transitions() {
    if t.from == state && t.trigger == trigger {
      to.push(t.to)
    }
  }
  if to.length() == 0 {
    return Block(
      "「\{state.designation()}」处没有「\{trigger.label()}」的边",
    )
  }
  if to.length() > 1 {
    return Open(trigger, to)
  }
  if to[0] == state {
    Held(trigger, state)
  } else {
    Moved(trigger, to[0])
  }
}

///|
/// 该状态是否有该触发驱动的边。
pub fn exitable(state : State, trigger : Trigger) -> Bool {
  for t in transitions() {
    if t.from == state && t.trigger == trigger {
      return true
    }
  }
  false
}

///|
/// 同一状态的同一触发只出现一次——社会机的表在触发粒度上确定，故 `step` 的回执
/// 只有迁／守／无路三种（`Open` 那条臂备而不用，见文件头）。
pub fn one_edge_per_trigger() -> Bool {
  for s in all_states() {
    let seen : Array[Trigger] = []
    for t in transitions() {
      if t.from == s {
        if seen.contains(t.trigger) {
          return false
        }
        seen.push(t.trigger)
      }
    }
  }
  true
}

///|
/// 一句触发、两个去处的组合（本表应为空；非空即说明表变了，`step` 会给 `Open`）。
pub fn open_pairs() -> Array[(State, Trigger, Array[State])] {
  let out : Array[(State, Trigger, Array[State])] = []
  for s in all_states() {
    let seen : Array[Trigger] = []
    for t in transitions() {
      if t.from == s && !seen.contains(t.trigger) {
        seen.push(t.trigger)
      }
    }
    for k in seen {
      let to : Array[State] = []
      for t in transitions() {
        if t.from == s && t.trigger == k {
          to.push(t.to)
        }
      }
      if to.length() > 1 {
        out.push((s, k, to))
      }
    }
  }
  out
}

///|
/// 不封闭：每个状态都有出边（`no_final_closure` 是「宁静↺反顾」那条重入边的
/// 另一种说法，这里补上「没有走完即止的末态」这一层）。
pub fn no_dead_end() -> Bool {
  for s in all_states() {
    let mut found = false
    for t in transitions() {
      if t.from == s {
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
/// 一段行走的记录。`Open`／`Block` 之后位置不变。
pub struct Trace {
  start : State
  steps : Array[(Trigger, Outcome)]
} derive(Eq)

///|
pub extend Trace with Eq::{not_equal, equal}

///|
/// 按给定的事件序列走一段。
pub fn walk(start : State, events : Array[Trigger]) -> Trace {
  let mut at = start
  let steps : Array[(Trigger, Outcome)] = []
  for k in events {
    let out = step(at, k)
    steps.push((k, out))
    match out.landing() {
      Some(next) => at = next
      None => ()
    }
  }
  { start, steps, }
}

///|
/// 走完之后的状态。
pub fn Trace::at(self : Trace) -> State {
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
/// 回执的名。
pub fn Trace::outcome_labels(self : Trace) -> Array[String] {
  let out : Array[String] = []
  for entry in self.steps {
    out.push(entry.1.label())
  }
  out
}
