///|
/// 运行时：消息总线 + 可重放的回合循环 + 整机落盘。
///
/// 真实协调器里，「想」这一步由 LLM 完成。这里把工人的确定性替身接在 `Worker` 上，
/// 于是整个回路可以**离线重放、可在测试里断言**；换成 LLM 只是替换这一步，协议与
/// 记账不变。`checkpoint` / `resume` 让运行中的状态整体可写可读（`cmd/coord` 会真的
/// 写进磁盘）。

///|
/// 一条消息。
pub struct Message {
  at : Int
  from : Int
  to : Int // -1 = 广播
  discourse : @multi.DiscourseType
  claim : @multi.ClaimKind
  body : String
}

///|
/// 运行时状态。`clock` 可变，其余是只追加的台账。
pub struct Runtime {
  mut clock : Int
  log : Array[Message]
  done : Array[Int]
  notebook : Notebook
  results : Array[Result]
  artifacts : Array[Artifact]
}

///|
/// 空运行时。
pub fn Runtime::new() -> Runtime {
  {
    clock: 0,
    log: [],
    done: [],
    notebook: Notebook::new(),
    results: [],
    artifacts: [],
  }
}

///|
/// 一步的回执。
pub struct StepReport {
  at : Int
  task : Int
  agent : Int
  discourse : String
  verdict : String
  result : Int
  finding : Int
}

///|
/// 由证据判词得到发现状态。
fn finding_status(v : EvidenceVerdict) -> FindingStatus {
  match v {
    Supported => Established
    Replicated => Established
    Refuted => Overturned
    Inconclusive => Pending
  }
}

///|
/// 跑一步：取一个就绪任务 → 指派 → 按商谈类型路由 → 产出一条结果与一条发现。
///
/// 路由：理论商谈走**证据**（真跑 DoubleML 并复现）；实践／表达／信仰商谈停在
/// 商谈段（各产出一条待证据的发现）。没有就绪任务或无人可派时返回 `None`。
pub fn Runtime::step(
  self : Runtime,
  tasks : Array[Task],
  questions : Array[Question],
  agents : Array[Worker],
  datasets : Array[Dataset],
  world : Array[@evolution.Opponent],
  parent : @evolution.Genome,
  candidate : @evolution.Genome,
) -> StepReport? {
  let rd = ready(tasks, self.done)
  if rd.length() == 0 {
    return None
  }
  let t = tasks[rd[0]]
  let q = questions[t.question]
  let agent = match assign(q, agents) {
    Some(a) => a
    None => return None
  }
  let at = self.clock
  let claim = match q.discourse {
    @multi.Theoretical => @multi.Truthfulness
    @multi.Practical => @multi.Legitimacy
    @multi.Aesthetic => @multi.Sincerity
    @multi.Faith => @multi.Authenticity
  }
  let phase = @multi.phase_of(claim)
  // 路由：只有理论商谈要数据。
  let binding : Binding? = match q.discourse {
    @multi.Theoretical =>
      if datasets.length() > q.id {
        let ds = datasets[q.id]
        let b0 = experiment(q.text, ds, parent, candidate, world)
        Some(replicate(b0, ds, parent, candidate, world))
      } else {
        None
      }
    _ => None
  }
  let verdict = match binding {
    Some(b) => evidence_verdict(b).label()
    None => "仅对话"
  }
  let summary = match binding {
    Some(b) =>
      "\{q.text}：效应 \{@evolution.show_pm(b.effect)}（复现 \{b.replicas} 次）"
    None => "\{q.text}：尚无数据，停在商谈段"
  }
  let (dataset_id, effect, lo, hi, replicas) = match binding {
    Some(b) => (b.dataset, b.effect, b.ci_low, b.ci_high, b.replicas)
    None => (-1, 0, 0, 0, 0)
  }
  let status = match binding {
    Some(b) => finding_status(evidence_verdict(b))
    None => Pending
  }
  let result_id = self.results.length()
  self.results.push(
    result(
      result_id,
      t.id,
      q.id,
      claim,
      phase,
      summary,
      dataset_id,
      effect,
      lo,
      hi,
      replicas,
    ),
  )
  let finding_id = self.notebook.add({
    id: 0,
    question: q.id,
    text: summary,
    claim,
    phase,
    result: result_id,
    residual: 3,
    status,
    supersedes: None,
    author: agent,
    at,
  })
  let artifact_id = self.artifacts.length()
  self.artifacts.push({
    id: artifact_id,
    kind: Note,
    name: "\{t.title} 的结论",
    task: t.id,
    digest: "\{result_id}",
  })
  self.log.push({
    at,
    from: agent,
    to: -1,
    discourse: q.discourse,
    claim,
    body: summary,
  })
  self.done.push(t.id)
  self.clock = at + 1
  Some({
    at,
    task: t.id,
    agent,
    discourse: q.discourse.label(),
    verdict,
    result: result_id,
    finding: finding_id,
  })
}

// ── 落盘 ────────────────────────────────────────────────────────

///|
fn discourse_code(d : @multi.DiscourseType) -> String {
  match d {
    @multi.Theoretical => "theo"
    @multi.Practical => "prac"
    @multi.Aesthetic => "aesth"
    @multi.Faith => "faith"
  }
}

///|
fn discourse_of(s : StringView) -> @multi.DiscourseType {
  let t = s.to_owned()
  if t == "prac" {
    @multi.Practical
  } else if t == "aesth" {
    @multi.Aesthetic
  } else if t == "faith" {
    @multi.Faith
  } else {
    @multi.Theoretical
  }
}

///|
fn kind_code(k : ArtifactKind) -> String {
  match k {
    Paper => "paper"
    Figure => "figure"
    Code => "code"
    Data => "data"
    Note => "note"
  }
}

///|
fn kind_of(s : StringView) -> ArtifactKind {
  let t = s.to_owned()
  if t == "paper" {
    Paper
  } else if t == "figure" {
    Figure
  } else if t == "code" {
    Code
  } else if t == "data" {
    Data
  } else {
    Note
  }
}

///|
fn ito(s : StringView) -> Int {
  @string.from_str(s.to_owned()) catch {
    _ => 0
  }
}

///|
/// 运行中的状态 → 文本（整机检查点）。
pub fn Runtime::checkpoint(self : Runtime) -> String {
  let lines : Array[String] = ["clock\t\{self.clock}"]
  for id in self.done {
    lines.push("done\t\{id}")
  }
  for m in self.log {
    lines.push(
      [
        "msg",
        "\{m.at}",
        "\{m.from}",
        "\{m.to}",
        discourse_code(m.discourse),
        claim_code(m.claim),
        m.body,
      ].join("\t"),
    )
  }
  for r in self.results {
    lines.push(
      [
        "result",
        "\{r.id}",
        "\{r.task}",
        "\{r.question}",
        claim_code(r.claim),
        phase_code(r.phase),
        "\{r.dataset}",
        "\{r.effect}",
        "\{r.ci_low}",
        "\{r.ci_high}",
        "\{r.replicas}",
        r.summary,
      ].join("\t"),
    )
  }
  for a in self.artifacts {
    lines.push(
      ["artifact", "\{a.id}", kind_code(a.kind), "\{a.task}", a.digest, a.name].join(
        "\t",
      ),
    )
  }
  let nb = self.notebook.serialize()
  if nb.length() > 0 {
    lines.push(nb)
  }
  lines.join("\n")
}

///|
/// 文本 → 运行时（`checkpoint` 的逆）。
pub fn restore(text : String) -> Runtime {
  let mut clock = 0
  let log : Array[Message] = []
  let done : Array[Int] = []
  let results : Array[Result] = []
  let artifacts : Array[Artifact] = []
  let nb_lines : Array[String] = []
  for line in text.split("\n") {
    if line.length() == 0 {
      continue
    }
    let f = line.split("\t").collect()
    if f.length() == 0 {
      continue
    }
    let tag = f[0].to_owned()
    if tag == "clock" && f.length() >= 2 {
      clock = ito(f[1])
    } else if tag == "done" && f.length() >= 2 {
      done.push(ito(f[1]))
    } else if tag == "msg" && f.length() >= 7 {
      log.push({
        at: ito(f[1]),
        from: ito(f[2]),
        to: ito(f[3]),
        discourse: discourse_of(f[4]),
        claim: claim_of(f[5]),
        body: f[6].to_owned(),
      })
    } else if tag == "result" && f.length() >= 12 {
      results.push({
        id: ito(f[1]),
        task: ito(f[2]),
        question: ito(f[3]),
        claim: claim_of(f[4]),
        phase: phase_of(f[5]),
        dataset: ito(f[6]),
        effect: ito(f[7]),
        ci_low: ito(f[8]),
        ci_high: ito(f[9]),
        replicas: ito(f[10]),
        summary: f[11].to_owned(),
      })
    } else if tag == "artifact" && f.length() >= 6 {
      artifacts.push({
        id: ito(f[1]),
        kind: kind_of(f[2]),
        task: ito(f[3]),
        digest: f[4].to_owned(),
        name: f[5].to_owned(),
      })
    } else if tag == "finding" {
      nb_lines.push(line.to_owned())
    }
  }
  {
    clock,
    log,
    done,
    notebook: parse_notebook(nb_lines.join("\n")),
    results,
    artifacts,
  }
}

///|
/// 检查点是否往返一致。
pub fn Runtime::round_trips(self : Runtime) -> Bool {
  let text = self.checkpoint()
  let back = restore(text)
  back.checkpoint() == text &&
  back.clock == self.clock &&
  back.notebook.findings.length() == self.notebook.findings.length()
}
