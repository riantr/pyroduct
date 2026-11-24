///|
/// 接口面实扫：把仓库里真实的 `pkg.generated.mbti` 逐个读进来审。
///
/// **为什么走盘而不硬编码清单**：`pkg.generated.mbti` 是 `moon info` 为每个包
/// 生成的，每加一个包就多一个。硬编码清单会静默过期——新包的接口文件没人审，
/// 而扫描报告上「0 条发现」照样成立。走盘 + 排除构建目录则相反：新包自动进扫描。
///
/// 排除项是构建产物与工具元数据：它们里面有大量 `.mbti` 拷贝，扫进去只会把
/// 同一份内容数几十遍，得到一个看着很大、其实什么都没审的计数。

///|
/// 不进扫描的目录名（构建产物与工具元数据）。
///
/// **这里是一条规则，不是一张清单**：凡是以 `.` 开头的目录名一律不进。
///
/// 为什么不能只列名字：依赖树被取到 `.mooncakes/` 下（gitignored，工具链的解压
/// 根目录；`moon fetch` 取到 `.repos/`），而**依赖自己带着一整套 `.mbti`**。
/// 实测 2026-11-24：判据视野里共 88 个 `.mbti`，其中 **67 个属于依赖树**，
/// 本仓库自己的只有 21 个。
/// 而本包的判据是「快照 ≡ 磁盘」**双向相等**（快照里有而磁盘上没有、磁盘上有
/// 而快照里没有，都算漂移），于是本机绿、CI 红——CI 上没有依赖树，磁盘只有
/// 21 个 `.mbti`，快照却有 88 行。
///
/// 一条**随工作目录而变**的判据不是判据：它在本机答一个题、在 CI 答另一个题。
/// 所以规则写成「点开头的目录不进」，而不是「把已知的那几个写下来」——后者每多
/// 一个新 scratch 目录就要记得改一次，忘了就是一次静默的分歧。
///
/// `tools/gen_iface_data.py` 必须用同一条规则（生成器与扫描器看不同的文件集合
/// 时，判据会误报或漏报）；两侧的一致性由 `tools/validate_iface_skip_lists.py`
/// 守着。
fn skipped(name : String) -> Bool {
  let skip = ["_build", "target", "node_modules"]
  for s in skip {
    if name == s {
      return true
    }
  }
  // 以 `.` 开头的一律不进：工具元数据与取回来的依赖都在这类目录里。
  name.has_prefix(".")
}

///|
/// 递归收集 `dir` 之下所有 `.mbti` 的**相对路径**，追加进 `out`。
///
/// 不用 `@fs.walk`：它只回调**子目录**、不回调文件，而且并行遍历要跨任务共享
/// 可变数组。自己递归顺带把相对路径一次算对，也省掉事后切片（MoonBit 没有
/// `[..n]` 切片语法，事后从全路径里截反而容易写错）。
async fn collect(dir : String, rel : String, out : Array[String]) -> Unit {
  let handle = @fs.opendir(dir)
  while handle.next() is Some(entry) {
    let name = entry.name
    if name == "." || name == ".." {
      continue
    }
    let rel_child = if rel == "" { name } else { rel + "/" + name }
    if entry.is_dir {
      if !skipped(name) {
        collect(dir + "/" + name, rel_child, out)
      }
    } else if name.has_suffix(".mbti") {
      out.push(rel_child)
    }
  }
  handle.close()
}

///|
/// 从 `root` 扫全仓，逐个审计，产出（相对路径, 发现）的行。
///
/// 读不出来的文件**不静默跳过**——一个 `.mbti` 读不到却记成「0 发现」，那正是
/// 本仓库反复防的假证据。故读失败直接算一条发现，让判据变红。
pub async fn scan(root : String) -> Array[@audit.IfaceRow] {
  let rels : Array[String] = []
  collect(root, "", rels)
  // 排序：遍历顺序不定，报告与判据都要稳定
  rels.sort()
  let rows : Array[@audit.IfaceRow] = []
  for rel in rels {
    // 读不到就置 ok=false，而不是把空串当内容送进审计——空串会「0 发现」，
    // 于是读盘失败会被记成「干净」，正是本仓库反复防的假证据。
    let mut ok = true
    let src : String = @fs.read_file(root + "/" + rel).text() catch {
      _ => {
        ok = false
        ""
      }
    }
    if ok {
      rows.push((rel, @audit.audit_iface(src, rel)))
    } else {
      rows.push((rel, [@audit.unreadable_finding(rel)]))
    }
  }
  rows
}

///|
/// 未预期发现总数（已知设计豁免是空的，故未预期即全部）。
pub fn fresh_total(rows : Array[@audit.IfaceRow]) -> Int32 {
  let mut n = 0
  for row in rows {
    let (_, fresh) = @audit.split_iface(row.1)
    n = n + fresh.length()
  }
  n
}
