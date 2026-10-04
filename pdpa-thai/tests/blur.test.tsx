import { expect, test } from 'claude-code/testing'

const MAIL = ['somchai', '@', 'mail.test'].join('')

test('draws a hover-reveal span on terminal and desktop', async $ => {
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({
      plugin: 'pdpa-thai',
      surface,
      component: 'AssistantMessage',
      props: { text: `contact ${MAIL} today`, isFirstOfReply: true },
    })
    expect(await ui.find({ type: 'Text', text: new RegExp(MAIL) })).toBeDefined()
    await ui.unmount()
  }
})
