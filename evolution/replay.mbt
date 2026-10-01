///|
/// 一次主体循环内的**裁决备忘录**：同一份证据不重裁。
///
/// `run_cycle` 每回合跑一次世界回应（`evaluate`）与两次闸门裁决（`judge`），三者
/// 都是 `(基因组, 世界, 判据)` 的纯函数（固定种子、固定世界）。被拒不推进配置，
/// 于是下一回合在**逐字节相同的输入**上重跑同一估计——重复裁决在哲学上是自欺
/// 的温床：同一份证据不应当被重裁一遍；在计算上是重复的 DoubleML。本备忘录按
/// （父代基因组, 候选基因组）记下首次裁决，命中时原样取回，判词以
/// 「[与回合 N 同判·不重裁]」为前缀入账——账本写明这份证据是哪一回合裁的。
///
/// 取舍：备忘录**只在一次循环内活**。世界与判据固定，父代得分又由基因组决定
/// （`response` 同样入此备忘录），键才决定一切；不跨循环、不跨运行共享，
/// 也没有全局可变状态（`evolve`／`breed` 的逐候选裁决不经过它）。
priv struct DecisionMemo {
  judgements : Array[(Genome, Genome, Int, Decision)] // 父代、候选、首裁回合、判词
  responses : Array[(Genome, Int, Fitness)] // 基因组、首评回合、世界回应
}

///|
fn DecisionMemo::new() -> DecisionMemo {
  { judgements: [], responses: [], }
}

///|
/// 世界回应：同一基因组只评一次。
fn DecisionMemo::response(
  self : DecisionMemo,
  g : Genome,
  round : Int,
  compute : () -> Fitness,
) -> Fitness {
  for entry in self.responses {
    if entry.0 == g {
      return entry.2
    }
  }
  let f = compute()
  self.responses.push((g, round, f))
  f
}

///|
/// 闸门裁决：同一对（父代, 候选）只裁一次；命中时原样取回首判，
/// 理由前缀「[与回合 N 同判·不重裁]」随账本一起只追加。
fn DecisionMemo::judgement(
  self : DecisionMemo,
  parent : Genome,
  c : Candidate,
  round : Int,
  compute : () -> Decision,
) -> Decision {
  for entry in self.judgements {
    if entry.0 == parent && entry.1 == c.genome {
      let d = entry.3
      return {
        verdict: d.verdict,
        reason: "[与回合 \{entry.2} 同判·不重裁] \{d.reason}",
        fitness: d.fitness,
        score: d.score,
        effect: d.effect,
        effect_lo: d.effect_lo,
      }
    }
  }
  let d = compute()
  self.judgements.push((parent, c.genome, round, d))
  d
}
