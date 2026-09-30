///|
/// 协调器总报告：把补上的七件事逐个演示一遍。
///
/// 例子里有 3 个研究问题（理论／实践／表达）、3 个任务（带依赖）、3 位研究者、
/// 2 个数据集。整个回路是**确定性**的，因而可离线重放、可在测试里断言。

///|
/// 把一串 id 印成 `a,b,c`。
fn fmt_ids(xs : Array[Int]) -> String {
  if xs.length() == 0 {
    "无"
  } else {
    xs.map(x => "\{x}").join(",")
  }
}

///|
/// 示例问题。
pub fn demo_questions() -> Array[Question] {
  [
    question(0, "新策略是否提升协作成效", @multi.Theoretical),
    question(1, "采用什么复核规范", @multi.Practical),
    question(2, "作者如何声明利益冲突", @multi.Aesthetic),
  ]
}

///|
/// 示例任务（约定 id 即下标）。
pub fn demo_tasks() -> Array[Task] {
  [
    task(0, 0, "测量新策略的因果效应", [], [], 40, 100),
    task(1, 1, "拟定复核规范", [0], [0], 30, 140),
    task(2, 2, "撰写诚实性声明", [1], [], 20, 200),
  ]
}

///|
/// 示例研究者。
pub fn demo_workers() -> Array[Worker] {
  [
    worker(0, "甲", @multi.InterSubjective, 85, 70, 60),
    worker(1, "乙", @multi.ChengRan, 60, 90, 60),
    worker(2, "丙", @multi.SuperSubjective, 70, 50, 60),
  ]
}

///|
/// 示例数据集。
pub fn demo_datasets() -> Array[Dataset] {
  [
    dataset(0, "回合数据 v1", 300, 20260930, "sha:rounds-v1"),
    dataset(1, "规范问卷 v1", 120, 20260931, "sha:survey-v1"),
  ]
}

///|
/// 总报告。
pub fn render_report() -> String {
  let qs = demo_questions()
  let ts = demo_tasks()
  let ws = demo_workers()
  let dss = demo_datasets()
  let world = @evolution.default_world()
  let parent = @evolution.default_agent()
  let candidate = @evolution.genome(
    parent.voice,
    @multi.ChengRan,
    parent.toward_other,
    parent.toward_self,
    parent.carry,
    parent.reason,
  )
  let lines : Array[String] = [
    "# 科研 Agent 协调器", "", "在 `multi`／`society`／`evolution` 之上，补齐协调器所需的七件事。",
    "", "## 一、任务与制品层", "", "不再以「对话判词」为结果，而以**可交付的制品**为单位：问题／任务／数据集／研究者。",
    "",
  ]
  for q in qs {
    lines.push("- 问题\{q.id}（\{q.discourse.label()}）：\{q.text}")
  }
  for t in ts {
    lines.push(
      "- 任务\{t.id}：\{t.title}｜依赖 \{fmt_ids(t.deps)}｜需制品 \{fmt_ids(t.needs)}｜预算 \{t.budget}｜期限 \{t.deadline}",
    )
  }
  for d in dss {
    lines.push(
      "- 数据集\{d.id}：\{d.name}｜\{d.rows} 行｜指纹 \{d.digest}",
    )
  }
  let refs : Array[Citation] = [
    {
      key: "gadamer1960",
      title: "真理与方法",
      locator: "商务印书馆 2007",
    },
    {
      key: "habermas1981",
      title: "交往行为理论",
      locator: "上海人民出版社 2004",
    },
  ]
  lines.push("")
  lines.push(
    "引用（\{refs.length()} 条）：\{refs.map(r => r.key).join("、")}",
  )
  lines.push("")
  lines.push("## 二、规划与调度")
  lines.push("")
  lines.push(
    "依赖图 → 拓扑序 → 按商谈类型分工 → 预算／期限核算：",
  )
  lines.push("")
  lines.push(render_plan(schedule(ts, qs, ws, 0), ts))
  lines.push("")
  // ── 外部证据绑定
  let ds0 = dss[0]
  let b0 = experiment(qs[0].text, ds0, parent, candidate, world)
  let b1 = replicate(b0, ds0, parent, candidate, world)
  lines.push("## 三、外部证据绑定")
  lines.push("")
  lines.push("主张：\{b1.claim_text}")
  lines.push(
    "- 数据集\{b1.dataset}（指纹 \{b1.digest}）｜效应 \{@evolution.show_pm(b1.effect)}｜95%CI [\{@evolution.show_pm(b1.ci_low)}, \{@evolution.show_pm(b1.ci_high)}]｜复现 \{b1.replicas} 次｜凭据 \{b1.warrant.label()}",
  )
  lines.push(
    "- 判词（由区间给出，不由投票给出）：\{evidence_verdict(b1).label()}",
  )
  lines.push("- 是否仍钉在该数据集版本上：\{b1.pinned_to(ds0)}")
  let rep0 = replication_of(0, ds0, b1, true)
  lines.push(
    "- 复现台账：结果\{rep0.result} ← 数据集\{rep0.dataset}｜效应 \{@evolution.show_pm(rep0.effect)}｜同号 \{rep0.agrees}",
  )
  lines.push("")
  // ── 运行时
  let rt = Runtime::new()
  let reports : Array[StepReport] = []
  for i = 0; i < 3; i = i + 1 {
    match rt.step(ts, qs, ws, dss, world, parent, candidate) {
      Some(rep) => reports.push(rep)
      None => ()
    }
  }
  lines.push("## 四、运行时（消息总线 + 可重放）")
  lines.push("")
  lines.push(
    "走了 \{rt.clock} 步；消息 \{rt.log.length()} 条；结果 \{rt.results.length()} 条；产物 \{rt.artifacts.length()} 件。",
  )
  for rep in reports {
    lines.push(
      "- 第\{rep.at + 1}步：任务\{rep.task} 派给研究者\{rep.agent}｜\{rep.discourse}｜判词 \{rep.verdict}｜结果\{rep.result} 发现\{rep.finding}",
    )
  }
  lines.push("")
  lines.push(
    "（「想」那一步在真实系统里由 LLM 充当；此处是确定性替身，所以整个回路可离线重放。）",
  )
  lines.push("")
  // ── 商谈段 / 决策段
  let opts : Array[Int] = []
  for f in rt.notebook.findings {
    if f.question == 0 {
      opts.push(f.id)
    }
  }
  let delib : Deliberation = {
    question: 0,
    options: opts,
    open_remainder: "尚未检验的替代策略，以及样本外的推广性",
  }
  lines.push("## 五、商谈段 / 决策段（分离）")
  lines.push("")
  lines.push(
    "商谈段：方案 \{fmt_ids(delib.options)}｜未穷尽者：\{delib.open_remainder}",
  )
  match
    decide(delib, 0, 0, "出现样本外证伪，或数据集 v1 被替换", 3) {
    Some(dec) => {
      lines.push("决策段：")
      lines.push(render_decision(dec))
      lines.push(
        "合宪？\{decision_ok(dec)}（可修订、重开条件非空、残余归属有效）",
      )
      let reopened = reopen(dec, 1)
      lines.push(
        "重开之后（缺口仍可达）：方案 \{fmt_ids(reopened.options)}｜\{reopened.open_remainder}",
      )
    }
    None =>
      lines.push(
        "决策被拒：缺可修订标记／重开条件／残余归属之一",
      )
  }
  lines.push("")
  // ── 内容记忆
  lines.push("## 六、内容记忆（记发现，不记改动）")
  lines.push("")
  for f in rt.notebook.findings {
    lines.push(
      "- 发现\{f.id}（问题\{f.question}）｜\{f.status.label()}｜残余 \{f.residual}｜绑定结果\{f.result}｜\{f.claim.label()}·\{f.phase.label()}",
    )
  }
  let old = rt.notebook.findings[0]
  rt.notebook.mark(0, Replaced)
  let nid = rt.notebook.add({
    ..old,
    id: 0,
    text: "（新数据）\{old.text}",
    supersedes: Some(0),
    at: 4,
    status: Established,
  })
  lines.push("")
  lines.push(
    "更新：发现\{nid} 取代发现0 → 追溯链 \{fmt_ids(rt.notebook.history(nid))}（被推翻的历史仍在）",
  )
  lines.push("")
  // ── 署名与信用
  lines.push("## 七、署名与信用（IP 溯源）")
  lines.push("")
  let cs : Array[Contribution] = [
    contribution(0, 0, Analysis, 40),
    contribution(0, 1, Method, 20),
    contribution(1, 0, Data, 30),
    contribution(1, 1, Review, 10),
    contribution(1, 2, Writing, 20),
    contribution(2, 0, Question, 25),
  ]
  lines.push(render_statement(cs))
  lines.push("")
  // ── 落盘
  lines.push("## 八、落盘（运行时可写可读）")
  lines.push("")
  lines.push("检查点往返一致：\{rt.round_trips()}")
  let ck = rt.checkpoint()
  let head = ck.split("\n").collect()
  lines.push("检查点前 5 行：")
  for i = 0; i < 5 && i < head.length(); i = i + 1 {
    lines.push("    \{head[i]}")
  }
  lines.join("\n")
}

///|
/// 示例世界（借 `evolution` 的五对手）。
pub fn demo_world() -> Array[@evolution.Opponent] {
  @evolution.default_world()
}

///|
/// 示例基线基因组。
pub fn demo_parent() -> @evolution.Genome {
  @evolution.default_agent()
}

///|
/// 示例候选基因组：体制改为「诚然」。
pub fn demo_candidate() -> @evolution.Genome {
  let p = @evolution.default_agent()
  @evolution.genome(
    p.voice,
    @multi.ChengRan,
    p.toward_other,
    p.toward_self,
    p.carry,
    p.reason,
  )
}

///|
/// 新建一个运行时（供包外调用）。
pub fn new_runtime() -> Runtime {
  Runtime::new()
}
