///|
/// 示例 4 —— **库使用者**的最小闭环：只 import 本库的公开 API，不碰内部实现。
///
///   moon run examples/consumer
///
/// 对应参考 README 里的 `examples/consumer_demo/`：一个外部 `moon add` 使用者
/// 会写出来的东西。
fn main {
  println("=== riantr/pyroduct · 库使用者示例 ===")
  println("")
  println("[主体状态机]")
  println("  状态数        = \{@sm.all_states().length()}")
  println("  阶段数        = \{@sm.all_phases().length()}")
  println(
    "  起点 / 终点   = \{@sm.initial().designation()} / \{@sm.terminal().designation()}",
  )
  println("  主线长度      = \{@sm.genesis_path().length()}")
  println(
    "  宁静可达      = \{@sm.reachable(@sm.initial(), @sm.terminal())}",
  )
  println("")
  println("[多主体]")
  let me = @multi.subject(
    1,
    @multi.rendezvous(),
    @multi.InterSubjective,
    70,
    70,
    9,
  )
  let other = @multi.subject(2, @multi.rendezvous(), @multi.ChengRan, 80, 80, 9)
  let claim : @multi.ValidityClaim = {
    kind: @multi.Truthfulness,
    phase: @multi.During,
  }
  let out = @multi.encounter(me, other, @multi.Theoretical, claim)
  println("  规则条数      = \{@multi.rules().length()}")
  println(
    "  一次遭遇      = 决断 \{out.verdict.label()}｜可修订 \{out.revisable}",
  )
  println("  甲 →          = \{out.a.state.designation()}")
  println("  乙 →          = \{out.b.state.designation()}")
  println("")
  println("[双层次社会交往模型]")
  println("  状态数        = \{@society.all_states().length()}")
  println("  迁移数        = \{@society.transitions().length()}")
  println("  不封闭        = \{@society.no_final_closure()}")
  println("  文本依据条数  = \{@society.basis().length()}")
  println("  起点          = \{@society.initial().designation()}")
}
