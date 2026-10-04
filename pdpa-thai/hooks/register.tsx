import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import { findSensitive, issuedTag, newTags, plan, redact, scrub } from './detect'

// Every row the conversation keeps passes session.append first, so rewriting there keeps
// detected values out of the request and the stored row. Request-only text (@file attachments,
// memory files, context blocks) has its own hooks below. Best effort: regexes, not a DPO.
// See README Limits for what this does not cover.
const guardMode = atom({ plugin: 'pdpa-thai', key: 'guardMode' } as const, 'redact')
const isBlurOn = atom({ plugin: 'pdpa-thai', key: 'isBlurOn' } as const, true)
const tagSuffix = atom({ plugin: 'pdpa-thai', key: 'tagSuffix' } as const, '')

const MODES = ['redact', 'block', 'off'] as const
type Mode = (typeof MODES)[number]

const HELP: Record<Mode, string> = {
  redact: 'redact: ปกปิดข้อมูลส่วนบุคคลก่อนส่งให้ Claude (ค่าเริ่มต้น)',
  block: 'block: ไม่ส่งพรอมต์ที่มีข้อมูลส่วนบุคคล และปกปิดผลลัพธ์ของเครื่องมือ',
  off: 'off: ปิดการป้องกัน',
}

// ponytail: a cell UI cannot blur pixels, so the real text is drawn grey-on-grey (width and
// wrapping stay stable) and hover swaps in readable colours. Raw colours, not theme keys, so
// it reads on light and dark. Selecting and copying still yields the real text.
const BLUR = { color: '#6b7280', backgroundColor: '#6b7280' }
const REVEAL = { color: '#ffffff', backgroundColor: '#b45309' }
const DISPLAY_MAX = 100_000

// one random-enough suffix per session, kept in state so a hot reload keeps it; it marks the
// tags this session issued. update() keeps an existing value, so concurrent first calls agree.
async function suffix($: EngineInterface) {
  const fresh = (await $.clock.now()).toString(36).slice(-5)
  await update($, tagSuffix, cur => cur || fresh)
  return read($, tagSuffix)
}

// the tree for a row holding personal data, or null to leave the engine's own drawing
function draw($: EngineInterface, e: Parameters<EngineInterface['ui']['resolve']>[0], text: string, id: string) {
  if (text.length > DISPLAY_MAX) return null
  const spans = findSensitive(text)
  if (spans.length === 0) return null

  const { Box, Markdown, Text } = $.ui.resolve(e)
  // hover groups are shared across the whole surface, so the scope carries the row's id
  const scope = id.slice(0, 40)

  return (
    <Box flexDirection="column">
      {plan(text, spans).map((chunk, i) =>
        'md' in chunk ? (
          <Markdown key={`m${i}`} text={chunk.md} />
        ) : (
          <Box key={`l${i}`} flexWrap="wrap">
            {chunk.pieces.length === 0 && <Text> </Text>}
            {chunk.pieces.map((p, j) =>
              p.hidden ? (
                <Text key={`p${j}`} {...BLUR} hover={{ scope: `${scope}:${i}-${j}`, ...REVEAL }}>
                  {p.text}
                </Text>
              ) : (
                <Text key={`p${j}`}>{p.text}</Text>
              ),
            )}
          </Box>
        ),
      )}
    </Box>
  )
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'pdpa-guard',
      description: 'PDPA guard: redact | block | off (no argument shows the current mode)',
    })
    await $.command.register({
      name: 'pdpa-blur',
      description: 'Turn PDPA personal-data blurring in the transcript on or off',
    })
    $.ui.status(`PDPA: ${await read($, guardMode)}`)
    return next(e)
  })

  on('command.run', { command: 'pdpa-guard' }, async ($, e) => {
    const arg = e.args.trim().toLowerCase()
    const next = MODES.find(m => m === arg)
    if (next) {
      await update($, guardMode, () => next)
      $.ui.status(`PDPA: ${next}`)
      return { text: `โหมดป้องกัน PDPA → ${HELP[next]}` }
    }
    const mode = (await read($, guardMode)) as Mode
    return { text: `โหมดปัจจุบัน ${HELP[mode]}\nเปลี่ยนด้วย /pdpa-guard ${MODES.join(' | ')}` }
  })

  // the prompt first, so even the queue record of what you typed is clean
  on('prompt.submit', async ($, e, next) => {
    const mode = await read($, guardMode)
    if (mode === 'off') return next(e)
    const { text, found } = redact(e.text, newTags(await suffix($)))
    if (found === 0) return next(e)
    if (mode === 'block') {
      $.ui.toast(`PDPA: พบข้อมูลส่วนบุคคล ${found} รายการ ไม่ส่งพรอมต์นี้ให้ Claude`)
      return { drop: 'PDPA guard blocked this prompt: it contains personal data. Edit it, or run /pdpa-guard redact | off.' }
    }
    $.ui.toast(`PDPA: ปกปิดข้อมูลส่วนบุคคล ${found} รายการก่อนส่งให้ Claude`)
    return next({ ...e, text })
  })

  // everything the conversation keeps: tool results, hook context, deliveries. Not the model's
  // own responses or compaction summaries (written by the model from text already redacted, so
  // nothing new reaches it) and not notices (the model never reads them).
  on('session.append', async ($, e, next) => {
    if (e.door === 'response' || e.door === 'compaction' || e.door === 'notice') return next(e)
    if ((await read($, guardMode)) === 'off') return next(e)
    const hits = { n: 0 }
    const content = scrub(e.message.content, hits, newTags(await suffix($))) as typeof e.message.content
    if (hits.n === 0) return next(e)
    $.ui.toast(`PDPA: ปกปิดข้อมูลส่วนบุคคล ${hits.n} รายการก่อนส่งให้ Claude`)
    return next({ ...e, message: { ...e.message, content } })
  })

  // text that only rides a request and never becomes a row: @file mentions, edited files,
  // memory (CLAUDE.md) and the other context blocks
  on('prompt.attachment', async ($, e, next) => {
    if ((await read($, guardMode)) === 'off') return next(e)
    const { text, found } = redact(e.text, newTags(await suffix($)))
    return found === 0 ? next(e) : next({ ...e, text })
  })

  on('prompt.context', async ($, e, next) => {
    if ((await read($, guardMode)) === 'off') return next(e)
    const tags = newTags(await suffix($))
    return next({ ...e, blocks: e.blocks.map(b => ({ ...b, text: redact(b.text, tags).text })) })
  })

  // the model only ever sees tags for personal data; using one of this session's tags as a real
  // value in a call would corrupt the user's work, so refuse and say why
  on('tool.call', async ($, e, next) => {
    if ((await read($, guardMode)) === 'off') return next(e)
    return issuedTag(await suffix($)).test(JSON.stringify(e))
      ? { deny: 'PDPA guard hides personal data from you behind placeholder tags. Do not use a tag as a real value; ask the user for it, or have them run /pdpa-guard off.' }
      : next(e)
  })

  on('command.run', { command: 'pdpa-blur' }, async $ => {
    const wasOn = await read($, isBlurOn)
    await update($, isBlurOn, () => !wasOn)
    return { text: wasOn ? 'PDPA blur off.' : 'PDPA blur on. Hover a grey block to reveal it.' }
  })

  // read the toggle first so every row subscribes and redraws when it flips; no hover exists on
  // the other surfaces, and a block that cannot be revealed is worse than none
  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    const isActive = await read($, isBlurOn)
    if (!isActive || (e.surface !== 'terminal' && e.surface !== 'desktop')) return next(e)
    return draw($, e, e.props.text, e.requestId) ?? next(e)
  })

  on('ui.render', { component: 'UserMessage' }, async ($, e, next) => {
    const isActive = await read($, isBlurOn)
    if (!isActive || (e.surface !== 'terminal' && e.surface !== 'desktop')) return next(e)
    return draw($, e, e.props.text, e.requestId) ?? next(e)
  })
}
