// Throwaway repos only. Fake secrets are assembled here, never stored as literal patterns.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync, readFileSync, appendFileSync, rmSync, cpSync, chmodSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const S = fileURLToPath(new URL('../scripts/', import.meta.url)), T = process.argv[2];
let failures = 0;
const run = (cwd, cmd, args = [], env = {}) => {
  const r = spawnSync(cmd, args, { cwd, encoding: 'utf8', env: { ...process.env, ...env } });
  return { code: r.status ?? 1, out: `${r.stdout || ''}${r.stderr || ''}` };
};
const git = (dir, ...args) => { const r = run(dir, 'git', args); assert.equal(r.code, 0, `git ${args[0]} failed`); return r.out.trim(); };
const plan = (dir, ...args) => run(dir, 'node', [join(S, 'bbn-plan.mjs'), ...args]);
const test = (name, fn) => { try { fn(); console.log(`ok   ${name}`); } catch (e) { failures++; console.log(`FAIL ${name}: ${e.message}`); } };
const repo = (name) => {
  const dir = join(T, name); mkdirSync(dir); git(dir, 'init', '-q');
  writeFileSync(join(dir, 'seed.txt'), 'base\n'); git(dir, 'add', 'seed.txt'); git(dir, 'commit', '-qm', 'init');
  return dir;
};
const commit = (dir) => { git(dir, 'add', '-A'); git(dir, 'commit', '-qm', 'fixture'); };
const stream = (paths) => ({ slug: 'owned', role: 'codex', paths, acceptance: ['true'] });
const draft = (paths) => ({ version: 1, title: 'PAY ## Feature', goal: 'g', status: 'draft', base: 'main', streams: [stream(paths)] });
const save = (dir, p) => { mkdirSync(join(dir, '.bbn'), { recursive: true }); writeFileSync(join(dir, '.bbn/plan.json'), JSON.stringify(p)); };
const load = (dir) => JSON.parse(readFileSync(join(dir, '.bbn/plan.json')));

const scanDir = repo('scan-unit'), scanWt = join(T, 'scan-unit-feature');
git(scanDir, 'worktree', 'add', '-q', '--no-track', '-b', 'feature/scan', scanWt, 'main');
test('scan unit: clean -> 0; bad arguments and missing base -> 2', () => {
  assert.equal(plan(scanWt, 'scan', '--base', 'main').code, 0);
  for (const args of [['--base'], ['--bogus'], ['--base', 'absent'], ['--base', 'main', '--bogus']]) assert.equal(plan(scanWt, 'scan', ...args).code, 2);
});
const samples = [
  ['aws-access-key', 'AK' + 'IA' + 'A'.repeat(16)],
  ['private-key', '-----BEGIN ' + 'RSA PRIVATE KEY-----'],
  ['github-token', 'gh' + 'p_' + 'a'.repeat(36)],
  ['github-token', 'github_' + 'pat_' + 'a'.repeat(60)],
  ['slack-token', 'xox' + 'b-' + 'a'.repeat(10)],
  ['stripe-live', 'sk_' + 'live_' + 'a'.repeat(16)],
  ['anthropic', 'sk-' + 'ant-' + 'a'.repeat(40)],
  ['openai-style', 'sk-' + 'proj-' + 'a'.repeat(32)],
  ['openai-style', 'sk-' + 'a'.repeat(32)],
  ['google-api', 'AI' + 'za' + 'a'.repeat(35)],
  ['assignment', 'API_KEY = ' + "'" + 'a'.repeat(16) + "'"],
];
writeFileSync(join(scanWt, 'secret file.txt'), 'safe\n' + samples.map(([, value]) => value).join('\n') + '\n');
writeFileSync(join(scanWt, 'allowed.txt'), samples.map(([, v]) => v + ' # bbn-' + 'allow-secret').join('\n'));
writeFileSync(join(scanWt, 'prefix.txt'), '++ ' + samples[0][1] + '\n');
for (const f of ['.env', '.env.production', '.env.example', '.env.sample', '.env.template']) writeFileSync(join(scanWt, f), 'SAFE=placeholder\n');
commit(scanWt);
test('scan unit: ordered patterns, line numbers, env files and redaction -> 3', () => {
  const r = plan(scanWt, 'scan', '--base', 'main');
  assert.equal(r.code, 3);
  for (const [i, [name, value]] of samples.entries()) {
    assert.ok(r.out.includes(`secret file.txt:${i + 2} ${name}\n`), `missing pattern ${name}`);
    assert.ok(!r.out.includes(value), 'scan leaked a value');
  }
  assert.ok(r.out.includes('prefix.txt:1 aws-access-key'), 'added +++ line must be scanned');
  assert.ok(r.out.includes('.env:1 env-file') && r.out.includes('.env.production:1 env-file'));
  assert.ok(!r.out.includes('allowed.txt') && !r.out.includes('.env.example') && !r.out.includes('.env.sample') && !r.out.includes('.env.template'));
  assert.equal(r.out.split('\n').filter((l) => l.startsWith('secret file.txt:8 ')).length, 1, 'anthropic has one hit');
});
git(scanWt, 'mv', 'seed.txt', '.env.renamed'); commit(scanWt);
test('scan unit: renamed env file is refused', () => {
  const r = plan(scanWt, 'scan', '--base', 'main'); assert.equal(r.code, 3); assert.ok(r.out.includes('.env.renamed:1 env-file'));
});

const historyDir = repo('scan-history-unit'), historyWt = join(T, 'scan-history-feature');
git(historyDir, 'worktree', 'add', '-q', '-b', 'feature/history', historyWt, 'main');
writeFileSync(join(historyWt, 'leak.txt'), samples[0][1] + '\n');
writeFileSync(join(historyWt, 'allowed.txt'), samples[0][1] + ' # bbn-' + 'allow-secret\n');
for (const f of ['.env.production', '.env.example', '.env.sample', '.env.template']) writeFileSync(join(historyWt, f), '');
commit(historyWt);
const leakedAt = git(historyWt, 'rev-parse', '--short=7', 'HEAD');
git(historyWt, 'rm', '-q', 'leak.txt', 'allowed.txt', '.env.production', '.env.example', '.env.sample', '.env.template'); commit(historyWt);
test('scan unit: deleted secret and empty env file remain refused in history', () => {
  const r = plan(historyWt, 'scan', '--base', 'main'); assert.equal(r.code, 3);
  assert.equal(r.out, `leak.txt:1 aws-access-key @${leakedAt}\n.env.production:1 env-file @${leakedAt}\n`);
  assert.ok(!r.out.includes(samples[0][1]), 'history scan leaked a value');
});
writeFileSync(join(historyWt, 'leak.txt'), samples[0][1] + '\n'); commit(historyWt);
test('scan unit: net diff suppresses history duplicates by file and pattern', () => {
  const r = plan(historyWt, 'scan', '--base', 'main'); assert.equal(r.code, 3);
  assert.equal(r.out.split('\n').filter((l) => l.startsWith('leak.txt:')).join('\n'), 'leak.txt:1 aws-access-key');
});
test('scan unit: a failed history git command exits 2', () => {
  const stub = join(T, 'bad-log'); mkdirSync(stub);
  const realGit = run(T, 'sh', ['-c', 'command -v git']).out.trim();
  writeFileSync(join(stub, 'git'), `#!/bin/sh\nfor arg in "$@"; do [ "$arg" = log ] && exit 1; done\nexec "${realGit}" "$@"\n`);
  chmodSync(join(stub, 'git'), 0o755);
  const r = run(historyDir, 'node', [join(S, 'bbn-plan.mjs'), 'scan', '--base', 'main'], { PATH: `${stub}:${process.env.PATH}` });
  assert.equal(r.code, 2); assert.ok(r.out.includes('cannot scan branch against base'));
});

const pdir = repo('plan-unit');
save(pdir, draft(['src/']));
test('plan unit: accept names integration and excludes it from the hash', () => {
  assert.equal(plan(pdir, 'accept').code, 0);
  const p = load(pdir); assert.equal(p.integration, `bbn/pay-feature-${p.planHash.slice(0, 6)}`);
  p.integration = 'bbn/custom'; save(pdir, p);
  assert.equal(plan(pdir, 'accept').code, 0); assert.equal(load(pdir).planHash, p.planHash); assert.equal(load(pdir).integration, 'bbn/custom');
});
test('plan unit: re-accept keeps integration; final merged branch gets a new name', () => {
  const p = load(pdir); p.goal = 'replan'; save(pdir, p); assert.equal(plan(pdir, 'accept').code, 0);
  assert.equal(load(pdir).integration, 'bbn/custom');
  const led = join(pdir, '.git/bbn/runs.jsonl');
  appendFileSync(led, JSON.stringify({ event: 'merge', result: 'merged', branch: 'bbn/custom' }) + '\n');
  p.goal = 'new run'; save(pdir, p); assert.equal(plan(pdir, 'accept').code, 0);
  assert.equal(load(pdir).integration, `bbn/pay-feature-${load(pdir).planHash.slice(0, 6)}`);
});
test('plan unit: apply defaults to integration, creates it without tracking', () => {
  assert.equal(plan(pdir, 'apply', '--apply').code, 0);
  const p = load(pdir);
  assert.equal(git(pdir, 'for-each-ref', '--format=%(upstream)', `refs/heads/${p.integration}`), '');
  const own = JSON.parse(readFileSync(join(T, 'plan-unit-owned/.bbn/ownership.json')));
  assert.equal(own.base, p.integration);
});
writeFileSync(join(pdir, '.gitignore'), 'cache/\nforced/\n'); commit(pdir);
test('plan unit: ignored path is an error in check, accept and apply', () => {
  save(pdir, draft(['cache/']));
  for (const cmd of ['check', 'accept', 'apply']) {
    const r = plan(pdir, cmd); assert.equal(r.code, 1); assert.ok(r.out.includes('cache/ is gitignored; worktrees will not carry it'));
  }
});
mkdirSync(join(pdir, 'forced')); writeFileSync(join(pdir, 'forced/keep.txt'), 'tracked\n'); git(pdir, 'add', '-f', 'forced/keep.txt'); git(pdir, 'commit', '-qm', 'forced file');
test('plan unit: ignored tree with tracked files warns and passes', () => {
  save(pdir, draft(['forced/'])); const r = plan(pdir, 'check'); assert.equal(r.code, 0); assert.ok(r.out.includes('warn: owned: forced/ is gitignored but has tracked files'));
});
mkdirSync(join(pdir, 'src')); writeFileSync(join(pdir, 'src/pending.txt'), 'unfinished\n');
test('plan unit: untracked main files are errors even from a stream worktree', () => {
  save(pdir, draft(['src/']));
  for (const dir of [pdir, join(T, 'plan-unit-owned')]) {
    const r = plan(dir, 'check'); assert.equal(r.code, 1); assert.ok(r.out.includes('src/ has untracked files in the main checkout'));
  }
  rmSync(join(pdir, 'src/pending.txt'));
  const wt = join(T, 'plan-unit-owned'); mkdirSync(join(wt, 'src')); writeFileSync(join(wt, 'src/pending.txt'), 'agent work\n');
  assert.equal(plan(wt, 'check').code, 0, 'stream untracked files are not main files');
});

const mdir = repo('merge-unit'), mwt = join(T, 'merge-unit-feature');
git(mdir, 'worktree', 'add', '-q', '-b', 'feature/merge', mwt, 'main');
writeFileSync(join(mwt, 'feature.txt'), 'feature\n'); commit(mwt);
assert.equal(run(mwt, join(S, 'bbn-review-record.sh'), ['APPROVE', '--base', 'main']).code, 0);
writeFileSync(join(mdir, 'target.txt'), 'target moved\n'); commit(mdir);
test('merge unit: --no-rebase exits 4, records base-moved and preserves HEAD', () => {
  const h = git(mwt, 'rev-parse', 'HEAD');
  const r = run(mwt, join(S, 'bbn-merge.sh'), ['--apply', '--base', 'main', '--no-rebase'], { BBN_GATE_CMD: 'true' });
  assert.equal(r.code, 4); assert.ok(r.out.includes('base moved: merge main into this branch (no rebase), then review again'));
  assert.equal(git(mwt, 'rev-parse', 'HEAD'), h);
  assert.ok(readFileSync(join(mdir, '.git/bbn/runs.jsonl'), 'utf8').includes('"stage":"base-moved"'));
});
const cp = join(T, 'scan-failure-plugin'); cpSync(join(S, '..'), cp, { recursive: true });
writeFileSync(join(cp, 'scripts/bbn-plan.mjs'), 'process.exit(2);\n');
test('merge unit: scan exit 2 fails closed in apply and dry-run', () => {
  for (const args of [['--base', 'main'], ['--apply', '--base', 'main']]) {
    const r = run(mwt, join(cp, 'scripts/bbn-merge.sh'), args, { BBN_GATE_CMD: 'true' });
    assert.equal(r.code, 3); assert.ok(r.out.includes('secret-scan refused (exit 2)'));
  }
  assert.ok(readFileSync(join(mdir, '.git/bbn/runs.jsonl'), 'utf8').includes('"reason":"secret-scan"'));
});

test('run unit: moving integration head changes check and gate progress keys', () => {
  const dir = repo('progress-unit'), p = draft(['watched/']);
  p.streams = ['watched', 'mover'].map((slug) => ({ ...stream([`${slug}/`]), slug }));
  save(dir, p); assert.equal(plan(dir, 'accept').code, 0); assert.equal(plan(dir, 'apply', '--apply').code, 0);
  const watched = join(T, 'progress-unit-watched'), mover = join(T, 'progress-unit-mover');
  for (const [wt, slug] of [[watched, 'watched'], [mover, 'mover']]) {
    mkdirSync(join(wt, slug)); writeFileSync(join(wt, slug, 'done.txt'), 'done\n'); commit(wt);
  }
  const tick = () => {
    const r = run(dir, 'node', [join(S, 'bbn-run.mjs'), '--apply', '--json']);
    assert.equal(r.code, 0); return JSON.parse(r.out.split('\n[bbn-run]')[0]);
  };
  tick();
  const base = load(dir).integration, before = git(dir, 'rev-parse', base);
  assert.equal(run(mover, join(S, 'bbn-review-record.sh'), ['APPROVE', '--base', base]).code, 0);
  const sd = join(git(watched, 'rev-parse', '--absolute-git-dir'), 'bbn');
  rmSync(join(sd, 'accept.json')); rmSync(join(sd, 'gate.json'));
  const r = tick();
  assert.notEqual(git(dir, 'rev-parse', base), before);
  for (const step of ['check', 'gate']) assert.equal(r.ran.filter((a) => a.stream === 'watched' && a.do === step).length, 2, `${step} must re-run after the integration merge`);
  assert.equal(r.actions[0].do, 'review', 'stale acceptance must not stop as no progress');
});
process.exitCode = failures ? 1 : 0;
