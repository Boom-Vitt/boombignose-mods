# นโยบายความปลอดภัย / Security Policy

**ไทย** · [English](#en)

<a id="th"></a>

## ภาษาไทย

boombignose-mods เป็นโครงการชุมชนที่ไม่เป็นทางการ ดูแลโดยบุคคลคนเดียวในเวลาว่าง ไม่มีความเกี่ยวข้องกับ Anthropic, สำนักงานคณะกรรมการคุ้มครองข้อมูลส่วนบุคคล (PDPC), สำนักงานพัฒนาธุรกรรมทางอิเล็กทรอนิกส์ (ETDA), สำนักงานพัฒนารัฐบาลดิจิทัล (DGA), กระทรวงดิจิทัลเพื่อเศรษฐกิจและสังคม (MDES) หรือหน่วยงานของรัฐใด ๆ ของไทย และไม่ได้รับการสนับสนุนหรือการรับรองจากองค์กรหรือหน่วยงานเหล่านี้

### เวอร์ชันที่ยังได้รับการแก้ไข (supported versions)

การแก้ไขด้านความปลอดภัยจะออกในเวอร์ชันล่าสุดของแต่ละมอด (mod) เท่านั้น ไม่มีการย้อนแก้ (backport) ไปยังเวอร์ชันเก่า

| มอด | เวอร์ชันที่ยังได้รับการแก้ไข | เวอร์ชันอื่น |
| --- | --- | --- |
| `pdpa-thai` | 0.3.x | ไม่ได้รับการแก้ไข |
| `context-bar` | 0.4.x | ไม่ได้รับการแก้ไข |
| `agents-panel` | 0.1.x | ไม่ได้รับการแก้ไข |
| `boom-big-nose-workflow` | 0.5.x | ไม่ได้รับการแก้ไข |
| `pdpa-blur` (รวมเข้ากับ `pdpa-thai` ตั้งแต่เวอร์ชัน 0.2.0) | ไม่มี | ให้เปลี่ยนไปใช้ `pdpa-thai` |

วิธีรับเวอร์ชันที่แก้ไขแล้ว ให้สั่ง `claude plugin marketplace update boombignose-mods` แล้วสั่ง `claude plugin update pdpa-thai@boombignose-mods` (มอดอื่นใช้คำสั่งเดียวกัน) จากนั้นเริ่ม Claude Code ใหม่

มอดทั้งหมดต้องใช้ Claude Code เวอร์ชันที่รองรับปลั๊กอินแบบ hook module และทดสอบแล้วกับ Claude Code เวอร์ชัน 2.1.289 เท่านั้น

ไฟล์ประกาศชนิด (type declarations) ที่ Claude Code เขียนไว้ข้างมอดเมื่อโหลดมอดจากโฟลเดอร์ (`.claude-plugin/types/claude-code/index.d.ts`) ระบุว่า API ของ hook module อยู่ในระยะเปิดให้ใช้ก่อน (early access) และอาจเปลี่ยนแปลงระหว่างเวอร์ชันโดยไม่แจ้งล่วงหน้า Claude Code เวอร์ชันเก่าหรือใหม่กว่านี้จึงอาจข้ามตัวป้องกัน (guard) บางส่วนหรือทั้งหมดโดยไม่มีคำเตือน หรือส่งข้อความผ่านเส้นทางที่ตัวป้องกันไม่ได้ดักไว้ CI ติดตั้ง Claude Code เวอร์ชันล่าสุดจาก npm แล้วตรวจ manifest และรันเทสต์ของมอด (รายละเอียดใน[สิ่งที่ CI ตรวจ](CONTRIBUTING.md#สิ่งที่-ci-ตรวจ)) ซึ่งช่วยให้พบ API ที่เปลี่ยนไปเท่าที่เทสต์ครอบคลุม แต่ป้ายสถานะ (badge) ของ CI แสดงเพียงว่าเทสต์หน่วย (unit test) ผ่านบนเวอร์ชันล่าสุด ไม่ได้แสดงว่าเวอร์ชันใหม่ยังส่งข้อความทุกเส้นทางผ่าน hook ที่ตัวป้องกันใช้ เวอร์ชันที่ทดสอบแล้วจึงยังคงเป็น 2.1.289

### วิธีรายงานช่องโหว่ (vulnerability)

**ห้ามเปิด issue สาธารณะที่มีรายละเอียดของช่องโหว่**

1. หากแท็บ **Security** ของ repository แสดงปุ่ม **Report a vulnerability** ให้กดปุ่มนั้นเพื่อส่งรายงานแบบส่วนตัว (private security advisory) ซึ่งเห็นได้เฉพาะผู้รายงาน ผู้ดูแลโครงการ และผู้ที่ผู้ดูแลเพิ่มเข้าใน advisory ทั้งนี้ สามารถเปิดแบบฟอร์มได้โดยตรงที่ <https://github.com/Boom-Vitt/boombignose-mods/security/advisories/new>
2. หากไม่พบปุ่ม Report a vulnerability แสดงว่าการรายงานแบบส่วนตัวยังปิดอยู่ ให้เปิด issue ด้วยแบบฟอร์ม **Feature request** ตั้งชื่อเรื่องว่า "Request private security contact" เขียนในช่องแรกเพียงว่า "ขอช่องทางติดต่อส่วนตัวเพื่อรายงานด้านความปลอดภัย" และเว้นช่องอื่นว่างไว้ ห้ามใส่รายละเอียดใด ๆ ของช่องโหว่ (ไม่ระบุมอด ชนิดข้อมูล หรือวิธีทำซ้ำ) ผู้ดูแลจะเปิดการรายงานแบบส่วนตัว ตอบกลับใน issue นั้นพร้อมลิงก์ แล้วปิด issue โครงการไม่เผยแพร่ที่อยู่อีเมล

ข้อมูลที่ควรมีในรายงาน

- มอดและเวอร์ชัน (ดูได้จาก `claude plugin list` หรือ `.claude-plugin/plugin.json` ของมอด) เวอร์ชันของ Claude Code (`claude --version`) และระบบปฏิบัติการ
- สำหรับ `pdpa-thai` ระบุว่าแถบสถานะ (status line) แสดง `PDPA: redact` หรือ `PDPA: block` หรือไม่ หากไม่แสดง แสดงว่ามอดไม่ได้โหลดและไม่มีการปกปิดใด ๆ (ดูสาเหตุได้ด้วย `claude --debug`)
- ขั้นตอนทำซ้ำ และผลที่คาดหวังเทียบกับผลที่เกิดขึ้นจริง
- ผลกระทบ เช่น ข้อมูลชนิดใดรั่วไหล และรั่วไหลไปที่ใด
- ตัวอย่างข้อมูลที่เป็นข้อมูลสมมติเท่านั้น (ดูหัวข้อถัดไป)

### ห้ามใส่ข้อมูลส่วนบุคคลจริง

ห้ามใส่ข้อมูลส่วนบุคคลจริงในรายงาน ใน issue หรือ pull request ในภาพหน้าจอ หรือในไฟล์ log ไม่ว่าจะเป็นข้อมูลของตนเองหรือของผู้อื่น ให้สร้างตัวอย่างสมมติที่ให้ผลแบบเดียวกัน หรืออธิบายรูปแบบเป็นคำพูด เช่น "เบอร์มือถือ 10 หลักที่เขียนด้วยเลขไทย" หากเผลอส่งข้อมูลจริงไปแล้ว ให้แจ้งผู้ดูแลผ่านช่องทางส่วนตัวข้างต้นเพื่อให้ผู้ดูแลพยายามลบออก ทั้งนี้ประวัติการแก้ไข fork และสำเนาที่มีอยู่แล้วอาจยังเก็บข้อมูลไว้

### สิ่งที่คาดหวังได้

โครงการนี้ดำเนินการโดยอาสาสมัคร ผู้ดูแลจะพยายามตอบรับรายงานภายใน 7 วันโดยไม่รับประกัน และไม่มีข้อตกลงระดับบริการ (SLA) ใด ๆ รวมถึงระยะเวลาแก้ไขและการออกเวอร์ชันใหม่ หลังตอบรับแล้ว ผู้ดูแลจะตรวจสอบว่าปัญหาเกิดขึ้นจริงหรือไม่ แจ้งความคืบหน้าใน advisory เดียวกัน และแจ้งเมื่อมีเวอร์ชันที่แก้ไขแล้ว

### ขอบเขต

อยู่ในขอบเขต (in scope)

- เทคนิคที่ทำให้ค่าซึ่งควรถูกปกปิดหลุดผ่านตัวป้องกันได้อย่างสม่ำเสมอ ทั้งที่ค่านั้นอยู่ในรูปแบบที่ [docs/DETECTION.md](docs/DETECTION.md) ระบุว่าครอบคลุม เช่น การแปลงรหัสอักขระ (encoding) หรือการจัดรูปแบบข้อความที่ไม่ได้ระบุไว้ในข้อจำกัดที่ทราบ ส่วนกรณีที่ตัวตรวจจับ (detector) พลาดเป็นครั้งคราว ให้รายงานด้วยแบบฟอร์ม Bug report ตามปกติพร้อมตัวอย่างสมมติ
- วิธีที่ทำให้ตัวป้องกันเองคัดลอกค่าเดิมที่ตรวจพบไปไว้ใน log สถานะของปลั๊กอิน (plugin state) หรือข้อความในทรานสคริปต์ (transcript) ที่ตัวป้องกันเขียนทับแล้ว
- ข้อความที่ทำให้ตัวตรวจจับทำงานนานผิดปกติหรือค้าง เช่น ReDoS (regular expression denial of service) กรณีนี้เป็นการหลบเลี่ยงตัวป้องกัน ไม่ใช่เพียงความล่าช้า เพราะ Claude Code จะข้าม hook ที่ทำงานเกินเวลาที่กำหนดต่อ hook และส่งข้อความไปตามเดิมโดยไม่แจ้งเตือน (fail-open)
- มอดที่เรียกเครือข่าย โปรเซส (process) โมเดล หรือ MCP นอกเหนือจากที่ README ระบุไว้ กรณีที่ระบุไว้คือปุ่ม ▶ run ของ `agents-panel` ซึ่งขอให้ Claude Code เริ่ม subagent เมื่อผู้ใช้กดปุ่มเท่านั้น และ subagent นั้นส่งบทสนทนาไปยังผู้ให้บริการโมเดลที่ตั้งค่าไว้ (โดยค่าเริ่มต้นคือ Anthropic) เช่นเดียวกับ agent อื่น และ `boom-big-nose-workflow` ซึ่งรันสคริปต์ของมอด เริ่ม subagent และใช้เซิร์ฟเวอร์ MCP Context7 และ Perplexity ตามที่ README ระบุ รวมถึง `bbn-codex.sh` ซึ่งรัน Codex CLI ของผู้ใช้ (Codex CLI เรียก OpenAI ด้วยการล็อกอินของผู้ใช้เอง) ส่วน `pdpa-thai` และ `context-bar` ไม่เรียกสิ่งเหล่านี้เลย
- ปัญหาด้านห่วงโซ่อุปทานซอฟต์แวร์ (supply chain) ใน CI เช่น ใน `.github/workflows/` หรือ `.github/dependabot.yml`

ไม่อยู่ในขอบเขต (out of scope)

- รูปแบบหรือกรณีที่ระบุไว้แล้วว่าไม่ครอบคลุมในหัวข้อ[ข้อจำกัด](README.md#ข้อจำกัด)ของ README หรือใน[ข้อจำกัดที่ทราบ](docs/DETECTION.md#ข้อจำกัดที่ทราบ)ของ docs/DETECTION.md (ทั้งสองรายการเป็นชุดเดียวกัน) ตัวอย่างเช่น
  - ผลลัพธ์ของเครื่องมือแบบมีโครงสร้างและเนื้อหาของไฟล์แนบ (เช่น ไฟล์ที่อ้างถึงด้วย `@`) ที่ Claude Code เก็บไว้ยังคงเป็นค่าเดิมในทรานสคริปต์ และการแสดงผลลัพธ์ของเครื่องมือบนหน้าจอไม่ถูกพราง
  - ประวัติพรอมต์ของ Claude Code เอง (ที่เรียกกลับด้วยปุ่มลูกศรขึ้น) อยู่นอกการควบคุมของมอด และอาจเก็บข้อความที่ผู้ใช้พิมพ์ไว้บนเครื่องโดยไม่ปกปิด
  - ไม่ตรวจพรอมต์ระบบ (system prompt) เช่น ข้อมูลสภาพแวดล้อม คำแนะนำของเซิร์ฟเวอร์ MCP และส่วนที่ปลั๊กอินอื่นเพิ่มเข้าไป รวมถึงคำอธิบายของเครื่องมือและ skill
  - hook ของปลั๊กอินอื่นที่ทำงานก่อนมอดนี้อาจเห็นข้อความต้นฉบับ
  - หาก hook ของมอดเกิดข้อผิดพลาด (throw) หรือใช้เวลาเกินที่ Claude Code กำหนดต่อ hook หนึ่งตัว Claude Code จะข้าม hook นั้นและส่งข้อความไปตามเดิมโดยไม่ปกปิดและไม่มีการแจ้งเตือน (fail-open) ทั้งนี้ ข้อความที่ทำให้ตัวตรวจจับเองทำงานช้าจนเกิดกรณีนี้ยังอยู่ในขอบเขต (ดูด้านบน)
- ผลบวกลวง (false positive) คือข้อความทั่วไปถูกปกปิด ให้รายงานเป็น issue ปกติ
- วิศวกรรมสังคม (social engineering) ต่อผู้ดูแลหรือผู้ใช้
- การที่บทสนทนาซึ่งปกปิดข้อมูลแล้วถูกส่งออกไป มอดนี้ช่วยลดข้อมูลที่ถูกส่งออกไป แต่ไม่ได้ทำให้ Claude Code หยุดส่งบทสนทนา (ที่ปกปิดแล้ว) ไปยังผู้ให้บริการโมเดลที่ตั้งค่าไว้ (โดยค่าเริ่มต้นคือ Anthropic) มอดนี้แก้ไขเฉพาะสิ่งที่ Claude Code ส่งให้โมเดล ช่องทางอื่นเป็นช่องทางแยกต่างหาก ไม่อยู่ในขอบเขตของมอด และอาจได้รับค่าเดิม ได้แก่ Remote Control (ซึ่งส่งต่อผ่านบริการของ Anthropic ไปยัง claude.ai หรือแอป Claude) hook แบบคำสั่ง (command hook) ในการตั้งค่าของผู้ใช้ ระบบรวบรวม telemetry ที่องค์กรตั้งค่าไว้ และรายงานที่ผู้ใช้ส่งให้ Anthropic เนื้อหาที่ตัวป้องกันไม่ได้แก้ไข (ภาพและเอกสาร กระบวนการคิดของโมเดล ค่าที่ Claude ส่งให้เครื่องมือ ประวัติที่เปิดต่อและทรานสคริปต์ของ subagent ที่บันทึกไว้แล้ว และค่าที่แบ่งส่งในหลายข้อความ ดู[ข้อจำกัดที่ทราบ](docs/DETECTION.md#ข้อจำกัดที่ทราบ)) จะถูกส่งไปตามเดิม การตรวจจับไม่รับประกันผล (best effort) และไม่ใช่ด่านป้องกันด้านความปลอดภัยที่เชื่อถือได้ (security boundary)
- ช่องโหว่ใน Claude Code เองหรือในบริการของ Anthropic ให้รายงานต่อ Anthropic ตาม Responsible Disclosure Policy ที่ <https://www.anthropic.com/responsible-disclosure-policy>
- คำถามว่าการใช้งานเป็นไปตามพระราชบัญญัติคุ้มครองข้อมูลส่วนบุคคล พ.ศ. 2562 หรือไม่ (ตัวบทที่ PDPC เผยแพร่: <https://www.pdpc.or.th/wp-content/uploads/2023/12/1_Personal-Data-Protection-2562.pdf> ตรวจสอบเมื่อ 4 ตุลาคม 2569 แหล่งข้อมูลอื่นดูที่หัวข้อ[แหล่งข้อมูลและการตรวจสอบ](docs/PDPA.md#แหล่งข้อมูลและการตรวจสอบ)) เอกสารนี้ไม่ใช่คำแนะนำทางกฎหมาย ให้ปรึกษาทนายความที่มีคุณสมบัติเหมาะสม หรือเจ้าหน้าที่คุ้มครองข้อมูลส่วนบุคคล (DPO) ขององค์กร และสอบถามการตีความอย่างเป็นทางการจาก PDPC ที่ <https://www.pdpc.or.th/> หรือช่องทางสอบถามข้อกฎหมายที่ <https://consult.pdpc.or.th/> (ตรวจสอบเมื่อ 4 ตุลาคม 2569)

### การเปิดเผยข้อมูลอย่างประสานงาน (coordinated disclosure)

ขอให้ผู้รายงานไม่เปิดเผยรายละเอียดต่อสาธารณะจนกว่าจะมีเวอร์ชันที่แก้ไขแล้ว หรือจนถึงวันที่ตกลงร่วมกัน เมื่อแก้ไขแล้ว ผู้ดูแลจะเผยแพร่ GitHub security advisory บันทึกการแก้ไขใน [CHANGELOG.md](CHANGELOG.md) และระบุชื่อผู้รายงานเป็นเครดิต เว้นแต่ผู้รายงานไม่ประสงค์ให้ระบุชื่อ

โครงการนี้ไม่มีรางวัลสำหรับการค้นพบช่องโหว่ (bug bounty)

### การวิจัยโดยสุจริต

ผู้ดูแลจะไม่ดำเนินการหรือสนับสนุนการดำเนินการทางกฎหมายต่อการวิจัยที่ทำโดยสุจริตและเป็นไปตามนโยบายนี้ ซึ่งหมายถึงผู้วิจัย

- ทดสอบบนเครื่อง บัญชี และข้อมูลของตนเอง โดยใช้ข้อมูลสมมติ
- ไม่เข้าถึง เก็บ หรือเปิดเผยข้อมูลของผู้อื่น
- ไม่รบกวนบริการของผู้อื่น รวมถึงบริการของ Anthropic และ GitHub
- รายงานผ่านช่องทางส่วนตัว และให้เวลาแก้ไขตามหัวข้อการเปิดเผยข้อมูลอย่างประสานงาน

คำยืนยันนี้เป็นคำมั่นของผู้ดูแลโครงการ ไม่ใช่ความคุ้มกันทางกฎหมาย ผูกพันเฉพาะผู้ดูแลโครงการ และไม่ครอบคลุมถึง Anthropic GitHub หรือบุคคลที่สาม

---

<a id="en"></a>

## English

[ไทย](#th) · **English**

boombignose-mods is an unofficial community project maintained by one individual in their spare time. It is not affiliated with, endorsed by or certified by Anthropic, the Personal Data Protection Committee Office (PDPC), the Electronic Transactions Development Agency (ETDA), the Digital Government Development Agency (DGA), the Ministry of Digital Economy and Society (MDES), or any Thai government body.

### Supported versions

Security fixes ship in the latest release of each mod only. Nothing is backported.

| Mod | Receives fixes | Other versions |
| --- | --- | --- |
| `pdpa-thai` | 0.3.x | not supported |
| `context-bar` | 0.4.x | not supported |
| `agents-panel` | 0.1.x | not supported |
| `boom-big-nose-workflow` | 0.5.x | not supported |
| `pdpa-blur` (merged into `pdpa-thai` in 0.2.0) | none | move to `pdpa-thai` |

To get a fix: `claude plugin marketplace update boombignose-mods`, then `claude plugin update pdpa-thai@boombignose-mods` (same for the other mods), then restart Claude Code.

All mods need a Claude Code build that supports hook-module plugins. They are tested only with Claude Code 2.1.289.

The API type declarations that Claude Code writes beside a mod it loads from a folder (`.claude-plugin/types/claude-code/index.d.ts`) mark the hook-module API as early access: it may change between releases without notice, so an older or newer build may skip some or all of the guard without warning, or pass text through a path the guard does not hook. CI installs the latest Claude Code from npm and runs the manifest checks and the mods' unit tests with it (details in [What CI runs](CONTRIBUTING.md#what-ci-runs)). That catches API changes the tests cover, but the CI badge shows only that the unit tests pass on the latest build; it does not show that a newer build still routes every message through the hooks the guard uses. The tested version remains 2.1.289.

### Reporting a vulnerability

**Do not open a public issue that describes a vulnerability.**

1. If the repository's **Security** tab shows **Report a vulnerability**, choose it. This opens a private security advisory that only you, the maintainer and anyone the maintainer adds to the advisory can see. Direct link: <https://github.com/Boom-Vitt/boombignose-mods/security/advisories/new>
2. If that option is not shown, private reporting is switched off. Open an issue with the **Feature request** form, titled "Request private security contact". In the first field write only "Requesting a private contact for a security report", and leave the other field empty. Include no details at all: no mod, no data type, no steps. The maintainer will switch private reporting on, reply in that issue with the link, and then close the issue. No email address is given out.

A useful report has:

- the mod and its version (`claude plugin list`, or the mod's `.claude-plugin/plugin.json`), the Claude Code version (`claude --version`) and your OS
- for `pdpa-thai`, whether the status line showed `PDPA: redact` or `PDPA: block`; if it did not, the mod did not load and nothing was redacted (run `claude --debug` to see why)
- steps to reproduce, with expected and actual results
- the impact: which kind of data gets out, and where it ends up
- sample data that is fake (see the next section)

### Never include real personal data

Do not put real personal data, yours or anyone else's, in a report, issue, pull request, screenshot or log. Build a fake sample that reproduces the same behaviour, or describe the format in words, for example "a 10-digit mobile number written in Thai digits". If you sent real data by mistake, tell the maintainer through the private channel above so the maintainer can try to remove it; edit history, forks and copies already made may keep it.

### What to expect

This is a volunteer project. The maintainer aims to acknowledge a report within 7 days, on a best-effort basis. There is no service-level agreement: no promised time to a fix or a release. After acknowledging, the maintainer checks whether the issue reproduces, posts progress in the same advisory, and tells you when a fixed release is out.

### Scope

In scope:

- a technique that reliably slips a value past the guard when [docs/DETECTION.en.md](docs/DETECTION.en.md) says its format is covered (for example an encoding or formatting trick not listed in the known limits). A single missed sample is a normal bug: open a Bug report with a fake sample.
- a way to make the guard itself copy an original value it detected into a log, plugin state, or text it rewrote in the transcript
- input that makes the detector hang or run for an unreasonable time (ReDoS or similar). This is a bypass, not only a slowdown: Claude Code skips a hook that runs past its per-hook time limit and sends the text unchanged, with no notice (fail-open).
- a mod that calls the network, a process, a model or MCP in a way its README does not document. The documented cases are the `agents-panel` ▶ run button, which asks Claude Code to start a subagent when you press it; that subagent's conversation goes to your configured model provider (Anthropic by default) like any agent's, and `boom-big-nose-workflow`, which runs its own scripts, starts subagents and uses the Context7 and Perplexity MCP servers as the README describes, and whose `bbn-codex.sh` runs your Codex CLI, which calls OpenAI with your own login. `pdpa-thai` and `context-bar` make no such calls.
- supply-chain issues in CI, such as `.github/workflows/` or `.github/dependabot.yml`

Out of scope:

- patterns and cases listed as not covered in the README's [Limits](README.en.md#limits) section or in the [known limits](docs/DETECTION.en.md#known-limits) of docs/DETECTION.en.md (the two lists are the same), for example:
  - Claude Code keeps structured tool results and attachment payloads (such as files mentioned with `@`) in their original form, so they stay unredacted in the stored transcript, and tool-result display is not masked.
  - Claude Code's own prompt history (up-arrow recall) is outside the mod's control and may keep what you typed, unredacted, on your machine.
  - The system prompt (environment details, MCP server instructions and sections other plugins add) and tool and skill descriptions are not inspected.
  - Hooks of other plugins that run before this mod's may see the original text.
  - If one of the mod's hooks throws an error or runs past Claude Code's per-hook time limit, Claude Code skips it and sends the text unchanged, with no notice (fail-open). Input that makes the detector itself slow enough to cause this is in scope (see above).
- false positives, where harmless text is redacted; open a normal issue
- social engineering of the maintainer or of users
- the redacted conversation being sent out. The guard reduces what is sent. It does not stop Claude Code from sending the (redacted) conversation to your configured model provider (Anthropic by default). The guard rewrites only what Claude Code sends to the model. Other channels are separate, are not covered and may receive original values: Remote Control (relayed through Anthropic's service to claude.ai or the Claude app), command hooks in your settings, a telemetry collector your organisation configured, and reports you send to Anthropic. Content the guard does not rewrite (images and documents, model thinking, tool_use inputs, resumed history and saved subagent transcripts, a value split across several messages; see the [known limits](docs/DETECTION.en.md#known-limits)) is sent as it is. Detection is best effort and is not a security boundary.
- vulnerabilities in Claude Code itself or in Anthropic's service; report those to Anthropic under its Responsible Disclosure Policy: <https://www.anthropic.com/responsible-disclosure-policy>
- whether a given use complies with the Personal Data Protection Act B.E. 2562 (2019) (PDPC-hosted text: <https://www.pdpc.or.th/wp-content/uploads/2023/12/1_Personal-Data-Protection-2562.pdf>, checked 2026-10-04; more sources in [Sources and verification](docs/PDPA.en.md#sources-and-verification)). This document is not legal advice. Ask a qualified lawyer or your organisation's data protection officer (DPO); for an official interpretation ask the PDPC: <https://www.pdpc.or.th/>, legal Q&A <https://consult.pdpc.or.th/> (checked 2026-10-04).

### Coordinated disclosure

Please keep the details private until a fixed release is out, or until a date we agree on. Once fixed, the maintainer publishes a GitHub security advisory, notes the fix in [CHANGELOG.md](CHANGELOG.md), and credits you unless you prefer not to be named.

There is no bug bounty.

### Good-faith research

The maintainer will not pursue or support legal action against security research done in good faith under this policy, meaning you:

- test on your own machine, accounts and data, using fake values
- do not access, keep or disclose anyone else's data
- do not disrupt other people's services, including Anthropic's and GitHub's
- report through the private channel and allow time for a fix as described above

This is a promise by the maintainer, not legal immunity. It binds the maintainer only and does not cover Anthropic, GitHub or any third party.
