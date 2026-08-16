#!/usr/bin/env node
/**
 * stdio MCP proxy: Claude Code <-> codex mcp-server
 *
 * Adds two things the Codex MCP server does not provide:
 *
 *  1. A *staleness* watchdog. Claude Code's per-server `timeout` is a hard
 *     wall-clock cap ("progress notifications do not extend it"), and Codex
 *     emits its own `codex/event` notifications rather than the standard
 *     `notifications/progress`, so nothing resets that clock. This proxy
 *     watches `codex/event` and kills a call only when Codex goes *quiet*.
 *     Reasoning blocks and shell commands emit nothing while they run, so
 *     those get a longer grace window.
 *
 *  2. A hard read-only lock. `sandbox` / `approval-policy` are per-call
 *     arguments the model controls, so a server-level default can be
 *     overridden. Here they are stamped onto every tools/call before it is
 *     forwarded, which the model cannot bypass.
 *
 * ---------------------------------------------------------------------------
 * LOAD-BEARING ASSUMPTION — re-verify when codex-cli is upgraded
 * ---------------------------------------------------------------------------
 * Only the `codex` tool is rewritten to read-only. `codex-reply` takes a
 * caller-supplied threadId and is forwarded untouched, and a resumed thread
 * inherits the sandbox it was created with. That is safe *only* because:
 *
 *   as of codex-cli 0.147.0, `codex-reply` resolves threads from the live
 *   mcp-server process's in-memory session map and will NOT rehydrate a
 *   session persisted on disk by an earlier process.
 *
 * Every reachable thread was therefore opened by a `codex` call through this
 * proxy, and every such call is forced read-only — so no writable thread can
 * exist in the reachable set. On-disk writable sessions exist, but they are
 * unreachable.
 *
 * If a future codex-cli lets `codex-reply` resume persisted sessions, this
 * lock silently opens: a caller could pass the id of an old workspace-write
 * thread and execute writes. Re-verify with:
 *
 *   1. find a workspace-write thread id in ~/.codex/sessions (its rollout
 *      jsonl contains "`sandbox_mode` is `workspace-write`")
 *   2. drive this proxy over stdio and call codex-reply with that threadId,
 *      asking it to `touch /tmp/CODEX_ESCAPE_TEST`
 *   3. expected: {"isError":true,"content":[{"text":"Session not found for
 *      thread_id: ..."}]} and no file created
 *
 * If that test ever writes the file, fix it here: track thread ids returned
 * by read-only `codex` calls in this process and reject codex-reply for any
 * id not in that set.
 * ---------------------------------------------------------------------------
 *
 * Env:
 *   CODEX_PROXY_IDLE_MS       quiet-time before a stall is declared  (default 180000)
 *   CODEX_PROXY_BUSY_IDLE_MS  quiet-time while reasoning/exec is open (default 900000)
 *   CODEX_PROXY_MAX_MS        absolute per-call ceiling, 0 = disabled (default 0)
 *   CODEX_PROXY_SANDBOX       sandbox to force                       (default read-only)
 *   CODEX_PROXY_LOG           path to append debug lines to          (default off)
 *
 * The timeout here is staleness-only by design; CODEX_PROXY_MAX_MS is opt-in.
 * Claude Code still imposes its own per-server `timeout` as a hard wall-clock
 * cap that progress cannot extend, and that one is not removable — dropping it
 * from .claude.json falls back to a *shorter* default. It is set high there to
 * stay out of the way, but it is a platform limit, not part of this design.
 */

import { spawn } from 'node:child_process'
import { createInterface } from 'node:readline'
import { appendFileSync } from 'node:fs'

const IDLE_MS = int(process.env.CODEX_PROXY_IDLE_MS, 180_000)
const BUSY_IDLE_MS = int(process.env.CODEX_PROXY_BUSY_IDLE_MS, 900_000)
const MAX_MS = int(process.env.CODEX_PROXY_MAX_MS, 0)
const SANDBOX = process.env.CODEX_PROXY_SANDBOX || 'read-only'
const LOG = process.env.CODEX_PROXY_LOG || ''

function int(v, d) {
  const n = Number.parseInt(v ?? '', 10)
  return Number.isFinite(n) && n >= 0 ? n : d
}

function log(...parts) {
  if (!LOG) return
  try {
    appendFileSync(LOG, `[${new Date().toISOString()}] ${parts.join(' ')}\n`)
  } catch {}
}

const child = spawn('codex', ['mcp-server', ...process.argv.slice(2)], {
  stdio: ['pipe', 'pipe', 'inherit'],
})

child.on('exit', (code, signal) => {
  const status = code ?? (signal ? 1 : 0)
  // process.exit() discards whatever is still queued on stdout, which can
  // swallow a final tool result when Codex exits right after answering. Stop
  // reading input and let the loop drain the pipe on its own instead.
  process.exitCode = status
  stdinLines.close()
  process.stdin.pause()
  setTimeout(() => process.exit(status), 5000).unref()
})

child.on('error', (err) => {
  process.stderr.write(`codex-proxy: failed to spawn codex mcp-server: ${err.message}\n`)
  process.exit(1)
})

const toCodex = (msg) => child.stdin.write(JSON.stringify(msg) + '\n')
const toClaude = (msg) => process.stdout.write(JSON.stringify(msg) + '\n')

/**
 * In-flight tools/call requests, keyed by JSON-RPC id.
 * { threadId, openOps:Set, timer, startedAt, progressToken, progressSeq, tool }
 */
const inflight = new Map()

/** ids we answered ourselves after a stall; Codex's late reply gets dropped. */
const answered = new Set()

// ---------------------------------------------------------------- watchdog

function windowFor(call) {
  return call.openOps.size > 0 ? BUSY_IDLE_MS : IDLE_MS
}

function arm(id) {
  const call = inflight.get(id)
  if (!call) return
  clearTimeout(call.timer)

  let wait = windowFor(call)
  if (MAX_MS > 0) {
    const remaining = MAX_MS - (Date.now() - call.startedAt)
    if (remaining <= 0) return stall(id, 'ceiling')
    wait = Math.min(wait, remaining)
  }

  call.timer = setTimeout(() => {
    const c = inflight.get(id)
    if (!c) return
    // The ceiling may have clipped this window short; if quiet-time is not
    // actually exhausted, the ceiling is what fired.
    const quiet = Date.now() - c.lastEventAt
    if (MAX_MS > 0 && Date.now() - c.startedAt >= MAX_MS && quiet < windowFor(c)) {
      return stall(id, 'ceiling')
    }
    stall(id, 'stall')
  }, wait)
  call.timer.unref?.()
}

function stall(id, kind) {
  const call = inflight.get(id)
  if (!call) return
  clearTimeout(call.timer)
  inflight.delete(id)
  answered.add(id)

  const quietSec = Math.round((Date.now() - call.lastEventAt) / 1000)
  const totalSec = Math.round((Date.now() - call.startedAt) / 1000)
  const detail =
    kind === 'ceiling'
      ? `exceeded the absolute ceiling of ${Math.round(MAX_MS / 1000)}s (ran ${totalSec}s)`
      : `went quiet for ${quietSec}s (limit ${Math.round(windowFor(call) / 1000)}s; ran ${totalSec}s total)`

  log(`abort id=${id} kind=${kind} quiet=${quietSec}s total=${totalSec}s ops=${call.openOps.size}`)

  // Ask Codex to abandon the turn, then answer Claude ourselves.
  toCodex({
    jsonrpc: '2.0',
    method: 'notifications/cancelled',
    params: { requestId: id, reason: `codex-proxy: ${kind}` },
  })

  toClaude({
    jsonrpc: '2.0',
    id,
    result: {
      isError: true,
      content: [
        {
          type: 'text',
          text:
            `Codex was cancelled by codex-proxy: the session ${detail}. ` +
            `No final message was produced. ` +
            (call.threadId
              ? `The thread id is ${call.threadId}, so codex-reply can resume it. `
              : '') +
            `Report the stall rather than guessing at what the review would have said.`,
        },
      ],
    },
  })
}

// ------------------------------------------------------- Claude -> Codex

const stdinLines = createInterface({ input: process.stdin })

stdinLines.on('line', (line) => {
  if (!line.trim()) return

  let msg
  try {
    msg = JSON.parse(line)
  } catch {
    return child.stdin.write(line + '\n') // not ours to interpret
  }

  // `msg.params` is guarded: a malformed tools/call without it would otherwise
  // throw here and take the whole server down mid-session.
  if (msg.method === 'tools/call' && msg.id !== undefined && msg.params) {
    const tool = msg.params.name
    const args = (msg.params.arguments ||= {})

    // Hard read-only lock. The model cannot opt out of this.
    if (tool === 'codex') {
      if (args.sandbox && args.sandbox !== SANDBOX) {
        log(`override sandbox ${args.sandbox} -> ${SANDBOX}`)
      }
      args.sandbox = SANDBOX
      args['approval-policy'] = 'never'
    }

    inflight.set(msg.id, {
      tool,
      threadId: tool === 'codex-reply' ? args.threadId || args.conversationId : null,
      openOps: new Set(),
      timer: null,
      startedAt: Date.now(),
      lastEventAt: Date.now(),
      progressToken: msg.params?._meta?.progressToken,
      progressSeq: 0,
    })
    arm(msg.id)
    log(`call id=${msg.id} tool=${tool}`)
  }

  toCodex(msg)
})

// ------------------------------------------------------- Codex -> Claude

createInterface({ input: child.stdout }).on('line', (line) => {
  if (!line.trim()) return

  let msg
  try {
    msg = JSON.parse(line)
  } catch {
    return process.stdout.write(line + '\n')
  }

  if (msg.method === 'codex/event') {
    onEvent(msg)
  } else if (msg.id !== undefined && (msg.result || msg.error)) {
    const call = inflight.get(msg.id)
    if (call) {
      clearTimeout(call.timer)
      inflight.delete(msg.id)
      log(`done id=${msg.id} after ${Math.round((Date.now() - call.startedAt) / 1000)}s`)
    } else if (answered.has(msg.id)) {
      // We already answered Claude for this id after a stall. Dropping the
      // late reply keeps us from emitting two responses for one request.
      answered.delete(msg.id)
      log(`drop late reply id=${msg.id}`)
      return
    }
  }

  toClaude(msg)
})

function onEvent(msg) {
  const meta = msg.params?._meta || {}
  const ev = msg.params?.msg || {}

  // Codex states the owning request on every event; route on that rather than
  // inferring it. Thread inference was wrong under concurrency (it bound the
  // first-seen thread to the oldest unbound call, swapping two calls' watchdog
  // state) and blind for the ~4% of events that carry no thread_id at all.
  const id = resolveId(meta)
  if (id === undefined) return

  const state = inflight.get(id)
  if (!state) return // already answered, or not a call we track

  state.lastEventAt = Date.now()
  state.threadId ||= meta.threadId || ev.thread_id

  // Reasoning items and shell commands are silent while they run. Hold the
  // longer window open until they close, so deep xhigh reasoning is not
  // mistaken for a stall.
  const item = ev.item || {}
  if (ev.type === 'item_started' && item.type === 'Reasoning') {
    state.openOps.add(`r:${item.id}`)
  } else if (ev.type === 'item_completed' && item.type === 'Reasoning') {
    state.openOps.delete(`r:${item.id}`)
  } else if (ev.type === 'exec_command_begin') {
    state.openOps.add(`x:${ev.call_id}`)
  } else if (ev.type === 'exec_command_end') {
    state.openOps.delete(`x:${ev.call_id}`)
  }

  if (state.progressToken !== undefined) {
    toClaude({
      jsonrpc: '2.0',
      method: 'notifications/progress',
      params: {
        progressToken: state.progressToken,
        progress: ++state.progressSeq,
        message: ev.type,
      },
    })
  }

  arm(id)
}

/**
 * Which in-flight request an event belongs to.
 *
 * `_meta.requestId` is authoritative and was present on every event observed
 * from codex-cli 0.147.0. The thread and single-call fallbacks exist only for
 * a version that stops sending it; both are refused under concurrency, where
 * guessing would reset the wrong call's watchdog.
 */
function resolveId(meta) {
  if (meta.requestId !== undefined && inflight.has(meta.requestId)) return meta.requestId

  if (meta.threadId) {
    for (const [id, state] of inflight) if (state.threadId === meta.threadId) return id
  }
  return inflight.size === 1 ? [...inflight.keys()][0] : undefined
}
