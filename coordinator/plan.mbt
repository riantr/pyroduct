///|
/// 规划与调度：依赖图、拓扑序、就绪判定、分工指派、预算与期限核算。

///|
/// 一位可承担任务的研究者（agent）。
pub struct Worker {
  id : Int
  name : String
  regime : @multi.TruthRegime
  reason : Int // 共同理性（纵向）
  cheng : Int // 两诚（这里简化为他之诚与己之诚的均值）
  budget : Int // 可用预算
}

///|
/// 构造一位研究者。
pub fn worker(
  id : Int,
  name : String,
  regime : @multi.TruthRegime,
  reason : Int,
  cheng : Int,
  budget : Int,
) -> Worker {
  { id, name, regime, reason, cheng, budget, }
}

///|
/// 一份计划。
pub struct Plan {
  order : Array[Int]
  assigned : Array[(Int, Int)] // (task, agent)
  feasible : Bool
  notes : Array[String]
}

///|
/// 拓扑序（Kahn）。约定 `Task.id` 即数组下标。返回 (顺序, 是否无环)。
pub fn topological(tasks : Array[Task]) -> (Array[Int], Bool) {
  let n = tasks.length()
  let indeg : Array[Int] = []
  let adj : Array[Array[Int]] = []
  for i = 0; i < n; i = i + 1 {
    indeg.push(0)
    adj.push([])
  }
  for t in tasks {
    for d in t.deps {
      indeg[t.id] = indeg[t.id] + 1
      adj[d].push(t.id)
    }
  }
  let order : Array[Int] = []
  let queue : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    if indeg[i] == 0 {
      queue.push(i)
    }
  }
  let mut head = 0
  while head < queue.length() {
    let u = queue[head]
    order.push(u)
    for v in adj[u] {
      indeg[v] = indeg[v] - 1
      if indeg[v] == 0 {
        queue.push(v)
      }
    }
    head += 1
  }
  (order, order.length() == n)
}

///|
/// 依赖已满足的任务（未完成，且其 deps 都已完成）。
pub fn ready(tasks : Array[Task], done : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for t in tasks {
    if done.contains(t.id) {
      continue
    }
    let mut ok = true
    for d in t.deps {
      if !done.contains(d) {
        ok = false
      }
    }
    if ok {
      out.push(t.id)
    }
  }
  out
}

///|
/// 一位研究者对某类商谈的适配度。
fn fit(q : Question, w : Worker) -> Int {
  match q.discourse {
    @multi.Theoretical => w.reason
    @multi.Practical => w.cheng
    @multi.Aesthetic => w.cheng
    @multi.Faith => 50
  }
}

///|
/// 指派：按商谈类型挑适配度最高、且还有预算的研究者。
pub fn assign(q : Question, agents : Array[Worker]) -> Int? {
  let mut best : Worker? = None
  for w in agents {
    if w.budget <= 0 {
      continue
    }
    match best {
      None => best = Some(w)
      Some(b) => if fit(q, w) > fit(q, b) { best = Some(w) }
    }
  }
  match best {
    Some(w) => Some(w.id)
    None => None
  }
}

///|
/// 排程：拓扑序 + 分工 + 预算/期限诊断。
pub fn schedule(
  tasks : Array[Task],
  questions : Array[Question],
  agents : Array[Worker],
  now : Int,
) -> Plan {
  let (order, acyclic) = topological(tasks)
  let notes : Array[String] = []
  if !acyclic {
    notes.push("依赖图有环：拓扑序不完整")
  }
  let assigned : Array[(Int, Int)] = []
  let mut spent = 0
  let mut overdue = false
  for id in order {
    let t = tasks[id]
    let q = questions[t.question]
    match assign(q, agents) {
      Some(a) => assigned.push((id, a))
      None => notes.push("任务 \{id} 无人可派（预算耗尽？）")
    }
    spent += t.budget
    if now + spent > t.deadline {
      overdue = true
    }
  }
  if overdue {
    notes.push("有任务会超出期限（now + 累计预算 > deadline）")
  }
  { order, assigned, feasible: notes.length() == 0, notes, }
}

///|
/// 某任务被派给了谁（未派返回 -1）。
pub fn agent_of(plan : Plan, id : Int) -> Int {
  for pair in plan.assigned {
    if pair.0 == id {
      return pair.1
    }
  }
  -1
}

///|
/// 计划文本。
pub fn render_plan(plan : Plan, tasks : Array[Task]) -> String {
  let lines : Array[String] = [
    "执行序 | 任务 | 指派 | 预算 | 期限", "---|---|---|---|---",
  ]
  for i = 0; i < plan.order.length(); i = i + 1 {
    let t = tasks[plan.order[i]]
    lines.push(
      "\{i + 1} | \{t.title} | 研究者\{agent_of(plan, t.id)} | \{t.budget} | \{t.deadline}",
    )
  }
  lines.push("")
  if plan.feasible {
    lines.push("可行")
  } else {
    lines.push("需调整：\{plan.notes.join("；")}")
  }
  lines.join("\n")
}
