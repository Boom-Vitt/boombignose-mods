---
description: First-time Orca setup - Perplexity sign-in, optional API key route, optional CI gate template
---

Walk the user through setup, step by step, and report what is done:

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/orca-doctor.sh` and summarise.
2. Perplexity (optional): the plugin connects to `https://api.perplexity.ai/mcp` with sign-in (OAuth). Tell the user to run `/mcp`, choose `plugin:boom-big-nose-workflow:perplexity`, and sign in (needs admin of a Perplexity API organization with billing). Without it, agents use WebSearch automatically.
   - Key route instead: see the README section "Using an API key instead" (Thai: "ใช้ API key แทน"). Never ask the user to paste a key into chat; never print or store a key.
3. Context7 needs nothing (optional `CONTEXT7_API_KEY` for higher limits).
4. Point the user to the quickstart (`${CLAUDE_PLUGIN_ROOT}/docs/QUICKSTART.md` Thai, `QUICKSTART.en.md` English) and suggest `/orca-plan init` for their first feature.
5. Optional CI gate for a project: copy `${CLAUDE_PLUGIN_ROOT}/scripts/orca-gate.sh` to `<repo>/.github/scripts/orca-gate.sh` and `${CLAUDE_PLUGIN_ROOT}/templates/github/orca-gate.yml` to `<repo>/.github/workflows/orca-gate.yml`, only if the user asks, and do not commit for them.
