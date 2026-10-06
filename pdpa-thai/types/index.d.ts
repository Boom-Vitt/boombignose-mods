declare module 'claude-code' {
  interface PluginState {
    'pdpa-thai': { isBlurOn: boolean; isRecording: boolean; guardMode: 'redact' | 'block' | 'off'; tagSuffix: string }
  }
}
