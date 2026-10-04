///|
/// 命令行入口：打印《通往宁静之路》的主体状态机。
///
///   moon run cmd/main              文字报告（默认）
///   moon run cmd/main -- mermaid   Mermaid 状态图
///   moon run cmd/main -- dot       Graphviz DOT
///   moon run cmd/main -- genesis   主线（原文顺序）
///   moon run cmd/main -- course    历程（可重入的环节序列）
///   moon run cmd/main -- naming    定名对照表（通用定名 / 原文名）
///   moon run cmd/main -- slots     驱动槽对照表（触发 → 八个槽）
///   moon run cmd/main -- loop      执行契约（位置 × 槽：迁／守／未定／无路）
///   moon run cmd/main -- principle 修订所依据的主体通用性原则
///   moon run cmd/main -- intuition 直觉读法：把裁决备忘录读成背景直觉的仓库（模型整理）
///   moon run cmd/main -- ml       机器学习/DoubleML 与状态机的接口 + 因果实验
///   moon run cmd/main -- ml-export 导出状态机生成的数据集（CSV，前若干行）
///   moon run cmd/main -- multi    多主体行为规则（R1–R12）+ 场景演示
///   moon run cmd/main -- group    群体状态机（模型延伸：成员 → 群体的涌现）
///   moon run cmd/main -- society 双层次社会交往模型（论文自身的理论构造：生活世界／系统／交往）
///   moon run cmd/main -- society-mermaid 上者的 Mermaid 状态图
///   moon run cmd/main -- group-mermaid  群体机的 Mermaid 状态图
///   moon run cmd/main -- nested-mermaid 嵌套视图：11 阶段为复合状态（容器）
///   moon run cmd/main -- journey    行程视图：一次示范行走真正走过的边（局部 + 样式）
///   moon run cmd/main -- viz       三台机汇成一页自包含 HTML（浏览器直开）
///   moon run cmd/main -- evolution 进化：变异空间／适应度目标／闸门／持久化／遗传
///   moon run cmd/main -- cycle    主体循环：位置 × 驱动槽 × 因果反馈（修习与开放都过闸门）
///   moon run cmd/main -- coordinator 科研 Agent 协调器：制品／规划／证据／决策／记忆／署名／运行时
///   moon run cmd/main -- dmlref 与外部参考实现（riantr/moonbit_doubleML）对照
///   moon run cmd/main -- causal   因果诊断（0.75.0 深用）：敏感性／多重检验／异质性
///   moon run cmd/main -- audit    自审计（三鉴）：主体机当程序读，已知设计 vs 未预期
///   moon run cmd/main -- spec     规格导出：主体机即 JSON 数据（词汇表防漂移，模型整理）
///   moon run cmd/main -- association 未定的软关联（JPDA 面镜像）：β 权重 + 歧义度 + 一致性核对（模型整理）
///   moon run cmd/main -- pathsum   泛半环路径和：最短路（tropical）+ 机器性质谓词（模型整理）
///   moon run cmd/main -- algebra   机器代数（Ragel 面）：算子映射 + 主线分解 + 最小化（模型整理）
///   moon run cmd/main -- petri     Petri 网面（CarlAdam 镜像）：库所/变迁/标识/发火/守恒（模型整理）
///   moon run cmd/main -- aho       回忆结构（Aho-Corasick 面）：触发句前缀树 + 失败链（模型整理）
///   moon run cmd/main -- buchi     ω-视角（Büchi 面）：非空性/活性潜势/停滞词（模型整理）
///   moon run cmd/main -- all       报告 + 历程 + Mermaid
fn main raise {
  let args = @env.args()
  let format = if args.length() > 1 { args[1] } else { "report" }
  match format {
    "mermaid" => println(@sm.render_mermaid())
    "dot" => println(@sm.render_dot())
    "genesis" => println(@sm.render_genesis())
    "course" => println(@sm.render_course())
    "naming" => println(@sm.render_naming_table())
    "slots" => println(@sm.render_slots())
    "loop" => println(@sm.render_loop_report())
    "principle" => println(@sm.revision_principle())
    "intuition" => println(@evolution.intuition_principle())
    "ml" => println(@ml.render_ml_report(@ml.default_ml_plan()))
    "ml-export" => println(@ml.csv_preview(@ml.make_dataset(200, 1.5, 7), 12))
    "multi" => println(@multi.render_multi_report())
    "group" => println(@group.render_group_report())
    "society" => println(@society.render_report())
    "society-mermaid" => println(@society.render_mermaid())
    "group-mermaid" => println(@group.render_mermaid())
    "nested-mermaid" => println(@sm.render_mermaid_nested())
    "journey" => println(@viz.journey())
    "viz" => println(@viz.page())
    "evolution" => println(@evolution.render_report())
    "cycle" => println(@evolution.render_cycle_report(@evolution.demo_cycle()))
    "coordinator" => println(@coordinator.render_report())
    "dmlref" => println(@dmlref.render_report())
    "causal" => println(@causal.render_report())
    "audit" => println(@audit.render_report())
    "spec" => println(@sm.spec_json())
    "association" => println(@evolution.render_association_report())
    "pathsum" => println(@sm.render_pathsum_report())
    "algebra" => println(@sm.render_algebra_report())
    "petri" => println(@sm.render_petri_report())
    "aho" => println(@sm.render_aho_report())
    "buchi" => println(@sm.render_buchi_report())
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
