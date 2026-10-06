///|
/// 接口面自审计：把本仓库**自己的** `pkg.generated.mbti` 当被测对象，交给
/// `riantr/moonbit_static_analysis@0.2.0` 的 `src/moonfiles` 审（模型整理）。
///
/// 与 `audit.mbt`／`fleet.mbt` 的分工要分清：那两面审的是**状态机表**——把真表
/// 转成纯数据 `MachineSpec` 再喂进去；本面审的是**工具链自己生成出来的接口
/// 文件**。两者同属「自己的产物当被测对象」，只是产物不同。
///
/// 为什么值得审：`.mbti` 是 `moon info` 的产物而**入库**（随 `moon.mod` 打进
/// 发布包），它一旦与真实导出面脱节，下游照它写的代码就对不上；手改一个
/// `pub` 字样也可能让接口与实现分家。库这一路抓三类形状——**重复签名**、
/// **畸形行**、**未知类型引用**（皆 `FParse`／结构鉴）。
///
/// 本文件**不做 IO**：读盘在 native 侧的 `tools/ifacescan`。这一侧只放纯函数，
/// 于是「正控：坏片段必被抓」与「净片段必为 0」两条判据可以进 wasm 门禁——
/// 读盘那条只能进 native 门禁，而正控不进门禁就等于没审。

///|
/// 审一段接口文件。薄透镜：语义全在库里，本层只负责「本仓库用什么口径称它」。
pub fn audit_iface(src : String, file : String) -> Array[@sareport.Report] {
  @safiles.iface(src, file)
}

///|
/// 对**内嵌快照**（`iface_data.mbt`，由 `tools/gen_iface_data.py` 生成）做实扫。
///
/// 这一层存在的理由：wasm／JS 侧读不了盘，而接口面要能被 agent 直接问到，
/// 就得把接口内容带进 wasm 侧。带进来之后「快照会过期」就成了必须回答的问题——
/// 答案不是小心，是判据：`tools/ifacescan` 的 native 测试逐字节比对
/// 「快照 ≡ 磁盘上的真文件」，`moon info` 一改就红。故这里报的是**真内容**的
/// 真计数，不是对一份样例报「0 发现」。
pub fn scan_snapshot() -> Array[IfaceRow] {
  let rows : Array[IfaceRow] = []
  for row in iface_snapshot() {
    let (rel, src) = row
    rows.push((rel, audit_iface(src, rel)))
  }
  rows
}

///|
/// 未预期发现总数（已知设计豁免是空的，故未预期即全部）。
pub fn snapshot_fresh_total() -> Int {
  let mut n = 0
  for row in scan_snapshot() {
    let (_, fresh) = split_iface(row.1)
    n = n + fresh.length()
  }
  n
}

///|
/// 逐条看这一段接口文件被报了什么家族。
pub fn families_of_iface(src : String, file : String) -> Array[String] {
  let out : Array[String] = []
  for f in audit_iface(src, file) {
    out.push(family_name(f.family))
  }
  out
}

///|
/// 接口面「已知设计」豁免清单：**空的**。
///
/// 与 `fleet.mbt` 同一纪律，理由是**实测出来的**而非假定的：20 个真 `.mbti`
/// 跑下来一次发现都没有（见 `tools/ifacescan` 的实扫与它的 native 判据）。
/// 没有已知设计可豁免，就不预留口子——预留了，将来谁改坏一条导出面，报出来的
/// 发现会被静默归进「已知设计」，绊线形同虚设。
fn is_known_iface(_f : @sareport.Report) -> Bool {
  false
}

///|
/// 把一批发现分成（已知设计，未预期）两层。
///
/// 单独成函数是为了让**分层本身**可测：真表上一次发现都没有，在真表上「全塞
/// 已知设计」与「正确分层」输出完全一致——只在真表上验分层，等于没验。
/// `mbti_test.mbt` 拿**试造的发现**来验。
pub fn split_iface(
  findings : Array[@sareport.Report],
) -> (Array[@sareport.Report], Array[@sareport.Report]) {
  let known : Array[@sareport.Report] = []
  let fresh : Array[@sareport.Report] = []
  for f in findings {
    if is_known_iface(f) {
      known.push(f)
    } else {
      fresh.push(f)
    }
  }
  (known, fresh)
}

///|
/// 干净样本：照 `cmd/main` 真实 `.mbti` 的形状造（`moon info` 的头注释、
/// `package` 行、六个分区、两个 `pub fn`）。**必须 0 发现**——它与真表同形，
/// 是「正控之外还要有反例」那一半。
pub fn clean_sample() -> String {
  let mut s = "// Generated using `moon info`, DON'T EDIT IT\n"
  s = s + "package \"riantr/pyroduct/sample\"\n\n"
  s = s + "// Values\n"
  s = s + "pub fn group() -> String\n\n"
  s = s + "pub fn journey() -> String\n\n"
  s = s + "// Errors\n\n"
  s = s + "// Types and methods\n\n"
  s = s + "// Type aliases\n\n"
  s = s + "// Traits\n"
  s
}

///|
/// 破坏一：**重复签名**。同一句 `pub fn` 写两遍。
pub fn broken_duplicate() -> String {
  let mut s = "// Generated using `moon info`, DON'T EDIT IT\n"
  s = s + "package \"riantr/pyroduct/sample\"\n\n"
  s = s + "// Values\n"
  s = s + "pub fn group() -> String\n\n"
  s = s + "pub fn group() -> String\n"
  s
}

///|
/// 破坏二：**畸形行**。一行既不是签名也不是类型声明。
pub fn broken_malformed() -> String {
  let mut s = "// Generated using `moon info`, DON'T EDIT IT\n"
  s = s + "package \"riantr/pyroduct/sample\"\n\n"
  s = s + "// Values\n"
  s = s + "pub fn group() -> String\n"
  s = s + "这一行既不是签名也不是类型声明\n"
  s
}

///|
/// 破坏三：**未知类型引用**。签名里引了一个本文件没声明、也不在库内建表里的
/// 类型名。带 `@` 的（`@statecheck.MachineSpec`）按库的口径算外部，不触发——
/// 这条同时把「外部引用不算错」这条口径钉住。
pub fn broken_unknown_type() -> String {
  let mut s = "// Generated using `moon info`, DON'T EDIT IT\n"
  s = s + "package \"riantr/pyroduct/sample\"\n\n"
  s = s + "import {\n"
  s = s + "  \"riantr/moonbit_static_analysis/src/statecheck\",\n"
  s = s + "}\n\n"
  s = s + "// Values\n"
  s = s + "pub fn machine() -> @statecheck.MachineSpec\n\n"
  s = s + "pub fn widget() -> Widget\n"
  s
}

///|
/// 造一条「读盘失败」发现，供 native 侧读不到 `.mbti` 时用。
///
/// 为什么在这里造而不让读盘包自己 import 库的 `core`：库的依赖纪律是本模块的
/// **唯一**消费者是 `audit`；多一个包 import 它，纪律就破了。
pub fn unreadable_finding(file : String) -> @sareport.Report {
  probe_finding(
    @sacore.FParse,
    "读不出 \{file}——把「读不到」当成「0 发现」是本仓库反复防的那类假证据",
  )
}

///|
/// 一行实扫结果：(.mbti 的相对路径, 它被报出的发现)。
///
/// 为什么在这里起别名：库的依赖纪律是 `riantr/moonbit_static_analysis` 的**唯一**
/// 消费者是 `audit`。若让 native 侧的读盘包直接 import 库的 `report`，那条纪律
/// 就破了两个包；故在此把行类型出口化，读盘包只认 `audit`。
pub type IfaceRow = (String, Array[@sareport.Report])

///|
/// 实扫报告。`rows` 是（相对路径, 发现）的序列，**由调用方读盘后喂进来**
/// ——本层不碰文件系统，故 wasm 侧也能渲染。
pub fn render_iface_report(rows : Array[IfaceRow]) -> String {
  let lines : Array[String] = []
  lines.push(
    "# 自审计（接口面）：本仓库自己的 .mbti 当被测对象",
  )
  lines.push("")
  lines.push(
    "与 `主体`／`fleet` 两面同一纪律：**自己的产物当被测对象**。区别是那两面审",
  )
  lines.push(
    "的是**状态机表**（真表转成纯数据 `MachineSpec`），本面审的是**工具链生成的",
  )
  lines.push(
    "接口文件**。`.mbti` 随发布包入库，一旦与真实导出面脱节，下游就接不上。",
  )
  lines.push(
    "库这一路（`src/moonfiles::iface`）抓三类形状：重复签名、畸形行、未知类型引用。",
  )
  lines.push("")
  lines.push(
    "**扫的是内嵌快照**（`audit/iface_data.mbt`，由 `tools/gen_iface_data.py` 从",
  )
  lines.push(
    "真实的 `pkg.generated.mbti` 逐字节生成）。wasm／JS 读不了盘，故真扫靠快照进行；",
  )
  lines.push(
    "快照与磁盘的等价性由 native 判据守着——`moon test --target native tools/ifacescan`",
  )
  lines.push(
    "逐字节比对二者，`moon info` 一改就红。故下面的数字说的是真内容，不是样例。",
  )
  lines.push("")
  lines.push(
    "已知设计豁免：**空**。没有已知设计可豁免就不预留口子——预留了，将来谁改坏",
  )
  lines.push(
    "一条导出面，发现会被静默归进「已知设计」，绊线形同虚设。",
  )
  lines.push("")
  let mut clean = 0
  let mut dirty = 0
  let mut total = 0
  for row in rows {
    let (_, findings) = row
    if findings.length() == 0 {
      clean = clean + 1
    } else {
      dirty = dirty + 1
      total = total + findings.length()
    }
  }
  lines.push("面 | 文件数 | 未预期发现")
  lines.push("---|---|---|")
  lines.push("| 接口（.mbti） | \{rows.length()} | \{total} |")
  lines.push("")
  lines.push("逐文件（仅列有发现的）：")
  lines.push("")
  if dirty == 0 {
    lines.push(
      "**0 条**——\{rows.length()} 个真实 `.mbti` 无任何报警。绊线：任何新增发现都会",
    )
    lines.push("让 native 门禁失败，强制复审。")
  } else {
    for row in rows {
      let (path, findings) = row
      if findings.length() > 0 {
        lines.push("- \{path}（\{findings.length()} 条）：")
        for f in findings {
          lines.push("  - \{f.render()}")
        }
      }
    }
  }
  lines.push("")
  lines.push("口径：干净 \{clean} 个，有发现 \{dirty} 个。")
  lines.join("\n")
}
