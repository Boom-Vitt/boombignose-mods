// What counts as sensitive follows Thailand's PDPA B.E. 2562 (checked 2026-10-04):
//   s.6  personal data: anything identifying a natural person directly or indirectly
//   s.26 sensitive data: ethnicity, race, political opinion, creed/religion/philosophy, sexual
//        behaviour, criminal record, health, disability, trade union, genetic, biometric
// https://www.pdpc.or.th/wp-content/uploads/2023/12/1_Personal-Data-Protection-2562.pdf
// A regex cannot read s.26 from prose, so those are caught as `label: value` only. Best effort,
// not legal advice. Every scan here is linear in the input: this runs on every tool result.

export type Kind =
  | 'THAI_ID' | 'CARD' | 'PHONE' | 'EMAIL' | 'IP' | 'SECRET' | 'PASSPORT'
  | 'BANK_ACCOUNT' | 'DOB' | 'SENSITIVE' | 'ADDRESS' | 'NAME'
export type Span = [start: number, end: number, kind: Kind]
export type Piece = { text: string; hidden: boolean }
export type Chunk = { md: string } | { pieces: Piece[] }

type Hit = [number, number]
type Rule = { kind: Kind; find: (s: string) => Iterable<Hit> }

// Rules run on a shadow of the text with the same length: Thai digits become Arabic and exotic
// horizontal spaces become ' ', so offsets still index the original.
const norm = (t: string) =>
  t
    .replace(/[๐-๙]/g, c => String.fromCharCode(c.charCodeAt(0) - 0x0e50 + 48))
    .replace(/[   -   　\t]/g, ' ')

const digits = (s: string) => s.replace(/\D/g, '')

// mod-11 check digit of the 13-digit Thai national ID
const thaiId = (s: string) => {
  const d = digits(s)
  if (d.length !== 13) return false
  let sum = 0
  for (let i = 0; i < 12; i++) sum += Number(d[i]) * (13 - i)
  return (11 - (sum % 11)) % 10 === Number(d[12])
}

const luhn = (d: string) => {
  let sum = 0
  for (let i = 0; i < d.length; i++) {
    let n = Number(d[d.length - 1 - i])
    if (i % 2) n = n * 2 > 9 ? n * 2 - 9 : n * 2
    sum += n
  }
  return sum % 10 === 0
}

// +66 / 0066 / trunk 0, then 8 digits (landline: 2 Bangkok, 3-7 provinces) or 9 (mobile 6/8/9)
const thaiPhone = (s: string) => {
  const d = digits(s)
  const n = d.startsWith('0066') ? d.slice(4) : s.startsWith('+') && d.startsWith('66') ? d.slice(2) : d.startsWith('0') ? d.slice(1) : ''
  return (n.length === 8 && /^[2-7]/.test(n)) || (n.length === 9 && /^[689]/.test(n))
}

const ipv4 = (s: string) => {
  const p = s.split('.').map(Number)
  return p.every(n => n <= 255) && p[0] !== 127 && s !== '0.0.0.0'
}

// a value that is code, not a secret: a type name, a dotted path, a call, a template, a shell var
const CODE_VALUE =
  /^(?:string|number|boolean|any|unknown|undefined|null|true|false|void|never|object|str|int|bool|None|Optional.*|Record.*|[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)+(?:[(\[].*)?|[A-Za-z_$][\w$]*\(.*|\$\{.*|\$[A-Za-z_]\w*|\{\{.*|<.*>|%\(.*|\*+|\.{3})$/

function re(kind: Kind, regex: RegExp, o: { groups?: number[]; ok?: (v: string) => boolean } = {}): Rule {
  return {
    kind,
    *find(s) {
      for (const m of s.matchAll(regex)) {
        const at = (o.groups ?? [0]).map(g => m.indices?.[g]).find(Boolean)
        if (at && at[1] > at[0] && (!o.ok || o.ok(s.slice(at[0], at[1])))) yield [at[0], at[1]]
      }
    },
  }
}

// the longest run of 13-19 digits (groups split by space or -) that passes Luhn, cut at a group
// boundary so a trailing stray digit cannot hide a real card
function* cards(s: string): Iterable<Hit> {
  for (const m of s.matchAll(/(?<!\d)\d(?:[ -]?\d){12,21}(?!\d)/g)) {
    const base = m.index
    const text = m[0]
    const starts: number[] = [0]
    const ends: number[] = []
    for (let i = 0; i < text.length; i++) {
      if (!/\d/.test(text[i])) starts.push(i + 1)
      else if (i + 1 === text.length || !/\d/.test(text[i + 1])) ends.push(i + 1)
    }
    let best: Hit | null = null
    for (const a of starts) {
      for (const b of ends) {
        const d = digits(text.slice(a, b))
        if (b > a && d.length >= 13 && d.length <= 19 && luhn(d) && (!best || b - a > best[1] - best[0])) best = [a, b]
      }
    }
    if (best) yield [base + best[0], base + best[1]]
  }
}

// a linear scan outward from each '@', so no input makes it quadratic
function* emails(s: string): Iterable<Hit> {
  const local = /[A-Za-z0-9._%+-]/
  const host = /[A-Za-z0-9.-]/
  for (let at = s.indexOf('@'); at !== -1; at = s.indexOf('@', at + 1)) {
    let a = at
    while (a > 0 && at - a < 64 && local.test(s[a - 1])) a--
    let b = at + 1
    while (b < s.length && b - at < 255 && host.test(s[b])) b++
    while (b > at + 1 && /[.-]/.test(s[b - 1])) b--
    const dom = s.slice(at + 1, b)
    if (a < at && /^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$/.test(dom) && !/^example\.(?:com|org|net)$/i.test(dom)) yield [a, b]
  }
}

const COLON = `["']?[ \\t]*[:：=][ \\t]*["']?`
// the value of `label: value`: starts at a non-blank (keeps scanning linear), runs to a delimiter,
// trailing blanks excluded; a value opening with [ or { (an array or object) is not matched
const VALUE = `([^\\s,;"'}\\[{](?:[^\\n,;"'}]*[^\\s,;"'}])?)`
const labelled = (kind: Kind, labels: string) =>
  re(kind, new RegExp(`(?:${labels})${COLON}${VALUE}`, 'gdi'), { groups: [1] })

const SENSITIVE_LABEL =
  'เชื้อชาติ|เผ่าพันธุ์|ศาสนา|ความเชื่อ|ลัทธิ|ความคิดเห็นทางการเมือง|พฤติกรรมทางเพศ|ประวัติอาชญากรรม|โรคประจำตัว|ประวัติการรักษา|ข้อมูลสุขภาพ|ความพิการ|สหภาพแรงงาน|ข้อมูลพันธุกรรม|ข้อมูลชีวภาพ|' +
  'race|ethnicity|religion|political(?: opinion)?|sexual (?:orientation|behaviou?r)|criminal (?:record|history)|medical history|diagnosis|health (?:condition|data)|disability|trade union|genetic(?: data)?|biometric(?: data)?'

// นาย/นาง/นางสาว/ด.ช./ด.ญ. + name, minus the compounds that merely start with a title
const NOT_A_NAME = 'จ้าง|หน้า|ก(?:รัฐ|เทศ|สมาคม|ฯ)|ทะเบียน|ธนาคาร|ช่าง|อำเภอ|แพทย์|ตำรวจ|พยาบาล|งาม|ฟ้า|ท้าย|ท่า|เหมือง|ห้าง|ประกัน'

const RULES: Rule[] = [
  re('THAI_ID', /(?<!\d)\d[ -]?\d{4}[ -]?\d{5}[ -]?\d{2}[ -]?\d(?!\d)/gd, { ok: thaiId }),
  { kind: 'CARD', find: cards },
  re('PHONE', /(?<!\d)(?:\+66|0066|0)[ -]?\d(?:[ -]?\d){7,8}(?!\d)/gd, { ok: thaiPhone }),
  { kind: 'EMAIL', find: emails },
  re('IP', /(?<![\d.vV])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])/gd, { ok: ipv4 }),
  // credentials and tokens
  re('SECRET', /\b(?:sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,})/gd),
  re('SECRET', /\bBearer[ \t]+([A-Za-z0-9._~+/=-]{20,})/gdi, { groups: [1] }),
  re(
    'SECRET',
    /(?:password|passwd|pwd|passphrase|secret|token|api[_-]?key|access[_-]?key|รหัสผ่าน)["']?[ \t]*[:=][ \t]*(?:"((?:[^"\\\n]|\\.)*)"|'((?:[^'\\\n]|\\.)*)'|([^\s"',;]+))/gdi,
    { groups: [1, 2, 3], ok: v => !CODE_VALUE.test(v) },
  ),
  // identifiers that only make sense next to their label
  re('PASSPORT', /(?:passport|เลขที่หนังสือเดินทาง|เลขพาสปอร์ต|พาสปอร์ต)\D{0,20}?([A-Z]{1,2}\d{6,8})\b/gdi, { groups: [1] }),
  re('BANK_ACCOUNT', /(?:เลขที่บัญชี|หมายเลขบัญชี|บัญชี|account[ \t]*(?:no\.?|number|#)|acct\.?|พร้อมเพย์|promptpay)\D{0,15}((?:\d[ -]?){9,14}\d)/gdi, { groups: [1] }),
  re('DOB', /(?:วันเกิด|date of birth|birth[ ]?date|dob)["']?[ \t]*(?:[:：][ \t]*)?["']?(\d{1,4}[/.-]\d{1,2}[/.-]\d{1,4})/gdi, { groups: [1] }),
  // s.26 sensitive categories, and name/address, as `label: value`
  labelled('SENSITIVE', SENSITIVE_LABEL),
  labelled('ADDRESS', 'ที่อยู่|home address|mailing address'),
  labelled('NAME', 'ชื่อ-?นามสกุล|ชื่อ-สกุล|ชื่อจริง|นามสกุล|ชื่อ|full[ _]?name|first[ _]?name|last[ _]?name|surname'),
  // titled names
  re('NAME', new RegExp(`(?<![ก-๙])(?:นางสาว|นาง|นาย|น\\.ส\\.|ด\\.ช\\.|ด\\.ญ\\.)(?!${NOT_A_NAME})[ \\t]*[ก-ฮเแโใไ][ก-๙]{1,30}(?:[ \\t]+[ก-ฮเแโใไ][ก-๙]{1,30})?`, 'gd')),
  re('NAME', /\b(?:Mr|Mrs|Ms|Miss|Dr)\.?[ \t]+[A-Z][a-z]+(?:[ \t]+[A-Z][a-z]+)?/gd),
]

// The tag that replaces a value: kind, a number, and a per-session suffix. The suffix makes a tag
// this session issued recognisable, so only a real tag is refused in a tool call, not a document
// or test that merely mentions the format.
const TAG = 'RE' + 'DACTED'
const PLACEHOLDER = new RegExp(`\\[${TAG}:([A-Z_]+)_(\\d+)(?:~[a-z0-9]+)?\\]`, 'g')

export const issuedTag = (sfx: string) => new RegExp(`\\[${TAG}:[A-Z_]+_\\d+~${sfx}\\]`)

export function findSensitive(text: string): Span[] {
  const s = norm(text)
  const found: Span[] = []
  for (const rule of RULES) for (const [a, b] of rule.find(s)) found.push([a, b, rule.kind])
  found.sort((x, y) => x[0] - y[0] || y[1] - x[1])

  // a tag from an earlier pass is never re-detected, so redaction is idempotent
  const held = [...s.matchAll(PLACEHOLDER)].map(m => [m.index, m.index + m[0].length])
  const free = held.length ? found.filter(([a, b]) => !held.some(([ha, hb]) => a < hb && b > ha)) : found

  const merged: Span[] = []
  for (const sp of free) {
    const last = merged[merged.length - 1]
    if (last && sp[0] < last[1]) last[1] = Math.max(last[1], sp[1])
    else merged.push([sp[0], sp[1], sp[2]])
  }
  return merged
}

export type Tags = { sfx: string; seen: Map<string, number>; counts: Partial<Record<Kind, number>> }
export const newTags = (sfx = ''): Tags => ({ sfx, seen: new Map(), counts: {} })

// Replaces each span with a tag the model can still refer to (PHONE_1); the same value gets the
// same tag across everything sharing one `tags`. Irreversible on purpose: the mod keeps no
// mapping back to the original value. Numbers already present in the text are reserved, never reused.
export function redact(text: string, tags: Tags = newTags()): { text: string; found: number } {
  const spans = findSensitive(text)
  if (spans.length === 0) return { text, found: 0 }
  const s = norm(text)
  for (const m of s.matchAll(PLACEHOLDER)) {
    const kind = m[1] as Kind
    tags.counts[kind] = Math.max(tags.counts[kind] ?? 0, Number(m[2]))
  }
  let out = ''
  let at = 0
  for (const [a, b, kind] of spans) {
    const key = `${kind}:${s.slice(a, b)}`
    let n = tags.seen.get(key)
    if (!n) {
      n = tags.counts[kind] = (tags.counts[kind] ?? 0) + 1
      tags.seen.set(key, n)
    }
    out += `${text.slice(at, a)}[${TAG}:${kind}_${n}${tags.sfx ? `~${tags.sfx}` : ''}]`
    at = b
  }
  return { text: out + text.slice(at), found: spans.length }
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

export type Hits = { n: number }

// a row's content is a string or blocks; only text and tool_result text are rewritten. One tag
// table per row, so a value repeated across blocks keeps one tag and numbers never collide.
export function scrub(content: unknown, hits: Hits, tags: Tags = newTags()): unknown {
  if (typeof content === 'string') {
    const r = redact(content, tags)
    hits.n += r.found
    return r.text
  }
  if (!Array.isArray(content)) return content
  return content.map(block => {
    if (block?.type === 'text' && typeof block.text === 'string') {
      const r = redact(block.text, tags)
      hits.n += r.found
      return { ...block, text: r.text }
    }
    return block?.type === 'tool_result' ? { ...block, content: scrub(block.content, hits, tags) } : block
  })
}
