import { expect, test } from 'claude-code/testing'

import { findSensitive, plan } from '../hooks/detect'

const hit = (t: string) => findSensitive(t).map(([s, e]) => t.slice(s, e))

test('flags PDPA identifiers', () => {
  expect(hit('id 1234567890121 ok')).toEqual(['1234567890121'])
  expect(hit('บัตร 1-2345-67890-12-1')).toEqual(['1-2345-67890-12-1'])
  expect(hit('card 4111 1111 1111 1111.')).toEqual(['4111 1111 1111 1111'])
  expect(hit('call 081-234-5678 or +66 81 234 5678 or 02-123-4567')).toEqual(['081-234-5678', '+66 81 234 5678', '02-123-4567'])
  expect(hit('mail somchai@mail.test')).toEqual(['somchai@mail.test'])
  expect(hit('from 192.168.1.10')).toEqual(['192.168.1.10'])
  expect(hit('password: hunter2!')).toEqual(['hunter2!'])
  expect(hit('ศาสนา: พุทธ')).toEqual(['พุทธ'])
  expect(hit('บัญชี 123-4-56789-0')).toEqual(['123-4-56789-0'])
  expect(hit('นายสมชาย ใจดี')).toEqual(['นายสมชาย ใจดี'])
})

test('leaves ordinary text alone', () => {
  expect(hit('1234567890123 has a bad checksum')).toEqual([])
  expect(hit('a@example.com, 127.0.0.1, 999.1.1.1, v1.2.3, order 12345 total 9999')).toEqual([])
  expect(hit('const address: string')).toEqual([])
})

test('plan keeps clean markdown whole and never splits a fence', () => {
  const text = 'hello\nmail a@b.co\n```\ncode\n```\nbye'
  const chunks = plan(text, findSensitive(text))
  expect(chunks.length).toBe(3)
  expect('md' in chunks[0]).toBe(true)
  expect('pieces' in chunks[1]).toBe(true)
  expect((chunks[2] as { md: string }).md).toBe('```\ncode\n```\nbye')

  const fenced = '```\nkey: a@b.co\nmore\n```'
  expect(plan(fenced, findSensitive(fenced)).every(c => 'pieces' in c)).toBe(true)
})

test('draws a hover-reveal span on terminal and desktop', async $ => {
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({
      plugin: 'pdpa-blur',
      surface,
      component: 'AssistantMessage',
      props: { text: 'contact somchai@mail.test today', isFirstOfReply: true },
    })
    expect(await ui.find({ type: 'Text', text: /somchai@mail.test/ })).toBeDefined()
    await ui.unmount()
  }
})
