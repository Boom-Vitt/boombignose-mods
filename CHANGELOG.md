# บันทึกการเปลี่ยนแปลง / Changelog

รูปแบบอ้างอิงจาก [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) โดยจัดหัวข้อตามวันที่และแยกตามมอด และแต่ละมอดใช้ [Semantic Versioning](https://semver.org/) แยกกัน
Based on Keep a Changelog, with date headings and per-mod headings; each mod is versioned separately with SemVer.

## Unreleased

### boom-big-nose-workflow 0.4.0

- **เพิ่ม** มอด `boom-big-nose-workflow` (เวิร์กโฟลว์ Orca) เข้า marketplace นี้ ติดตั้งด้วย `claude plugin install boom-big-nose-workflow@claude-mods-boombignose` พร้อมแผนภาพขั้นตอน `boom-big-nose-workflow/docs/workflow-diagram.md` รายละเอียดของแต่ละเวอร์ชันอยู่ใน [boom-big-nose-workflow/CHANGELOG.md](boom-big-nose-workflow/CHANGELOG.md)
- **Added** the `boom-big-nose-workflow` mod (the Orca workflow) to this marketplace: `claude plugin install boom-big-nose-workflow@claude-mods-boombignose`, with a workflow diagram in `boom-big-nose-workflow/docs/workflow-diagram.md`. Per-version notes are in [boom-big-nose-workflow/CHANGELOG.md](boom-big-nose-workflow/CHANGELOG.md).

### pdpa-thai 0.3.0

- **เพิ่ม** `/pdpa-blur record` (โหมดบันทึกหน้าจอ) สำหรับการบันทึกวิดีโอหน้าจอและการแชร์หน้าจอ การพรางยังเปิดอยู่และการวางเมาส์จะไม่แสดงค่าจริง โหมดนี้พรางเฉพาะค่าที่ตรวจพบในข้อความของผู้ใช้และของ Claude และไม่ครอบคลุมข้อมูลที่กฎตรวจไม่พบ ข้อความในช่องพรอมต์ก่อนกดส่ง การเรียกเครื่องมือ ผลลัพธ์ของเครื่องมือหรือคำสั่ง ข้อความต้นฉบับที่แสดงอยู่ที่อื่น และการเลือกหรือคัดลอกข้อความ ดูหัวข้อ "การบันทึกหรือแชร์หน้าจอ" ใน README
- **เพิ่ม** `/pdpa-blur on` และ `/pdpa-blur off` ส่วน `/pdpa-blur` โดยไม่ระบุอาร์กิวเมนต์ยังสลับสถานะเหมือนเดิม (เปิดหากปิดอยู่ ปิดหากเปิดอยู่หรืออยู่ในโหมดบันทึกหน้าจอ)
- **เปลี่ยน** อาร์กิวเมนต์อื่นของ `/pdpa-blur` จะไม่เปลี่ยนการตั้งค่าใด และแสดงบรรทัดวิธีใช้ (usage) ก่อนหน้านี้อาร์กิวเมนต์ถูกละเว้นและคำสั่งสลับสถานะทุกครั้ง
- **เพิ่ม** แถบสถานะแสดง ` · REC` ต่อท้าย `PDPA: <โหมด>` ในโหมดบันทึกหน้าจอ เช่น `PDPA: redact · REC`
- **บันทึกเพิ่มเติม** (อยู่ในโค้ดตั้งแต่ 0.2.0 แต่ยังไม่ได้ระบุไว้ในบันทึกของ 0.2.0) กฎค่าหลังป้ายกำกับ (`SENSITIVE`, `ADDRESS`, `NAME`) ถูกแก้ไม่ให้ใช้เวลาแบบกำลังสอง (quadratic time) กับข้อความบางรูปแบบ และทำงานในเวลาเชิงเส้น ทั้งนี้ค่าหลังป้ายกำกับที่ขึ้นต้นด้วย `[` หรือ `{` (อาร์เรย์หรืออ็อบเจกต์ JSON) จะไม่ตรงกับกฎกลุ่มนี้
- **Added** `/pdpa-blur record` (recording mode) for screen recording and screen sharing: the mask stays on and hovering no longer reveals anything. It masks detected values only in your messages and Claude's messages, and does not cover data the rules do not detect, the prompt box before you send, tool calls, tool or command output, the original text shown anywhere else, or selecting and copying text; see "Recording or sharing your screen" in the README.
- **Added** `/pdpa-blur on` and `/pdpa-blur off`. `/pdpa-blur` with no argument still toggles (on if it was off, off if it was on or recording).
- **Changed** any other argument to `/pdpa-blur` now changes nothing and prints a usage line. Before, arguments were ignored and every run toggled the mask.
- **Added** the status line appends ` · REC` to `PDPA: <mode>` in recording mode, for example `PDPA: redact · REC`.
- **Noted** (in the code since 0.2.0, but missing from the 0.2.0 notes) the labelled-value rules (`SENSITIVE`, `ADDRESS`, `NAME`) were fixed so that certain inputs no longer take quadratic time; they now scan in linear time. A labelled value that opens with `[` or `{` (a JSON array or object) is not matched by these rules.

### เอกสาร การดูแลโครงการ และ CI / Docs, governance and CI

- **เพิ่ม** README ภาษาไทย (`README.md`) และภาษาอังกฤษ (`README.en.md`) ครอบคลุมการติดตั้ง มอดในชุดนี้ ข้อจำกัด และวิธีตรวจสอบโค้ดด้วยตนเอง
- **เพิ่ม** `docs/PDPA.md` และ `docs/PDPA.en.md` สรุปบทบัญญัติที่เกี่ยวข้องของพระราชบัญญัติคุ้มครองข้อมูลส่วนบุคคล พ.ศ. 2562 พร้อม URL แหล่งที่มาและวันที่ตรวจสอบ (ไม่ใช่คำแนะนำทางกฎหมาย)
- **เพิ่ม** `docs/DETECTION.md` และ `docs/DETECTION.en.md` อธิบายกฎการตรวจจับของ `pdpa-thai` ทีละกฎ สิ่งที่ตรวจไม่พบ การตรวจจับผิดที่ทราบ และข้อจำกัดที่ทราบ
- **เพิ่ม** ไฟล์การดูแลโครงการ ได้แก่ `LICENSE` (MIT), `SECURITY.md` (วิธีรายงานช่องโหว่แบบส่วนตัว), `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1), แบบฟอร์ม issue, แม่แบบ pull request, `CODEOWNERS` และ Dependabot สำหรับ GitHub Actions
- **เพิ่ม** CI (`.github/workflows/test.yml`) ซึ่งทำงานทุกครั้งที่มี push และ pull request โดยตรวจ manifest ของ marketplace และของทุกมอด รันชุดทดสอบของ `context-bar` และ `pdpa-thai` ทำการตรวจเฉพาะในเครื่อง (local-only) 2 รายการ (ค้นหาข้อความในโค้ดฮุกของทุกมอดว่ามีการเรียกเครือข่าย โปรเซส โมเดล หรือ MCP หรือ `fetch(` หรือไม่ และตรวจว่าการเรียกเอนจินทุกรายการในบรรทัด `calls:` ที่ `claude plugin validate pdpa-thai` แสดง เป็นการเรียกกลุ่ม state, ui, clock หรือ command เท่านั้น) และตรวจว่าไฟล์ JSON manifest ทุกไฟล์อ่านได้ รายละเอียดอยู่ใน `CONTRIBUTING.md`
- **เปลี่ยน** เพิ่มข้อมูลผู้เขียน สัญญาอนุญาต หน้าแรก และที่เก็บโค้ดใน `plugin.json` ของ `context-bar` และ `agents-panel` (เลขเวอร์ชันไม่เปลี่ยน)
- **Added** Thai (`README.md`) and English (`README.en.md`) READMEs covering install, the mods, limits and how to audit the code yourself.
- **Added** `docs/PDPA.md` and `docs/PDPA.en.md`: the relevant sections of the Personal Data Protection Act B.E. 2562 (2019), each with a source URL and a checked date (not legal advice).
- **Added** `docs/DETECTION.md` and `docs/DETECTION.en.md`: each `pdpa-thai` detection rule, what it misses, known false positives and known limits.
- **Added** governance files: `LICENSE` (MIT), `SECURITY.md` (how to report a vulnerability privately), `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1), issue forms, a pull request template, `CODEOWNERS` and Dependabot for GitHub Actions.
- **Added** CI (`.github/workflows/test.yml`) on every push and pull request: validates the marketplace and every mod, runs the `context-bar` and `pdpa-thai` tests, runs two local-only checks (a text search of every mod's hook code for network, process, model and MCP calls and for `fetch(`, and a check that every engine call on the `calls:` line printed by `claude plugin validate pdpa-thai` is a state, ui, clock or command call), and checks that every JSON manifest parses. Details are in `CONTRIBUTING.md`.
- **Changed** the `plugin.json` of `context-bar` and `agents-panel` now has author, license, homepage and repository fields (versions unchanged).

## 2026-10-04

### pdpa-thai 0.2.0

- **เพิ่ม** `/pdpa-guard` (`redact` | `block` | `off`): ปกปิดข้อมูลส่วนบุคคลที่ตรวจพบในพรอมต์ ผลลัพธ์ของเครื่องมือ และข้อความอื่นที่โมเดลจะอ่าน **ก่อน** ที่โมเดลจะอ่าน ทั้งนี้สำเนาเดิมที่ Claude Code เก็บไว้เองของผลลัพธ์ของเครื่องมือแบบมีโครงสร้าง ไฟล์แนบ และประวัติพรอมต์ ไม่ได้ถูกแก้ไข ดูหัวข้อข้อจำกัดของ README
- **เพิ่ม** ปฏิเสธ tool call ที่มีป้ายแทนค่า (placeholder) `[REDACTED:…]` ของเซสชันนี้ ซึ่งช่วยลดโอกาสที่ป้ายแทนค่าจะถูกเขียนลงไฟล์หรือคำสั่งจริง
- **เปลี่ยน** ยุบ `pdpa-blur` เข้าเป็นมอดเดียว (`pdpa-thai`) ใช้กฎตรวจจับชุดเดียวกัน; `/pdpa-blur` ยังใช้ได้เหมือนเดิม
- **เพิ่ม** ชนิดข้อมูล: เลขบัตรชำระเงิน (Luhn), IPv4, โทเค็น/รหัสผ่าน, หนังสือเดินทาง, เลขบัญชี, วันเกิด, ที่อยู่, ชื่อ, หมวดอ่อนไหวมาตรา 26 แบบ `label: value`
- **Added** `/pdpa-guard` (`redact` | `block` | `off`): redacts detected personal data in prompts, tool results and other rows the model reads *before* the model reads them. Claude Code's own raw copies of structured tool results, attachments and prompt history are not changed; see the README's Limits.
- **Added** refusal of tool calls that contain a `[REDACTED:…]` placeholder issued in this session, to help keep placeholders out of real files and commands.
- **Changed** merged `pdpa-blur` into a single mod, `pdpa-thai`, sharing one set of detection rules; `/pdpa-blur` works as before.
- **Added** kinds of data: payment card (Luhn), IPv4, tokens and passwords, passport, bank account, date of birth, address, name, and section 26 sensitive categories written as `label: value`.

### context-bar 0.4.0

- แถบ context แยกตามหมวด พร้อมตัวนับเวลา prompt cache (`live` / นับถอยหลัง / `cold`) / Context breakdown bar with a prompt-cache countdown.

### agents-panel 0.1.0

- แผงข้างแสดง agent ของโปรเจกต์ (`.claude/agents`) และ agent ของผู้ใช้/ปลั๊กอิน พร้อมปุ่มเรียกใช้ / Side pane listing project, user and plugin agents with a run button.
