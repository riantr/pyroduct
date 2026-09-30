///|
/// 任务与制品层 —— 把「结果」从对话判词换成**可交付的制品**。
///
/// 以前这个项目里，一次交互的产出是 `@multi.Verdict`（一个对话判词）。这一层补上
/// 科研协调真正要传递的对象：**研究问题、数据集、产物、结果、引用、复现**。
/// 一条 `Result` 必须钉在一个 `Dataset` 上（行数 + 种子 + 指纹），带效应与区间，
/// 并有 `Replication` 记录——这就是「外部证据绑定」的载体。

///|
/// 研究问题。
pub struct Question {
  id : Int
  text : String
  discourse : @multi.DiscourseType
}

///|
/// 数据集：外部证据的载体。行数与种子保证可复现，`digest` 把后续结果钉在**这一版**上。
pub struct Dataset {
  id : Int
  name : String
  rows : Int
  seed : UInt64
  digest : String
}

///|
/// 产物种类。
pub(all) enum ArtifactKind {
  Paper // 论文
  Figure // 图
  Code // 代码
  Data // 数据
  Note // 笔记
} derive(Eq)

///|
pub extend ArtifactKind with Eq::{not_equal, equal}

///|
/// 产物种类名。
pub fn ArtifactKind::label(self : ArtifactKind) -> String {
  match self {
    Paper => "论文"
    Figure => "图"
    Code => "代码"
    Data => "数据"
    Note => "笔记"
  }
}

///|
/// 产物：一次科研产出的构件。
pub struct Artifact {
  id : Int
  kind : ArtifactKind
  name : String
  task : Int
  digest : String
}

///|
/// 结果：一条**可交付**的产出（不再是对话判词）。效应与区间以千分位整数存放。
pub struct Result {
  id : Int
  task : Int
  question : Int
  claim : @multi.ClaimKind
  phase : @multi.ClaimPhase
  summary : String
  dataset : Int
  effect : Int
  ci_low : Int
  ci_high : Int
  replicas : Int
}

///|
/// 引用。
pub struct Citation {
  key : String
  title : String
  locator : String
}

///|
/// 复现：在**另一个**数据集（不同种子）上重跑同一结果。
pub struct Replication {
  id : Int
  result : Int
  dataset : Int
  effect : Int
  ci_low : Int
  ci_high : Int
  agrees : Bool
}

///|
/// 任务：问题的执行单元，带依赖、所需制品、预算与期限。
/// 约定：`id` 即数组下标（`deps` 也按下标引用）。
pub struct Task {
  id : Int
  question : Int
  title : String
  deps : Array[Int]
  needs : Array[Int]
  budget : Int
  deadline : Int
}

///|
/// 构造一个问题。
pub fn question(
  id : Int,
  text : String,
  discourse : @multi.DiscourseType,
) -> Question {
  { id, text, discourse, }
}

///|
/// 构造一个数据集。
pub fn dataset(
  id : Int,
  name : String,
  rows : Int,
  seed : UInt64,
  digest : String,
) -> Dataset {
  { id, name, rows, seed, digest, }
}

///|
/// 构造一个任务。
pub fn task(
  id : Int,
  question : Int,
  title : String,
  deps : Array[Int],
  needs : Array[Int],
  budget : Int,
  deadline : Int,
) -> Task {
  { id, question, title, deps, needs, budget, deadline, }
}

///|
/// 构造一条结果。
pub fn result(
  id : Int,
  task : Int,
  question : Int,
  claim : @multi.ClaimKind,
  phase : @multi.ClaimPhase,
  summary : String,
  dataset : Int,
  effect : Int,
  ci_low : Int,
  ci_high : Int,
  replicas : Int,
) -> Result {
  {
    id,
    task,
    question,
    claim,
    phase,
    summary,
    dataset,
    effect,
    ci_low,
    ci_high,
    replicas,
  }
}

///|
/// 结果是否钉在了某个数据集上（外部证据绑定）。
pub fn Result::is_bound(self : Result) -> Bool {
  self.dataset >= 0 && self.ci_low <= self.ci_high
}
