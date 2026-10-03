///|
test "规格转写：真实主体机的表原样进入 MachineSpec" {
  let spec = @audit.build_spec()
  assert_eq(spec.states.length(), 34)
  assert_eq(spec.transitions.length(), 53)
  assert_eq(spec.trigger_slots.length(), 49)
  assert_eq(spec.slot_names.length(), 8)
  assert_eq(spec.blocks.length(), 228)
  assert_eq(spec.course.length(), 31)
  assert_eq(spec.initial, "立位")
  assert_eq(spec.terminal, "宁静")
}

///|
test "三鉴在真实表上：4 条已知设计（无忆／无筹），未预期必须为零" {
  let (known, fresh) = @audit.run_audit(@audit.build_spec())
  // 回归绊线：结构／类型／行为任一层新增报警即测试失败，强制复审。
  assert_eq(fresh.length(), 0)
  assert_eq(known.length(), 4)
  for f in known {
    // 已知设计只可能是无忆／无筹的「从未被进入」与「从初始不可达」。
    assert_true(f.message.contains("无忆") || f.message.contains("无筹"))
  }
}

///|
test "无路全部说出口：228 条组合逐条带非空理由" {
  let spec = @audit.build_spec()
  for b in spec.blocks {
    let (_, _, reason) = b
    assert_true(!reason.is_empty())
  }
}

///|
test "绊线是活的：给历程人为接一步无路，行为层立刻报警" {
  let spec = @audit.build_spec()
  spec.course.push("自由")
  let (known, fresh) = @audit.run_audit(spec)
  assert_eq(known.length(), 4)
  assert_eq(fresh.length(), 1)
  assert_true(fresh[0].message.contains("course step 31"))
}

///|
test "报告对称：三鉴小节、出处层标注、判读齐全" {
  let report = @audit.render_report()
  assert_true(report.contains("三鉴"))
  assert_true(report.contains("已知设计"))
  assert_true(report.contains("未预期"))
  assert_true(report.contains("设计使然"))
  assert_true(report.contains("0.1.2"))
}
