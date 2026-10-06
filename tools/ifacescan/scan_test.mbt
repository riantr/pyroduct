///|
/// 黑盒测试：接口面**实扫**（native 专属，模型整理）。
///
/// 判据是「真表上一次发现都没有」。这句话需要证据才站得住，故这里断三件事：
/// 1. **扫到了东西**——0 个文件也算「0 条发现」，那与什么都看不见同形；
/// 2. **扫的是真文件**——含几个已知的真实包，且没有构建产物混进来；
/// 3. **真的 0**——每一个真 `.mbti` 都没有未预期发现。
///
/// 判据 2 的反面就是本工具最容易犯的错：忘了排除 `_build`，于是同一份 `.mbti`
/// 被数几十遍，计数看着很大、其实没审到任何新东西。故这里显式断「路径里不含
/// `_build`」且「文件数与去重后的路径数一致」。

///|
async test "实扫：扫到真文件、没有构建产物混进来" {
  let rows = @ifacescan.scan(".")
  assert_true(rows.length() > 0)
  let mut has_src = false
  let mut has_audit = false
  let mut leaked = 0
  let uniq : Array[String] = []
  for row in rows {
    let (rel, _) = row
    if rel == "src/pkg.generated.mbti" {
      has_src = true
    }
    if rel == "audit/pkg.generated.mbti" {
      has_audit = true
    }
    if rel.contains("_build") ||
      rel.contains(".mooncakes") ||
      rel.contains(".git") {
      leaked = leaked + 1
    }
    let mut fresh = true
    for u in uniq {
      if u == rel {
        fresh = false
      }
    }
    if fresh {
      uniq.push(rel)
    }
  }
  assert_true(has_src)
  assert_true(has_audit)
  assert_eq(leaked, 0)
  assert_eq(uniq.length(), rows.length())
}

///|
async test "实扫：每一个真 .mbti 的未预期发现都是 0" {
  let rows = @ifacescan.scan(".")
  assert_eq(@ifacescan.fresh_total(rows), 0)
}

///|
/// 去掉 `\r`。与库的 `moonfiles::normalize` 同一口径：换行符差异是 `core.autocrlf`
/// 的产物（`git checkout` 能把整包翻过来），不是内容变化，不该让漂移绊线变红。
///
/// 住在测试文件里而不是包里：测试是**黑盒**的，只经 `@pkg.…` 的公开 API 看得见
/// 东西（见本仓约定），包内的私有辅助函数测试调不到。
fn strip_cr(src : String) -> String {
  let buf = StringBuilder()
  for c in src {
    if c != '\r' {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// **漂移绊线——本设计的全部要害。** `audit` 侧的接口面之所以能报真数字，靠的是
/// `iface_data.mbt` 这份内嵌快照；本条判据保证它没有悄悄过期。
///
/// 两个方向都断：快照里的某条与磁盘不等（内容改了没重新生成），以及磁盘上多出
/// 一个快照里没有的 `.mbti`（新包没被收进快照）。任一方向都让本条变红。
///
/// 换行符差异不比：那是 `core.autocrlf` 的产物，不是内容变化；库的 `normalize`
/// 同样先剥 `\r`，故两边口径一致。
async test "漂移绊线：内嵌快照 ≡ 磁盘上的真 .mbti" {
  let snapshot = @audit.iface_snapshot()
  assert_true(snapshot.length() > 0)
  let drift : Array[String] = []
  for entry in snapshot {
    let (rel, src) = entry
    let got = @fs.read_file(rel).text() catch { _ => "\u{FFFF}" }
    if strip_cr(got) != strip_cr(src) {
      drift.push("内容已变：" + rel)
    }
  }
  for r in @ifacescan.scan(".") {
    let (rel, _) = r
    let mut found = false
    for entry in snapshot {
      if entry.0 == rel {
        found = true
      }
    }
    if !found {
      drift.push("磁盘多出：" + rel)
    }
  }
  assert_eq(drift.length(), 0)
}

///|
/// 读盘失败**不许**被当成「0 发现」——那正是本仓库反复防的假证据。空串送进
/// 审计会「0 发现」，所以读盘失败必须走另一个出口。
async test "实扫：读不到的文件报出来，不静默记 0" {
  let f = @audit.unreadable_finding("此文件不存在.mbti")
  let (known, fresh) = @audit.split_iface([f])
  assert_eq(known.length(), 0)
  assert_eq(fresh.length(), 1)
  // 空串确实「0 发现」——这正是读盘失败不能走的那条路，本条把它钉住
  assert_eq(@audit.audit_iface("", "空.mbti").length(), 0)
}
