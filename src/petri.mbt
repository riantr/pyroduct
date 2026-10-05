///|
/// Petri 网面（CarlAdam 镜像，模型整理）：把主体机读成**多托肯** Petri 网。
///
/// 参照 CarlAdam（Python 的 Petri 网库，以 Carl Adam Petri 命名）：Petri 网
/// 用库所（Place，持托肯）、变迁（Transition，事件）、弧（Arc，库所↔变迁）
/// 描述分布式系统；**标识**（Marking，库所 → 托肯集）是全局状态——与经典
/// 状态机的单「当前位置」不同，Petri 网允许多托肯并发；发生（Occurrence）
/// 判使能、记效果（Consume／Produce），发火返回**新标识**（标识不可变）。
///
/// pyroduct 的对准：
///
///   - **库所** ↔ 34 个位置（`all_states`）；
///   - **变迁** ↔ 迁移表的一行（`Transition`：from → to，触发粒度），共 53 个
///     ——变迁是**一对一**的（一个输入库所、一个输出库所）；
///   - **弧** ↔ 迁移行本身（输入弧 from→t、输出弧 t→to）；
///   - **托肯** ↔ 主体。经典读法单托肯；本面允许多托肯——**群体**在同一
///     机器上并发行走（进化层的世代即多托肯的真实机制）；
///   - **使能** ↔ 输入库所有托肯且变迁存在——228 处无路**没有对应变迁**：
///     缺口即结构，不使能由结构给出，无须守卫（evolution 的宪法才是守卫）；
///   - **效果** ↔ Consume(from) + Produce(to)；守（自环）＝同库所一收一发，
///     净变化为零；每次发火**托肯守恒**（一对一，测试锁定）；
///   - **结构冲突** ↔ 未定：同一槽的多个变迁共享输入库所——Petri 网里这是
///     竞争同一托肯的冲突；pyroduct 的仲裁照旧不在 src（双诚之比，0.1.15）；
///   - **着色** ↔ 托肯之色＝基因组（进化层）：本面无色（纯计数标识），着色
///     Petri 网（CPN）的对应记档在此，色不进 src（`先行` 不带数的纪律）；
///   - **标识不可变** ↔ 发火返回新标识（MoonBit 的 Map 即不可变，与 CarlAdam
///     的 pyrsistent 同构）。
///
/// 出处层：模型整理——Petri 语义是结构视角，不引其数。

///|
/// 标识：库所（位置的定名）→ 托肯数。不可变；发火返回新标识。
pub(all) struct PetriMarking {
  counts : Map[String, Int]
} derive(Eq)

///|
pub extend PetriMarking with Eq::{not_equal, equal}

///|
/// 从托肯列表构造标识（同库所多托肯自动合并计数）。
pub fn petri_marking_of(tokens : Array[SubjectState]) -> PetriMarking {
  let counts : Map[String, Int] = Map([])
  for t in tokens {
    let k = t.designation()
    counts[k] = petri_at_counts(counts, k) + 1
  }
  { counts, }
}

///|
fn petri_at_counts(counts : Map[String, Int], key : String) -> Int {
  match counts.get(key) {
    Some(n) => n
    None => 0
  }
}

///|
/// 某库所的托肯数。
pub fn PetriMarking::at(self : PetriMarking, s : SubjectState) -> Int {
  petri_at_counts(self.counts, s.designation())
}

///|
/// 标识上的总托肯数——发火守恒（一对一）不变式的观测量。
pub fn PetriMarking::total(self : PetriMarking) -> Int {
  let mut n = 0
  for entry in self.counts {
    let (k, v) = entry
    let _ = k
    n += v
  }
  n
}

///|
/// Petri 变迁：迁移表的一行（一对一：一个输入库所、一个输出库所）。
pub(all) struct PetriTransition {
  from : SubjectState
  trigger : Trigger
  to : SubjectState
} derive(Eq)

///|
pub extend PetriTransition with Eq::{not_equal, equal}

///|
/// 全部 Petri 变迁（= 迁移表，53 个）。
pub fn petri_transitions() -> Array[PetriTransition] {
  let out : Array[PetriTransition] = []
  for t in transitions() {
    out.push({ from: t.from, trigger: t.trigger, to: t.to, })
  }
  out
}

///|
/// 使能的变迁：输入库所当前有托肯（CarlAdam 的 enabled_transitions）。
pub fn PetriMarking::enabled(self : PetriMarking) -> Array[PetriTransition] {
  let out : Array[PetriTransition] = []
  for t in petri_transitions() {
    if self.at(t.from) > 0 {
      out.push(t)
    }
  }
  out
}

///|
/// 发生的一次效果：从库所收一托肯 / 向库所放一托肯。
pub(all) enum PetriEffect {
  Consume(SubjectState) // 从库所移除一托肯
  Produce(SubjectState) // 向库所加入一托肯
} derive(Eq)

///|
pub extend PetriEffect with Eq::{not_equal, equal}

///|
/// 发火一条变迁：未使能或变迁不存在（缺口即结构）返回 None；
/// 成功返回（效果序列, 新标识）。托肯守恒：新标识的总数与原标识相同。
pub fn PetriMarking::fire(
  self : PetriMarking,
  t : PetriTransition,
) -> (Array[PetriEffect], PetriMarking)? {
  if self.at(t.from) == 0 {
    return None
  }
  let mut known = false
  for row in petri_transitions() {
    if row.from == t.from && row.trigger == t.trigger {
      known = true
    }
  }
  if !known {
    return None
  }
  let counts : Map[String, Int] = Map([])
  for entry in self.counts {
    let (k, v) = entry
    counts[k] = v
  }
  let effects : Array[PetriEffect] = []
  let kf = t.from.designation()
  let kt = t.to.designation()
  counts[kf] = petri_at_counts(counts, kf) - 1
  effects.push(Consume(t.from))
  counts[kt] = petri_at_counts(counts, kt) + 1
  effects.push(Produce(t.to))
  Some((effects, { counts, }))
}

///|
/// 便捷发火：按（位置, 触发）找变迁再发火。
pub fn PetriMarking::fire_by(
  self : PetriMarking,
  from : SubjectState,
  trigger : Trigger,
) -> (Array[PetriEffect], PetriMarking)? {
  for t in petri_transitions() {
    if t.from == from && t.trigger == trigger {
      return self.fire(t)
    }
  }
  None
}

///|
/// 定点显示：托肯数（供报告）。
fn petri_fmt_count(n : Int) -> String {
  n.to_string()
}

///|
/// Petri 网面的报告：概念对准、双托肯演示（并发视角）、守恒与冲突判读。

///|
/// 着色（托肯之色＝基因组）的实现状态：一句话，供报告与测试共用。
///
/// 记档自 0.1.17 起就写在文件头与报告里，但**没有人断言它**——散文里的
/// 「未实现」和代码里的「没有入口」可以各说各话。把它变成一个函数，报告与
/// 测试引同一处，就不会漂移。是否把基因组做进本面是**范围判断**（基因组住在
/// `evolution`，`src` 零 import），不在状态机层顺手替人定。
pub fn petri_coloring_status() -> String {
  "着色 ↔ 托肯之色＝基因组（进化层）：本面无色（计数标识），色不进 src；本面不实现着色。"
}

///|
/// 执行契约的报告：四组对照与并发演示。
pub fn render_petri_report() -> String {
  let lines : Array[String] = [
    "# Petri 网面（CarlAdam 镜像）", "", "参照 CarlAdam（以 Carl Adam Petri 命名的 Petri 网库）：库所持托肯、",
    "变迁是事件、标识（库所→托肯集）是全局状态——与经典状态机的单「当前位置」",
    "不同，Petri 网允许多托肯并发。出处层：模型整理——语义对准，不引其数。",
    "", "## 概念对准",
  ]
  lines.push(
    "- 库所 ↔ 34 个位置；变迁 ↔ 迁移表的 53 行（一对一：一收一发）；托肯 ↔ 主体；",
  )
  lines.push(
    "- 使能 ↔ 输入库所有托肯——228 处无路没有对应变迁：缺口即结构，无须守卫；",
  )
  lines.push(
    "- 效果 ↔ 一收一发；守（自环）＝同库所一收一发，净变化为零；每次发火托肯守恒；",
  )
  lines.push(
    "- 结构冲突 ↔ 未定：同一槽的多个变迁共享输入库所——仲裁照旧不在 src（双诚之比）；",
  )
  lines.push(petri_coloring_status())
  lines.push("")
  lines.push(
    "## 并发演示：两个托肯在同一机器上（multi 的结构对准）",
  )
  let m0 = petri_marking_of([Standing, Tranquility])
  lines.push(
    "- 初标识：立位×\{petri_fmt_count(m0.at(Standing))}　宁静×\{petri_fmt_count(m0.at(Tranquility))}（总 \{m0.total()} 托肯）",
  )
  let mut m = m0
  // 托肯甲：立位沿主线走一步（ActInFreedom → 自由）
  match m.fire_by(Standing, ActInFreedom) {
    Some((effects, m1)) => {
      m = m1
      let names : Array[String] = []
      for e in effects {
        match e {
          Consume(s) => names.push("收\{s.designation()}")
          Produce(s) => names.push("放\{s.designation()}")
        }
      }
      lines.push(
        "- 托肯甲表态：\{names.join("＋")}——标识：立位×\{m.at(Standing)}　自由×\{m.at(Freedom)}　宁静×\{m.at(Tranquility)}",
      )
    }
    None => lines.push("- 托肯甲表态：未使能")
  }
  // 托肯乙：宁静走重入（ReopenByHorizon → 反顾）
  match m.fire_by(Tranquility, ReopenByHorizon) {
    Some((effects, m1)) => {
      m = m1
      let names : Array[String] = []
      for e in effects {
        match e {
          Consume(s) => names.push("收\{s.designation()}")
          Produce(s) => names.push("放\{s.designation()}")
        }
      }
      lines.push(
        "- 托肯乙重开界域：\{names.join("＋")}——标识：自由×\{m.at(Freedom)}　反顾×\{m.at(Reflection)}　宁静×\{m.at(Tranquility)}",
      )
    }
    None => lines.push("- 托肯乙重开界域：未使能")
  }
  lines.push(
    "- 终标识总托肯 \{m.total()}（守恒：一收一发，\{m0.total()} → \{m.total()}）",
  )
  lines.push("")
  lines.push("## 判读")
  let conflict_slots : Map[String, Bool] = Map([])
  for s in all_states() {
    for k in all_slots() {
      match step(s, k) {
        Open(_) =>
          conflict_slots["\{s.designation()}×\{k.designation()}"] = true
        _ => ()
      }
    }
  }
  lines.push(
    "- 单托肯读法＝经典状态机（0.1.x 已有）；多托肯读法＝Petri 网：世代与群体",
  )
  lines.push(
    "  （进化层的多个基因组同时在机器上走）是本面真实的并发机制；",
  )
  lines.push(
    "- 结构冲突（未定）\{conflict_slots.length()} 处：竞争同一托肯的变迁组——经典 Petri 网",
  )
  lines.push(
    "  以任意仲裁解决冲突，pyroduct 把仲裁交给主体的双诚之比（0.1.15）与",
  )
  lines.push(
    "  β 权重诊断（0.1.17）——机器不替主体择其一；",
  )
  lines.push(
    "- 守恒：一对一的变迁使总托肯数恒定——主体不因行走而增减；会增减的是",
  )
  lines.push(
    "  群体（进化层的遗传），那在网外，不由网内的变迁制造。",
  )
  lines.join("\n")
}
