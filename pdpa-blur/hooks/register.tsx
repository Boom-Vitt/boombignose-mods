import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import { findSensitive, plan } from './detect'

const isOn = atom({ plugin: 'pdpa-blur', key: 'isOn' } as const, true)

// ponytail: a cell UI cannot blur pixels, so the real text is drawn grey-on-grey (width and
// wrapping stay stable) and hover swaps in readable colours. Raw colours, not theme keys, so
// it reads on light and dark. Selecting and copying still yields the real text.
const BLUR = { color: '#6b7280', backgroundColor: '#6b7280' }
const REVEAL = { color: '#ffffff', backgroundColor: '#b45309' }

// the tree for a row holding personal data, or null to leave the engine's own drawing
function draw($: EngineInterface, e: Parameters<EngineInterface['ui']['resolve']>[0], text: string) {
  const spans = findSensitive(text)
  if (spans.length === 0) return null

  const { Box, Markdown, Text } = $.ui.resolve(e)

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
                <Text key={`p${j}`} {...BLUR} hover={{ scope: `s${i}-${j}`, ...REVEAL }}>
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
      name: 'pdpa-blur',
      description: 'Turn PDPA personal-data blurring in the transcript on or off',
    })
    return next(e)
  })

  on('command.run', { command: 'pdpa-blur' }, async $ => {
    const wasOn = await read($, isOn)
    await update($, isOn, () => !wasOn)
    return { text: wasOn ? 'PDPA blur off.' : 'PDPA blur on. Hover a grey block to reveal it.' }
  })

  // read the toggle first so every row subscribes and redraws when it flips; no hover exists on
  // the other surfaces, and a block that cannot be revealed is worse than none
  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    const isActive = await read($, isOn)
    if (!isActive || (e.surface !== 'terminal' && e.surface !== 'desktop')) return next(e)
    return draw($, e, e.props.text) ?? next(e)
  })

  on('ui.render', { component: 'UserMessage' }, async ($, e, next) => {
    const isActive = await read($, isOn)
    if (!isActive || (e.surface !== 'terminal' && e.surface !== 'desktop')) return next(e)
    return draw($, e, e.props.text) ?? next(e)
  })
}
