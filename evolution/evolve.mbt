///|
/// 遗传与世代循环。
///
/// **遗传**在这里是三条：
///
///   1. 子代＝父代 + 一处改动（`descend`）；
///   2. 宪法**不在** `Genome` 里，因此没有任何变异能触到它，每一个后代都自动原样继承——
///      「遗产」不是被复制过去的，而是根本就不可变；
///   3. 每条改动连同它的理由写进账本（`Trail.why`），所以「为什么变成这样」也一起传下去。

///|
/// 子代：父代 + 候选改动；候选若没有实际改动，则原样返回父代。
pub fn descend(parent : Genome, c : Candidate) -> Genome {
  if c.genome == parent {
    parent
  } else {
    c.genome
  }
}

///|
/// 一个候选改动 + 它在闸门下的裁决。
pub struct Offer {
  candidate : Candidate
  decision : Decision
}

///|
/// 枚举父代的全部候选，逐个过闸门。
pub fn breed(
  parent : Genome,
  parent_score : Int,
  world : Array[Opponent],
  criterion : Criterion,
) -> Array[Offer] {
  let out : Array[Offer] = []
  for c in mutations(parent) {
    out.push({
      candidate: c,
      decision: judge(parent, parent_score, c, world, criterion),
    })
  }
  out
}

///|
/// 一次进化：从 `seed` 出发，做 `generations` 代爬山。
///
/// 每代把**全部**候选都记进账本（接收的、拒收的、回滚的），只把其中最好的一个接收改动
/// 作为下一代——账本因而同时记录「发生了什么」与「被挡下了什么」。没有可接收的改动就停。
pub fn evolve(
  seed : Genome,
  world : Array[Opponent],
  criterion : Criterion,
  generations : Int,
) -> Ledger {
  let objective = match criterion {
    Weighted(o) => o
    Causal(p) => p.objective
  }
  let trails : Array[Trail] = []
  let mut current = seed
  let mut current_score = score(evaluate(seed, world), objective)
  for gen = 0; gen < generations; gen = gen + 1 {
    let offers = breed(current, current_score, world, criterion)
    let mut best : Offer? = None
    for i = 0; i < offers.length(); i = i + 1 {
      let offer = offers[i]
      trails.push({
        generation: gen,
        step: i,
        parent: if gen == 0 {
          None
        } else {
          Some(gen - 1)
        },
        locus: offer.candidate.locus,
        what: offer.candidate.what,
        why: offer.decision.reason,
        verdict: offer.decision.verdict,
        score: offer.decision.score,
        effect: offer.decision.effect,
        effect_lo: offer.decision.effect_lo,
        fitness: offer.decision.fitness,
        genome: offer.candidate.genome,
      })
      if offer.decision.verdict == Accepted {
        let better = match best {
          None => true
          Some(b) =>
            key_of(offer.decision, criterion) > key_of(b.decision, criterion)
        }
        if better {
          best = Some(offer)
        }
      }
    }
    match best {
      Some(b) => {
        current = b.candidate.genome
        current_score = b.decision.score
      }
      None => break
    }
  }
  { seed, objective: objective.name, trails, }
}

///|
/// 挑选「最好」的那个改动：加权判据看分数，因果判据看效应。
fn key_of(d : Decision, criterion : Criterion) -> Int {
  match criterion {
    Weighted(_) => d.score
    Causal(_) => d.effect
  }
}
