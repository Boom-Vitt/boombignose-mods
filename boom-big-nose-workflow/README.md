# boom-big-nose-workflow (Orca) v0.4.0

[ไทย](#ไทย) · [English](#english)

---

<a id="ไทย"></a>
## ไทย

มอด Orca สำหรับ Claude Code และ Codex: แยกบทบาท agent (วางแผน / เขียนโค้ด / รวมหลายไฟล์ / รีวิว), แยก worktree ต่อฟีเจอร์ พร้อม port/env/DB ของตัวเอง, บังคับให้ผ่าน lint+typecheck+test + รีวิวก่อน merge และเดินงานตามเฟส SDLC ที่มีเกณฑ์ผ่านทุกเฟส Context7 MCP และ Perplexity MCP ต่ออัตโนมัติ (ทั้งคู่ไม่บังคับ มี fallback)

> ชื่อ Grok Build / Claude Code / Codex ในมอดนี้คือ **บทบาท agent** ไม่ใช่การล็อกอินเข้าแอปภายนอก

### ติดตั้ง

```bash
claude plugin marketplace add Boom-Vitt/boombignose-mods
claude plugin install boom-big-nose-workflow@boombignose-mods
```

รีสตาร์ท Claude Code แล้วรัน `/orca-setup` หรือ `/orca-doctor` เริ่มใช้งานทีละขั้น: [docs/QUICKSTART.md](docs/QUICKSTART.md)

### ติดตั้งใน Codex

```bash
codex plugin marketplace add Boom-Vitt/boombignose-mods
codex plugin add boom-big-nose-workflow@boombignose-mods
```

Codex ไม่มี slash command ของปลั๊กอิน ให้สั่งเป็นประโยค เช่น "วางแผนงานนี้ด้วย Orca" skill `orca-workflow` จะเปิด `commands/orca-<ขั้น>.md` แล้วรันสคริปต์ชุดเดียวกัน Codex เล่นแต่ละบทบาทเอง (หรือใช้ subagent ถ้าเปิดไว้) แต่ reviewer ต้องรันแยกจากบริบทที่เขียนโค้ด เช่น `codex exec -s read-only` ใน worktree นั้น `maxTurns` บังคับได้เฉพาะใน Claude Code การสร้าง worktree และ merge เขียนนอก workspace จึงอาจต้องกดอนุมัติ ส่วน Perplexity ให้ sign in ด้วย `codex mcp login perplexity`

### คำสั่ง

| คำสั่ง | หน้าที่ |
|---|---|
| `/orca-setup` | ตั้งค่าครั้งแรก (Perplexity sign-in, CI template) |
| `/orca-doctor` | ตรวจสุขภาพ: git, gh, claude, node, MCP, คีย์ (มี/ไม่มี), config, แผน, ledger พร้อมวิธีแก้ (`fix:`) |
| `/orca-plan` | checkpoint: เขียน/ตรวจ/accept `.orca/plan.json` (stream, เจ้าของไฟล์, dependency, acceptance) แล้วสร้าง worktree ตามลำดับ |
| `/orca-worktree <slug>` | สร้าง worktree พร้อม isolation |
| `/orca-status` | สถานะทุกสาขา: ahead/behind, gate/review, ไฟล์ที่ชนกัน |
| `/orca-queue` | ลำดับ merge: dependency ในแผน, พร้อมหรือยัง, ทำนายการชนด้วย `git merge-tree`, ขนาด (อ่านอย่างเดียว) |
| `/orca-review` | รัน gate + reviewer บันทึกคำตัดสิน |
| `/orca-merge` | dry-run เป็นค่าเริ่มต้น; `--apply` รวมเข้า base ท้องถิ่น (ปฏิเสธถ้า dependency ในแผนยังไม่ merge); `--apply --pr` เปิด draft PR |
| `/orca-cleanup` | ลบ worktree ที่ merge แล้ว (dry-run เป็นค่าเริ่มต้น) |
| `/orca-report` | สรุปจาก ledger: gate/review/merge และ turn ที่แต่ละ agent ใช้เทียบงบ `maxTurns` |

### Ledger

ทุกสคริปต์บันทึกเหตุการณ์ลง `<git common dir>/orca/runs.jsonl` (ในเครื่อง ไม่เข้า git ไม่ส่งออกไปไหน) Orca บันทึก turn ของแต่ละ agent ด้วย `scripts/orca-ledger.sh agent <role> --turns N` ปิดได้ด้วย `ORCA_LEDGER=0`

### Perplexity (ไม่บังคับ)

มอดต่อ `https://api.perplexity.ai/mcp` แบบ sign-in (OAuth) ตาม[เอกสารของ Perplexity](https://docs.perplexity.ai/docs/getting-started/integrations/mcp-server) (ตรวจสอบ 2026-10-08):

1. ใน Claude Code รัน `/mcp`
2. เลือก `plugin:boom-big-nose-workflow:perplexity` แล้ว sign in
3. ต้องเป็น admin ของ Perplexity API organization ที่มีการเรียกเก็บเงิน

ถ้ายังไม่ sign in agent จะใช้ `WebSearch` / `WebFetch` อัตโนมัติ และบอกในผลลัพธ์ ไม่มีอะไรพัง

#### ใช้ API key แทน (ทางเลือก)

ใส่ใน `~/.zshrc` (หรือ shell profile ที่ใช้เปิด Claude Code) แล้วเปิดเทอร์มินัลใหม่ / รีสตาร์ท Claude Code จากเทอร์มินัลนั้น:

```bash
export PERPLEXITY_API_KEY="pplx-..."   # อย่าใส่ค่าจริงในแชทหรือใน git
```

จากนั้นในเทอร์มินัลใหม่ เพิ่มเซิร์ฟเวอร์แบบมีคีย์แยกจากปลั๊กอิน (อย่าแก้ `.mcp.json` ของปลั๊กอินให้ฝังคีย์):

```bash
claude mcp add --scope user --transport http perplexity-key https://api.perplexity.ai/mcp \
  --header "Authorization: Bearer ${PERPLEXITY_API_KEY}"
```

shell จะแทนค่าคีย์ตอนรันคำสั่ง และ Claude Code เก็บไว้ใน `~/.claude.json` (ไฟล์ส่วนตัวในเครื่อง) ตรวจด้วย `claude mcp list` ว่า `perplexity-key` เป็น Connected ส่วน `plugin:boom-big-nose-workflow:perplexity` จะยังขึ้น "Needs authentication" ได้ ไม่เป็นไร ห้ามพิมพ์หรือขอคีย์ในแชท

### Context7 (ไม่บังคับ)

ไม่ต้องตั้งอะไร Anonymous ได้ ถ้าต้องการโควตาสูงกว่า: `export CONTEXT7_API_KEY="..."` ใน shell profile เดียวกัน

### งบและ config

ดู `orca.config.json` (ตรวจด้วย `scripts/orca-config-check.mjs` ตาม `orca.config.schema.json`) `maxTurns` ของแต่ละ agent บังคับโดย Claude Code แต่ละขั้นของ gate จำกัดเวลา `reviewGate.stepTimeoutSec` (ค่าเริ่มต้น 1800 วินาที, override ด้วย `ORCA_GATE_TIMEOUT`) แผนตรวจตาม `orca.plan.schema.json` ความหมาย exit code: [docs/exit-codes.md](docs/exit-codes.md)

### CI สำหรับโปรเจกต์ของคุณ

คัดลอก `scripts/orca-gate.sh` + `scripts/lib/` ไปที่ `<repo>/.github/scripts/` และ `templates/github/orca-gate.yml` ไปที่ `<repo>/.github/workflows/`

### เอกสาร

- `docs/QUICKSTART.md` / `docs/QUICKSTART.en.md` — เริ่มใช้งานทีละขั้น
- `docs/workflow-diagram.md` — แผนภาพขั้นตอนทั้งหมด ตั้งแต่วางแผนจนถึง cleanup และหลักการ SDLC (เกณฑ์ผ่านของแต่ละเฟส)
- `docs/orca-architecture.md` — โครงสร้าง + mermaid + ประวัติจุดอ่อน→แก้
- `docs/exit-codes.md` — exit code ของทุกสคริปต์
- `docs/decisions/` — ADR
- `CHANGELOG.md`

### ทดสอบสคริปต์

```bash
bash tests/run.sh     # unit: แต่ละสคริปต์
bash tests/smoke.sh   # e2e: แผน -> worktree -> gate -> review -> queue -> merge -> report -> cleanup
```

สร้าง git repo ชั่วคราวใน temp แล้วลบเอง ไม่แตะโปรเจกต์อื่น ไม่ใช้เครือข่าย ถ้ามี `shellcheck` จะตรวจด้วย

---

<a id="english"></a>
## English

Orca for Claude Code and Codex: role agents (plan / implement / integrate / review), one git worktree per feature with its own port/env/DB, a lint+typecheck+test + reviewer gate before anything reaches the base branch, and SDLC phases that each end with an exit criterion. Context7 and Perplexity MCP connect automatically (both optional, with fallbacks).

> "Grok Build", "Claude Code" and "Codex" in this mod are **agent roles**, not logins to those external products.

### Install

```bash
claude plugin marketplace add Boom-Vitt/boombignose-mods
claude plugin install boom-big-nose-workflow@boombignose-mods
```

Restart Claude Code, then run `/orca-setup` or `/orca-doctor`. Step by step: [docs/QUICKSTART.en.md](docs/QUICKSTART.en.md)

### Install in Codex

```bash
codex plugin marketplace add Boom-Vitt/boombignose-mods
codex plugin add boom-big-nose-workflow@boombignose-mods
```

Codex has no plugin slash commands: ask in plain words, e.g. "plan this with Orca". The `orca-workflow` skill opens `commands/orca-<step>.md` and runs the same scripts. Codex plays each role itself (or in subagents when enabled), but the reviewer runs apart from the context that wrote the code, e.g. `codex exec -s read-only` in that worktree. `maxTurns` is enforced only in Claude Code. Creating worktrees and merging write outside the workspace, so Codex may ask for approval. Sign in to Perplexity with `codex mcp login perplexity`.

### Commands

| Command | What it does |
|---|---|
| `/orca-setup` | First-time setup (Perplexity sign-in, CI template) |
| `/orca-doctor` | Health check: git, gh, claude, node, MCP, key presence, config, plan, ledger, with `fix:` hints |
| `/orca-plan` | Checkpoint: write/check/accept `.orca/plan.json` (streams, file ownership, dependencies, acceptance), then create worktrees in order |
| `/orca-worktree <slug>` | Create an isolated worktree |
| `/orca-status` | Every branch: ahead/behind, gate/review, overlapping files |
| `/orca-queue` | Merge order: plan dependencies, readiness, conflicts predicted with `git merge-tree`, size (read-only) |
| `/orca-review` | Run the gate + reviewer and record the verdict |
| `/orca-merge` | Dry-run by default; `--apply` merges into the local base (refuses while a plan dependency is unmerged); `--apply --pr` opens a draft PR |
| `/orca-cleanup` | Remove merged worktrees (dry-run by default) |
| `/orca-report` | Ledger summary: gates/reviews/merges and turns each agent used vs its `maxTurns` budget |

### Ledger

Every script appends events to `<git common dir>/orca/runs.jsonl` (local only, never committed or uploaded). Orca records each agent's turns with `scripts/orca-ledger.sh agent <role> --turns N`. Turn it off with `ORCA_LEDGER=0`.

### Perplexity (optional)

The mod connects to `https://api.perplexity.ai/mcp` with sign-in (OAuth), Perplexity's [documented Claude Code setup](https://docs.perplexity.ai/docs/getting-started/integrations/mcp-server) (checked 2026-10-08):

1. In Claude Code run `/mcp`
2. Choose `plugin:boom-big-nose-workflow:perplexity` and sign in
3. You must be an admin of a Perplexity API organization that can pay for usage

Until you sign in, agents fall back to `WebSearch` / `WebFetch` and say so. Nothing breaks.

#### Using an API key instead (optional)

Put this in `~/.zshrc` (or whichever shell profile launches Claude Code), then open a new terminal and restart Claude Code from it:

```bash
export PERPLEXITY_API_KEY="pplx-..."   # never paste a real key into chat or git
```

Then, in that new terminal, add a separate key-based server (do not put a key into the plugin's `.mcp.json`):

```bash
claude mcp add --scope user --transport http perplexity-key https://api.perplexity.ai/mcp \
  --header "Authorization: Bearer ${PERPLEXITY_API_KEY}"
```

Your shell substitutes the key when you run this, and Claude Code stores it in `~/.claude.json` (private, on your machine). Check `claude mcp list`: `perplexity-key` should be Connected; `plugin:boom-big-nose-workflow:perplexity` may still say "Needs authentication", which is fine. Never type or ask for a key in chat.

### Context7 (optional)

Nothing required (anonymous works). For higher limits: `export CONTEXT7_API_KEY="..."` in the same shell profile.

### Budgets and config

See `orca.config.json` (validated by `scripts/orca-config-check.mjs` against `orca.config.schema.json`). Each agent's `maxTurns` is enforced by Claude Code. Each gate step is limited by `reviewGate.stepTimeoutSec` (default 1800 s, override with `ORCA_GATE_TIMEOUT`). Plans are validated against `orca.plan.schema.json`. Exit codes: [docs/exit-codes.md](docs/exit-codes.md)

### CI for your own projects

Copy `scripts/orca-gate.sh` + `scripts/lib/` into `<repo>/.github/scripts/` and `templates/github/orca-gate.yml` into `<repo>/.github/workflows/`.

### Docs

- `docs/QUICKSTART.en.md` / `docs/QUICKSTART.md` — step-by-step start
- `docs/workflow-diagram.md` — the whole workflow as one diagram, plan to cleanup, and the SDLC phases with their exit criteria
- `docs/orca-architecture.md` — structure, mermaid, weakness→fix history
- `docs/exit-codes.md` — exit codes of every script
- `docs/decisions/` — ADRs
- `CHANGELOG.md`

### Testing the scripts

```bash
bash tests/run.sh     # unit: each script
bash tests/smoke.sh   # e2e: plan -> worktrees -> gate -> review -> queue -> merge -> report -> cleanup
```

Builds throwaway git repos in a temp directory and deletes them. No network, does not touch other projects. Runs `shellcheck` when it is installed.
