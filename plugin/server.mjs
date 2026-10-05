#!/usr/bin/env node
/**
 * pyroduct-model — local MiniMax Plugin MCP server.
 *
 * Exposes the riantr/pyroduct philosophy state-machine family as plain MCP
 * tools. Like the shipped dsh plugin, it is **a spawner and a formatter,
 * never a second implementation**: every model fact comes out of the module's
 * own `cmd/jsoncli` bridge, a Node-runnable JS bundle produced by
 * `moon build --target js`.
 *
 * Bridge resolution order (first hit wins):
 *   1. `PYRODUCT_PROJECT_DIR` set  -> <dir>/_build/js/.../jsoncli.js,
 *      built on first use with `moon build --target js` (needs `moon` on PATH);
 *      this same checkout is what `pyroduct_gates` runs the module gate in.
 *   2. no checkout configured      -> the bundled snapshot `vendor/jsoncli.js`,
 *      so the plugin works with no MoonBit toolchain at all.
 *
 * stdout carries JSON-RPC only; every diagnostic goes to stderr.
 */
import { spawn } from 'node:child_process'
import { existsSync, readFileSync, readdirSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const PLUGIN_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)))
const BUNDLED_BRIDGE = path.join(PLUGIN_ROOT, 'vendor', 'jsoncli.js')
const BRIDGE_RELATIVE = path.join('_build', 'js', 'debug', 'build', 'cmd', 'jsoncli', 'jsoncli.js')
const PROVENANCE_FILE = path.join(PLUGIN_ROOT, 'vendor', 'BUILD.json')

const SERVER_NAME = 'pyroduct-model'
const SERVER_VERSION = '0.2.0'
const DEFAULT_TIMEOUT_MS = 120_000
const GATE_TIMEOUT_MS = 900_000

/**
 * The bridge's face catalog with one reading line each — mirrors the bridge's
 * own `faces()` (anti-drift) and gives the model a reason to pick one face
 * over another. Presentation-only views (`viz`, `journey`, nested, `all`) are
 * deliberately absent: they are rendering, not model facts.
 */
const FACES = [
  ['report', '主体机全表：34 位置 · 53 迁移 · 11 阶段，逐行列位置定名与原文措辞，末节「派生表与持久度」给出处层。默认面，先读它。'],
  ['slots', '49 条触发句 → 8 个驱动槽（处境6·取向6·先行4·行动9·反馈8·持存8·共在3·揭蔽5）。'],
  ['loop', '位置 × 槽的执行契约：迁／守／未定／无路；272 组合中 228 个无路（缺口即数据）。'],
  ['multi', '两个主体的一次遭遇：体制 × 两诚 × 有效性主张时序 → 判词（R1–R14 规范规则）。'],
  ['group', '群体涌现机（20 状态）：成员配置 → 群体状态，R7 回写。'],
  ['society', '双层次社会交往机（13 状态）：生活世界 vs 系统。'],
  ['evolution', 'Agent 层：基因型／变异／适应度／宪法／闸门／只追加账本。'],
  ['cycle', '主体循环：位置 × 驱动槽 → 修习与开放两个候选过同一个因果闸门。'],
  ['coordinator', '科研 Agent 协调器：制品／规划／外部证据（按置信区间）／内容记忆／信用。'],
  ['dmlref', '自研 DoubleML 与 riantr/moonbit_doubleML@0.75.0 的互校（θ̂ 差、se 差）。'],
  ['causal', '0.75.0 深用诊断（模型整理）：敏感性 rv、多重检验 BH/Bonferroni、BLP 异质性。'],
  ['audit', '三鉴自审计（模型整理）：结构鉴／类型鉴／行为鉴；已知设计 4 条、未预期 0 条。'],
  ['fleet', '三鉴自审计扩到另两台机（模型整理）：群体 20 状态·44 迁移、社会 13 状态·28 迁移；两台机无驱动槽、无终点，故类型鉴的槽层整层跳过；未预期 0 条且不设豁免。'],
  ['mutants', '迁移表变异网（模型整理）：三台机×六族破坏共 18 处，逐处被抓到且家族对得上——「0 条发现」需要证据才站得住。'],
  ['mermaid', '主体机 Mermaid stateDiagram-v2 源码。'],
  ['dot', '主体机 Graphviz dot 源码。'],
  ['genesis', '主线：从开端到持住的环节序列。'],
  ['course', '环节序列：最小商的分块数恰等于它的长度。'],
  ['naming', '定名对照表：两字定名｜原文名｜原文措辞（这一面不带层标注，也不带页码）。引用具体位置时取这一行。'],
  ['principle', '主体机的通用性原则（revision_principle）。'],
  ['intuition', '直觉读法（模型整理）：备忘录读成背景直觉的仓库。'],
  ['ml', '自研 DoubleML 接口与因果实验说明：PLR／交叉拟合／正交得分。'],
  ['ml-export', '因果数据集 CSV 预览（make_dataset(200, 1.5, 7) 的前 12 行）。'],
  ['spec', '主体机即 JSON 数据（states／phases／slots／transitions）＋词汇表防漂移。'],
  ['association', '未定的软关联（JPDA 面镜像）：β 权重／香农熵／argmax 一致性（诊断，不采样）。'],
  ['pathsum', '泛半环路径和（tropical）：通往宁静的最短步阶梯 ＋ 性质谓词。'],
  ['algebra', '机器代数（Ragel 面）：算子映射／主线分解／最小商（31 块）。'],
  ['petri', 'Petri 网面（CarlAdam 镜像）：库所 34／变迁 53／标识／发火／托肯守恒。'],
  ['aho', '回忆结构（Aho-Corasick 面）：触发句前缀树／失败链／输出合并。'],
  ['buchi', 'ω-视角（Büchi 面）：非空性／活性潜势／停滞词——结构不强迫活性。'],
]

const FACE_KINDS = FACES.map(([kind]) => kind)

/** Provenance of the bundled snapshot, as data so it cannot drift silently. */
function bundledProvenance() {
  try {
    return JSON.parse(readFileSync(PROVENANCE_FILE, 'utf8'))
  } catch {
    return null
  }
}

/** Configured checkout, if any. Everything optional is an env override. */
function projectDirOf() {
  const dir = process.env.PYRODUCT_PROJECT_DIR
  if (typeof dir !== 'string' || dir.trim().length === 0) return null
  return path.resolve(dir.trim())
}

/**
 * A configured path that is not a MoonBit module would otherwise surface as a
 * bare `moon check` failure ("moon.mod not found"), which reads like a broken
 * toolchain rather than a mistyped path. Name the actual problem instead, and
 * show what the directory does contain.
 */
function assertMoonbitCheckout(projectDir) {
  if (existsSync(path.join(projectDir, 'moon.mod'))) return
  let listing = []
  try {
    listing = readdirSync(projectDir).slice(0, 12)
  } catch {
    listing = []
  }
  const detail = listing.length > 0 ? listing.join('、') : '（空目录，或不可读）'
  throw new Error(
    `PYRODUCT_PROJECT_DIR 指向的目录不像 MoonBit 模块：${projectDir}（根目录没有 moon.mod；顶层：${detail}）。` +
      '要么改成 riantr/pyroduct 的 checkout，要么清掉这个环境变量改用内置快照。',
  )
}

/** A runnable Node: the interpreter already running this file is the safest one. */
function nodePathOf() {
  const override = process.env.PYRODUCT_NODE
  if (typeof override === 'string' && override.length > 0 && existsSync(override)) return override
  return process.execPath
}

/** Resolve the moon binary; CreateProcess appends .exe on Windows. */
function moonPathOf() {
  const override = process.env.PYRODUCT_MOON
  if (typeof override === 'string' && override.length > 0) return override
  return 'moon'
}

/** One spawned process: collected stdout/stderr, exit code, abort support. */
function runProcess(command, args, options) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      windowsHide: true,
      env: process.env,
      ...(options.signal ? { signal: options.signal } : {}),
    })
    let stdout = ''
    let stderr = ''
    const timer = setTimeout(() => child.kill(), options.timeoutMs ?? DEFAULT_TIMEOUT_MS)
    child.stdout.on('data', (chunk) => {
      stdout += chunk
    })
    child.stderr.on('data', (chunk) => {
      stderr += chunk
    })
    child.on('error', (error) => {
      clearTimeout(timer)
      reject(error)
    })
    child.on('close', (code, signal) => {
      clearTimeout(timer)
      resolve({ code, signal, stdout, stderr })
    })
  })
}

/**
 * Resolve the bridge to run. A configured checkout wins and is built on first
 * use; otherwise the bundled snapshot is returned as-is (never built, never
 * mutated).
 */
async function resolveBridge(projectDir) {
  if (projectDir === null) {
    if (!existsSync(BUNDLED_BRIDGE)) {
      throw new Error(`bundled bridge missing: ${BUNDLED_BRIDGE}`)
    }
    return { bridge: BUNDLED_BRIDGE, source: 'bundled' }
  }
  const bridge = path.join(projectDir, BRIDGE_RELATIVE)
  // A mistyped or stale PYRODUCT_PROJECT_DIR must not cost the model its facts:
  // reading is read-only, so fall back to the bundled snapshot and carry the
  // reason along instead of failing. `pyroduct_gates` has no such fallback and
  // still hard-fails — a gate that silently ran elsewhere would be a lie.
  try {
    assertMoonbitCheckout(projectDir)
  } catch (error) {
    if (!existsSync(BUNDLED_BRIDGE)) throw error
    return {
      bridge: BUNDLED_BRIDGE,
      source: 'fallback',
      warning: `${error.message} 本次已回落到内置快照（模型 ${bundledProvenance()?.version ?? '记档缺失'}，非该 checkout）。`,
    }
  }
  if (existsSync(bridge)) return { bridge, source: 'checkout' }
  const build = await runProcess(moonPathOf(), ['build', '--target', 'js'], {
    cwd: projectDir,
    timeoutMs: GATE_TIMEOUT_MS,
  })
  if (!existsSync(bridge)) {
    const detail = `${build.stderr}\n${build.stdout}`.trim().slice(0, 400)
    throw new Error(
      `jsoncli bridge missing after 'moon build --target js' in ${projectDir}: ${detail || 'no output'}`,
    )
  }
  return { bridge, source: 'checkout' }
}

/** One JSON request through the bridge; replies are parsed JSON envelopes. */
async function callBridge(projectDir, request, signal) {
  const { bridge, source, warning } = await resolveBridge(projectDir)
  const result = await runProcess(nodePathOf(), [bridge, JSON.stringify(request)], {
    cwd: projectDir ?? PLUGIN_ROOT,
    timeoutMs: DEFAULT_TIMEOUT_MS,
    signal,
  })
  const line = result.stdout.trim().split('\n').pop() ?? ''
  let reply
  try {
    reply = JSON.parse(line)
  } catch {
    const detail = line.slice(0, 200) || result.stderr.trim().slice(0, 200)
    throw new Error(`bridge reply unparseable (exit ${result.code}): ${detail || 'no output'}`)
  }
  if (reply.ok !== true) {
    throw new Error(`bridge reported failure: ${String(reply.error ?? 'unknown error')}`)
  }
  return { ...reply, source, warning: warning ?? null }
}

const TOOLS = [
  {
    name: 'pyroduct_faces',
    description:
      'Catalog of the pyroduct analysis faces: the 28 runnable views of the philosophy state-machine family, each with one reading line, plus which bridge answered (bundled snapshot or a local checkout) and the module version it was built from. Call this first when you need to know which face answers a question — it is the index, not the content.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
    readOnly: true,
  },
  {
    name: 'pyroduct_face',
    description:
      '跑一个 pyroduct 分析面，返回该面报告全文。面：report（34 状态 · 53 迁移 · 11 阶段，各阶段下列位置与原文措辞，末节给出处层——默认入口，先读它）、' +
      'slots（49 触发 → 8 驱动槽）、loop（位置 × 槽契约：迁／守／未定／无路）、multi（R1–R14 下两主体遭遇的判词）、' +
      'group、society、evolution、cycle、coordinator、dmlref、causal、audit、fleet、mutants、naming、course、genesis、principle、intuition、ml、ml-export、' +
      'spec、association、pathsum、algebra、petri、aho、buchi、mermaid、dot。页码出处（P.xx）只有 multi／group／society／intuition 四面印，' +
      '主体机自己的面没有页码字段。呈现层（viz/journey/嵌套视图/all）不在桥里。凡是需要机器自己的事实而不是记忆里的数字时用它。',
    inputSchema: {
      type: 'object',
      properties: {
        kind: {
          type: 'string',
          description: `Which face to run. One of: ${FACE_KINDS.join(', ')}.`,
        },
      },
      required: ['kind'],
      additionalProperties: false,
    },
    readOnly: true,
  },
  {
    name: 'pyroduct_gates',
    description:
      'Run the pyroduct module gate suite in a configured checkout: moon check + moon fmt --check + moon test (wasm target, 190 tests), returning per-command exit codes and the tail of each output. Requires PYRODUCT_PROJECT_DIR to point at a riantr/pyroduct checkout; with only the bundled snapshot it reports that the gate is unavailable instead of failing. Use it before and after changing the model.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
    readOnly: true,
  },
]

function textResult(text) {
  return { content: [{ type: 'text', text }] }
}

function toolResult(text, isError = false) {
  return { content: [{ type: 'text', text }], isError }
}

function renderCatalog(source, warning) {
  const provenance = bundledProvenance()
  const sourceLine =
    source === 'checkout'
      ? '本地 checkout（PYRODUCT_PROJECT_DIR）'
      : source === 'fallback'
        ? '插件内置快照 vendor/jsoncli.js（**配置的 checkout 不可用，已回落**）'
        : '插件内置快照 vendor/jsoncli.js'
  const head = [
    `pyroduct 分析面目录（${FACES.length} 面）`,
    '',
    provenance
      ? `模型：${provenance.module}@${provenance.version}（${provenance.builtWith}，target js）`
      : '模型：riantr/pyroduct（版本记档缺失）',
    `回答来源：${sourceLine}`,
    ...(warning ? [`⚠ ${warning}`] : []),
    '',
  ]
  const width = Math.max(...FACE_KINDS.map((kind) => kind.length))
  const rows = FACES.map(([kind, note]) => `  ${kind.padEnd(width)}  ${note}`)
  const tail = [
    '',
    '呈现层（viz/journey/嵌套视图/all）不在桥里：它们是渲染，不是模型事实。',
    '出处层不是每面都印：report 末节「派生表与持久度」与 slots 逐槽给标注。',
    '页码出处只印在 multi／group／society／intuition 四面（gloss 带 P.xx，intuition 是 evolution 那三处）；主体机的面没有页码字段，别自己补一个。',
  ]
  return [...head, ...rows, ...tail].join('\n')
}

async function callTool(name, args, signal) {
  const projectDir = projectDirOf()
  switch (name) {
    case 'pyroduct_faces': {
      const probe = await callBridge(projectDir, { kind: 'report' }, signal)
      return textResult(renderCatalog(probe.source, probe.warning))
    }
    case 'pyroduct_face': {
      const kind = typeof args.kind === 'string' ? args.kind.trim() : ''
      if (kind.length === 0) {
        return toolResult(`missing kind. One of: ${FACE_KINDS.join(', ')}`, true)
      }
      if (!FACE_KINDS.includes(kind)) {
        return toolResult(
          `unknown kind '${kind}'. One of: ${FACE_KINDS.join(', ')}`,
          true,
        )
      }
      const reply = await callBridge(projectDir, { kind }, signal)
      const body = reply.rendered.trimEnd()
      if (reply.warning === null || reply.warning === undefined) return textResult(body)
      // Fallback is a different model version: say so on top of the report so
      // the reader cannot mistake the snapshot for the checkout they configured.
      return textResult(
        `⚠ ${reply.warning}\n\n以下是内置快照的 ${kind} 面：\n\n${body}`,
      )
    }
    case 'pyroduct_gates': {
      if (projectDir === null) {
        return textResult(
          [
            'pyroduct 门禁不可用：未配置 checkout（当前只带内置只读快照）。',
            '',
            '要用门禁请在本会话的环境里设 PYRODUCT_PROJECT_DIR 指向 riantr/pyroduct 的 checkout，',
            '然后重试；首次调用会自动跑 `moon build --target js`。',
            '要跑哪些：moon check、moon fmt --check、moon test（wasm target，190 个测试）。',
          ].join('\n'),
        )
      }
      const specs = [
        ['check'],
        ['fmt', '--check'],
        ['test'],
      ]
      const lines = [`pyroduct 门禁 @ ${projectDir}`]
      assertMoonbitCheckout(projectDir)
      let failed = 0
      for (const spec of specs) {
        let outcome
        try {
          outcome = await runProcess(moonPathOf(), spec, {
            cwd: projectDir,
            timeoutMs: GATE_TIMEOUT_MS,
            signal,
          })
        } catch (error) {
          failed += 1
          lines.push(`moon ${spec.join(' ')} -> spawn error: ${String(error)}`)
          continue
        }
        if (outcome.code !== 0) failed += 1
        const tail = `${outcome.stdout}\n${outcome.stderr}`
          .split('\n')
          .map((line) => line.trim())
          .filter((line) => line.length > 0)
          .slice(-4)
          .join(' / ')
        lines.push(
          `moon ${spec.join(' ')} -> exit ${outcome.code}${tail ? ` | ${tail}` : ''}`,
        )
      }
      lines.push(failed === 0 ? '门禁结论：全绿。' : `门禁结论：${failed} 条未通过。`)
      return textResult(lines.join('\n'))
    }
    default:
      return toolResult(`unknown tool '${name}'`, true)
  }
}

/** JSON-RPC error object for a request the protocol layer itself rejects. */
function rpcError(id, code, message) {
  return { jsonrpc: '2.0', id, error: { code, message } }
}

async function handle(message) {
  const { id, method, params } = message
  switch (method) {
    case 'initialize':
      return {
        jsonrpc: '2.0',
        id,
        result: {
          protocolVersion:
            typeof params?.protocolVersion === 'string' ? params.protocolVersion : '2024-11-05',
          capabilities: { tools: { listChanged: false } },
          serverInfo: { name: SERVER_NAME, version: SERVER_VERSION },
        },
      }
    case 'ping':
      return { jsonrpc: '2.0', id, result: {} }
    case 'tools/list':
      return {
        jsonrpc: '2.0',
        id,
        result: {
          tools: TOOLS.map((tool) => ({
            name: tool.name,
            description: tool.description,
            inputSchema: tool.inputSchema,
            annotations: { readOnlyHint: true, openWorldHint: false },
          })),
        },
      }
    case 'tools/call': {
      const name = params?.name
      const args = params?.arguments ?? {}
      try {
        return { jsonrpc: '2.0', id, result: await callTool(name, args, undefined) }
      } catch (error) {
        return {
          jsonrpc: '2.0',
          id,
          result: toolResult(`${name} 失败：${String(error?.message ?? error)}`, true),
        }
      }
    }
    default:
      if (typeof id === 'undefined') return null // notification we do not implement
      return rpcError(id, -32601, `method not found: ${method}`)
  }
}

/** Newline-delimited JSON-RPC over stdin/stdout; stderr stays diagnostic. */
let pending = ''
process.stdin.setEncoding('utf8')
process.stdin.on('data', (chunk) => {
  pending += chunk
  let index
  while ((index = pending.indexOf('\n')) >= 0) {
    const line = pending.slice(0, index).trim()
    pending = pending.slice(index + 1)
    if (line.length === 0) continue
    let message
    try {
      message = JSON.parse(line)
    } catch {
      process.stderr.write(`pyroduct-model: unparseable line: ${line.slice(0, 200)}\n`)
      continue
    }
    handle(message)
      .then((response) => {
        if (response !== null) process.stdout.write(`${JSON.stringify(response)}\n`)
      })
      .catch((error) => {
        process.stderr.write(`pyroduct-model: ${String(error?.stack ?? error)}\n`)
      })
  }
})
process.stdin.on('end', () => process.exit(0))
process.stdin.resume()
