---
description: BBN health check - git, gh auth, claude CLI, node, MCP status, key presence, config validity, plan, ledger, with fix hints
---

Run `${CLAUDE_PLUGIN_ROOT}/scripts/bbn-doctor.sh` and report the FAIL/WARN lines with the `fix:` hint the script prints under each. Missing MCP servers are not errors: agents fall back to WebSearch/WebFetch. Never print secret values.
