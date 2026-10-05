///|
/// 泛半环路径和（模型整理）：把 FiniteStateTransducers.jl（Idiap，OpenFST
/// 谱系）的 shortest_distance 与 properties 面移植到主体机上。
///
/// 参照库的路径和是**泛半环**的：权重取自一个半环（⊕/⊗/0̄/1̄），
/// `shortest_distance`（Mohri 2002）对 k-封闭且可分配的半环给出单源最短
/// 距离，`reversed` 变体从终态反算。pyroduct 的对应与取舍：
///
///   - **Boolean 半环**——路径存在性：`reachable`／`gaps` 已有（0.1.x）；
///   - **Tropical 半环**（⊕=min, ⊗=+, 0̄=∞, 1̄=0）——本文件的 `min_steps`：
///     每条边计一步，最短步数即 tropical 路径和。幂等故**循环安全**：
///     Held 自环与重入环不使路程发散（Mohri 框架对 k-封闭半环的收敛条件
///     在这里由幂等性满足）；
///   - **Probability 半环**——不在 src：概率住在 evolution（关联诊断的
///     β 权重，0.1.17；`先行` 槽不带数的纪律）。
///
/// 本仓库已经横跨三个半环而不自知：布尔（可达／缺口）、tropical（本文件）、
/// 概率（evolution）。本文件把这件事说出口。
///
/// 性质谓词（参照其 `properties.jl`）：`is_deterministic`——每 (位置, 触发)
/// 至多一条边，自动机层面确定；「未定」是**槽层面**的不确定（多个不同触发
/// 共占一槽），这就是 Open 恰在槽粒度出现、而触发粒度恒无歧义的原因。
/// `is_acyclic`——本机**有意成环**（自环 + 宁静→反顾→…→宁静的重入环）：
/// 重入正是「不封闭」的形态，故恒 false。**无 ε 弧**：每条边都消费一个真实
/// 触发句——pyroduct 是 acceptor（读触发序列），不是 transducer（无输出
/// 投影），这是与参照库的本质差异，也是构图纪律（出处挂在触发上）的结果。

///|
/// 最短步数（tropical 路径和）：从 `from` 到 `to` 最少几步；不可达返回 None。
/// 广度优先即 tropical 的实现（每边权重 0̄+1̄=1，⊕=min）。
pub fn min_steps(from : SubjectState, to : SubjectState) -> Int? {
  if from == to {
    return Some(0)
  }
  let dist : Map[String, Int] = Map([])
  dist[from.designation()] = 0
  let queue : Array[String] = [from.designation()]
  let mut head = 0
  while head < queue.length() {
    let cur = queue[head]
    head += 1
    let d = match dist.get(cur) {
      Some(d) => d
      None => 0
    }
    for t in transitions() {
      if t.from.designation() == cur && !dist.contains(t.to.designation()) {
        if t.to == to {
          return Some(d + 1)
        }
        dist[t.to.designation()] = d + 1
        queue.push(t.to.designation())
      }
    }
  }
  None
}

///|
/// 反向最短距离（参照库 shortest_distance 的 reversed 变体）：从 `to` 出发
/// 沿反边一次广度优先，给出**每个**位置到 `to` 的最短步数（照 `all_states`
/// 顺序；不可达为 None）。通往宁静之路，对每个位置各差几步。
pub fn distance_to(to : SubjectState) -> Array[(SubjectState, Int?)] {
  let rev : Map[String, Array[String]] = Map([])
  for t in transitions() {
    let key = t.to.designation()
    let arr = match rev.get(key) {
      Some(a) => a
      None => {
        let a : Array[String] = []
        rev[key] = a
        a
      }
    }
    arr.push(t.from.designation())
  }
  let dist : Map[String, Int] = Map([])
  dist[to.designation()] = 0
  let queue : Array[String] = [to.designation()]
  let mut head = 0
  while head < queue.length() {
    let cur = queue[head]
    head += 1
    let d = match dist.get(cur) {
      Some(d) => d
      None => 0
    }
    match rev.get(cur) {
      Some(prevs) =>
        for p in prevs {
          if !dist.contains(p) {
            dist[p] = d + 1
            queue.push(p)
          }
        }
      None => ()
    }
  }
  let out : Array[(SubjectState, Int?)] = []
  for s in all_states() {
    out.push((s, dist.get(s.designation())))
  }
  out
}

///|
/// 性质谓词：每 (位置, 触发) 至多一条边——触发粒度恒确定。
///
/// 这条原先是**一份独立的 O(n²) 实现**，与 `loop.mbt` 的 `one_edge_per_trigger`
/// 查同一件事；两份各自演化，将来修一份不会修另一份，而报告会把它们当两条独立
/// 性质印出来。现委托给那个已被变异 A4 覆盖的实现——牙齿在唯一一份逻辑上。
pub fn is_deterministic() -> Bool {
  one_edge_per_trigger()
}

///|
/// 性质谓词：机器是否无环。本机**有意成环**——自环（守）与宁静→反顾→
/// …→宁静的重入环都是设计（不封闭的形态），故恒 false；测试锁定这一点。
pub fn is_acyclic() -> Bool {
  let edges : Map[String, Array[String]] = Map([])
  for t in transitions() {
    let key = t.from.designation()
    let arr = match edges.get(key) {
      Some(a) => a
      None => {
        let a : Array[String] = []
        edges[key] = a
        a
      }
    }
    arr.push(t.to.designation())
  }
  let color : Map[String, Int] = Map([])
  fn has_cycle(u : String) -> Bool {
    color[u] = 1
    let mut found = false
    match edges.get(u) {
      Some(vs) =>
        for v in vs {
          let c = match color.get(v) {
            Some(c) => c
            None => 0
          }
          if c == 1 {
            found = true
          } else if c == 0 && has_cycle(v) {
            found = true
          }
        }
      None => ()
    }
    color[u] = 2
    found
  }

  for s in all_states() {
    let c = match color.get(s.designation()) {
      Some(c) => c
      None => 0
    }
    if c == 0 && has_cycle(s.designation()) {
      return false
    }
  }
  true
}

///|
/// 泛半环路径和的报告：三个半环的对应、机器的三个性质、每个位置到宁静
/// 的最短路（书名的算法形态）。
pub fn render_pathsum_report() -> String {
  let lines : Array[String] = [
    "# 泛半环路径和 · 通往宁静之路的最短路", "", "参照 FiniteStateTransducers.jl（OpenFST 谱系）：路径和是泛半环的——布尔",
    "（可达，`reachable`／`gaps` 已有）、tropical（⊕=min, ⊗=+，最短步数，本文件）、",
    "概率（关联诊断的 β 权重，evolution）。出处层：模型整理——步数是结构事实，",
    "不是原文的数。", "", "## 机器的三个性质",
  ]
  lines.push(
    "- 触发粒度确定（is_deterministic）：\{is_deterministic()}——每 (位置, 触发) 至多一条边；「未定」只在槽粒度出现（多触发共占一槽）。",
  )
  lines.push(
    "- 无环（is_acyclic）：\{is_acyclic()}——有意成环：自环（守）与宁静→反顾→…→宁静的重入环，重入是不封闭的形态。",
  )
  lines.push(
    "- 无 ε 弧：每条边都消费一个真实触发句——本机是 acceptor（读触发序列）而非 transducer（无输出投影）。",
  )
  lines.push("")
  lines.push(
    "## 每个位置到宁静的最短路（reversed shortest distance）",
  )
  let dist = distance_to(terminal())
  let mut furthest = 0
  let mut furthest_name = ""
  let mut missing = 0
  for entry in dist {
    match entry.1 {
      Some(n) => {
        if n > furthest {
          furthest = n
          furthest_name = entry.0.designation()
        }
        lines.push("- \{entry.0.designation()}　\{n} 步")
      }
      None => {
        missing += 1
        lines.push("- \{entry.0.designation()}　不可达")
      }
    }
  }
  lines.push("")
  lines.push(
    "最远的是\{furthest_name}（\{furthest} 步）；\{missing} 处不可达。宁静→反顾恰 1 步（重入边，R11）——通往宁静之路走完之后，界域一重开就回到反顾，整条路重新可走。",
  )
  lines.join("\n")
}
