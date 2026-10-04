export type Agent = {
  name: string
  source: string
  model: string | null
  description: string
  tokens: number
}

declare module 'claude-code' {
  interface PluginState {
    'agents-panel': { agents: Agent[] }
  }
}
