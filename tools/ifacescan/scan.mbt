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
fn skipped(name : String) -> Bool {
  let skip = [
    "_build", ".mooncakes", ".git", "target", "node_modules", ".openseek", ".mavis",
    ".idea", ".vscode",
  ]
  for s in skip {
    if name == s {
      return true
    }
  }
  false
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
pub fn fresh_total(rows : Array[@audit.IfaceRow]) -> Int {
  let mut n = 0
  for row in rows {
    let (_, fresh) = @audit.split_iface(row.1)
    n = n + fresh.length()
  }
  n
}
