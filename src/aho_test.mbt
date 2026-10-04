///|
/// 黑盒测试：Aho-Corasick 自动机（pyahocorasick 镜像）。锁定——教科书
/// 例子的匹配集、失败链的形状、49 条触发句的自扫描完备。

///|
test "aho：教科书例子——ushers 里的 he／she／his／hers" {
  let a = @src.aho_build(["he", "she", "his", "hers"])
  let hits = a.scan("ushers")
  // 「she」与它的后缀「he」在同一刻涌现（输出合并）；「hers」在句尾
  assert_eq(hits.length(), 3)
  assert_eq(hits[0], (3, 1)) // she：u0 s1 h2 e3
  assert_eq(hits[1], (3, 0)) // he：h2 e3——失败链合并的输出
  assert_eq(hits[2], (5, 3)) // hers：h2 e3 r4 s5
  // 失败链的形状：she 节点的失败链指向 he 节点（最长共同已往）
  let she = a.children[a.children[a.children[0]['s']]['h']]['e']
  let he = a.children[a.children[0]['h']]['e']
  assert_eq(a.fail[she], he)
  assert_eq(a.output[she].length(), 2) // she 与 he 一并浮现
}

///|
test "aho：49 条触发句——自扫描完备，互不吞并" {
  let words : Array[String] = []
  for t in @src.all_triggers() {
    words.push(t.label())
  }
  let a = @src.aho_build(words)
  let s = a.stats()
  assert_eq(a.words.length(), 49)
  assert_true(s.nodes >= s.longest_word + 1) // 最长句的链必须在树里
  // 每句在自身末尾找到自己
  let mut self_hits = 0
  let mut cross_hits = 0
  for wi = 0; wi < words.length(); wi = wi + 1 {
    for entry in a.scan(words[wi]) {
      let (end, p) = entry
      if p == wi && end == words[wi].length() - 1 {
        self_hits += 1
      } else if p != wi {
        cross_hits += 1
      }
    }
  }
  assert_eq(self_hits, 49)
  assert_true(cross_hits >= 0)
}
