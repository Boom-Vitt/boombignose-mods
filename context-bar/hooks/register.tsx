import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Fill } from '../types'

const fill = atom({ plugin: 'context-bar', key: 'fill' } as const, null)
const isHidden = atom({ plugin: 'context-bar', key: 'isHidden' } as const, false)
const cache = atom({ plugin: 'context-bar', key: 'cache' } as const, null)
// in $.state, not a module variable: a hot reload would lose it and freeze the countdown
const endsAt = atom({ plugin: 'context-bar', key: 'endsAt' } as const, null)

// ponytail: fixed 5-minute prompt-cache TTL; set 3_600_000 if the session uses the 1h cache
const TTL_MS = 5 * 60 * 1000

const fmt = (n: number) =>
  n >= 1e6 ? `${+(n / 1e6).toFixed(1)}M` : n >= 1e4 ? `${Math.round(n / 1e3)}k` : n >= 1e3 ? `${(n / 1e3).toFixed(1)}k` : `${n}`

const SHORT: Record<string, string> = {
  'system prompt': 'prompt',
  'system tools': 'tools',
  'mcp tools': 'mcp',
  'mcp server instructions': 'mcp instr',
  'custom agents': 'agents',
  'memory files': 'memory',
  messages: 'msgs',
  'autocompact buffer': 'buffer',
  'free space': 'free',
}

const mmss = (s: number) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`

async function refresh($: EngineInterface) {
  try {
    const { context } = await $.session.usage({ breakdown: 'summary' })
    const b = context.breakdown
    const cats = (b?.categories ?? [])
      .filter(c => !c.isDeferred)
      .map(({ name, tokens, color, kind }) => ({ name, tokens, color, kind }))
    const buffer = cats.find(c => c.kind === 'buffer')
    const next: Fill | null = b
      ? {
          cats,
          total: b.totalTokens,
          window: b.rawMaxTokens,
          pct: b.percentage,
          compactAt: buffer ? b.rawMaxTokens - buffer.tokens : null,
        }
      : null
    await update($, fill, () => next)
  } catch {
    // no usage before the session binds; the next turn.complete retries
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'context-bar',
      description: 'Show or hide the context window breakdown above the prompt',
    })
    await refresh($)
    $.clock.every(1000, async () => {
      const end = await read($, endsAt)
      if (end === null) return
      const left = Math.max(0, Math.ceil((end - (await $.clock.now())) / 1000))
      await update($, cache, () => left)
      if (left === 0) await update($, endsAt, () => null) // cold: stop redrawing every second
    })
    return next(e)
  })

  on('prompt.submit', async ($, e, next) => {
    await update($, endsAt, () => null)
    await update($, cache, () => 'live' as const)
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const end = (await $.clock.now()) + TTL_MS
    await update($, endsAt, () => end)
    await update($, cache, () => TTL_MS / 1000)
    await refresh($)
    return next(e)
  })

  on('command.run', { command: 'context-bar' }, async $ => {
    const wasHidden = await read($, isHidden)
    await update($, isHidden, () => !wasHidden)
    if (wasHidden) await refresh($)
    return { text: wasHidden ? 'Context bar shown.' : 'Context bar hidden.' }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const f = await read($, fill)
    if (e.props.hasSurvey || f === null || (await read($, isHidden))) return next(e)

    const c = await read($, cache)
    const { Box, Text } = $.ui.resolve(e)
    // the box the band draws into (narrower than the viewport beside a docked pane)
    const width = Math.max(24, (e.props.bodyColumns ?? 80) - 2)
    const sum = f.cats.reduce((a, k) => a + k.tokens, 0) || 1
    // ponytail: fixed 70/85 thresholds, make them options if they need tuning
    const tone = f.pct >= 85 ? 'red' : f.pct >= 70 ? 'yellow' : 'green'
    const cacheTone = c === 'live' || (c !== null && c > 60) ? 'green' : c === 0 ? 'red' : 'yellow'

    return (
      <Box flexDirection="column" width={width}>
        <Box width={width} flexWrap="wrap" justifyContent="space-between">
          <Box>
            <Text bold>◆ context</Text>
            {c !== null && (
              <Text color={cacheTone}>  ⏱ cache {c === 'live' ? 'live' : c === 0 ? 'cold' : mmss(c)}</Text>
            )}
          </Box>
          <Box>
            <Text bold>{fmt(f.total)}</Text>
            <Text dimColor> of {fmt(f.window)}</Text>
            {f.compactAt !== null && <Text dimColor> · compacts at {fmt(f.compactAt)} </Text>}
            <Text color={tone} inverse bold> {Math.round(f.pct)}% </Text>
          </Box>
        </Box>
        {/* colour blocks sized by flex, not by glyph count: a glyph's advance differs per surface */}
        <Box width={width} height={1} overflow="hidden">
          {f.cats
            .filter(k => k.tokens > 0)
            .map(k => (
              <Box key={k.name} flexGrow={Math.max(1, Math.round((k.tokens / sum) * 1000))} minWidth={1} height={1} backgroundColor={k.color} />
            ))}
        </Box>
        <Box width={width} flexWrap="wrap">
          {f.cats.map(k => (
            <Box key={k.name} marginRight={2}>
              <Text color={k.color}>■ </Text>
              <Text dimColor>{SHORT[k.name.toLowerCase()] ?? k.name.toLowerCase()} </Text>
              <Text bold>{fmt(k.tokens)}</Text>
            </Box>
          ))}
        </Box>
      </Box>
    )
  })
}
