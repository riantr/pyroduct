# pyroduct-model（本地 MiniMax 插件）

把 [riantr/pyroduct](https://gitee.com/ren-yongxiang/pyroduct) 变成 MiniMax Code 的
本地插件：一个技能（读法纪律 + 取事实的次序）＋ 一个 MCP server（三个只读工具）。

## 它暴露什么

| 能力 | 名字 | 做什么 |
|---|---|---|
| Skill | `skills/pyroduct-model/SKILL.md` | 读法纪律（未定不是失败／无路是数据／出处两层／绊线是零）、取事实的次序、三尺度术语表参考 |
| MCP | `pyroduct` | `pyroduct_faces`（30 面目录）、`pyroduct_face(kind)`（跑一个面取全文）、`pyroduct_gates`（模块门禁套件） |

## 源码与安装目录

本包有两份：仓库 `riantr/pyroduct` 的 `plugin/` 是真相源，本机数据目录
`~/.minimax/plugins/pyroduct-model/`（`.mavis` 是它的 junction）是安装副本——
Desktop 只读后者。两份用 `plugin/tools/sync-install.mjs` 对齐，**方向是参数不是猜测**：

```console
node plugin\tools\sync-install.mjs push [checkout]   # 仓库 -> 安装目录（安装）
node plugin\tools\sync-install.mjs pull               # 安装目录 -> 仓库（把在数据目录里的改动收回来）
```

`vendor/jsoncli.js`（1.1 MB 的桥）不当文本搬：它不入版本控制（仓库 `.gitignore`
排除），由 `moon build --target js` 生成。`push` 若带了 checkout 参数，会接着调
`tools/update-bundle.mjs` 重建、重钉、跑回归。

`push` 装之前先核对 `vendor/BUILD.json` 里记的 SHA-256 与磁盘文件——对不上就拒绝
安装并退出 1，因为模型语义就装在那个文件里。`pull` 与 `push` 都会删掉源里已不存在
的文件，免得改名之后留下一个还在被加载的旧 `server.mjs` 或旧参考。

## 形态：spawner，不是第二实现

`server.mjs` 只做三件事——spawn `cmd/jsoncli` 的 JS bundle、把回信里的 `rendered`
当文本输出、在输入不合法时说清楚。**模型语义一条都不在插件里**：全部留在 MoonBit 侧，
随模块定版与门禁（`moon check` + `moon fmt --check` + `moon test`）。桥自己也是一个
纯 spawner：一个 `{kind}` JSON 请求入、一行 `{ok,kind,rendered,faces}` JSON 回信出。

## 两种回答来源

| 来源 | 条件 | 说明 |
|---|---|---|
| 内置快照 | 默认 | `vendor/jsoncli.js`（随插件定版，出处与哈希记在 `vendor/BUILD.json`）。不需要 MoonBit 工具链，装完即用；机器是只读的 |
| 本地 checkout | 设 `PYRODUCT_PROJECT_DIR` | 用该 checkout 的 `_build/js/.../jsoncli.js`，缺则自动 `moon build --target js`；`pyroduct_gates` 也在这个 checkout 里跑 |

**checkout 配错时两个工具故意不一样**：`pyroduct_gates` 直接失败并说清「根目录没有
moon.mod」＋那个目录的顶层是什么——门禁在别处跑过等于撒谎；`pyroduct_face` 与
`pyroduct_faces` 则回落到内置快照，并在正文顶部标一行 `⚠` 写明回落到哪个模型版本，
因为只读事实不该因为一个错路径就取不到，但版本必须说出来。

其它环境变量：`PYRODUCT_MOON`（moon 可执行）、`PYRODUCT_NODE`（跑 bundle 的 Node，
默认用当前解释器）。

**前置条件**：PATH 上有 `node`，且版本 ≥ 18（`server.mjs` 与 `tools/` 都是 ESM，用到
`import.meta.url`；更低版本会在加载时就报错）。走 checkout 路径还需要 `moon`。

## 呈现层不在工具里

`viz` 合成页、`journey` 行程视图、`nested-mermaid`、`all` 组合**不走桥**——它们是渲染，
不是模型事实。工具面的 30 面清单里没有它们，这是有意的取舍（见技能里的
[参考/工具与面目录](skills/pyroduct-model/references/tools.md)）。有 checkout 时用
`moon run cmd/main -- viz` 一类命令。

## 终端里直接取一面

桥收的是**一个 JSON 对象参数**，而 Windows 的 PowerShell 会把行内引号吃掉——
`node vendor\jsoncli.js '{"kind":"petri"}'` 到桥那边成了 `{kind:petri}`，回你一句
`bad request: Invalid character 'k'`（只有 `cmd /c node vendor\jsoncli.js
"{\"kind\":\"petri\"}"` 能活）。所以插件带了个不用跟引号较劲的壳：

```console
node tools\face.mjs --list          # 30 个面
node tools\face.mjs petri            # 该面报告全文
node tools\face.mjs --raw aho        # 完整 JSON 信封 {ok,kind,rendered,faces}
```

在 MiniMax Code 里用不到它——MCP server 是在 Node 里拼 argv 的，没这个坑。

## 更新内置快照

一条命令，剩下它自己走完：

```console
node tools\update-bundle.mjs D:\src\DeepseekHarness\Projects\pyroduct
```

它依次：`moon build --target js` → 复制 `jsoncli.js` → 重写 `vendor/BUILD.json`
（version 取自 `moon.mod`、builtWith 取自 `moon --version`、bytes 与 **SHA-256**）→
跑 `tools/validate-plugin.mjs`。模型改了但那些不变量没跟上时，这一步就会红，
不用等到下一次发版才发现。`plugin.json` 的 `version` 仍需你手动按 SemVer 提
——脚本不替你决定发版号。

**为什么钉哈希**：模型语义就装在那个 bundle 里，谁手滑改了它，
`tools/validate-plugin.mjs` 第一件事就是比对 `vendor/BUILD.json` 的 `bundleSha256`
与磁盘文件（外加字节数、`manifest` 与 `server.mjs` 的版本是否一致），不一致直接退出 1，
在任何报告被采信之前。

## 自带的回归网

```console
node tools\validate-plugin.mjs
```

26 条：哈希钉 → 真 MCP 握手与三个工具（9 条）→ 30 个面全渲染 → 22 条内容不变量
（含 `audit` 的「未预期 0 条」这条绊线与 `fleet` 的两条口径说明）→ 反漂移规则（3 条）
→ checkout 守卫的**阳性对照**（3 条）。

最后一条是重点：守卫若没人触发就只是一句没人验过的声明。回归网会用一个故意错的
`PYRODUCT_PROJECT_DIR` 再起一个 server，断言 `pyroduct_gates` 硬失败而
`pyroduct_face` 回落并标注——没有这个对照，「守卫存在」和「守卫是 no-op」在输出上
长得一模一样。

反漂移规则的来历：`report` 与 `naming` 的工具说明曾按印象写成「带页码出处」／
「带出处层」，而那两面一个页码、一个层标注都不印。规则是——目录里任何一行若声称
某面带页码出处，那一面就必须真的印出 `P.xx`；带页码的面钉成闭集
（`group`／`intuition`／`multi`／`society`），多一个少一个都失败。

`tools/` 不在 `plugin.json` 的能力清单里，Desktop 不会加载它；它只是改包之后
该跑的那道网。

## 出处

插件形态参照随 `riantr/moonbit_static_analysis` 发布的 dsh 插件（spawner + 格式化、
一个 JSON 桥）与本仓库自带的 `riantr/dsh-plugin-pyroduct`。每个 pyroduct 事实都留在
riantr/pyroduct 里；插件不放事实。

MIT。
