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

// A crash used to be the least diagnosable failure this harness could have: an
// uncaught throw prints a stack to stderr and exits 1, and CI then reports only
// "Process completed with exit code 1". Three red runs in a row were spent
// narrowing that down by elimination because the reason was locked behind the
// log-download endpoint, which needs auth. Announce the crash as an error
// workflow command so it lands in the run's annotations, where it is readable
// without a credential. GitHub caps the message length; keep it to one line.
process.on('uncaughtException', (err) => {
  const first = String(err?.stack ?? err).split('\n').slice(0, 4).join(' ')
  console.log(`FAIL  harness crashed — ${first.slice(0, 300)}`)
  console.log(`::error::pyroduct plugin harness crashed — ${first.slice(0, 400)}`)
  process.exit(1)
})
process.on('unhandledRejection', (reason) => {
  const first = String(reason?.stack ?? reason).split('\n').slice(0, 4).join(' ')
  console.log(`FAIL  harness aborted — ${first.slice(0, 300)}`)
  console.log(`::error::pyroduct plugin harness aborted — ${first.slice(0, 400)}`)
  process.exit(1)
})

// ---------------------------------------------------------------------------
// Static pin check first: the bundled bridge carries every model fact, so an
// edited or stale copy must fail before any report is believed.
//
// `--fresh-build` splits this block in two, because it holds two kinds of
// check that have different homes:
//
//   * sha256 / byte length — reproducible only under the exact toolchain, on
//     the exact platform, that ran update-bundle.mjs. Measured on CI (Linux,
//     2026-10-12): the freshly built bundle hashed c4a6b512… at 1382480 bytes
//     against a pin recorded on Windows at b1bdd9b2… / 1382502. Demanding a
//     match there is demanding that two machines be one machine. Reported as a
//     warning, never fatal.
//   * version consistency — plain SemVer, and plugin.json == server.mjs's
//     SERVER_VERSION. These have nothing to do with the platform and stay fatal
//     in both modes.
//
// The behavioural suite below is what CI actually gates on. Dropping the byte
// assertion does not drop coverage: the moment the bridge is edited by hand,
// the faces it renders stop matching the source tables, and those checks go
// red.
const FRESH_BUILD = process.argv.includes('--fresh-build')
{
  const { createHash } = await import('node:crypto')
  const { readFileSync, statSync, existsSync } = await import('node:fs')
  const build = JSON.parse(
    readFileSync(path.join(PLUGIN, 'vendor', 'BUILD.json'), 'utf8'),
  )
  const bundle = path.join(PLUGIN, build.artifact)
  // `vendor/<bundle>` is a build artifact and is gitignored; BUILD.json pins it
  // by sha256 instead. A fresh checkout therefore does not have it, and a bare
  // readFileSync here died with ENOENT — a stack trace that says nothing about
  // the fix, on a machine where the file always exists. Say what to do instead.
  if (!existsSync(bundle)) {
    console.log(`FAIL  bundled bridge missing — ${build.artifact} is a build artifact (gitignored).`)
    console.log(`      Build it first:  moon build --target js`)
    console.log(`      then copy it in:  cp ${build.sourcePath} plugin/${build.artifact}`)
    console.log(`      or on Windows, run:  node plugin\\tools\\update-bundle.mjs <checkout>`)
    console.log(`::error::bundled bridge missing (${build.artifact}); build it with 'moon build --target js' and copy it into plugin/vendor/`)
    process.exit(1)
  }
  const raw = readFileSync(bundle)
  const sha = createHash('sha256').update(raw).digest('hex')
  const problems = []
  const notes = []
  const record = m => (FRESH_BUILD ? notes : problems).push(m)
  if (build.bundleSha256 !== sha) {
    record(`sha mismatch: BUILD.json ${String(build.bundleSha256).slice(0, 16)}… vs file ${sha.slice(0, 16)}…`)
  }
  if (build.bytes !== raw.length) {
    record(`size mismatch: BUILD.json ${build.bytes} vs file ${raw.length}`)
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
  for (const n of notes) console.log(`::warning::${n}`)
  if (problems.length === 0) {
    console.log(
      notes.length === 0
        ? `PASS  bundled bridge pinned — ${build.module}@${build.version}, sha ${sha.slice(0, 12)}…, ${statSync(bundle).size} bytes`
        : `PASS  bundled bridge freshly built — ${build.module}@${build.version}, sha ${sha.slice(0, 12)}…, ${statSync(bundle).size} bytes` +
          `\n      (differs from the pin by ${notes.length === 1 ? '1 comparison' : `${notes.length} comparisons`}: ` +
          `the pin was recorded under ${build.builtWith})`,
    )
  } else {
    console.log(`FAIL  bundled bridge pin — ${problems.join(' | ')}`)
    console.log('      (tools/update-bundle.mjs rewrites the pin; a mismatch means the artifact was edited by hand)')
    for (const p of problems) console.log(`::error::bundled bridge pin — ${p}`)
    process.exit(1)
  }
}

// `PYRODUCT_PROJECT_DIR` steers *this* harness's own file walk — that is what
// the wasm test count check below reads it for, and what AGENTS.md documents it
// as. The server under test must therefore NOT inherit it: the check "gates
// degrades cleanly without a checkout" is only true when the server sees no
// checkout, and an inherited variable makes gates find a real module and run it
// for real. That check could not pass on the command AGENTS.md tells you to
// run. The decoy spawn further down sets the variable deliberately, for the
// opposite reason, and must keep doing so.
const childEnv = { ...process.env }
delete childEnv.PYRODUCT_PROJECT_DIR
const child = spawn('node', [SERVER], { stdio: ['pipe', 'pipe', 'pipe'], env: childEnv })
let buf = ''
const pending = new Map()
// Count the reply lines the server actually wrote. A reply with no `id` has
// no pending entry, so the dispatcher below drops it SILENTLY -- which is
// exactly why a server that answered a notification used to look fine to
// this harness. Counting the lines is what lets a check say "no reply was
// sent" rather than "no reply was matched".
let replyLines = 0
child.stdout.setEncoding('utf8')
child.stdout.on('data', (chunk) => {
  buf += chunk
  let i
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim()
    buf = buf.slice(i + 1)
    if (!line) continue
    replyLines += 1
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
// Per-call budget. `pyroduct_gates` spawns the real MoonBit gate (check +
// fmt --check + the whole test suite), and server.mjs allows that 900 s — but
// this harness used to wait only 180 s, so on a COLD CI runner (nothing built,
// nothing cached) the wait expired first and the harness exited non-zero. It
// passed locally every time because a warm build finishes the gate in seconds:
// a shorter timeout than the thing under test is a timeout that only fires away
// from the machine you wrote it on. Overridable so a slow machine is not a
// false failure.
const CALL_TIMEOUT_MS = Number(process.env.PYRODUCT_VALIDATE_TIMEOUT_MS ?? 900000)
function request(method, params) {
  const id = nextId++
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`timeout after ${CALL_TIMEOUT_MS}ms on ${method}`)),
      CALL_TIMEOUT_MS,
    )
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
let checkCount = 0
function check(label, condition, detail = '') {
  const ok = Boolean(condition)
  checkCount += 1
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? ` — ${detail}` : ''}`)
  if (!ok) problems.push(label)
}

const FACES = [
  'report', 'slots', 'loop', 'multi', 'group', 'society', 'evolution', 'cycle',
  'coordinator', 'dmlref', 'causal', 'audit', 'fleet', 'mutants', 'mbti', 'mermaid',
  'dot', 'genesis', 'course', 'naming', 'principle', 'intuition', 'ml',
  'ml-export', 'spec', 'association', 'pathsum', 'algebra', 'petri', 'aho',
  'buchi',
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
check(`catalog lists all ${FACES.length} faces`, FACES.every((f) => catText.includes(f)))
// The reverse direction, and the one that actually bit: a new face added to the
// bridge but not to FACES above still made every check below pass — the catalog
// did contain all of FACES, and FACES was simply missing the new one. That left
// the 31st face unrendered-checked with the whole suite green. So: the catalog's
// own face list and this list must be the SAME set, not a subset.
const catalogFaces = [...catText.matchAll(/^ {2}([a-z][a-z-]*)\s{2,}/gm)].map((m) => m[1])
const onlyInCatalog = catalogFaces.filter((f) => !FACES.includes(f))
const onlyHere = FACES.filter((f) => !catalogFaces.includes(f))
check('catalog face list === FACES (no face escapes validation)',
  onlyInCatalog.length === 0 && onlyHere.length === 0,
  `catalog-only: ${onlyInCatalog.join(',') || '—'} | harness-only: ${onlyHere.join(',') || '—'}`)
// The count written into the pyroduct_faces DESCRIPTION is prose that no other
// check reads: it said 28 while the catalog rendered 31, and every check stayed
// green — including the one that counts the faces. A live agent reading that
// description was simply told the wrong number. Held to FACES here,
// so a face added later cannot leave the description behind again.
const facesDesc = tools.find((t) => t.name === 'pyroduct_faces')?.description ?? ''
const descCount = Number((facesDesc.match(/the (\d+) runnable views/) || [])[1])
check('faces description states the real face count',
  descCount === FACES.length,
  `description says ${Number.isNaN(descCount) ? '(no count found)' : descCount}, catalog has ${FACES.length}`)
// The same number appears a third time, in plugin.json's description — the blurb
// the plugin catalog shows before any tool is called. Nothing read it: it said
// 28 while the catalog rendered 31, and the harness stayed green, because the
// check above only covers the tool description. A count that three documents
// publish is three chances to rot, so all three are held to FACES here.
const pluginJson = JSON.parse(
  await import('node:fs').then((fs) => fs.readFileSync(path.join(PLUGIN, '.minimax-plugin', 'plugin.json'), 'utf8')),
)
const pluginDescCount = Number((pluginJson.description?.match(/(\d+)\s*个分析面/) || [])[1])
check('plugin.json description states the real face count',
  pluginDescCount === FACES.length,
  `plugin.json says ${Number.isNaN(pluginDescCount) ? '(no count found)' : pluginDescCount}, catalog has ${FACES.length}`)
// And once more inside the package's own shipped prose: the plugin README, the
// SKILL doc an agent reads, the tools reference, and the MCP manifest each
// publish the face count ("31 faces") as something a reader can act on. A
// count that four documents publish is four chances to rot, so every number
// they state is held to FACES.
//
// The manifest is the fourth copy and it rotted last: it said "28-face
// analysis catalog" while the catalog rendered 31, and no check read it --
// the harness only covered the tool description, then plugin.json, then the
// prose. Each pass found one more copy that nobody was watching.
const shippedDocs = [
  path.join(PLUGIN, 'README.md'),
  path.join(PLUGIN, 'skills', 'pyroduct-model', 'SKILL.md'),
  path.join(PLUGIN, 'skills', 'pyroduct-model', 'references', 'tools.md'),
  path.join(PLUGIN, 'pyroduct.mcp.json'),
]
{
  const { readFileSync: rf, existsSync: es } = await import('node:fs')
  const offenders = []
  let scanned = 0
  for (const p of shippedDocs) {
    if (!es(p)) continue
    scanned += 1
    // "31 面" / "31 个面" / "31 分析面" in the Chinese docs, "31-face" in the
    // English manifest.
    for (const m of rf(p, 'utf8').matchAll(/(\d+)\s*(?:个|条)?\s*(?:分析)?面|(\d+)-face/g)) {
      const stated = Number(m[1] ?? m[2])
      if (stated !== FACES.length) {
        offenders.push(`${path.basename(p)}: "${m[0]}"`)
      }
    }
  }
  check('shipped docs state the real face count',
    offenders.length === 0,
    offenders.length === 0
      ? `${FACES.length} faces, ${scanned} doc(s) scanned`
      : offenders.join(' | '))
}
// Version-agnostic on purpose: the number moves with every release, so pinning a
// literal here would turn each version bump into a harness edit. What must hold is
// that the catalog reports the version the pin file records — that pair drifting
// apart is the real defect.
const buildInfo = JSON.parse(
  await import('node:fs').then((fs) => fs.readFileSync(path.join(PLUGIN, 'vendor', 'BUILD.json'), 'utf8')),
)
check(
  'catalog states the version the pin file records',
  catText.includes(`${buildInfo.module}@${buildInfo.version}`),
  catText.split('\n')[2],
)

const badKind = await request('tools/call', {
  name: 'pyroduct_face',
  arguments: { kind: 'not-a-face' },
})
check('bad kind -> isError + legal list', badKind.result?.isError === true && textOf(badKind).includes('report'))
const noKind = await request('tools/call', { name: 'pyroduct_face', arguments: {} })
check('missing kind -> isError', noKind.result?.isError === true)
// "missing" and "wrong type" are different mistakes. A caller that sent
// `kind: 123` and is told the argument is missing goes off to add the
// argument it already added.
const wrongType = await request('tools/call', { name: 'pyroduct_face', arguments: { kind: 123 } })
check('wrong-typed kind -> isError and says the TYPE is wrong',
  wrongType.result?.isError === true && textOf(wrongType).includes('must be a string'),
  textOf(wrongType).slice(0, 80))
// An error message must not repeat the caller's whole input back: the caller
// controls its length, and echoing 100 KB is an amplifier.
const hugeKind = await request('tools/call', { name: 'pyroduct_face', arguments: { kind: 'x'.repeat(100000) } })
const hugeText = textOf(hugeKind)
check('an unknown kind is not echoed back in full',
  hugeText.length < 2000 && hugeText.includes('chars)'),
  `${hugeText.length} chars in the reply`)
// A request with no `id` is a JSON-RPC notification and must not be
// answered. The server used to answer it, and `JSON.stringify` drops the
// undefined id, so the frame was `{"jsonrpc":"2.0","result":{}}` -- a
// response with no id, which is not legal JSON-RPC. The reply has no
// pending entry, so it was dropped SILENTLY by the dispatcher above: this
// check counts the lines the server wrote instead.
{
  const before = replyLines
  child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', method: 'ping' })}\n`)
  await new Promise((resolve) => setTimeout(resolve, 400))
  const answered = replyLines - before
  check('a request without an id gets no reply (it is a notification)',
    answered === 0,
    `${answered} reply line(s) for a notification`)
}

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
check(`all ${FACES.length} faces render non-empty`, empty.length === 0, empty.join(' | '))
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
  ['fleet', '未预期发现：**0 条**'],
  ['fleet', '没有驱动槽'],
  ['mutants', '6／6'],
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

// --- test count anti-drift ---------------------------------------------------
// The pyroduct_gates description states a test count ("197 tests"). That number
// drifted from 190 to 197 without anyone noticing — the same shape as the
// "28 faces" drift that commit 7b95863 fixed. Count test functions in *_test.mbt
// files, subtract native-only packages, and compare against the description.
{
  const { readFileSync: rf, existsSync: es } = await import('node:fs')
  const { readdirSync: rd, statSync: st } = await import('node:fs')
  // Prefer an explicit checkout. `path.dirname(PLUGIN)` is only a fallback: run
  // from the installed plugin copy, that is ~/.minimax/plugins/, which holds no
  // MoonBit module at all — walkTests returns nothing, totalTests stays 0, and
  // the check below compares the description's 197 against 0 and reports a
  // mismatch that says nothing true about anything. Measured 2026-10-12: the
  // command AGENTS.md tells you to run after every plugin change could never
  // pass when run the way AGENTS.md tells you to run it.
  const candidate = process.env.PYRODUCT_PROJECT_DIR
  const projectRoot =
    candidate && es(path.join(candidate, 'moon.mod')) ? candidate : path.dirname(PLUGIN)

  function walkTests(dir, out) {
    for (const entry of rd(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name)
      if (entry.name === '_build' || entry.name === '.mooncakes' || entry.name === 'node_modules') continue
      if (entry.isDirectory()) walkTests(full, out)
      else if (entry.name.endsWith('_test.mbt')) out.push(full)
    }
  }
  const testFiles = []
  walkTests(projectRoot, testFiles)

  // A check that cannot see its subject must say so, not report a finding.
  if (testFiles.length === 0) {
    console.log(`SKIP  wasm test count — no *_test.mbt under ${projectRoot}.`)
    console.log('      Unmeasurable here, which is not the same as zero tests.')
    console.log('      Run from a checkout, or set PYRODUCT_PROJECT_DIR to one.')
    console.log('::warning::wasm test count not measurable from ' + projectRoot)
  } else {

  let totalTests = 0
  const fileCounts = new Map()
  for (const f of testFiles) {
    const content = rf(f, 'utf8')
    const matches = content.match(/^\s*(async\s+)?test\s+"/gm)
    const count = matches ? matches.length : 0
    fileCounts.set(f, count)
    totalTests += count
  }

  // Identify +native packages: their moon.pkg has supported_targets = "+native"
  function isNativeOnly(testFile) {
    const pkgDir = path.dirname(testFile)
    const moonPkg = path.join(pkgDir, 'moon.pkg')
    if (!es(moonPkg)) return false
    const content = rf(moonPkg, 'utf8')
    return /^\s*supported_targets\s*=\s*"\+native"\s*$/m.test(content)
  }

  let nativeTests = 0
  for (const [f, count] of fileCounts) {
    if (isNativeOnly(f)) nativeTests += count
  }
  const wasmTests = totalTests - nativeTests

  // Extract the test count from the pyroduct_gates tool description
  const gatesDesc = tools.find((t) => t.name === 'pyroduct_gates')?.description ?? ''
  const descMatch = gatesDesc.match(/(\d+)\s+tests/)
  const descCount = descMatch ? Number(descMatch[1]) : NaN

  check('gates description states the real wasm test count',
    descCount === wasmTests,
    `description says ${descCount}, code has ${wasmTests} (${totalTests} total - ${nativeTests} native-only)`)

  // The same number also appears in the shipped SKILL doc, and NOTHING read it.
  // Measured 2026-10-18: the harness printed PASS on the test-count anti-drift
  // while SKILL.md told a live agent "197 个测试" and the code ran 205. This is
  // the same failure the check above was written for — a number in prose that
  // drifts with every release — one document further from the counter. A check
  // that only covers the tool description covers the class of bug it was
  // invented to catch, and leaves the sibling copy to rot in peace.
  const skillPath = path.join(PLUGIN, 'skills', 'pyroduct-model', 'SKILL.md')
  const skillText = es(skillPath) ? rf(skillPath, 'utf8') : ''
  // Any <number> 个测试 / <number> tests near the gate row. Requiring exactly one
  // match keeps this from silently passing on a doc that stopped claiming it.
  const skillCounts = [...skillText.matchAll(/(\d+)\s*(?:个测试|tests)/g)]
    .map((m) => Number(m[1]))
  const skillWrong = skillCounts.filter((n) => n !== wasmTests)
  check('SKILL.md states the real wasm test count',
    skillText.length > 0 && skillCounts.length > 0 && skillWrong.length === 0,
    skillText.length === 0
      ? 'SKILL.md not found under plugin/skills/pyroduct-model/'
      : skillCounts.length === 0
        ? 'SKILL.md claims no test count at all — nothing for this check to hold'
        : skillWrong.length === 0
          ? `all ${skillCounts.length} claim(s) say ${wasmTests}`
          : `says ${[...new Set(skillWrong)].join(', ')}, code has ${wasmTests}`)
  }
}

// --- model fact anti-drift ---------------------------------------------------
// Face descriptions in server.mjs contain hardcoded model facts (34 states,
// 53 transitions, etc.). If the enums change but the descriptions don't, the
// plugin lies to agents. Cross-check the descriptions against known facts.
{
  // Expected facts (must match tools/extract_model_facts.py)
  const facts = {
    subject: { states: 34, transitions: 53, phases: 11, triggers: 49, slots: 8 },
    group: { states: 20, transitions: 44, phases: 9, triggers: 22 },
    society: { states: 13, transitions: 28, phases: 8, triggers: 18 },
    combinations: { total: 272, no_way: 228 },
  }

  // Build a map from face kind to description
  const faceDescMap = new Map()
  for (const t of tools) {
    if (t.name === 'pyroduct_face') {
      // The tool description doesn't have per-face descriptions; they're in the catalog
      continue
    }
  }
  // Extract from catalog text instead
  const faceDescs = [...catText.matchAll(/^ {2}(\S+)\s+(.*)$/gm)]
    .map((m) => [m[1], m[2]])
    .filter(([kind]) => FACES.includes(kind))
  for (const [kind, desc] of faceDescs) {
    faceDescMap.set(kind, desc)
  }

  // Check report: "34 位置 · 53 迁移 · 11 阶段"
  const reportDesc = faceDescMap.get('report') || ''
  const reportMatch = reportDesc.match(/(\d+)\s*位置.*?(\d+)\s*迁移.*?(\d+)\s*阶段/)
  if (reportMatch) {
    const actual = [Number(reportMatch[1]), Number(reportMatch[2]), Number(reportMatch[3])]
    const expected = [facts.subject.states, facts.subject.transitions, facts.subject.phases]
    check('report description model facts match code',
      JSON.stringify(actual) === JSON.stringify(expected),
      `expected ${expected}, got ${actual}`)
  } else {
    check('report description contains model facts', false, 'pattern not found')
  }

  // Check slots: "49 条触发句 → 8 个驱动槽"
  const slotsDesc = faceDescMap.get('slots') || ''
  const slotsMatch = slotsDesc.match(/(\d+)\s*条触发句.*?(\d+)\s*个驱动槽/)
  if (slotsMatch) {
    const actual = [Number(slotsMatch[1]), Number(slotsMatch[2])]
    const expected = [facts.subject.triggers, facts.subject.slots]
    check('slots description model facts match code',
      JSON.stringify(actual) === JSON.stringify(expected),
      `expected ${expected}, got ${actual}`)
  } else {
    check('slots description contains model facts', false, 'pattern not found')
  }

  // Check loop: "272 组合中 228 个无路"
  const loopDesc = faceDescMap.get('loop') || ''
  const loopMatch = loopDesc.match(/(\d+)\s*组合中\s*(\d+)\s*个无路/)
  if (loopMatch) {
    const actual = [Number(loopMatch[1]), Number(loopMatch[2])]
    const expected = [facts.combinations.total, facts.combinations.no_way]
    check('loop description model facts match code',
      JSON.stringify(actual) === JSON.stringify(expected),
      `expected ${expected}, got ${actual}`)
  } else {
    check('loop description contains model facts', false, 'pattern not found')
  }

  // Check group: "20 状态"
  const groupDesc = faceDescMap.get('group') || ''
  const groupMatch = groupDesc.match(/(\d+)\s*状态/)
  if (groupMatch) {
    const actual = Number(groupMatch[1])
    const expected = facts.group.states
    check('group description model facts match code',
      actual === expected,
      `expected ${expected}, got ${actual}`)
  } else {
    check('group description contains model facts', false, 'pattern not found')
  }

  // Check society: "13 状态"
  const societyDesc = faceDescMap.get('society') || ''
  const societyMatch = societyDesc.match(/(\d+)\s*状态/)
  if (societyMatch) {
    const actual = Number(societyMatch[1])
    const expected = facts.society.states
    check('society description model facts match code',
      actual === expected,
      `expected ${expected}, got ${actual}`)
  } else {
    check('society description contains model facts', false, 'pattern not found')
  }

  // Check fleet: "群体 20 状态·44 迁移、社会 13 状态·28 迁移"
  const fleetDesc = faceDescMap.get('fleet') || ''
  const fleetMatch = fleetDesc.match(/群体\s*(\d+)\s*状态.*?(\d+)\s*迁移.*?社会\s*(\d+)\s*状态.*?(\d+)\s*迁移/)
  if (fleetMatch) {
    const actual = [Number(fleetMatch[1]), Number(fleetMatch[2]), Number(fleetMatch[3]), Number(fleetMatch[4])]
    const expected = [facts.group.states, facts.group.transitions, facts.society.states, facts.society.transitions]
    check('fleet description model facts match code',
      JSON.stringify(actual) === JSON.stringify(expected),
      `expected ${expected}, got ${actual}`)
  } else {
    check('fleet description contains model facts', false, 'pattern not found')
  }

  // Check algebra: "最小商（31 块）"
  const algebraDesc = faceDescMap.get('algebra') || ''
  const algebraMatch = algebraDesc.match(/最小商.*?(\d+)\s*块/)
  if (algebraMatch) {
    const actual = Number(algebraMatch[1])
    const expected = 31  // minimal_quotient block count (from src/algebra.mbt)
    check('algebra description model facts match code',
      actual === expected,
      `expected ${expected}, got ${actual}`)
  } else {
    check('algebra description contains model facts', false, 'pattern not found')
  }

  // Check petri: "库所 34／变迁 53"
  const petriDesc = faceDescMap.get('petri') || ''
  const petriMatch = petriDesc.match(/库所\s*(\d+).*?变迁\s*(\d+)/)
  if (petriMatch) {
    const actual = [Number(petriMatch[1]), Number(petriMatch[2])]
    const expected = [facts.subject.states, facts.subject.transitions]
    check('petri description model facts match code',
      JSON.stringify(actual) === JSON.stringify(expected),
      `expected ${expected}, got ${actual}`)
  } else {
    check('petri description contains model facts', false, 'pattern not found')
  }

  // Check multi: the rule range the plugin quotes, in BOTH places it appears
  // (the face catalog AND the tool description), must be the range the module
  // prints. No pin for this one -- the module is the source, so when a rule is
  // added the module moves first and this goes red until the plugin's two
  // copies are updated. It has already drifted once: the catalog said R1-R12
  // while the module printed R1-R14, and nothing noticed.
  const RULE_RANGE = /R1[-\u2013]R(\d+)/
  const multiDesc = faceDescMap.get('multi') || ''
  const multiDescRange = multiDesc.match(RULE_RANGE)
  const multiBodyRange = (bodies.multi || '').match(RULE_RANGE)
  const faceToolDesc = tools.find((t) => t.name === 'pyroduct_face')?.description ?? ''
  const multiToolRange = faceToolDesc.match(RULE_RANGE)
  if (multiDescRange && multiBodyRange && multiToolRange) {
    const inModule = Number(multiBodyRange[1])
    const inCatalog = Number(multiDescRange[1])
    const inTool = Number(multiToolRange[1])
    check('multi rule range agrees across the module, the catalog, and the tool description',
      inCatalog === inModule && inTool === inModule,
      `module prints R1-R${inModule}, catalog says R1-R${inCatalog}, tool description says R1-R${inTool}`)
  } else {
    check('multi rule range is present in all three places', false,
      `catalog: ${multiDescRange ? 'found' : 'MISSING'}, module: ${multiBodyRange ? 'found' : 'MISSING'}, tool description: ${multiToolRange ? 'found' : 'MISSING'}`)
  }
}

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
  // Same reasoning as CALL_TIMEOUT_MS: the decoy run points at a directory
  // that is deliberately not a MoonBit module, so it must fail fast — but the
  // floor is the same shared budget rather than a second, smaller magic number.
  const arequest = (method, params, ms = CALL_TIMEOUT_MS) => {
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
// The count is printed by the harness rather than transcribed into prose: a
// hand-maintained number in a document was already one behind the truth here,
// exactly like the "28 faces" this file also had to catch. Read it from here.
console.log(`\n${checkCount} checks run`)
// GitHub turns `::error::` lines on stdout into annotations, and annotations are
// readable through the REST API without the log-download endpoint (which needs
// auth). Without this, a red CI run said only "exit code 1" — the diagnosis was
// locked behind a credential, which is exactly how the first two red runs of this
// release had to be diagnosed by elimination instead of by reading.
for (const p of problems) {
  console.log(`::error::pyroduct plugin check failed — ${p}`)
}
console.log(problems.length === 0
  ? `ALL CHECKS PASSED (${checkCount})`
  : `FAILURES (${checkCount - problems.length}/${checkCount} passed): ${problems.join(' | ')}`)
process.exit(problems.length === 0 ? 0 : 1)
