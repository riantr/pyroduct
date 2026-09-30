///|
/// 协调器 CLI：跑一段示例研究，把整机检查点**写进磁盘**，再读回校验。
///
///   moon run --target native cmd/coord
///
/// 写出的文件放在 `.openseek/`（已被 `.gitignore` 忽略），不污染工作树。
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
  @fs.write_file(path, rt.checkpoint())
  let back = @coordinator.restore(@fs.read_file(path).text())
  println(
    "步数 \{steps}｜时钟 \{rt.clock}｜发现 \{rt.notebook.findings.length()} 条",
  )
  println("已落盘：\{path}")
  println(
    "读回：时钟 \{back.clock}｜往返一致 \{back.round_trips()}｜与写前一致 \{back.checkpoint() == rt.checkpoint()}",
  )
}
