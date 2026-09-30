///|
/// 署名与信用：谁做了什么、作者顺序怎么定、某个产物归功于谁（IP 溯源）。

///|
/// 贡献角色。
pub(all) enum Role {
  Question // 提出问题
  Data // 数据
  Method // 方法
  Analysis // 分析
  Writing // 写作
  Review // 审阅
} derive(Eq)

///|
pub extend Role with Eq::{not_equal, equal}

///|
/// 角色名。
pub fn Role::label(self : Role) -> String {
  match self {
    Question => "提出问题"
    Data => "数据"
    Method => "方法"
    Analysis => "分析"
    Writing => "写作"
    Review => "审阅"
  }
}

///|
/// 一条贡献记录。
pub struct Contribution {
  agent : Int
  task : Int
  role : Role
  weight : Int
}

///|
/// 构造一条贡献。
pub fn contribution(
  agent : Int,
  task : Int,
  role : Role,
  weight : Int,
) -> Contribution {
  { agent, task, role, weight, }
}

///|
/// 每位参与者的贡献总额。
pub fn totals(cs : Array[Contribution]) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  for c in cs {
    let mut found = false
    for i = 0; i < out.length(); i = i + 1 {
      if out[i].0 == c.agent {
        out[i] = (out[i].0, out[i].1 + c.weight)
        found = true
      }
    }
    if !found {
      out.push((c.agent, c.weight))
    }
  }
  out
}

///|
/// 作者顺序：贡献总额降序，同分按 id 升序。
pub fn author_order(cs : Array[Contribution]) -> Array[Int] {
  let t = totals(cs)
  t.sort_by((a, b) => {
    if a.1 == b.1 {
      a.0.compare(b.0)
    } else {
      b.1.compare(a.1)
    }
  })
  t.map(p => p.0)
}

///|
/// 某任务应归功于谁（按该任务上的权重降序）——IP 溯源。
pub fn credit_of_task(cs : Array[Contribution], task : Int) -> Array[Int] {
  let mine : Array[Contribution] = []
  for c in cs {
    if c.task == task {
      mine.push(c)
    }
  }
  author_order(mine)
}

///|
/// 贡献声明文本。
pub fn render_statement(cs : Array[Contribution]) -> String {
  let lines : Array[String] = [
    "署名（按贡献）：\{author_order(cs).map(a => "\{a}").join(" > ")}",
  ]
  for pair in totals(cs) {
    lines.push("- 研究者\{pair.0}：总贡献 \{pair.1}")
  }
  lines.push("")
  lines.push("分任务溯源：")
  let seen : Array[Int] = []
  for c in cs {
    if !seen.contains(c.task) {
      seen.push(c.task)
      lines.push(
        "- 任务\{c.task} → \{credit_of_task(cs, c.task).map(a => "\{a}").join(" > ")}",
      )
    }
  }
  lines.join("\n")
}
