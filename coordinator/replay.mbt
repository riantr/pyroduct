///|
/// 确定性回放：内容指纹 ＋ 失败闭合的恢复 ＋ 降级账。
///
/// 形状取自 SDYJ_Multi_Agents（`hwfengcs/SDYJ_Multi_Agents`）那套「record-and-replay」
/// 的做法：运行不是「跑过一次」，而是**可以再跑出同一个东西**。那边的做法是按
/// prompt 哈希匹配缓存（`ReplayLLM` 按 prompt hash 命中，顺序只作兜底），并把
/// 崩溃时的部分状态写进 `state.partial.json` 以便续跑。
///
/// 这边没有 LLM——工人是确定性替身——于是可以直接要求**更强**的东西：
///
/// 1. **内容指纹**。一次运行的状态有一枚 64 位指纹（FNV-1a）。不引依赖、不用
///    时钟、不用随机源：同一段内容永远给出同一枚指纹。
/// 2. **双哈希**。那边记的是「请求哈希 + 响应哈希」两枚；这边检查点里记的是
///    **内容指纹**，而**重建出来的运行时**另算一枚——两枚对不上，就说明恢复过程
///    动了手脚。这是「字节级往返只证明序列化没坏」那句话的正面回答。
/// 3. **失败闭合**。恢复时每一处「只能猜」都记进**降级账**（`repairs`）：猜出来的
///    数字、猜出来的商谈类型、猜出来的制品类别、被整行丢掉的发现、对不上的指纹。
///    恢复出来的运行时因此要么**忠实**，要么**明说自己不忠实**。
/// 4. **重放闸门**。同一份计划跑两遍，两遍的内容指纹必须一致。不一致就说明运行
///    里混进了不确定的东西（时钟、随机、字典序、共享状态）。
///
/// 第 3 条是本层最要紧的一条。此前 `restore` 是**无声的**：数字解析失败就记 0，
/// 未知的商谈类型就当理论商谈，未知的制品类别就当笔记。恢复出来的运行时与写出去
/// 的那个**长得一样，却处处不同**——那是最难查的一类坏，因为它看上去是好的。

///|
/// 一段文本的 64 位指纹（FNV-1a）。
///
/// 逐字符取码点算，不引依赖、不用时钟、不用随机源——**同一段文本永远给出同一枚
/// 指纹**，这是「重放」得以成立的前提。
pub fn digest_of(text : String) -> String {
  let mut h : UInt64 = 0xcbf29ce484222325
  for ch in text.iter() {
    h = h ^ ch.to_int().to_uint64()
    h = h * 0x100000001b3
  }
  let hex = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
  ]
  let mut out = ""
  let mut n = h
  let mut i = 0
  while i < 16 {
    out = out + hex[(n & 0xF).to_int()]
    n = n >> 4
    i = i + 1
  }
  out
}

///|
/// 运行时的**内容**（检查点里除指纹行以外的部分）。
///
/// 指纹算在这一段上。降级账（`repairs`）**不算**进去：它描述的是「这次解析猜了
/// 什么」，不是状态本身；把它算进去会让「恢复出来的东西」与「写出去的东西」
/// 永远对不上。
pub fn Runtime::body(self : Runtime) -> String {
  let lines : Array[String] = ["clock\t\{self.clock}"]
  for id in self.done {
    lines.push("done\t\{id}")
  }
  for m in self.log {
    lines.push(
      [
        "msg",
        "\{m.at}",
        "\{m.from}",
        "\{m.to}",
        discourse_code(m.discourse),
        claim_code(m.claim),
        m.body,
      ].join("\t"),
    )
  }
  for r in self.results {
    lines.push(
      [
        "result",
        "\{r.id}",
        "\{r.task}",
        "\{r.question}",
        claim_code(r.claim),
        phase_code(r.phase),
        "\{r.dataset}",
        "\{r.effect}",
        "\{r.ci_low}",
        "\{r.ci_high}",
        "\{r.replicas}",
        r.summary,
      ].join("\t"),
    )
  }
  for a in self.artifacts {
    lines.push(
      ["artifact", "\{a.id}", kind_code(a.kind), "\{a.task}", a.digest, a.name].join(
        "\t",
      ),
    )
  }
  let nb = self.notebook.serialize()
  if nb.length() > 0 {
    lines.push(nb)
  }
  lines.join("\n")
}

///|
/// 运行时的内容指纹。
pub fn Runtime::digest(self : Runtime) -> String {
  digest_of(self.body())
}

///|
/// 这次恢复是否**忠实**：一处也没有猜。
pub fn Runtime::is_faithful(self : Runtime) -> Bool {
  self.repairs.length() == 0
}

///|
/// 降级账（人读）：这一次恢复里每一处「只能猜」的地方。
pub fn Runtime::repair_summary(self : Runtime) -> String {
  if self.repairs.length() == 0 {
    "降级账：空——恢复过程一处也没有猜"
  } else {
    let lines : Array[String] = [
      "降级账：\{self.repairs.length()} 处被迫猜测",
    ]
    for r in self.repairs {
      lines.push("- \{r}")
    }
    lines.join("\n")
  }
}

///|
/// 两次运行的内容是否一致。
///
/// 这是重放闸门的判定：不是「跑完了吗」，而是「跑出来的是不是同一个东西」。
pub fn replay_agrees(a : Runtime, b : Runtime) -> Bool {
  a.digest() == b.digest() && a.body() == b.body()
}

///|
/// 检查点里记的指纹行（若有）。
pub fn claimed_digest(text : String) -> String {
  for line in text.split("\n") {
    let f = line.split("\t").collect()
    if f.length() >= 2 && f[0].to_owned() == "digest" {
      return f[1].to_owned()
    }
  }
  ""
}
