///|
/// 黑盒测试：规格往返（0.1.28 新增）。
///
/// `spec.mbt` 明说「不做反向构造」——那是**库**的立场：反向构造会在产品里
/// 留下第二事实源，违背数据即代码。本文件照这个立场办：反向构造只发生在
/// **测试里**，从 `spec_json()` 那一串字符出发把机器重建出来，再逐字段与
/// 真表比对。测试里多一份重建，恰好是「规格没有丢信息」的证据；库里不多
/// 一份重建，恰好是「只有一个事实源」的证据。两边都不牺牲。
///
/// 判据三层，逐层加严：
/// 1. **重建是单射的**：状态定名、阶段定名、槽定名、触发原文措辞各自互异
///    ——否则规格有损，重建只是在挑一条；
/// 2. **逐字段相等**：状态（id／原文名／阶段，按序）、阶段（成员按序）、
///    槽、迁移（from／event／target／slot）全部与真表一致；
/// 3. **行为相等**：拿重建出来的表在本地重算 272 个（位置, 槽）组合的回执，
///    与 `@src.step` 的回执类别与落点逐一相等。字段相等有可能是因为两处都
///    取自同一份源；行为相等才说明规格真能独立驱动一台机器。
///
/// 读取器只认本文档的一种排版：每个数组元素独占一行，键值形如 `"k": "v"`。
/// 故按行扫描、按 `"` 切分即可，不必引 JSON 库（`src` 零 import 纪律维持）。
/// 这是**刻意的脆弱**——规格若改了排版，读取器与计数判据一并报错，不会
/// 静默读出半份规格。逐行的切分还顺带说明了为什么不能用 `String` 的字符
/// 下标：`s[i]` 取出的字符 `to_string()` 给的是十进制码而非字符本身，
/// 拼出来的会是数字串。

///|
/// 一行里全部的 `"键": "值"` 对（按出现顺序）。
///
/// 注意配对的位次：按 `"` 切分后，**键和值都落在奇数位**上（一个键值对贡献
/// 两个字符串字面量），中间隔着 `: `。故键在 1、值在 3，下一对在 5、7。
fn line_fields(line : String) -> Array[(String, String)] {
  let parts = line.split("\"").collect()
  let out : Array[(String, String)] = []
  let mut i = 1
  while i + 2 < parts.length() {
    out.push((parts[i].to_owned(), parts[i + 2].to_owned()))
    i += 4
  }
  out
}

///|
/// `"slots": [...]` 里的八个槽名。引号切分后：0 是缩进、1 是键名 `slots`、
/// 2 是 `: [`，槽名从 3 开始落在奇数位上，末位是 `],`。
fn slot_names(line : String) -> Array[String] {
  let parts = line.split("\"").collect()
  let out : Array[String] = []
  let mut i = 3
  while i < parts.length() {
    out.push(parts[i].to_owned())
    i += 2
  }
  out
}

///|
/// 一行里某个键的值；没有就返回空串（调用方据此判断这行是什么）。
fn field_of(line : String, key : String) -> String {
  for pair in line_fields(line) {
    if pair.0 == key {
      return pair.1
    }
  }
  ""
}

///|
/// 文档级字段（`$schema`／`name`／`initial`…）。逐行找含该键的那一行再取值——
/// 不能对整篇文档直接切分：字符串数组会破坏键与值的奇偶交替。
fn doc_field(spec : String, key : String) -> String {
  let needle = "\"" + key + "\": "
  for line in spec.split("\n").collect() {
    let text = line.to_owned()
    if text.contains(needle) {
      return field_of(text, key)
    }
  }
  ""
}

///|
/// `"members": ["a", "b"]` 的成员。键名落在奇数位上，第一个成员在它之后两位。
fn members_of(line : String) -> Array[String] {
  let parts = line.split("\"").collect()
  let out : Array[String] = []
  let mut i = 1
  while i < parts.length() {
    if parts[i].to_owned() == "members" {
      let mut k = i + 2
      while k < parts.length() {
        out.push(parts[k].to_owned())
        k += 2
      }
      return out
    }
    i += 2
  }
  out
}

///|
/// 按定名找回位置；找不到就如实报 `None`（规格里出现了表上没有的位置，
/// 那是规格的错，不是调用方的错）。
fn rt_state(name : String) -> @src.SubjectState? {
  for s in @src.all_states() {
    if s.designation() == name {
      return Some(s)
    }
  }
  None
}

///|
fn rt_phase(name : String) -> @src.Phase? {
  for p in @src.all_phases() {
    if p.designation() == name {
      return Some(p)
    }
  }
  None
}

///|
fn rt_slot(name : String) -> @src.Slot? {
  for k in @src.all_slots() {
    if k.designation() == name {
      return Some(k)
    }
  }
  None
}

///|
/// 按**原文措辞**找回触发（规格里 `event` 存的就是措辞，不是定名）。
fn rt_trigger(label : String) -> @src.Trigger? {
  for t in @src.all_triggers() {
    if t.label() == label {
      return Some(t)
    }
  }
  None
}

///|
/// 重建出来的一条迁移。
struct RtEdge {
  from : @src.SubjectState
  trigger : @src.Trigger
  to : @src.SubjectState
} derive(Eq, Debug)

///|
/// 从规格的迁移行重建整张表。任一条读不出对应物就当场 `panic`——规格里有
/// 真表没有的边，是规格的错，不该被静默跳过。
fn rt_table(spec : String) -> Array[RtEdge] {
  let out : Array[RtEdge] = []
  for line in spec.split("\n").collect() {
    let text = line.to_owned()
    if !text.contains("\"from\": ") {
      continue
    }
    let from = match rt_state(field_of(text, "from")) {
      Some(s) => s
      None => panic()
    }
    let trigger = match rt_trigger(field_of(text, "event")) {
      Some(t) => t
      None => panic()
    }
    let to = match rt_state(field_of(text, "target")) {
      Some(s) => s
      None => panic()
    }
    // 规格里的槽是**模型整理**的那一列，重建后必须与触发自身的归位一致——
    // 这两列在真表里同源，规格把它们并排放出来，漂移就会在这里露出来。
    let slot = match rt_slot(field_of(text, "slot")) {
      Some(k) => k
      None => panic()
    }
    if trigger.slot() != slot {
      panic()
    }
    out.push({ from, trigger, to, })
  }
  out
}

///|
/// 拿重建出来的表在本地重算回执（回执规则照 `src/loop.mbt` 的定义重写一遍：
/// 零候选给无路；多候选同归一处给同归；多候选去处不同给未定；唯一候选落回
/// 自身给守，否则给迁）。返回（回执名，落点定名；未定／无路无落点故为空）。
fn rt_step(
  table : Array[RtEdge],
  state : @src.SubjectState,
  slot : @src.Slot,
) -> (String, String) {
  let cands : Array[(@src.Trigger, @src.SubjectState)] = []
  for e in table {
    if e.from == state && e.trigger.slot() == slot {
      cands.push((e.trigger, e.to))
    }
  }
  if cands.length() == 0 {
    return ("无路", "")
  }
  let dests : Array[@src.SubjectState] = []
  for c in cands {
    let mut seen = false
    for d in dests {
      if d == c.1 {
        seen = true
      }
    }
    if !seen {
      dests.push(c.1)
    }
  }
  if dests.length() > 1 {
    return ("未定", "")
  }
  if cands.length() > 1 {
    return ("同归", dests[0].designation())
  }
  if cands[0].1 == state {
    ("守", state.designation())
  } else {
    ("迁", cands[0].1.designation())
  }
}

///|
/// 第一层：重建是单射的。
///
/// 规格以**原文措辞**作 `event`，故要问两件事，不能只问一件：
/// 1. 同一位置的同一句措辞不出现两次——否则读回那条边是任选（有歧义）。
///    同一句措辞挂在**不同**位置上是正常的（`EnactOrder` 两处），那不构成
///    歧义，53 条迁移对 49 句触发正是这个差额；
/// 2. 措辞的**种数**恰等于触发表的条数——多一句是两种触发共用一句（有损），
///    少一句是某种触发写不出（有缺）。
test "spec 往返的前提：措辞种数等于触发条数，同一位置的同一句不出现两次" {
  let spec = @src.spec_json()
  let event_ids : Array[String] = []
  let state_ids : Array[String] = []
  let phase_ids : Array[String] = []
  let slot_ids : Array[String] = []
  let from_event : Array[String] = []
  for line in spec.split("\n").collect() {
    let text = line.to_owned()
    if text.contains("\"members\"") {
      let id = field_of(text, "id")
      for seen in phase_ids {
        assert_false(seen == id)
      }
      phase_ids.push(id)
    } else if text.contains("\"id\": \"") {
      let id = field_of(text, "id")
      for seen in state_ids {
        assert_false(seen == id)
      }
      state_ids.push(id)
    } else if text.contains("\"from\": ") {
      // 措辞按**种**计数，不按行计数：同一句触发挂两条边时措辞当然相同，
      // 那正是「一句措辞对一句触发」该有的样子。
      let e = field_of(text, "event")
      let mut fresh = true
      for seen in event_ids {
        if seen == e {
          fresh = false
        }
      }
      if fresh {
        event_ids.push(e)
      }
      let fe = field_of(text, "from") + "→" + e
      for seen in from_event {
        assert_false(seen == fe)
      }
      from_event.push(fe)
    } else if text.contains("\"slots\": [") {
      for name in slot_names(text) {
        for seen in slot_ids {
          assert_false(seen == name)
        }
        slot_ids.push(name)
      }
    }
  }
  // 注入判据：无重复的声明若读不到一个元素，那这条判据就是空的
  assert_eq(state_ids.length(), 34)
  assert_eq(phase_ids.length(), 11)
  assert_eq(slot_ids.length(), 8)
  // 53 条迁移的行行措辞两两互异 ⇒ 读回触发无歧义
  assert_eq(from_event.length(), @src.transitions().length())
  // 措辞的种数恰等于触发表的条数：一句措辞对应一句触发
  assert_eq(event_ids.length(), @src.all_triggers().length())
}

///|
/// 第二层：逐字段相等。状态、阶段、槽、迁移，全部按序与真表比对。
test "spec 往返：逐字段相等" {
  let spec = @src.spec_json()
  // 文档级
  assert_true(doc_field(spec, "$schema") == "pyroduct-spec-v1")
  assert_true(doc_field(spec, "name") == "subject")
  assert_true(doc_field(spec, "initial") == @src.initial().designation())
  assert_true(doc_field(spec, "restingPole") == @src.terminal().designation())
  assert_true(doc_field(spec, "description").length() > 0)
  let mut seen_state = 0
  let mut seen_phase = 0
  for line in spec.split("\n").collect() {
    let text = line.to_owned()
    if text.contains("\"members\"") {
      let p = match rt_phase(field_of(text, "id")) {
        Some(x) => x
        None => panic()
      }
      assert_true(p == @src.all_phases()[seen_phase])
      let members = members_of(text)
      let want : Array[String] = []
      for s in @src.all_states() {
        if s.phase() == p {
          want.push(s.designation())
        }
      }
      assert_eq(members.length(), want.length())
      for k = 0; k < members.length(); k = k + 1 {
        assert_true(members[k] == want[k])
      }
      seen_phase += 1
    } else if text.contains("\"id\": \"") {
      let s = match rt_state(field_of(text, "id")) {
        Some(x) => x
        None => panic()
      }
      assert_true(s == @src.all_states()[seen_state])
      assert_true(field_of(text, "original") == s.label())
      assert_true(field_of(text, "phase") == s.phase().designation())
      seen_state += 1
    } else if text.contains("\"slots\": [") {
      let names = slot_names(text)
      assert_eq(names.length(), @src.all_slots().length())
      for i = 0; i < names.length(); i = i + 1 {
        let k = match rt_slot(names[i]) {
          Some(x) => x
          None => panic()
        }
        assert_true(k == @src.all_slots()[i])
      }
    }
  }
  assert_eq(seen_state, 34)
  assert_eq(seen_phase, 11)
  // 迁移：整表逐条相等（含顺序）
  let table = rt_table(spec)
  assert_eq(table.length(), @src.transitions().length())
  for i = 0; i < table.length(); i = i + 1 {
    let t = @src.transitions()[i]
    assert_true(table[i].from == t.from)
    assert_true(table[i].trigger == t.trigger)
    assert_true(table[i].to == t.to)
  }
}

///|
/// 第三层：行为相等。字段相等有可能是因为两处同源；拿重建的表在本地重算
/// 272 个组合的回执，才说明这份规格真能独立驱动一台机器。
test "spec 往返：重建的机器行为与真机一致（272 个组合逐个比对）" {
  let table = rt_table(@src.spec_json())
  let mut compared = 0
  for s in @src.all_states() {
    for k in @src.all_slots() {
      let live = @src.step(s, k)
      let (label, landing) = rt_step(table, s, k)
      assert_true(label == live.label())
      let live_landing = match live.landing() {
        Some(x) => x.designation()
        None => ""
      }
      assert_true(landing == live_landing)
      compared += 1
    }
  }
  assert_eq(compared, 34 * 8)
}
