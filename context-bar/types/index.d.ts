export type Cat = { name: string; tokens: number; color: string; kind: string }
export type Fill = {
  cats: Cat[]
  total: number
  window: number
  pct: number
  compactAt: number | null
}
// seconds of prompt cache left; 'live' while a turn runs; null before the first turn
export type Cache = number | 'live' | null

declare module 'claude-code' {
  interface PluginState {
    'context-bar': { fill: Fill | null; isHidden: boolean; cache: Cache; endsAt: number | null }
  }
}
