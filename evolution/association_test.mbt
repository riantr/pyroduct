///|
/// 黑盒测试：关联诊断（JPDA 面镜像）。锁定三件事——归一化（β Σ=1）、
/// 与硬裁决的一致性（双诚之比恰是 β 的 argmax，全部并存组合逐个核对）、
/// 歧义度的界（两路持平 = 1 bit）。

///|
/// 机器里全部并存（Open）组合的枚举（位置 × 槽，272 次查询，纯函数）。
fn all_opens() -> Array[(@sm.SubjectState, @sm.Slot, @sm.Outcome)] {
  let out : Array[(@sm.SubjectState, @sm.Slot, @sm.Outcome)] = []
  for s in @sm.all_states() {
    for k in @sm.all_slots() {
      let o = @sm.step(s, k)
      match o {
        @sm.Open(_) => out.push((s, k, o))
        _ => ()
      }
    }
  }
  out
}

///|
test "association：全部并存组合的 β 归一化（Σ=1）且与硬裁决 argmax 逐一一致" {
  // 四种基因组：双诚中等、他之诚更盛、己之诚更盛、双双夹零
  let genomes = [
    @evolution.default_agent(),
    @evolution.genome(
      @evolution.Suggestive,
      @multi.InterSubjective,
      90,
      40,
      3,
      70,
    ),
    @evolution.genome(
      @evolution.Suggestive,
      @multi.InterSubjective,
      40,
      90,
      3,
      70,
    ),
    @evolution.genome(
      @evolution.Suggestive,
      @multi.InterSubjective,
      0,
      0,
      3,
      70,
    ),
  ]
  let opens = all_opens()
  assert_true(opens.length() > 0)
  for entry in opens {
    for g in genomes {
      let probs = @evolution.association_probs(
        g.toward_self,
        g.toward_other,
        entry.2,
      )
      match entry.2 {
        @sm.Open(cands) => assert_eq(probs.length(), cands.length())
        _ => assert_true(false)
      }
      let mut sum = 0.0
      for p in probs {
        assert_true(p > 0.0 && p <= 1.0)
        sum += p
      }
      assert_true((sum - 1.0).abs() < 0.000000001)
      // 硬裁决（双诚之比挑首/末）恰是软分布的 argmax——活绊线
      match
        @evolution.association_consistent(
          g.toward_self,
          g.toward_other,
          entry.2,
        ) {
        Some(ok) => assert_true(ok)
        None => assert_true(false)
      }
    }
  }
}

///|
test "association：两路持平恰 1 bit；倾斜则质量随双诚移动；非未定无分布" {
  let opens = all_opens()
  // 任取一个两路并存：两诚持平 → 熵恰 1 bit（完全并重）
  let mut checked = 0
  for entry in opens {
    match entry.2 {
      @sm.Open(cands) =>
        if cands.length() == 2 {
          checked += 1
          // 持平：β = 0.5/0.5，熵 1 bit
          let h_even = @evolution.association_entropy(
            @evolution.association_probs(70, 70, entry.2),
          )
          assert_true((h_even - 1.0).abs() < 0.000000001)
          // 他之诚更盛：质量移到空间侧（末条），熵 < 1
          let probs = @evolution.association_probs(40, 90, entry.2)
          assert_true(probs[1] > probs[0])
          let h_skew = @evolution.association_entropy(probs)
          assert_true(h_skew < 1.0)
          // 己之诚更盛：质量移到时间侧（首条）
          let probs2 = @evolution.association_probs(90, 40, entry.2)
          assert_true(probs2[0] > probs2[1])
        }
      _ => assert_true(false)
    }
  }
  assert_true(checked > 0)
  // 非未定：无分布、无歧义、一致性为 None
  let moved = @sm.step(@sm.Standing, @sm.Act) // 迁
  assert_true(@evolution.association_probs(70, 70, moved).length() == 0)
  assert_true(@evolution.association_entropy([]) == 0.0)
  match @evolution.association_consistent(70, 70, moved) {
    Some(_) => assert_true(false)
    None => ()
  }
}
