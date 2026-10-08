# ADR-0002: Perplexity via sign-in (OAuth), optional, with web search fallback

- **Status:** Accepted
- **Date:** 2026-10-08
- **Deciders:** Boom + Orca workflow maintainers

## Context

v0.1-v0.2 shipped `.mcp.json` with `Authorization: Bearer ${PERPLEXITY_API_KEY}`. On a machine without that variable the header was sent with an empty token, Perplexity answered HTTP 401, and Claude Code disables OAuth fallback whenever `headers.Authorization` is set, so the server could never connect. Agent definitions also used `tools:` allowlists, which hide every MCP tool from the subagent, so even a working Perplexity or Context7 server was unreachable from the role agents.

## Decision

1. The plugin's Perplexity entry is the remote server `https://api.perplexity.ai/mcp` with **no** header. Users sign in once with `/mcp` (Perplexity's documented Claude Code setup). Users who prefer an API key add a separate user-scoped server (README).
2. Perplexity and Context7 are optional. Agents fall back to built-in `WebSearch`/`WebFetch` and say so.
3. Agents use `disallowedTools` (denylist) instead of `tools` (allowlist) so MCP tools are inherited.

## Consequences

- No secret in the plugin; nothing fails without a key (status shows "needs authentication" instead of an error).
- Sign-in bills the Perplexity API organization chosen at sign-in; the user must be an admin of one.
- Read-only roles (planner, reviewer) are restricted by denying Write/Edit/NotebookEdit rather than by allowlist.
