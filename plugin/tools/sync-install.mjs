#!/usr/bin/env node
/**
 * Sync the MiniMax plugin between its source of truth (this repo's plugin/)
 * and the installed local package (the Desktop data dir).
 *
 *   node plugin\tools\sync-install.mjs push [checkout]
 *   node plugin\tools\sync-install.mjs pull
 *
 * Direction matters, so it is an argument, not a guess:
 * - `push` repo -> data dir. This is the install step. The installed package is
 *   what the Desktop loads, so the repo copy is authoritative for text.
 * - `pull` data dir -> repo. Use after editing files inside the data dir (the
 *   runtime never writes there, so this only captures your own edits).
 *
 * `vendor/jsoncli.js` never travels: it is a 1.1 MB build artifact, it is
 * gitignored, and its SHA-256 is pinned in vendor/BUILD.json. `push` refuses to
 * leave the repo without that pin in place, and with a checkout argument it
 * chains into <data dir>\tools\update-bundle.mjs to rebuild the artifact and
 * re-run the package's own regression net.
 *
 * This file is repo-only: `push` skips it so the installed package stays lean.
 */
import { spawn } from 'node:child_process'
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
} from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const REPO_PLUGIN = path.resolve(HERE, '..')
const DATA_DIR = process.env.MINIMAX_DATA_DIR
  ? path.resolve(process.env.MINIMAX_DATA_DIR)
  : path.join(os.homedir(), '.minimax')
const INSTALLED = path.join(DATA_DIR, 'plugins', 'pyroduct-model')
const SELF = 'sync-install.mjs'
const SKIP = new Set([SELF, 'jsoncli.js'])

const mode = process.argv[2]
const checkout = process.argv[3] ?? process.env.PYRODUCT_PROJECT_DIR ?? null

if (mode !== 'push' && mode !== 'pull') {
  process.stderr.write(
    'usage: node plugin\\tools\\sync-install.mjs push [checkout]\n' +
      '       node plugin\\tools\\sync-install.mjs pull\n' +
      'env : MINIMAX_DATA_DIR (default ~/.minimax), PYRODUCT_PROJECT_DIR\n',
  )
  process.exit(1)
}

function walk(root, base = root, out = []) {
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    const full = path.join(root, entry.name)
    if (entry.isDirectory()) walk(full, base, out)
    else out.push(path.relative(base, full).split(path.sep).join('/'))
  }
  return out
}

function filesOf(root) {
  if (!existsSync(root)) return []
  return walk(root).filter((rel) => !rel.split('/').some((seg) => SKIP.has(seg)))
}

const from = mode === 'push' ? REPO_PLUGIN : INSTALLED
const to = mode === 'push' ? INSTALLED : REPO_PLUGIN
if (!existsSync(from)) {
  process.stderr.write(`sync: 源目录不存在：${from}\n`)
  process.exit(1)
}

const rels = filesOf(from)
if (rels.length === 0) {
  process.stderr.write(`sync: ${from} 里没有可同步的文件\n`)
  process.exit(1)
}

console.log(`${mode}: ${from}\n   -> ${to}`)
let written = 0
for (const rel of rels) {
  const src = path.join(from, rel)
  const dst = path.join(to, rel)
  if (existsSync(dst) && readFileSync(src).equals(readFileSync(dst))) continue
  mkdirSync(path.dirname(dst), { recursive: true })
  copyFileSync(src, dst)
  written += 1
  console.log(`   ${written === 0 ? '' : '+ '}${rel}`)
}

// Drop files the destination no longer has, so a rename does not leave a ghost
// behind (a stale server.mjs or skill reference is exactly the kind of drift
// this project treats as a defect).
const stale = filesOf(to).filter((rel) => !rels.includes(rel))
for (const rel of stale) {
  rmSync(path.join(to, rel), { force: true })
  console.log(`   - ${rel} (源里已无，删掉)`)
}
console.log(`${mode}: ${rels.length} 个文件，${written} 个写入，${stale.length} 个清理`)

// The pin is what makes the artifact trustworthy, so a push must not install a
// package whose recorded hash no longer matches what the runtime would load.
if (mode === 'push') {
  const buildPath = path.join(to, 'vendor', 'BUILD.json')
  const bundlePath = path.join(to, 'vendor', 'jsoncli.js')
  if (!existsSync(buildPath)) {
    process.stderr.write('sync: 安装目录缺 vendor/BUILD.json，钉不在，先跑 update-bundle.mjs\n')
    process.exit(1)
  }
  const build = JSON.parse(readFileSync(buildPath, 'utf8'))
  if (existsSync(bundlePath)) {
    const { createHash } = await import('node:crypto')
    const sha = createHash('sha256').update(readFileSync(bundlePath)).digest('hex')
    if (build.bundleSha256 !== sha) {
      process.stderr.write(
        `sync: vendor/jsoncli.js 的哈希与 BUILD.json 不符（${String(sha).slice(0, 12)}… vs ${String(build.bundleSha256).slice(0, 12)}…）——` +
          '这是构建产物被人手改过。跑 <plugin>\\tools\\update-bundle.mjs 重钉。\n',
      )
      process.exit(1)
    }
    console.log(`钉：${build.module}@${build.version} · sha ${sha.slice(0, 12)}… · ${statSync(bundlePath).size} 字节`)
  } else {
    console.log('钉：安装目录还没有桥（首次安装正常）；下一步跑 update-bundle.mjs 生成它')
  }
}

if (mode === 'push' && checkout) {
  const updater = path.join(INSTALLED, 'tools', 'update-bundle.mjs')
  if (!existsSync(updater)) {
    process.stderr.write(`sync: 找不到 ${updater}\n`)
    process.exit(1)
  }
  console.log(`\n接上 update-bundle.mjs（重建桥 + 重钉 + 跑回归）`)
  const child = spawn(process.execPath, [updater, checkout], {
    cwd: INSTALLED,
    stdio: 'inherit',
  })
  const code = await new Promise((resolve) => child.on('close', resolve))
  if (code !== 0) {
    process.stderr.write('sync: update-bundle 失败，安装目录现在是半新半旧的状态，别用它回答问题\n')
    process.exit(code ?? 1)
  }
}

if (mode === 'push' && !checkout) {
  console.log('\n下一步：node <plugin>\\tools\\update-bundle.mjs <checkout>  （生成桥 + 钉 + 回归）')
}
