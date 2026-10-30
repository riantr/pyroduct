///|
/// 内容记忆 —— 记的是**发现本身**，不是改动。
///
/// `@evolution.Ledger` 记的是「基因组怎么变」；这里记的是「知道了什么」：每条发现
/// 绑定到一条 `Result`（因而可追溯到数据集与复现），并且**保留被它取代的历史**——
/// 推翻一个旧结论这件事本身，也要留下痕迹。

///|
/// 发现的状态。
pub(all) enum FindingStatus {
  Pending // 待证据
  Established // 被数据支持
  Overturned // 被数据反驳
  Replaced // 被新发现取代
  Retracted // 撤回
} derive(Eq)

///|
pub extend FindingStatus with Eq::{not_equal, equal}

///|
/// 状态名。
pub fn FindingStatus::label(self : FindingStatus) -> String {
  match self {
    Pending => "待证据"
    Established => "已支持"
    Overturned => "已反驳"
    Replaced => "已取代"
    Retracted => "已撤回"
  }
}

///|
/// 一条发现。
pub(all) struct Finding {
  id : Int32
  question : Int32
  text : String
  claim : @multi.ClaimKind
  phase : @multi.ClaimPhase
  result : Int32
  residual : Int32
  status : FindingStatus
  supersedes : Int32?
  author : Int32
  at : Int32
}

///|
/// 笔记本：只追加。
pub struct Notebook {
  findings : Array[Finding]
}

///|
/// 空笔记本。
pub fn Notebook::new() -> Notebook {
  { findings: [], }
}

///|
/// 追加一条发现，返回新 id。
pub fn Notebook::add(self : Notebook, f : Finding) -> Int32 {
  let id = self.findings.length()
  self.findings.push({ ..f, id, })
  id
}

///|
/// 按 id 取一条发现。
pub fn Notebook::find(self : Notebook, id : Int32) -> Finding? {
  for f in self.findings {
    if f.id == id {
      return Some(f)
    }
  }
  None
}

///|
/// 改一条发现的状态。
pub fn Notebook::mark(
  self : Notebook,
  id : Int32,
  status : FindingStatus,
) -> Unit {
  for i = 0; i < self.findings.length(); i = i + 1 {
    if self.findings[i].id == id {
      self.findings[i] = { ..self.findings[i], status, }
    }
  }
}

///|
/// 某问题当前成立的发现（最后一次被支持或待证据者）。
pub fn Notebook::current(self : Notebook, question : Int32) -> Finding? {
  let mut best : Finding? = None
  for f in self.findings {
    if f.question == question &&
      (f.status == Established || f.status == Pending) {
      best = Some(f)
    }
  }
  best
}

///|
/// 追溯一条发现「取代了谁」的链（内容记忆的关键：被推翻的历史也在）。
pub fn Notebook::history(self : Notebook, id : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  let mut cur : Int32? = Some(id)
  let mut go = true
  while go {
    match cur {
      Some(c) => {
        out.push(c)
        cur = match self.find(c) {
          Some(f) => f.supersedes
          None => None
        }
      }
      None => go = false
    }
  }
  out
}

// ── 编解码（供运行时落盘） ──────────────────────────────────────

///|
fn claim_code(c : @multi.ClaimKind) -> String {
  match c {
    @multi.Truthfulness => "truth"
    @multi.Legitimacy => "legit"
    @multi.Authenticity => "auth"
    @multi.Sincerity => "sinc"
  }
}

///|
fn claim_of(s : StringView, repairs : Array[String]) -> @multi.ClaimKind {
  let t = s.to_owned()
  if t == "legit" {
    @multi.Legitimacy
  } else if t == "auth" {
    @multi.Authenticity
  } else if t == "sinc" {
    @multi.Sincerity
  } else if t == "truth" {
    @multi.Truthfulness
  } else {
    repairs.push("未知的有效性主张码：「\{t}」→ 记为真实性")
    @multi.Truthfulness
  }
}

///|
fn phase_code(p : @multi.ClaimPhase) -> String {
  match p {
    @multi.Before => "before"
    @multi.During => "during"
    @multi.After => "after"
  }
}

///|
fn phase_of(s : StringView, repairs : Array[String]) -> @multi.ClaimPhase {
  let t = s.to_owned()
  if t == "before" {
    @multi.Before
  } else if t == "after" {
    @multi.After
  } else if t == "during" {
    @multi.During
  } else {
    repairs.push("未知的时间位置码：「\{t}」→ 记为事中")
    @multi.During
  }
}

///|
fn status_code(s : FindingStatus) -> String {
  match s {
    Pending => "open"
    Established => "supp"
    Overturned => "refut"
    Replaced => "super"
    Retracted => "withd"
  }
}

///|
fn status_of(s : StringView, repairs : Array[String]) -> FindingStatus {
  let t = s.to_owned()
  if t == "supp" {
    Established
  } else if t == "refut" {
    Overturned
  } else if t == "super" {
    Replaced
  } else if t == "withd" {
    Retracted
  } else if t == "open" {
    Pending
  } else {
    repairs.push("未知的发现状态码：「\{t}」→ 记为待定")
    Pending
  }
}

///|
fn int_of(s : StringView, repairs : Array[String]) -> Int32 {
  @string.from_str(s.to_owned()) catch {
    _ => {
      repairs.push("无法解析成数字：「\{s.to_owned()}」→ 记为 0")
      0
    }
  }
}

///|
/// 笔记本 → 文本（每行一条发现；文本字段置于行尾，可含逗号）。
pub fn Notebook::serialize(self : Notebook) -> String {
  let lines : Array[String] = []
  for f in self.findings {
    let sup = match f.supersedes {
      Some(i) => "\{i}"
      None => "-"
    }
    lines.push(
      [
        "finding",
        "\{f.id}",
        "\{f.question}",
        claim_code(f.claim),
        phase_code(f.phase),
        "\{f.result}",
        "\{f.residual}",
        status_code(f.status),
        sup,
        "\{f.author}",
        "\{f.at}",
        f.text,
      ].join("\t"),
    )
  }
  lines.join("\n")
}

///|
/// 文本 → 笔记本。
pub fn parse_notebook(text : String) -> Notebook {
  let (nb, _repairs) = parse_notebook_checked(text)
  nb
}

///|
/// 文本 → 笔记本，**并**把每一处「只能猜」与「被整行丢掉」记下来。
///
/// 此前这一层是**无声的**：字段不足的行被整行跳过（`continue`），于是笔记本可能
/// 少了一条发现，而读回来的人看不见少了什么。「看不见」不等于「没问题」——被丢掉
/// 的行必须说出来。
pub fn parse_notebook_checked(text : String) -> (Notebook, Array[String]) {
  let nb = Notebook::new()
  let repairs : Array[String] = []
  for line in text.split("\n") {
    if line.length() == 0 {
      continue
    }
    let f = line.split("\t").collect()
    if f.length() == 0 {
      continue
    }
    if f[0].to_owned() != "finding" {
      repairs.push(
        "不是发现行，被整行丢掉：「\{f[0].to_owned()}」",
      )
      continue
    }
    if f.length() < 11 {
      repairs.push(
        "字段不足的发现行（\{f.length()} 列），被整行丢掉",
      )
      continue
    }
    let sup = if f[8].to_owned() == "-" {
      None
    } else {
      Some(int_of(f[8], repairs))
    }
    let text_field = if f.length() >= 12 { f[11].to_owned() } else { "" }
    nb.findings.push({
      id: int_of(f[1], repairs),
      question: int_of(f[2], repairs),
      claim: claim_of(f[3], repairs),
      phase: phase_of(f[4], repairs),
      result: int_of(f[5], repairs),
      residual: int_of(f[6], repairs),
      status: status_of(f[7], repairs),
      supersedes: sup,
      author: int_of(f[9], repairs),
      at: int_of(f[10], repairs),
      text: text_field,
    })
  }
  (nb, repairs)
}
