///|
/// 可视化层：三台状态机（主体／群体／社会）的 Mermaid 汇总与自包含 HTML 页。
/// 各机的图源由所属层渲染（报告对称惯例），这里只做汇整与呈现。

///|
/// 主体机（34 状态 · 53 迁移 · 11 阶段）的 Mermaid `stateDiagram-v2` 源文本。
pub fn subject() -> String {
  @sm.render_mermaid()
}

///|
/// 群体机（20 状态 · 42 迁移 · 9 阶段）的 Mermaid `stateDiagram-v2` 源文本。
pub fn group() -> String {
  @group.render_mermaid()
}

///|
/// 社会机（13 状态 · 26 迁移 · 8 阶段）的 Mermaid `stateDiagram-v2` 源文本。
pub fn society() -> String {
  @society.render_mermaid()
}

///|
/// 自包含 HTML 页：三张 Mermaid 图嵌在同一页，浏览器打开即渲染。
/// 引 mermaid.js CDN——构建与运行零网络，联网只发生在视时。
/// 落盘：`moon run cmd/main -- viz > viz.html`。
pub fn page() -> String {
  let lines : Array[String] = [
    "<!DOCTYPE html>", "<html lang=\"zh\">", "<head>", "<meta charset=\"utf-8\">",
    "<title>Pyroduct 状态机：主体 · 群体 · 社会</title>", "<script type=\"module\">",
    "import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';",
    "mermaid.initialize({ startOnLoad: true, theme: 'neutral' });", "</script>",
    "<style>", "body { font-family: 'Noto Serif SC', serif; margin: 2rem auto; max-width: 60rem; }",
    "h1 { font-size: 1.4rem; }", "h2 { font-size: 1.2rem; margin-top: 2rem; }", "pre.mermaid { background: #fafafa; border: 1px solid #ddd; padding: 1rem; }",
    ".meta { color: #666; }", "</style>", "</head>", "<body>", "<h1>Pyroduct 状态机：主体 · 群体 · 社会</h1>",
    "<p class=\"meta\">出处：任勇祥《伽达默尔与哈贝马斯真理观比较》（2008）及附录",
    "《通往宁静之路：个体道德发生论纲要》。原文直述 vs 模型整理，见各层报告。</p>",
    "<h2>主体（34 状态 · 53 迁移 · 11 阶段）</h2>", "<pre class=\"mermaid\">",
  ]
  lines.push(subject())
  lines.push("</pre>")
  lines.push("<h2>群体（20 状态 · 42 迁移 · 9 阶段）</h2>")
  lines.push("<pre class=\"mermaid\">")
  lines.push(group())
  lines.push("</pre>")
  lines.push("<h2>社会（13 状态 · 26 迁移 · 8 阶段）</h2>")
  lines.push("<pre class=\"mermaid\">")
  lines.push(society())
  lines.push("</pre>")
  lines.push("</body>")
  lines.push("</html>")
  lines.join("\n")
}
