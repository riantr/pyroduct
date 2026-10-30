///|
/// 执行契约的**设计与检查**：DbC 契约 ＋ 轨迹覆盖。
///
/// 「执行契约」此前只是 `step` 的五种回执——它说了**会回什么**，没说**凭什么**。
/// 凭什么在迁移表里，而表与回执之间**没有一道锁**：改坏了 `step`，只要回执的名字
/// 还对，外面看不出来。缺口（`Block`）与未定点（`Open`）尤其危险——那两种回执
/// 说的都是「没有什么」，说错了不会显形。
///
/// 这里补两道锁，形状取自 Sismic（`AlexandreDecan/sismic`，状态图解释器与检查器）
/// 的做法：**契约挂在状态与迁移上，求值点精确**。它没有 property-based testing，
/// 也不做状态空间穷尽探索，所以本层不引入生成器、不引入守卫字符串、不引入嵌套
/// 状态与历史状态——那些是它的取舍，不是它的长处。
///
/// 三条纪律：
///
/// - **求值点精确**。契约的求值点写下来：整机不变式求值一次、阶段不变式在**每个
///   阶段**上求值一次、迁移后置在**每个位置 × 槽**的求值点上求值一次。求值点写
///   下来，才谈得上「这一步保证了什么」。
/// - **契约不许空转**。每条契约都要有**能失败**的判据。一条恒真的契约不是契约，
///   恒真的包装层更不是。
/// - **失败闭合**。契约表里若有判据没人求值，那是**失败**，不是「没关系」。
///   「看不见」不等于「没问题」。
///
/// 关于 **before** 这一段为什么空着：本模型**没有守卫**——迁移表本身就是许可结构，
/// 没有额外的「允许条件」表达式可查。所以「事前」没有可失败的判据，硬凑一条等于
/// 造一条空判据。空着，并且把空着的**理由**写在这里，好过放一条恒真的检查。

///|
/// 契约的求值点。
pub(all) enum ContractKind {
  AlwaysMachine // 恒真（整机）：求值一次
  AlwaysPhase // 恒真（阶段）：每个阶段求值一次
  AfterStep // 事后（位置 × 槽）：每个位置 × 槽的求值点上求值一次
} derive(Eq)

///|
pub extend ContractKind with Eq::{not_equal, equal}

///|
/// 求值点的名。
pub fn ContractKind::label(self : ContractKind) -> String {
  match self {
    AlwaysMachine => "恒真（整机）"
    AlwaysPhase => "恒真（阶段）"
    AfterStep => "事后（位置 × 槽）"
  }
}

///|
/// 契约的判据。
///
/// `match` 一律**穷举**（不写 `_` 臂）：加一个新判据而不给它求值方式，编译器
/// 就会拒绝——这把「契约表里没人求值」从运行时的失败闭合提前到编译期。
pub(all) enum Check {
  Reachable // 有入边的位置，必自起点可达
  HasIncoming // 自起点可达的位置（起点除外），必有入边
  PhaseHasNonAct // 该阶段至少有一条非「行动」的出边
  ReceiptExact // 回执点名的边与迁移表**完全相符**（不多不少）
} derive(Eq)

///|
pub extend Check with Eq::{not_equal, equal}

///|
/// 判据的名。
pub fn Check::label(self : Check) -> String {
  match self {
    Reachable => "有入边的位置必自起点可达"
    HasIncoming => "自起点可达的位置必有入边"
    PhaseHasNonAct => "该阶段至少有一条非「行动」的出边"
    ReceiptExact => "回执点名的边与迁移表完全相符"
  }
}

///|
/// 一条契约。
pub(all) struct Contract {
  kind : ContractKind
  check : Check
  text : String
}

///|
/// 契约表。
///
/// 判据与求值点一一对应：`contracts_cover_all_checks` 盯着两个方向——表里有而
/// 枚举里没有的、以及枚举里有而表里没有的，都算失败。
pub fn contracts() -> Array[Contract] {
  [
    {
      kind: AlwaysMachine,
      check: Reachable,
      text: "凡有入边的位置，必自起点可达——进得去就出得来，机器里没有岛",
    },
    {
      kind: AlwaysMachine,
      check: HasIncoming,
      text: "凡自起点可达的位置（起点除外），必有入边——没有凭空出现的位置",
    },
    {
      kind: AlwaysPhase,
      check: PhaseHasNonAct,
      text: "每个阶段至少有一条非「行动」的出边，否则整段被还原成目的—手段回路",
    },
    {
      kind: AfterStep,
      check: ReceiptExact,
      text: "回执点名的边与迁移表完全相符：多一条、少一条、把缺口说成出路，都是违约",
    },
  ]
}

///|
/// 全部判据（枚举的权威清单）。
pub fn all_checks() -> Array[Check] {
  [Reachable, HasIncoming, PhaseHasNonAct, ReceiptExact]
}

///|
/// 契约表与判据清单**双向**吻合：表里的判据都认得，认得的判据都在表里。
pub fn contracts_cover_all_checks() -> Bool {
  for c in all_checks() {
    let mut in_table = false
    for k in contracts() {
      if k.check == c {
        in_table = true
      }
    }
    if !in_table {
      return false
    }
  }
  for k in contracts() {
    if !all_checks().contains(k.check) {
      return false
    }
  }
  true
}

///|
/// 该判据该在哪种求值点上求值。
pub fn kind_of_check(c : Check) -> ContractKind {
  match c {
    Reachable => AlwaysMachine
    HasIncoming => AlwaysMachine
    PhaseHasNonAct => AlwaysPhase
    ReceiptExact => AfterStep
  }
}

///|
/// 契约表自身是**良构**的：每条契约的求值点与它的判据相配。
///
/// 判据与求值点配错了，求值就落不到该落的地方——比如把「回执是否与表相符」挂到
/// 整机求值点上，它就永远成立（`at`／`slot`／`out` 都不对，却没人拦得住）。
pub fn contracts_well_formed() -> Bool {
  for k in contracts() {
    if k.kind != kind_of_check(k.check) {
      return false
    }
  }
  true
}

///|
/// 该位置有没有入边。
pub fn has_incoming(state : SubjectState) -> Bool {
  for t in transitions() {
    if t.to == state {
      return true
    }
  }
  false
}

///|
/// 有入边的位置的 designation。
pub fn inbound_designations() -> Array[String] {
  let out : Array[String] = []
  for s in all_states() {
    if has_incoming(s) {
      out.push(s.designation())
    }
  }
  out
}

///|
/// 自起点可达的位置的 designation。
pub fn reachable_designations() -> Array[String] {
  let out : Array[String] = []
  for s in all_states() {
    if reachable(initial(), s) {
      out.push(s.designation())
    }
  }
  out
}

///|
/// 纯函数版：**有入边却自起点不可达**的位置（正常是空）。
///
/// 例外是**入口**：本模型有两个退化起点（失忆与浑噩，「两条退化起点汇入站立」），
/// 它们有出边、没有入边，也自起点不可达——那是设计，不是缺陷。所以判据只在
/// 「有入边」的位置上要求可达。
///
/// 取料与判定分开，同 `every_phase_has_non_act_of` 的理由：真表上本判定恒为空，
/// 只看真表的判据分不出「检查在跑」与「检查恒真」。判据喂它一份**造出来的**清单
/// 才验得动。
pub fn unreachable_of(
  reachable : Array[String],
  sources : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  for d in sources {
    if !reachable.contains(d) {
      out.push(d)
    }
  }
  out
}

///|
/// 纯函数版：**自起点可达却没有入边**的位置（正常是空）。
///
/// 起点本身除外：它是流水线的头，没有来路是定义，不是缺陷。
pub fn incomingless_of(
  reachable : Array[String],
  sources : Array[String],
  start : String,
) -> Array[String] {
  let out : Array[String] = []
  for d in reachable {
    if d != start && !sources.contains(d) {
      out.push(d)
    }
  }
  out
}

///|
/// 有非「行动」出边的阶段。
pub fn phases_with_non_act() -> Array[Phase] {
  let covered : Array[Phase] = []
  for t in transitions() {
    if t.trigger.slot() != Act {
      let p = t.from.phase()
      if !covered.contains(p) {
        covered.push(p)
      }
    }
  }
  covered
}

///|
/// 没有非「行动」出边的阶段（正常是空）。
pub fn phases_without_non_act() -> Array[Phase] {
  let out : Array[Phase] = []
  let covered = phases_with_non_act()
  for p in all_phases() {
    if !covered.contains(p) {
      out.push(p)
    }
  }
  out
}

///|
/// 回执**点名**了哪些边。
///
/// 这是契约的关键取料：五种回执各自点了什么边，都要在这里说清楚。若某条回执
/// 点了表里没有的边，契约就会失败——**回执不许编造**。
pub fn receipt_edges(out : Outcome) -> Array[(Trigger, SubjectState)] {
  match out {
    Moved(tr, to) => [(tr, to)]
    Held(tr, s) => [(tr, s)]
    Same(_, named, to) => {
      let edges : Array[(Trigger, SubjectState)] = []
      for tr in named {
        edges.push((tr, to))
      }
      edges
    }
    Open(cands) => cands
    Block(_) => []
  }
}

///|
/// 两条边集是否相同（多重集意义：条数相同且互相涵盖）。
fn same_edges(
  a : Array[(Trigger, SubjectState)],
  b : Array[(Trigger, SubjectState)],
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for e in a {
    let mut found = false
    for f in b {
      if e.0 == f.0 && e.1 == f.1 {
        found = true
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
/// 回执与迁移表**完全相符**：不多不少。
///
/// 这一条不是「回执说的边都在表里」——那太弱，漏报也能过。要**恰好**是表里
/// 那几条：`Block` 说的「没有边」必须真的没有；`Open` 与 `Same` 说的候选必须
/// 一条不少、一条不多。
pub fn receipt_matches(
  state : SubjectState,
  slot : Slot,
  out : Outcome,
) -> Bool {
  same_edges(receipt_edges(out), candidates(state, slot))
}

///|
/// 求值点：一个位置、一个槽、一次回执。
pub(all) struct Point {
  at : SubjectState
  slot : Slot
  out : Outcome
}

///|
/// 全部求值点：每个位置 × 每个槽走一步。
///
/// 272 个位置 × 槽组合，每一个都是一个求值点——契约在**全部**求值点上求值，
/// 不是抽检。五种回执（迁／守／未定／同归／无路）在这 272 个点上都会出现，
/// 所以契约不是只验了最容易的那一种。
pub fn all_points() -> Array[Point] {
  let out : Array[Point] = []
  for s in all_states() {
    for k in all_slots() {
      out.push({ at: s, slot: k, out: step(s, k), })
    }
  }
  out
}

///|
/// 契约在给定点上的判定：成立与否，以及**破在哪里**。
///
/// 只有这一处 `match`，且**穷举**（不写 `_` 臂）：加一个新判据而不给它求值方式，
/// 编译器就会拒绝。
fn evaluate(
  c : Contract,
  at : SubjectState,
  slot : Slot,
  out : Outcome,
) -> (Bool, Array[String]) {
  match c.check {
    Reachable => {
      let bad = unreachable_of(reachable_designations(), inbound_designations())
      (bad.length() == 0, bad)
    }
    HasIncoming => {
      let bad = incomingless_of(
        reachable_designations(),
        inbound_designations(),
        initial().designation(),
      )
      (bad.length() == 0, bad)
    }
    PhaseHasNonAct => {
      let bad : Array[String] = []
      for p in phases_without_non_act() {
        bad.push(p.label())
      }
      (bad.length() == 0, bad)
    }
    ReceiptExact => {
      let bad : Array[String] = []
      if !receipt_matches(at, slot, out) {
        bad.push(
          "\{at.designation()} × \{slot.designation()}：回执「\{out.label()}」与迁移表不相符",
        )
      }
      (bad.length() == 0, bad)
    }
  }
}

///|
/// 契约检查的结果。
///
/// `checked` 是求值次数；`held` 是成立的次数；`broken` 是破约的次数。
/// `broken` 不为零即不通过——**失败闭合**：没查到的、查漏的，都算破。
pub(all) struct ContractReport {
  checked : Int32
  held : Int32
  broken : Int32
  faults : Array[String]
}

///|
/// 契约是否全部成立。
pub fn ContractReport::ok(self : ContractReport) -> Bool {
  self.broken == 0
}

///|
/// 核验全部契约。
///
/// 三段求值：整机不变式求值一次、阶段不变式在每个阶段上求值一次、迁移后置在每个
/// 位置 × 槽的求值点上求值一次。求值点写进报告里，好让人知道「查了多少」。
pub fn check_contracts() -> ContractReport {
  let table = contracts()
  let mut checked = 0
  let mut held = 0
  let mut broken = 0
  let faults : Array[String] = []
  let phases = all_phases()
  let states = all_states()
  let slots = all_slots()
  for c in table {
    if c.kind == AlwaysMachine {
      checked += 1
      let (good, bad) = evaluate(c, states[0], slots[0], Block(""))
      if good {
        held += 1
      } else {
        broken += 1
        faults.push(
          "破约（\{c.check.label()}）：\{bad.join("、")}　\{c.text}",
        )
      }
    }
  }
  for p in phases {
    for c in table {
      if c.kind != AlwaysPhase {
        continue
      }
      checked += 1
      let (good, _bad) = evaluate(c, states[0], slots[0], Block(""))
      if good {
        held += 1
      } else {
        broken += 1
        faults.push(
          "破约（\{c.check.label()}）：阶段 \{p.label()}　\{c.text}",
        )
      }
    }
  }
  for pt in all_points() {
    for c in table {
      if c.kind != AfterStep {
        continue
      }
      checked += 1
      let (good, bad) = evaluate(c, pt.at, pt.slot, pt.out)
      if good {
        held += 1
      } else {
        broken += 1
        faults.push(
          "破约（\{c.check.label()}）：\{bad.join("、")}　\{c.text}",
        )
      }
    }
  }
  { checked, held, broken, faults, }
}

///|
/// 契约核验报告（人读）。
pub fn render_contract_report(r : ContractReport) -> String {
  let lines : Array[String] = []
  lines.push(
    "契约 \{contracts().length()} 条，求值 \{r.checked} 次，成立 \{r.held} 次，破约 \{r.broken} 次",
  )
  lines.push(
    "求值点：恒真（整机）1 次 × 2 条｜恒真（阶段）\{all_phases().length()} 次 × 1 条｜事后（位置 × 槽）\{all_points().length()} 次 × 1 条",
  )
  if r.broken > 0 {
    lines.push("")
    lines.push("## 破约之处")
    for f in r.faults {
      lines.push("- \{f}")
    }
  }
  lines.join("\n")
}

///|
/// 轨迹覆盖：迁移表的哪些行被走过了。
///
/// `total` 是迁移表的行数；`exercised` 是被走过的行数；`missing` 是**从未被走过**
/// 的行——它们不是错的，只是没被证明过。把「没走过」说出来，和把「走过了」说
/// 出来一样重要。
pub(all) struct CoverageReport {
  total : Int32
  exercised : Int32
  missing : Array[(SubjectState, Trigger, SubjectState)]
}

///|
/// 覆盖是否走遍全表。
pub fn CoverageReport::ok(self : CoverageReport) -> Bool {
  self.missing.length() == 0
}

///|
/// 覆盖报告（人读）。
pub fn render_coverage(c : CoverageReport) -> String {
  let lines : Array[String] = []
  lines.push(
    "迁移表 \{c.total} 行，走过 \{c.exercised} 行，未走过 \{c.missing.length()} 行",
  )
  for m in c.missing {
    lines.push(
      "- 未走过：\{m.0.designation()} —「\{m.1.label()}」→ \{m.2.designation()}",
    )
  }
  lines.join("\n")
}

///|
/// 一条迁移行的键。
fn edge_key(
  from : SubjectState,
  trigger : Trigger,
  to : SubjectState,
) -> String {
  "\{from.designation()}|\{trigger.label()}|\{to.designation()}"
}

///|
/// 一批走法的覆盖。
pub fn row_coverage(traces : Array[Trace]) -> CoverageReport {
  let seen : Array[String] = []
  for tr in traces {
    for step in tr.detailed() {
      for e in receipt_edges(step.outcome) {
        let key = edge_key(step.from, e.0, e.1)
        if !seen.contains(key) {
          seen.push(key)
        }
      }
    }
  }
  let missing : Array[(SubjectState, Trigger, SubjectState)] = []
  let mut exercised = 0
  for t in transitions() {
    if seen.contains(edge_key(t.from, t.trigger, t.to)) {
      exercised += 1
    } else {
      missing.push((t.from, t.trigger, t.to))
    }
  }
  { total: transitions().length(), exercised, missing, }
}

///|
/// 主线（`course`）走成的轨迹。
///
/// 主线是模型自己规定的那条路。它被走成一条轨迹，才能问「主线走过了迁移表的
/// 多少行」。找不到对应的边就**不编造**：那一步被跳过，主线因此可能短于原文的
/// 主线——短了多少写在 `course_trace_steps` 里，不藏着。
pub fn course_trace() -> Trace {
  let line = course()
  let steps : Array[(Slot, Outcome)] = []
  let mut at = line[0]
  for i = 1; i < line.length(); i = i + 1 {
    let target = line[i]
    let mut found = false
    for t in transitions() {
      if t.from == at && t.to == target && !found {
        found = true
        let o = if t.to == t.from {
          Held(t.trigger, t.to)
        } else {
          Moved(t.trigger, t.to)
        }
        steps.push((t.trigger.slot(), o))
        at = target
      }
    }
  }
  { start: line[0], steps, }
}

///|
/// 主线实际走过的步数（`course` 的长度是位置数，不是步数）。
pub fn course_trace_steps() -> Int32 {
  course_trace().steps.length()
}

///|
/// 主线的覆盖。
pub fn course_coverage() -> CoverageReport {
  row_coverage([course_trace()])
}
