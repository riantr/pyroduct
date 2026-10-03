///|
test "沉淀实验：固定种子可复现，同槽权重大于跨槽，命中超基线" {
  let a = @snnref.run_sediment(@snnref.SedimentConfig::new())
  let b = @snnref.run_sediment(@snnref.SedimentConfig::new())
  // 确定性：同一种子两次运行逐位一致（全部随机性只走 Xoshiro(seed)）。
  assert_eq(a.within_mean, b.within_mean)
  assert_eq(a.cross_mean, b.cross_mean)
  assert_eq(a.hit_rate, b.hit_rate)
  assert_eq(a.n_triggers, 49)
  assert_eq(a.n_slots, 8)
  // 判据 1：同槽平均权重 > 跨槽平均权重（结构从放电中长出）。
  assert_true(a.within_mean > a.cross_mean)
  // 判据 2：最强伙伴命中率 > 随机基线。
  assert_true(a.hit_rate > a.chance_rate)
  assert_true(a.recovered)
}

///|
test "报告对称：沉淀报告给出机制、判据、分槽命中与出处层" {
  let r = @snnref.render_report()
  assert_true(r.contains("脉冲沉淀"))
  assert_true(r.contains("STDP"))
  assert_true(r.contains("驱动槽八分"))
  assert_true(r.contains("模型整理"))
  assert_true(r.contains("同槽平均权重"))
  assert_true(r.contains("跨槽平均权重"))
  assert_true(r.contains("不是论断"))
  // 分槽命中表覆盖八个槽。
  assert_true(r.contains("处境") || r.contains("共在"))
}
