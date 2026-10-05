#!/usr/bin/env node
/**
 * Refresh the bundled snapshot, then prove the package still agrees with itself.
 *
 *   node tools\update-bundle.mjs D:\src\DeepseekHarness\Projects\pyroduct
 *
 * Steps, in the order that makes a half-finished refresh impossible to miss:
 *   1. `moon build --target js` in the checkout (so the artifact is current);
 *   2. copy `_build/js/debug/build/cmd/jsoncli/jsoncli.js` over the bundled one;
 *   3. rewrite `vendor/BUILD.json` — version from moon.mod, toolchain from
 *      `moon --version`, plus bytes and SHA-256;
 *   4. run `tools/validate-plugin.mjs`, which asserts the pin, re-renders every
 *      face, and re-checks the model-count invariants. A model change that moves
 *      those counts therefore fails here rather than at the next release.
 *
 * It never edits the module's own sources and never touches anything outside
 * this package except the checkout's build directory.
 *
 * Not a capability and not referenced by plugin.json.
 */
import { spawn } from 'node:child_process'
import { createHash } from 'node:crypto'
import { copyFileSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const PLUGIN = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const BUILD_TIMEOUT_MS = 900_000
const BRIDGE_RELATIVE = path.join('_build', 'js', 'debug', 'build', 'cmd', 'jsoncli', 'jsoncli.js')

const projectDir = path.resolve(
  process.argv[2] ?? process.env.PYRODUCT_PROJECT_DIR ?? '',
)
if (process.argv[2] === undefined && !process.env.PYRODUCT_PROJECT_DIR) {
  process.stderr.write(
    'usage: node tools\\update-bundle.mjs <path-to-pyroduct-checkout>\n' +
      '       set PYRODUCT_PROJECT_DIR instead of passing the path\n',
  )
  process.exit(1)
}

function run(command, args, cwd) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, windowsHide: true, env: process.env })
    let stdout = ''
    let stderr = ''
    const timer = setTimeout(() => child.kill(), BUILD_TIMEOUT_MS)
    child.stdout.on('data', (c) => {
      stdout += c
    })
    child.stderr.on('data', (c) => {
      stderr += c
    })
    child.on('error', (error) => {
      clearTimeout(timer)
      reject(error)
    })
    child.on('close', (code) => {
      clearTimeout(timer)
      resolve({ code, stdout, stderr })
    })
  })
}

function fail(message) {
  process.stderr.write(`update-bundle: ${message}\n`)
  process.exit(1)
}

const moonMod = path.join(projectDir, 'moon.mod')
try {
  statSync(moonMod)
} catch {
  fail(`${projectDir} 不是一个 MoonBit 模块（缺 moon.mod）`)
}

console.log(`[1/4] moon build --target js @ ${projectDir}`)
const build = await run(process.env.PYRODUCT_MOON || 'moon', ['build', '--target', 'js'], projectDir)
if (build.code !== 0) {
  fail(`build 失败（exit ${build.code}）：${`${build.stderr}\n${build.stdout}`.trim().slice(0, 600)}`)
}

const source = path.join(projectDir, BRIDGE_RELATIVE)
let sourceStat
try {
  sourceStat = statSync(source)
} catch {
  fail(`build 成功但找不到 ${BRIDGE_RELATIVE}——这个 checkout 里没有 cmd/jsoncli？`)
}

console.log(`[2/4] 复制 ${sourceStat.size} 字节到 vendor/jsoncli.js`)
const buildJsonPath = path.join(PLUGIN, 'vendor', 'BUILD.json')
const previous = JSON.parse(readFileSync(buildJsonPath, 'utf8'))
const target = path.join(PLUGIN, previous.artifact)
copyFileSync(source, target)

console.log('[3/4] 写 vendor/BUILD.json（version / builtWith / bytes / sha256）')
const moduleVersion = /version\s*=\s*"([^"]+)"/.exec(readFileSync(moonMod, 'utf8'))?.[1]
if (!moduleVersion) fail(`读不出 moon.mod 里的 version`)
const version = await run(process.env.PYRODUCT_MOON || 'moon', ['--version'], projectDir)
// Keep only "<tool> <version>": the rest of the line is a build hash and an
// absolute binary path, which would make the recorded string differ per machine
// for no informational gain.
const toolchain = version.stdout
  .split('\n')
  .map((line) => line.trim().match(/^(moon|moonc)\s+(\S+)/))
  .filter(Boolean)
  .slice(0, 2)
  .map((m) => `${m[1]} ${m[2]}`)
  .join(' / ')
const raw = readFileSync(target)
const next = {
  ...previous,
  version: moduleVersion,
  builtWith: toolchain || previous.builtWith,
  bytes: raw.length,
  bundleSha256: createHash('sha256').update(raw).digest('hex'),
}
writeFileSync(buildJsonPath, `${JSON.stringify(next, null, 2)}\n`, 'utf8')
console.log(
  `      ${next.module}@${next.version} · ${next.bytes} 字节 · sha ${next.bundleSha256.slice(0, 12)}…`,
)
if (previous.bundleSha256 && previous.bundleSha256 !== next.bundleSha256) {
  console.log('      注意：内容与上次打进的快照不同（模型或工具链变了，这是正常的）')
}

console.log('[3b/4] plugin.json 的 version 需手动按 SemVer 提升——脚本不替你决定发版号')
console.log(`      当前 plugin.json: ${JSON.parse(readFileSync(path.join(PLUGIN, '.minimax-plugin', 'plugin.json'), 'utf8')).version}`)

console.log('[4/4] node tools/validate-plugin.mjs')
const verify = await run(process.execPath, [path.join(PLUGIN, 'tools', 'validate-plugin.mjs')], PLUGIN)
process.stdout.write(verify.stdout)
if (verify.code !== 0) {
  process.stderr.write(verify.stderr)
  fail('刷新后的包没过自己的回归网——快照已更新，但先别用，查清哪条不变量动了')
}
console.log('\n刷新完成：新快照 + 新哈希钉 + 自带回归网全过。记得同步 plugin.json 的 version。')
