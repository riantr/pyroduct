///|
/// 黑盒测试：只通过 `@coordinator.…` 公开 API，并尽量使用 `demo_*` 夹具。

///|
/// 取 `v` 在 `xs` 中的下标（找不到返回 -1）。
fn idx(xs : Array[Int], v : Int) -> Int {
  for i = 0; i < xs.length(); i = i + 1 {
    if xs[i] == v {
      return i
    }
  }
  -1
}

///|
/// 跑一段示例研究。
fn run_demo(steps : Int) -> @coordinator.Runtime {
  let rt = @coordinator.new_runtime()
  let ts = @coordinator.demo_tasks()
  let qs = @coordinator.demo_questions()
  let ws = @coordinator.demo_workers()
  let dss = @coordinator.demo_datasets()
  for i = 0; i < steps; i = i + 1 {
    ignore(
      rt.step(
        ts,
        qs,
        ws,
        dss,
        @coordinator.demo_world(),
        @coordinator.demo_parent(),
        @coordinator.demo_candidate(),
      ),
    )
  }
  rt
}

///|
test "规划：拓扑序合法、环被检出、按商谈类型分工" {
  let ts = @coordinator.demo_tasks()
  let qs = @coordinator.demo_questions()
  let ws = @coordinator.demo_workers()
  let (order, acyclic) = @coordinator.topological(ts)
  assert_true(acyclic)
  assert_eq(order.length(), 3)
  assert_true(idx(order, 0) < idx(order, 1))
  assert_true(idx(order, 1) < idx(order, 2))
  let cycled : Array[@coordinator.Task] = [
    @coordinator.task(0, 0, "a", [1], [], 1, 10),
    @coordinator.task(1, 0, "b", [0], [], 1, 10),
  ]
  let (_, ok) = @coordinator.topological(cycled)
  assert_true(!ok)
  let plan = @coordinator.schedule(ts, qs, ws, 0)
  assert_true(plan.feasible)
  assert_eq(plan.assigned.length(), 3)
  // 理论商谈派给共同理性最高的甲(0)
  assert_eq(@coordinator.agent_of(plan, 0), 0)
}

///|
test "证据绑定：钉在数据集版本上，复现升级凭据" {
  let ds = @coordinator.demo_datasets()[0]
  let qs = @coordinator.demo_questions()
  let b0 = @coordinator.experiment(
    qs[0].text,
    ds,
    @coordinator.demo_parent(),
    @coordinator.demo_candidate(),
    @coordinator.demo_world(),
  )
  assert_true(b0.pinned_to(ds))
  assert_eq(b0.replicas, 1)
  let b1 = @coordinator.replicate(
    b0,
    ds,
    @coordinator.demo_parent(),
    @coordinator.demo_candidate(),
    @coordinator.demo_world(),
  )
  assert_eq(b1.replicas, 2)
  assert_true(@coordinator.evidence_verdict(b1) == @coordinator.Replicated)
  // 数据集换版 → 绑定失效
  let ds2 = @coordinator.dataset(
    0, "回合数据 v2", 300, 20260930, "sha:rounds-v2",
  )
  assert_true(!b0.pinned_to(ds2))
}

///|
test "内容记忆：发现可追溯，且保留被取代的历史" {
  let rt = run_demo(3)
  assert_eq(rt.notebook.findings.length(), 3)
  let f0 = rt.notebook.findings[0]
  assert_true(f0.residual > 0)
  rt.notebook.mark(0, @coordinator.Replaced)
  let nid = rt.notebook.add({
    ..f0,
    id: 0,
    supersedes: Some(0),
    status: @coordinator.Established,
    at: 9,
  })
  let chain = rt.notebook.history(nid)
  assert_eq(chain.length(), 2)
  assert_eq(chain[0], nid)
  assert_eq(chain[1], 0)
  let text = rt.notebook.serialize()
  assert_eq(@coordinator.parse_notebook(text).serialize(), text)
}

///|
test "决策段：缺一即拒，交付恒带可修订与重开条件" {
  let delib : @coordinator.Deliberation = {
    question: 0,
    options: [0, 1],
    open_remainder: "未检验的替代方案",
  }
  assert_true(
    @coordinator.decide(delib, 7, 0, "出现样本外证伪", 1) is None,
  )
  assert_true(@coordinator.decide(delib, 0, 0, "", 1) is None)
  assert_true(
    @coordinator.decide(delib, 0, -1, "出现样本外证伪", 1) is None,
  )
  let empty : @coordinator.Deliberation = {
    question: 0,
    options: [0],
    open_remainder: "",
  }
  assert_true(
    @coordinator.decide(empty, 0, 0, "出现样本外证伪", 1) is None,
  )
  let dec = match @coordinator.decide(delib, 0, 1, "出现样本外证伪", 1) {
    Some(d) => d
    None => fail("应当给出决策")
  }
  assert_true(@coordinator.decision_ok(dec))
  let re = @coordinator.reopen(dec, 1)
  assert_true(re.options.length() > 0)
  assert_true(re.open_remainder.length() > 0)
}

///|
test "署名：作者顺序按贡献，同分按 id" {
  let cs : Array[@coordinator.Contribution] = [
    @coordinator.contribution(0, 0, @coordinator.Analysis, 40),
    @coordinator.contribution(1, 0, @coordinator.Method, 30),
    @coordinator.contribution(2, 0, @coordinator.Review, 30),
  ]
  let order = @coordinator.author_order(cs)
  assert_eq(order[0], 0)
  assert_true(order[1] == 1 && order[2] == 2)
  assert_eq(@coordinator.credit_of_task(cs, 0).length(), 3)
}

///|
test "运行时：依赖序执行，检查点可往返且状态延续" {
  let rt = run_demo(2)
  assert_eq(rt.clock, 2)
  assert_eq(rt.done.length(), 2)
  assert_eq(rt.done[0], 0)
  assert_eq(rt.done[1], 1)
  assert_eq(rt.results.length(), 2)
  assert_eq(rt.artifacts.length(), 2)
  assert_true(rt.results[0].is_bound())
  let ck = rt.checkpoint()
  let back = @coordinator.restore(ck)
  assert_eq(back.clock, 2)
  assert_eq(back.notebook.findings.length(), 2)
  assert_eq(back.checkpoint(), ck)
  assert_true(rt.round_trips())
  // 从检查点恢复后可以接着跑
  let more = back.step(
    @coordinator.demo_tasks(),
    @coordinator.demo_questions(),
    @coordinator.demo_workers(),
    @coordinator.demo_datasets(),
    @coordinator.demo_world(),
    @coordinator.demo_parent(),
    @coordinator.demo_candidate(),
  )
  assert_true(more is Some(_))
  assert_eq(back.clock, 3)
  // 全部任务完成后不应再有可跑的一步
  let none = back.step(
    @coordinator.demo_tasks(),
    @coordinator.demo_questions(),
    @coordinator.demo_workers(),
    @coordinator.demo_datasets(),
    @coordinator.demo_world(),
    @coordinator.demo_parent(),
    @coordinator.demo_candidate(),
  )
  assert_true(none is None)
}

///|
test "报告覆盖补上的七件事" {
  let r = @coordinator.render_report()
  for
    k in [
      "任务与制品层", "规划与调度", "外部证据绑定", "运行时",
      "商谈段 / 决策段", "内容记忆", "署名与信用",
    ] {
    assert_true(r.contains(k))
  }
  assert_true(r.contains("检查点往返一致：true"))
}
