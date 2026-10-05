///|
/// 另两台机的自审计（0.1.28 新增，模型整理）。
///
/// `audit.mbt` 把**主体机**当程序读了一遍；本文件把同一套三鉴（结构鉴／类型鉴／
/// 行为鉴）扩到**群体机**与**社会机**——那两台此前没有静态审察面，验证面只覆盖
/// `src` 是个真缺口：机器可以「跑得动」而不被判过一次。
///
/// 两条必须说清的口径，否则报告里的数字会被误读：
///
/// 1. **两台机没有驱动槽。** 主体机有八槽，触发落槽是真实契约；群体机与社会机
///    的驱动就是**触发本身**（`one_edge_per_trigger` 为真，触发粒度确定），没有
///    槽这一层。故 `slot_names` 留空——MachineSpec 明文允许（空 = 跳过空槽检查），
///    类型鉴的槽层因此整层不参与；`trigger_slots` 按 (触发, 触发) 登记，只是为了
///    让结构鉴的「触发未声明」一项有据可查，**不是**凭空发明一层槽。
/// 2. **两台机没有终点。** `no_dead_end` 断言每个位置都有出边，「不封闭」是它们的
///    结构事实。把某个位置填进 `terminal` 会让结构鉴报「终点不可达」，那是把
///    「不封闭」误报成缺陷。故 `terminal` 一律留空（`""` = 无终点）。主体机相反：
///    静定极（宁静）可达且可重入，故 `audit.mbt` 如实报了它。
///
/// 出处纪律同 `audit.mbt`：发现分**已知设计**（按设计如此，报出时要说出处层）与
/// **未预期**（必须是零，回归绊线）两层。本层只读：不改判据、不修表。

///|
/// 群体机的 MachineSpec（20 状态 · 42 迁移 · 无槽 · 无终点）。
pub fn build_group_spec() -> @sa.MachineSpec {
  let states : Array[String] = []
  for s in @g.all_states() {
    states.push(s.designation())
  }
  let transitions : Array[(String, String, String)] = []
  for t in @g.transitions() {
    transitions.push(
      (t.from.designation(), t.trigger.label(), t.to.designation()),
    )
  }
  // 触发即驱动：按 (触发, 触发) 登记，让结构鉴认得每一句。
  let trigger_slots : Array[(String, String)] = []
  for t in @g.transitions() {
    let name = t.trigger.label()
    let mut fresh = true
    for pair in trigger_slots {
      if pair.0 == name {
        fresh = false
      }
    }
    if fresh {
      trigger_slots.push((name, name))
    }
  }
  // 无路必须说出口：把每一个 (位置, 触发) 无出边的组合连同理由交上去。
  let blocks : Array[(String, String, String)] = []
  for s in @g.all_states() {
    for name in group_triggers() {
      match @g.step(s, name.0) {
        @g.Block(reason) => blocks.push((s.designation(), name.1, reason))
        _ => ()
      }
    }
  }
  let course : Array[String] = []
  for s in @g.course() {
    course.push(s.designation())
  }
  {
    name: "群体",
    states,
    initial: @g.initial().designation(),
    terminal: "",
    transitions,
    trigger_slots,
    slot_names: [],
    blocks,
    course,
  }
}

///|
/// 群体机的全部触发（(枚举值, 原文措辞)），从迁移表去重得来——表外不存在的
/// 触发不构成驱动，与 `src::all_triggers` 同一纪律。
fn group_triggers() -> Array[(@g.GroupTrigger, String)] {
  let out : Array[(@g.GroupTrigger, String)] = []
  for t in @g.transitions() {
    let mut fresh = true
    for e in out {
      if e.0 == t.trigger {
        fresh = false
      }
    }
    if fresh {
      out.push((t.trigger, t.trigger.label()))
    }
  }
  out
}

///|
/// 社会机的 MachineSpec（13 状态 · 26 迁移 · 无槽 · 无终点）。
pub fn build_society_spec() -> @sa.MachineSpec {
  let states : Array[String] = []
  for s in @so.all_states() {
    states.push(s.designation())
  }
  let transitions : Array[(String, String, String)] = []
  for t in @so.transitions() {
    transitions.push(
      (t.from.designation(), t.trigger.label(), t.to.designation()),
    )
  }
  let trigger_slots : Array[(String, String)] = []
  for name in society_triggers() {
    trigger_slots.push((name.1, name.1))
  }
  let blocks : Array[(String, String, String)] = []
  for s in @so.all_states() {
    for name in society_triggers() {
      match @so.step(s, name.0) {
        @so.Block(reason) => blocks.push((s.designation(), name.1, reason))
        _ => ()
      }
    }
  }
  let course : Array[String] = []
  for s in @so.course() {
    course.push(s.designation())
  }
  {
    name: "社会",
    states,
    initial: @so.initial().designation(),
    terminal: "",
    transitions,
    trigger_slots,
    slot_names: [],
    blocks,
    course,
  }
}

///|
/// 社会机的全部触发（(枚举值, 原文措辞)），从迁移表去重得来——与群体机同一
/// 纪律：表外不存在的触发不构成驱动。
fn society_triggers() -> Array[(@so.Trigger, String)] {
  let out : Array[(@so.Trigger, String)] = []
  for t in @so.transitions() {
    let mut fresh = true
    for e in out {
      if e.0 == t.trigger {
        fresh = false
      }
    }
    if fresh {
      out.push((t.trigger, t.trigger.label()))
    }
  }
  out
}

///|
/// 一台机的一次三鉴结果。（不 derive Eq／Debug：外部库的 `Report` 没实现那两个
/// trait，本层也不去替它实现——那是库的事。）
pub(all) struct Verdict {
  machine : String
  known : Array[@sareport.Report]
  fresh : Array[@sareport.Report]
}

///|
/// 群体机／社会机的「已知设计」豁免清单：**空的**。
///
/// `audit.mbt` 给了主体机两条豁免（无忆／无筹只出不进），因为那两处**真的**
/// 只出不进。本文件不设豁免，理由是实测出来的：两台机的真表上一次发现都没有
/// （0 条，见报告首表）。既然没有已知设计可豁免，就不该预留一个口子——预留了，
/// 将来谁改坏一条边，报出来的「未用局部／不可达」会被静默归进「已知设计」，
/// 绊线就形同虚设。故一切发现都算未预期。
fn is_known_fleet(_f : @sareport.Report) -> Bool {
  false
}

///|
/// 把一批发现分成（已知设计，未预期）两层。
///
/// 单独成函数而不是内联在 `run_fleet_audit` 里：**分层本身要能测**。真表上一次
/// 发现都没有，所以在真表上「全塞已知设计」与「正确分层」输出完全一致——
/// 分层若只在真表上被验，它就是没被验的。给它一批**试造的发现**，它才受得住
/// 变异：任何「塞进已知设计」的改动都会让这条判据变红。
pub fn split_fleet(
  machine : String,
  findings : Array[@sareport.Report],
) -> Verdict {
  let known : Array[@sareport.Report] = []
  let fresh : Array[@sareport.Report] = []
  for f in findings {
    if is_known_fleet(f) {
      known.push(f)
    } else {
      fresh.push(f)
    }
  }
  { machine, known, fresh, }
}

///|
/// 造一条试造的发现（供分层判据用）。真表上没有发现可分层，故分层要拿造出来的
/// 发现来验；`zero_span` 是外部库给的空位置，本层不替它算哈希。
pub fn probe_finding(
  family : @sacore.Family,
  message : String,
) -> @sareport.Report {
  @sareport.Report::{
    family,
    lenses: [@sacore.LStructural],
    message,
    span: @sacore.zero_span(),
    vst: [],
  }
}

///|
/// 跑两台机的三鉴并分层。
pub fn run_fleet_audit() -> Array[Verdict] {
  let out : Array[Verdict] = []
  for spec in [build_group_spec(), build_society_spec()] {
    out.push(split_fleet(spec.name, @sa.audit(spec)))
  }
  out
}

///|
/// 两台机的三鉴报告。
pub fn render_fleet_report() -> String {
  let lines : Array[String] = [
    "# 自审计（三鉴）：群体机与社会机当程序读", "", "同 `主体` 面的三鉴（结构鉴／类型鉴／行为鉴），但两条口径不同，须先读：",
    "", "- **没有驱动槽**：两台机的驱动就是触发本身（`one_edge_per_trigger` 为真），",
    "  没有槽这一层，故类型鉴的槽层整层跳过（MachineSpec 的 `slot_names` 留空",
    "  是明文允许的读法）。`trigger_slots` 按 (触发, 触发) 登记只为让结构鉴",
    "  认得每一句，不是凭空发明一层槽。", "- **没有终点**：`no_dead_end` 断言每个位置都有出边，「不封闭」是结构事实。",
    "  填一个 `terminal` 进去，三鉴会报「终点不可达」——那是把「不封闭」误报成",
    "  缺陷。故留空。主体机相反：静定极可达且可重入，那一面如实报了。",
    "", "机 | 状态 | 迁移 | 触发 | 无路组合 | 历程 | 已知设计 | 未预期",
    "---|---|---|---|---|---|---|---",
  ]
  let group = build_group_spec()
  let society = build_society_spec()
  for v in run_fleet_audit() {
    let spec = if v.machine == "群体" { group } else { society }
    lines.push(
      "| \{spec.name} | \{spec.states.length()} | \{spec.transitions.length()} | \{spec.trigger_slots.length()} | \{spec.blocks.length()} | \{spec.course.length()} | \{v.known.length()} | \{v.fresh.length()} |",
    )
  }
  lines.push("")
  for v in run_fleet_audit() {
    lines.push("## \{v.machine}")
    lines.push("")
    if v.known.length() == 0 {
      lines.push("已知设计：无")
    } else {
      lines.push("已知设计（\{v.known.length()} 条）：")
      for f in v.known {
        lines.push("- \{f.message}")
      }
    }
    lines.push("")
    if v.fresh.length() == 0 {
      lines.push(
        "未预期发现：**0 条**——三鉴在真实表上无任何报警。绊线：任何新增发现都会",
      )
      lines.push(
        "让测试失败，强制复审。本层**不设已知设计豁免**（与 `主体` 面不同）：真表上",
      )
      lines.push(
        "一次发现都没有，就没有可豁免者；预留豁免口子等于给未来的改坏留后门。",
      )
    } else {
      lines.push("未预期发现（\{v.fresh.length()} 条）：")
      for f in v.fresh {
        lines.push("- \{f.render()}")
      }
    }
    lines.push("")
  }
  lines.join("\n")
}
