import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Agent } from '../types'

const PANE = 'agents-panel'
const agents = atom({ plugin: 'agents-panel', key: 'agents' } as const, [])

const DOTS = ['blue', 'cyan', 'yellow', 'magenta', 'red', 'green']
const SECTIONS: Record<string, string> = {
  projectSettings: 'PROJECT  .claude/agents',
  userSettings: 'USER  ~/.claude/agents',
  plugin: 'PLUGIN',
}

// ponytail: single-line frontmatter values only; a `description: >` block reads as ">"
function front(src: string): Record<string, string> {
  const out: Record<string, string> = {}
  const block = /^---\r?\n([\s\S]*?)\r?\n---/.exec(src)?.[1] ?? ''
  for (const line of block.split('\n')) {
    const i = line.indexOf(':')
    if (i > 0 && !/^\s/.test(line)) out[line.slice(0, i).trim()] = line.slice(i + 1).trim().replace(/^["']|["']$/g, '')
  }
  return out
}

async function load($: EngineInterface): Promise<Agent[]> {
  const out: Agent[] = []
  const seen = new Set<string>()

  // frontmatter has the description and model; the usage breakdown does not
  const files = await $.fs.list('.claude/agents').catch(() => [])
  for (const f of files) {
    if (f.kind !== 'file' || !f.name.endsWith('.md')) continue
    const fm = front(String(await $.fs.read(`.claude/agents/${f.name}`)))
    const name = fm.name ?? f.name.slice(0, -3)
    seen.add(name)
    out.push({ name, source: 'projectSettings', model: fm.model ?? null, description: fm.description ?? '', tokens: 0 })
  }

  // user and plugin agents (and any project one the files above missed)
  const { context } = await $.session.usage({ breakdown: 'summary' }).catch(() => ({ context: {} as never }))
  for (const a of context.breakdown?.agents ?? []) {
    if (!seen.has(a.agentType)) out.push({ name: a.agentType, source: a.source, model: null, description: '', tokens: a.tokens })
  }
  return out
}

export const register: Register = on => {
  let isOpen = false

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'agents-panel',
      description: 'Show or hide a side pane listing project, user and plugin agents',
    })
    return next(e)
  })

  on('command.run', { command: 'agents-panel' }, async $ => {
    if (isOpen) {
      await $.ui.close({ id: PANE })
      return { text: 'Agents panel closed.' }
    }
    const list = await load($)
    await update($, agents, () => list)
    await $.ui.open({ id: PANE, title: 'Agents' })
    isOpen = true
    return { text: 'Agents panel open.' }
  })

  on('ui.close', ($, e, next) => {
    if (e.id === PANE) isOpen = false
    return next(e)
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button, Text } = $.ui.resolve(e)
    const list = await read($, agents)
    const order = [...Object.keys(SECTIONS), ...new Set(list.map(a => a.source).filter(s => !(s in SECTIONS)))]

    return (
      <Box flexDirection="column">
        <Box justifyContent="space-between">
          <Text bold>◆ Agents <Text dimColor>in this project</Text></Text>
          <Text dimColor>{list.length} defined</Text>
        </Box>
        {list.length === 0 && (
          <Box marginTop={1}>
            <Text dimColor>No custom agents. Add .md files to .claude/agents/.</Text>
          </Box>
        )}
        {order.map(src => {
          const rows = list.filter(a => a.source === src)
          if (rows.length === 0) return null
          return (
            <Box key={src} flexDirection="column" marginTop={1}>
              <Text color="blue" bold>{SECTIONS[src] ?? src.toUpperCase()} <Text dimColor>· {rows.length}</Text></Text>
              {rows.map((a, i) => (
                <Box key={a.name} flexDirection="column" marginTop={1}>
                  <Box justifyContent="space-between">
                    <Box>
                      <Text color={DOTS[i % DOTS.length]}>● </Text>
                      <Text bold>{a.name}</Text>
                      {a.model !== null && <Text dimColor> {a.model}</Text>}
                    </Box>
                    <Button
                      key={`run-${a.name}`}
                      label="▶ run"
                      dimColor
                      onPress={async () => {
                        const r = await $.agent.spawn({
                          subagentType: a.name,
                          description: `run ${a.name}`,
                          prompt: `Run the ${a.name} agent on the current project.`,
                        })
                        $.ui.toast(r.deny ? `${a.name}: ${r.deny}` : `${a.name} started`)
                      }}
                    />
                  </Box>
                  <Text dimColor wrap="truncate-end">
                    {a.description || `~${a.tokens} tokens in the Agent tool prompt`}
                  </Text>
                </Box>
              ))}
            </Box>
          )
        })}
        <Box marginTop={1}>
          <Text dimColor>click ▶ run to start one · /agents-panel to hide</Text>
        </Box>
      </Box>
    )
  })
}
