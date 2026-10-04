///|
/// Büchi 面（模型整理）：把主体机读成 ω-自动机——无限词上的接受条件。
///
/// 为什么问题在这里成立：机器**没有终态**（`no_final_closure`），历程的
/// 结尾不是「止于宁静」而是「宁静 ↺ 反顾」（R11 界域重开）——任何主体
/// 都不是一次走完，而是反复经过这条序列（`course` 的记档）。有限自动机
/// 的「到达即停」读法在设计上是错的；自然的接受条件是 **Büchi 的**：
/// 某个状态被无限次访问（Müller／Büchi 条件中的 recurrence——无限常现）。
///
/// 对准（模型整理）：
///
///   - **验收集** = {宁静}：静定极作为反复发生的「好事」——recurrence
///     性质（infinitely often）。选宁静是本仓库的整理：原文只说它是
///     **本环节的静定极**，不是终态；
///   - **非空性**：存在经过验收集的可达环（lasso：茎 + 过接受态的环）
///     ——重入环 宁静→反顾→…→宁静 使之为真；这是「不封闭」的 ω-
///     形式化：机器的 ω-语言非空，存在本意的无穷行走；
///   - **活性潜势**：每个位置都可达验收集（0.1.18 的最短路阶梯，0 处
///     不可达）——没有位置是 ω-语言的死端（机器是「得体的」：每个状态
///     都还接得上本意）；
///   - **停滞词**（关键的否定结果）：守（自环）给出无穷触发序列——同一
///     守句无限重复，位置不变。其中 10 处非接受态的守词让宁静**零次**被
///     访——机器的 ω-语言**包含不被接受的词**：结构不强迫活性，活性须
///     **公平性假设**（主体终究要动）。这个假设的结构住处在进化层：双诚
///     之比与闸门（0.1.15／0.1.17）——「未定不掷骰子」「Block 绝不伪造」
///     是同一条纪律的 ω-形式化：机器不能替主体决断，也不能强迫主体行走。
///     唯一的例外是宁静自己的守（静待下一刻，WaitNext 自环）：持住静定极
///     本身让宁静无限次被访——**被接受的停滞**，recurrence 的最简形式。
///
/// 刻意不移植（如实记录）：
///
///   - **LTL→Büchi 的全量模型检验**：需要**非确定** Büchi（确定性 Büchi
///     严格弱于非确定，表达力差一截）；本机是确定自动机（0.1.18），recurrence
///     性质确定地可表达，但论域规则的 until／公平交替需要 NBA 与乘积构造
///     （位置 × 基因组空间的乘积，原则上可行，此处不做）；
///   - **Streett／Rabin 公平性对**：闸门的「反馈不由标签给出」最自然的
///     形式是 Streett 对（公正与慈悲）——此处只作概念对应；
///   - **Büchi 极小化／补**：无需求——非空性与活性潜势只需 lasso 与
///     可达的廉价计算。
///
/// 出处层：模型整理——验收集的选择与「停滞词」的读法是本仓库的整理；
/// 非空性、活性潜势、自环数是结构事实。

///|
/// 验收集：静定极（recurrence 性质的「好事」）。
pub fn buchi_accepting() -> Array[SubjectState] {
  [Tranquility]
}

///|
/// 停滞位置：有自环迁移（守）的状态——无穷停滞词的见证。
pub fn buchi_stalls() -> Array[SubjectState] {
  let seen : Map[String, Bool] = Map([])
  let out : Array[SubjectState] = []
  for t in transitions() {
    if t.from == t.to {
      let k = t.from.designation()
      match seen.get(k) {
        Some(_) => ()
        None => {
          seen[k] = true
          out.push(t.from)
        }
      }
    }
  }
  out
}

///|
/// 非空性：存在经过验收集的可达环——从宁静走 ≥1 步可达的位置里，有一个
/// 能回到宁静（lasso 的核；重入环使它成立）。
pub fn buchi_nonempty() -> Bool {
  let s = Tranquility
  let seen : Map[String, Bool] = Map([])
  let queue : Array[SubjectState] = []
  for t in transitions() {
    if t.from == s {
      let k = t.to.designation()
      match seen.get(k) {
        Some(_) => ()
        None => {
          seen[k] = true
          queue.push(t.to)
        }
      }
    }
  }
  let mut head = 0
  while head < queue.length() {
    let u = queue[head]
    head += 1
    for t in transitions() {
      if t.from == u {
        let k = t.to.designation()
        match seen.get(k) {
          Some(_) => ()
          None => {
            seen[k] = true
            queue.push(t.to)
          }
        }
      }
    }
  }
  for u in queue {
    match min_steps(u, s) {
      Some(_) => return true
      None => ()
    }
  }
  false
}

///|
/// 活性潜势：每个位置都可达验收集——没有位置是 ω-语言的死端。
pub fn buchi_live_potential() -> Bool {
  for s in all_states() {
    match min_steps(s, Tranquility) {
      Some(_) => ()
      None => return false
    }
  }
  true
}

///|
/// ω-视角的报告：三个判定、停滞位置、判读与不移植项。
pub fn render_buchi_report() -> String {
  let stalls = buchi_stalls()
  let rej_names : Array[String] = []
  for s in stalls {
    if s != Tranquility {
      rej_names.push(s.designation())
    }
  }
  let lines : Array[String] = [
    "# ω-视角（Büchi 面）", "", "机器没有终态（no_final_closure）；历程的结尾不是「止于宁静」而是",
    "「宁静 ↺ 反顾」（R11 界域重开）——任何主体都不是一次走完，而是反复",
    "经过这条序列。「到达即停」的有限读法是错的；自然的接受条件是 Büchi 的：",
    "某个状态被无限次访问。出处层：模型整理——验收集的选择与停滞词的读法是",
    "本仓库的整理；非空性、活性潜势、自环数是结构事实。",
    "", "## 三个判定",
  ]
  lines.push(
    "- 验收集 = {宁静}（静定极；recurrence：infinitely often）——重入环让静定成为环节的静定极，而非终态；",
  )
  lines.push(
    "- 非空性：\{buchi_nonempty()}——存在经过宁静的可达环（重入环：宁静→反顾→…→宁静）；「不封闭」的 ω-形式化：本意的无穷行走存在；",
  )
  lines.push(
    "- 活性潜势：\{buchi_live_potential()}——每个位置都可达宁静（0.1.18 的最短路阶梯，0 处不可达）；没有位置是 ω-语言的死端；",
  )
  lines.push(
    "- 停滞位置：\{stalls.length()} 处有守（自环）——其中 \{rej_names.length()} 处（\{rej_names.join("、")}）的停滞词**不被接受**：同一守句无限重复，宁静零次被访；",
  )
  lines.push(
    "- 宁静自己的守（静待下一刻）是唯一**被接受的停滞**：持住静定极本身让宁静无限次被访，recurrence 的最简形式；",
  )
  lines.push("")
  lines.push("## 判读")
  lines.push(
    "- 关键的否定结果：机器的 ω-语言**包含不被接受的词**——结构不强迫活性；",
  )
  lines.push(
    "  活性须公平性假设（主体终究要动），而这个假设的结构住处在进化层：",
  )
  lines.push(
    "  双诚之比与闸门（0.1.15／0.1.17）。「未定不掷骰子」「Block 绝不伪造」",
  )
  lines.push(
    "  是同一条纪律的 ω-形式化：机器不能替主体决断，也不能强迫主体行走——",
  )
  lines.push(
    "  修养在结构上永远**可能**（活性潜势），在结构上永远**不被强迫**（停滞词）。",
  )
  lines.push(
    "- 其余每个停滞位置都仍有出口（活性潜势对它们也成立）——守不是死端，是",
  )
  lines.push(
    "  「静待下一刻」的读法；走出去的是主体的决断，不是结构的推力。而停在",
  )
  lines.push(
    "  静定极上的守是被接受的——静待与修习不冲突：持住即好事的常现。",
  )
  lines.push("")
  lines.push("## 刻意不移植（如实记录）")
  lines.push(
    "- LTL→Büchi 的全量模型检验：需要非确定 Büchi（确定性表达力不足），",
  )
  lines.push(
    "  及位置 × 基因组空间的乘积构造——原则上可行，此处不做；",
  )
  lines.push(
    "- Streett／Rabin 公平性对：闸门的「反馈不由标签给出」最自然的形式是",
  )
  lines.push(
    "  Streett 对（公正与慈悲）——此处只作概念对应；",
  )
  lines.push(
    "- Büchi 极小化／补：无需求——非空性与活性潜势只需 lasso 与可达计算。",
  )
  lines.join("\n")
}
