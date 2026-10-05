/**
 * Validation harness for the pyroduct-model local MiniMax Plugin.
 * Speaks real MCP over stdio (newline-delimited JSON-RPC) and exercises
 * every tool, every face, plus a bad-kind call and the gates tool.
 *
 * Run it after changing the bundled snapshot, a tool description, or the skill
 * text:  node tools/validate-plugin.mjs
 *
 * It is not a capability and is not referenced by plugin.json. Its job is to
 * fail loudly when the package's own claims drift away from what the machine
 * actually prints — the drift that produced two wrong tool descriptions
 * (page citations and provenance layers) before they were measured.
 */
import { spawn } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const PLUGIN = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const SERVER = path.join(PLUGIN, 'server.mjs')

// ---------------------------------------------------------------------------
// Static pin check first: the bundled bridge carries every model fact, so an
// edited or stale copy must fail before any report is believed.
// ---------------------------------------------------------------------------
{
  const { createHash } = await import('node:crypto')
  const { readFileSync, statSync } = await import('node:fs')
  const build = JSON.parse(
    readFileSync(path.join(PLUGIN, 'vendor', 'BUILD.json'), 'utf8'),
  )
  const bundle = path.join(PLUGIN, build.artifact)
  const raw = readFileSync(bundle)
  const sha = createHash('sha256').update(raw).digest('hex')
  const problems = []
  if (build.bundleSha256 !== sha) {
    problems.push(`sha mismatch: BUILD.json ${String(build.bundleSha256).slice(0, 16)}… vs file ${sha.slice(0, 16)}…`)
  }
  if (build.bytes !== raw.length) {
    problems.push(`size mismatch: BUILD.json ${build.bytes} vs file ${raw.length}`)
  }
  if (!/^\d+\.\d+\.\d+$/.test(build.version)) {
    problems.push(`version is not plain SemVer: ${build.version}`)
  }
  const manifestVersion = JSON.parse(
    readFileSync(path.join(PLUGIN, '.minimax-plugin', 'plugin.json'), 'utf8'),
  ).version
  const serverVersion = /SERVER_VERSION = '([^']+)'/.exec(
    readFileSync(SERVER, 'utf8'),
  )?.[1]
  if (serverVersion !== manifestVersion) {
    problems.push(`plugin.json ${manifestVersion} != server.mjs ${serverVersion}`)
  }
  if (problems.length === 0) {
    console.log(`PASS  bundled bridge pinned — ${build.module}@${build.version}, sha ${sha.slice(0, 12)}…, ${statSync(bundle).size} bytes`)
  } else {
    console.log(`FAIL  bundled bridge pin — ${problems.join(' | ')}`)
    console.log('      (tools/update-bundle.mjs rewrites the pin; a mismatch means the artifact was edited by hand)')
    process.exit(1)
  }
}

const child = spawn('node', [SERVER], { stdio: ['pipe', 'pipe', 'pipe'] })
let buf = ''
const pending = new Map()
child.stdout.setEncoding('utf8')
child.stdout.on('data', (chunk) => {
  buf += chunk
  let i
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim()
    buf = buf.slice(i + 1)
    if (!line) continue
    const msg = JSON.parse(line)
    const resolver = pending.get(msg.id)
    if (resolver) {
      pending.delete(msg.id)
      resolver(msg)
    }
  }
})
let stderrText = ''
child.stderr.setEncoding('utf8')
child.stderr.on('data', (c) => {
  stderrText += c
})

let nextId = 1
function request(method, params) {
  const id = nextId++
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`timeout on ${method}`)), 180000)
    pending.set(id, (msg) => {
      clearTimeout(timer)
      resolve(msg)
    })
    child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', id, method, params })}\n`)
  })
}
function notify(method, params) {
  child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', method, params })}\n`)
}
function textOf(msg) {
  if (msg.error) return `<RPC ERROR ${msg.error.code}: ${msg.error.message}>`
  return msg.result.content.map((c) => c.text).join('\n')
}

const problems = []
function check(label, condition, detail = '') {
  const ok = Boolean(condition)
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? ` — ${detail}` : ''}`)
  if (!ok) problems.push(label)
}

const FACES = [
  'report', 'slots', 'loop', 'multi', 'group', 'society', 'evolution', 'cycle',
  'coordinator', 'dmlref', 'causal', 'audit', 'mermaid', 'dot', 'genesis', 'course',
  'naming', 'principle', 'intuition', 'ml', 'ml-export', 'spec', 'association',
  'pathsum', 'algebra', 'petri', 'aho', 'buchi',
]

const init = await request('initialize', {
  protocolVersion: '2025-06-18',
  capabilities: {},
  clientInfo: { name: 'validate', version: '1.0.0' },
})
notify('notifications/initialized')
console.log(`init -> ${JSON.stringify(init.result ?? init.error)}`)
check('initialize returns serverInfo', init.result?.serverInfo?.name === 'pyroduct-model')
check('initialize echoes protocolVersion', init.result?.protocolVersion === '2025-06-18')
check('initialize advertises tools capability', init.result?.capabilities?.tools !== undefined)

const ping = await request('ping', {})
check('ping answered', JSON.stringify(ping.result) === '{}')

const list = await request('tools/list', {})
const tools = list.result?.tools ?? []
check('tools/list has 3 tools', tools.length === 3, tools.map((t) => t.name).join(','))
for (const t of tools) {
  check(`tool ${t.name} has schema+description`,
    typeof t.description === 'string' && t.description.length > 40 &&
    t.inputSchema?.type === 'object')
}
const unknown = await request('nosuch/method', {})
check('unknown method -> -32601', unknown.error?.code === -32601)

const cat = await request('tools/call', { name: 'pyroduct_faces', arguments: {} })
const catText = textOf(cat)
check('pyroduct_faces ok', cat.result?.isError !== true)
check('catalog lists all 28 faces', FACES.every((f) => catText.includes(f)))
check('catalog states its provenance', catText.includes('0.1.24'), catText.split('\n')[2])

const badKind = await request('tools/call', {
  name: 'pyroduct_face',
  arguments: { kind: 'not-a-face' },
})
check('bad kind -> isError + legal list', badKind.result?.isError === true && textOf(badKind).includes('report'))
const noKind = await request('tools/call', { name: 'pyroduct_face', arguments: {} })
check('missing kind -> isError', noKind.result?.isError === true)

let empty = []
let tiny = []
for (const kind of FACES) {
  const reply = await request('tools/call', { name: 'pyroduct_face', arguments: { kind } })
  const body = textOf(reply)
  if (reply.result?.isError === true) {
    empty.push(`${kind}: ${body.slice(0, 80)}`)
    continue
  }
  if (body.trim().length < 80) tiny.push(`${kind} (${body.trim().length} chars)`)
}
check('all 28 faces render non-empty', empty.length === 0, empty.join(' | '))
check('no face renders a stub', tiny.length === 0, tiny.join(' | '))

// Content invariants, asserted against what the model actually prints.
// (A page-citation assertion was tried first and removed: no face prints
// page refs, and `src`'s tables carry no page numbers at all.)
const invariants = [
  ['report', '状态 34 个 · 迁移 53 条 · 阶段 11 个'],
  ['report', '272'],
  ['report', '228'],
  ['report', '派生表与持久度'],
  ['report', '原文直述'],
  ['report', '模型整理'],
  ['naming', '（原文：'],
  ['slots', '处境 6 · 取向 6 · 先行 4 · 行动 9 · 反馈 8 · 持存 8 · 共在 3 · 揭蔽 5'],
  ['slots', '模型整理'],
  ['loop', '272'],
  ['loop', '228'],
  ['audit', '未预期发现：**0 条**'],
  ['audit', '228'],
  ['algebra', '最小商：31 块'],
  ['pathsum', '宁静'],
  ['petri', '守恒'],
  ['aho', '失败'],
  ['buchi', '验收集 = {宁静}'],
  ['buchi', '结构不强迫活性'],
]
const bodies = {}
for (const kind of FACES) {
  bodies[kind] = textOf(await request('tools/call', { name: 'pyroduct_face', arguments: { kind } }))
}
const missing = []
for (const [kind, needle] of invariants) {
  if (!bodies[kind].includes(needle)) missing.push(`${kind} lacks ${JSON.stringify(needle)}`)
}
check('content invariants hold across faces', missing.length === 0, missing.join(' | '))
// Page citations: printed by the multi/group/society faces (their glosses carry
// P.xx), absent from the subject machine's own faces (src's tables have no page
// field). Both halves are asserted — a one-sided check would pass on a partial
// sample, which is exactly how "no face prints page refs" got believed once.
const pageRef = (k) => /P\.\d+/.test(bodies[k])
// Closed set, not a subset: if a future face gains or loses page refs, this
// fails and forces the catalog text and the skill docs to be updated together.
const EXPECTED_REFS = ['group', 'intuition', 'multi', 'society']
const withRefs = FACES.filter(pageRef).sort()
check('exactly four faces print page citations',
  JSON.stringify(withRefs) === JSON.stringify(EXPECTED_REFS), withRefs.join(','))
check('subject-machine faces carry no page field',
  ['report', 'slots', 'naming', 'spec', 'loop'].every((k) => !pageRef(k)))

// Generalized anti-drift: a catalog line may not claim page citations for a face
// whose output carries none. This is the rule that would have caught the two
// wrong tool descriptions written from memory before verification.
const claimed = [...catText.matchAll(/^ {2}(\S+)\s+(.*)$/gm)]
  .map((m) => [m[1], m[2]])
  .filter(([kind]) => FACES.includes(kind))
// A row may legitimately say "this face has no page citations" — so the check
// looks for a *positive* claim: a 页码/P.xx mention not preceded by a negator.
const assertsPageRefs = (note) => {
  for (const m of note.matchAll(/页码|P\.xx/g)) {
    const before = note.slice(Math.max(0, m.index - 6), m.index)
    if (!/[不无没]/.test(before)) return true
  }
  return false
}
const unsupported = claimed
  .filter(([, note]) => assertsPageRefs(note))
  .map(([kind]) => kind)
  .filter((kind) => !pageRef(kind))
check('no catalog line claims page citations for a face without them',
  unsupported.length === 0, unsupported.join(',') || `${claimed.length} lines scanned`)
const namedWrong = [...catText.matchAll(/^ {2}(\S+)\s+.*(?:页码|出处层)/gm)]
  .map((m) => m[1])
  .filter((kind) => ['naming', 'report', 'slots', 'spec', 'loop'].includes(kind) && kind !== 'report')
check('naming row no longer claims a provenance layer',
  !catText.includes('定名对照表：两字定名 ＋ 原文措辞 ＋ 出处层'), namedWrong.join(',') || 'clean')

const gates = await request('tools/call', { name: 'pyroduct_gates', arguments: {} })
const gateText = textOf(gates)
check('gates degrades cleanly without a checkout',
  gates.result?.isError !== true && gateText.includes('PYRODUCT_PROJECT_DIR'), gateText.split('\n')[0])

// --- positive control for the checkout guard -------------------------------
// A guard nobody fires is an untested claim: "the gate reports a bad
// PYRODUCT_PROJECT_DIR" needs a deliberately wrong path to be evidence. The
// two tools must also disagree on purpose — gates hard-fails (a gate that ran
// elsewhere would be a lie), while face falls back to the snapshot and says so.
{
  const decoy = path.join(PLUGIN, 'tools')
  const alt = spawn('node', [SERVER], {
    env: { ...process.env, PYRODUCT_PROJECT_DIR: decoy },
    stdio: ['pipe', 'pipe', 'pipe'],
  })
  let abuf = ''
  const apending = new Map()
  alt.stdout.setEncoding('utf8')
  alt.stdout.on('data', (chunk) => {
    abuf += chunk
    let i
    while ((i = abuf.indexOf('\n')) >= 0) {
      const line = abuf.slice(0, i).trim()
      abuf = abuf.slice(i + 1)
      if (!line) continue
      const msg = JSON.parse(line)
      const r = apending.get(msg.id)
      if (r) {
        apending.delete(msg.id)
        r(msg)
      }
    }
  })
  let aid = 1
  const arequest = (method, params, ms = 120000) => {
    const rid = aid++
    return new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error(`timeout ${method}`)), ms)
      apending.set(rid, (m) => {
        clearTimeout(t)
        resolve(m)
      })
      alt.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', id: rid, method, params })}\n`)
    })
  }
  await arequest('initialize', { protocolVersion: '2025-06-18', capabilities: {} }, 30000)
  alt.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' })}\n`)

  const badGates = await arequest('tools/call', { name: 'pyroduct_gates', arguments: {} })
  const badGateText = badGates.result.content.map((c) => c.text).join('\n')
  check('gates hard-fails on a non-MoonBit checkout and names the reason',
    badGates.result?.isError === true &&
      badGateText.includes('不像 MoonBit 模块') &&
      badGateText.includes('moon.mod'),
    badGateText.slice(0, 90))

  const badFace = await arequest('tools/call', {
    name: 'pyroduct_face',
    arguments: { kind: 'report' },
  })
  const badFaceText = badFace.result.content.map((c) => c.text).join('\n')
  check('face falls back to the snapshot and labels the fallback',
    badFace.result?.isError !== true &&
      badFaceText.includes('内置快照') &&
      badFaceText.includes('状态 34 个'),
    badFaceText.split('\n')[0].slice(0, 90))

  const badCat = await arequest('tools/call', { name: 'pyroduct_faces', arguments: {} })
  const badCatText = badCat.result.content.map((c) => c.text).join('\n')
  check('catalog marks the fallback source',
    badCatText.includes('已回落') && badCatText.includes('⚠'),
    badCatText.split('\n')[3]?.slice(0, 90))
  alt.stdin.end()
}

console.log(`\nstderr: ${stderrText.trim() || '(empty)'}`)
child.stdin.end()
console.log(problems.length === 0 ? '\nALL CHECKS PASSED' : `\nFAILURES: ${problems.join(' | ')}`)
process.exit(problems.length === 0 ? 0 : 1)
