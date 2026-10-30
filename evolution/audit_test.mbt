///|
/// 闸门审计的黑盒测试：只通过 `@evolution.` 公开 API。
///
/// 这里不只测「通过」——**判据必须能变红**。所以每一项都配一个「尺子动了／判词被改过」
/// 的反面用例：审计必须不通过，而且必须**点名**。一本账本在两种尺子下都「通过」，
/// 那它证明的不是账本干净，而是审计没长牙。

///|
/// 一本最小账本：跑两代手写权重的进化。
fn small_ledger() -> @evolution.Ledger {
  @evolution.evolve(
    @evolution.default_agent(),
    @evolution.default_world(),
    @evolution.Weighted(@evolution.truth_objective()),
    2,
  )
}

///|
/// 一条**旧格式**的记录行（没有尺子指纹那一列）。
fn legacy_trail_line(gen : String, parent : String) -> String {
  "trail\t" +
  gen +
  "\t0\t" +
  parent +
  "\tprompt\tacc\t120\t0\t0\t10,20,10,35\tdecl|inter|70|70|3|70\tX\tY"
}

///|
/// 把账本文本里第一条记录的判词换掉——在**文本层**动刀，像篡改文件的人那样。
///
/// 之所以走文本而不走内存：黑盒测试只能碰公开 API，而 `Trail`／`Ledger` 是
/// 只读类型，构造不了。能改的只有它自己的序列化。
fn tamper_first_verdict(text : String) -> String {
  let out : Array[String] = []
  let mut done = false
  for line in text.split("\n") {
    if !done && line.has_prefix("trail\t") {
      let f = line.split("\t").collect()
      let fields : Array[String] = []
      for i = 0; i < f.length(); i = i + 1 {
        if i == 5 {
          let flipped = if f[5].to_owned() == "acc" { "rev" } else { "acc" }
          fields.push(flipped)
        } else {
          fields.push(f[i].to_owned())
        }
      }
      out.push(fields.join("\t"))
      done = true
    } else {
      out.push(line.to_owned())
    }
  }
  out.join("\n")
}

///|
test "闸门审计：自己裁的账本，重裁一致，尺子未动" {
  let led = small_ledger()
  assert_true(led.trails.length() > 0)
  let audit = @evolution.replay_gate(
    led,
    @evolution.default_world(),
    @evolution.Weighted(@evolution.truth_objective()),
  )
  assert_eq(audit.checked, led.trails.length())
  assert_eq(audit.agreed, audit.checked)
  assert_eq(audit.disagreed, 0)
  assert_eq(audit.moved_bar, 0)
  assert_eq(audit.unbarred, 0)
  assert_true(audit.ok())
}

///|
test "闸门审计：尺子动了必须被抓——同一本账本，换一把尺子重裁" {
  let led = small_ledger()
  // 换成「省力」目标：权重变了，就是另一把尺子。
  let audit = @evolution.replay_gate(
    led,
    @evolution.default_world(),
    @evolution.Weighted(@evolution.thrifty_objective()),
  )
  assert_true(audit.moved_bar > 0)
  assert_true(!audit.ok())
  // 判据要**说得出**坏在哪：点名「尺子已动」，不是只给一个布尔。
  assert_true(audit.faults.length() > 0)
  let mut named = false
  for f in audit.faults {
    if f.contains("尺子已动") {
      named = true
    }
  }
  assert_true(named)
}

///|
test "闸门审计：账本里有一行判词被改过，重裁必须对不上" {
  let led = small_ledger()
  // 在文本层动刀：把第一条记录的判词换掉，再读回来。
  let tampered = @evolution.parse(tamper_first_verdict(led.serialize()))
  assert_eq(tampered.trails.length(), led.trails.length())
  let audit = @evolution.replay_gate(
    tampered,
    @evolution.default_world(),
    @evolution.Weighted(@evolution.truth_objective()),
  )
  assert_true(audit.disagreed > 0)
  assert_true(!audit.ok())
  let mut named = false
  for f in audit.faults {
    if f.contains("判词对不上") {
      named = true
    }
  }
  assert_true(named)
}

///|
test "闸门审计：没记尺子的旧账本按失败闭合算，不是「没看见就放过」" {
  let legacy = @evolution.parse(
    [
      "seed\tsugg|inter|70|70|3|70",
      "objective\t求真",
      legacy_trail_line("0", "-"),
      legacy_trail_line("1", "0"),
    ].join("\n"),
  )
  assert_eq(legacy.trails.length(), 2)
  let audit = @evolution.replay_gate(
    legacy,
    @evolution.default_world(),
    @evolution.Weighted(@evolution.truth_objective()),
  )
  assert_eq(audit.unbarred, 2)
  assert_true(!audit.ok())
}

///|
test "账本往返：尺子指纹随记录一起存下来，往返后审计照样通过" {
  let led = small_ledger()
  let text = led.serialize()
  let back = @evolution.parse(text)
  assert_eq(back.serialize(), text)
  for t in back.trails {
    assert_true(t.gate.length() > 0)
  }
  let audit = @evolution.replay_gate(
    back,
    @evolution.default_world(),
    @evolution.Weighted(@evolution.truth_objective()),
  )
  assert_true(audit.ok())
}

///|
test "闸门指纹：权重不同就是不同的尺子；因果那档连种子都算尺子" {
  let truth = @evolution.gate_fingerprint(
    @evolution.Weighted(@evolution.truth_objective()),
  )
  let thrifty = @evolution.gate_fingerprint(
    @evolution.Weighted(@evolution.thrifty_objective()),
  )
  assert_true(truth != thrifty)
  let plan_a = @evolution.causal_plan(
    @evolution.truth_objective(),
    2,
    @ml.DmlConfig::new(3, 0.02, 5, 20260920),
  )
  let plan_b = @evolution.causal_plan(
    @evolution.truth_objective(),
    2,
    @ml.DmlConfig::new(3, 0.02, 5, 20260921),
  )
  let causal_a = @evolution.gate_fingerprint(@evolution.Causal(plan_a))
  let causal_b = @evolution.gate_fingerprint(@evolution.Causal(plan_b))
  // 种子一变，合成数据就变了——尺子也就变了。
  assert_true(causal_a != causal_b)
  assert_true(causal_a != truth)
}

///|
test "闸门审计报告：说得出结论，也说得出坏在哪" {
  let led = small_ledger()
  let ok_audit = @evolution.replay_gate(
    led,
    @evolution.default_world(),
    @evolution.Weighted(@evolution.truth_objective()),
  )
  let text = @evolution.render_gate_audit(ok_audit)
  assert_true(text.contains("通过"))
  assert_true(text.contains("被重裁的行数"))
  let bad_audit = @evolution.replay_gate(
    led,
    @evolution.default_world(),
    @evolution.Weighted(@evolution.thrifty_objective()),
  )
  let bad_text = @evolution.render_gate_audit(bad_audit)
  assert_true(bad_text.contains("不通过"))
  assert_true(bad_text.contains("尺子已动"))
  assert_true(@evolution.audit_summary(bad_audit).contains("不通过"))
}
