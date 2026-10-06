///|
/// 接口面实扫 CLI 入口。逻辑在 `@ifacescan`（`tools/ifacescan`）——可执行包
/// 引用不到自己，这是 MoonBit 的形状（与 `cmd/coord` + `coordinator` 同构）。
async fn main {
  let rows = @scan.scan(".")
  println(@audit.render_iface_report(rows))
  let n = @scan.fresh_total(rows)
  if n > 0 {
    println("")
    println("未预期发现 \{n} 条——门禁失败，须先复审。")
  }
}
