///|
/// 黑盒测试：社会机的执行契约层（0.1.27）。只经 `@society.` 公开 API。

///|
test "step 给回执：迁与守" {
  // 生活世界 × 语言在言说我们 → 超主体性
  let moved = @society.step(@society.World, @society.SpeakLanguage)
  assert_true(moved.label() == "迁")
  match moved {
    @society.Moved(tr, to) => {
      assert_true(tr == @society.SpeakLanguage)
      assert_true(to == @society.Suprasubjective)
    }
    _ => assert_true(false)
  }
  // 商谈 × 洗衣机过滤：位置不变
  let held = @society.step(@society.Discourse, @society.Filter)
  assert_true(held.label() == "守")
  match held.landing() {
    Some(at) => assert_true(at == @society.Discourse)
    None => assert_true(false)
  }
}

///|
/// 这张表在触发粒度上确定：同一状态的同一触发只出现一次，故回执只有三种。
/// `Open` 那条臂备而不用——哪天出现一句触发两个去处，这条断言会红，而机器会
/// 如实并列而不是替表挑一个。
test "社会机的表在触发粒度上确定：open_pairs 为空" {
  assert_true(@society.one_edge_per_trigger())
  assert_eq(@society.open_pairs().length(), 0)
}

///|
/// 上面那条 `one_edge_per_trigger` 在真表上**恒真**（这句触发、两个去处那条臂在
/// 真表上不可达），所以它分不出「检查在跑」与「检查恒真」：把那条 `return false`
/// 换成空语句，真表结果一点不变。这条给 `one_edge_each` 一份**造出来的**清单，
/// 那个 `false` 只有真被跑过才会出现。
test "触发粒度的确定性在造的重复对上确实返回 false" {
  let clean : Array[(@society.State, @society.Trigger)] = [
    (@society.World, @society.SpeakLanguage),
    (@society.Colony, @society.RaiseClaims),
    (@society.Colony, @society.Filter),
  ]
  assert_true(@society.one_edge_each(clean))
  // 同一位置同一句：歧义
  let same_pair : Array[(@society.State, @society.Trigger)] = [
    (@society.Colony, @society.Filter),
    (@society.Colony, @society.Filter),
  ]
  assert_false(@society.one_edge_each(same_pair))
  // 同一位置不同句：合法，不该误报
  let two_from : Array[(@society.State, @society.Trigger)] = [
    (@society.Colony, @society.RaiseClaims),
    (@society.Colony, @society.Filter),
  ]
  assert_true(@society.one_edge_each(two_from))
  // 同一句不同位置：也合法
  let two_to : Array[(@society.State, @society.Trigger)] = [
    (@society.World, @society.SpeakLanguage),
    (@society.Colony, @society.SpeakLanguage),
  ]
  assert_true(@society.one_edge_each(two_to))
  // 空清单：平凡成立
  let empty : Array[(@society.State, @society.Trigger)] = []
  assert_true(@society.one_edge_each(empty))
}

///|
/// 「本表触发粒度确定」那条断言在真表上**恒真**（真表本来就没有一句触发两个去处），
/// 所以它分不出「检查在跑」与「检查恒返回空」——后者是**等价变异**，真表结果不变。
/// 这条给 `ambiguous` 一份**造出来的**清单：一个去处、两个、三个，那条边界才验得住。
test "并列判定在造的多去处清单上确实返回 true" {
  // 一个去处：确定，不并列
  assert_false(@society.ambiguous([@society.Colony]))
  // 两个去处：并列
  assert_true(@society.ambiguous([@society.Colony, @society.Discourse]))
  // 三个去处：仍是并列（不是恰好两条才算）
  assert_true(
    @society.ambiguous([@society.Colony, @society.Discourse, @society.Norm]),
  )
  // 空清单：无处可去，不并列
  let none : Array[@society.State] = []
  assert_false(@society.ambiguous(none))
  // 真表侧每个触发都只有一个去处——所以真表那条断言恒真，不是这条
  for t in @society.transitions() {
    assert_false(@society.ambiguous([t.to]))
  }
}

///|
/// `no_dead_end` 同理：真表上恒真，所以判据得落在纯函数上，用造出来的
/// 「有位置没有出边」验那条 `false`。
test "不封闭的检查在造的无出边位置上确实返回 false" {
  let states : Array[@society.State] = [@society.World, @society.Colony]
  let full : Array[@society.State] = [@society.World, @society.Colony]
  assert_true(@society.no_dead_end_of(states, full))
  let missing : Array[@society.State] = [@society.World]
  assert_false(@society.no_dead_end_of(states, missing))
  let outside : Array[@society.State] = [@society.Suprasubjective]
  assert_false(@society.no_dead_end_of(states, outside))
  let no_states : Array[@society.State] = []
  let no_froms : Array[@society.State] = []
  assert_true(@society.no_dead_end_of(no_states, no_froms))
}

///|
/// `no_final_closure` 有**两条** `return false` 臂：出现终态、某个位置到不了缺口。
/// 真表上两条都不可达，所以只看真表的判据分不出「检查在跑」与「检查恒真」。这条
/// 给纯函数**造出来的**三份清单，把两条臂各验一次。
test "不封闭的判别在造的终态与到不了的缺口上确实返回 false" {
  let states = @society.all_states()
  assert_true(states.length() > 2)
  let all = states
  let no_terminal : Array[@society.State] = []
  // 无终态、处处到得了缺口：成立
  assert_true(@society.no_final_closure_of(all, no_terminal, all))
  // 造一个终态：第一条臂
  let with_terminal : Array[@society.State] = [all[0]]
  assert_false(@society.no_final_closure_of(all, with_terminal, all))
  // 缺口只到一处：第二条臂（某个共识被彻底封口）
  let one_gap : Array[@society.State] = [all[0]]
  assert_false(@society.no_final_closure_of(all, no_terminal, one_gap))
  // 缺口清单落在表外：同样封口
  let no_gap : Array[@society.State] = []
  assert_false(@society.no_final_closure_of(all, no_terminal, no_gap))
  // 没有位置：空集平凡成立
  let none : Array[@society.State] = []
  assert_true(@society.no_final_closure_of(none, none, none))
}

///|
test "缺口：此处无此事，位置不动" {
  let out = @society.step(@society.Colony, @society.Justify)
  assert_true(out.label() == "无路")
  assert_true(out.landing() == None)
  assert_true(!@society.exitable(@society.Colony, @society.Justify))
}

///|
test "不封闭：13 个状态都有出边" {
  assert_true(@society.no_dead_end())
}

///|
test "凡点名的回执，那个状态的该触发恰有一条边（不编造）" {
  for s in @society.all_states() {
    let triggers : Array[@society.Trigger] = []
    for t in @society.transitions() {
      if t.from == s {
        triggers.push(t.trigger)
      }
    }
    for k in triggers {
      let mut cands = 0
      for t in @society.transitions() {
        if t.from == s && t.trigger == k {
          cands += 1
        }
      }
      match @society.step(s, k) {
        @society.Moved(tr, _) => {
          assert_eq(cands, 1)
          assert_true(tr == k)
        }
        @society.Held(tr, _) => {
          assert_eq(cands, 1)
          assert_true(tr == k)
        }
        @society.Open(tr, tos) => {
          assert_eq(tos.length(), cands)
          assert_true(cands > 1)
          assert_true(tr == k)
        }
        @society.Block(_) => assert_eq(cands, 0)
      }
    }
  }
}

///|
test "每条边都走得出" {
  for t in @society.transitions() {
    assert_true(@society.exitable(t.from, t.trigger))
  }
}

///|
test "walk：缺口之后位置不变；走通的路到得了" {
  let blocked = @society.walk(@society.World, [@society.Justify])
  assert_eq(blocked.steps.length(), 1)
  assert_true(blocked.steps[0].1.label() == "无路")
  assert_true(blocked.at() == @society.World)
  // 一条真路：生活世界 →（语言）→ 超主体性 →（需第三者）→ 缺口
  let ok = @society.walk(@society.World, [
    @society.SpeakLanguage,
    @society.DemandThird,
  ])
  assert_true(ok.steps[0].1.label() == "迁")
  assert_true(ok.steps[1].1.label() == "迁")
  assert_true(ok.at() == @society.Gap)
  let labels = ok.outcome_labels()
  assert_eq(labels.length(), 2)
}

///|
test "不封闭的那条重入边在执行契约下也走得通" {
  // 复建 × 循环过程取代对立关系 → 回到生活世界：不是走完即止
  let out = @society.step(@society.Reconstruction, @society.Circulate)
  match out.landing() {
    Some(at) => assert_true(at == @society.World)
    None => assert_true(false)
  }
  assert_true(@society.no_final_closure())
}
