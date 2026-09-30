///|
/// 命令行入口：打印《通往宁静之路》的主体状态机。
///
///   moon run cmd/main              文字报告（默认）
///   moon run cmd/main -- mermaid   Mermaid 状态图
///   moon run cmd/main -- dot       Graphviz DOT
///   moon run cmd/main -- genesis   主线（原文顺序）
///   moon run cmd/main -- course    历程（可重入的环节序列）
///   moon run cmd/main -- naming    定名对照表（通用定名 / 原文名）
///   moon run cmd/main -- principle 修订所依据的主体通用性原则
///   moon run cmd/main -- ml       机器学习/DoubleML 与状态机的接口 + 因果实验
///   moon run cmd/main -- ml-export 导出状态机生成的数据集（CSV，前若干行）
///   moon run cmd/main -- all       报告 + 历程 + Mermaid
fn main {
  let args = @env.args()
  let format = if args.length() > 1 { args[1] } else { "report" }
  match format {
    "mermaid" => println(@sm.render_mermaid())
    "dot" => println(@sm.render_dot())
    "genesis" => println(@sm.render_genesis())
    "course" => println(@sm.render_course())
    "naming" => println(@sm.render_naming_table())
    "principle" => println(@sm.revision_principle())
    "ml" => println(@ml.render_ml_report(@ml.default_ml_plan()))
    "ml-export" => println(@ml.csv_preview(@ml.make_dataset(200, 1.5, 7), 12))
    "all" => {
      println(@sm.render_report())
      println("")
      println("## 历程（可重入的环节序列）")
      println("")
      println(@sm.render_course())
      println("")
      println("## 主线（原文顺序）")
      println("")
      println(@sm.render_genesis())
      println("")
      println("## Mermaid")
      println("")
      println(@sm.render_mermaid())
    }
    _ => println(@sm.render_report())
  }
}
