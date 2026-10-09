---
description: First-time BBN setup - Perplexity sign-in, optional API key route, optional CI gate template
---

Walk the user through setup, step by step, and report what is done:

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/bbn-doctor.sh` and summarise.
2. Perplexity (optional): the plugin connects to `https://api.perplexity.ai/mcp` with sign-in (OAuth). Tell the user to run `/mcp`, choose `plugin:boom-big-nose-workflow:perplexity`, and sign in (needs admin of a Perplexity API organization with billing). Without it, the hub uses WebSearch automatically.
   - Key route instead: see the README section "Using an API key instead" (Thai: "ใช้ API key แทน"). Never ask the user to paste a key into chat; never print or store a key.
3. Context7 needs nothing (optional `CONTEXT7_API_KEY` for higher limits).
4. Point the user to the quickstart (`${CLAUDE_PLUGIN_ROOT}/docs/QUICKSTART.md` Thai, `QUICKSTART.en.md` English) and tell them they can just describe their first feature in plain words (autopilot), or use `/bbn-plan init` to go step by step. If `bbn-doctor` warned about the Codex CLI, mention `npm install -g @openai/codex`, then `codex login` (optional).
5. Optional CI gate for a project: copy `${CLAUDE_PLUGIN_ROOT}/scripts/bbn-gate.sh` to `<repo>/.github/scripts/bbn-gate.sh` and `${CLAUDE_PLUGIN_ROOT}/templates/github/bbn-gate.yml` to `<repo>/.github/workflows/bbn-gate.yml`, only if the user asks, and do not commit for them.
