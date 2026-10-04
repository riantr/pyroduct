///|
/// 关联诊断（JPDA 面镜像，模型整理）：未定的软关联。
///
/// 参照 PDA-JPDA（liqwidon，C++/Eigen 头文件实现）：JPDA 的本质是**不做硬
/// 关联**——门限矩阵剪除不可能，枚举一致的联合指派，按似然加权、在分布上
/// 融合（β 权重），软权重把硬指派解释成 argmax。四段与 pyroduct 的对应：
///
///   - **门限矩阵**（marks × trajectories 布尔，马氏距离 × χ² 门限）↔
///     位置 × 槽 的 exitable 表——272 组合中 228 无路＝门限外，`@sm.gaps`
///     已是那份布尔矩阵（执行契约，0.1.x 已有）；
///   - **关联事件**（一致的联合指派）↔ `@sm.Open` 的并存候选（同一处境的
///     多条出路并存）；
///   - **条件似然**（高斯残差似然）↔ 双诚对候选的分量：时间侧（首条）取
///     toward_self，空间侧（末条）取 toward_other，中间候选取两侧均值；
///   - **β 权重**（边缘化关联概率，Σ=1）↔ 归一化的候选权重；
///     **熵** ↔ 未定的关联歧义度（bit）。
///
/// 与既有裁决的一致性（关键命题，测试锁定）：`resolve_open` 的硬裁决
/// （双诚之比挑首/末）恰是 β 的 argmax——软分布把硬规则**解释**出来而不
/// 替代它：裁决仍由 `resolve_open` 做，这里只出诊断（分布、argmax 一致性、
/// 歧义度）。没有采样——「未定不掷骰子」的纪律照旧。
///
/// 数字纪律：概率住在 evolution（`先行` 槽不带数），src 零 import 不变；
/// 双诚 0..100 是 genome 的策略位，取它的分量作似然是模型整理，非原文直述。

///|
/// 一个并存候选的关联权重（模型整理）：首条（时间侧）取 toward_self，
/// 末条（空间侧）取 toward_other，中间候选取两侧均值（中性权重；机器若
/// 不出现 >2 路并存则此分支不触发）。
fn association_weight(
  cands_length : Int,
  index : Int,
  toward_self : Int,
  toward_other : Int,
) -> Double {
  if index == 0 {
    toward_self.to_double()
  } else if index == cands_length - 1 {
    toward_other.to_double()
  } else {
    (toward_self.to_double() + toward_other.to_double()) / 2.0
  }
}

///|
/// 未定的关联分布：并存候选的 β 权重（归一化，Σ=1）；非未定返回空数组。
/// 双诚同为零时（变异可把两诚夹到 0）无似然可言，回退均匀分布——门限外
/// 无信息，均匀是诚实的无信息先验。
pub fn association_probs(
  toward_self : Int,
  toward_other : Int,
  outcome : @sm.Outcome,
) -> Array[Double] {
  let out : Array[Double] = []
  match outcome {
    @sm.Open(cands) => {
      let n = cands.length()
      let raw : Array[Double] = []
      let mut sum = 0.0
      for i = 0; i < n; i = i + 1 {
        let w = association_weight(n, i, toward_self, toward_other)
        raw.push(w)
        sum += w
      }
      if sum <= 0.0 {
        for _i = 0; _i < n; _i = _i + 1 {
          out.push(1.0 / n.to_double())
        }
      } else {
        for w in raw {
          out.push(w / sum)
        }
      }
    }
    _ => ()
  }
  out
}

///|
/// 关联歧义度：β 的香农熵（bit）——0 表示无歧义，1 表示两路完全并重。
pub fn association_entropy(probs : Array[Double]) -> Double {
  let mut h = 0.0
  for p in probs {
    if p > 0.0 {
      h -= p * @math.log2(p)
    }
  }
  h
}

///|
/// 硬裁决与软分布的一致性：`resolve_open` 的选择（双诚之比挑首/末）是否
/// 为 β 的 argmax。两诚持平 → argmax 并列取首，恰是硬裁决的「挑首」。
/// 非未定返回 None。
pub fn association_consistent(
  toward_self : Int,
  toward_other : Int,
  outcome : @sm.Outcome,
) -> Bool? {
  match outcome {
    @sm.Open(cands) => {
      if cands.length() < 2 {
        return None
      }
      let probs = association_probs(toward_self, toward_other, outcome)
      let mut best = 0
      for i = 0; i < probs.length(); i = i + 1 {
        if probs[i] > probs[best] {
          best = i
        }
      }
      let pick = if toward_other > toward_self { cands.length() - 1 } else { 0 }
      Some(best == pick)
    }
    _ => None
  }
}

///|
/// 定点百分比显示（β=0.625 → `62.5%`）——免得浮点尾数进报告。
fn fmt_pct(p : Double) -> String {
  let tenths = (p * 1000.0).to_int()
  "\{tenths / 10}.\{tenths % 10}%"
}

///|
/// 定点两位小数显示（熵 0.918… → `0.91`）。
fn fmt2d(x : Double) -> String {
  let hundredths = (x * 100.0).to_int()
  "\{hundredths / 100}.\{hundredths % 100 / 10}\{hundredths % 10}"
}

///|
/// 关联诊断报告：枚举机器里全部并存（Open）组合，逐一给出 β 分布与歧义度；
/// 硬裁决与软分布的 argmax 逐个核对——全部一致是本层的活绊线（不一致即
/// 失败：说明权重方案与双诚之比漂移了，必须复审）。
pub fn render_association_report() -> String {
  let agent = default_agent()
  let lines : Array[String] = [
    "# 未定的软关联（JPDA 面镜像）", "", "参照 PDA-JPDA：门限矩阵 ↔ 位置 × 槽 的 exitable 表（`@sm.gaps`：272 组合",
    "中 228 在门外）；关联事件 ↔ `@sm.Open` 的并存候选；条件似然 ↔ 双诚分量；",
    "β 权重 ↔ 归一化关联概率（Σ=1）；熵 ↔ 关联歧义度（bit）。出处层：模型整理",
    "——权重是双诚（0..100）的分量，不是原文的数；裁决仍由双诚之比做，",
    "这里不掷骰子、不替主体决断，只把未定量化。", "", "## 机器里的全部并存组合（缺省 agent：双诚中等 70/70）",
  ]
  let mut opens = 0
  let mut all_consistent = true
  for s in @sm.all_states() {
    for k in @sm.all_slots() {
      let out = @sm.step(s, k)
      match out {
        @sm.Open(cands) => {
          opens += 1
          let probs = association_probs(
            agent.toward_self,
            agent.toward_other,
            out,
          )
          let h = association_entropy(probs)
          let parts : Array[String] = []
          for i = 0; i < cands.length(); i = i + 1 {
            parts.push(
              "\{cands[i].0.label()}→\{cands[i].1.designation()}（β=\{fmt_pct(probs[i])}）",
            )
          }
          match
            association_consistent(agent.toward_self, agent.toward_other, out) {
            Some(ok) => if !ok { all_consistent = false }
            None => ()
          }
          lines.push(
            "- \{s.designation()} × \{k.designation()}　\{cands.length()} 路并存：\{parts.join("；")}；熵 \{fmt2d(h)} bit",
          )
        }
        _ => ()
      }
    }
  }
  lines.push("")
  lines.push(
    "共 \{opens} 个并存组合；硬裁决（双诚之比挑首/末）与软分布的 argmax 逐个核对：\{if all_consistent { "全部一致" } else { "出现不一致——复审！" }}。双诚倾斜时质量随倾斜移到被选侧，熵随之下降；两诚持平的 agent 站在完全并重的 1 bit 上——未定就是未定，机器不替主体择其一，主体以双诚之比自择。",
  )
  lines.join("\n")
}
