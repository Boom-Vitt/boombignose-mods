#!/usr/bin/env node
// BBN plan checkpoint. The plan lives at <main worktree>/.bbn/plan.json (git-excluded).
//   init [--title T] [--overwrite]   write a draft template
//   check [--file F]                 validate: schema, slugs, deps (no cycles), budgets, ownership overlaps
//   accept [--by user|reviewer]      check + mark accepted (records a hash; any later edit needs re-accept)
//   apply [--apply] [--only SLUG] [--base R]  dry-run by default; --apply creates one worktree per stream in dependency
//                                    order and writes paths/deps/acceptance into each .bbn/ownership.json
//   show                             print the plan as a short summary
//   deps-merged --branch B [--base R]  exit 3 if a stream B depends on is not merged into base yet
//   stream-id [--branch B]           print the id of the plan stream on branch B (nothing if none)
// Exit: 0 ok, 1 invalid plan, 2 usage, 3 refused (not accepted / changed since accept / order)
import { readFileSync, writeFileSync, mkdirSync, existsSync, appendFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';
import { PLUGIN_ROOT, git, gitOk, readJson, loadConfig, pickBase, worktrees, ledger, checkPlan as checkPlanCfg, hashStreams, streamId } from './lib/bbn-node.mjs';

const [cmd, ...rest] = process.argv.slice(2);
const opt = (name) => { const i = rest.indexOf(name); return i >= 0 ? (rest[i + 1] ?? '') : undefined; };
const flag = (name) => rest.includes(name);
const die = (msg, code) => { console.error(`[bbn-plan] ${msg}`); process.exit(code); };
const log = (msg) => console.log(`[bbn-plan] ${msg}`);

if (!gitOk(['rev-parse', '--is-inside-work-tree'])) die('not inside a git repo', 2);
const mainWt = worktrees()[0].path;
const planPath = opt('--file') ? opt('--file') : join(mainWt, '.bbn', 'plan.json');
const cfg = loadConfig();
const checkPlan = (plan) => checkPlanCfg(plan, cfg);

function ensureExcluded() {
  const excl = join(git(['rev-parse', '--path-format=absolute', '--git-common-dir']), 'info', 'exclude');
  mkdirSync(join(excl, '..'), { recursive: true });
  const cur = existsSync(excl) ? readFileSync(excl, 'utf8') : '';
  if (!cur.split('\n').includes('.bbn/')) appendFileSync(excl, (cur.endsWith('\n') || !cur ? '' : '\n') + '.bbn/\n');
}
function loadPlan() {
  if (!existsSync(planPath)) die(`no plan at ${planPath} (run: bbn-plan.mjs init)`, 2);
  const plan = readJson(planPath);
  if (!plan) die(`${planPath} is not valid JSON`, 1);
  return plan;
}
function report({ errors, warnings }) {
  for (const w of warnings) log(`warn: ${w}`);
  if (errors.length) { console.error('[bbn-plan] plan INVALID'); for (const e of errors) console.error('  - ' + e); return false; }
  return true;
}

switch (cmd) {
  case 'init': {
    if (existsSync(planPath) && !flag('--overwrite')) die(`${planPath} exists (use --overwrite)`, 3);
    mkdirSync(join(planPath, '..'), { recursive: true }); ensureExcluded();
    const tpl = {
      $schema: 'bbn.plan.schema.json', version: 1, title: opt('--title') || 'TODO title', status: 'draft',
      goal: 'TODO: one sentence goal and how we know it is done',
      nonGoals: [], risks: [], replanTriggers: [],
      streams: [
        { slug: 'example-api', role: 'claude-code', summary: 'TODO', paths: ['src/api/'], dependsOn: [], acceptance: ['npm test -- api'] },
        { slug: 'example-ui', role: 'claude-code', summary: 'TODO', paths: ['src/ui/'], dependsOn: ['example-api'], acceptance: ['npm test -- ui'] },
      ],
    };
    writeFileSync(planPath, JSON.stringify(tpl, null, 2) + '\n');
    log(`draft written: ${planPath}`); break;
  }
  case 'check': {
    const r = checkPlan(loadPlan());
    if (!report(r)) process.exit(1);
    log(`plan OK; merge order by dependsOn: ${r.order.join(' -> ')}`); break;
  }
  case 'accept': {
    const by = opt('--by') ?? 'user';
    if (!['user', 'reviewer'].includes(by)) { console.error('accept --by must be user or reviewer'); process.exit(2); }
    const plan = loadPlan(); const r = checkPlan(plan);
    if (!report(r)) process.exit(1);
    plan.status = 'accepted'; plan.acceptedAt = new Date().toISOString(); plan.planHash = hashStreams(plan);
    writeFileSync(planPath, JSON.stringify(plan, null, 2) + '\n');
    ledger('plan.accept', { title: plan.title, streams: plan.streams.length, hash: plan.planHash, by });
    log(`accepted (hash ${plan.planHash}); next: apply`); break;
  }
  case 'apply': {
    const plan = loadPlan(); const r = checkPlan(plan);
    if (!report(r)) process.exit(1);
    if (plan.status !== 'accepted') die('plan is a draft; it must pass the checkpoint first (accept)', 3);
    if (plan.planHash !== hashStreams(plan)) die('plan changed after it was accepted; review and accept again', 3);
    const bySlug = new Map(plan.streams.map((s) => [s.slug, s]));
    const have = new Set(worktrees().map((w) => w.branch));
    const only = opt('--only');
    if (only !== undefined && !bySlug.has(only)) die(`--only: no stream '${only}' in the plan`, 2);
    const todo = r.order.filter((s) => !have.has(`feature/${s}`) && (only === undefined || s === only));
    log(`${todo.length} worktree(s) to create: ${todo.join(', ') || 'none'}${flag('--apply') ? '' : ' (dry-run; add --apply)'}`);
    if (!flag('--apply')) break;
    for (const slug of todo) {
      const args = [slug]; const b = opt('--base') || plan.base; if (b) args.push('--base', b);
      execFileSync(join(PLUGIN_ROOT, 'scripts', 'worktree-new.sh'), args, { stdio: 'inherit', cwd: mainWt });
      const wt = worktrees().find((w) => w.branch === `feature/${slug}`);
      const own = join(wt.path, '.bbn', 'ownership.json');
      const s = bySlug.get(slug);
      const o = { ...readJson(own, {}), role: s.role, summary: s.summary || '', paths: s.paths, dependsOn: s.dependsOn || [], acceptance: s.acceptance, planHash: plan.planHash };
      writeFileSync(own, JSON.stringify(o, null, 2) + '\n');
    }
    ledger('plan.apply', { created: todo.length, hash: plan.planHash });
    break;
  }
  case 'show': {
    const plan = loadPlan();
    console.log(`${plan.title} [${plan.status}${plan.planHash ? ' ' + plan.planHash : ''}]\ngoal: ${plan.goal}`);
    for (const s of plan.streams) console.log(`- ${s.slug} (${s.role}) paths: ${s.paths.join(', ')}${s.dependsOn?.length ? ' after: ' + s.dependsOn.join(', ') : ''}`);
    break;
  }
  case 'deps-merged': {
    const branch = opt('--branch') || git(['rev-parse', '--abbrev-ref', 'HEAD']);
    if (!existsSync(planPath)) break;                       // no plan: nothing to enforce
    const plan = readJson(planPath); if (!plan?.streams) break;
    const s = plan.streams.find((x) => `feature/${x.slug}` === branch); if (!s) break;
    let base; try { base = pickBase(opt('--base')); } catch (e) { die(e.message, 2); }
    const local = base.replace(/^origin\//, '');
    const pending = (s.dependsOn || []).filter((d) => {
      const ref = `refs/heads/feature/${d}`;
      if (!gitOk(['rev-parse', '--verify', '--quiet', ref])) return false;   // already merged and deleted
      const merged = gitOk(['merge-base', '--is-ancestor', ref, base]) ||
        (gitOk(['rev-parse', '--verify', '--quiet', `refs/heads/${local}`]) && gitOk(['merge-base', '--is-ancestor', ref, `refs/heads/${local}`]));
      return !merged;
    });
    if (pending.length) { console.log(`plan order: merge ${pending.map((d) => 'feature/' + d).join(', ')} first`); process.exit(3); }
    break;
  }
  case 'stream-id': {
    const branch = opt('--branch') || git(['rev-parse', '--abbrev-ref', 'HEAD']);
    const plan = existsSync(planPath) ? readJson(planPath) : null;
    const s = plan?.streams?.find((x) => `feature/${x.slug}` === branch);
    if (s) console.log(streamId(s));
    break;
  }
  default:
    console.error('usage: bbn-plan.mjs init|check|accept|apply|show|deps-merged|stream-id  (see header)'); process.exit(2);
}
