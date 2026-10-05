///|
/// 黑盒测试：群体机的执行契约层（0.1.27）。只经 `@group.` 公开 API。
///
/// 与主体机同纪律：回执如实，不替表挑去处；缺口如实说出口。

///|
test "step 给回执：迁与守" {
  // 共语 × 由传统立规：唯一出路，通向规训
  let moved = @group.step(@group.CommonTongue, @group.NormFromTradition)
  assert_true(moved.label() == "迁")
  match moved {
    @group.Moved(tr, to) => {
      assert_true(tr == @group.NormFromTradition)
      assert_true(to == @group.Normed)
    }
    _ => assert_true(false)
  }
  // 宁定 × 不再绝对化：静待下一刻，回到自身
  let held = @group.step(@group.Settled, @group.Settle)
  assert_true(held.label() == "守")
  match held.landing() {
    Some(at) => assert_true(at == @group.Settled)
    None => assert_true(false)
  }
}

///|
test "一句触发、两个去处：表里真的有一处，机器不替它挑" {
  let pairs = @group.open_pairs()
  assert_eq(pairs.length(), 1)
  let (s, k, to) = pairs[0]
  assert_true(s == @group.Converging)
  assert_true(k == @group.Attention)
  assert_eq(to.length(), 2)
  assert_true(to.contains(@group.CommonTongue) && to.contains(@group.Discourse))
  // 机器这一层仍然只给未定：裁决是上层递进来的偏向，不在表里。
  let raw = @group.step(@group.Converging, @group.Attention)
  assert_true(raw.label() == "未定")
  assert_true(raw.landing() == None)
  // 偏好在：共见取第一条（共语），共辩取最后一条（商谈）。两个去处都还在表里。
  let seen = @group.resolve_open(raw, @group.Supra, @group.Converging)
  assert_true(seen.label() == "迁")
  assert_true(seen.landing() == Some(@group.CommonTongue))
  let argued = @group.resolve_open(raw, @group.Inter, @group.Converging)
  assert_true(argued.label() == "迁")
  assert_true(argued.landing() == Some(@group.Discourse))
  // 缺省口径在「超体」——这是叙述口径，不是优先级：两侧同为常态震荡的两相。
  assert_true(@group.default_lean() == @group.Supra)
  assert_true(@group.Supra.label() == "超体")
  assert_true(@group.Inter.label() == "间体")
  // 表的震荡边不改变那处并列：仍只有一处「一句触发、两个去处」。
  assert_eq(@group.open_pairs().length(), 1)
  let out = @group.step(@group.Converging, @group.Attention)
  match out {
    @group.Open(tr, tos) => {
      assert_true(tr == @group.Attention)
      assert_eq(tos.length(), 2)
    }
    _ => assert_true(false)
  }
}

///|
/// 裁决器的反例侧。真表上只有一处 `Open`，所以「共见取第一条、共辩取最后一条」
/// 那两句若写反，表上仍会给出同一个落点（只有一个候选族）——判据分不出对错。
/// 这条用**造出来的**三条候选驱动：共见取头、共辩取尾，两者必须不同。
test "裁决按偏向取首／取尾（造三条候选才分得出）" {
  let three = @group.Open(@group.Attention, [
    @group.CommonTongue,
    @group.Normed,
    @group.Discourse,
  ])
  let seen = @group.resolve_open(three, @group.Supra, @group.Converging)
  assert_true(seen.landing() == Some(@group.CommonTongue))
  let argued = @group.resolve_open(three, @group.Inter, @group.Converging)
  assert_true(argued.landing() == Some(@group.Discourse))
  // 落点与当前位置相同就是「守」，不是「迁」——与 step 的读法一致。
  let held = @group.resolve_open(
    @group.Open(@group.Attention, [@group.Converging, @group.Discourse]),
    @group.Supra,
    @group.Converging,
  )
  assert_true(held.label() == "守")
  // 只有一个候选时不动它：并列不足两条就不裁决，原样回传。
  let single = @group.Open(@group.Attention, [@group.Discourse])
  assert_true(
    @group.resolve_open(single, @group.Supra, @group.Converging) == single,
  )
  // 非 Open 的回执原样透传，不被裁决器改写。
  let moved = @group.Moved(@group.Appear, @group.Scattered)
  assert_true(
    @group.resolve_open(moved, @group.Inter, @group.Converging) == moved,
  )
  let block = @group.Block("此处无此事")
  assert_true(
    @group.resolve_open(block, @group.Inter, @group.Converging) == block,
  )
}

///|
/// 成体内的震荡：超主体性与主体间性同为常态，两相之间**双向**可通，同一句触发
/// 既维持当前相位也可能换相。
test "成体震荡：两相之间双向可通，且自环仍在" {
  // 跨相：共语上冒出有效性主张 → 商谈
  let up = @group.step(@group.CommonTongue, @group.RaiseClaims)
  assert_true(up.label() == "迁")
  assert_true(up.landing() == Some(@group.Discourse))
  // 跨相：商谈里差异消弭、共同语言承担理解 → 共语
  let down = @group.step(@group.Discourse, @group.SharedMedium)
  assert_true(down.label() == "迁")
  assert_true(down.landing() == Some(@group.CommonTongue))
  // 自环（维持当前相位）仍在，且落在同侧
  assert_true(
    @group.step(@group.CommonTongue, @group.SharedMedium).landing() ==
    Some(@group.CommonTongue),
  )
  assert_true(
    @group.step(@group.Discourse, @group.RaiseClaims).landing() ==
    Some(@group.Discourse),
  )
  // 震荡闭合：一来一回能回到原处
  let there = @group.step(@group.CommonTongue, @group.RaiseClaims)
  match there.landing() {
    Some(g) => {
      let back = @group.step(g, @group.SharedMedium)
      assert_true(back.landing() == Some(@group.CommonTongue))
    }
    None => assert_true(false)
  }
  // 另一侧不封闭：两相都各有出边，不是死路
  assert_true(@group.no_dead_end())
}

///|
test "缺口：此处无此事，位置不动" {
  let out = @group.step(@group.Dispersed, @group.Agree)
  assert_true(out.label() == "无路")
  assert_true(out.landing() == None)
  assert_true(!@group.exitable(@group.Dispersed, @group.Agree))
}

///|
test "不封闭：20 个状态都有出边，没有走完即止的末态" {
  assert_true(@group.no_dead_end())
}

///|
/// 上面那条在真表上**恒真**，所以它分不出「检查在跑」与「检查恒真」：把
/// `no_dead_end` 改成 `if true { return true }`，真表照样通过。这条给
/// `no_dead_end_of` 一份**造出来的**清单——有位置不在出边清单里，那个 `false`
/// 只有真被跑过才会出现。
test "不封闭的检查在造的无出边位置上确实返回 false" {
  let states : Array[@group.GroupState] = [@group.Dispersed, @group.Converging]
  // 每个位置都有出边：不封闭
  let full : Array[@group.GroupState] = [@group.Dispersed, @group.Converging]
  assert_true(@group.no_dead_end_of(states, full))
  // 少一个位置的出边：那个位置成了末态
  let missing : Array[@group.GroupState] = [@group.Dispersed]
  assert_false(@group.no_dead_end_of(states, missing))
  // 出边落在表外：同样不封闭
  let outside : Array[@group.GroupState] = [@group.Settled]
  assert_false(@group.no_dead_end_of(states, outside))
  // 没有位置：空集平凡成立
  let no_states : Array[@group.GroupState] = []
  let no_froms : Array[@group.GroupState] = []
  assert_true(@group.no_dead_end_of(no_states, no_froms))
}

///|
test "凡点名的回执，那个状态的该触发恰有一条边（不编造）" {
  for s in @group.all_states() {
    let triggers : Array[@group.GroupTrigger] = []
    for t in @group.transitions() {
      if t.from == s {
        triggers.push(t.trigger)
      }
    }
    for k in triggers {
      let mut cands = 0
      for t in @group.transitions() {
        if t.from == s && t.trigger == k {
          cands += 1
        }
      }
      match @group.step(s, k) {
        @group.Moved(tr, _) => {
          assert_eq(cands, 1)
          assert_true(tr == k)
        }
        @group.Held(tr, _) => {
          assert_eq(cands, 1)
          assert_true(tr == k)
        }
        @group.Open(tr, tos) => {
          assert_eq(tos.length(), cands)
          assert_true(cands > 1)
          assert_true(tr == k)
        }
        @group.Block(_) => assert_eq(cands, 0)
      }
    }
  }
}

///|
test "每条边都走得出，且走得出的都能被 exitable 认出来" {
  for t in @group.transitions() {
    assert_true(@group.exitable(t.from, t.trigger))
  }
}

///|
test "walk：未定与无路之后位置不变" {
  let trace = @group.walk(@group.Converging, [@group.Attention, @group.Agree])
  assert_eq(trace.steps.length(), 2)
  assert_true(trace.steps[0].1.label() == "未定")
  assert_true(trace.steps[1].1.label() == "无路")
  assert_true(trace.at() == @group.Converging)
  let labels = trace.outcome_labels()
  assert_eq(labels[0], "未定")
  assert_eq(labels[1], "无路")
}

///|
test "walk：能走的路走得通，且与逐步 step 一致" {
  let trace = @group.walk(@group.initial(), [@group.Appear, @group.Attention])
  assert_true(trace.steps[0].1.label() == "迁")
  assert_true(trace.steps[1].1.label() == "未定")
  // 未定之后位置不变：仍在趋同（注意汇聚那一处两个去处）
  assert_true(trace.at() == @group.Converging)
}

///|
test "emerge 与 step 回答不同问题，互不替代" {
  // 分类函数：成员体制 + 主体状态 → 涌现态（9 行涌现表，与迁移表无关）
  let rows = @group.emergence_table()
  assert_eq(rows.length(), 9)
  let (_, st) = rows[0]
  assert_true(st == @group.Converging)
  let m = [@multi.subject(1, @sm.Standing, @multi.ChengRan, 1, 9, 5)]
  assert_true(@group.is_well_formed(st, m))
  // 执行契约：表上的投影（44 条边，与成员配置无关）
  let out = @group.step(@group.Converging, @group.Attention)
  assert_true(out.label() == "未定")
  assert_eq(@group.transitions().length(), 44)
}
