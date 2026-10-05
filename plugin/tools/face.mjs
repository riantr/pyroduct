#!/usr/bin/env node
/**
 * Face runner for humans — the same bridge the MCP server spawns, without the
 * JSON-argument quoting dance.
 *
 *   node tools\face.mjs petri
 *   node tools\face.mjs --list
 *
 * Why this exists: the bridge takes ONE JSON object argument, and on Windows a
 * PowerShell command line strips the inner quotes — `node vendor\jsoncli.js
 * '{"kind":"petri"}'` reaches the bridge as {kind:petri} and it answers
 * {"ok":false,"error":"bad request: Invalid character 'k'..."}. Only
 * `cmd /c node vendor\jsoncli.js "{\"kind\":\"petri\"}"` survives. Inside
 * MiniMax Code you never hit this, because the MCP server builds the argv in
 * Node; this script is for when you want a face in a terminal.
 *
 * It is not a capability and is not referenced by plugin.json.
 */
import { spawn } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const PLUGIN = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const BRIDGE = path.join(PLUGIN, 'vendor', 'jsoncli.js')
const TIMEOUT_MS = 120_000

const kind = process.argv[2]
if (kind === undefined || kind === '--help' || kind === '-h') {
  process.stdout.write(
    'usage: node tools\\face.mjs <kind>\n' +
      '       node tools\\face.mjs --list   (print the supported kinds)\n' +
      '       node tools\\face.mjs --raw <kind>  (print the JSON reply)\n',
  )
  process.exit(kind === undefined ? 1 : 0)
}

const request = kind === '--list' ? { kind: 'report' } : { kind: kind === '--raw' ? process.argv[3] : kind }

const child = spawn(process.execPath, [BRIDGE, JSON.stringify(request)], {
  cwd: PLUGIN,
  windowsHide: true,
})
let stdout = ''
let stderr = ''
const timer = setTimeout(() => child.kill(), TIMEOUT_MS)
child.stdout.on('data', (c) => {
  stdout += c
})
child.stderr.on('data', (c) => {
  stderr += c
})
child.on('error', (error) => {
  clearTimeout(timer)
  process.stderr.write(`face: spawn error: ${String(error)}\n`)
  process.exit(1)
})
child.on('close', (code) => {
  clearTimeout(timer)
  const line = stdout.trim().split('\n').pop() ?? ''
  let reply
  try {
    reply = JSON.parse(line)
  } catch {
    process.stderr.write(`face: unparseable reply (exit ${code}): ${line.slice(0, 200) || stderr.slice(0, 200)}\n`)
    process.exit(1)
  }
  if (reply.ok !== true) {
    process.stderr.write(`face: ${String(reply.error)}\n`)
    process.exit(1)
  }
  if (kind === '--list') {
    process.stdout.write(`${reply.faces.join('\n')}\n`)
    return
  }
  if (kind === '--raw') {
    process.stdout.write(`${JSON.stringify(reply, null, 2)}\n`)
    return
  }
  process.stdout.write(`${reply.rendered.trimEnd()}\n`)
})
