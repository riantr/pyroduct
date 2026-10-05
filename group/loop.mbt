///|
/// 执行契约：把「位置 + 群体触发」投影到迁移表上（`src::loop.mbt` 的同构件，
/// 0.1.27）。
///
/// **与 `emerge` 回答两个不同的问题，不要混用**：
/// - `emerge(成员配置)` = **这群人现在是什么状态**——配置 → 涌现态的分类函数；
/// - `step(位置, 触发)` = **这句群体事件把它推向哪里**——表上的投影。
/// 一次涌现不必然经过某条边，反之亦然；两者互不替代。
///
/// 群体机**没有驱动槽**（那是主体机为「同一处境两条路」设的建模装置，属模型整理），
/// 触发句本身就是驱动，所以回执比 `src` 少一种：没有「多来处同归一处」——
/// 那种形态要先有槽才谈得上。剩下的三种确定形态是：
/// `Moved`（唯一出路）／`Held`（出路回到自身）／`Block`（此处无此事的边，缺口）。
///
/// 第四种 `Open` 在这里**不是**槽粒度的并列，而是**一句触发、两个去处**——
/// 表里 `Converging × Attention` 就是这样（注意汇聚既可通向共同语言、也可通向
/// 商谈）。这**是表里有意的一处**，不是笔误：作者已确认注意力汇聚之后既可能落成
/// 共同语言，也可能直接进入商谈。机器不替这份表挑一个去处，如实并列。
///
/// 这一处的「未定」有实义：那一刻群体**还没做任何事**，行为未发生，所以超主体性
/// 与主体间性哪一个显影**还没有结果可判**。判据成立之前的样子，机器不补。
///
/// 成体之后两者**同为常态**：如同波的振动，由群体行为的结果判定，不是一次性的
/// 达成。表里两相各有自环（延续当前相位），且有双向跨态边（换相）：
/// `CommonTongue --RaiseClaims--> Discourse`（共享传统上冒出有效性主张）、
/// `Discourse --SharedMedium--> CommonTongue`（讨论里差异消弭）。
///
/// `src` 保持零 import 的规矩在 `src` 自己那边；本包本就依赖 `src`／`multi`，
/// 但本文件不新增任何依赖。

///|
/// 一次 `step` 的回执。
pub(all) enum GroupOutcome {
  Moved(GroupTrigger, GroupState) // 唯一出路：由该触发迁到该状态
  Held(GroupTrigger, GroupState) // 出路回到自身：位置不变（沉淀、静待）
  Open(GroupTrigger, Array[GroupState]) // 一句触发、多个去处：不替表挑一个
  Block(String) // 此状态无此触发：缺口，不许编造
} derive(Eq)

///|
pub extend GroupOutcome with Eq::{not_equal, equal}

///|
/// 成体内**当下显影的那一侧**——不是偏好。超主体性与主体间性如同波的振动，
/// **两者都是常态**：这一轮群体做出什么行为，就判读到哪一侧，下一轮可能换相。
/// 所以这里没有「更可取」的一侧，写成枚举只是为了让「本轮哪一侧」成为一个
/// 可以被读、被写、被变异验证的输入。
///
/// `Converging × Attention` 给 `Open` 是因为那一刻群体**还没做**任何事——行为未
/// 发生，结果就还没定，这正是判据成立之前的样子，不该由机器补上。
///
/// 命名沿用两字纪律，只指称结构关系：
pub(all) enum GroupLean {
  Supra // 超体：超主体性显影（共同语言／传统承担理解）
  Inter // 间体：主体间性显影（相互提出有效性主张）
} derive(Eq)

///|
pub extend GroupLean with Eq::{not_equal, equal}

///|
pub fn GroupLean::label(self : GroupLean) -> String {
  match self {
    Supra => "超体"
    Inter => "间体"
  }
}

///|
/// 无参行走与报告叙述用的口径：**不是优先级**，只声明「若上层未另行判读，就按
/// 这一侧叙述」。真正的相位由上层按本轮行为给出（见 `resolve_open`）。
///
/// 之所以不给它一个哲学地位：两侧是常态震荡的两相，先验地给一相加权等于把
/// 判读变成了偏好——那正是「常态」不容许的。
pub fn default_lean() -> GroupLean {
  Supra
}

///|
/// `Open` 的裁决：在并存的去处里按**本轮判读到的那一侧**挑一个，其余回执原样透传。
///
/// 取料与判定分开，同 `open_pairs`／`one_edge_each` 的理由：真表上只有一处 `Open`
///，所以判据必须能造出**两侧都会翻面**的输入才验得住。测试喂**造出来的**候选
/// 清单，两种相位各驱动一次。
///
/// 候选按迁移表行序，故 `Supra` 取第一条（表里是共语）、`Inter` 取最后一条
/// （表里是商谈）——与 `step` 收集候选的读法一致，可重放。表里两个相位之间另有
/// 震荡边（`RaiseClaims`／`SharedMedium`），所以判到哪一侧都能继续往下走。
pub fn resolve_open(
  out : GroupOutcome,
  lean : GroupLean,
  at : GroupState,
) -> GroupOutcome {
  match out {
    Open(trig, cands) => {
      if cands.length() < 2 {
        return out
      }
      let to = match lean {
        Supra => cands[0]
        Inter => cands[cands.length() - 1]
      }
      if to == at {
        Held(trig, to)
      } else {
        Moved(trig, to)
      }
    }
    other => other
  }
}

///|
/// 回执的名。
pub fn GroupOutcome::label(self : GroupOutcome) -> String {
  match self {
    Moved(_, _) => "迁"
    Held(_, _) => "守"
    Open(_, _) => "未定"
    Block(_) => "无路"
  }
}

///|
/// 回执落到的状态；`Open` 与 `Block` 无定位（返回 `None`）。
pub fn GroupOutcome::landing(self : GroupOutcome) -> GroupState? {
  match self {
    Moved(_, to) => Some(to)
    Held(_, s) => Some(s)
    Open(_, _) => None
    Block(_) => None
  }
}

///|
/// 走一步：取 `state` 出发、由 `trigger` 驱动的全部边，据其数目给回执。
///
/// 候选按迁移表的顺序收集，故结果可重放。一条都没有就是缺口——群体机同样不许
/// 为没发生过的事编造下一步。
pub fn step(state : GroupState, trigger : GroupTrigger) -> GroupOutcome {
  let to : Array[GroupState] = []
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
pub fn exitable(state : GroupState, trigger : GroupTrigger) -> Bool {
  for t in transitions() {
    if t.from == state && t.trigger == trigger {
      return true
    }
  }
  false
}

///|
/// 一句触发、两个去处的组合（`Open` 的全部来源）。报告与测试从这里取料。
pub fn open_pairs() -> Array[(GroupState, GroupTrigger, Array[GroupState])] {
  let out : Array[(GroupState, GroupTrigger, Array[GroupState])] = []
  for s in all_states() {
    let seen : Array[GroupTrigger] = []
    for t in transitions() {
      if t.from == s && !seen.contains(t.trigger) {
        seen.push(t.trigger)
      }
    }
    for k in seen {
      let to : Array[GroupState] = []
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
/// 纯函数版：给全部位置与「有出边的位置」两份清单，不封闭 = 后者覆盖前者。
///
/// 取料与判定分开，同 `src::one_edge_each` 的理由：真表上 `no_dead_end` 恒为
/// `true`，只看真表的判据分不出「检查在跑」与「检查恒真」——把函数改成
/// `if true { return true }` 在真表上照样通过。测试给它一份**造出来的**清单
/// （有位置不在出边清单里），那条 `false` 才验得住。
pub fn no_dead_end_of(
  states : Array[GroupState],
  froms : Array[GroupState],
) -> Bool {
  for s in states {
    if !froms.contains(s) {
      return false
    }
  }
  true
}

///|
/// 不封闭：每个状态都有出边，故群体机没有「走完即止」的末态
/// （`src` 的 `no_final_closure` 在这里的对应物）。
pub fn no_dead_end() -> Bool {
  let froms : Array[GroupState] = []
  for t in transitions() {
    froms.push(t.from)
  }
  no_dead_end_of(all_states(), froms)
}

///|
/// 一段行走的记录。`steps` 只追加；`Open`／`Block` 之后位置不变——未定与缺口
/// 都不许被写成「已经过去了」。
pub struct GroupTrace {
  start : GroupState
  steps : Array[(GroupTrigger, GroupOutcome)]
} derive(Eq)

///|
pub extend GroupTrace with Eq::{not_equal, equal}

///|
/// 按给定的事件序列走一段。
pub fn walk(start : GroupState, events : Array[GroupTrigger]) -> GroupTrace {
  let mut at = start
  let steps : Array[(GroupTrigger, GroupOutcome)] = []
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
pub fn GroupTrace::at(self : GroupTrace) -> GroupState {
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
pub fn GroupTrace::outcome_labels(self : GroupTrace) -> Array[String] {
  let out : Array[String] = []
  for entry in self.steps {
    out.push(entry.1.label())
  }
  out
}
