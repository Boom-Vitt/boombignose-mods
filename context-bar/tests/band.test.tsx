import { expect, test } from 'claude-code/testing'

const cats = [
  { name: 'System prompt', tokens: 4700, color: 'inactive', isDeferred: false, kind: 'used' },
  { name: 'Messages', tokens: 84000, color: 'permission', isDeferred: false, kind: 'used' },
  { name: 'Free space', tokens: 811000, color: 'promptBorder', isDeferred: false, kind: 'free' },
  { name: 'Autocompact buffer', tokens: 33000, color: 'inactive', isDeferred: false, kind: 'buffer' },
]

test('band draws on terminal and desktop', async ($, on) => {
  on('session.usage', () => ({ value: {
    startedAt: 0,
    context: {
      tokens: 156000,
      window: 1000000,
      percent: 16,
      breakdown: { categories: cats, totalTokens: 156000, maxTokens: 1000000, rawMaxTokens: 1000000, percentage: 16 },
    },
    rateLimits: [],
  } }))
  on('session.start', ($$, e) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: { command: 'context-bar' } }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({
      plugin: 'context-bar',
      surface,
      component: 'AbovePrompt',
      props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 100, scroll: { offset: 0, bodyRows: 10 }, view: {} },
    })
    expect(await ui.find({ type: 'Text', text: /context/ })).toBeDefined()
    await ui.unmount()
  }
})
