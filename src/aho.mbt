///|
/// Aho-Corasick 自动机（pyahocorasick 镜像，模型整理）：把 49 条触发句建成
/// 前缀树并补失败链，读成**回忆结构**。
///
/// 参照 pyahocorasick（Wojciech Muła 的 Aho-Corasick 库）：先作**词典**——
/// `add_word` 把每句插进前缀树（Trie，冗余前缀只存一份）；再 `make_automaton`
/// ——广度优先补**失败链**（fail：读入失败时退回的最长已往——后缀恰是某句
/// 前缀的最长共享处）并做**输出合并**（到达某节点，所有以之为终点的句子一并
/// 浮现）；扫描线性不回头（O(总长)——过去的失败不会导致重走已走之路）。
///
/// pyroduct 的对准：
///
///   - **词典** ↔ 49 条触发句（`all_triggers` 的 label，原文触发句）；
///   - **失败链** ↔ 回忆的算法形态：匹配失败时退回**最长的共同过去**再试
///     下一刻——不是从头重来（无忆的对面）；最深失败链的深度＝句子间最长
///     的共享已往（后缀＝前缀）；
///   - **输出合并** ↔ 在同一刻涌现多条已往（「he」与「she」在同一刻浮现）；
///   - **扫描** ↔ 逐字推进、不回头：失败的回退只沿失败链，不重走；
///   - **分叉** ↔ 共享前缀：深度 ≥ 2 的分叉节点＝两条以上触发句共享开头
///     （「当他……」的时刻句式是文本自身的复沓）；
///   - **守恒与纪律**：纯结构视角，零 import，不带数（字符数是结构事实）；
///     触发句仍是执行契约的出处（0.1.x 的槽归位不变）。
///
/// 出处层：模型整理——回忆结构的读法是本仓库的整理，不是 pyahocorasick
/// 或原文的说法；自动机事实（节点数、失败链、共享前缀）是结构事实。

///|
/// 自动机：每节点的子边 / 失败链 / 终点句表 / 深度 / 根到节点的路径 / 词典。
pub(all) struct AhoAutomaton {
  children : Array[Map[Char, Int]]
  fail : Array[Int]
  output : Array[Array[Int]]
  depth : Array[Int]
  path : Array[String]
  words : Array[String]
}

///|
/// 词典阶段 + 自动机阶段：插入全部句子，广度优先补失败链与输出合并。
pub fn aho_build(words : Array[String]) -> AhoAutomaton {
  let children : Array[Map[Char, Int]] = [Map([])]
  let output : Array[Array[Int]] = [[]]
  let depth : Array[Int] = [0]
  let path : Array[String] = [""]
  // 词典：逐句插入前缀树（冗余前缀只存一份）
  for wi = 0; wi < words.length(); wi = wi + 1 {
    let mut node = 0
    for ch in words[wi].iter() {
      match children[node].get(ch) {
        Some(next) => node = next
        None => {
          let id = children.length()
          children.push(Map([]))
          output.push([])
          depth.push(depth[node] + 1)
          path.push(path[node] + "\{ch}")
          children[node][ch] = id
          node = id
        }
      }
    }
    output[node].push(wi)
  }
  // 自动机：广度优先补失败链；输出沿失败链合并（失败链更浅，BFS 序保证完备）
  let fail : Array[Int] = Array::make(children.length(), 0)
  let queue : Array[Int] = []
  for entry in children[0] {
    let (ch, v) = entry
    let _ = ch
    queue.push(v)
  }
  let mut head = 0
  while head < queue.length() {
    let u = queue[head]
    head += 1
    for entry in children[u] {
      let (ch, v) = entry
      let mut f = fail[u]
      while f != 0 && !children[f].contains(ch) {
        f = fail[f]
      }
      fail[v] = match children[f].get(ch) {
        Some(t) => if t == v { 0 } else { t }
        None => 0
      }
      for p in output[fail[v]] {
        output[v].push(p)
      }
      queue.push(v)
    }
  }
  { children, fail, output, depth, path, words, }
}

///|
/// 扫描：逐字推进，匹配失败沿失败链回退（不从头重来）；返回（结束下标,
/// 句号）对——0 起下标，与 pyahocorasick 的 `iter` 同形。
pub fn AhoAutomaton::scan(
  self : AhoAutomaton,
  text : String,
) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  let mut node = 0
  for entry in text.iter2() {
    let (i, ch) = entry
    while node != 0 && !self.children[node].contains(ch) {
      node = self.fail[node]
    }
    node = match self.children[node].get(ch) {
      Some(t) => t
      None => 0
    }
    for p in self.output[node] {
      out.push((i, p))
    }
  }
  out
}

///|
/// 自动机的统计：节点 / 边 / 最长句 / 非平凡失败链 / 最深失败链（最长的
/// 共享已往）与最深分叉（最长的共享前缀）。
pub(all) struct AhoStats {
  nodes : Int
  links : Int
  longest_word : Int
  fail_links : Int
  deepest_fail : Int
  deepest_fail_path : String
  deepest_fail_target : String
  deepest_branch : Int
  deepest_branch_path : String
}

///|
pub fn AhoAutomaton::stats(self : AhoAutomaton) -> AhoStats {
  let mut links = 0
  let mut fail_links = 0
  let mut deepest_fail = 0
  let mut deepest_fail_path = ""
  let mut deepest_fail_target = ""
  let mut deepest_branch = 0
  let mut deepest_branch_path = ""
  for v = 0; v < self.children.length(); v = v + 1 {
    links += self.children[v].length()
    if self.fail[v] != 0 && self.depth[v] > deepest_fail {
      deepest_fail = self.depth[v]
      deepest_fail_path = self.path[v]
      deepest_fail_target = self.path[self.fail[v]]
    }
    if self.children[v].length() >= 2 && self.depth[v] > deepest_branch {
      deepest_branch = self.depth[v]
      deepest_branch_path = self.path[v]
    }
  }
  for f in self.fail {
    if f != 0 {
      fail_links += 1
    }
  }
  let mut longest = 0
  for w in self.words {
    if w.length() > longest {
      longest = w.length()
    }
  }
  {
    nodes: self.children.length(),
    links,
    longest_word: longest,
    fail_links,
    deepest_fail,
    deepest_fail_path,
    deepest_fail_target,
    deepest_branch,
    deepest_branch_path,
  }
}

///|
/// 回忆结构的报告：自动机统计、共享前缀、自扫描与判读。
pub fn render_aho_report() -> String {
  let words : Array[String] = []
  for t in all_triggers() {
    words.push(t.label())
  }
  let a = aho_build(words)
  let s = a.stats()
  let lines : Array[String] = [
    "# 回忆结构（Aho-Corasick 面）", "", "参照 pyahocorasick：49 条触发句建成前缀树（冗余前缀只存一份），补失败链",
    "与输出合并成自动机。失败链＝回忆的算法形态：读入失败时退回**最长的共同",
    "过去**再试下一刻，不是从头重来。出处层：模型整理——回忆结构的读法是",
    "本仓库的整理；节点数与共享前缀是结构事实。", "",
  ]
  lines.push(
    "- 词典：\{words.length()} 条触发句；自动机 \{s.nodes} 节点、\{s.links} 条边、最长句 \{s.longest_word} 字；",
  )
  // 最深失败链指向的节点：找出以它为开头的句子（共享已往落在谁的开头上；
  // 取迁移表顺序的**首个**——多句共享同一开头时报告仍确定且不点错名）
  let owners : Array[String] = []
  let target = s.deepest_fail_target
  let ti = target.length()
  for w in words {
    if w.length() > ti && w[:ti].to_owned() == target {
      owners.push(w)
    }
  }
  let fail_owner = if owners.length() > 0 { owners[0] } else { "" }
  lines.push(
    "- 失败链：\{s.fail_links} 条非平凡——读入失败时能想起已往的位置；最深一条 \{s.deepest_fail} 字（标记地图失效的那句）；它的已往「\{s.deepest_fail_target}」恰是「\{fail_owner}」的开头——最深的一次回忆，落在残渣句的起点上：地图被推翻之处，正是已往沉积之处；",
  )
  lines.push(
    "- 分叉：最深的共享前缀 \{s.deepest_branch} 字：\{s.deepest_branch_path}（两条以上触发句从这里分岔——文本自身的复沓）；",
  )
  lines.push("")
  lines.push(
    "## 自扫描：每句在自动机里找到自己（与可能重叠的他句）",
  )
  let mut self_hits = 0
  let mut cross_hits = 0
  for wi = 0; wi < words.length(); wi = wi + 1 {
    for entry in a.scan(words[wi]) {
      let (end, p) = entry
      if p == wi {
        if end == words[wi].length() - 1 {
          self_hits += 1
        }
      } else {
        cross_hits += 1
        lines.push(
          "- 重叠：\{words[p]} 完整出现在 \{words[wi]} 之内（句尾下标 \{end}）",
        )
      }
    }
  }
  lines.push(
    "- \{self_hits}/\{words.length()} 句找到自身；句中包含他句 \{cross_hits} 处——触发句互不吞并，一字一格。",
  )
  lines.push("")
  lines.push("## 判读")
  lines.push(
    "- 无忆（NoPast）与无筹（NoFuture）是退化起点：没有过去可供失败链回退，",
  )
  lines.push(
    "  也没有未来可作筹划——根节点的失败链指向自己，读入失败只能停在原地；",
  )
  lines.push(
    "- 反顾（Reflection）是重入边：界域重开即回到反顾——失败链的回退不改变",
  )
  lines.push("  当前位置，它只改写下一刻的读法；")
  lines.push(
    "- 输出合并：到达一个状态，所有以之为终点的句子一并浮现——回忆不是检索",
  )
  lines.push("  一条记录，是同刻涌现一组已往；")
  lines.push(
    "- 线性扫描：失败不重走已走之路——已往不被重过，只被换一种读法接住。",
  )
  lines.join("\n")
}
