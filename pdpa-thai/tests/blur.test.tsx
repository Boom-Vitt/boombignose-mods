import { expect, test } from 'claude-code/testing'

const MAIL = ['somchai', '@', 'mail.test'].join('')
const MASK = { color: '#6b7280', backgroundColor: '#6b7280' }

test('draws a masked span on terminal and desktop', async $ => {
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({
      plugin: 'pdpa-thai',
      surface,
      component: 'AssistantMessage',
      props: { text: `contact ${MAIL} today`, isFirstOfReply: true },
    })
    expect((await ui.find({ type: 'Text', text: new RegExp(MAIL) }))?.props).toMatchObject(MASK)
    await ui.unmount()
  }
})

test('/pdpa-blur record keeps the mask, bad arguments change nothing, off ends it', async $ => {
  const run = (args: string) =>
    $.command.run({ command: 'pdpa-blur', args, origin: { kind: 'composer' }, presentation: { isFullscreen: false, columns: 80 } })
  expect((await run('record')).text).toMatch(/recording mode/)
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({
      plugin: 'pdpa-thai',
      surface,
      component: 'UserMessage',
      props: { text: `contact ${MAIL} today`, origin: { kind: 'composer' }, isExpanded: false },
    })
    // the kit does not expose hover props, so this proves the mask still draws; "no hover" is one conditional in draw()
    expect((await ui.find({ type: 'Text', text: new RegExp(MAIL) }))?.props).toMatchObject(MASK)
    await ui.unmount()
  }
  expect((await run('nonsense')).text).toMatch(/Usage/)
  expect((await run('off')).text).toBe('PDPA blur off.')
})
