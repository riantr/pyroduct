///|
/// 数一段 Mermaid 源里带 " --> " 的行（起始行 + 迁移行；注释与声明不算）。
fn arrow_lines(text : String) -> Int {
  let mut n = 0
  for line in text.split("\n") {
    if line.contains(" --> ") {
      n += 1
    }
  }
  n
}

///|
test "viz：三张图的内容与边数锁定" {
  // 主体：34 状态声明 + 3 个 [*] 起始 + 53 迁移 = 56 条箭头行
  let subject = @viz.subject()
  assert_true(subject.has_prefix("stateDiagram-v2"))
  assert_true(
    subject.contains("state \"无忆（原文：失忆）\" as NoPast"),
  )
  assert_true(subject.contains("[*] --> Standing"))
  assert_true(subject.contains("Tranquility"))
  assert_eq(arrow_lines(subject), 56)
  // 群体：20 状态声明 + 1 个 [*] 起始 + 44 迁移 = 45 条箭头行
  let group = @viz.group()
  assert_true(group.has_prefix("stateDiagram-v2"))
  assert_true(group.contains("state \"散在\" as Scattered"))
  assert_true(group.contains("[*] --> Scattered"))
  assert_true(group.contains("Settled"))
  assert_eq(arrow_lines(group), 45)
  // 社会：13 状态声明 + 1 个 [*] 起始 + 28 迁移 = 29 条箭头行
  let society = @viz.society()
  assert_true(society.has_prefix("stateDiagram-v2"))
  assert_true(society.contains("state \"世界\" as World"))
  assert_true(society.contains("Gap"))
  assert_eq(arrow_lines(society), 29)
}

///|
test "viz：HTML 页嵌三图且确定" {
  let page = @viz.page()
  assert_true(page.has_prefix("<!DOCTYPE html>"))
  assert_true(page.contains("mermaid.esm.min.mjs"))
  assert_true(page.contains("mermaid.initialize"))
  assert_true(page.contains(@viz.subject()))
  assert_true(page.contains(@viz.group()))
  assert_true(page.contains(@viz.society()))
  // 视时 CDN；构建与运行零网络
  assert_false(page.contains("http") && !page.contains("cdn.jsdelivr.net"))
  assert_eq(page, @viz.page())
}

///|
test "viz：嵌套视图与行程视图锁定" {
  // 嵌套：11 个阶段为复合状态容器；迁移边数与平铺一致（56 = 3 起始 + 53 迁移）
  let nested = @viz.subject_nested()
  assert_true(nested.has_prefix("stateDiagram-v2"))
  assert_true(nested.contains("as Natural {"))
  assert_true(nested.contains("as Standing"))
  assert_true(
    nested.contains("state \"无忆（原文：失忆）\" as NoPast"),
  )
  assert_eq(arrow_lines(nested), 56)
  // 行程：示范巡回——只画走过的边；未定与无路只以注释说明；当下位置高亮
  let journey = @viz.journey()
  assert_true(journey.has_prefix("stateDiagram-v2"))
  assert_true(journey.contains("[*] --> Standing"))
  assert_true(journey.contains("classDef now"))
  assert_true(journey.contains("%% 未定：自由 × 处境"))
  assert_true(journey.contains("%% 无路"))
  // 页面嵌五节：三平铺 + 嵌套 + 行程
  let page = @viz.page()
  assert_true(page.contains(nested))
  assert_true(page.contains(journey))
}
