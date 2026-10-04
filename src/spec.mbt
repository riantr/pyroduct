///|
/// 规格导出（模型整理）：把主体机写成一份自描述的 JSON 文档——「机器即数据」。
///
/// 参照 python-statemachine 的 io/ 中立 IR（JSON／YAML／SCXML →
/// StateMachineDefinition → builder → machine class；其 JSON Schema 供工具经
/// `$schema` 引用；词汇表键集在解析器与 schema 之间断言相等，两者永不漂移）。
/// pyroduct 的方向相反：**数据即代码**（模型是字面表），故这里导出
/// **机器 → 规格**——规格成为可被外部工具消费的文档，而**不做反向构造**
/// （spec → machine 会引入第二事实源，违背数据即代码；audit 已把真表转纯数据
/// 做静态审察，那是同一方向的另一形态）。
///
/// 词汇表纪律（移植自其 `_DOCUMENT_KEYS` ↔ schema 断言）：`spec_vocabulary`
/// 是唯一事实源，测试逐键核对输出——输出里出现词汇表之外的键即失败。
///
/// 刻意不含的键（如实记录）：`final`／`parallel`／`history`——本模型没有
/// 终点（宁静是静定极而非终点，R11 恒可重入反顾）、没有并行区域（并存的两侧
/// 是「未定」，不是并行激活）、没有运行时历史（宁静→反顾的重入是数据边）。
/// 这些是 statechart 的概念，不是原文的事实。
///
/// 规格只含**本质表**（原文直述 + 槽归位）：派生数据（无路组合、历程、
/// 嵌套视图）不入规格——规格是机器，不是它的分析。
///
/// 构建零依赖：手写字符串，不引 JSON 库（`src` 零 import 纪律维持）。
/// 语料措辞（定名／原文名／触发句）经核不含 ASCII 引号与反斜杠，故直接
/// 产出；若未来引入含引号的措辞，先加转义再入规格。

///|
/// 规格文档的全部键（唯一事实源；测试逐键核对输出，防漂移）。
pub fn spec_vocabulary() -> Array[String] {
  [
    "$schema", "name", "description", "initial", "restingPole", // 文档级
     "states", "id", "original", "phase", // 状态（按 id 键控）
     "phases", "members", // 阶段（嵌套容器）
     "slots", "transitions", "from", "event", "target", "slot", // 槽与迁移
  ]
}

///|
/// 主体机的 JSON 规格：34 状态（按两字定名作 id）· 11 阶段（members 嵌套）·
/// 8 槽 · 53 迁移（event 是原文直述的触发句，slot 是模型整理的槽归位）。
pub fn spec_json() -> String {
  let lines : Array[String] = []
  lines.push("{")
  lines.push("  \"$schema\": \"pyroduct-spec-v1\",")
  lines.push("  \"name\": \"subject\",")
  lines.push(
    "  \"description\": \"主体道德发生状态机 —— 《通往宁静之路：个体道德发生论纲要》\",",
  )
  lines.push("  \"initial\": \"\{initial().designation()}\",")
  lines.push("  \"restingPole\": \"\{terminal().designation()}\",")
  // 状态：按 id（两字定名）键控，原文名与所属阶段随行。
  let st_lines : Array[String] = []
  for s in all_states() {
    st_lines.push(
      "    {\"id\": \"\{s.designation()}\", \"original\": \"\{s.label()}\", \"phase\": \"\{s.phase().designation()}\"}",
    )
  }
  lines.push("  \"states\": [")
  lines.push(st_lines.join(",\n"))
  lines.push("  ],")
  // 阶段：嵌套容器，members 是其内部状态（照 all_states 顺序）。
  let ph_lines : Array[String] = []
  for p in all_phases() {
    let ms : Array[String] = []
    for s in all_states() {
      if s.phase() == p {
        ms.push("\"\{s.designation()}\"")
      }
    }
    ph_lines.push(
      "    {\"id\": \"\{p.designation()}\", \"members\": [\{ms.join(", ")}]}",
    )
  }
  lines.push("  \"phases\": [")
  lines.push(ph_lines.join(",\n"))
  lines.push("  ],")
  // 槽：八个驱动槽（定名互异，见测试）。
  let sl : Array[String] = []
  for k in all_slots() {
    sl.push("\"\{k.designation()}\"")
  }
  lines.push("  \"slots\": [\{sl.join(", ")}],")
  // 迁移：event 是原文直述的触发句；slot 是模型整理的槽归位。
  let tr_lines : Array[String] = []
  for t in transitions() {
    tr_lines.push(
      "    {\"from\": \"\{t.from.designation()}\", \"event\": \"\{t.trigger.label()}\", \"target\": \"\{t.to.designation()}\", \"slot\": \"\{t.trigger.slot().designation()}\"}",
    )
  }
  lines.push("  \"transitions\": [")
  lines.push(tr_lines.join(",\n"))
  lines.push("  ]")
  lines.push("}")
  lines.join("\n")
}
