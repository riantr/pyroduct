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
        # 打在**纯函数**上，不是包一层取料的那层。真表上 `no_dead_end` 恒为
        # true，所以只把 `no_dead_end()` 改成恒真，真表照样通过——牙齿在
        # `no_dead_end_of` 上，测试用造出来的「有位置没出边」驱动它。
        "B4 group::no_dead_end_of 恒真（不封闭的检查不再跑）",
        "group/loop.mbt",
        "for s in states {\n    if !froms.contains(s) {",
        "if true {\n    return true\n  }\n  for s in states {\n    if !froms.contains(s) {",
    ),
    (
        "B5 society::one_edge_each 去掉去重（触发粒度的确定性不再被锁）",
        "society/loop.mbt",
        "    if dup {\n      return false\n    }\n    seen.push(p)",
        "    if dup {\n      ()\n    }\n    seen.push(p)",
    ),
    (
        "B6 society::no_dead_end_of 恒真（不封闭的检查不再跑）",
        "society/loop.mbt",
        "for s in states {\n    if !froms.contains(s) {",
        "if true {\n    return true\n  }\n  for s in states {\n    if !froms.contains(s) {",
    ),
]

# P 组：空判据普查。
#
# B4 那次抓到的是一个**形状**而不是一条变异：零参数的性质谓词在真表上恒为
# true，它那条 `return false` 臂不可达，而唯一的判据是 `assert_true(那个调用)`
# ——于是把函数改成恒真，一条测试都不会红。修好 B4/B5/B6 之后我按这个形状把
# 全仓的谓词扫了一遍，又查出六处同形的空判据（详见 P1~P6 的注释）。这六条的
# 锚点一律打在**有牙齿的那一层**（纯函数），不打只包一层取料的外壳。
PROPS = [
    (
        "P1 src::exitable 恒真（缺口那侧不再被认出来）",
        "src/loop.mbt",
        "pub fn exitable(state : SubjectState, slot : Slot) -> Bool {\n  let mut found = false",
        "pub fn exitable(state : SubjectState, slot : Slot) -> Bool {\n  if true {\n    return true\n  }\n  let mut found = false",
    ),
    (
        "P2 src::every_phase_has_non_act_of 恒真",
        "src/loop.mbt",
        "  for p in phases {\n    if !covered.contains(p) {",
        "  if true {\n    return true\n  }\n  for p in phases {\n    if !covered.contains(p) {",
    ),
    (
        "P3 src::any_returns_to 恒真（非空性不再被检查）",
        "src/buchi.mbt",
        "  for u in reachable {\n    if back.contains(u) {",
        "  if true {\n    return true\n  }\n  for u in reachable {\n    if back.contains(u) {",
    ),
    (
        "P4 src::all_covered 恒真（活性潜势不再被检查）",
        "src/buchi.mbt",
        "  for s in states {\n    if !covered.contains(s) {",
        "  if true {\n    return true\n  }\n  for s in states {\n    if !covered.contains(s) {",
    ),
    (
        # 这条与别处不同：委托之后**恒真反而是等价的**（表本来就确定），恒真变异
        # 会存活。所以打**反相**：答案必须真来自那次检查，不能是写死的。
        "P5 src::is_deterministic 反相（答案不是来自那次检查）",
        "src/paths.mbt",
        "pub fn is_deterministic() -> Bool {\n  one_edge_per_trigger()",
        "pub fn is_deterministic() -> Bool {\n  !one_edge_per_trigger()",
    ),
    (
        "P6 society::no_final_closure_of 恒真（两条 false 臂都不再跑）",
        "society/state.mbt",
        "  if terminal.length() > 0 {\r\n    return false\r\n  }",
        "  if true {\r\n    return true\r\n  }\r\n  if terminal.length() > 0 {\r\n    return false\r\n  }",
    ),
    (
        "P7 group::resolve_open 两种偏向取同一条（能耗原则不成立）",
        "group/loop.mbt",
        "      let to = match lean {\n        Supra => cands[0]\n        Inter => cands[cands.length() - 1]\n      }",
        "      let to = cands[0]\n      match lean {\n        Supra => ()\n        Inter => ()\n      }",
    ),
    (
        "P8 evolution::group_lean_of 偏向反相（双诚之比读反了）",
        "evolution/cycle.mbt",
        "  if toward_other > toward_self {\n    @g.Inter",
        "  if toward_self >= toward_other {\n    @g.Inter",
    ),
    (
        "P9 震荡边只剩单向（共语上不再冒出有效性主张）",
        "group/machine.mbt",
        "    { from: CommonTongue, trigger: RaiseClaims, to: Discourse, },\r\n    { from: Discourse, trigger: SharedMedium, to: CommonTongue, },\r\n",
        "",
    ),
    (
        "P10 震荡边接反（超体与间体倒置）",
        "group/machine.mbt",
        "    { from: CommonTongue, trigger: RaiseClaims, to: Discourse, },\r\n    { from: Discourse, trigger: SharedMedium, to: CommonTongue, },",
        "    { from: CommonTongue, trigger: SharedMedium, to: Discourse, },\r\n    { from: Discourse, trigger: RaiseClaims, to: CommonTongue, },",
    ),
    (
        "P11 社会两相震荡只剩单向（超体上不再冒出有效性主张）",
        "society/state.mbt",
        "    { from: Suprasubjective, trigger: RaiseClaims, to: Intersubjective, },\r\n    { from: Intersubjective, trigger: SpeakLanguage, to: Suprasubjective, },\r\n",
        "",
    ),
    (
        "P12 社会两相震荡边接反（超体与间体倒置）",
        "society/state.mbt",
        "    { from: Suprasubjective, trigger: RaiseClaims, to: Intersubjective, },\r\n    { from: Intersubjective, trigger: SpeakLanguage, to: Suprasubjective, },",
        "    { from: Suprasubjective, trigger: SpeakLanguage, to: Intersubjective, },\r\n    { from: Intersubjective, trigger: RaiseClaims, to: Suprasubjective, },",
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
    "props": PROPS,
    # 单条复查用的别名，**不进默认跑**：它与 loop5 里的一条重复，默认跑带上
    # 就会在留档里出现两行同名的判定，看起来像跑了两次。
    "l3": [LOOP5[2]],
}
# 默认跑只取真正的一组一 Loop，别名要显式点名。
DEFAULT_GROUPS = ["loop1", "loop2", "loop3", "loop4", "loop5", "props"]

# 变异条数**由表算出来**，不写死。我在这份头部里写死过「30 条」，而表里其实
# 是 34 条（A5+B5+M9+S6+L9）——写死的数字在表增长时不会跟着动，漂了也没人知道。
# 硬写的计数本身就是一处会骗人的判据。
MUT_COUNT = sum(len(GROUPS[n]) for n in DEFAULT_GROUPS)

SUMMARY = re.compile(r"Total tests:\s*(\d+),\s*passed:\s*(\d+),\s*failed:\s*(\d+)")

LOG_HEADER = """# 变异表判定记录（生成物，勿手改）

这张表是 `python tools/mutate_review.py` 的**输出留档**，为的是让
「每条变异都被判据抓住」这句话不必靠重跑一次破坏工作树的运行来核对。
重跑方式：`python tools/mutate_review.py`（%d 条变异 × 全量测试，约 20-30 分钟）。
本文件**只由全量跑生成**。`python tools/mutate_review.py loop3` 这样的单组跑会
另写 `mutation_review_log.loop3.md`，不会碰这份——单组跑曾经把这份全量记录
覆盖成自己那几行，而我把截断版提交了；工具静默毁掉自己的记录比没有工具更糟。

判读五态：
- `CAUGHT` + 失败数 > 0 —— 判据真的变红了。这是要的结果。
- `COMPILE-ERROR` —— 变异在**编译期**被拒。这**不是**抓取：它证明的是语法，
  不是判据有牙齿。首版四条 `arr[..n]` 切片死在这里，全部重写后才算数。
- `ANCHOR-ERROR` —— 源码形状与表里记的不符（改动导致锚点漂移）。不是抓取，
  得先修表。
- `LEAK-ERROR` —— 施加这条之前工作树就不干净，说明上一条没还原。不是判定，
  是 harness 的错；它存在是为了让那种错当场炸，而不是静默产出假数字。
- `SURVIVED` —— 变异活着。必须归类为「等价」或「具名缺口」，不能悬着。

纪律三条：变异必须**编译得过**（见上）；每条必须在**干净**的工作树上测
（换文件的条目不还原上一条，失败会算到别人头上——B4 曾记着 A5 的 failed=3）；
每条结束时校验 sha256 与开跑前一致——改源码的脚本要自己证明没留痕迹。

""" % MUT_COUNT


def render_log(report, full_run, groups):
    """Render the record to text. Split out from write_log on purpose.

    Anything that needs to reproduce the file must go through HERE, not through
    a second copy of the layout. I once rebuilt the header by hand and produced
    a file that was self-consistent and wrong: one blank line after the header
    where the generator writes three. A hand-rolled reconstruction that checks
    itself against itself proves nothing — only this function defines the truth.
    """
    lines = [LOG_HEADER, ""]
    if not full_run:
        lines.insert(
            1,
            "> **这是单组跑的留档（%s），只覆盖本次跑的那几组。**"
            "全量记录在 `mutation_review_log.md`，本次运行**没有**覆盖它。"
            % ", ".join(groups),
        )
    lines.append("机 | 变异 | 判定 | 详情 |")
    lines.append("|---|---|---|---|")
    for name, verdict, detail in report:
        cells = [c.replace("|", "\\|") for c in (name, verdict, detail)]
        lines.append("| " + " | ".join(cells) + " |")
    return "\n".join(lines) + "\n"


def write_log(report, full_run, groups):
    """Write the verdict record — but a PARTIAL run must not clobber the full one.

    I once re-ran `loop1` alone to double-check two mutations after restoring a
    refactor, and it overwrote the committed full record with its own few rows.
    Then I committed that. A tool that silently truncates its own evidence is
    worse than no tool: the record looked authoritative and was wrong.

    So: the full run owns mutation_review_log.md; a partial run writes
    mutation_review_log.<groups>.md instead and says so out loud.
    """
    if full_run:
        path = LOG
    else:
        tag = "-".join(groups)
        path = os.path.join(ROOT, "tools", "mutation_review_log.%s.md" % tag)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(render_log(report, full_run, groups))
    print("wrote " + os.path.relpath(path, ROOT))
    if not full_run:
        print(
            "NOTE: partial run — the full record in mutation_review_log.md was "
            "left untouched (a partial run used to overwrite it; that silently "
            "truncated the committed evidence once already)."
        )


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

    def restore_all():
        for rel, blob in originals.items():
            with open(os.path.join(ROOT, rel), "wb") as fh:
                fh.write(blob)

    def dirty_files():
        """源文件里当前与开跑前不一致的那些——只该是本条变异动过的那一个。"""
        out = []
        for rel, blob in originals.items():
            with open(os.path.join(ROOT, rel), "rb") as fh:
                if fh.read() != blob:
                    out.append(rel)
        return out

    try:
        rc, text = run_tests()
        m = SUMMARY.search(text)
        report.append(
            ("BASELINE (no mutation)", "0" if rc == 0 else "rc=%d" % rc, m.group(0) if m else "no summary")
        )
        for name, rel, old, new in table:
            # 每条都在**干净**的工作树上测。这一条不是洁癖：还原原先只发生在
            # 最外层 finally，于是换文件的条目会带着上一个文件的变异跑。
            # B4 因此记了 failed=3，而那 3 条其实是还挂在 src/loop.mbt 上的
            # A5 留下的——B4 单独跑其实是 failed=0，一条**等价变异**，
            # 却因为别人的失败而记成 CAUGHT。数字对不上，判据却看着有牙齿。
            leaked = dirty_files()
            if leaked:
                report.append(
                    (name, "LEAK-ERROR", "working tree dirty before mutation: %s" % ", ".join(leaked))
                )
                restore_all()
                continue
            src = originals[rel]
            hits = src.count(old.encode("utf-8"))
            if hits != 1:
                report.append((name, "ANCHOR-ERROR", "%s occurs %d times" % (rel, hits)))
                continue
            with open(os.path.join(ROOT, rel), "wb") as fh:
                fh.write(src.replace(old.encode("utf-8"), new.encode("utf-8"), 1))
            try:
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
                # 立刻还原，让下一条从干净状态起跑。
                with open(os.path.join(ROOT, rel), "wb") as fh:
                    fh.write(src)
    finally:
        restore_all()

    for rel, digest in hashes.items():
        with open(os.path.join(ROOT, rel), "rb") as fh:
            same = hashlib.sha256(fh.read()).hexdigest() == digest
        report.append(("RESTORED " + rel, "OK" if same else "HASH-MISMATCH", digest[:16]))

    # 「全量」= 没点名任何组。传了组名就是部分跑，留档另写，不覆盖全量记录。
    write_log(report, not sys.argv[1:], wanted)
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
