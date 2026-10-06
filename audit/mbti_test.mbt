///|
/// 黑盒测试：接口面（`.mbti`）自审计（模型整理）。
///
/// 两半都要有，缺一不可：
/// - **正控**：三段坏片段各自必被抓。这一半是「0 条发现」这句话的证据——
///   从不报警的审计与什么都看不见的审计，在报告上长得一模一样；
/// - **反例**：与真表同形的干净片段必为 0，否则「抓到了」也可能只是它见谁咬谁。
///
/// 判据断的是**消息**不是家族：三处坏片段的家族都是 `FParse`，只断家族等于
/// 三条判据说的是同一句话，断不掉任何一种坏法。

///|
/// 正控：三段坏片段逐段被抓，且各自的措辞对得上。
test "正控：重复签名／畸形行／未知类型引用逐段被抓" {
  let dup = @audit.audit_iface(@audit.broken_duplicate(), "dup.mbti")
  assert_eq(dup.length(), 1)
  assert_true(dup[0].message.contains("duplicate signature"))
  let bad = @audit.audit_iface(@audit.broken_malformed(), "bad.mbti")
  assert_eq(bad.length(), 1)
  assert_true(bad[0].message.contains("malformed interface line"))
  let unknown = @audit.audit_iface(@audit.broken_unknown_type(), "unknown.mbti")
  assert_eq(unknown.length(), 1)
  assert_true(unknown[0].message.contains("unknown type"))
  assert_true(unknown[0].message.contains("Widget"))
  // 外部引用（带 @ 的）按库的口径不算错——这一条把那条口径也钉住
  assert_false(unknown[0].message.contains("MachineSpec"))
}

///|
/// 反例：干净样本与真表同形，必须 0 发现。
test "反例：与真表同形的干净样本 0 发现" {
  let found = @audit.audit_iface(@audit.clean_sample(), "clean.mbti")
  assert_eq(found.length(), 0)
  assert_eq(
    @audit.families_of_iface(@audit.clean_sample(), "clean.mbti").length(),
    0,
  )
}

///|
/// 三处坏片段家族都登记成同一个名字——家族表只有一份，故这里也验一遍登记本身。
test "家族登记：三处坏片段都归「语法」类" {
  for
    src in [
      @audit.broken_duplicate(),
      @audit.broken_malformed(),
      @audit.broken_unknown_type(),
    ] {
    let fams = @audit.families_of_iface(src, "x.mbti")
    assert_eq(fams.length(), 1)
    assert_true(fams[0] == "语法")
  }
}

///|
/// 分层本身要能测。真表上一次发现都没有，所以在真表上「全塞已知设计」与
/// 「正确分层」输出完全一致——只在真表上验分层，等于没验。拿**试造的发现**
/// 来验：任何把它塞进「已知设计」的改动都变红。
test "分层：不设豁免 ⇒ 试造的发现全部进未预期" {
  let findings = [
    @audit.probe_finding(@sacore.FParse, "试造：一处语法问题"),
    @audit.probe_finding(@sacore.FUndefinedName, "试造：未定义名"),
  ]
  let (known, fresh) = @audit.split_iface(findings)
  assert_eq(known.length(), 0)
  assert_eq(fresh.length(), 2)
}

///|
/// 报告对称：口径、计数表、逐文件清单都在。
test "报告对称：接口面报告口径齐全" {
  let report = @audit.render_iface_report([
    ("src/pkg.generated.mbti", []),
    (
      "audit/pkg.generated.mbti",
      [@audit.probe_finding(@sacore.FParse, "试造：某行畸形")],
    ),
  ])
  assert_true(report.contains("接口面"))
  assert_true(report.contains("重复签名"))
  assert_true(report.contains("已知设计豁免"))
  assert_true(report.contains("audit/pkg.generated.mbti"))
  assert_true(report.contains("逐文件"))
}
