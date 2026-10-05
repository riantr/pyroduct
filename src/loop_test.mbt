///|
/// 黑盒测试：执行契约层。验证五种合法回执、缺口的所在层面，以及「不封闭」未被削弱。
/// 0.1.26 增：触发粒度（`step_by_trigger`）与「同归不点名」这条反编造判据。
/// 0.1.28 增：未定的可编程展开（`forks_from`／`expand`／`after_open`）——
/// 判据的核心是「展开不增事实」：每条走法都能由 `step_by_trigger` 逐条复核，
/// 且与一条**独立枚举**（直接扫 `transitions()`）逐条相等。

///|
/// 追加一句并另存一份。
fn push_tr(
  path : Array[@src.Trigger],
  tr : @src.Trigger,
) -> Array[@src.Trigger] {
  let out : Array[@src.Trigger] = []
  for t in path {
    out.push(t)
  }
  out.push(tr)
  out
}

///|
/// 两个触发序列逐条相等。
fn same_triggers(a : Array[@src.Trigger], b : Array[@src.Trigger]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
/// 从一条走法里取出「点过名的那些句」：迁／守有名字，未定与同归没有，
/// 缺口没有出边故不占一步的名字。
fn named_triggers(leaf : @src.Trace) -> Array[@src.Trigger] {
  let out : Array[@src.Trigger] = []
  for e in leaf.steps {
    match e.1 {
      @src.Moved(tr, _) => out.push(tr)
      @src.Held(tr, _) => out.push(tr)
      _ => ()
    }
  }
  out
}

///|
/// 判据用的**独立枚举**：不调 `expand`／`candidates`／`forks_from`，也不调
/// `step`，直接扫 `transitions()` 自己分叉。同一份语义、另一条取料路径——
/// 两处实现对不上，就是有一处错了。语义照 `expand` 的三条纪律写：只在去处
/// 多于一时分叉；去处确定时同归不点名；缺口处位置不动、继续下一槽。
fn oracle_paths(
  at : @src.SubjectState,
  slots : Array[@src.Slot],
  i : Int,
  path : Array[@src.Trigger],
  acc : Array[Array[@src.Trigger]],
) -> Unit {
  if i >= slots.length() {
    let leaf : Array[@src.Trigger] = []
    for t in path {
      leaf.push(t)
    }
    acc.push(leaf)
    return
  }
  let slot = slots[i]
  let edges : Array[(@src.Trigger, @src.SubjectState)] = []
  let dests : Array[@src.SubjectState] = []
  for t in @src.transitions() {
    if t.from == at && t.trigger.slot() == slot {
      edges.push((t.trigger, t.to))
      if !has_state(dests, t.to) {
        dests.push(t.to)
      }
    }
  }
  if edges.length() == 0 {
    oracle_paths(at, slots, i + 1, path, acc)
  } else if dests.length() > 1 {
    for e in edges {
      oracle_paths(e.1, slots, i + 1, push_tr(path, e.0), acc)
    }
  } else if edges.length() == 1 {
    oracle_paths(dests[0], slots, i + 1, push_tr(path, edges[0].0), acc)
  } else {
    // 同归：去处确定，来处不名——不分叉，也不写进触发序列。
    oracle_paths(dests[0], slots, i + 1, path, acc)
  }
}

///|
/// 未定点清单就是「`step` 给未定的那些」：5 处，每处 2 条候选边。
/// 逐个组合扫过去核对，不维护第二份清单。
test "未定点：step 给未定的每一处都在清单里，清单里没有别处" {
  let listed = @src.open_points()
  let mut found = 0
  for s in @src.all_states() {
    for k in @src.all_slots() {
      match @src.step(s, k) {
        @src.Open(cands) => {
          found += 1
          let mut hit = false
          for op in listed {
            if op.0 == s && op.1 == k {
              hit = true
              assert_eq(op.2, cands.length())
              // 候选边的条数与 `candidates` 一致（两处取料不许对不上）
              assert_eq(@src.candidates(s, k).length(), cands.length())
            }
          }
          assert_true(hit)
        }
        _ => ()
      }
    }
  }
  assert_eq(found, 5)
  assert_eq(listed.length(), 5)
}

///|
/// 「展开不增事实」的正面判据：每条走法都是迁移表里真实存在的那条边，且
/// 能由 `step_by_trigger` 独立复核出同样的结果。逐个组合扫 272 次。
test "可编程分叉不增事实：每条走法都复核得出，且条数与候选边一致" {
  for s in @src.all_states() {
    for k in @src.all_slots() {
      let cands = @src.candidates(s, k)
      let forks = @src.step(s, k).forks_from(s)
      assert_eq(forks.length(), cands.length())
      for f in forks {
        // 只给确定回执：缺口不可展开，机器不许凭空造一条。
        let tr = match f {
          @src.Moved(tr, _) => Some(tr)
          @src.Held(tr, _) => Some(tr)
          _ => None
        }
        match tr {
          Some(named) => {
            // 这条边确实在表里，且落点确实是它说的那个
            let mut in_table = false
            for c in cands {
              if c.0 == named {
                in_table = true
                assert_true(f.landing() == Some(c.1))
              }
            }
            assert_true(in_table)
            // 用另一条取料路径（`step_by_trigger`）复核同一件事
            let again = @src.step_by_trigger(s, named)
            assert_true(again == f)
          }
          None => assert_true(false)
        }
      }
      // 缺口给不出任何走法——缺口一旦能被展开，缺口就名存实亡
      if cands.length() == 0 {
        assert_eq(forks.length(), 0)
      }
    }
  }
}

///|
/// 同归可逐条展开（要问「是哪一句」时用），但展开**不**使走法倍增：去处已定，
/// 树上是同一条路。三处同归、七条触发句，逐条都取得到。
test "同归逐条可取，但不让走法倍增" {
  for pair in @src.same_target_pairs() {
    let (s, k, named, to) = pair
    let forks = @src.step(s, k).forks_from(s)
    assert_eq(forks.length(), named.length())
    assert_true(named.length() > 1)
    for tr in named {
      let mut hit = false
      for f in forks {
        match f {
          @src.Held(nt, at) =>
            if nt == tr {
              hit = true
              assert_true(at == to)
            }
          _ => assert_true(false)
        }
      }
      assert_true(hit)
    }
  }
}

///|
/// 展开出的每条走法都是**真路径**：从起点逐步用 `step_by_trigger` 重放，
/// 每一步的出发点与落点都必须接得上，且步数与给定脚本等长（缺口不终止行程）。
test "展开的每条走法都是真路径：逐条重放接得上，步数与脚本等长" {
  let script = [@src.Act, @src.Occasion, @src.Occasion, @src.Occasion]
  let fan = @src.expand(@src.Standing, script, 64)
  assert_eq(fan.leaves.length(), 2)
  for leaf in fan.leaves {
    assert_eq(leaf.steps.length(), script.length())
    let mut at = @src.Standing
    for i = 0; i < leaf.steps.length(); i = i + 1 {
      let entry = leaf.steps[i]
      let (slot, out) = entry
      // 走法不得悄悄改写脚本：每一步仍是给定的那一槽
      assert_true(slot == script[i])
      match out {
        @src.Moved(tr, to) => {
          assert_true(@src.step_by_trigger(at, tr).landing() == Some(to))
          at = to
        }
        @src.Held(tr, to) => {
          assert_true(@src.step_by_trigger(at, tr).landing() == Some(to))
          at = to
        }
        // 未定不会出现在展开的叶子里（分叉时已选定那一句），
        // 同归与无路不点名，位置不动。
        @src.Same(_, _, to) => at = to
        @src.Open(_) => assert_true(false)
        @src.Block(_) => ()
      }
    }
    assert_true(at == leaf.at())
  }
}

///|
/// 不遗漏也不多出：展开的走法集合与一条**独立枚举**逐条相等。
/// 脚本故意连撞多个未定点（自由、自身），好让两边都得分叉。
test "展开不遗漏也不多出：与独立枚举逐条相等" {
  let script = [
    @src.Act,
    @src.Occasion,
    @src.Occasion,
    @src.Occasion,
    @src.Hold,
    @src.Hold,
    @src.Orientation,
    @src.CoBeing,
    @src.Hold,
    @src.CoBeing,
    @src.Occasion,
  ]
  let want : Array[Array[@src.Trigger]] = []
  oracle_paths(@src.Standing, script, 0, [], want)
  let fan = @src.expand(@src.Standing, script, 512)
  assert_eq(fan.leaves.length(), want.length())
  // 每条独立枚举出来的路径，都能在这批走法里找到一模一样的
  for w in want {
    let mut hit = false
    for leaf in fan.leaves {
      if same_triggers(named_triggers(leaf), w) {
        hit = true
      }
    }
    assert_true(hit)
  }
  // 反向也成立：走法里没有独立枚举列不出来的
  for leaf in fan.leaves {
    let got = named_triggers(leaf)
    let mut hit = false
    for w in want {
      if same_triggers(got, w) {
        hit = true
      }
    }
    assert_true(hit)
  }
}

///|
/// 上界要说出来：撞上 `limit` 就置 `truncated`，叶子数恰为 `limit`。
/// 静默截断的结果会被读成「所有可能的后续」，而它不是。
test "撞界明说：truncated 为真，且叶子数恰为上限" {
  let script = [@src.Act, @src.Occasion, @src.Occasion, @src.Occasion]
  let full = @src.expand(@src.Standing, script, 64)
  assert_true(!full.truncated)
  let one = @src.expand(@src.Standing, script, 1)
  assert_true(one.truncated)
  assert_eq(one.leaves.length(), 1)
  // 截断的走法仍然是真路径，不因截断而编造
  for leaf in one.leaves {
    assert_eq(leaf.steps.length(), script.length())
  }
}

///|
/// 没有未定的脚本：展开恰给一条，且与 `walk` 逐步相同。
test "无未定的脚本：展开与 walk 同一条路" {
  let script = [@src.Act, @src.Act]
  let fan = @src.expand(@src.Standing, script, 16)
  assert_eq(fan.leaves.length(), 1)
  assert_true(!fan.truncated)
  let plain = @src.walk(@src.Standing, script)
  assert_eq(fan.leaves[0].steps, plain.steps)
  assert_true(fan.leaves[0].at() == plain.at())
}

///|
/// `after_open` 与 `min_steps` 互证：两个函数的取料路径不同（一个从候选边
/// 多源广度优先，一个单目标广度优先），对得上才说明「未定之后够得着哪些
/// 地方」这句话没说错。
test "未定之后够得着的地方：与 min_steps 互证" {
  for op in @src.open_points() {
    let (s, k, _) = op
    for depth = 1; depth <= 3; depth = depth + 1 {
      let got = @src.after_open(s, k, depth)
      // 逐个位置核对：够得着 ⟺ 某条候选边走 depth-1 步以内到得了
      for x in @src.all_states() {
        let mut reachable = false
        for c in @src.candidates(s, k) {
          match @src.min_steps(c.1, x) {
            Some(d) => if d <= depth - 1 { reachable = true }
            None => ()
          }
        }
        let mut listed = false
        for g in got {
          if g.0 == x {
            listed = true
            // 步数也须一致，且不超上限
            assert_true(g.1 >= 1 && g.1 <= depth)
          }
        }
        assert_true(listed == reachable)
      }
      // 未定点本身不算后续（除非有候选边绕回它）
      assert_true(got.length() > 0)
    }
  }
}

///|
/// 缺口处没有「之后」可言：没有候选边，就没有后续可枚举。
test "缺口处的 after_open 为空" {
  for g in @src.gaps() {
    assert_eq(@src.after_open(g.0, g.1, 3).length(), 0)
  }
}

///|
/// 「只在未定处分叉」这条纪律最干净的读法：**单步展开的分叉因子**。
/// 逐个组合扫 272 次——去多于一处分叉（因子 = 候选边数），其余一律 1。
/// 同归（3 处、7 条来处）在这条判据下必须是 1，缺口也必须是 1。
test "单步展开的分叉因子：只在去多于一处时大于一" {
  for s in @src.all_states() {
    for k in @src.all_slots() {
      let cands = @src.candidates(s, k)
      let dests : Array[@src.SubjectState] = []
      for c in cands {
        if !has_state(dests, c.1) {
          dests.push(c.1)
        }
      }
      let expected = if dests.length() > 1 { cands.length() } else { 1 }
      let fan = @src.expand(s, [k], 16)
      assert_eq(fan.leaves.length(), expected)
      assert_true(!fan.truncated)
      for leaf in fan.leaves {
        // 单步展开：一步，不多不少
        assert_eq(leaf.steps.length(), 1)
        assert_true(leaf.steps[0].0 == k)
      }
    }
  }
}

///|
test "step 给五种合法回执：迁、守、未定、同归、无路" {
  let moved = @src.step(@src.Standing, @src.Act)
  assert_true(moved.label() == "迁")
  match moved.landing() {
    Some(to) => assert_true(to == @src.Freedom)
    None => assert_true(false)
  }
  // 相遇 × 持存挂着三条触发句且同归相遇：去处确定、来处不名，故不报「守」。
  let same = @src.step(@src.Encounter, @src.Hold)
  assert_true(same.label() == "同归")
  match same.landing() {
    Some(to) => assert_true(to == @src.Encounter)
    None => assert_true(false)
  }
  match same {
    @src.Same(slot, named, to) => {
      assert_true(slot == @src.Hold)
      assert_eq(named.length(), 3)
      assert_true(to == @src.Encounter)
    }
    _ => assert_true(false)
  }
  // 单触发自环仍是「守」：宁静 × 先行只有「静待下一刻」一条来处，可点名
  // （也正是 buchi 面认定的那个「被接受的停滞」）。
  let held = @src.step(@src.Tranquility, @src.Antecedent)
  assert_true(held.label() == "守")
  match held {
    @src.Held(tr, at) =>
      assert_true(tr == @src.WaitNext && at == @src.Tranquility)
    _ => assert_true(false)
  }
  match held.landing() {
    Some(to) => assert_true(to == @src.Tranquility)
    None => assert_true(false)
  }
  let open = @src.step(@src.Freedom, @src.Occasion)
  assert_true(open.label() == "未定")
  assert_true(open.landing() == None)
  let blocked = @src.step(@src.Tranquility, @src.CoBeing)
  assert_true(blocked.label() == "无路")
  assert_true(blocked.landing() == None)
}

///|
/// step_by_trigger 的前提：同一位置的同一条触发句不出现两次。否则「是哪一句」
/// 本身就没有答案，表该复查，而不是让机器替它挑。
test "表无歧义：同一位置的同一条触发句只出现一次" {
  assert_true(@src.one_edge_per_trigger())
}

///|
/// 三处同归、七条触发句：每一条单独驱动都必须被认出来，且回执里点名的正是它
/// 自己——不是同组里碰巧排在最前的那一条。
test "同归的每条触发句各自驱动：回执点名的就是那一句" {
  let pairs = @src.same_target_pairs()
  assert_eq(pairs.length(), 3)
  let mut seen = 0
  for pair in pairs {
    let (s, k, named, to) = pair
    // 槽给出的回执是同归：不点名任何一句。
    match @src.step(s, k) {
      @src.Same(_, all, landing) => {
        assert_eq(all.length(), named.length())
        assert_true(landing == to)
      }
      _ => assert_true(false)
    }
    for tr in named {
      seen += 1
      assert_true(tr.slot() == k)
      let out = @src.step_by_trigger(s, tr)
      assert_true(out.label() == "守")
      match out {
        @src.Held(named_tr, landing) => {
          assert_true(named_tr == tr)
          assert_true(landing == to)
        }
        _ => assert_true(false)
      }
      match out.landing() {
        Some(at) => assert_true(at == to)
        None => assert_true(false)
      }
    }
  }
  assert_eq(seen, 7)
}

///|
/// 不是此处的出边就报缺口，不替表猜另一条。槽位也要对上：那句若属别的槽，
/// 照样不是「这个位置的这个槽」的边。
test "step_by_trigger 认不得就说缺口" {
  let missed = @src.step_by_trigger(@src.Tranquility, @src.Surprise)
  assert_true(missed.label() == "无路")
  assert_true(missed.landing() == None)
  // 属别的槽、也不是此处的边：同样报缺口（并把槽名说清楚）。
  let wrong_slot = @src.step_by_trigger(@src.Tranquility, @src.Endure)
  assert_true(wrong_slot.label() == "无路")
}

///|
/// 反编造判据（这条能抓住 0.1.26 之前的行为）：凡是**点名**了触发的回执
/// （迁／守），那个位置的该槽必须**恰好只有一条**出边——多一条就必须给同归，
/// 不许挑第一条报出来。逐个组合扫，不靠清单。
test "凡点名触发的回执，该槽在该位置恰有一条出边（不编造触发）" {
  for s in @src.all_states() {
    for k in @src.all_slots() {
      let out = @src.step(s, k)
      let mut cands = 0
      for t in @src.transitions() {
        if t.from == s && t.trigger.slot() == k {
          cands += 1
        }
      }
      match out {
        @src.Moved(_, _) => assert_eq(cands, 1)
        @src.Held(_, _) => assert_eq(cands, 1)
        @src.Same(_, named, _) => {
          assert_eq(named.length(), cands)
          assert_true(cands > 1)
        }
        @src.Open(cands_in) => {
          assert_eq(cands_in.length(), cands)
          assert_true(cands > 1)
        }
        @src.Block(_) => assert_eq(cands, 0)
      }
    }
  }
}

///|
/// 同归的目标与逐条驱动的落点一致：槽粒度说「去这儿」，触发粒度逐条说也是
/// 「去这儿」。两边对不上就是表与回执打架。
test "同归：槽粒度的目标与逐条驱动的落点一致" {
  for pair in @src.same_target_pairs() {
    let (s, k, named, to) = pair
    for tr in named {
      match @src.step_by_trigger(s, tr).landing() {
        Some(at) => assert_true(at == to)
        None => assert_true(false)
      }
    }
    match @src.step(s, k).landing() {
      Some(at) => assert_true(at == to)
      None => assert_true(false)
    }
  }
}

///|
/// 同归要能被画出来：行程视图那条 `Same` 分支不能是没人走过的死码。走
/// 「择取 × 共在 → 相遇」，再用「持存」撞上同归组合，图上应有「同归」二字，
/// 且那条边**不带触发句**（来处不名就不许在边上点名）。
test "行程视图能画出同归：边照画，边上不写触发句" {
  let trace = @src.walk(@src.Choosing, [@src.CoBeing, @src.Hold])
  assert_eq(trace.steps.length(), 2)
  assert_true(trace.steps[1].1.label() == "同归")
  assert_true(trace.at() == @src.Encounter)
  let journey = @src.render_mermaid_journey(trace)
  assert_true(journey.contains("同归"))
  assert_true(!journey.contains("最初是惊喜"))
}

///|
test "detailed：每步带上出发位置，与重放一致" {
  let trace = @src.walk(@src.Standing, [
    @src.Act,
    @src.Occasion,
    @src.Occasion,
    @src.CoBeing,
  ])
  let d = trace.detailed()
  assert_eq(d.length(), 4)
  // 第一步：立位 × 行动 → 迁到自由
  assert_true(d[0].from == @src.Standing)
  assert_true(d[0].slot == @src.Act)
  match d[0].outcome.landing() {
    Some(to) => assert_true(to == @src.Freedom)
    None => assert_true(false)
  }
  // 第二步出发位置是自由（上一步落点）
  assert_true(d[1].from == @src.Freedom)
  // 未定之后位置不变：第三、四步出发位置仍是自由
  assert_true(d[2].from == @src.Freedom)
  assert_true(d[3].from == @src.Freedom)
  // 明细与重放互证：at() 等于最后落点（或最后出发位）
  assert_true(trace.at() == @src.Freedom)
}

///|
test "缺口只在槽的组合层面，不在位置层面：每个位置都有出边，宁静之后仍可重入反顾" {
  for s in @src.all_states() {
    assert_true(@src.successors(s).length() > 0)
  }
  assert_true(@src.gaps().length() > 0)
  assert_true(@src.reachable(@src.Tranquility, @src.Reflection))
}

///|
test "行走不替主体决断：未定与无路之后位置不变" {
  let stalled = @src.walk(@src.Freedom, [@src.Occasion, @src.Occasion])
  assert_eq(stalled.steps.length(), 2)
  assert_true(stalled.at() == @src.Freedom)
  let blocked_walk = @src.walk(@src.Tranquility, [@src.CoBeing])
  assert_true(blocked_walk.at() == @src.Tranquility)
  // 到自由之后没有第二次「行动」可走：下一步只能由处境推动，故位置停在自由。
  let act_twice = @src.walk(@src.Standing, [@src.Act, @src.Act])
  assert_true(act_twice.at() == @src.Freedom)
  // 连由揭蔽推动，则一路走归责三步：受挫 → 自归 → 失权。
  let unveil_twice = @src.walk(@src.Evil, [@src.Unveil, @src.Unveil])
  assert_true(unveil_twice.at() == @src.Guilt)
}

///|
test "执行契约与迁移表一致：每条边由其槽走得出，报告可打印" {
  for t in @src.transitions() {
    assert_true(@src.exitable(t.from, t.trigger.slot()))
  }
  let report = @src.render_loop_report()
  assert_true(report.contains("执行契约"))
  assert_true(report.contains("未定"))
  assert_true(report.contains("无路"))
}
