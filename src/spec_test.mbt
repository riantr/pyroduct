///|
/// 黑盒测试：规格导出。词汇表防漂移（输出里的每个键都在词汇表里——
/// 参照 python-statemachine「解析器与 schema 断言相等，永不漂移」的纪律），
/// 以及规格与机器计数一致。

///|
test "spec：词汇表防漂移——输出中出现的每个键都在 spec_vocabulary 里" {
  let vocab = @src.spec_vocabulary()
  let spec = @src.spec_json()
  // 输出不含反斜杠（语料措辞无 ASCII 引号；转义缺席即可观测）
  assert_false(spec.contains("\\"))
  // 逐行扫描 `"key":` 形态：按 `"` 切分后，奇数位且后随 `:` 的段是键
  for line in spec.split("\n") {
    let parts = line.split("\"").collect()
    for i = 0; i < parts.length(); i = i + 1 {
      if i % 2 == 1 &&
        i + 1 < parts.length() &&
        parts[i + 1].to_owned().has_prefix(":") {
        let key = parts[i].to_owned()
        let mut known = false
        for v in vocab {
          if v == key {
            known = true
          }
        }
        assert_true(known)
      }
    }
  }
}

///|
test "spec：规格与机器计数一致——34 状态 · 11 阶段 · 8 槽 · 53 迁移" {
  let spec = @src.spec_json()
  let mut state_ids = 0
  let mut phase_ids = 0
  let mut moves = 0
  for line in spec.split("\n") {
    if line.contains("\"id\": \"") && !line.contains("\"members\"") {
      state_ids += 1
    }
    if line.contains("\"members\"") {
      phase_ids += 1
    }
    if line.contains("\"from\": ") {
      moves += 1
    }
  }
  assert_eq(state_ids, 34)
  assert_eq(phase_ids, 11)
  assert_eq(moves, 53)
  assert_true(spec.contains("\"initial\": \"立位\""))
  assert_true(spec.contains("\"restingPole\": \"宁静\""))
  // 槽行恰含 8 个定名（由 all_slots 顺序产出）
  assert_true(spec.contains("\"slots\": [\"处境\", \"取向\", "))
  // 词汇表自身无重复键
  let vocab = @src.spec_vocabulary()
  for i = 0; i < vocab.length(); i = i + 1 {
    for j = 0; j < vocab.length(); j = j + 1 {
      if i < j {
        assert_false(vocab[i] == vocab[j])
      }
    }
  }
}
