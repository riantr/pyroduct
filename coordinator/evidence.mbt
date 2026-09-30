///|
/// 外部证据绑定 —— 把一条主张钉到**数据集与复现**上，而不是钉到对话判词上。
///
/// 一条 `Binding` 记录：在哪个数据集（哪一版指纹）、跑了多少行、效应与 95% 区间、
/// 复现了几次。判词由**区间**给出，不由投票给出——这正是「把主张钉到数据上」。

///|
/// 凭据强弱。
pub(all) enum Warrant {
  FromData // 单次数据
  FromReplication // 多次复现且同号
  FromDialogue // 仅对话（未做实验）
} derive(Eq)

///|
pub extend Warrant with Eq::{not_equal, equal}

///|
/// 凭据名。
pub fn Warrant::label(self : Warrant) -> String {
  match self {
    FromData => "单次数据"
    FromReplication => "多次复现"
    FromDialogue => "仅对话"
  }
}

///|
/// 证据绑定。
pub struct Binding {
  claim_text : String
  dataset : Int
  digest : String
  effect : Int // 千分位
  ci_low : Int
  ci_high : Int
  replicas : Int
  warrant : Warrant
}

///|
/// 由证据得到的判词（不是投票结果）。
pub(all) enum EvidenceVerdict {
  Supported // 支持
  Refuted // 反驳
  Inconclusive // 不确定
  Replicated // 复现成立
} derive(Eq)

///|
pub extend EvidenceVerdict with Eq::{not_equal, equal}

///|
/// 判词名。
pub fn EvidenceVerdict::label(self : EvidenceVerdict) -> String {
  match self {
    Supported => "支持"
    Refuted => "反驳"
    Inconclusive => "不确定"
    Replicated => "复现成立"
  }
}

///|
/// 判词：区间不含 0 且为正 → 支持；不含 0 且为负 → 反驳；含 0 → 不确定；
/// 复现 ≥2 次且显著为正 → 复现成立。
pub fn evidence_verdict(b : Binding) -> EvidenceVerdict {
  if b.replicas >= 2 && b.ci_low > 0 {
    Replicated
  } else if b.ci_low > 0 {
    Supported
  } else if b.ci_high < 0 {
    Refuted
  } else {
    Inconclusive
  }
}

///|
/// 该绑定是否仍钉在当前的数据集版本上（指纹一致）——数据一改，绑定即失效。
pub fn Binding::pinned_to(self : Binding, ds : Dataset) -> Bool {
  self.dataset == ds.id && self.digest == ds.digest
}

///|
/// 在一个数据集上做一次实验（真跑 DoubleML）。
pub fn experiment(
  claim_text : String,
  ds : Dataset,
  parent : @evolution.Genome,
  candidate : @evolution.Genome,
  world : Array[@evolution.Opponent],
) -> Binding {
  let (effect, lo, hi) = measure(parent, candidate, world, ds.rows, ds.seed)
  {
    claim_text,
    dataset: ds.id,
    digest: ds.digest,
    effect,
    ci_low: lo,
    ci_high: hi,
    replicas: 1,
    warrant: FromData,
  }
}

///|
/// 复现：换一个种子重跑。同号且都显著则记为复现成立。
pub fn replicate(
  b : Binding,
  ds : Dataset,
  parent : @evolution.Genome,
  candidate : @evolution.Genome,
  world : Array[@evolution.Opponent],
) -> Binding {
  let (effect, lo, hi) = measure(parent, candidate, world, ds.rows, ds.seed + 1)
  let same_sign = (effect > 0) == (b.effect > 0) && (lo > 0) == (b.ci_low > 0)
  ignore(hi)
  {
    ..b,
    replicas: b.replicas + 1,
    warrant: if same_sign {
      FromReplication
    } else {
      b.warrant
    },
  }
}

///|
/// 一次测量：生成回合 → DoubleML → 千分位 (θ̂, 下界, 上界)。
fn measure(
  parent : @evolution.Genome,
  candidate : @evolution.Genome,
  world : Array[@evolution.Opponent],
  rows : Int,
  seed : UInt64,
) -> (Int, Int, Int) {
  let data = @evolution.make_episodes(parent, candidate, world, rows, seed)
  let r = @ml.dml_plr(data.y, data.t, data.x, @ml.default_dml_config())
  (
    @evolution.permille(r.theta),
    @evolution.permille(r.ci_low),
    @evolution.permille(r.ci_high),
  )
}

///|
/// 把一次复现记成一条 `Replication`（供台账与报告）。
pub fn replication_of(
  result_id : Int,
  ds : Dataset,
  b : Binding,
  agrees : Bool,
) -> Replication {
  {
    id: 0,
    result: result_id,
    dataset: ds.id,
    effect: b.effect,
    ci_low: b.ci_low,
    ci_high: b.ci_high,
    agrees,
  }
}
