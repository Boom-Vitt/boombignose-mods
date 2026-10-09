# BBN Quickstart (ภาษาไทย)

[English](QUICKSTART.en.md)

ตั้งแต่ v0.5 BBN ทำงานเองอัตโนมัติ ติดตั้งแล้วบอกสิ่งที่อยากได้เป็นภาษาธรรมดาได้เลย ส่วน A คือเส้นทางอัตโนมัติ ส่วน B คือการสั่งเองทีละขั้นด้วยคำสั่ง `/bbn-*` ซึ่งยังใช้ได้เหมือนเดิม

# A. โหมดอัตโนมัติ

## 1. ติดตั้งและตรวจ

```bash
claude plugin marketplace add Boom-Vitt/boombignose-mods
claude plugin install boom-big-nose-workflow@boombignose-mods
```

รีสตาร์ท Claude Code แล้วใน repo ของคุณพิมพ์ `/bbn-doctor` ทุกบรรทัด WARN/FAIL จะมี `fix:` บอกวิธีแก้ ต้องมี git 2.39+ และ node

Codex CLI ไม่บังคับ ถ้าติดตั้งไว้ role `codex` จะส่งงานที่แตะหลายไฟล์ให้ Codex ทำ และ reviewer จะได้ความเห็นที่สองจาก Codex ด้วย:

```bash
npm install -g @openai/codex
codex login
```

ถ้าไม่มี `/bbn-doctor` จะเตือน stream ของ role `codex` จะย้ายไปให้ `claude-code` ทำแทน และ reviewer จะรีวิวคนเดียว ตั้งโมเดลและ effort ได้ที่ `bbn.config.json` → `codex` (`gpt-6.1-sol`, reasoning `xhigh`) หรือใช้ `BBN_CODEX_MODEL` / `BBN_CODEX_EFFORT`

Perplexity ไม่บังคับ: `/mcp` -> `plugin:boom-big-nose-workflow:perplexity` -> sign in ถ้าไม่ทำ hub จะใช้ WebSearch แทน

## 2. บอกเป้าหมาย

ใน git repo พิมพ์เป้าหมายเป็นภาษาธรรมดา เช่น

```text
เพิ่มการจ่ายเงินด้วยบัตร: มี API สร้าง order และหน้า checkout พร้อม test ยังไม่ต้องทำคูปอง
```

ไม่ต้องพิมพ์ slash command เพราะ skill `bbn-workflow` จะเริ่มเองเมื่องานแตะหลายไฟล์หรือหลายส่วน (ไม่เริ่มกับคำถามหรือการแก้บรรทัดเดียว) ถ้าอยากให้ทั้ง session เป็นอัตโนมัติ ให้เปิด Claude Code ด้วย `claude --agent boom-big-nose-workflow:bbn-orchestrator` หรือจะพิมพ์ว่า "use BBN" ก็ได้

## 3. ระบบทำอะไรบ้าง

1. **วางแผน** BBN ซึ่งเป็น hub (Claude Opus) เขียน `.bbn/plan.json` (ไม่เข้า git) ระบุ stream, path ที่แต่ละ stream ดูแล, `dependsOn` และคำสั่ง acceptance ที่จะ fail จนกว่างานจะเสร็จ ดูตัวอย่างด้านล่าง
2. **อนุมัติแผน** `bbn-reviewer` (Claude Opus) ตรวจแผนแล้วอนุมัติ หรือส่งกลับให้ hub พร้อมรายการที่ต้องแก้
3. **สร้างงาน** harness (`scripts/bbn-run.mjs`) สร้าง worktree ให้ stream ละหนึ่งอันตามลำดับ dependency แล้ว `claude-code` (Claude Sonnet) หรือ `codex` (Codex CLI ที่ Claude Haiku คุม) ทำงานของ stream นั้นและ commit
4. **ตรวจ** harness รัน acceptance ของ stream และ gate (lint/typecheck/test) บน commit นั้นตรง ๆ ถ้าไม่ผ่านจะส่งกลับให้คนทำแก้ (`fix`)
5. **รีวิว** `bbn-reviewer` รีวิว branch โดยมีความเห็นที่สองจาก Codex ถ้า APPROVE harness จะ merge เข้า base **ในเครื่อง** ทีละ branch ตามลำดับในแผน ถ้าชนกัน `codex` จะแก้ แล้ว branch นั้นต้องผ่านการตรวจและรีวิวใหม่
6. **ยืนยันผล** หลัง merge ตัวสุดท้าย harness ลบ worktree ที่ merge แล้ว และรัน acceptance ทุกข้อพร้อม gate บน base ที่รวมแล้ว จากนั้น BBN รายงานผลแต่ละ stream ผลการยืนยัน commit ของ base ในเครื่อง และ turn ที่ใช้เทียบงบ

ระบบไม่ push อะไรเลย การ push เปิด PR และ deploy เป็นการตัดสินใจของคุณ ถ้า stream ไหนไม่ผ่านการตรวจหรือรีวิวครบ 3 ครั้ง หรือขั้นไหนไม่คืบหน้า stream นั้นจะหยุด BBN จะบอกว่าหยุดที่ stream ไหนเพราะอะไร แล้วทำ stream อื่นต่อ

ตัวอย่างแผน:

```json
{
  "version": 1,
  "title": "ระบบ checkout",
  "status": "draft",
  "goal": "ผู้ใช้จ่ายเงินด้วยบัตรได้",
  "nonGoals": ["คูปอง"],
  "base": "main",
  "streams": [
    { "slug": "checkout-api", "role": "claude-code", "summary": "API สร้าง order",
      "paths": ["src/api/checkout/"], "dependsOn": [],
      "acceptance": ["npm test -- src/api/checkout"] },
    { "slug": "checkout-ui", "role": "claude-code", "summary": "หน้า checkout",
      "paths": ["src/app/checkout/"], "dependsOn": ["checkout-api"],
      "acceptance": ["npm test -- src/app/checkout"] }
  ],
  "risks": ["เปลี่ยน schema ของ order"]
}
```

`acceptance` แต่ละข้อคือคำสั่ง shell ที่รันจาก root ของ worktree ถ้า exit 0 ถือว่าผ่าน

## 4. เปิด checkpoint

ค่าเริ่มต้นคือระบบไม่หยุดรอคุณเลยตั้งแต่สั่งงานจนถึงรายงานสุดท้าย ถ้าอยากให้หยุดถามเหมือนเดิม ให้ตั้ง `automation` ใน `bbn.config.json` ของปลั๊กอิน (เป็นไฟล์ของปลั๊กอินเอง หลังอัปเดตปลั๊กอินควรเช็กอีกครั้ง):

```json
"automation": { "planApproval": "user", "merge": "ask" }
```

- `planApproval: "user"`: BBN แสดงแผนแล้วรอคุณตอบ OK ก่อนสร้าง worktree
- `merge: "ask"`: BBN ถามก่อน merge เข้า base ในเครื่องทุกครั้ง

เลือกเปิดอย่างใดอย่างหนึ่งหรือทั้งสองอย่างก็ได้

## 5. ดูความคืบหน้าหรือดูล่วงหน้า

- `/bbn-status`: ดู worktree ทั้งหมด ahead/behind สถานะ gate และ review
- `/bbn-report`: gate, review, merge และ turn ที่ใช้ต่อ agent เทียบงบ
- ถ้าอยากรู้ว่าขั้นต่อไปจะทำอะไรโดยไม่เปลี่ยนอะไรเลย ให้ Claude รัน `node ${CLAUDE_PLUGIN_ROOT}/scripts/bbn-run.mjs` (ไม่ใส่ `--apply`) ส่วน `bbn-run.mjs verify` จะรัน acceptance ทุกข้อและ gate บน base ตอนนี้

# B. สั่งเองทีละขั้น

คำสั่ง `/bbn-*` ยังใช้สั่งแต่ละขั้นเองได้ ทุกขั้นที่เปลี่ยนอะไรจริงเป็น dry-run ก่อนเสมอ

## 1. วางแผน (checkpoint)

```text
/bbn-plan init "ระบบ checkout"
```

BBN (hub) เขียนแผนลง `.bbn/plan.json` แบบเดียวกับตัวอย่างในข้อ A.3

`/bbn-plan check` ตรวจ: schema, จำนวน stream ไม่เกินงบ, acceptance อย่างน้อย `minAcceptanceChecks` ข้อต่อ stream (ค่าเริ่มต้น 1), path ต้องเป็น relative, dependsOn ต้องมีจริงและไม่วนกัน, **สอง stream ห้ามเป็นเจ้าของ path เดียวกัน** เว้นแต่ stream หนึ่ง dependsOn อีก stream

ดูแผนแล้วตอบ OK จากนั้น BBN รัน `accept` และ `apply --apply` ซึ่งสร้าง worktree ตามลำดับ dependency พร้อม `.bbn/ownership.json` ถ้าแก้แผนหลัง accept ต้อง `check` + `accept` ใหม่ (apply จะปฏิเสธ exit 3)

## 2. ทำงานคู่ขนาน

- `claude-code` หรือ `codex` ทำงานใน worktree ของตัวเอง (port, `.env.worktree`, DB branch `wt-<slug>` แยกกัน)
- หลัง agent แต่ละตัวทำเสร็จ BBN บันทึกจำนวน turn ลง ledger (`bbn-ledger.sh agent ...`)
- `/bbn-status` ดูภาพรวม

## 3. ลำดับการ merge

```text
/bbn-queue
```

เรียงตาม dependency ของแผน -> พร้อมแล้ว (gate + review ตรงกับ commit ปัจจุบัน) -> คาดว่าชนกับ base -> ชนกันเอง -> ขนาด ทำนายการชนด้วย `git merge-tree` โดยไม่แตะ checkout ไหนเลย บรรทัด `next:` คือสาขาที่ควร merge ก่อน

## 4. รีวิวและ merge

```text
/bbn-review checkout-api
/bbn-merge checkout-api            # dry-run
/bbn-merge checkout-api --apply    # rebase -> gate -> ตรวจ fingerprint -> merge เข้า base ในเครื่อง
```

- exit 3: ถูกปฏิเสธ (ยังไม่ APPROVE, tree ไม่สะอาด, dependency ในแผนยังไม่ merge)
- exit 4: ชนตอน rebase -> ส่งให้ `codex` แล้วรีวิวใหม่
- exit 5: โค้ดเปลี่ยนหลังรีวิว -> รีวิวใหม่

ไม่ push base และไม่ force-push ถ้าต้องการ PR: `--apply --pr` (draft)

## 5. สรุปและเก็บกวาด

```text
/bbn-report     # gate/review/merge และ turn ที่ใช้ต่อ agent เทียบงบ
/bbn-cleanup    # dry-run; --apply ลบ worktree ที่ merge แล้ว
```

ความหมาย exit code ทั้งหมด: [exit-codes.md](exit-codes.md)
