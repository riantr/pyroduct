// 主体机 JSON 桥入口：DeepSeek Harness 插件（dsh-plugin-pyroduct）在 Node 下
// 运行本程序，传**一个**以 '{' 开头的 JSON 请求参数，从 stdout 读一行 JSON
// 回信。请求形如 { "kind": "petri" }；未给 kind 时默认 "report"（与 CLI 的
// 缺省一致）。桥使插件保持纯 spawner：全部模型语义留在 MoonBit 侧，随本模
// 块一起定版与门禁（参照 moonbit_static_analysis/src/jsoncli 的先例）。
//
// 支持的 kind = faces() 清单：机器本体（report/slots/loop/mermaid/dot/
// genesis/course/naming/principle/spec）+ 多主体与涌现（multi/group/society）
// + agent 层（evolution/cycle/intuition/association）+ 因果与审计（dmlref/
// causal/audit/ml/ml-export）+ 协调器 + 五条分析面（pathsum/algebra/petri/
// aho/buchi）。可视化合成页（viz/journey/嵌套视图）与 all 组合不走桥——
// 它们是呈现层，不是模型事实。

///|
/// 回信信封：rendered 是报告全文；faces 是支持的 kind 清单（防漂移）。
struct Reply {
  ok : Bool
  error : String?
  kind : String
  rendered : String
  faces : Array[String]
} derive(ToJson)

///|
struct Request {
  kind : String?
} derive(FromJson)

///|
/// 本机分析面的稳定清单（新增面时同步此表、cmd/main 与插件 README）。
fn faces() -> Array[String] {
  [
    "report", "slots", "loop", "multi", "group", "society", "evolution", "cycle",
    "coordinator", "dmlref", "causal", "audit", "mermaid", "dot", "genesis", "course",
    "naming", "principle", "intuition", "ml", "ml-export", "spec", "association",
    "pathsum", "algebra", "petri", "aho", "buchi",
  ]
}

///|
fn ok_reply(kind : String, rendered : String) -> Reply {
  { ok: true, error: None, kind, rendered, faces: faces(), }
}

///|
fn err_reply(msg : String) -> Reply {
  { ok: false, error: Some(msg), kind: "", rendered: "", faces: faces(), }
}

///|
fn render_kind(kind : String) -> String raise {
  match kind {
    "report" => @sm.render_report()
    "slots" => @sm.render_slots()
    "loop" => @sm.render_loop_report()
    "multi" => @multi.render_multi_report()
    "group" => @group.render_group_report()
    "society" => @society.render_report()
    "evolution" => @evolution.render_report()
    "cycle" => @evolution.render_cycle_report(@evolution.demo_cycle())
    "coordinator" => @coordinator.render_report()
    "dmlref" => @dmlref.render_report()
    "causal" => @causal.render_report()
    "audit" => @audit.render_report()
    "mermaid" => @sm.render_mermaid()
    "dot" => @sm.render_dot()
    "genesis" => @sm.render_genesis()
    "course" => @sm.render_course()
    "naming" => @sm.render_naming_table()
    "principle" => @sm.revision_principle()
    "intuition" => @evolution.intuition_principle()
    "ml" => @ml.render_ml_report(@ml.default_ml_plan())
    "ml-export" => @ml.csv_preview(@ml.make_dataset(200, 1.5, 7), 12)
    "spec" => @sm.spec_json()
    "association" => @evolution.render_association_report()
    "pathsum" => @sm.render_pathsum_report()
    "algebra" => @sm.render_algebra_report()
    "petri" => @sm.render_petri_report()
    "aho" => @sm.render_aho_report()
    "buchi" => @sm.render_buchi_report()
    _ => ""
  }
}

///|
/// 请求 JSON 是以 '{' 开头的那一个参数（运行器在它之前的参数被忽略）。
fn find_request_arg(args : Array[String]) -> String? {
  for s in args {
    if s.trim_start().has_prefix("{") {
      return Some(s)
    }
  }
  None
}

///|
fn handle(raw : String) -> Reply {
  try {
    let request : Request = @json.from_json(@json.parse(raw))
    let kind = request.kind.unwrap_or("report")
    match kind {
      k if faces().contains(k) => ok_reply(k, render_kind(k))
      other =>
        err_reply("unknown kind '\{other}'（faces: \{faces().join(", ")}）")
    }
  } catch {
    err => err_reply("bad request: \{err.to_string()}")
  }
}

///|
fn main {
  let args : Array[String] = @env.args()
  match find_request_arg(args) {
    None =>
      println(
        @json.to_json(err_reply("missing request argument (a JSON object)")).stringify(),
      )
    Some(raw) => println(@json.to_json(handle(raw)).stringify())
  }
}
