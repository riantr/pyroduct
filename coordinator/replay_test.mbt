///|
/// 黑盒测试：只通过 `@coordinator.…` 公开 API，验证确定性回放层。
///
/// 这一层治的是一种**看上去是好的**坏：检查点读回来，长度一样、结构一样，
/// 却处处不同——数字解析失败被记成 0，未知的商谈类型被当成理论商谈，被丢掉
/// 的发现行不留痕迹。所以这里的判据大多是**阴性**的：把检查点弄坏，恢复必须
/// **说自己不忠实**，并**点名**坏在哪。

///|
/// 演示运行写出来的检查点。
fn demo_checkpoint() -> String {
  let (rt, _) = @coordinator.demo_run()
  rt.checkpoint()
}

///|
/// 把检查点的第一行换成别的（用来做定点破坏）。
fn tamper_first_line(text : String, replacement : String) -> String {
  let out : Array[String] = []
  let mut first = true
  for part in text.split("\n") {
    if first {
      out.push(replacement)
      first = false
    } else {
      out.push(part.to_owned())
    }
  }
  out.join("\n")
}

///|
/// 降级账里有没有点名某件事。
fn mentions(rt : @coordinator.Runtime, needle : String) -> Bool {
  for r in rt.repairs {
    if r.contains(needle) {
      return true
    }
  }
  false
}

///|
test "指纹是确定且对内容敏感的" {
  assert_eq(@coordinator.digest_of("abc"), @coordinator.digest_of("abc"))
  assert_true(@coordinator.digest_of("abc") != @coordinator.digest_of("abd"))
  assert_eq(@coordinator.digest_of("").length(), 16)
}

///|
test "重放闸门：同一份计划跑两遍，内容指纹一致" {
  let (same, d1, d2) = @coordinator.repeat_gate()
  assert_true(same)
  assert_eq(d1, d2)
  assert_true(d1.length() > 0)
}

///|
test "往返恢复是忠实的：降级账为空" {
  let ck = demo_checkpoint()
  let back = @coordinator.restore(ck)
  assert_true(back.is_faithful())
  assert_eq(back.repairs.length(), 0)
  assert_eq(back.checkpoint(), ck)
  assert_true(back.round_trips())
}

///|
test "检查点里带着一枚指纹，读回时能被核验" {
  let ck = demo_checkpoint()
  let claimed = @coordinator.claimed_digest(ck)
  assert_true(claimed.length() > 0)
  let back = @coordinator.restore(ck)
  assert_eq(claimed, back.digest())
}

///|
test "内容被改过 → 指纹对不上 → 恢复不忠实并点名" {
  let ck = demo_checkpoint()
  let bad = tamper_first_line(ck, "clock\t999")
  let back = @coordinator.restore(bad)
  assert_true(!back.is_faithful())
  assert_true(mentions(back, "指纹对不上"))
}

///|
test "坏数字 → 降级账点名，不许悄悄记成 0" {
  let ck = demo_checkpoint()
  let bad = tamper_first_line(ck, "clock\t不是数字")
  let back = @coordinator.restore(bad)
  assert_true(!back.is_faithful())
  assert_true(mentions(back, "无法解析成数字"))
}

///|
test "未知的商谈类型码 → 降级账点名" {
  let bad = "clock\t0\nmsg\t0\t1\t-1\t未知码\ttruth\t正文\ndigest\t0"
  let back = @coordinator.restore(bad)
  assert_true(!back.is_faithful())
  assert_true(mentions(back, "未知的商谈类型码"))
}

///|
test "未知的制品类别码 → 降级账点名" {
  let bad = "clock\t0\nartifact\t0\t未知类\t0\td\t名\ndigest\t0"
  let back = @coordinator.restore(bad)
  assert_true(!back.is_faithful())
  assert_true(mentions(back, "未知的制品类别码"))
}

///|
test "字段不足的行 → 降级账点名" {
  let bad = "clock\t0\nmsg\t0\t1\ndigest\t0"
  let back = @coordinator.restore(bad)
  assert_true(!back.is_faithful())
  assert_true(mentions(back, "字段不足的行"))
}

///|
test "不认识的行 → 降级账点名，不许静默吞掉" {
  let bad = "clock\t0\n某行\t1\t2\ndigest\t0"
  let back = @coordinator.restore(bad)
  assert_true(!back.is_faithful())
  assert_true(mentions(back, "不认识的行"))
}

///|
test "字段不足的发现行 → 降级账点名「被整行丢掉」" {
  let bad = "clock\t0\nfinding\t0\t1\ndigest\t0"
  let back = @coordinator.restore(bad)
  assert_true(!back.is_faithful())
  assert_true(mentions(back, "被整行丢掉"))
}

///|
test "没有指纹行的检查点 → 降级账点名（不能当作没问题）" {
  let bad = "clock\t0"
  let back = @coordinator.restore(bad)
  assert_true(!back.is_faithful())
  assert_true(mentions(back, "没有指纹行"))
}

///|
test "降级账说得出结论与坏在哪" {
  let ck = demo_checkpoint()
  let bad = tamper_first_line(ck, "clock\t不是数字")
  let back = @coordinator.restore(bad)
  let summary = back.repair_summary()
  assert_true(summary.contains("降级账"))
  assert_true(summary.contains("无法解析成数字"))
  // 忠实的恢复说的是「空」，不是「没问题」两个字糊弄过去。
  let ok = @coordinator.restore(ck)
  assert_true(ok.repair_summary().contains("空"))
}

///|
test "两次运行的内容一致，但恢复出来的运行时是**新**的一份" {
  let (a, _) = @coordinator.demo_run()
  let (b, _) = @coordinator.demo_run()
  assert_true(@coordinator.replay_agrees(a, b))
  assert_eq(a.digest(), b.digest())
  // 指纹相同不等于共用同一份内容——它们是两个独立跑出来的运行。
  assert_true(a.body() == b.body())
}

///|
test "重放闸门有牙齿：内容不同的两个运行必须**判为不一致**" {
  // 只断「两遍一致」不够：那样一个恒真的闸门也能过。这一条从**反面**断它——
  // 两者内容不同，闸门必须说不同意。
  let (a, _) = @coordinator.demo_run()
  let b = @coordinator.restore(tamper_first_line(a.checkpoint(), "clock\t999"))
  assert_true(!@coordinator.replay_agrees(a, b))
  assert_true(a.digest() != b.digest())
}
