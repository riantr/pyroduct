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
  at : Int32
  from : Int32
  to : Int32 // -1 = 广播
  discourse : @multi.DiscourseType
  claim : @multi.ClaimKind
  body : String
}

///|
/// 运行时状态。`clock` 可变，其余是只追加的台账。
///
/// `repairs` 是**降级账**：这一次恢复（或构造）里，每一处「只能猜」都记在这里。
/// 它**不是**状态的一部分（不算进内容指纹），而是「这份状态是怎么来的」的账。
/// 空账 = 忠实恢复；有账 = 明说自己不忠实。
pub struct Runtime {
  mut clock : Int32
  log : Array[Message]
  done : Array[Int32]
  notebook : Notebook
  results : Array[Result]
  artifacts : Array[Artifact]
  repairs : Array[String]
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
    repairs: [],
  }
}

///|
/// 一步的回执。
pub struct StepReport {
  at : Int32
  task : Int32
  agent : Int32
  discourse : String
  verdict : String
  result : Int32
  finding : Int32
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
fn discourse_of(
  s : StringView,
  repairs : Array[String],
) -> @multi.DiscourseType {
  let t = s.to_owned()
  if t == "prac" {
    @multi.Practical
  } else if t == "aesth" {
    @multi.Aesthetic
  } else if t == "faith" {
    @multi.Faith
  } else if t == "theo" {
    @multi.Theoretical
  } else {
    repairs.push("未知的商谈类型码：「\{t}」→ 记为理论商谈")
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
fn kind_of(s : StringView, repairs : Array[String]) -> ArtifactKind {
  let t = s.to_owned()
  if t == "paper" {
    Paper
  } else if t == "figure" {
    Figure
  } else if t == "code" {
    Code
  } else if t == "data" {
    Data
  } else if t == "note" {
    Note
  } else {
    repairs.push("未知的制品类别码：「\{t}」→ 记为笔记")
    Note
  }
}

///|
fn ito(s : StringView, repairs : Array[String]) -> Int32 {
  @string.from_str(s.to_owned()) catch {
    _ => {
      repairs.push("无法解析成数字：「\{s.to_owned()}」→ 记为 0")
      0
    }
  }
}

///|
/// 运行中的状态 → 文本（整机检查点）。
///
/// 末行是**内容指纹**：它算在「除指纹行以外的那部分」上。写进去，是为了日后读回
/// 时能核验「读回来的还是不是写出去的那个」——只看字节往返不够，字节往返只证明
/// 序列化没坏，不证明恢复时没猜值。
pub fn Runtime::checkpoint(self : Runtime) -> String {
  self.body() + "\n" + "digest\t" + self.digest()
}

///|
/// 文本 → 运行时（`checkpoint` 的逆）。
///
/// **失败闭合**：解析时每一处「只能猜」都记进降级账——猜出来的数字、猜出来的商谈
/// 类型、猜出来的制品类别、字段不足的行、对不上的指纹、整行被丢掉的发现。恢复
/// 出来的运行时因此要么**忠实**，要么**明说自己不忠实**；不会悄悄变成一个「看起
/// 来合理但值全错」的运行时。
///
/// 此前这里是**无声的**：数字解析失败就记 0，未知的商谈类型就当理论商谈，未知的
/// 制品类别就当笔记，字段不足的行整行跳过。恢复出来的运行时与写出去的那个**长度
/// 一样、结构一样，却处处不同**——那是最难查的一类坏，因为它看上去是好的。
///
/// 指纹核验是最后一道：检查点里记着一枚内容指纹，重建出来的运行时另算一枚。两枚
/// 对不上，说明恢复过程中内容变了——被篡改，或者解析时猜了值。
pub fn restore(text : String) -> Runtime {
  let mut clock = 0
  let log : Array[Message] = []
  let done : Array[Int32] = []
  let results : Array[Result] = []
  let artifacts : Array[Artifact] = []
  let nb_lines : Array[String] = []
  let repairs : Array[String] = []
  let known = ["clock", "done", "msg", "result", "artifact", "finding"]
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
      clock = ito(f[1], repairs)
    } else if tag == "done" && f.length() >= 2 {
      done.push(ito(f[1], repairs))
    } else if tag == "msg" && f.length() >= 7 {
      log.push({
        at: ito(f[1], repairs),
        from: ito(f[2], repairs),
        to: ito(f[3], repairs),
        discourse: discourse_of(f[4], repairs),
        claim: claim_of(f[5], repairs),
        body: f[6].to_owned(),
      })
    } else if tag == "result" && f.length() >= 12 {
      results.push({
        id: ito(f[1], repairs),
        task: ito(f[2], repairs),
        question: ito(f[3], repairs),
        claim: claim_of(f[4], repairs),
        phase: phase_of(f[5], repairs),
        dataset: ito(f[6], repairs),
        effect: ito(f[7], repairs),
        ci_low: ito(f[8], repairs),
        ci_high: ito(f[9], repairs),
        replicas: ito(f[10], repairs),
        summary: f[11].to_owned(),
      })
    } else if tag == "artifact" && f.length() >= 6 {
      artifacts.push({
        id: ito(f[1], repairs),
        kind: kind_of(f[2], repairs),
        task: ito(f[3], repairs),
        digest: f[4].to_owned(),
        name: f[5].to_owned(),
      })
    } else if tag == "finding" {
      nb_lines.push(line.to_owned())
    } else if tag == "digest" && f.length() >= 2 {
      // 指纹行：核验时另算一遍，见下。
      ()
    } else if known.contains(tag) {
      repairs.push("字段不足的行：「\{tag}」")
    } else {
      repairs.push("不认识的行：「\{tag}」")
    }
  }
  let (nb, nb_repairs) = parse_notebook_checked(nb_lines.join("\n"))
  for r in nb_repairs {
    repairs.push(r)
  }
  let rt = { clock, log, done, notebook: nb, results, artifacts, repairs, }
  // 双哈希：检查点里记的那一枚，与重建出来的这一枚，必须相同。
  let claimed = claimed_digest(text)
  let rebuilt = rt.digest()
  if claimed.length() == 0 {
    repairs.push("检查点没有指纹行：无法确认内容未被改动")
  } else if claimed != rebuilt {
    repairs.push(
      "指纹对不上：记的是「\{claimed}」，重建出来的是「\{rebuilt}」——内容在恢复途中变了",
    )
  }
  rt
}

///|
/// 检查点是否往返一致。
///
/// 「往返一致」现在含两件事：序列化没坏，**且**恢复过程一处也没有猜。
pub fn Runtime::round_trips(self : Runtime) -> Bool {
  let text = self.checkpoint()
  let back = restore(text)
  back.checkpoint() == text &&
  back.clock == self.clock &&
  back.notebook.findings.length() == self.notebook.findings.length() &&
  back.is_faithful()
}
