///|
/// 迁移表的**邻接索引**：一次扫描建好，聚合查询按需取。
///
/// 这是「派生查询」的最小形态：派生表先声明它消费什么——本索引只读
/// `transitions()`（原文直述）与 `Trigger::slot`（模型整理）；键取两字定名
/// （状态与槽的定名各自互异，见测试），数组按迁移表顺序追加，故任何聚合的
/// 结果与直接全表扫描逐条相同、可重放。
///
/// 取舍：**不设全局缓存**。建索引是一次 O(迁移数) 的扫描，由聚合查询
/// （`gaps`／`positions_reachable_by`）逐调用重建；`src` 不接环境，表永不
/// mutated，同一数据必建出同一索引。单点查询（`step`／`exitable`）保持直扫：
/// 为一次查询建索引反而不划算。
priv struct MovesIndex {
  from_edges : Map[String, Array[(Trigger, SubjectState)]] // 位置定名 → 出边（表序）
  slot_edges : Map[String, Array[(Trigger, SubjectState)]] // 槽定名 → 边（表序）
}

///|
fn MovesIndex::build() -> MovesIndex {
  let idx : MovesIndex = { from_edges: {}, slot_edges: {}, }
  for t in transitions() {
    let from_key = t.from.designation()
    let slot_key = t.trigger.slot().designation()
    let from_arr = match idx.from_edges.get(from_key) {
      Some(arr) => arr
      None => {
        let arr : Array[(Trigger, SubjectState)] = []
        idx.from_edges[from_key] = arr
        arr
      }
    }
    from_arr.push((t.trigger, t.to))
    let slot_arr = match idx.slot_edges.get(slot_key) {
      Some(arr) => arr
      None => {
        let arr : Array[(Trigger, SubjectState)] = []
        idx.slot_edges[slot_key] = arr
        arr
      }
    }
    slot_arr.push((t.trigger, t.to))
  }
  idx
}

///|
/// 某位置的出边；无出边返回空数组（仍按表序）。
fn MovesIndex::edges_from(
  self : MovesIndex,
  state : SubjectState,
) -> Array[(Trigger, SubjectState)] {
  match self.from_edges.get(state.designation()) {
    Some(arr) => arr
    None => {
      let empty : Array[(Trigger, SubjectState)] = []
      empty
    }
  }
}
