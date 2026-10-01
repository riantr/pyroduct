///|
/// 派生表的**持久度清单**：每张派生表声明它消费哪些出处层。
///
/// 出处层就是持久度：「原文直述」的表（状态、迁移、定名）是**高持久度**输入
/// ——永不改动；「模型整理」的定义（驱动槽八分、循环次序）可被修订。修订只应
/// 触发标注了该层的派生表重算：「改模型要同步哪些报告」由此从纪律清单变成
/// 可查的数据——每行（派生表, 消费层, 改动来源）就是它的答案。
///
/// 机械可查的部分：槽相关行消费的出处层在运行时取自 `Slot::provenance()` 的
/// 首段——揭蔽槽是「模型整理」，因此任何槽的派生表都必然消费模型整理层；
/// 这一条不由手写断言给出，由清单自己长出来。
pub fn durability_manifest() -> Array[(String, String, String)] {
  let slot_layers = slot_layer_heads()
  [
    (
      "迁移图（mermaid／dot）", "原文直述：状态表、迁移表、定名",
      "改原文措辞或迁移表 → 重算；改槽映射不涉及",
    ),
    (
      "主线／环节（genesis／course）", "原文直述：迁移表", "改迁移表 → 重算",
    ),
    (
      "驱动槽八分（slot_tally／render_slots）",
      "\{slot_layers}（运行时取自 Slot::provenance）",
      "改槽定义或归位 → 重算",
    ),
    (
      "执行契约与缺口（step／exitable／gaps／邻接索引）",
      "迁移表（原文直述）＋槽映射（\{slot_layers}）",
      "改迁移表或槽映射 → 重算",
    ),
  ]
}

///|
/// 八槽出处层的首段（原文直述／混合／模型整理），按 `all_slots` 顺序去重。
fn slot_layer_heads() -> String {
  let seen : Array[String] = []
  for s in all_slots() {
    let head = layer_head(s.provenance())
    let mut seen_it = false
    for x in seen {
      if x == head {
        seen_it = true
      }
    }
    if !seen_it {
      seen.push(head)
    }
  }
  seen.join("＋")
}

///|
/// 出处层字段的首段：到全角冒号为止（「原文直述」无冒号则整段）。
fn layer_head(p : String) -> String {
  match p.split("：").collect().get(0) {
    Some(head) => head.to_owned()
    None => p
  }
}
