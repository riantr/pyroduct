#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Review harness: mutation table for the five capability Loops.

「测试全过」不算 review。每一条 mutation 把某个构件改回**旧样子／错样子**，
重跑 `moon test`，判据必须变红。跑得通的表才有意义，跑不完的表是陷阱。

每条 mutation 是**精确字符串替换**且必须恰好命中一次（命中 0 次或多次即报
ANCHOR-ERROR，不动手）。原文件字节先入内存，`finally` 里逐字节写回，事后
校验 sha256 与开跑前一致——改源码的脚本必须自己证明自己没留下痕迹。

用法：
    python tools/mutate_review.py            # 全部 Loop
    python tools/mutate_review.py loop3      # 只跑某一组
"""

import hashlib
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOG = os.path.join(ROOT, "tools", "mutation_review_log.md")

# Loop 1：触发粒度。同归组合上 `step` 曾经直接报出迁移表里第一条，等于替环境
# 说了一句它没说过的话；`Same` 与 `step_by_trigger` 是为此而加。
LOOP1 = [
    (
        "A1 step 在同归组合上点名第一条（旧行为）",
        "src/loop.mbt",
        "  if cands.length() > 1 {\n"
        "    // 同归：多条不同的触发句归到同一个目标。报出其中一条就是编造——`Block`\n"
        "    // 存在的全部意义是不许编造下一步，同一条纪律不许编造上一步的触发。\n"
        "    let named : Array[Trigger] = []\n"
        "    for entry in cands {\n"
        "      named.push(entry.0)\n"
        "    }\n"
        "    return Same(slot, named, first.1)\n"
        "  }\n",
        "  if cands.length() > 1 {\n"
        "    if first.1 == state {\n"
        "      return Held(first.0, state)\n"
        "    } else {\n"
        "      return Moved(first.0, first.1)\n"
        "    }\n"
        "  }\n",
    ),
    (
        "A2 Same 不给落点（回执不再推进行程）",
        "src/loop.mbt",
        "    Same(_, _, to) => Some(to)",
        "    Same(_, _, _) => None",
    ),
    (
        "A3 有歧义时替表挑一条（不猜→猜）",
        "src/loop.mbt",
        "  if hits.length() > 1 {\n"
        "    return Block(\n"
        "      \"「\\{trigger.label()}」从「\\{state.designation()}」出发有多条出边——表有歧义，不猜\",\n"
        "    )\n  }\n",
        "  if hits.length() > 1 {\n    return Moved(trigger, hits[0])\n  }\n",
    ),
    (
        "A4 去重检查恒真（表有歧义也不报）",
        "src/loop.mbt",
        "    if dup {\n      return false\n    }",
        "    if dup {\n      ()\n    }",
    ),
    (
        "A5 same_target_pairs 把未定也算成同归",
        "src/loop.mbt",
        "      if targets.length() == 1 {",
        "      if targets.length() >= 1 {",
    ),
]

# Loop 2：group/society 的执行契约。「纯新增」曾让 `Open` 不可达，判据没有牙齿。
LOOP2 = [
    (
        "B1 group::step 去掉并列分支（一句触发两个去处被抹平）",
        "group/loop.mbt",
        "  if to.length() > 1 {\n    return Open(trigger, to)\n  }\n",
        "",
    ),
    (
        "B2 group::step 给缺口编造一条出边",
        "group/loop.mbt",
        "  if to.length() == 0 {\n"
        "    return Block(\n"
        "      \"「\\{state.designation()}」处没有「\\{trigger.label()}」的边\",\n"
        "    )\n  }\n",
        "  if to.length() == 0 {\n    return Moved(trigger, initial())\n  }\n",
    ),
    (
        "B3 group::open_pairs 返回空（那句数据问题被藏起来）",
        "group/loop.mbt",
        "      if to.length() > 1 {\n        out.push((s, k, to))\n      }",
        "      if to.length() > 99 {\n        out.push((s, k, to))\n      }",
    ),
    (
        "B4 group::no_dead_end 恒真",
        "group/loop.mbt",
        "pub fn no_dead_end() -> Bool {\n  for s in all_states() {",
        "pub fn no_dead_end() -> Bool {\n  if true {\n    return true\n  }\n  for s in all_states() {",
    ),
    (
        "B5 society::one_edge_per_trigger 恒真（触发粒度的确定性不再被锁）",
        "society/loop.mbt",
        "        if seen.contains(t.trigger) {\n          return false\n        }",
        "        if seen.contains(t.trigger) {\n          ()\n        }",
    ),
]

LOOP3 = [
    (
        "M1 缺口被编造出一条边",
        "src/loop.mbt",
        "    Block(_) => ()\n  }\n  out\n}",
        "    Block(_) => out.push(Moved(TakeStand, at))\n  }\n  out\n}",
    ),
    (
        "M2 同归只点名第一条",
        "src/loop.mbt",
        "    Same(_, named, to) =>\n"
        "      for tr in named {\n"
        "        out.push(resolved(tr, to, at))\n"
        "      }\n",
        "    Same(_, _, to) => out.push(resolved(TakeStand, to, at))\n",
    ),
    (
        "M3 同归被当成未定展开",
        "src/loop.mbt",
        "  let slot = slots[i]\n  let out = step(at, slot)\n  match out {\n",
        "  let slot = slots[i]\n"
        "  let raw = step(at, slot)\n"
        "  let out = match raw {\n"
        "    Same(_, named, to) => {\n"
        "      let cands : Array[(Trigger, SubjectState)] = []\n"
        "      for tr in named {\n"
        "        cands.push((tr, to))\n"
        "      }\n"
        "      Open(cands)\n"
        "    }\n"
        "    other => other\n"
        "  }\n"
        "  match out {\n",
    ),
    (
        "M4 缺口处终止分支",
        "src/loop.mbt",
        "        None => at\n      }\n"
        "      expand_from(origin, next, advanced, slots, i + 1, budget)\n",
        "        None => return ([{ start: origin, steps: advanced, }], false)\n      }\n"
        "      expand_from(origin, next, advanced, slots, i + 1, budget)\n",
    ),
    (
        "M5 after_open 起点步数偏一",
        "src/loop.mbt",
        "      dist[c.1.designation()] = 1\n",
        "      dist[c.1.designation()] = 2\n",
    ),
    (
        "M6 after_open 去掉深度闸",
        "src/loop.mbt",
        "    if d >= depth {\n      continue\n    }",
        "    if d >= depth && depth < 0 {\n      continue\n    }",
    ),
    (
        "M7 push_step 共用同一份行程（别名）",
        "src/loop.mbt",
        "  let out : Array[(Slot, Outcome)] = []\n"
        "  for entry in steps {\n"
        "    out.push(entry)\n"
        "  }\n"
        "  out.push((slot, outcome))\n  out\n}",
        "  steps.push((slot, outcome))\n  steps\n}",
    ),
    (
        "M8 撞界不报",
        "src/loop.mbt",
        "  { leaves, truncated, }\n}",
        "  { leaves, truncated: false, }\n}",
    ),
    (
        "M9 open_points 把同归也算成未定点",
        "src/loop.mbt",
        "        Open(cands) => out.push((s, k, cands.length()))\n        _ => ()\n",
        "        Open(cands) => out.push((s, k, cands.length()))\n"
        "        Same(_, named, _) => out.push((s, k, named.length()))\n"
        "        _ => ()\n",
    ),
]

# Loop 4 审的是「规格漂移会不会被抓到」：每条把 spec_json 弄成有损／错值，
# 往返判据必须变红。
#
# 纪律：变异必须**编译得过**。编译期就被拒的替换不是 review——它证明的是
# 语法错，不是判据有牙齿。首版四条用 `arr[..n]` 切片，全部死在编译期，
# 已改为计数器 + continue 的等价写法。
LOOP4 = [
    (
        "S1 状态少导出一个",
        "src/spec.mbt",
        "  for s in all_states() {\n    st_lines.push(",
        "  let mut st_n = 0\n"
        "  for s in all_states() {\n"
        "    st_n += 1\n"
        "    if st_n > 33 {\n"
        "      continue\n"
        "    }\n"
        "    st_lines.push(",
    ),
    (
        "S2 迁移少导出一条",
        "src/spec.mbt",
        "  for t in transitions() {\n    tr_lines.push(",
        "  let mut tr_n = 0\n"
        "  for t in transitions() {\n"
        "    tr_n += 1\n"
        "    if tr_n > 52 {\n"
        "      continue\n"
        "    }\n"
        "    tr_lines.push(",
    ),
    (
        "S3 迁移的 from 写成 to",
        "src/spec.mbt",
        '      "    {\\"from\\": \\"\\{t.from.designation()}\\", \\"event\\": \\"\\{t.trigger.label()}\\", \\"target\\": \\"\\{t.to.designation()}\\", \\"slot\\": \\"\\{t.trigger.slot().designation()}\\"}",',
        '      "    {\\"from\\": \\"\\{t.to.designation()}\\", \\"event\\": \\"\\{t.trigger.label()}\\", \\"target\\": \\"\\{t.to.designation()}\\", \\"slot\\": \\"\\{t.trigger.slot().designation()}\\"}",',
    ),
    (
        "S4 原文名写成定名",
        "src/spec.mbt",
        '      "    {\\"id\\": \\"\\{s.designation()}\\", \\"original\\": \\"\\{s.label()}\\", \\"phase\\": \\"\\{s.phase().designation()}\\"}",',
        '      "    {\\"id\\": \\"\\{s.designation()}\\", \\"original\\": \\"\\{s.designation()}\\", \\"phase\\": \\"\\{s.phase().designation()}\\"}",',
    ),
    (
        "S5 阶段成员漏一个",
        "src/spec.mbt",
        "    for s in all_states() {\n      if s.phase() == p {",
        "    let mut mb_n = 0\n"
        "    for s in all_states() {\n"
        "      mb_n += 1\n"
        "      if mb_n > 10 {\n"
        "        continue\n"
        "      }\n"
        "      if s.phase() == p {",
    ),
    (
        "S6 槽少导出一个",
        "src/spec.mbt",
        "  for k in all_slots() {\n    sl.push(",
        "  let mut sl_n = 0\n"
        "  for k in all_slots() {\n"
        "    sl_n += 1\n"
        "    if sl_n > 7 {\n"
        "      continue\n"
        "    }\n"
        "    sl.push(",
    ),
]

# Loop 5 审的是「验证面扩出去之后，它还站得住吗」。群体机与社会机的真表上
# 三鉴报 0 条——那正是最需要证据的时候，故这组变异全部冲这条 0 去。
LOOP5 = [
    (
        "L1 群体规格少导一条迁移",
        "audit/fleet.mbt",
        "  let transitions : Array[(String, String, String)] = []\n"
        "  for t in @g.transitions() {\n",
        "  let transitions : Array[(String, String, String)] = []\n"
        "  let mut sk_n = 0\n"
        "  for t in @g.transitions() {\n"
        "    sk_n += 1\n"
        "    if sk_n > 41 {\n"
        "      continue\n"
        "    }\n",
    ),
    (
        "L2 群体规格起点写错",
        "audit/fleet.mbt",
        "    initial: @g.initial().designation(),",
        '    initial: "孤岛",',
    ),
    (
        "L3 三鉴发现不分层（全部塞进已知设计）",
        "audit/fleet.mbt",
        "    if is_known_fleet(f) {\n      known.push(f)",
        "    if true {\n      known.push(f)",
    ),
    (
        "L4 变异网少一族",
        "audit/mutants.mbt",
        "    for kind = 0; kind < 6; kind = kind + 1 {",
        "    for kind = 0; kind < 5; kind = kind + 1 {",
    ),
    (
        "L5 「填一个不可达终点」这一族变成空操作",
        "audit/mutants.mbt",
        '    terminal = "查无此位"\n    expect = "方法错"',
        '    terminal = spec.terminal\n    expect = "方法错"',
    ),
    (
        "L6 变异网期望家族写错（条件布尔 → 方法错）",
        "audit/mutants.mbt",
        '      expect = "条件布尔"',
        '      expect = "方法错"',
    ),
    (
        "L7 「删掉一条迁移」这一族不再删",
        "audit/mutants.mbt",
        "  } else if transitions.length() < 2 {\n"
        "    // 删掉一条迁移：某处位置可能因此不再被绑定／进入／可达\n"
        "    skip = true\n"
        "  } else {\n",
        "  } else if transitions.length() < 2 {\n"
        "    // 删掉一条迁移：某处位置可能因此不再被绑定／进入／可达\n"
        "    skip = true\n"
        "  } else if false {\n",
    ),
    (
        "L8 设计图少一条接口",
        "ml/design.mbt",
        '    ("9. 与 Python 生态对接（本包已实现）", "已实现"),\n',
        "",
    ),
    (
        "L9 着色声明去掉「不实现」",
        "src/petri.mbt",
        "；本面不实现着色。",
        "；本面有颜色。",
    ),
]

GROUPS = {
    "loop1": LOOP1,
    "loop2": LOOP2,
    "loop3": LOOP3,
    "loop4": LOOP4,
    "loop5": LOOP5,
    # 单条复查用的别名，**不进默认跑**：它与 loop5 里的一条重复，默认跑带上
    # 就会在留档里出现两行同名的判定，看起来像跑了两次。
    "l3": [LOOP5[2]],
}
# 默认跑只取真正的一组一 Loop，别名要显式点名。
DEFAULT_GROUPS = ["loop1", "loop2", "loop3", "loop4", "loop5"]

SUMMARY = re.compile(r"Total tests:\s*(\d+),\s*passed:\s*(\d+),\s*failed:\s*(\d+)")

LOG_HEADER = """# 变异表判定记录（生成物，勿手改）

这张表是 `python tools/mutate_review.py` 的**输出留档**，为的是让
「每条变异都被判据抓住」这句话不必靠重跑一次破坏工作树的运行来核对。
重跑方式：`python tools/mutate_review.py`（30 条变异 × 全量测试，约 20-30 分钟；
`python tools/mutate_review.py loop3` 只跑一组）。

判读四态：
- `CAUGHT` + 失败数 > 0 —— 判据真的变红了。这是要的结果。
- `COMPILE-ERROR` —— 变异在**编译期**被拒。这**不是**抓取：它证明的是语法，
  不是判据有牙齿。首版四条 `arr[..n]` 切片死在这里，全部重写后才算数。
- `ANCHOR-ERROR` —— 源码形状与表里记的不符（改动导致锚点漂移）。不是抓取，
  得先修表。
- `SURVIVED` —— 变异活着。必须归类为「等价」或「具名缺口」，不能悬着。

纪律两条：变异必须**编译得过**（见上）；每条结束时校验 sha256 与开跑前一致
——改源码的脚本要自己证明没留痕迹。

"""


def write_log(report):
    lines = [LOG_HEADER, ""]
    lines.append("机 | 变异 | 判定 | 详情 |")
    lines.append("|---|---|---|---|")
    for name, verdict, detail in report:
        cells = [c.replace("|", "\\|") for c in (name, verdict, detail)]
        lines.append("| " + " | ".join(cells) + " |")
    with open(LOG, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def run_tests():
    proc = subprocess.run(["moon", "test"], cwd=ROOT, capture_output=True)
    text = (proc.stdout + proc.stderr).decode("utf-8", errors="replace")
    return proc.returncode, text


def main():
    wanted = sys.argv[1:] or DEFAULT_GROUPS
    table = []
    for name in wanted:
        table.extend(GROUPS[name])

    originals = {}
    hashes = {}
    for _, rel, _, _ in table:
        if rel not in originals:
            path = os.path.join(ROOT, rel)
            with open(path, "rb") as fh:
                originals[rel] = fh.read()
            hashes[rel] = hashlib.sha256(originals[rel]).hexdigest()

    report = []
    try:
        rc, text = run_tests()
        m = SUMMARY.search(text)
        report.append(
            ("BASELINE (no mutation)", "0" if rc == 0 else "rc=%d" % rc, m.group(0) if m else "no summary")
        )
        for name, rel, old, new in table:
            src = originals[rel]
            hits = src.count(old.encode("utf-8"))
            if hits != 1:
                report.append((name, "ANCHOR-ERROR", "%s occurs %d times" % (rel, hits)))
                continue
            with open(os.path.join(ROOT, rel), "wb") as fh:
                fh.write(src.replace(old.encode("utf-8"), new.encode("utf-8"), 1))
            rc, text = run_tests()
            m = SUMMARY.search(text)
            if m:
                verdict = "CAUGHT" if int(m.group(3)) > 0 else "SURVIVED"
                detail = m.group(0)
            else:
                # 编译错**不算**抓住：它证明的是语法，不是判据有牙齿。留成
                # ANCHOR/COMPILE 两态让人看见，而不是并进 CAUGHT 里好看。
                verdict = "COMPILE-ERROR" if rc != 0 else "SURVIVED"
                detail = "compile error rc=%d (NOT a catch)" % rc
            report.append((name, verdict, detail))
    finally:
        for rel, blob in originals.items():
            with open(os.path.join(ROOT, rel), "wb") as fh:
                fh.write(blob)

    for rel, digest in hashes.items():
        with open(os.path.join(ROOT, rel), "rb") as fh:
            same = hashlib.sha256(fh.read()).hexdigest() == digest
        report.append(("RESTORED " + rel, "OK" if same else "HASH-MISMATCH", digest[:16]))

    write_log(report)
    for name, verdict, detail in report:
        print("%-46s %-14s %s" % (name, verdict, detail))

    # 退出码：有任何一条不是「判据红了」就算不合格。这样它能进 CI，而不是
    # 只在有人记得看输出时才有意义。
    bad = [n for (n, v, _) in report if v not in ("CAUGHT", "OK") and not n.startswith("BASELINE")]
    survived = [n for (n, v, _) in report if v == "SURVIVED"]
    if survived:
        print("\nSURVIVED (must be classified, not left hanging):")
        for n in survived:
            print("  - " + n)
    if bad:
        print("\nFAIL: %d mutation(s) did not turn the criteria red." % len(bad))
        return 1
    print("\nOK: every mutation turned at least one criterion red; sources restored.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
