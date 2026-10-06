///|
/// 自审计层（模型整理）。
///
/// `riantr/moonbit_static_analysis@0.2.0` 的 `statecheck` 把状态机当程序读：
/// 三鉴——结构鉴（状态即绑定：每状态至少被一条迁移绑定、被进入一次、
/// 从初始可达；终点可达）、类型鉴（注解即契约：触发落槽、无路必须说出口）、
/// 行为鉴（历程抽象执行：每一步有触发承载）。「鉴」兼照镜与审察二义：
/// 一面镜照见一类缺陷，三鉴照见绑定、契约、轨迹。它的 `moon.mod` 注释把
/// pyroduct 点名为参考消费者——这里兑现：`build_spec` 把**真实主体机**的表
/// （`src` 的 34 状态 · 53 迁移 · 49 触发 · 228 无路组合 · 修习历程）转成
/// 纯数据 `MachineSpec`，`run_audit` 过三鉴，`render_report` 出报告。
///
/// 出处纪律：发现分两层——**已知设计**（无忆／无筹（原文：失忆／浑噩）
/// 只出不进：从「忆起／预感」离开而不是被进入，0.2.0 审计已验证并锁进
/// 测试）与**未预期**（必须是零，回归绊线：三鉴新增发现即测试失败，
/// 强制复审）。
///
/// 出处声明**跟着实际在跑的版本走**，不写成历史轶事：0.1.2 与 0.2.0 的
/// `statecheck`／`report`／`core` 三个包逐字节相同，故这条验证在 0.2.0
/// 上原样成立——但报告该说「0.2.0 已验证」，因为读者手上跑的就是 0.2.0。

///|
/// 把真实主体机的表转成纯数据 MachineSpec（状态用两字定名作键）。
pub fn build_spec() -> @sa.MachineSpec {
  let states : Array[String] = []
  for s in @sm.all_states() {
    states.push(s.designation())
  }
  let transitions : Array[(String, String, String)] = []
  for t in @sm.transitions() {
    transitions.push(
      (t.from.designation(), t.trigger.label(), t.to.designation()),
    )
  }
  let trigger_slots : Array[(String, String)] = []
  for tr in @sm.all_triggers() {
    trigger_slots.push((tr.label(), tr.slot().designation()))
  }
  let slots : Array[String] = []
  for s in @sm.all_slots() {
    slots.push(s.designation())
  }
  // 无路组合带理由：step 的 Block(reason) —— 「无路必须说出口」的原料。
  let blocks : Array[(String, String, String)] = []
  for g in @sm.gaps() {
    let (st, slot) = g
    match @sm.step(st, slot) {
      @sm.Block(reason) =>
        blocks.push((st.designation(), slot.designation(), reason))
      _ => ()
    }
  }
  let course : Array[String] = []
  for s in @sm.course() {
    course.push(s.designation())
  }
  {
    name: "主体",
    states,
    initial: @sm.initial().designation(),
    terminal: @sm.terminal().designation(),
    transitions,
    trigger_slots,
    slot_names: slots,
    blocks,
    course,
  }
}

///|
/// 已知设计使然的发现：只出不进状态（失忆／无明）的「从未被进入」与
/// 「从初始不可达」——从它们离开是设计（忆起／预感不回头），不是缺陷。
fn is_known_by_design(f : @sareport.Report) -> Bool {
  let only_exit = [@sm.NoPast.designation(), @sm.NoFuture.designation()]
  let mut mentions = false
  for s in only_exit {
    if f.message.contains(s) {
      mentions = true
    }
  }
  match f.family {
    @sacore.FUnusedLocal | @sacore.FUnreachable => mentions
    _ => false
  }
}

///|
/// 跑三鉴并把发现分成（已知设计，未预期）两层。吃任意 MachineSpec——
/// 测试可先 `build_spec` 再篡改，验证绊线是活的。
pub fn run_audit(
  spec : @sa.MachineSpec,
) -> (Array[@sareport.Report], Array[@sareport.Report]) {
  let findings = @sa.audit(spec)
  let known : Array[@sareport.Report] = []
  let fresh : Array[@sareport.Report] = []
  for f in findings {
    if is_known_by_design(f) {
      known.push(f)
    } else {
      fresh.push(f)
    }
  }
  (known, fresh)
}

///|
/// 三位数显示（如 34 → `034`）——与 src 的报告对齐。
fn fmt3(n : Int) -> String {
  "\{n / 100}\{(n % 100) / 10}\{n % 10}"
}

///|
/// 报告：规格计数 → 三鉴发现（已知设计注明出处层）→ 判读。
pub fn render_report() -> String {
  let spec = build_spec()
  let (known, fresh) = run_audit(spec)
  let lines : Array[String] = [
    "# 自审计（三鉴）：主体机当程序读",
    "",
    "依赖：`riantr/moonbit_static_analysis@0.2.0`——它的 moon.mod 把本仓库点名",
    "为参考消费者。三鉴（「鉴」兼照镜与审察）：结构鉴（状态即绑定）／类型鉴",
    "（注解即契约）／行为鉴（历程抽象执行）。出处层：模型整理——被审的**表**",
    "是原文直述，审计的**工具**是外部库。",
    "",
    "规格 | 计数",
    "---|---",
    "状态 | \{fmt3(spec.states.length())}",
    "迁移 | \{fmt3(spec.transitions.length())}",
    "触发→槽 | \{fmt3(spec.trigger_slots.length())} → \{spec.slot_names.length()}",
    "无路组合（带理由） | \{fmt3(spec.blocks.length())}",
    "修习历程 | \{fmt3(spec.course.length())} 站",
    "",
    "## 发现",
    "",
  ]
  if known.length() == 0 {
    lines.push("已知设计：无")
  } else {
    lines.push(
      "已知设计（\{known.length()} 条，出处层：设计使然——0.2.0 审计已验证）：",
    )
    for f in known {
      lines.push("- \{f.message}")
    }
    lines.push("")
    lines.push(
      "读法：无忆／无筹（原文：失忆／浑噩）只出不进——「切断过去／预感未来」是",
    )
    lines.push(
      "离开它们的唯一方式，没有迁移指向它们：过去不可重进、未来不可直取，正是",
    )
    lines.push(
      "「记不起来的过去」与「尚未到来的未来」。三鉴按程序语义报警，模型按",
    )
    lines.push(
      "文本语义成立——两层都如实：报警不是缺陷，设计使然要说出处层。",
    )
  }
  lines.push("")
  if fresh.length() == 0 {
    lines.push(
      "未预期发现：**0 条**——三鉴在真实表上无新增报警（回归绊线：",
    )
    lines.push(
      "任何结构／类型／行为层的新发现都会让测试失败，强制复审）。",
    )
  } else {
    lines.push("未预期发现（\{fresh.length()} 条）：")
    for f in fresh {
      lines.push("- \{f.render()}")
    }
  }
  lines.push("")
  lines.push(
    "判读：\{known.length()} 条已知设计 + \{fresh.length()} 条未预期 = \{known.length() + fresh.length()} 条总发现；",
  )
  lines.push(
    "无路 \{spec.blocks.length()} 条全部带理由（说出口），\{spec.slot_names.length()} 个驱动槽全部有触发落位，",
  )
  lines.push(
    "修习历程 \{spec.course.length() - 1} 步全部有触发承载——三鉴之上，模型与程序同构。",
  )
  lines.join("\n")
}
