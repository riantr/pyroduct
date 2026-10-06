///|
/// 迁移表变异网（0.1.28 新增，模型整理）。
///
/// 三鉴报「0 条发现」本身是个**需要证据的断言**：一个从不报警的审计，与一个
/// 什么都看不见的审计，在报告上长得一模一样。故本文件拿真表做故意的破坏，
/// 要求每一处破坏都被三鉴抓到——**把「三鉴在两台机上没漏」从断言变成结论**。
///
/// 六个破坏点覆盖三鉴的每一处报警分支，每一处都对应一条真表数据：
///
/// | 变异 | 破坏什么 | 应报的家族 |
/// |---|---|---|
/// | 指向不存在的状态 | 迁移端点未声明 | 未定义名 |
/// | 用没登记的触发 | 触发未声明 | 未定义名 |
/// | 把无路理由清空 | 「无路必须说出口」 | 条件布尔 |
/// | 历程抽掉一站 | 行为鉴的步承载 | 方法错 |
/// | 填一个不可达终点 | 终点可达性 | 方法错 |
/// | 删掉一条迁移 | 绑定／进入／可达的会计 | 未用局部 或 不可达 |
///
/// 变异网是**只读压力测试**：它不碰真表（`build_spec` 每次现搭），故不会把
/// 「审察」变成「修表」。

///|
/// 一个故意的坏表：`spec` 是被破坏后的副本，`expect` 是必须被报出的发现家族。
pub(all) struct Mutant {
  machine : String
  label : String
  spec : @sa.MachineSpec
  expect : String
}

///|
/// 家族名（供报告与测试比对；外部库的 enum 没有可读的 to_string，故在此登记）。
/// `pub` 是因为 `mbti.mbt` 的接口面也要用它——家族表只能有一份，登记两份就会漂。
pub fn family_name(f : @sacore.Family) -> String {
  match f {
    @sacore.FParse => "语法"
    @sacore.FUndefinedName => "未定义名"
    @sacore.FUnusedLocal => "未用局部"
    @sacore.FUnreachable => "不可达"
    @sacore.FMethodError => "方法错"
    @sacore.FArgType => "参数类型"
    @sacore.FCondBool => "条件布尔"
    _ => "其他"
  }
}

///|
/// 逐个家族看三鉴报了什么。
pub fn families_of(spec : @sa.MachineSpec) -> Array[String] {
  let out : Array[String] = []
  for f in @sa.audit(spec) {
    out.push(family_name(f.family))
  }
  out
}

///|
/// 把真表拆成局部数组（每条都新建，不与原表共享任何一个数组——否则一处破坏
/// 会顺着别名流到别处，变异网就白做了），施加一处破坏，再现搭一份规格。
///
/// 全程走局部变量、不改结构体字段：规格是外部库的类型，字段赋值不是本层该
/// 依赖的语义。某一族在这台机上不适用（如没有无路组合）时返回 `None`。
fn apply(spec : @sa.MachineSpec, kind : Int) -> (@sa.MachineSpec, String)? {
  let states : Array[String] = []
  for s in spec.states {
    states.push(s)
  }
  let transitions : Array[(String, String, String)] = []
  for t in spec.transitions {
    transitions.push(t)
  }
  let trigger_slots : Array[(String, String)] = []
  for p in spec.trigger_slots {
    trigger_slots.push(p)
  }
  let slot_names : Array[String] = []
  for s in spec.slot_names {
    slot_names.push(s)
  }
  let blocks : Array[(String, String, String)] = []
  for b in spec.blocks {
    blocks.push(b)
  }
  let course : Array[String] = []
  for c in spec.course {
    course.push(c)
  }
  let mut terminal = spec.terminal
  let mut expect = "任意"
  let mut skip = false
  if kind == 0 {
    // 指向不存在的状态：改末条迁移的落点
    if transitions.length() == 0 {
      skip = true
    } else {
      let last = transitions.length() - 1
      let (from, trigger, _) = transitions[last]
      transitions[last] = (from, trigger, "查无此位")
      expect = "未定义名"
    }
  } else if kind == 1 {
    // 用没登记的触发
    if transitions.length() == 0 {
      skip = true
    } else {
      let last = transitions.length() - 1
      let (from, _, to) = transitions[last]
      transitions[last] = (from, "查无此句", to)
      expect = "未定义名"
    }
  } else if kind == 2 {
    // 把无路理由清空：「无路必须说出口」的唯一入口
    if blocks.length() == 0 {
      skip = true
    } else {
      let last = blocks.length() - 1
      let (state, slot, _) = blocks[last]
      blocks[last] = (state, slot, "")
      expect = "条件布尔"
    }
  } else if kind == 3 {
    // 历程抽掉中间一站
    if course.length() < 3 {
      skip = true
    } else {
      let mid = course.length() / 2
      let short : Array[String] = []
      for i = 0; i < course.length(); i = i + 1 {
        if i != mid {
          short.push(course[i])
        }
      }
      course.clear()
      for c in short {
        course.push(c)
      }
      expect = "方法错"
    }
  } else if kind == 4 {
    // 填一个不可达终点（真表留空正是为了不报这一条）
    terminal = "查无此位"
    expect = "方法错"
  } else if transitions.length() < 2 {
    // 删掉一条迁移：某处位置可能因此不再被绑定／进入／可达
    skip = true
  } else {
    let short : Array[(String, String, String)] = []
    for i = 0; i < transitions.length() - 1; i = i + 1 {
      short.push(transitions[i])
    }
    transitions.clear()
    for t in short {
      transitions.push(t)
    }
  }
  if skip {
    return None
  }
  let broken : @sa.MachineSpec = {
    name: spec.name,
    states,
    initial: spec.initial,
    terminal,
    transitions,
    trigger_slots,
    slot_names,
    blocks,
    course,
  }
  Some((broken, expect))
}

///|
/// 六个破坏点的名字（按 `apply` 的 kind 次序）。
fn kind_name(kind : Int) -> String {
  if kind == 0 {
    "指向不存在的状态"
  } else if kind == 1 {
    "用没登记的触发"
  } else if kind == 2 {
    "把无路理由清空"
  } else if kind == 3 {
    "历程抽掉一站"
  } else if kind == 4 {
    "填一个不可达终点"
  } else {
    "删掉一条迁移"
  }
}

///|
/// 全部变异：三台机（主体／群体／社会）各六族。
pub fn table_mutants() -> Array[Mutant] {
  let out : Array[Mutant] = []
  for spec in [build_spec(), build_group_spec(), build_society_spec()] {
    for kind = 0; kind < 6; kind = kind + 1 {
      match apply(spec, kind) {
        Some(pair) => {
          let (broken, expect) = pair
          out.push({
            machine: spec.name,
            label: kind_name(kind),
            spec: broken,
            expect,
          })
        }
        None => ()
      }
    }
  }
  out
}

///|
/// 变异网的报告：每台机真表的发现数，随后每一处破坏被抓到的发现。
pub fn render_mutation_report() -> String {
  let lines : Array[String] = [
    "# 迁移表变异网：三鉴有没有牙齿", "", "「0 条发现」是个**需要证据**的断言——一个从不报警的审计，与一个什么都看不见",
    "的审计，在报告上长得一模一样。故拿真表做故意的破坏，要求每一处都被抓到。",
    "变异网只读：它改的是现搭出来的副本，真表一个字节都不动。",
    "", "机 | 真表发现 | 破坏处数 | 全部被抓", "---|---|---|---|",
  ]
  let specs = [build_spec(), build_group_spec(), build_society_spec()]
  let all = table_mutants()
  for spec in specs {
    let base = @sa.audit(spec).length()
    let mut total = 0
    let mut caught = 0
    for m in all {
      if m.machine == spec.name {
        total += 1
        if @sa.audit(m.spec).length() > 0 {
          caught += 1
        }
      }
    }
    lines.push("| \{spec.name} | \{base} | \{total} | \{caught}／\{total} |")
  }
  lines.push("")
  for m in all {
    let found = families_of(m.spec)
    lines.push(
      "- \{m.machine} · \{m.label}　期望「\{m.expect}」类，实际报出 \{found.length()} 条：\{found.join("、")}",
    )
  }
  lines.push("")
  lines.push(
    "读法：期望一栏是**该族必须报的家族**。「填一个不可达终点」这一族特别值得看：",
  )
  lines.push(
    "群体机与社会机的真表把 `terminal` 留空（它们没有终点，「不封闭」是结构事实），",
  )
  lines.push(
    "于是结构鉴那条「终点不可达」的报警在真表上不会响——留空不是让它闭嘴，是这台机",
  )
  lines.push(
    "真的没有那个位置。这一族把报警重新点上：它一响就说明该分支是活的，留空确实是",
  )
  lines.push("一个选择，而不是审计失灵。")
  lines.join("\n")
}
