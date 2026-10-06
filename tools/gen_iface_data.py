"""把本仓库真实的 .mbti 快照成一张 MoonBit 数据表（生成物，勿手改）。

为什么要有这一层：wasm／JS 侧不能读盘，所以 `audit` 的接口面若要在 agent 可见的
面上**真扫**，就得把接口内容带进 wasm 侧。带进来之后，「快照会不会过期」就从一个
隐患变成一个必须回答的问题——本脚本连同 `tools/ifacescan` 的 native 判据一起回答：
快照与磁盘逐字节相等，不等就红。

用法：
    python tools/gen_iface_data.py

生成后跑门禁：
    moon check && moon fmt --check && moon test
    moon test --target native tools/ifacescan
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audit", "iface_data.mbt")

# 与 tools/ifacescan/scan.mbt 的 skipped() **必须一致**——不一致的话两边会
# 审到不同的文件集合，而漂移判据会误报（或漏报）。改一处就改两处。
SKIP = {
    "_build",
    ".mooncakes",
    ".git",
    "target",
    "node_modules",
    ".openseek",
    ".mavis",
    ".idea",
    ".vscode",
}


def walk():
    out = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP]
        for name in filenames:
            if name.endswith(".mbti"):
                full = os.path.join(dirpath, name)
                rel = os.path.relpath(full, ROOT).replace("\\", "/")
                out.append((rel, full))
    out.sort()
    return out


def lit(text):
    """把内容编成一个单行 MoonBit 字符串字面量。"""
    esc = text.replace("\\", "\\\\").replace('"', '\\"')
    esc = esc.replace("\r\n", "\n").replace("\n", "\\n").replace("\t", "\\t")
    return '"' + esc + '"'


HEADER = '''///|
/// **生成物，勿手改。** 改法：先改 `.mbti`（通常由 `moon info` 生成），再跑
/// `python tools/gen_iface_data.py`。
///
/// 本表是本仓库全部 `pkg.generated.mbti` 的**逐字节快照**。它存在的唯一理由是
/// 让接口面能进 wasm／JS 侧（那里读不了盘），从而对**真内容**给出真计数，而不是
/// 对一份样例报「0 发现」——那会让一个没测过的东西看起来像被测过了。
///
/// 代价是快照会过期。对付办法不是小心，是判据：`tools/ifacescan` 的 native 测试
/// 逐字节比对「本表 ≡ 磁盘上的真文件」，`moon info` 一改就红。
///
/// 排版：`audit/moon.pkg` 里把本文件列进 `formatter(ignore:)`——一屏一行的长字符串
/// 字面量，格式化器改它只会徒增 diff 噪声。
'''


def main():
    rows = walk()
    if not rows:
        sys.exit("没找到任何 .mbti——生成器不该在这种情况下写出空表。")
    body = [HEADER, "///|", "/// 本表里的每一行：(相对路径, 原文)。", "pub fn iface_snapshot() -> Array[(String, String)] {", "  ["]
    for rel, full in rows:
        with open(full, "r", encoding="utf-8", newline="") as fh:
            src = fh.read()
        body.append("    (%s, %s)," % (lit(rel), lit(src)))
    body.append("  ]")
    body.append("}")
    body.append("")
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(body))
    total = sum(len(open(f, "rb").read()) for _, f in rows)
    print("wrote %s: %d files, %d bytes of .mbti" % (OUT, len(rows), total))


if __name__ == "__main__":
    main()
