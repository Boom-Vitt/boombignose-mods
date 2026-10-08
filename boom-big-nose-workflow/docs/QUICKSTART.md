# Orca Quickstart (ภาษาไทย)

[English](QUICKSTART.en.md)

ตั้งแต่ติดตั้งจนรวมฟีเจอร์แรกเข้า base ใช้เวลาประมาณ 10 นาที ทุกขั้นที่เปลี่ยนอะไรจริงเป็น dry-run ก่อนเสมอ

## 1. ติดตั้งและตรวจ

```bash
claude plugin marketplace add Boom-Vitt/boombignose-mods
claude plugin install boom-big-nose-workflow@boombignose-mods
```

รีสตาร์ท Claude Code แล้วใน repo ของคุณพิมพ์ `/orca-doctor` ทุกบรรทัด WARN/FAIL จะมี `fix:` บอกวิธีแก้ ต้องมี git 2.38+ และ node

Perplexity ไม่บังคับ: `/mcp` -> `plugin:boom-big-nose-workflow:perplexity` -> sign in ถ้าไม่ทำ agent จะใช้ WebSearch แทน

## 2. วางแผน (checkpoint)

```text
/orca-plan init "ระบบ checkout"
```

Orca ให้ `grok-build` เขียนแผนลง `.orca/plan.json` (ไม่เข้า git) ตัวอย่าง:

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
      "acceptance": ["POST /checkout คืน 201", "มี test ของ order total"] },
    { "slug": "checkout-ui", "role": "claude-code", "summary": "หน้า checkout",
      "paths": ["src/app/checkout/"], "dependsOn": ["checkout-api"],
      "acceptance": ["กดจ่ายแล้วไปหน้า success", "แสดง error เมื่อบัตรถูกปฏิเสธ"] }
  ],
  "risks": ["เปลี่ยน schema ของ order"]
}
```

`/orca-plan check` ตรวจ: schema, จำนวน stream ไม่เกินงบ, acceptance อย่างน้อย 2 ข้อ, path ต้องเป็น relative, dependsOn ต้องมีจริงและไม่วนกัน, **สอง stream ห้ามเป็นเจ้าของ path เดียวกัน** เว้นแต่ stream หนึ่ง dependsOn อีก stream

ดูแผนแล้วตอบ OK จากนั้น Orca รัน `accept` และ `apply --apply` ซึ่งสร้าง worktree ตามลำดับ dependency พร้อม `.orca/ownership.json` ถ้าแก้แผนหลัง accept ต้อง `check` + `accept` ใหม่ (apply จะปฏิเสธ exit 3)

## 3. ทำงานคู่ขนาน

- `claude-code` ทำงานใน worktree ของตัวเอง (port, `.env.worktree`, DB branch `wt-<slug>` แยกกัน)
- หลัง agent แต่ละตัวทำเสร็จ Orca บันทึกจำนวน turn ลง ledger (`orca-ledger.sh agent ...`)
- `/orca-status` ดูภาพรวม

## 4. ลำดับการ merge

```text
/orca-queue
```

เรียงตาม dependency ของแผน -> พร้อมแล้ว (gate + review ตรงกับ commit ปัจจุบัน) -> คาดว่าชนกับ base -> ชนกันเอง -> ขนาด ทำนายการชนด้วย `git merge-tree` โดยไม่แตะ checkout ไหนเลย บรรทัด `next:` คือสาขาที่ควร merge ก่อน

## 5. รีวิวและ merge

```text
/orca-review checkout-api
/orca-merge checkout-api            # dry-run
/orca-merge checkout-api --apply    # rebase -> gate -> ตรวจ fingerprint -> merge เข้า base ในเครื่อง
```

- exit 3: ถูกปฏิเสธ (ยังไม่ APPROVE, tree ไม่สะอาด, dependency ในแผนยังไม่ merge)
- exit 4: ชนตอน rebase -> ส่งให้ `codex` แล้วรีวิวใหม่
- exit 5: โค้ดเปลี่ยนหลังรีวิว -> รีวิวใหม่

ไม่ push base และไม่ force-push ถ้าต้องการ PR: `--apply --pr` (draft)

## 6. สรุปและเก็บกวาด

```text
/orca-report     # gate/review/merge และ turn ที่ใช้ต่อ agent เทียบงบ
/orca-cleanup    # dry-run; --apply ลบ worktree ที่ merge แล้ว
```

ความหมาย exit code ทั้งหมด: [exit-codes.md](exit-codes.md)
