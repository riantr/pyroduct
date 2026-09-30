///|
/// 持久化：可序列化、可版本追溯的账本。
///
/// 模型本身全是纯函数，跨轮次的「进化」无处安放；`Ledger` 就是那处。它是**只追加**
/// 的记录：每一代、每一个候选改动都留一行，连同它的基因组、适应度与判词，因此
/// 一次进化可以被完整地写下（`serialize`）、读回（`parse`），并接着跑。

///|
/// 一条记录：哪一代、第几个候选、父代是谁、改了哪里、判了什么、得分多少、基因组是什么。
pub struct Trail {
  generation : Int
  step : Int
  parent : Int? // 上一代最佳在账本中的下标；None = 种子
  locus : Locus
  what : String
  why : String // 裁决理由（接收／拒收／回滚）
  verdict : Judgement
  score : Int
  effect : Int // θ̂ 的千分位（因果判据时）
  effect_lo : Int // 置信下界千分位
  fitness : Fitness
  genome : Genome
}

///|
/// 一次进化的全部记录。
pub struct Ledger {
  seed : Genome
  objective : String
  trails : Array[Trail]
}

///|
/// 接收了多少条。
pub fn Ledger::accepted_count(self : Ledger) -> Int {
  let mut c = 0
  for t in self.trails {
    if t.verdict == Accepted {
      c += 1
    }
  }
  c
}

///|
/// 被宪法拒收了多少条（即：变异想改、宪法不许的改动）。
pub fn Ledger::rejected_count(self : Ledger) -> Int {
  let mut c = 0
  for t in self.trails {
    if t.verdict == RejectedConstitutional {
      c += 1
    }
  }
  c
}

///|
/// 当前最佳基因组：最后一条被接收的改动；没有就回到种子。
pub fn Ledger::current(self : Ledger) -> Genome {
  let mut g = self.seed
  for t in self.trails {
    if t.verdict == Accepted {
      g = t.genome
    }
  }
  g
}

///|
/// 一条被宪法拒收的例子（供报告用）。
pub fn Ledger::rejected_example(self : Ledger) -> String? {
  for t in self.trails {
    if t.verdict == RejectedConstitutional {
      return Some("\{t.what}　——　\{t.why}")
    }
  }
  None
}

// ── 持久化：编解码 ──────────────────────────────────────────────

///|
fn locus_code(l : Locus) -> String {
  match l {
    Prompt => "prompt"
    Strategy => "strategy"
    Memory => "memory"
    Code => "code"
  }
}

///|
fn locus_of(c : StringView) -> Locus {
  let s = c.to_owned()
  if s == "prompt" {
    Prompt
  } else if s == "memory" {
    Memory
  } else if s == "code" {
    Code
  } else {
    Strategy
  }
}

///|
fn voice_code(v : Voice) -> String {
  match v {
    Declarative => "decl"
    Suggestive => "sugg"
    Withholding => "with"
  }
}

///|
fn voice_of(c : StringView) -> Voice {
  let s = c.to_owned()
  if s == "decl" {
    Declarative
  } else if s == "with" {
    Withholding
  } else {
    Suggestive
  }
}

///|
fn regime_code(r : @multi.TruthRegime) -> String {
  match r {
    @multi.Immanent => "immanent"
    @multi.Logos => "logos"
    @multi.SuperSubjective => "supra"
    @multi.InterSubjective => "inter"
    @multi.ChengRan => "cheng"
  }
}

///|
fn regime_of(c : StringView) -> @multi.TruthRegime {
  let s = c.to_owned()
  if s == "immanent" {
    @multi.Immanent
  } else if s == "logos" {
    @multi.Logos
  } else if s == "supra" {
    @multi.SuperSubjective
  } else if s == "cheng" {
    @multi.ChengRan
  } else {
    @multi.InterSubjective
  }
}

///|
fn verdict_code(j : Judgement) -> String {
  match j {
    Accepted => "acc"
    RejectedConstitutional => "rej"
    RevertedRegression => "rev"
    Tie => "tie"
  }
}

///|
fn verdict_of(c : StringView) -> Judgement {
  let s = c.to_owned()
  if s == "acc" {
    Accepted
  } else if s == "rej" {
    RejectedConstitutional
  } else if s == "rev" {
    RevertedRegression
  } else {
    Tie
  }
}

///|
/// 基因组 → 一行文本（`|` 分隔，六段）。
pub fn Genome::encode(self : Genome) -> String {
  [
    voice_code(self.voice),
    regime_code(self.regime),
    "\{self.toward_other}",
    "\{self.toward_self}",
    "\{self.carry}",
    "\{self.reason}",
  ].join("|")
}

///|
/// 一行文本 → 基因组。
pub fn Genome::decode(text : String) -> Genome {
  let p = text.split("|").collect()
  if p.length() < 6 {
    return default_agent()
  }
  {
    voice: voice_of(p[0]),
    regime: regime_of(p[1]),
    toward_other: int_of(p[2]),
    toward_self: int_of(p[3]),
    carry: int_of(p[4]),
    reason: int_of(p[5]),
  }
}

///|
fn int_of(c : StringView) -> Int {
  @string.from_str(c.to_owned()) catch {
    _ => 0
  }
}

///|
fn ints_of(c : StringView) -> Array[Int] {
  let out : Array[Int] = []
  for x in c.split(",") {
    out.push(int_of(x))
  }
  out
}

///|
/// 账本 → 文本（制表符分隔；首两行是种子与目标名）。
pub fn Ledger::serialize(self : Ledger) -> String {
  let lines : Array[String] = [
    "seed\t\{self.seed.encode()}",
    "objective\t\{self.objective}",
  ]
  for t in self.trails {
    let parent = match t.parent {
      Some(i) => "\{i}"
      None => "-"
    }
    lines.push(
      [
        "trail",
        "\{t.generation}",
        "\{t.step}",
        parent,
        locus_code(t.locus),
        verdict_code(t.verdict),
        "\{t.score}",
        "\{t.effect}",
        "\{t.effect_lo}",
        [
          "\{t.fitness.consensus}",
          "\{t.fitness.stability}",
          "\{t.fitness.residue}",
          "\{t.fitness.cost}",
        ].join(","),
        t.genome.encode(),
        t.what,
        t.why,
      ].join("\t"),
    )
  }
  lines.join("\n")
}

///|
/// 文本 → 账本。
pub fn parse(text : String) -> Ledger {
  let mut seed = default_agent()
  let mut objective = ""
  let trails : Array[Trail] = []
  for line in text.split("\n") {
    if line.length() == 0 {
      continue
    }
    let f = line.split("\t").collect()
    if f.length() == 0 {
      continue
    }
    let tag = f[0].to_owned()
    if tag == "seed" && f.length() >= 2 {
      seed = Genome::decode(f[1].to_owned())
    } else if tag == "objective" && f.length() >= 2 {
      objective = f[1].to_owned()
    } else if tag == "trail" && f.length() >= 13 {
      let fit = ints_of(f[9])
      trails.push({
        generation: int_of(f[1]),
        step: int_of(f[2]),
        parent: if f[3].to_owned() == "-" {
          None
        } else {
          Some(int_of(f[3]))
        },
        locus: locus_of(f[4]),
        verdict: verdict_of(f[5]),
        score: int_of(f[6]),
        effect: int_of(f[7]),
        effect_lo: int_of(f[8]),
        fitness: {
          consensus: fit[0],
          stability: fit[1],
          residue: fit[2],
          cost: fit[3],
        },
        genome: Genome::decode(f[10].to_owned()),
        what: f[11].to_owned(),
        why: f[12].to_owned(),
      })
    }
  }
  { seed, objective, trails, }
}
