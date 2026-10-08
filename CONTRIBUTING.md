# การร่วมพัฒนา / Contributing

**ไทย** · [English](#en)

<a id="th"></a>

## ภาษาไทย

ขอบคุณที่สนใจร่วมพัฒนา boombignose-mods โครงการนี้เป็นโครงการชุมชนที่ไม่เป็นทางการ ดูแลโดยบุคคลคนเดียว ไม่มีความเกี่ยวข้องกับ Anthropic, สำนักงานคณะกรรมการคุ้มครองข้อมูลส่วนบุคคล (PDPC), สำนักงานพัฒนาธุรกรรมทางอิเล็กทรอนิกส์ (ETDA), สำนักงานพัฒนารัฐบาลดิจิทัล (DGA), กระทรวงดิจิทัลเพื่อเศรษฐกิจและสังคม (MDES) หรือหน่วยงานของรัฐใด ๆ ของไทย และไม่ได้รับการสนับสนุนหรือการรับรองจากองค์กรหรือหน่วยงานเหล่านี้ ทุกคนที่มีส่วนร่วมในโครงการต้องปฏิบัติตาม[จรรยาบรรณ](CODE_OF_CONDUCT.md) หากพบช่องโหว่ ให้รายงานตาม [SECURITY.md](SECURITY.md) โดยห้ามรายงานผ่าน issue สาธารณะ

### กฎเหล็ก: ห้ามใช้ข้อมูลส่วนบุคคลจริง

`pdpa-thai` เป็นเครื่องมือตรวจจับข้อมูลส่วนบุคคล (PII) จึงต้องไม่มีข้อมูลส่วนบุคคลจริงอยู่ใน repository นี้เลย

- ห้าม commit ข้อมูลส่วนบุคคลจริงของผู้ใด รวมถึงของตนเอง ไม่ว่าจะอยู่ในโค้ด เทสต์ เอกสาร ภาพหน้าจอ หรือข้อความ commit
- ให้ commit ด้วยอีเมล noreply ของ GitHub โดยคัดลอกที่อยู่ `…@users.noreply.github.com` จาก Settings > Emails มาตั้งด้วย `git config user.email` และเปิด Keep my email addresses private กับ Block command line pushes that expose my email เพราะชื่อและอีเมลผู้เขียน commit จะถูกเผยแพร่พร้อม repository หากไม่ต้องการเผยแพร่ชื่อจริง ให้ตั้ง `git config user.name` เป็นชื่อผู้ใช้ GitHub
- ใช้ค่าสมมติเท่านั้น ประกอบค่าตัวอย่างในเทสต์จากชิ้นส่วนที่นำมาต่อกันขณะรัน (ดูฟังก์ชัน `j(...)` ใน `pdpa-thai/tests/detect.test.ts`) เพื่อลดโอกาสที่เครื่องมือสแกนความลับจะตรวจพบไฟล์ และเลือกค่าที่เห็นได้ชัดว่าเป็นค่าสมมติเมื่อทำได้ เช่น เลขเรียงลำดับที่คำนวณหลักตรวจสอบ (check digit) ให้ผ่าน หมายเลขบัตรสำหรับทดสอบที่ผู้ให้บริการรับชำระเงินเผยแพร่ในเอกสารสำหรับนักพัฒนา โดเมนที่สงวนไว้สำหรับทดสอบ เช่น `.test` และช่วงหมายเลข IP สำหรับเอกสาร (RFC 5737) ค่าตัวอย่างหลายค่าต้องมีรูปแบบที่ถูกต้องเพื่อให้กฎตรวจพบ จึงอาจดูเหมือนข้อมูลจริงได้ ด้วยเหตุนี้จึงห้ามนำค่าตัวอย่างมาจากบุคคลจริง
- กฎ EMAIL จงใจข้ามโดเมน `example.com` `example.org` และ `example.net` จึงใช้โดเมนเหล่านี้เป็นตัวอย่างในกรณีที่ต้องตรวจพบ (positive) ไม่ได้ เฉพาะโดเมนเหล่านี้เท่านั้นที่ถูกข้าม โดเมนย่อย เช่น `mail.example.com` ยังถูกตรวจพบ
- ห้ามแปะข้อมูลจริงลงใน issue หรือ pull request หากข้อมูลจริงทำให้เกิดบั๊ก ให้สร้างค่าสมมติที่ให้ผลแบบเดียวกัน หรืออธิบายรูปแบบเป็นคำพูด เช่น "เลขประจำตัวประชาชน 13 หลัก คั่นด้วยขีดเป็นกลุ่ม 1-4-5-2-1"
- หากเผลอ commit หรือโพสต์ข้อมูลจริง การแก้ด้วย commit ใหม่เพียงอย่างเดียวไม่พอ เพราะข้อมูลยังอยู่ในประวัติ ให้แจ้งผู้ดูแลผ่านช่องทางส่วนตัวใน [SECURITY.md](SECURITY.md) เพื่อลบออกจาก repository และประวัติเท่าที่ทำได้ สำเนาที่ถูก clone fork หรือแคชไปแล้วไม่สามารถเรียกคืนได้

### การเสนอการเปลี่ยนแปลง

- การแก้ไขเล็กน้อย เช่น คำผิด ลิงก์เสีย หรือบั๊กที่ชัดเจน ส่ง pull request ได้ทันที
- การเปลี่ยนกฎตรวจจับ (เพิ่มชนิดข้อมูล หรือเปลี่ยนสิ่งที่กฎตรวจจับหรือไม่ตรวจจับ) การเปลี่ยนพฤติกรรมของโหมด `/pdpa-guard` และการเพิ่มมอด (mod) ใหม่ **ให้เปิด issue ก่อน** ด้วยแบบฟอร์ม Feature request โดยระบุรูปแบบข้อมูลเป็นคำพูดหรือด้วยตัวอย่างสมมติ วิธีตรวจความถูกต้อง (ถ้ามี) และแหล่งอ้างอิง เพื่อตกลงแนวทางก่อนเขียนโค้ด

เมื่อเพิ่มมอดใหม่ ต้องเพิ่มรายการใน `.claude-plugin/marketplace.json` เพิ่มชื่อมอดในลูป validate (และลูป test หากมีเทสต์) ใน `.github/workflows/test.yml` เพิ่มแถวใน README ทั้งสองภาษา เพิ่มแถวในตารางเวอร์ชันที่ยังได้รับการแก้ไขของ [SECURITY.md](SECURITY.md) ทั้งสองภาษา เพิ่มชื่อในรายการมอดของ `.github/ISSUE_TEMPLATE/bug_report.yml` และเพิ่มบรรทัดใน [CHANGELOG.md](CHANGELOG.md)

### การเตรียมเครื่องสำหรับพัฒนา

ต้องมี Claude Code เวอร์ชันที่รองรับปลั๊กอินแบบ hook module (ทดสอบแล้วกับเวอร์ชัน 2.1.289 เท่านั้น) แต่ละมอดคือปลั๊กอินที่ไฟล์ `hooks/hooks.json` ระบุโมดูล TypeScript (`hooks/register.tsx`) ซึ่งผูกกับเหตุการณ์ (event) ของ Claude Code

```bash
git clone https://github.com/Boom-Vitt/boombignose-mods.git
cd boombignose-mods

# ตรวจ manifest ของ marketplace และของมอด
claude plugin validate .
claude plugin validate pdpa-thai

# รันเทสต์ของมอด (ไฟล์ *.test.ts และ *.test.tsx ทุกไฟล์ในโฟลเดอร์ของมอด โครงการนี้เก็บไว้ใน tests/)
claude plugin test pdpa-thai
claude plugin test context-bar

# ลองใช้มอดจากโฟลเดอร์ในเครื่อง เฉพาะเซสชัน (session) นี้
claude --plugin-dir ./pdpa-thai
```

ในเซสชันแบบโต้ตอบ (interactive) Claude Code จะเฝ้าดูโฟลเดอร์ที่ส่งผ่าน `--plugin-dir` และโหลดโมดูลซ้ำ (reload) ทุกครั้งที่บันทึกไฟล์

การตรวจชนิด (type check) ไม่บังคับและไม่ได้รันใน CI เมื่อ Claude Code โหลดมอดจากโฟลเดอร์ในเครื่อง จะเขียนไฟล์ type ของ API ไว้ที่ `<mod>/.claude-plugin/types/` และไฟล์ `<mod>/tsconfig.json` ที่ extends `./.claude-plugin/types/tsconfig.json` (ทั้งสองอยู่ใน `.gitignore`) จากนั้นตรวจด้วย TypeScript 5.4 ขึ้นไป

```bash
npx -p typescript tsc -p pdpa-thai
```

หากไม่มี `tsconfig.json` ให้สร้างเองโดยมีเนื้อหา `{ "extends": "./.claude-plugin/types/tsconfig.json" }`

หมายเหตุ: หากเปิดใช้ `pdpa-thai` ในเซสชันที่ใช้พัฒนา ตัวป้องกัน (guard) จะปกปิดค่าตัวอย่างในไฟล์เทสต์ก่อนส่งให้ Claude ด้วย และจะปฏิเสธการเรียกเครื่องมือ (tool call) ที่มีป้ายแทนค่า (placeholder) ซึ่งเซสชันนั้นออกให้ ทั้งนี้เป็นพฤติกรรมที่ออกแบบไว้ หากต้องการให้ Claude อ่านหรือแก้ค่าตัวอย่างในเทสต์ ให้สั่ง `/pdpa-guard off` ในเซสชันนั้น (หรือพัฒนาในเซสชันที่ไม่ได้เปิดมอดนี้) แล้วเปิดกลับด้วย `/pdpa-guard redact` เมื่อเสร็จ

### สิ่งที่ CI ตรวจ

[`.github/workflows/test.yml`](.github/workflows/test.yml) รันทุกครั้งที่มี push และ pull request โดยติดตั้ง Claude Code เวอร์ชันล่าสุดจาก npm แล้วทำขั้นตอนต่อไปนี้

1. `claude plugin validate .` และ `claude plugin validate <mod>` สำหรับมอดทุกตัวที่ระบุในลูปของ workflow
2. `claude plugin test` สำหรับ `context-bar` และ `pdpa-thai`
3. ค้นข้อความ (grep) ในไฟล์ `.ts` และ `.tsx` ใต้โฟลเดอร์ `hooks/` ของทุกมอด และให้ CI ล้มเหลวหากพบ `$.http` `$.process` `$.model` `$.mcp` หรือ `fetch(`
4. เฉพาะ `pdpa-thai`: นำบรรทัด `calls:` ที่คำสั่ง `claude plugin validate pdpa-thai` แสดง (ผลการวิเคราะห์ของ Claude Code เองว่าโมดูลเรียก engine ใดบ้าง) มาตรวจกับรายการที่อนุญาต (allowlist) และให้ CI ล้มเหลวหากมีการเรียกที่ไม่อยู่ใต้ `$.state` `$.ui` `$.clock` หรือ `$.command` รวมถึงล้มเหลวหากไม่พบบรรทัดนี้ (fail closed)
5. ตรวจว่าไฟล์ JSON manifest ทุกไฟล์อ่านได้ถูกต้อง

ก่อนส่ง pull request ให้รันข้อ 1 และ 2 ในเครื่องให้ผ่าน

CI ใช้ Claude Code เวอร์ชันล่าสุดเสมอ ส่วนเวอร์ชันที่ทดสอบแล้วคือ 2.1.289 ป้ายสถานะ (badge) ของ CI จึงแสดงเพียงว่า manifest ผ่านการตรวจและเทสต์หน่วย (unit test) ผ่านบนเวอร์ชันล่าสุด ไม่ได้แสดงว่าตัวป้องกันยังดักข้อความได้ทุกเส้นทางบนเวอร์ชันนั้น

### ห้ามมอดเรียกเครือข่าย โปรเซส โมเดล หรือ MCP ด้วยตนเอง

โค้ดของมอดต้องไม่เรียกเครือข่าย โปรเซสภายนอก โมเดล หรือเซิร์ฟเวอร์ MCP ด้วยตนเอง ข้อยกเว้นเดียวที่ระบุไว้คือปุ่ม ▶ run ของ `agents-panel` ซึ่งเรียก `$.agent.spawn` เพื่อเริ่ม subagent เมื่อผู้ใช้กดปุ่มเท่านั้น และ subagent นั้นส่งบทสนทนาไปยังผู้ให้บริการโมเดลที่ตั้งค่าไว้ (โดยค่าเริ่มต้นคือ Anthropic) เช่นเดียวกับ agent อื่น ข้อยกเว้นใหม่ต้องเปิด issue ก่อน และต้องระบุใน README ทั้งสองภาษา และในรายการที่อยู่ในขอบเขตของ [SECURITY.md](SECURITY.md) ทั้งสองภาษา

การตรวจทั้งสองแบบ (ข้อ 3 และ 4) เป็นการอ่านซอร์สแบบคงที่ (static) และไม่ใช่การพิสูจน์

- grep (ข้อ 3) อ่านเฉพาะไฟล์ `.ts` และ `.tsx` ในโฟลเดอร์ `hooks/` ของแต่ละมอด และตรวจหาเฉพาะข้อความ `$.http` `$.process` `$.model` `$.mcp` และ `fetch(` ตามตัวอักษร จึงไม่ครอบคลุมการเรียก engine อื่นที่เข้าถึงเครือข่าย โมเดล หรือ agent อื่น หรือมีผลนอกมอด ได้แก่ `$.agent` (`spawn`) `$.tool` (ซึ่งเรียก Bash, WebFetch หรือเครื่องมือ MCP ได้) `$.prompt` (`submit` เริ่มรอบการทำงานของโมเดล) `$.session` (`compact` เรียกโมเดล `send` ส่งข้อความถึง agent หรือเซสชันอื่น และ `usage({ breakdown: 'full' })` ส่งคำขอนับโทเค็น) `$.audio` (`play` อาจดึงไฟล์จาก URL) `$.telemetry` (ส่งบันทึกถึง Anthropic หรือถึงระบบเก็บข้อมูลที่ผู้ดูแลเซสชันตั้งค่าไว้) `$.fs.write` และ `$.config.set` และไม่ครอบคลุมโค้ดในไฟล์ `.js` `.mjs` `.cjs` `.jsx` `.mts` หรือ `.cts`
- allowlist (ข้อ 4) ไม่ขึ้นกับการสะกดตามตัวอักษร จึงจับการเรียกข้างต้นทั้งหมดได้หาก `pdpa-thai` เรียกโดยตรง และใน Claude Code 2.1.289 คำสั่ง `claude plugin validate` (ข้อ 1) จะไม่ผ่านหากโมดูลผูก `$` กับชื่อตัวแปร (เช่น `const { http } = $`) อ่านสมาชิกของ `$` ด้วยชื่อที่คำนวณขึ้น (เช่น `$['http']`) หรือนำเข้าสิ่งอื่นนอกจากไฟล์ของมอดเองและ `claude-code` แต่ allowlist ก็ยังเป็นการอ่านซอร์ส โค้ดที่จงใจซ่อนการเรียก เช่น เข้าถึงตัวแปรส่วนกลาง (global) ด้วยชื่อที่ประกอบขึ้นขณะรัน อาจผ่านการตรวจทั้งสองแบบได้
- allowlist ครอบคลุมเฉพาะ `pdpa-thai` สำหรับ `context-bar` และ `agents-panel` ผู้ตรวจ (reviewer) ต้องเทียบบรรทัด `calls:` ของ `claude plugin validate <mod>` กับรายการข้างต้นเอง
- การตรวจทั้งสองแบบไม่ได้บอกอะไรเกี่ยวกับสิ่งที่ Claude Code ส่งออกไปเอง และไม่แทนการอ่านโค้ด ห้ามเขียนโค้ดเพื่อเลี่ยงการตรวจเหล่านี้ เช่น ตั้งชื่อตัวแปร `$` ใหม่ หรือเข้าถึงด้วยชื่อที่ประกอบขึ้นขณะรัน

### การเพิ่มหรือแก้ไขกฎตรวจจับ

กฎทั้งหมดอยู่ในอาร์เรย์ `RULES` ใน `pdpa-thai/hooks/detect.ts`

1. เปิด issue ก่อน (ดูหัวข้อการเสนอการเปลี่ยนแปลง)
2. แก้ `pdpa-thai/hooks/detect.ts` ชนิดข้อมูลใหม่ต้องเพิ่มใน type `Kind` ด้วย กฎทำงานบนสำเนาของข้อความที่แปลงเลขไทยเป็นเลขอารบิกและแปลงช่องว่างพิเศษเป็นช่องว่างปกติแล้ว โดยความยาวเท่าเดิม ตำแหน่ง (offset) จึงตรงกับข้อความต้นฉบับ ห้ามแก้การแปลงนี้ให้ความยาวเปลี่ยน
3. เพิ่มเทสต์ใน `pdpa-thai/tests/detect.test.ts` ทั้งสองด้าน
   - กรณีที่ต้องตรวจพบ (positive) รวมรูปแบบย่อย เช่น เลขไทยและตัวคั่นแบบต่าง ๆ
   - กรณีที่ต้องไม่ถูกตรวจพบ (negative) เช่น ตัวเลขที่ checksum ไม่ผ่าน ชื่อตัวแปรในโค้ด หรือคำประสมภาษาไทยที่ขึ้นต้นเหมือนคำนำหน้าชื่อ
4. กฎต้องทำงานในเวลาเชิงเส้น (linear time) เพราะกฎรันกับทุกพรอมต์ ผลลัพธ์ของเครื่องมือ ไฟล์แนบ และ context block และ Claude Code จะข้าม hook ที่ทำงานเกินเวลาที่กำหนดต่อ hook แล้วส่งข้อความไปตามเดิมโดยไม่แจ้งเตือน (fail-open) ข้อความที่ทำให้กฎทำงานช้าจึงเป็นช่องทางหลบเลี่ยงตัวป้องกัน ไม่ใช่เพียงความล่าช้า หลีกเลี่ยง quantifier ซ้อนกันและทางเลือกที่ทับซ้อนจนเกิดการย้อนรอย (backtracking) และจำกัดความยาวด้วย `{m,n}` เมื่อรูปแบบข้อมูลมีความยาวสูงสุดตามธรรมชาติ ส่วนค่าที่มีป้ายกำกับ (label) จงใจไม่จำกัดความยาว (ดูเทสต์ "no length cap") ค่าจึงต้องเริ่มด้วยอักขระที่ไม่ใช่ช่องว่าง เช่นเดียวกับ `VALUE` ใน `detect.ts` หากช่องว่างหลังป้ายกำกับนับเป็นส่วนของตัวคั่นหรือของค่าก็ได้ ช่องว่างที่ยาวมากจะทำให้การจับคู่ใช้เวลาแบบกำลังสอง (quadratic) หากนิพจน์ปรกติ (regular expression) ใดมีความเสี่ยง ให้เขียนเป็นการสแกนแบบฟังก์ชัน `emails()` แทน และเพิ่มกรณีข้อมูลนำเข้าที่จงใจสร้างให้ทำงานช้า (hostile input) ของกฎนั้นในเทสต์ "size and time" หรือในเทสต์ "blank runs after a label" สำหรับกฎที่มีป้ายกำกับ
5. ลดผลบวกลวง (false positive) ให้เหลือน้อย ใช้การตรวจความถูกต้องเมื่อรูปแบบข้อมูลนั้นมีวิธีตรวจ (เช่น mod-11 ของเลขประจำตัวประชาชน และ Luhn ของบัตร) และสำหรับค่าที่มีรูปแบบเหมือนตัวเลขทั่วไป ให้ตรวจจับเฉพาะเมื่อมีป้ายกำกับนำหน้า เช่นเดียวกับ `PASSPORT` `BANK_ACCOUNT` และ `DOB`
6. อัปเดต [docs/DETECTION.md](docs/DETECTION.md) และ [docs/DETECTION.en.md](docs/DETECTION.en.md) ให้ตรงกัน ระบุสิ่งที่ตรวจจับ สิ่งที่ไม่ตรวจจับ และข้อจำกัดที่ทราบ โดยอธิบายรูปแบบเป็นคำพูด ไม่ใส่ตัวเลขที่ดูเหมือนค่าจริง
7. หากกฎอ้างอิงกฎหมาย ให้ใส่ URL แหล่งที่มาและวันที่ตรวจสอบในคอมเมนต์ เช่นเดียวกับหัวไฟล์ `detect.ts`

### ป้ายแทนค่าและการแก้ตัวป้องกัน

ป้ายแทนค่าที่ตัวป้องกันเขียนแทนค่าเดิมมีรูปแบบ `[REDACTED:PHONE_1~k3x9q]` คือ ชนิดข้อมูล ลำดับ และรหัสประจำเซสชัน 5 อักขระ (ตัวอักษรและตัวเลข) ในโค้ดและเทสต์ ให้ประกอบคำนำหน้าของป้ายแทนค่าจากสองชิ้น เช่นเดียวกับค่าคงที่ `TAG` ใน `detect.ts` เพื่อไม่ให้มีป้ายแทนค่าสำเร็จรูปอยู่ในซอร์ส

การแก้ `pdpa-thai/hooks/register.tsx` ต้องเพิ่มหรือแก้เทสต์ใน `pdpa-thai/tests/guard.test.ts` หรือ `pdpa-thai/tests/blur.test.tsx` ค่าใหม่ใน `$.state` ต้องประกาศไว้ใต้ชื่อมอดใน `<mod>/types/index.d.ts` ด้วย คำสั่ง `claude plugin validate` ตรวจข้อนี้

### ข้อความเกี่ยวกับกฎหมายและหน่วยงานกำกับ

- ข้อเท็จจริงเกี่ยวกับกฎหมายไทย มาตรา มาตรฐาน ค่าธรรมเนียม หรือกำหนดเวลา ต้องมี URL แหล่งที่มาและวันที่ตรวจสอบเสมอ ห้ามคาดเดา หากไม่แน่ใจ ให้ระบุว่าเรื่องนั้นไม่ครอบคลุม และแนะนำให้สอบถาม PDPC ที่ <https://www.pdpc.or.th/> ให้ใช้แหล่งข้อมูลในหัวข้อ[แหล่งข้อมูลและการตรวจสอบ](docs/PDPA.md#แหล่งข้อมูลและการตรวจสอบ)ของ docs/PDPA.md ก่อน แหล่งใหม่ต้องมี URL และวันที่ตรวจสอบ
- ห้ามใช้ถ้อยคำที่สื่อว่าเป็นทางการหรือผ่านการรับรอง เช่น "รับรอง" "certified" "compliant" หรือ "ถูกต้องตาม PDPA" ให้ใช้ "ช่วยลดความเสี่ยง" แทน
- ห้ามใช้ตราครุฑหรือตราสัญลักษณ์ของหน่วยงานใด
- เอกสารของโครงการไม่ใช่คำแนะนำทางกฎหมาย

### เอกสารสองภาษา

แก้เอกสารภาษาไทยและภาษาอังกฤษไปพร้อมกัน (`README.md` กับ `README.en.md` และ `docs/*.md` กับ `docs/*.en.md`) สำหรับ `SECURITY.md` `CONTRIBUTING.md` และ `CODE_OF_CONDUCT.md` ซึ่งรวมสองภาษาไว้ในไฟล์เดียว ให้แก้ทั้งส่วนภาษาไทยและส่วนภาษาอังกฤษ ภาษาไทยใช้ภาษาเขียนที่เป็นทางการแต่อ่านง่าย ใช้เลขอารบิกทั้งหมดรวมถึงปี พ.ศ. (เช่น 2569) และวงเล็บศัพท์ภาษาอังกฤษเมื่อใช้ครั้งแรก

### ข้อความ commit

เขียนเป็นภาษาอังกฤษ บรรทัดแรกสั้น ขึ้นต้นด้วยคำกริยารูปคำสั่ง (imperative) เช่น `Add ...` หรือ `Fix ...` และไม่มีข้อมูลส่วนบุคคล

### การส่ง pull request

ทำตามเช็กลิสต์ใน [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md) ได้แก่ validate และเทสต์ผ่าน มอดไม่เรียกเครือข่าย โปรเซส โมเดล หรือ MCP ด้วยตนเอง (CI ตรวจบางส่วนตามหัวข้อสิ่งที่ CI ตรวจ ผู้ตรวจตรวจส่วนที่เหลือ) ข้อมูลตัวอย่างเป็นค่าสมมติทั้งหมดและไม่ได้นำมาจากบุคคลจริง เอกสารไทยและอังกฤษตรงกัน ข้อความด้านกฎหมายมีแหล่งที่มาและวันที่ตรวจสอบ และมีบรรทัดใน `CHANGELOG.md`

### การกำหนดเวอร์ชันและบันทึกการเปลี่ยนแปลง

แต่ละมอดมีเลขเวอร์ชันของตนเองตาม [Semantic Versioning](https://semver.org/) (SemVer) แก้บั๊กให้เพิ่มเลข patch และเพิ่มกฎหรือความสามารถใหม่ให้เพิ่มเลข minor ส่วนในช่วงเวอร์ชัน 0.x การเปลี่ยนแปลงที่ไม่เข้ากันกับเวอร์ชันเดิม (breaking change) ให้เพิ่มเลข minor เช่นกัน และระบุให้ชัดใน CHANGELOG

เมื่อเปลี่ยนเวอร์ชัน ให้แก้เลขเวอร์ชันทุกแห่งใน commit เดียวกัน ได้แก่ `<mod>/.claude-plugin/plugin.json` รายการของมอดนั้นใน `.claude-plugin/marketplace.json` คอลัมน์เวอร์ชันในตารางมอดของ `README.md` และ `README.en.md` และเลขเวอร์ชันที่ระบุใน `docs/*.md` (สำหรับ `pdpa-thai`) หากเลข minor เปลี่ยน ให้แก้ตารางเวอร์ชันที่ยังได้รับการแก้ไขใน [SECURITY.md](SECURITY.md) ทั้งสองภาษาด้วย แล้วเพิ่มบรรทัดใน [CHANGELOG.md](CHANGELOG.md) ใต้หัวข้อ `[Unreleased]` ทั้งภาษาไทยและอังกฤษ บันทึกการเปลี่ยนแปลงใช้รูปแบบที่อิงจาก Keep a Changelog โดยแต่ละการเผยแพร่มีหัวข้อเป็นวันที่ และมีหัวข้อย่อยแยกตามมอด เมื่อสร้างแท็กสำหรับการเผยแพร่ (release tag) คำสั่ง `claude plugin tag <mod>` จะตรวจว่าเลขเวอร์ชันใน plugin.json กับรายการใน marketplace ตรงกัน

### สัญญาอนุญาต

การร่วมพัฒนาทั้งหมดอยู่ภายใต้สัญญาอนุญาต MIT ตาม [LICENSE](LICENSE) การส่ง pull request ถือว่ายินยอมให้เผยแพร่ผลงานนั้นภายใต้สัญญาอนุญาตเดียวกัน

---

<a id="en"></a>

## English

[ไทย](#th) · **English**

Thanks for helping. boombignose-mods is an unofficial community project maintained by one individual. It is not affiliated with, endorsed by or certified by Anthropic, the Personal Data Protection Committee Office (PDPC), the Electronic Transactions Development Agency (ETDA), the Digital Government Development Agency (DGA), the Ministry of Digital Economy and Society (MDES) or any Thai government body. Everyone who takes part follows the [Code of Conduct](CODE_OF_CONDUCT.md). Report vulnerabilities as described in [SECURITY.md](SECURITY.md), never in a public issue.

### Hard rule: no real personal data

`pdpa-thai` is a PII detector. This repository must never contain real personal data.

- Never commit anyone's real personal data, including your own, in code, tests, docs, screenshots or commit messages.
- Commit with your GitHub noreply address: copy the `…@users.noreply.github.com` address from GitHub Settings > Emails, set it with `git config user.email`, and turn on "Keep my email addresses private" and "Block command line pushes that expose my email". A commit's author name and email are published with the repository. If you prefer not to publish your legal name, set `git config user.name` to your GitHub username.
- Use made-up values only. Assemble test samples from fragments joined at run time (see `j(...)` in `pdpa-thai/tests/detect.test.ts`) so that the file is less likely to trip secret scanners, and make them obviously fictional where you can: a sequential number with a computed check digit, a published test card number from a payment processor's developer documentation, a reserved test domain such as `.test`, documentation IP ranges (RFC 5737). Many samples need a valid format for a rule to match them, so they can still look realistic; that is why a sample must never come from a real person.
- The EMAIL rule deliberately skips `example.com`, `example.org` and `example.net`, so those domains cannot be used for a sample that must be detected. Only those exact domains are skipped; a subdomain such as `mail.example.com` is detected.
- Never paste real data into an issue or pull request. If real data triggered a bug, make a fake value that reproduces it, or describe the format in words, for example "a 13-digit national ID with dashes in 1-4-5-2-1 groups".
- If real data was committed or posted by mistake, a follow-up commit is not enough because it stays in history. Tell the maintainer through the private channel in [SECURITY.md](SECURITY.md) so the data can be removed from the repository and its history as far as possible. Copies already cloned, forked or cached cannot be recalled.

### Proposing a change

- Small fixes (typos, broken links, obvious bugs): open a pull request directly.
- Detection rule changes (a new kind of data, or a change to what a rule does or does not match), changes to `/pdpa-guard` mode behaviour, and new mods: **open an issue first** with the Feature request form. Describe the format in words or with fake samples, any validity check, and a source, so the approach is agreed before code is written.

A new mod also needs: an entry in `.claude-plugin/marketplace.json`, its name in the validate loop (and in the test loop if it has tests) in `.github/workflows/test.yml`, a row in both READMEs, a row in both supported-versions tables in [SECURITY.md](SECURITY.md), its name in the Mod dropdown of `.github/ISSUE_TEMPLATE/bug_report.yml`, and a [CHANGELOG.md](CHANGELOG.md) entry.

### Development setup

You need a Claude Code build that supports hook-module plugins (tested only with 2.1.289). Each mod is a plugin whose `hooks/hooks.json` lists a TypeScript module (`hooks/register.tsx`) that hooks Claude Code events.

```bash
git clone https://github.com/Boom-Vitt/boombignose-mods.git
cd boombignose-mods

# validate the marketplace and a mod
claude plugin validate .
claude plugin validate pdpa-thai

# run a mod's tests (every *.test.ts / *.test.tsx in the mod folder; this repo keeps them in tests/)
claude plugin test pdpa-thai
claude plugin test context-bar

# try a mod from your checkout, for this session only
claude --plugin-dir ./pdpa-thai
```

In an interactive session, Claude Code watches a `--plugin-dir` folder and reloads the module when you save a file.

Type checking is optional and not run in CI. When Claude Code loads a mod from a local folder, it writes the API types to `<mod>/.claude-plugin/types/` and a `<mod>/tsconfig.json` that extends `./.claude-plugin/types/tsconfig.json` (both are git-ignored). Then run TypeScript 5.4 or newer:

```bash
npx -p typescript tsc -p pdpa-thai
```

If `tsconfig.json` is missing, create it with `{ "extends": "./.claude-plugin/types/tsconfig.json" }`.

Note: if `pdpa-thai` is enabled in the session you develop in, it also redacts the fake samples in test files before Claude sees them, and refuses tool calls that contain a placeholder that session issued. That is intended. To have Claude read or edit test samples, run `/pdpa-guard off` in that session (or develop in a session without the mod), and turn it back on with `/pdpa-guard redact` when you are done.

### What CI runs

[`.github/workflows/test.yml`](.github/workflows/test.yml) runs on every push and pull request. It installs the latest Claude Code from npm, then runs:

1. `claude plugin validate .` and `claude plugin validate <mod>` for each mod listed in the workflow's loop
2. `claude plugin test` for `context-bar` and `pdpa-thai`
3. a text search (grep) that fails if any `.ts` or `.tsx` file under a mod's `hooks/` folder contains `$.http`, `$.process`, `$.model`, `$.mcp` or `fetch(`
4. for `pdpa-thai` only: an allowlist check on the `calls:` line that `claude plugin validate pdpa-thai` prints (Claude Code's own analysis of which engine calls the module makes). It fails unless every call is under `$.state`, `$.ui`, `$.clock` or `$.command`, and fails closed if the line is missing.
5. a parse check of every JSON manifest

Run steps 1 and 2 locally before you open a pull request.

CI always uses the latest Claude Code; the tested version is 2.1.289. A green CI badge therefore shows only that the manifests validate and the unit tests pass on the latest build, not that the guard still hooks every path on it.

### Mods make no network, process, model or MCP calls of their own

Mod code must not call the network, an external process, a model or an MCP server on its own. The one documented exception is the `agents-panel` ▶ run button: it calls `$.agent.spawn` to start a subagent, only when you press it, and that subagent sends its conversation to your configured model provider (Anthropic by default) like any agent. A new exception needs an issue first, a line in both READMEs, and an update to the in-scope list in both halves of [SECURITY.md](SECURITY.md).

Both checks (steps 3 and 4) read the source statically. Neither is a proof.

- The grep (step 3) reads only `.ts` and `.tsx` files in each mod's `hooks/` folder and matches only the literal text `$.http`, `$.process`, `$.model`, `$.mcp` and `fetch(`. It misses other engine calls that reach the network, the model or another agent, or act outside the mod: `$.agent` (`spawn`), `$.tool` (which can run Bash, WebFetch or MCP tools), `$.prompt` (`submit` starts a model turn), `$.session` (`compact` calls the model, `send` messages another agent or session, `usage({ breakdown: 'full' })` sends token-count requests), `$.audio` (`play` can fetch a URL), `$.telemetry` (records for Anthropic or for a collector the session's operator configured), `$.fs.write` and `$.config.set`. It also misses code in `.js`, `.mjs`, `.cjs`, `.jsx`, `.mts` or `.cts` files.
- The allowlist (step 4) does not depend on spelling, so it catches any of the calls above that `pdpa-thai` makes directly. In Claude Code 2.1.289, `claude plugin validate` (step 1) also fails if a module binds `$` to a name (`const { http } = $`), reads a member of `$` by a computed name (`$['http']`), or imports anything other than the mod's own files and `claude-code`. The allowlist is still a reading of the source: code written to hide a call, for example by reaching a global through a name built at run time, can pass both checks.
- The allowlist covers `pdpa-thai` only. For `context-bar` and `agents-panel`, reviewers compare the `calls:` line of `claude plugin validate <mod>` with the list above by hand.
- Neither check says anything about what Claude Code itself sends, and neither replaces reading the code. Do not write code to route around them, for example by renaming `$` or building a property name at run time.

### Adding or changing a detection rule

All rules live in the `RULES` array in `pdpa-thai/hooks/detect.ts`.

1. Open an issue first (see Proposing a change).
2. Edit `pdpa-thai/hooks/detect.ts`. A new kind of data also goes into the `Kind` type. Rules run on a copy of the text in which Thai digits become Arabic digits and unusual spaces become plain spaces, with the length unchanged, so offsets still index the original. Do not change that normalisation in a way that changes the length.
3. Add tests to `pdpa-thai/tests/detect.test.ts`, both ways:
   - positive: text that must be detected, including variants such as Thai digits and different separators
   - negative: text that must be left alone, such as numbers with a bad checksum, identifiers in code, or Thai compound words that start like a title
4. Keep it linear-time. The rules run on every prompt, tool result, attachment and context block, and Claude Code skips a hook that runs past its per-hook time limit and sends the text unchanged, with no notice (fail-open). Slow input is therefore a bypass, not only a slowdown. Avoid nested quantifiers and overlapping alternatives that backtrack, and bound repetition with `{m,n}` where the format has a natural maximum. Labelled values are deliberately uncapped (see the "no length cap" test), so a value must start with a non-blank character, as `VALUE` in `detect.ts` does: if the blanks after a label could belong to either the separator or the value, a long run of them makes the match quadratic. If a regex is risky, write a scan like `emails()` instead. Add a hostile-input case for the rule to the "size and time" test, or to the "blank runs after a label" test for a labelled rule.
5. Keep false positives low. Use the format's validity check where it has one (mod-11 for the national ID, Luhn for cards). For values that look like ordinary numbers, match only after a label, as `PASSPORT`, `BANK_ACCOUNT` and `DOB` do.
6. Update [docs/DETECTION.md](docs/DETECTION.md) and [docs/DETECTION.en.md](docs/DETECTION.en.md) together: what is matched, what is not, and known limits. Describe formats in words, never with a number that looks real.
7. If a rule refers to the law, put the source URL and a checked date in a comment, as the header of `detect.ts` does.

### Placeholders and guard changes

The placeholder the guard writes in place of a value looks like `[REDACTED:PHONE_1~k3x9q]`: kind, number, and a 5-character per-session suffix (letters and digits). In code and tests, assemble the placeholder's prefix word from two fragments, as the `TAG` constant in `detect.ts` does, so the source never holds a ready-made placeholder.

Changes to `pdpa-thai/hooks/register.tsx` need a new or updated test in `pdpa-thai/tests/guard.test.ts` or `pdpa-thai/tests/blur.test.tsx`. A new `$.state` value must also be declared under the mod's name in `<mod>/types/index.d.ts`; `claude plugin validate` checks this.

### Statements about law and regulators

- Any fact about Thai law, a section number, a standard, a fee or a deadline needs a source URL and a checked date. Never guess. If unsure, say the point is not covered and point to the PDPC: <https://www.pdpc.or.th/>. Reuse the sources in the [Sources and verification](docs/PDPA.en.md#sources-and-verification) section of docs/PDPA.en.md; a new source needs its URL and the date you checked it.
- Do not use wording that suggests official status or certification, such as "certified", "compliant", "รับรอง" or "ถูกต้องตาม PDPA". Use "designed to help reduce" instead.
- Do not use the Garuda emblem or any agency's logo.
- Nothing in this project is legal advice.

### Docs in both languages

Update Thai and English docs together (`README.md` with `README.en.md`, `docs/*.md` with `docs/*.en.md`). In `SECURITY.md`, `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md`, which hold both languages in one file, update both halves. Thai text uses formal, readable written Thai with Arabic digits everywhere, including Buddhist-era years (2569), and English terms in brackets on first use.

### Commit messages

Write them in English. Keep the first line short and start it with an imperative verb, such as `Add ...` or `Fix ...`. No personal data.

### Pull requests

Follow the checklist in [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md): validate and tests pass, no network, process, model or MCP calls of a mod's own (CI checks part of this, see What CI runs; reviewers check the rest), all sample data made up and none taken from a real person, Thai and English docs in sync, legal statements sourced and dated, and a `CHANGELOG.md` entry.

### Versioning and changelog

Each mod has its own version under [Semantic Versioning](https://semver.org/): a bug fix bumps the patch number, a new rule or feature bumps the minor number. While a mod is below 1.0, an incompatible change bumps the minor number and is called out in the changelog.

When you change a version, update it everywhere in the same commit: `<mod>/.claude-plugin/plugin.json`, that mod's entry in `.claude-plugin/marketplace.json`, the version column of the mods table in `README.md` and `README.en.md`, and the version named in `docs/*.md` for `pdpa-thai`. For a new minor version, also update both supported-versions tables in [SECURITY.md](SECURITY.md). Then add a line under `[Unreleased]` in [CHANGELOG.md](CHANGELOG.md), in Thai and English. The changelog is based on Keep a Changelog, with a date heading for each release and one subheading per mod. When you tag a release, `claude plugin tag <mod>` checks that plugin.json and the marketplace entry agree.

### Licence

All contributions are made under the MIT licence in [LICENSE](LICENSE). By opening a pull request you agree that your contribution is released under that licence.
