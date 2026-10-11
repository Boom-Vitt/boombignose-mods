#!/usr/bin/env node
// Validate bbn.config.json against bbn.config.schema.json and check that each agent's
// maxTurns frontmatter matches budgets.perRole. Exit 0 valid, 1 invalid.
// usage: node bbn-config-check.mjs [config-path]
import { readFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { PLUGIN_ROOT, validate } from './lib/bbn-node.mjs';

const cfgPath = resolve(process.argv[2] || join(PLUGIN_ROOT, 'bbn.config.json'));
const schema = JSON.parse(readFileSync(join(PLUGIN_ROOT, 'bbn.config.schema.json'), 'utf8'));
let cfg;
try { cfg = JSON.parse(readFileSync(cfgPath, 'utf8')); }
catch (e) { console.error(`bbn.config.json: INVALID JSON (${e.message})`); process.exit(1); }
const errors = validate(cfg, schema, 'config');

const agentsDir = join(PLUGIN_ROOT, 'agents');
for (const [role, b] of Object.entries(cfg.budgets?.perRole || {})) {
  const f = join(agentsDir, `${role}.md`);
  if (!existsSync(f)) { errors.push(`budgets.perRole.${role}: no agents/${role}.md`); continue; }
  const fm = (readFileSync(f, 'utf8').match(/^---\n([\s\S]*?)\n---/) || [])[1] || '';
  const t = fm.match(/^maxTurns:\s*(\d+)\s*$/m);
  if (!t) errors.push(`agents/${role}.md: missing maxTurns`);
  else if (Number(t[1]) !== b.maxTurns) errors.push(`agents/${role}.md: maxTurns ${t[1]} != budget ${b.maxTurns}`);
  if (/^tools:/m.test(fm)) errors.push(`agents/${role}.md: uses a tools: allowlist, which hides MCP tools; use disallowedTools`);
}
for (const [server, r] of Object.entries(cfg.mcpRouting || {}))
  for (const role of r.roles || [])
    if (!existsSync(join(agentsDir, `${role}.md`))) errors.push(`mcpRouting.${server}: unknown role ${role}`);

if (errors.length) { console.error('bbn.config.json: INVALID'); for (const e of errors) console.error('  - ' + e); process.exit(1); }
console.log('bbn.config.json: OK');
