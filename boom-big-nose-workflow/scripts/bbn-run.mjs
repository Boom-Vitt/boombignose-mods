#!/usr/bin/env node
// BBN harness: reads the plan, worktrees, state files and ledger, and says what happens next.
//   bbn-run.mjs [--apply] [--json]   one tick. --apply runs every mechanical step (create worktree, acceptance
//                                    checks, gate, merge into the local base, cleanup, final verify) until only
//                                    agent work is left. Without --apply nothing changes (steps show as auto).
//   bbn-run.mjs verify [--json]      run every acceptance check + the gate on the base now
// Agent actions: plan, fix-plan, approve-plan, build, fix, review, resolve, ask-merge, replan; also wait, stop, done.
// Never pushes. Merges go into the local base only, one branch per step, in plan order.
// Exit: 0 ok, 1 verify failed or error, 2 usage
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { writeFileSync, mkdirSync, mkdtempSync, rmSync, chmodSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { PLUGIN_ROOT, git, gitOk, readJson, loadConfig, pickBase, worktrees, ledger, commonDir, exists, checkPlan, hashStreams, streamId } from './lib/bbn-node.mjs';

const args = process.argv.slice(2);
if (args.some((a) => !['verify', '--apply', '--json'].includes(a)) || args.indexOf('verify') > 0) {
  console.error('usage: bbn-run.mjs [--apply] [--json] | bbn-run.mjs verify [--json]'); process.exit(2);
}
const VERIFY = args[0] === 'verify', APPLY = args.includes('--apply'), JSON_OUT = args.includes('--json');
const S = join(PLUGIN_ROOT, 'scripts');
const cfg = loadConfig();
const auto = { planApproval: 'reviewer', merge: 'local', ...cfg.automation };
const STEP_MS = (cfg.reviewGate?.stepTimeoutSec ?? 1800) * 1000;
const MAX_STRIKES = cfg.budgets?.hardStopOnRepeatedFailures ?? 3;
const MAX_AGENTS = cfg.budgets?.maxParallelAgents ?? 4;
const AGENT_WORK = new Set(['build', 'fix', 'review', 'resolve']);
const progress = (m) => console.error(`[bbn-run] ${m}`);
const tail = (s, n = 15) => s.trimEnd().split('\n').slice(-n).join('\n');
const now = () => new Date().toISOString().replace(/\.\d+Z$/, 'Z');
const short = (x) => createHash('sha256').update(JSON.stringify(x)).digest('hex').slice(0, 12);
const checksId = (s) => short(s.acceptance);
const GATE_MARK = '# Written by bbn-run.mjs';
const q = (x) => `'${String(x).replace(/'/g, `'\\''`)}'`;   // shell-quote for commands shown to the user
// What the gate on the main checkout runs besides tracked files: BBN_GATE_CMD and the untracked .bbn/gate.sh.
const gateId = (dir) => { const f = join(dir, '.bbn', 'gate.sh'); return short([process.env.BBN_GATE_CMD || '', exists(f) ? [statSync(f).mode & 0o111, readFileSync(f, 'utf8')] : '']); };
let base = '';

function run(cmd, argv, { cwd, timeout } = {}) {
  const r = spawnSync(cmd, argv, { cwd, timeout, encoding: 'utf8', maxBuffer: 64 << 20, killSignal: 'SIGKILL',
    env: { ...process.env, BBN_BASE: base, GIT_TERMINAL_PROMPT: '0', CI: process.env.CI || '1' }, stdio: ['ignore', 'pipe', 'pipe'] });
  return { code: r.error?.code === 'ETIMEDOUT' ? 124 : (r.status ?? 1), out: `${r.stdout || ''}${r.stderr || ''}` };
}
const head = (wt) => git(['-C', wt, 'rev-parse', 'HEAD']);
const refOk = (ref) => gitOk(['rev-parse', '--verify', '--quiet', ref]);
const events = () => {
  const f = join(commonDir(), 'runs.jsonl');
  if (!exists(f)) return [];
  return readFileSync(f, 'utf8').split('\n').flatMap((l) => { try { return l ? [JSON.parse(l)] : []; } catch { return []; } });
};

// Base: the plan's or BBN_BASE, else the first candidate. Prefer the local branch once it is ahead of
// origin, because merges land there and later streams must start from them.
function resolveBase(plan) {
  const r = pickBase(plan?.base || process.env.BBN_BASE || undefined);
  if (!r.startsWith('origin/')) return r;
  const l = r.slice(7);
  return refOk(`refs/heads/${l}`) && gitOk(['merge-base', '--is-ancestor', r, `refs/heads/${l}`]) ? l : r;
}

// Merged = bbn-merge.sh recorded a merge for the branch after its worktree was created, for this stream
// (not an older plan's that reused the slug), and the merged head is in this base.
function isMerged(s, ev) {
  const br = `feature/${s.slug}`;
  let created = -1;
  ev.forEach((e, i) => { if (e.event === 'worktree.create' && e.feature === s.slug) created = i; });
  const m = ev.filter((e, i) => i > created && e.event === 'merge' && e.result === 'merged' && e.branch === br).at(-1);
  return !!m?.head && m.stream === streamId(s) && gitOk(['merge-base', '--is-ancestor', m.head, base]);
}

// Failed acceptance/gate runs and REQUEST_CHANGES since the stream's last APPROVE (or its new worktree).
function strikes(slug, ev) {
  let n = 0;
  for (const e of ev) {
    if (e.event === 'worktree.create' && e.feature === slug) n = 0;
    if (e.branch !== `feature/${slug}`) continue;
    if (e.event === 'review') n = e.verdict === 'APPROVE' ? 0 : e.verdict === 'REQUEST_CHANGES' ? n + 1 : n;
    else if ((e.event === 'accept' || e.event === 'gate') && e.result === 'fail') n++;
  }
  return n;
}

function patchId(wt) {
  const mb = git(['-C', wt, 'merge-base', base, 'HEAD']);
  const r = run('bash', ['-c', 'git diff "$1" HEAD | git patch-id --verbatim', '_', mb], { cwd: wt });
  const id = r.out.split(' ')[0].trim();
  if (r.out.trim() && !/^[0-9a-f]{40,64}$/.test(id)) throw new Error(`git patch-id --verbatim failed (needs git 2.39+): ${tail(r.out, 2)}`);
  return id;
}

function runAccept(s, wt, sd, h) {
  const failed = [];
  for (const cmd of s.acceptance) {
    const r = run('bash', ['-c', cmd], { cwd: wt, timeout: STEP_MS });
    if (r.code) failed.push({ cmd, code: r.code, tail: tail(r.out) });
  }
  const result = failed.length ? 'fail' : 'pass';
  mkdirSync(sd, { recursive: true });
  writeFileSync(join(sd, 'accept.json'), JSON.stringify({ head: h, checks: checksId(s), result, failed, at: now() }, null, 2) + '\n');
  rmSync(join(sd, 'gate.json'), { force: true });   // the gate runs again after any new acceptance run
  ledger('accept', { branch: `feature/${s.slug}`, result, head: h.slice(0, 12), failed: failed.length });
  return result;
}

// No lint/typecheck/test found: gate on the plan's acceptance checks, each in its own shell like runAccept.
function writeGate(f, s) {
  writeFileSync(f, `#!/usr/bin/env bash\n${GATE_MARK}: no lint/typecheck/test was found, so the gate runs the plan's acceptance checks.\nset -e\n${s.acceptance.map((c) => `(\nset +e\n${c}\n)`).join('\n')}\n`);
  chmodSync(f, 0o755);
}

function runGate(s, wt, sd) {
  const own = join(wt, '.bbn', 'gate.sh');
  if (exists(own) && readFileSync(own, 'utf8').includes(GATE_MARK)) writeGate(own, s);   // keep ours in step with the plan
  let r = run(join(S, 'bbn-gate.sh'), [], { cwd: wt });
  if (r.code === 2 && !exists(own)) { writeGate(own, s); r = run(join(S, 'bbn-gate.sh'), [], { cwd: wt }); }
  writeFileSync(join(sd, 'gate.log'), r.out);
  return ['pass', 'fail', 'empty'][r.code] ?? 'fail';
}

function verify(plan) {
  const mainWt = worktrees()[0].path, baseHead = git(['rev-parse', base]);
  const inMain = head(mainWt) === baseHead && !git(['-C', mainWt, 'status', '--porcelain', '--untracked-files=no']);
  let dir = mainWt;
  if (!inMain) {
    dir = mkdtempSync(join(tmpdir(), 'bbn-verify-')); git(['worktree', 'add', '--quiet', '--detach', dir, baseHead]);
    const own = join(mainWt, '.bbn', 'gate.sh');   // the project's custom gate is untracked: bring it along
    if (exists(own)) { mkdirSync(join(dir, '.bbn'), { recursive: true }); writeFileSync(join(dir, '.bbn', 'gate.sh'), readFileSync(own)); chmodSync(join(dir, '.bbn', 'gate.sh'), statSync(own).mode & 0o777); }
  }
  const failed = [];
  try {
    for (const s of plan.streams) for (const cmd of s.acceptance) {
      const r = run('bash', ['-c', cmd], { cwd: dir, timeout: STEP_MS });
      if (r.code) failed.push({ stream: s.slug, cmd, code: r.code, tail: tail(r.out) });
    }
    const g = run(join(S, 'bbn-gate.sh'), ['--no-record'], { cwd: dir });
    if (g.code && g.code !== 2) failed.push({ cmd: 'bbn-gate.sh', code: g.code, tail: tail(g.out) });   // 2 = no checks
  } finally {
    if (!inMain) { git(['worktree', 'remove', '--force', dir], { allowFail: true }); rmSync(dir, { recursive: true, force: true }); }
  }
  const result = failed.length ? 'fail' : 'pass';
  writeFileSync(join(commonDir(), 'verify.json'), JSON.stringify({ head: baseHead, plan: plan.planHash, gate: gateId(mainWt), base, result, failed, at: now() }, null, 2) + '\n');
  ledger('verify', { result, head: baseHead, base, failed: failed.length });
  return { result, failed };
}

// One pass over the state. Returns the actions; an action with fn is a mechanical step --apply may run.
function evaluate(attempted) {
  const mainWt = worktrees()[0].path, planPath = join(mainWt, '.bbn', 'plan.json');
  if (!exists(planPath)) return [{ do: 'plan', file: planPath, why: 'no plan yet: write .bbn/plan.json (streams, paths, dependsOn, acceptance)' }];
  const plan = readJson(planPath);
  if (!plan) return [{ do: 'fix-plan', file: planPath, errors: ['not valid JSON'] }];
  const chk = checkPlan(plan, cfg);
  if (chk.errors.length) return [{ do: 'fix-plan', file: planPath, errors: chk.errors }];
  if (plan.status !== 'accepted' || plan.planHash !== hashStreams(plan)) {
    return [{ do: 'approve-plan', by: auto.planApproval, file: planPath, warnings: chk.warnings,
      why: plan.status === 'accepted' ? 'plan changed since it was accepted' : 'draft plan needs the checkpoint' }];
  }
  base = resolveBase(plan);
  const ev = events(), out = [];
  const step = (o, key, fn) => {
    if (attempted.has(key)) return out.push({ ...o, do: 'stop', why: `${o.do} made no progress: ${attempted.get(key)}` });
    out.push({ ...o, auto: true, key, fn });
  };
  const wts = new Map(worktrees().map((w) => [w.branch, w.path]));
  const bySlug = new Map(plan.streams.map((s) => [s.slug, s]));
  const merged = new Set(chk.order.filter((slug) => isMerged(bySlug.get(slug), ev)));
  let mergeQueued = false;

  for (const slug of chk.order) {
    if (merged.has(slug)) continue;
    const s = bySlug.get(slug), br = `feature/${slug}`, wt = wts.get(br);
    const a = { stream: slug, role: s.role, base, ...(wt && { worktree: wt }) };
    if (!wt) {
      const pending = (s.dependsOn || []).filter((d) => !merged.has(d));
      if (pending.length) out.push({ ...a, do: 'wait', why: `starts after ${pending.join(', ')} merge` });
      else if (refOk(`refs/heads/${br}`)) out.push({ ...a, do: 'stop', why: `${br} exists without a worktree: re-attach it (git worktree add) or rename the stream` });
      else step({ ...a, do: 'create' }, `create:${slug}`, () => run('node', [join(S, 'bbn-plan.mjs'), 'apply', '--apply', '--only', slug, '--base', base], { cwd: mainWt }));
      continue;
    }
    const gd = git(['-C', wt, 'rev-parse', '--absolute-git-dir']), sd = join(gd, 'bbn'), h = head(wt);
    const work = { summary: s.summary || '', paths: s.paths, acceptance: s.acceptance };
    const busy = ['rebase-merge', 'rebase-apply'].some((f) => exists(join(gd, f))) ? 'rebase' : exists(join(gd, 'MERGE_HEAD')) ? 'merge' : '';
    if (busy) { out.push({ ...a, do: 'resolve', role: 'codex', why: `${busy} in progress: resolve the conflicts, git add, git ${busy} --continue (onto ${base})` }); continue; }
    if (git(['-C', wt, 'status', '--porcelain'])) { out.push({ ...a, do: 'build', ...work, why: 'uncommitted changes: finish the work and commit it' }); continue; }
    if (git(['-C', wt, 'rev-list', '--count', `${base}..HEAD`]) === '0') { out.push({ ...a, do: 'build', ...work, why: 'no commits yet' }); continue; }
    const n = strikes(slug, ev);
    const fix = (o) => out.push(n >= MAX_STRIKES
      ? { ...a, ...o, do: 'stop', why: `${o.why}, and ${n} failed checks or reviews since the last approval (hardStopOnRepeatedFailures): needs the user` }
      : { ...a, ...work, ...o, do: 'fix' });

    const acc = readJson(join(sd, 'accept.json'), {});
    if (acc.head !== h || acc.checks !== checksId(s)) { step({ ...a, do: 'check' }, `check:${slug}:${h}:${checksId(s)}`, () => ({ out: runAccept(s, wt, sd, h) })); continue; }
    if (acc.result !== 'pass') { fix({ failed: acc.failed, why: 'acceptance checks failed' }); continue; }
    const gate = readJson(join(sd, 'gate.json'), {});
    if (gate.head !== h) { step({ ...a, do: 'gate' }, `gate:${slug}:${h}`, () => ({ out: runGate(s, wt, sd) })); continue; }
    if (gate.result === 'fail') { fix({ log: join(sd, 'gate.log'), why: `gate failed (${gate.steps})` }); continue; }
    if (gate.result !== 'pass') { out.push({ ...a, do: 'stop', why: 'gate found no checks: add .bbn/gate.sh or set BBN_GATE_CMD' }); continue; }

    const rv = readJson(join(sd, 'review.json'), {});
    if (!rv.verdict || rv.patch_id !== patchId(wt)) { out.push({ ...a, do: 'review', role: 'bbn-reviewer', why: rv.verdict ? 'new changes since the last review' : 'gate passed; needs an independent review' }); continue; }
    if (rv.verdict === 'REQUEST_CHANGES') { fix({ note: rv.note, why: 'review asked for changes' }); continue; }
    if (rv.verdict !== 'APPROVE') { out.push({ ...a, do: 'stop', note: rv.note, why: 'review BLOCKed this stream: needs the user' }); continue; }

    const deps = (s.dependsOn || []).filter((d) => !merged.has(d));
    if (deps.length) { out.push({ ...a, do: 'wait', why: `approved; merges after ${deps.join(', ')}` }); continue; }
    const last = ev.filter((e) => e.event === 'run.merge' && e.branch === br).at(-1);
    if (last?.head === h && last.code === 4) { out.push({ ...a, do: 'resolve', role: 'codex', why: `merge into ${base} failed (exit 4): ${last.reason}. Rebase on ${base}, resolve, commit` }); continue; }
    if (last?.head === h && last.code !== 0 && last.code !== 5) { out.push({ ...a, do: 'stop', why: `bbn-merge.sh exit ${last.code}: ${last.reason}` }); continue; }
    if (mergeQueued) { out.push({ ...a, do: 'wait', why: 'approved; merges one branch at a time, in plan order' }); continue; }
    mergeQueued = true;
    if (auto.merge === 'ask') { out.push({ ...a, do: 'ask-merge', cmd: `${q(join(S, 'bbn-merge.sh'))} --apply --base ${q(base)}`, why: 'approved: ask the user, then run cmd in the worktree' }); continue; }
    step({ ...a, do: 'merge' }, `merge:${slug}:${h}`, () => {
      const r = run(join(S, 'bbn-merge.sh'), ['--apply', '--base', base], { cwd: wt });
      ledger('run.merge', { branch: br, code: r.code, head: head(wt), reason: r.code ? tail(r.out, 3).replace(/\s*\n\s*/g, ' ') : '' });
      return { out: `exit ${r.code}` };
    });
  }
  if (out.length) return capAgents(out);

  // Every stream is merged: clean up this plan's worktrees (no others), then verify the base as a whole.
  const mine = plan.streams.map((s) => `feature/${s.slug}`).filter((b) => wts.has(b));
  if (mine.length && !attempted.has('cleanup')) {
    return [{ do: 'cleanup', base, auto: true, key: 'cleanup', fn: () => run(join(S, 'bbn-cleanup.sh'), ['--apply', '--base', base, ...mine.flatMap((b) => ['--branch', b])], { cwd: mainWt }) }];
  }
  const v = readJson(join(commonDir(), 'verify.json'), {});
  if (v.head !== git(['rev-parse', base]) || v.plan !== plan.planHash || v.gate !== gateId(mainWt)) {
    const o = { do: 'verify', base };
    return [attempted.has('verify') ? { ...o, do: 'stop', why: 'verify did not record a result' } : { ...o, auto: true, key: 'verify', fn: () => ({ out: verify(plan).result }) }];
  }
  if (v.result !== 'pass') return [{ do: 'replan', base, failed: v.failed, file: planPath, why: 'all streams merged but the base fails its checks: add a fix stream to the plan' }];
  return [{ do: 'done', base, why: `all ${plan.streams.length} stream(s) merged into local ${base} and verified; pushing is the user's call` }];
}

function capAgents(out) {
  let n = 0;
  return out.map((x) => (AGENT_WORK.has(x.do) && ++n > MAX_AGENTS ? { ...x, do: 'wait', why: `maxParallelAgents (${MAX_AGENTS}) reached` } : x));
}

function main() {
  if (!gitOk(['rev-parse', '--is-inside-work-tree'])) throw Object.assign(new Error('not inside a git repo'), { exitCode: 2 });
  if (VERIFY) {
    const plan = readJson(join(worktrees()[0].path, '.bbn', 'plan.json'));
    if (!plan?.streams) throw Object.assign(new Error('no valid .bbn/plan.json'), { exitCode: 2 });
    base = resolveBase(plan);
    const r = verify(plan);
    if (JSON_OUT) console.log(JSON.stringify({ base, ...r }));
    else { console.log(`[bbn-run] verify ${r.result} on ${base}`); for (const f of r.failed) console.log(`  - ${f.cmd} (exit ${f.code})`); }
    return r.result === 'pass' ? 0 : 1;
  }
  const attempted = new Map(), ran = [];
  let actions = evaluate(attempted);
  for (let i = 0; APPLY && i < 100; i++) {
    const next = actions.find((x) => x.fn);
    if (!next) break;
    progress(`${next.do}${next.stream ? ' ' + next.stream : ''} ...`);
    const r = next.fn();
    const result = r?.code !== undefined ? (r.code ? `exit ${r.code}` : 'ok') : r?.out;
    if (r?.code) progress(tail(r.out, 5));
    attempted.set(next.key, r?.code ? tail(r.out, 3) : `${result}`);
    ran.push({ do: next.do, ...(next.stream && { stream: next.stream }), result });
    progress(`${next.do}${next.stream ? ' ' + next.stream : ''}: ${result}`);
    actions = evaluate(attempted);
  }
  actions = actions.map(({ fn, key, ...x }) => x);
  const done = actions.length === 1 && actions[0].do === 'done';
  if (JSON_OUT) console.log(JSON.stringify({ base, actions, ran, done }, null, 2));
  else for (const x of actions) console.log(`- ${x.do}${x.auto ? ' (auto)' : ''}${x.stream ? ' ' + x.stream : ''}${x.role ? ' [' + x.role + ']' : ''}${x.why ? ': ' + x.why : ''}`);
  return 0;
}

try { process.exitCode = main(); } catch (e) {
  if (JSON_OUT) console.log(JSON.stringify({ error: e.message }));
  else console.error(`[bbn-run] ${e.message}`);
  process.exitCode = e.exitCode ?? 1;
}
