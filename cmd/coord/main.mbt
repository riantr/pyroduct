///|
/// 协调器 CLI：跑一段示例研究，把整机检查点**写进磁盘**，再读回校验。
///
///   moon run --target native cmd/coord
///
/// 写出的文件放在 `.openseek/`（已被 `.gitignore` 忽略），不污染工作树；目录不存在
/// 时先建（新克隆里它并不在）。
async fn main {
  let rt = @coordinator.new_runtime()
  let ts = @coordinator.demo_tasks()
  let qs = @coordinator.demo_questions()
  let ws = @coordinator.demo_workers()
  let dss = @coordinator.demo_datasets()
  let world = @coordinator.demo_world()
  let parent = @coordinator.demo_parent()
  let candidate = @coordinator.demo_candidate()
  let mut steps = 0
  for i = 0; i < 3; i = i + 1 {
    if rt.step(ts, qs, ws, dss, world, parent, candidate) is Some(_) {
      steps += 1
    }
  }
  let path = ".openseek/coordinator-state.txt"
  @fs.mkdir(".openseek", recursive=true, allow_exist=true)
  @fs.write_file(path, rt.checkpoint())
  let back = @coordinator.restore(@fs.read_file(path).text())
  let same = back.checkpoint() == rt.checkpoint()
  println(
    "步数 \{steps}｜时钟 \{rt.clock}｜发现 \{rt.notebook.findings.length()} 条",
  )
  println("已落盘：\{path}")
  println(
    "读回：时钟 \{back.clock}｜往返一致 \{back.round_trips()}｜与写前一致 \{same}",
  )
  println(
    "内容指纹：\{back.digest()}｜忠实恢复 \{back.is_faithful()}",
  )
  // 这一步在 CI 里是**判据**，所以它必须能红。原来它只打印判决、永远以 0 退出，
  // 于是「检查点往返坏了」在门禁上与「往返正常」在输出上长得一模一样——判据不能
  // 失败就不是判据，而门禁的注释还写着「非零退出意味着运行时没能恢复自己的
  // 检查点」，那句话此前是不可达的。
  //
  // 口径要说清楚：这里读回的是**刚写出去**的那份，所以它证明的是
  // 「序列化→反序列化无损」，不是「上一个进程留下的检查点能被恢复」。后者需要
  // 另一个进程写、这一个进程读，CLI 目前不做那件事。
  //
  // 「忠实恢复」是第三道：往返一致只说明字节回来了，恢复过程**一处也没有猜**
  // 才是没有隐藏损失。此前 `restore` 是无声的：数字解析失败就记 0，未知的商谈
  // 类型就当理论商谈——读回来的运行时与写出去的那个**长度一样、结构一样，却处处
  // 不同**，而输出看上去是好的。
  if !same || !back.round_trips() {
    eprintln(
      "协调器检查点往返失败：写出去的检查点读回来不一样（round_trips=\{back.round_trips()}，与写前一致=\{same}）。检查点的序列化或恢复坏了。",
    )
    abort("coordinator checkpoint round-trip failed")
  }
  if !back.is_faithful() {
    eprintln(
      "协调器检查点恢复不忠实：恢复过程有 \{back.repairs.length()} 处被迫猜测——\{back.repair_summary()}",
    )
    abort("coordinator checkpoint restore was not faithful")
  }
}
