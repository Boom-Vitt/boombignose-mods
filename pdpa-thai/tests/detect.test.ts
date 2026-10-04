import { expect, test } from 'claude-code/testing'

import { findSensitive, issuedTag, newTags, plan, redact, scrub } from '../hooks/detect'

// samples are made up: some assembled from fragments, some obviously fictional
const j = (...p: string[]) => p.join('')
const TAG = j('RE', 'DACTED')
const tag = (kind: string, n: number, sfx = '') => `[${TAG}:${kind}_${n}${sfx ? `~${sfx}` : ''}]`
const thai = (s: string) => s.replace(/\d/g, d => String.fromCharCode(0x0e50 + Number(d)))
const ID = j('12345', '67890', '121') // valid mod-11 checksum
const CARD = [j('4111'), j('1111'), j('1111'), j('1111')].join(' ') // Luhn test number
const PHONE = ['081', '234', '5678'].join('-')
const MAIL = j('somchai', '@', 'mail.test')

const hit = (t: string) => findSensitive(t).map(([s, e]) => t.slice(s, e))
const ms = (f: () => void) => {
  const t0 = Date.now()
  f()
  return Date.now() - t0
}

test('flags PDPA identifiers', () => {
  expect(hit(`id ${ID} ok`)).toEqual([ID])
  expect(hit(`บัตร ${[ID[0], ID.slice(1, 5), ID.slice(5, 10), ID.slice(10, 12), ID[12]].join('-')}`).length).toBe(1)
  expect(hit(`card ${CARD}.`)).toEqual([CARD])
  expect(hit(`call ${PHONE} or ${j('+66 81 ', '234 5678')}`).length).toBe(2)
  expect(hit(`mail ${MAIL}`)).toEqual([MAIL])
  expect(hit(`from ${['192', '168', '1', '10'].join('.')}`).length).toBe(1)
  expect(hit('บัญชี 123-4-56789-0')).toEqual(['123-4-56789-0'])
  expect(hit('นายสมชาย ใจดี')).toEqual(['นายสมชาย ใจดี'])
})

test('Thai numerals, odd spaces and every landline shape', () => {
  expect(hit(thai(PHONE)).length).toBe(1)
  expect(hit(['081', '234', '5678'].join(' ')).length).toBe(1)
  expect(hit(thai(ID)).length).toBe(1)
  for (const landline of [j('053', '-123', '-456'), j('+66 2 ', '123 4567'), j('0066 2 ', '123 4567'), j('02', '-123', '-4567')]) {
    expect(hit(`tel ${landline}`)).toEqual([landline])
  }
})

test('a stray trailing or leading digit cannot hide a card', () => {
  expect(hit(`${j('4111', '1111', '1111', '1111')} 1`)).toEqual([j('4111', '1111', '1111', '1111')])
  expect(hit(`1 ${CARD}`)).toEqual([CARD])
  expect(hit(j('4111', '1111', '1111', '11111'))).toEqual([]) // 17 digits glued: not a card
})

test('JSON and quoted labels, complete values, no length cap', () => {
  const json = JSON.stringify({ password: 'hunter2!', dob: '1990-01-02', 'full name': 'Somchai Jaidee', religion: 'Buddhist' })
  expect(hit(json)).toEqual(['hunter2!', '1990-01-02', 'Somchai Jaidee', 'Buddhist'])
  expect(hit('password: "horse battery staple"')).toEqual(['horse battery staple'])
  expect(hit('password: a')).toEqual(['a'])
  const long = `ศาสนา: ${'ก'.repeat(80)}`
  expect(hit(long)).toEqual(['ก'.repeat(80)])
  expect(hit('ข้อมูลสุขภาพ: HIV')).toEqual(['HIV'])
  expect(hit('ข้อมูลพันธุกรรม: BRCA1')).toEqual(['BRCA1'])
  expect(hit('ชื่อ: สมชาย ใจดี')).toEqual(['สมชาย ใจดี'])
  expect(hit('นายสมชาย\t ใจดี')).toEqual(['นายสมชาย\t ใจดี'])
})

test('leaves ordinary text and code alone', () => {
  expect(hit(`${j('12345', '67890', '123')} has a bad checksum`)).toEqual([])
  expect(hit(`a${'@'}example.com, 127.0.0.1, 999.1.1.1, v1.2.3.4, order 12345 total 9999`)).toEqual([])
  expect(hit('const address: string')).toEqual([])
  for (const code of [
    'const token: string = config.token;',
    'password: str',
    'api_key = process.env.API_KEY',
    'token = get_token()',
    'password: ${PASSWORD}',
    'secret = os.environ["SECRET"]',
  ]) {
    expect(hit(code)).toEqual([])
  }
  for (const word of ['นายจ้าง', 'นายกรัฐมนตรี', 'นางฟ้า', 'นายทะเบียน']) expect(hit(word)).toEqual([])
})

test('tags: kinds, repeats, shared numbering, reserved numbers, idempotence', () => {
  const r = redact(`${PHONE} then ${MAIL} then ${PHONE}`)
  expect(r.text).toBe(`${tag('PHONE', 1)} then ${tag('EMAIL', 1)} then ${tag('PHONE', 1)}`)
  expect(r.found).toBe(3)
  expect(redact('nothing here')).toEqual({ text: 'nothing here', found: 0 })

  // already-tagged text is left alone, even right after a secret label, and numbers are not reused
  const again = redact(r.text)
  expect(again).toEqual({ text: r.text, found: 0 })
  expect(redact(`password: ${tag('EMAIL', 2)}`).found).toBe(0)
  expect(redact(`${tag('PHONE', 3)} and ${PHONE}`).text).toBe(`${tag('PHONE', 3)} and ${tag('PHONE', 4)}`)

  // one table per row: a repeat across blocks keeps its tag, a new value gets the next number
  const hits = { n: 0 }
  const out = scrub([{ type: 'text', text: PHONE }, { type: 'text', text: `${j('082', '-345', '-6789')} ${PHONE}` }], hits) as { text: string }[]
  expect(out.map(b => b.text)).toEqual([tag('PHONE', 1), `${tag('PHONE', 2)} ${tag('PHONE', 1)}`])
})

test('this session tags are recognised, a mention of the format is not', () => {
  const r = redact(`call ${PHONE}`, newTags('k3x9'))
  expect(r.text).toBe(`call ${tag('PHONE', 1, 'k3x9')}`)
  expect(issuedTag('k3x9').test(r.text)).toBe(true)
  expect(issuedTag('zzzz').test(r.text)).toBe(false)
  expect(issuedTag('k3x9').test(`docs show ${tag('PHONE', 1)} as an example`)).toBe(false)
})

test('size and time: oversized text is still scanned, hostile text stays linear', () => {
  expect(hit(`${'x'.repeat(150_000)} ${MAIL}`)).toEqual([MAIL])
  expect(ms(() => findSensitive('a'.repeat(100_000)))).toBeLessThan(1000)
  expect(ms(() => findSensitive('@'.repeat(50_000)))).toBeLessThan(2000)
  expect(ms(() => findSensitive('a@'.repeat(30_000)))).toBeLessThan(2000)
  expect(ms(() => findSensitive('1 '.repeat(50_000)))).toBeLessThan(2000)
  expect(ms(() => findSensitive('password: '.repeat(10_000)))).toBeLessThan(2000)
})

test('blank runs after a label cannot stall a hook (a hook past its time limit is skipped)', () => {
  const blanks = [' ', '\t', ' \t', '\u00a0']
  for (const label of ['dob', 'dob:', 'วันเกิด:', 'full name:', 'full name', 'ชื่อ:', 'diagnosis=', 'ศาสนา: ', 'password:', 'address:'])
    for (const b of blanks) expect(ms(() => findSensitive(label + b.repeat(150_000)))).toBeLessThan(500)
  expect(ms(() => findSensitive('name:a' + ' '.repeat(150_000) + '\n'))).toBeLessThan(500)
  expect(ms(() => findSensitive('name: '.repeat(30_000)))).toBeLessThan(1000)
  expect(ms(() => findSensitive('password:"'.repeat(20_000)))).toBeLessThan(1000)
})

test('an array or object value is left alone rather than half-redacted', () => {
  expect(hit('"diagnosis": ["flu", "cold"]')).toEqual([])
  expect(hit('"full name": {"first": 1}')).toEqual([])
  expect(hit('"religion": "Buddhist"')).toEqual(['Buddhist'])
})

test('scrub rewrites text and tool_result text, leaves every other block whole', () => {
  const hits = { n: 0 }
  const image = { type: 'image', source: { type: 'base64', data: PHONE } }
  const use = { type: 'tool_use', id: 't', name: 'Bash', input: { command: `echo ${PHONE}` } }
  const out = scrub(
    [
      { type: 'text', text: `tel ${PHONE}` },
      { type: 'tool_result', tool_use_id: 't', content: [{ type: 'text', text: `also ${PHONE}` }] },
      { type: 'tool_result', tool_use_id: 'u', content: `str ${PHONE}` },
      image,
      use,
    ],
    hits,
  ) as unknown[]
  expect(hits.n).toBe(3)
  expect(JSON.stringify(out.slice(0, 3))).not.toContain(PHONE)
  expect(out[3]).toBe(image)
  expect(out[4]).toBe(use)
  expect(scrub(undefined, { n: 0 })).toBe(undefined)
})

test('plan keeps clean markdown whole and never splits a fence', () => {
  const text = `hello\nmail ${MAIL}\n\`\`\`\ncode\n\`\`\`\nbye`
  const chunks = plan(text, findSensitive(text))
  expect(chunks.length).toBe(3)
  expect('md' in chunks[0]).toBe(true)
  expect('pieces' in chunks[1]).toBe(true)
  expect((chunks[2] as { md: string }).md).toBe('```\ncode\n```\nbye')

  const fenced = `\`\`\`\nkey: ${MAIL}\nmore\n\`\`\``
  expect(plan(fenced, findSensitive(fenced)).every(c => 'pieces' in c)).toBe(true)
})
