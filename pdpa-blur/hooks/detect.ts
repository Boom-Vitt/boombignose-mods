// What counts as sensitive follows Thailand's PDPA B.E. 2562 (checked 2026-10-04):
//   s.6  personal data: anything identifying a person directly or indirectly (name, address,
//        phone, ID number, email, bank account, IP address, username/password...)
//   s.26 sensitive data: race/ethnicity, political opinion, religion/philosophy, sexual behaviour,
//        criminal record, health, disability, trade union, genetic, biometric
// https://getterms.io/blog/thailand-personal-data-protection-act-pdpa
// https://www.pricesanond.com/knowledge/archives-consumer-protection-and-regulatory-compliance/thailands-new-personal-data-protection-act.php
// A regex cannot read s.26 from prose, so those are caught as `label: value` only. Not legal advice.

export type Span = [start: number, end: number]
export type Piece = { text: string; hidden: boolean }
export type Chunk = { md: string } | { pieces: Piece[] }

type Rule = { re: RegExp; group?: number; ok?: (s: string) => boolean }

const digits = (s: string) => s.replace(/\D/g, '')

// mod-11 check digit of the 13-digit Thai national ID
const thaiId = (s: string) => {
  const d = digits(s)
  if (d.length !== 13) return false
  let sum = 0
  for (let i = 0; i < 12; i++) sum += Number(d[i]) * (13 - i)
  return (11 - (sum % 11)) % 10 === Number(d[12])
}

const luhn = (s: string) => {
  const d = digits(s)
  if (d.length < 13 || d.length > 19) return false
  let sum = 0
  for (let i = 0; i < d.length; i++) {
    let n = Number(d[d.length - 1 - i])
    if (i % 2) n = n * 2 > 9 ? n * 2 - 9 : n * 2
    sum += n
  }
  return sum % 10 === 0
}

const thaiPhone = (s: string) => {
  const d = digits(s)
  return (d[0] === '0' && (d.length === 9 || d.length === 10) && d.slice(0, 2) !== '00') ||
    (d.startsWith('66') && d.length === 11) ||
    (d.startsWith('0066') && d.length === 13)
}

const ipv4 = (s: string) => {
  const p = s.split('.').map(Number)
  return p.every(n => n <= 255) && p[0] !== 127 && s !== '0.0.0.0'
}

const SENSITIVE_LABEL =
  'เชื้อชาติ|ศาสนา|ความคิดเห็นทางการเมือง|พฤติกรรมทางเพศ|ประวัติอาชญากรรม|โรคประจำตัว|ประวัติการรักษา|ความพิการ|สหภาพแรงงาน|' +
  'race|ethnicity|religion|political(?: opinion)?|sexual orientation|criminal record|medical history|diagnosis|health condition|disability|trade union|genetic|biometric'

// every pattern uses [ -] not \s between digits so a match never crosses a line
const RULES: Rule[] = [
  { re: /(?<!\d)\d[ -]?\d{4}[ -]?\d{5}[ -]?\d{2}[ -]?\d(?!\d)/gd, ok: thaiId },
  { re: /(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)/gd, ok: luhn },
  { re: /(?<!\d)(?:\+66|0066|0)[ -]?(?:[689]\d|[2-7])[ -]?\d{3}[ -]?\d{3,4}(?!\d)/gd, ok: thaiPhone },
  { re: /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/gd, ok: s => !/@example\.(?:com|org|net)$/i.test(s) },
  { re: /(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])/gd, ok: ipv4 },
  // credentials and tokens (PDPA lists username/password as personal data)
  { re: /\b(?:sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,})/gd },
  { re: /\bBearer[ \t]+([A-Za-z0-9._~+/=-]{20,})/gdi, group: 1 },
  { re: /(?:password|passwd|pwd|secret|token|api[_-]?key|รหัสผ่าน)[ \t]*[:=][ \t]*["']?([^\s"',;]{4,})/gdi, group: 1 },
  // identifiers that only make sense next to their label
  { re: /(?:passport|เลขที่หนังสือเดินทาง|เลขพาสปอร์ต|พาสปอร์ต)\D{0,20}?([A-Z]{1,2}\d{6,8})\b/gdi, group: 1 },
  { re: /(?:เลขที่บัญชี|หมายเลขบัญชี|บัญชี|account[ \t]*(?:no\.?|number|#)|acct\.?|พร้อมเพย์|promptpay)\D{0,15}((?:\d[ -]?){9,14}\d)/gdi, group: 1 },
  { re: /(?:วันเกิด|date of birth|birth[ ]?date|dob)[ \t]*[:：]?[ \t]*(\d{1,4}[/.-]\d{1,2}[/.-]\d{1,4})/gdi, group: 1 },
  // s.26 sensitive categories, as `label: value`
  { re: new RegExp(`(?:${SENSITIVE_LABEL})[ \\t]*[:：=][ \\t]*([^\\n,;]{1,60})`, 'gdi'), group: 1 },
  { re: /(?:ที่อยู่|home address|mailing address)[ \t]*[:：][ \t]*([^\n]{5,120})/gdi, group: 1 },
  { re: /(?:ชื่อ-?นามสกุล|ชื่อ-สกุล|full name)[ \t]*[:：][ \t]*([^\n,;]{2,60})/gdi, group: 1 },
  // titled names
  { re: /(?<![ก-๙])(?:นาย|นางสาว|น\.ส\.|นาง|ด\.ช\.|ด\.ญ\.)[ ]?[ก-ฮเแโใไ][ก-๙]{1,30}(?:[ ][ก-ฮเแโใไ][ก-๙]{1,30})?/gd },
  { re: /\b(?:Mr|Mrs|Ms|Miss|Dr)\.?[ ]+[A-Z][a-z]+(?:[ ][A-Z][a-z]+)?/gd },
]

// ponytail: skips huge texts so a streaming reply is not re-scanned at 100k chars per frame
const MAX = 100_000

export function findSensitive(text: string): Span[] {
  if (text.length > MAX) return []
  const found: Span[] = []
  for (const { re, group = 0, ok } of RULES) {
    for (const m of text.matchAll(re)) {
      const at = m.indices?.[group]
      if (at && (!ok || ok(m[group]))) found.push([at[0], at[1]])
    }
  }
  found.sort((a, b) => a[0] - b[0])
  const merged: Span[] = []
  for (const s of found) {
    const last = merged[merged.length - 1]
    if (last && s[0] <= last[1]) last[1] = Math.max(last[1], s[1])
    else merged.push([s[0], s[1]])
  }
  return merged
}

function pieces(text: string, ls: number, le: number, spans: Span[]): Piece[] {
  const out: Piece[] = []
  let at = ls
  for (const [s, e] of spans) {
    if (e <= ls || s >= le) continue
    const a = Math.max(s, ls)
    const b = Math.min(e, le)
    if (a > at) out.push({ text: text.slice(at, a), hidden: false })
    out.push({ text: text.slice(a, b), hidden: true })
    at = b
  }
  if (at < le) out.push({ text: text.slice(at, le), hidden: false })
  return out
}

// Clean stretches stay Markdown; a line holding a span (or a whole code fence holding one) is
// drawn as plain pieces so each hidden span can carry its own hover. Fences are never split.
export function plan(text: string, spans: Span[]): Chunk[] {
  const units: { s: number; e: number; lines: [number, number][] }[] = []
  let at = 0
  let fence: (typeof units)[number] | null = null
  for (const line of text.split('\n')) {
    const span: [number, number] = [at, at + line.length]
    at += line.length + 1
    const isFence = /^\s*(```|~~~)/.test(line)
    if (fence) {
      fence.lines.push(span)
      fence.e = span[1]
      if (isFence) fence = null
    } else if (isFence) {
      fence = { s: span[0], e: span[1], lines: [span] }
      units.push(fence)
    } else units.push({ s: span[0], e: span[1], lines: [span] })
  }

  const out: Chunk[] = []
  let cleanFrom: number | null = null
  let cleanTo = 0
  const flush = () => {
    if (cleanFrom !== null) out.push({ md: text.slice(cleanFrom, cleanTo) })
    cleanFrom = null
  }
  for (const u of units) {
    if (spans.some(([s, e]) => s < u.e && e > u.s)) {
      flush()
      for (const [ls, le] of u.lines) out.push({ pieces: pieces(text, ls, le, spans) })
    } else {
      cleanFrom ??= u.s
      cleanTo = u.e
    }
  }
  flush()
  return out
}
