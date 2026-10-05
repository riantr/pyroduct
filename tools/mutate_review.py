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
    "loop3": LOOP3,
    "loop4": LOOP4,
    "loop5": LOOP5,
    # 单条复查用：L3 首轮存活（真表 0 发现 ⇒ 分层与不分层输出一致），
    # 补了「试造发现」的分层判据后重跑。
    "l3": [LOOP5[2]],
}

SUMMARY = re.compile(r"Total tests:\s*(\d+),\s*passed:\s*(\d+),\s*failed:\s*(\d+)")


def run_tests():
    proc = subprocess.run(["moon", "test"], cwd=ROOT, capture_output=True)
    text = (proc.stdout + proc.stderr).decode("utf-8", errors="replace")
    return proc.returncode, text


def main():
    wanted = sys.argv[1:] or list(GROUPS)
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
                verdict = "CAUGHT" if rc != 0 else "SURVIVED"
                detail = "compile error rc=%d" % rc
            report.append((name, verdict, detail))
    finally:
        for rel, blob in originals.items():
            with open(os.path.join(ROOT, rel), "wb") as fh:
                fh.write(blob)

    for rel, digest in hashes.items():
        with open(os.path.join(ROOT, rel), "rb") as fh:
            same = hashlib.sha256(fh.read()).hexdigest() == digest
        report.append(("RESTORED " + rel, "OK" if same else "HASH-MISMATCH", digest[:16]))

    for name, verdict, detail in report:
        print("%-46s %-14s %s" % (name, verdict, detail))
    return 0


if __name__ == "__main__":
    sys.exit(main())
