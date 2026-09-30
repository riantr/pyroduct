///|
/// 商谈段 / 决策段的分离。
///
/// 「商谈段」开放：多个方案并存，任何主张只是建议（R14）。「决策段」必须交付——
/// 但交付物恒带三样东西：**可修订标记、残余归属、重开条件**。这样既交了东西，
/// 又保证「缺口」仍可达（`@society.no_final_closure` 的精神）。

///|
/// 商谈段：开放。
pub(all) struct Deliberation {
  question : Int
  options : Array[Int] // 候选发现（finding id）
  open_remainder : String // 未穷尽者（R3），恒非空
}

///|
/// 交付状态。
pub(all) enum Commitment {
  Draft // 草稿
  Adopted // 采纳
  Superseded // 被取代
  Withdrawn // 撤回
} derive(Eq)

///|
pub extend Commitment with Eq::{not_equal, equal}

///|
/// 交付状态名。
pub fn Commitment::label(self : Commitment) -> String {
  match self {
    Draft => "草稿"
    Adopted => "采纳"
    Superseded => "被取代"
    Withdrawn => "撤回"
  }
}

///|
/// 决策段：必须交付，且恒带可修订标记、残余归属与重开条件。
pub struct Decision {
  question : Int
  chosen : Int
  commitment : Commitment
  revisable : Bool
  residual_owner : Int
  reopen_when : String
  at : Int
}

///|
/// 从商谈段进入决策段。以下任一不满足即拒（返回 `None`）：
/// 选中项不在方案里、未穷尽者为空、重开条件为空、残余归属无效。
pub fn decide(
  d : Deliberation,
  chosen : Int,
  residual_owner : Int,
  reopen_when : String,
  at : Int,
) -> Decision? {
  if !d.options.contains(chosen) {
    return None
  }
  if d.open_remainder.length() == 0 || reopen_when.length() == 0 {
    return None
  }
  if residual_owner < 0 {
    return None
  }
  Some({
    question: d.question,
    chosen,
    commitment: Adopted,
    revisable: true,
    residual_owner,
    reopen_when,
    at,
  })
}

///|
/// 决策是否合宪：可修订、重开条件非空、残余归属有效。
pub fn decision_ok(dec : Decision) -> Bool {
  dec.revisable && dec.reopen_when.length() > 0 && dec.residual_owner >= 0
}

///|
/// 回到商谈段（缺口可达）：交付降为草稿，并把新方案并进来。
pub fn reopen(dec : Decision, extra : Int) -> Deliberation {
  {
    question: dec.question,
    options: [dec.chosen, extra],
    open_remainder: "重开：\{dec.reopen_when}",
  }
}

///|
/// 决策文本。
pub fn render_decision(dec : Decision) -> String {
  let lines : Array[String] = [
    "问题\{dec.question}｜交付=\{dec.commitment.label()}｜可修订=\{dec.revisable}",
    "残余归属：研究者\{dec.residual_owner}",
    "重开条件：\{dec.reopen_when}",
  ]
  lines.join("\n")
}
