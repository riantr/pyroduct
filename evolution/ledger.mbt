///|
/// 持久化：可序列化、可版本追溯的账本。
///
/// 模型本身全是纯函数，跨轮次的「进化」无处安放；`Ledger` 就是那处。它是**只追加**
/// 的记录：每一代、每一个候选改动都留一行，连同它的基因组、适应度与判词，因此
/// 一次进化可以被完整地写下（`serialize`）、读回（`parse`），并接着跑。

///|
/// 一条记录：哪一代、第几个候选、父代是谁、改了哪里、判了什么、得分多少、基因组是什么。
pub struct Trail {
  generation : Int32
  step : Int32
  parent : Int32? // 上一代最佳在账本中的下标；None = 种子
  locus : Locus
  what : String
  why : String // 裁决理由（接收／拒收／回滚）
  verdict : Judgement
  score : Int32
  effect : Int32 // θ̂ 的千分位（因果判据时）
  effect_lo : Int32 // 置信下界千分位
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
pub fn Ledger::accepted_count(self : Ledger) -> Int32 {
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
pub fn Ledger::rejected_count(self : Ledger) -> Int32 {
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

// ── 树视图 ────────────────────────────────────────────────────
//
// 账本是**只追加**的，而每条记录都记着「我的父是账本里的第几条」。这两件事合起来
// 就已经是一棵树：父下标必然小于自身，所以不会有环；每条记录至多一个父，所以
// 不会分叉出两条同父的世系之外的东西。下面这组函数只是把这棵已经在那里的树
// 显式地读出来，并给出它的健康检查（`tree_ok` / `tree_faults`）。
//
// 为什么值得显式化：账本原本把父写成「上一代的**编号**」。而一代要记十四条候选，
// 于是那个编号根本不是下标——记下来的「遗传」指向了别的候选。树视图的存在让这条
// 关系可证伪，而不是靠注释声称。

///|
/// 全部根：父为 None 的记录下标。只追加的账本里根必在前面，故天然有序。
pub fn Ledger::roots(self : Ledger) -> Array[Int32] {
  let out : Array[Int32] = []
  for i = 0; i < self.trails.length(); i = i + 1 {
    if self.trails[i].parent == None {
      out.push(i)
    }
  }
  out
}

///|
/// 某条记录的直接子记录下标（按追加顺序）。
pub fn Ledger::children(self : Ledger, i : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  if i < 0 || i >= self.trails.length() {
    return out
  }
  for j = 0; j < self.trails.length(); j = j + 1 {
    match self.trails[j].parent {
      Some(p) => if p == i { out.push(j) }
      None => ()
    }
  }
  out
}

///|
/// 从根到该记录的血缘路径：根在前，含自己。
///
/// 向上走有步数上限。只追加的账本里父必在子前，三步就到根；但一本手改过或旧版
/// 写坏的账本可能把父指到后面去，没有上限就是死循环——**读一个坏掉的结构不该把
/// 进程挂住**。超限时返回已经走到的部分，不假装它是一条完整世系。
pub fn Ledger::ancestry(self : Ledger, i : Int32) -> Array[Int32] {
  let up : Array[Int32] = []
  let mut cur = i
  let mut steps = 0
  while cur >= 0 && cur < self.trails.length() && steps <= self.trails.length() {
    up.push(cur)
    match self.trails[cur].parent {
      Some(p) => cur = p
      None => break
    }
    steps += 1
  }
  let out : Array[Int32] = []
  for k = up.length() - 1; k >= 0; k = k - 1 {
    out.push(up[k])
  }
  out
}

///|
/// 某条记录的深度：根为 0。
pub fn Ledger::depth(self : Ledger, i : Int32) -> Int32 {
  let a = self.ancestry(i)
  if a.length() == 0 {
    0
  } else {
    a.length() - 1
  }
}

///|
/// 树高：最深一条记录的深度 + 1；空账本为 0。
pub fn Ledger::height(self : Ledger) -> Int32 {
  let mut h = 0
  for i = 0; i < self.trails.length(); i = i + 1 {
    let d = self.depth(i) + 1
    if d > h {
      h = d
    }
  }
  h
}

///|
/// 叶子（没有子记录的那些）。
pub fn Ledger::leaves(self : Ledger) -> Array[Int32] {
  let out : Array[Int32] = []
  for i = 0; i < self.trails.length(); i = i + 1 {
    if self.children(i).length() == 0 {
      out.push(i)
    }
  }
  out
}

///|
/// 世系：根到该记录，每一步「改了什么」串成一行。
pub fn Ledger::lineage(self : Ledger, i : Int32) -> String {
  let parts : Array[String] = []
  for k in self.ancestry(i) {
    parts.push(self.trails[k].what)
  }
  if parts.length() == 0 {
    "（无）"
  } else {
    parts.join(" ⟶ ")
  }
}

///|
/// **结构**不变式被破坏的理由（空数组 = 全部成立）。只查账本自身能查的东西：
///
///   1. **父不在自己之前**：只追加的账本里父必在子前。越界、或指到后面 ⇒ 这本账坏了。
///      这条同时保证无环，所以 `ancestry` 不必再做别的防护。
///   2. **深度 > 世代号**：一回合至多往下一代传一层，深过世代号说明父子关系乱指。
///      注意是 `>` 不是 `≠`：深度与世代号只在「一条干净的链」上相等，一旦某回合的
///      改动没被接下（见 `descent_faults`），后来的记录会重新起根，那时深度 < 世代号
///      是对的。把相等当不变量，等于逼所有账本都得是链。
///   3. **世代号没有往前走**：非根记录的父必须来自**更早的**世代。一代只推进一格，
///      所以 `父.世代 < 子.世代` 恒应成立。早先只查「深度 ≤ 世代」，于是 hand-built
///      的一条 `gen3(根) → gen3 → gen4` 能同时骗过两层判据：下标合法、深度合法，
///      可父与子自称同一代。这一条补的就是那个缝。
pub fn Ledger::tree_faults(self : Ledger) -> Array[String] {
  let bad : Array[String] = []
  for i = 0; i < self.trails.length(); i = i + 1 {
    let d = self.depth(i)
    if d > self.trails[i].generation {
      bad.push(
        "#\{i} 深度 \{d} 超过它的世代号 \{self.trails[i].generation}",
      )
    }
    match self.trails[i].parent {
      None => ()
      Some(p) =>
        if p < 0 || p >= i {
          bad.push(
            "#\{i} 的父下标 \{p} 不在它自己之前（只追加的账本里父必在子前）",
          )
        } else if self.trails[p].generation >= self.trails[i].generation {
          bad.push(
            "#\{i} 的父 #\{p} 与它同代或更晚（父 #{self.trails[p].generation} ≥ 子 #{self.trails[i].generation}）",
          )
        }
    }
  }
  bad
}

///|
/// 结构不变式是否全部成立（无环、父在子前、深度不超世代）。任何只追加的账本都该过。
pub fn Ledger::tree_ok(self : Ledger) -> Bool {
  self.tree_faults().length() == 0
}

///|
/// **遗传**不变式被破坏的理由（空数组 = 全部成立）。比结构更进一步：它问的不是
/// 「父下标合不合法」，而是「父指向的那条记录，是不是这一条真正的来路」。
///
///   1. **父既不是根、也不是被接收的记录**。下一代的候选是从上一代**被接收**的基因组
///      生成的。宪法拦下或闸门回滚的改动不能成为谁的父——从别处借一个当父，记下来的
///      「遗传」就是假的。
///   2. **与父差的多于一处**。变异是单步的（`mutations` 每次只改一层），差多处说明
///      父子关系记错了。
///   3. **父下标不在可分析的范围里**（越界或指到后面）。这一条是补上一个洞：早先
///      的写法在 `0 <= p < i` 不成立时**直接跳过**，于是一本自指／前指的账本
///      `descent_ok` 会**真空地成立**——恰恰是结构那一层要抓的畸形，遗传这一层却
///      报「没问题」。不可分析不等于没问题。
///
/// **「至多一处」，不是「恰好一处」**：这一条最初写的是 `== 1`，并且因此把一本合法
/// 账本判红了（实测：省力目标、8 代，`#93 与父 #79 差 0 处`）。原因是 `mutations`
/// 用 `clamp100` 夹取两诚，某层触底后再加同一方向的改动就是**原地踏步**，候选与父代
/// 逐字节相同。`diff == 0` 是合法结果，不是记账错误——判据红了健康账本，比漏了
/// 坏账本更糟，它会教人忽略自己。
///
/// **适用范围要说准**：`evolve` 的账本记的是真遗传，本判据对它成立。
///
/// `SubjectCycle::ledger` **不**满足它，也不该满足，但**理由不是**「开放被接下时来路
/// 没有记录」——那是早先文档里的说法，`cycle.mbt:316` 并非如此：它每回合都写
/// `Some(i - 1)`，从不停在 `None`。真实理由是**这本账记的是尝试的先后，不是遗传**：
/// 每一回合的修习候选都从**该回合进场时的基因组**生成，而那份基因组只在某个 F_t 被
/// 接下时才往前走。若某一回合被拒或回滚，下一回合的候选其实是从**更早**的那份基因组
/// 生成的——此时「父＝上一条」声称的正是一次没有发生的遗传。差 0 处也是同一个成因：
/// 残余已到 1 时再减 4，候选与父代相同。
pub fn Ledger::descent_faults(self : Ledger) -> Array[String] {
  let bad : Array[String] = []
  for i = 0; i < self.trails.length(); i = i + 1 {
    let t = self.trails[i]
    match t.parent {
      None =>
        if diff_count(self.seed, t.genome) > 1 {
          bad.push(
            "#\{i} 是根，与种子差 \{diff_count(self.seed, t.genome)} 处（至多一处）",
          )
        }
      Some(p) =>
        if p >= 0 && p < i {
          let par = self.trails[p]
          if par.verdict != Accepted {
            bad.push(
              "#\{i} 的父 #\{p} 是「\{par.verdict.label()}」，不是被接收的记录",
            )
          }
          if diff_count(par.genome, t.genome) > 1 {
            bad.push(
              "#\{i} 与父 #\{p} 差 \{diff_count(par.genome, t.genome)} 处（至多一处）",
            )
          }
        } else {
          bad.push(
            "#\{i} 的父下标 #{p} 不在可分析的范围（本条无法验证，不等于没问题）",
          )
        }
    }
  }
  bad
}

///|
/// 遗传不变式是否成立。只对**确实在记真遗传**的账本才有意义（见 `descent_faults`）。
pub fn Ledger::descent_ok(self : Ledger) -> Bool {
  self.descent_faults().length() == 0
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
fn int_of(c : StringView) -> Int32 {
  @string.from_str(c.to_owned()) catch {
    _ => 0
  }
}

///|
fn ints_of(c : StringView) -> Array[Int32] {
  let out : Array[Int32] = []
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
