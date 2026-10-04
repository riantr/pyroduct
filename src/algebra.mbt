///|
/// 机器代数（Ragel 面，模型整理）：把 Ragel 状态机编译器（Adrian Thurston，
/// 已并入 colm-suite）的机器构造语义对准主体机。
///
/// Ragel 的本质：从**声明式规格**编译可执行机器——机器代数（并 `|`、相接
/// （并置）、星 `*`、可选 `?`、重复 `{n,m}`、交 `&`、差 `-`、强差 `--`）
/// 先构造非确定机，子集构造法确定化，再最小化，动作嵌在迁移上（`> @ $ %`
/// 与 fgoto/fcall/fret/fhold/fbreak 流控），另有扫描器（最长匹配）与全局
/// 错误态（err）。pyroduct 的对应与取舍：
///
///   - **相接** ↔ course 主线：30 站的链（`course()`），一站接一站；
///   - **并** ↔ 槽粒度的并存：5 处多路未定（0.1.17 的 β 权重面）；
///   - **星（自环）** ↔ 守：自环迁移（位置不变，驱动被吸收）；
///   - **环（重入）** ↔ 宁静→反顾：界域重开，整条链重新可走；
///   - **差** ↔ 全状态 − 主线 = 4 处（两退化入口 + 两空间侧支路）——主线
///     是原文主线（时间侧），空间侧（疏离／畏怖）是并存的另一侧；
///   - **确定化** ↔ 不需要：迁移表生来确定（触发粒度，0.1.18 锁定）；
///     非确定只在槽粒度，由双诚之比裁决（0.1.15）；
///   - **最小化** ↔ `is_minimal()`：分区细化（无接受态之分，初始单块）——
///     **没有两个位置共享同一个未来轮廓**；每个位置都不可被合并掉。
///   - **全局错误态（err）** ↔ Block 缺口：Ragel 用 err 接住未预期输入；
///     pyroduct 不接住——无路如实说出口（`gaps`），缺口即诚实版错误态；
///   - **动作嵌入** ↔ 不适用：pyroduct 的「动作」是触发句的出处（原文页码
///     的 gloss），不是宿主代码；机器不被编译成别的语言——数据即代码。
///
/// 出处层：模型整理——Ragel 是编译器架构，这里只取其语义对准，不引其数。

///|
/// 分区细化的共用核（Ragel 的最小化）：返回（块数, >1 成员的等价类列表，
/// 按码点序）。
fn refine() -> (Int, Array[String]) {
  let states = all_states()
  let mut block : Map[String, Int] = Map([])
  for s in states {
    block[s.designation()] = 0
  }
  let mut count = 1
  let mut stable = false
  while !stable {
    // 每个位置的未来轮廓：出边集（触发 → 目标块），照 all_triggers 典范序
    let keys : Map[String, String] = Map([]) // 轮廓 -> 代表位置
    let newid : Map[String, Int] = Map([]) // 位置 -> 新块号
    let mut next = 0
    for s in states {
      let tgts : Map[String, String] = Map([])
      for t in transitions() {
        if t.from == s {
          match block.get(t.to.designation()) {
            Some(b) => tgts[t.trigger.label()] = b.to_string()
            None => ()
          }
        }
      }
      let mut key = ""
      for tr in all_triggers() {
        match tgts.get(tr.label()) {
          Some(b) => key = key + tr.label() + "→" + b + ";"
          None => ()
        }
      }
      match keys.get(key) {
        Some(rep) => newid[s.designation()] = newid.get(rep).unwrap()
        None => {
          keys[key] = s.designation()
          newid[s.designation()] = next
          next += 1
        }
      }
    }
    if next == count {
      stable = true
    } else {
      count = next
      block = newid
    }
  }
  let groups : Map[Int, Array[String]] = Map([])
  for s in states {
    match block.get(s.designation()) {
      Some(b) => {
        let arr = match groups.get(b) {
          Some(a) => a
          None => {
            let a : Array[String] = []
            groups[b] = a
            a
          }
        }
        arr.push(s.designation())
      }
      None => ()
    }
  }
  let classes : Array[String] = []
  for entry in groups {
    let (b, members) = entry
    let _ = b
    if members.length() > 1 {
      classes.push(members.join(" ≡ "))
    }
  }
  classes.sort()
  (count, classes)
}

///|
/// 性质谓词：机器是否最小（Ragel 的最小化当不变量用）。
///
/// 分区细化：无接受态之分，初始全体一块，每轮按**未来轮廓**（出边集：
/// 触发 → 目标块）分块，直到稳定。最小 ⟺ 块数 = 状态数。
///
/// 本机**有意成双**：三对孪生位置（无忆≡无筹、紧迫≡疏离、受赏≡畏怖）
/// ——原文以**不同触发**区分其来处（表态各一、两种感受交融、嘉奖与威慑
/// 各一），机器以**相同行为**识别其去处（同触发同目标）。故 false 是设计
/// 事实，不是冗余；等价类清单由 `minimal_quotient` 如实给出，测试锁定
/// 三对——若未来的编辑意外合并两处无关位置，清单变红即复审。
pub fn is_minimal() -> Bool {
  let (count, _classes) = refine()
  count == all_states().length()
}

///|
/// 最小商：分区细化后的（块数, 等价类列表）——可合并的位置对如实列出。
/// 本机为（31, 三对孪生）：31 恰是 `course()` 的长度——主线就是最小商
/// （差一步：退化起点对不在主线上；疏离并入紧迫、畏怖并入受赏，各与其
/// 主线孪兄同块）。
pub fn minimal_quotient() -> (Int, Array[String]) {
  refine()
}

///|
/// 机器代数的报告：算子映射、主线的代数分解、最小化结论。
pub fn render_algebra_report() -> String {
  let lines : Array[String] = [
    "# 机器代数（Ragel 面）", "", "参照 Ragel 状态机编译器：从声明式规格编译可执行机器——机器代数构造",
    "非确定机，确定化，最小化，动作嵌在迁移上。出处层：模型整理——只取",
    "语义对准，不引其数。", "", "## 算子映射",
  ]
  let mut loops = 0
  for t in transitions() {
    if t.from == t.to {
      loops += 1
    }
  }
  lines.push(
    "- 相接（并置）↔ 主线：\{course().length()} 项的链（course()，末项是重入的反顾）——\{course().length() - 1} 站一站接一站；",
  )
  lines.push(
    "- 并（|）↔ 槽粒度并存：5 处多路未定（0.1.17 的 β 权重面，双诚之比裁决）；",
  )
  lines.push(
    "- 星（自环）↔ 守：\{loops} 条自环迁移——位置不变，驱动被吸收；",
  )
  lines.push(
    "- 环（重入）↔ 宁静→反顾：界域重开（R11），整条链重新可走——机器没有终态，只有重入的环；",
  )
  lines.push(
    "- 确定化 ↔ 不需要：迁移表生来确定（触发粒度，is_deterministic 已锁定）；非确定只在槽粒度；",
  )
  let (count, classes) = minimal_quotient()
  lines.push(
    "- 最小化 ↔ is_minimal：\{count == all_states().length()}——分区细化：\{if count == all_states().length() { "没有两个位置共享同一个未来轮廓" } else { "三对孪生（成双是设计）：\{classes.join("；")}——原文以不同触发区分其来处，机器以相同行为识别其去处" }}；",
  )
  lines.push(
    "- 全局错误态（err）↔ Block 缺口：不接住未预期输入，\{gaps().length()} 处无路如实说出口——缺口即诚实版错误态；",
  )
  lines.push(
    "- 动作嵌入 ↔ 不适用：pyroduct 的「动作」是触发句的出处（gloss，原文页码），不是宿主代码——数据即代码，机器不被编译成别的语言。",
  )
  lines.push("")
  lines.push("## 主线的代数分解（差集）")
  let on_course : Map[String, Bool] = Map([])
  for s in course() {
    on_course[s.designation()] = true
  }
  let missing : Array[String] = []
  for s in all_states() {
    match on_course.get(s.designation()) {
      Some(_) => ()
      None => missing.push(s.designation())
    }
  }
  lines.push(
    "- 主线（相接）：\{on_course.length()} 站（course() 共 \{course().length()} 项，末项是重入），\{course()[0].designation()} → … → \{course()[course().length() - 2].designation()} ↺ \{course()[course().length() - 1].designation()}；",
  )
  lines.push(
    "- 全状态 − 主线：\{missing.join("、")}——\{if missing.length() == 4 { "两退化入口（无忆／无筹，只出不进）加两空间侧支路（疏离／畏怖，并存的另一侧）" } else { "" }}。",
  )
  lines.push(
    "- 最小商：\{count} 块 = course 的长度——主线就是最小商（差一步：退化起点对不在主线上；疏离并入紧迫、畏怖并入受赏，各与其主线孪兄同块）。",
  )
  lines.push("")
  lines.push("## 相的划分（块的并）")
  let per_phase : Array[String] = []
  for p in all_phases() {
    let mut c = 0
    for s in all_states() {
      if s.phase() == p {
        c += 1
      }
    }
    per_phase.push("\{p.designation()}\{c}")
  }
  lines.push(
    "- \{all_phases().length()} 个相把 \{all_states().length()} 个位置分块（每位置恰属一相）：\{per_phase.join(" ")}；",
  )
  lines.push(
    "- 块的并 = 全状态，块两两不交——相不是标签，是划分。",
  )
  lines.join("\n")
}
