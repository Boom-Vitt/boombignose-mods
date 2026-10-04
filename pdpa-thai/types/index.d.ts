declare module 'claude-code' {
  interface PluginState {
    'pdpa-thai': { isBlurOn: boolean; guardMode: 'redact' | 'block' | 'off'; tagSuffix: string }
  }
}
