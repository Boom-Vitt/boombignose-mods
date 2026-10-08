# BBN workflow diagram

How a goal moves through BBN v0.4, from plan to cleanup, and how each step maps to an SDLC phase ([ไทย](#sdlc-th)). Step by step: [QUICKSTART.en.md](QUICKSTART.en.md) · [QUICKSTART.md](QUICKSTART.md) (ไทย). Roles and design: [bbn-architecture.md](bbn-architecture.md).

```
                        ┌───────────────────────────┐
  you ──── goal ──────▶ │  bbn-orchestrator  (hub)  │   setup unknown? → /bbn-doctor  (every problem has a fix: hint)
                        └─────────────┬─────────────┘
                 ┌────────────────────┴────────────────────┐
         several streams                              one ad-hoc stream
                 ▼                                         ▼
 ① /bbn-plan                                      /bbn-worktree  <slug>
   grok-build writes .bbn/plan.json                 port, .env.worktree,
   (streams · owned paths · dependsOn · acceptance) .bbn/ownership.json
   check ─▶ shown to you ─▶ ⏸ waits for your OK
   ─▶ accept ─▶ apply --apply
   (worktrees created in dependency order)
                 └────────────────────┬────────────────────┘
                                      ▼
 ② BUILD     ┌ worktree A ┐   ┌ worktree B ┐   ┌ worktree C ┐
             │ claude-code│   │ claude-code│   │ claude-code│   maxTurns per agent (bbn.config.json)
             └─────┬──────┘   └─────┬──────┘   └─────┬──────┘
                   └────── conflict? (exit 4) ──▶ codex integrates and resolves
             each run logged: bbn-ledger.sh  agent <role> --turns N --status ok|partial|failed
                                      ▼
 ③ /bbn-queue    merge order + predicted conflicts   ·   /bbn-status  quick overview
                                      ▼
 ④ /bbn-review   bbn-gate.sh  (lint/typecheck/test) + bbn-reviewer
                 ├─ APPROVE ─────────────────────────────┐
                 └─ REQUEST_CHANGES / BLOCK ─▶ back to ② │
                                      ▼  ◀───────────────┘
 ⑤ /bbn-merge    dry-run ─▶ --apply      (local merge; refused while a plan dependency is unmerged)
                         └▶ --apply --pr (draft PR)        never force-push
                                      ▼                    stale review (exit 5) ─▶ back to ④
 ⑥ /bbn-cleanup  removes merged worktrees   ·   /bbn-report  turns used vs budget
```

**Exit codes (every script):** 0 ok · 1 check failed · 2 usage · 3 refused by policy · 4 conflict → codex · 5 stale review. Details: [exit-codes.md](exit-codes.md).

**MCP routing:** research → Perplexity (fallback WebSearch + WebFetch) · library/API docs → Context7 (fallback WebFetch of official docs). Both are optional.

## SDLC phases

BBN runs a change through the software development life cycle. Each phase ends with an exit criterion, and the next phase starts only when it holds.

```
 requirements ──▶ design ──▶ build ──▶ test & review ──▶ release ──▶ maintain
  hub + you        ①          ② ③        ④                 ⑤           ⑥
                   ▲          ▲          │
                   │          └──────────┤ REQUEST_CHANGES · conflict (exit 4)
                   └─────────────────────┘ wrong scope or design: re-plan, accept again
```

| Phase | BBN step | Exit criterion |
|---|---|---|
| Requirements | The hub agrees the goal, non-goals and success criteria with you | You confirm; every stream gets testable acceptance checks |
| Design | ① `/bbn-plan`: streams, owned paths, dependsOn, risks; an ADR in `docs/decisions/` for lasting decisions | `check` passes and you say OK, then `accept` |
| Build | ② one worktree per stream (`claude-code`), integration (`codex`); ③ `/bbn-queue` | The stream's acceptance checks pass; the run is in the ledger |
| Test and review | ④ `/bbn-review`: `bbn-gate.sh` (lint/typecheck/test), then an independent `bbn-reviewer` | Gate exit 0 (exit 2 explained) and APPROVE on the current patch |
| Release | ⑤ `/bbn-merge`: dry-run, then `--apply` or `--apply --pr` | Merged without force-push. Deploying stays the project's own step, with the owner's approval |
| Maintain | ⑥ `/bbn-cleanup`, `/bbn-report`, ADR updates | Merged worktrees removed; budget use and failures reported |

**Principles**

- **Test early:** acceptance checks are written in the plan, before any code.
- **Traceability:** every merge traces back through goal, stream, acceptance, gate, verdict and ledger.
- **Change control:** a changed plan must be accepted again before `apply`; any new commit makes the review stale (exit 5).
- **Separation of duties:** nobody approves their own plan or code.
- **Fail back to the owning phase:** REQUEST_CHANGES goes to build, a conflict to `codex` and then review, a stale review to review, wrong scope or design to a re-plan.
- **Small batches:** one stream per worktree, merged one branch at a time in queue order.

<a id="sdlc-th"></a>
## หลักการ SDLC (ภาษาไทย)

BBN พางานผ่านวงจรการพัฒนาซอฟต์แวร์ (SDLC) ทีละเฟส แต่ละเฟสมีเกณฑ์ผ่าน ถ้ายังไม่ผ่านจะไม่เริ่มเฟสถัดไป

| เฟส | ขั้นใน BBN | เกณฑ์ผ่าน |
|---|---|---|
| เก็บความต้องการ | hub ตกลงเป้าหมาย สิ่งที่ไม่ทำ และเกณฑ์ความสำเร็จกับคุณ | คุณยืนยัน และทุก stream มี acceptance check ที่ทดสอบได้ |
| ออกแบบ | ① `/bbn-plan`: stream, ไฟล์ที่แต่ละ stream ดูแล, dependsOn, ความเสี่ยง และเขียน ADR ใน `docs/decisions/` สำหรับการตัดสินใจระยะยาว | `check` ผ่าน คุณตอบตกลง แล้วจึง `accept` |
| พัฒนา | ② หนึ่ง worktree ต่อหนึ่ง stream (`claude-code`), รวมหลายไฟล์ (`codex`); ③ `/bbn-queue` | acceptance check ของ stream ผ่าน และบันทึกการรันลง ledger แล้ว |
| ทดสอบและรีวิว | ④ `/bbn-review`: `bbn-gate.sh` (lint/typecheck/test) แล้วให้ `bbn-reviewer` ที่ไม่ได้เขียนโค้ดเองเป็นผู้ตรวจ | gate ได้ exit 0 (ถ้าได้ exit 2 ต้องอธิบายเหตุผล) และได้ APPROVE บน patch ปัจจุบัน |
| ส่งมอบ | ⑤ `/bbn-merge`: dry-run ก่อน แล้ว `--apply` หรือ `--apply --pr` | merge แล้วโดยไม่ force-push ส่วนการ deploy เป็นขั้นของโปรเจกต์เอง และต้องได้รับอนุมัติจากเจ้าของ |
| ดูแลต่อ | ⑥ `/bbn-cleanup`, `/bbn-report`, อัปเดต ADR | ลบ worktree ที่ merge แล้ว และรายงานการใช้งบกับจุดที่ล้มเหลว |

**หลักการ**

- **ทดสอบตั้งแต่ต้น:** เขียน acceptance check ไว้ในแผนก่อนเริ่มเขียนโค้ด
- **ตรวจย้อนได้:** ทุก merge ย้อนกลับไปหาเป้าหมาย, stream, acceptance, gate, คำตัดสินรีวิว และ ledger ได้
- **ควบคุมการเปลี่ยนแปลง:** แผนที่ถูกแก้ต้อง accept ใหม่ก่อน `apply` และ commit ใหม่ทุกครั้งทำให้รีวิวเดิมหมดอายุ (exit 5)
- **แยกหน้าที่:** ไม่มีใครอนุมัติแผนหรือโค้ดของตัวเอง
- **ย้อนกลับไปเฟสที่รับผิดชอบปัญหา:** REQUEST_CHANGES กลับไปเฟสพัฒนา, conflict ส่งให้ `codex` แล้วรีวิวใหม่, รีวิวหมดอายุก็รีวิวใหม่, ขอบเขตหรือการออกแบบผิดก็วางแผนใหม่
- **ทำงานเป็นชิ้นเล็ก:** หนึ่ง stream ต่อหนึ่ง worktree และ merge ทีละสาขาตามลำดับใน queue
