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
  id : Int
  question : Int
  text : String
  claim : @multi.ClaimKind
  phase : @multi.ClaimPhase
  result : Int
  residual : Int
  status : FindingStatus
  supersedes : Int?
  author : Int
  at : Int
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
pub fn Notebook::add(self : Notebook, f : Finding) -> Int {
  let id = self.findings.length()
  self.findings.push({ ..f, id, })
  id
}

///|
/// 按 id 取一条发现。
pub fn Notebook::find(self : Notebook, id : Int) -> Finding? {
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
  id : Int,
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
pub fn Notebook::current(self : Notebook, question : Int) -> Finding? {
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
pub fn Notebook::history(self : Notebook, id : Int) -> Array[Int] {
  let out : Array[Int] = []
  let mut cur : Int? = Some(id)
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
fn claim_of(s : StringView) -> @multi.ClaimKind {
  let t = s.to_owned()
  if t == "legit" {
    @multi.Legitimacy
  } else if t == "auth" {
    @multi.Authenticity
  } else if t == "sinc" {
    @multi.Sincerity
  } else {
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
fn phase_of(s : StringView) -> @multi.ClaimPhase {
  let t = s.to_owned()
  if t == "before" {
    @multi.Before
  } else if t == "after" {
    @multi.After
  } else {
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
fn status_of(s : StringView) -> FindingStatus {
  let t = s.to_owned()
  if t == "supp" {
    Established
  } else if t == "refut" {
    Overturned
  } else if t == "super" {
    Replaced
  } else if t == "withd" {
    Retracted
  } else {
    Pending
  }
}

///|
fn int_of(s : StringView) -> Int {
  @string.from_str(s.to_owned()) catch {
    _ => 0
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
  let nb = Notebook::new()
  for line in text.split("\n") {
    if line.length() == 0 {
      continue
    }
    let f = line.split("\t").collect()
    if f.length() < 11 || f[0].to_owned() != "finding" {
      continue
    }
    let sup = if f[8].to_owned() == "-" { None } else { Some(int_of(f[8])) }
    let text_field = if f.length() >= 12 { f[11].to_owned() } else { "" }
    nb.findings.push({
      id: int_of(f[1]),
      question: int_of(f[2]),
      claim: claim_of(f[3]),
      phase: phase_of(f[4]),
      result: int_of(f[5]),
      residual: int_of(f[6]),
      status: status_of(f[7]),
      supersedes: sup,
      author: int_of(f[9]),
      at: int_of(f[10]),
      text: text_field,
    })
  }
  nb
}
