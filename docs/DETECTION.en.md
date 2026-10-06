# What pdpa-thai detects, and what it misses

[ไทย](DETECTION.md) · **English**

This page describes, rule by rule, what the `pdpa-thai` mod (version 0.3.0) looks for, what it rewrites before Claude reads it, and where it falls short. It is written from the code: [`pdpa-thai/hooks/detect.ts`](../pdpa-thai/hooks/detect.ts) holds the rules and [`pdpa-thai/hooks/register.tsx`](../pdpa-thai/hooks/register.tsx) holds the hooks. If this page and the code disagree, the code is what runs and this page has a bug: please [open an issue](https://github.com/Boom-Vitt/claude-mods-boombignose/issues/new/choose).

> [!IMPORTANT]
> pdpa-thai is an unofficial community project by an individual maintainer. It is not affiliated with, endorsed by or certified by Anthropic, the Personal Data Protection Committee Office (PDPC), the Electronic Transactions Development Agency (ETDA), the Digital Government Development Agency (DGA), the Ministry of Digital Economy and Society (MDES) or any Thai government body. It is designed to help reduce how much personal data you send to Claude. Using it does not make your use of Claude comply with Thailand's [Personal Data Protection Act B.E. 2562 (2019)](https://www.pdpc.or.th/wp-content/uploads/2023/12/1_Personal-Data-Protection-2562.pdf), the PDPA, and does not replace any of your obligations under it, and this page is not legal advice. For your obligations, ask a qualified lawyer or your organisation's data protection officer; for an official interpretation, ask the [PDPC](https://www.pdpc.or.th/) (legal questions: <https://consult.pdpc.or.th/>, checked 2026-10-04). The law side is covered in [PDPA.en.md](PDPA.en.md).

## In short

- Detection is a set of regular expressions plus a few checks (an ID checksum, the Luhn check, phone prefixes, host rules). It **will miss** personal data and it **will flag** harmless text. Treat it as a safety net, not a guarantee.
- Detection runs inside the Claude Code process, on your machine or wherever a cloud or remote session runs. The mod makes no network, process, model or MCP calls of its own. The redacted conversation is still sent to your configured model provider (Anthropic by default), like any Claude Code conversation. Only the occurrences the guard replaced are held back; if the same value also appears somewhere the guard does not rewrite (see [Known limits](#known-limits)), it is sent. The guard rewrites only what Claude Code sends to the model: a row can appear in its original form on screen, in an SDK stream or through Remote Control (relayed to claude.ai or the Claude app) just before it is rewritten, and other channels, such as command hooks in your settings, organisation telemetry and reports sent to Anthropic, are not covered.
- In the default `redact` mode, a detected value is replaced by a placeholder such as `[REDACTED:PHONE_1~k3x9q]` before the model sees it.

## How text is scanned

1. **Normalise.** The rules run on a shadow copy of the text that has the same length as the original. In the copy, Thai digits (๐–๙) become Arabic digits (0–9), and tabs and unusual horizontal spaces become a plain space: no-break space (U+00A0), U+1680, U+2000–U+200A, U+202F, U+205F and the ideographic space (U+3000). Because the lengths match, every match points back at the original characters, and those are what get replaced.

   Not normalised: zero-width characters (such as U+200B) and full-width digits (０–９). A value that contains them is not detected.
2. **Match.** Every rule below runs over the whole text. There is no size limit.
3. **Skip existing placeholders.** A match that overlaps text already in placeholder form is dropped whole, so in `label: <placeholder> more text` the text after the placeholder is not redacted either (see [Placeholders](#placeholders)).
4. **Merge.** Overlapping matches become one span. The span takes the kind of the match that starts first; on a tie the longer match wins, then the rule listed earlier in `detect.ts`. For example, a phone number written after `password:` becomes `PHONE`, not `SECRET`.

## What each kind catches

| Kind | What it catches | What it ignores or misses |
|---|---|---|
| `THAI_ID` | 13 digits, optionally grouped 1-4-5-2-1 with single spaces or dashes, that pass the mod-11 check digit | other groupings; a wrong check digit; digits that are part of a longer number |
| `CARD` | 13 to 19 digits (single spaces or dashes allowed between digits) that pass the Luhn check | numbers that fail Luhn. There is no issuer or prefix check, so any Luhn-valid number counts |
| `PHONE` | Thai numbers with a leading `0`, `+66` or `0066`: landlines (8 digits after the prefix, starting 2–7) and mobiles (9 digits after the prefix, starting 6, 8 or 9) | numbers from other countries; brackets or dots as separators; `66` without `+`; the `+66 (0)` form |
| `EMAIL` | `local@domain` with an ASCII local part and a dotted ASCII domain ending in 2 or more letters | exactly `example.com`, `example.org` and `example.net`; hosts with no dot (`localhost`); non-ASCII addresses |
| `IP` | IPv4 addresses with every part 255 or less | `127.x.x.x` (loopback) and `0.0.0.0`; numbers after `v` or `V` (version strings); IPv6; an address followed directly by a full stop |
| `SECRET` | known token shapes, `Bearer` tokens, and values after password, secret, token or API key labels | values that look like code: type names, dotted paths, calls, templates, environment lookups, `***`, `...` |
| `PASSPORT` | 1–2 letters and 6–8 digits shortly after a passport label | passport numbers without a label |
| `BANK_ACCOUNT` | 10 to 15 digits shortly after an account or PromptPay label | account numbers without a label |
| `DOB` | a numeric date after a date-of-birth label | dates written with month names; dates without a label |
| `SENSITIVE` | the value after a PDPA section 26 label, written as `label: value` | the same facts in ordinary sentences |
| `ADDRESS` | the value after an address label | unlabelled addresses; anything after the first comma or line break |
| `NAME` | the value after a name label; Thai names after a title; Latin names after Mr, Mrs, Ms, Miss or Dr | names with no label and no title, in any language |

### Thai national ID (`THAI_ID`)

- **Shape:** 13 digits that do not touch another digit. A single space or dash is allowed at the usual group boundaries (after the 1st, 5th, 10th and 12th digit).
- **Check:** the mod-11 check digit. The first 12 digits are multiplied by 13, 12, … 2 and added up; the 13th digit must equal (11 − sum mod 11) mod 10. A number that fails is left alone.
- **Side effect:** roughly 1 in 10 arbitrary 13-digit numbers pass this check, so other 13-digit numbers, such as millisecond timestamps or order numbers, are sometimes replaced.

### Payment card (`CARD`)

- Looks at runs of 13 to 22 digits in which single spaces or dashes may sit between digits. Inside a run it keeps the longest stretch that starts and ends at a group boundary (a space or dash), has 13 to 19 digits and passes the Luhn check. Extra digits separated from a card number by a space or dash therefore do not hide it. A stray digit written directly against the number does: the stray digit and the card number are then checked as one number, which usually fails Luhn.
- **Side effect:** roughly 1 in 10 arbitrary long numbers pass Luhn, so long numeric IDs are sometimes replaced.

### Phone (`PHONE`)

- **Shape:** a leading `0`, `+66` or `0066`, then 8 or 9 more digits. A single space or dash may sit between any two digits. Thai digits work because of normalisation.
- **Check:** after removing the prefix, the rule accepts 8 digits starting with 2–7 (treated as landlines) or 9 digits starting with 6, 8 or 9 (treated as mobiles). These prefixes are the rule's own assumption and were not checked against the regulator's numbering plan. In words: a 10-digit mobile number starting `06`, `08` or `09`, or a 9-digit landline starting `02` to `07`, plus the same numbers in `+66` form.
- **Misses:** numbers from other countries, brackets such as `(02)`, dots as separators, `66` without a plus, and the `+66 (0)` form.
- **Side effect:** any 9- or 10-digit number with a leading zero that fits these prefixes is treated as a phone number, including zero-padded reference numbers and public hotlines.

### Email (`EMAIL`)

- Scans outward from each `@`, at most 64 characters back and 255 forward, so the time it takes stays proportional to the input.
- **Local part:** ASCII letters, digits and `. _ % + -`. **Domain:** ASCII labels separated by dots, ending in 2 or more letters; a trailing dot or dash is trimmed off.
- **Skipped:** exactly `example.com`, `example.org` and `example.net`. Subdomains of these, and reserved names such as `.test` or `.local`, are not skipped.
- **Side effect:** strings that are not personal data but have the same shape are replaced too, for example an SSH Git remote: `git@` followed by a dotted host name, such as a GitHub remote.

### IPv4 (`IP`)

- **Shape:** four numbers of 1–3 digits separated by dots, not preceded by a digit, a dot, `v` or `V`, and not followed by a digit or a dot.
- **Check:** every part is 255 or less; `127.x.x.x` (loopback) and `0.0.0.0` are skipped. Private and documentation ranges (for example `192.0.2.10`) are not skipped.
- **Misses:** IPv6, and an IPv4 address that ends a sentence with a full stop directly after it (the trailing dot defeats the "not followed by a dot" rule).
- **Side effect:** four-part version numbers without a leading `v`, such as `1.0.0.12`, are replaced.

### Secrets (`SECRET`)

Three rules:

1. **Known token shapes:** keys starting `sk-` followed by 20 or more characters (a prefix several AI providers use); GitHub tokens (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_` followed by 30 or more characters); AWS access key IDs (`AKIA` followed by 16 characters); Slack tokens (`xoxb-`, `xoxa-`, `xoxp-`, `xoxr-`, `xoxs-` followed by 10 or more characters); JWT-shaped strings (three dot-separated parts, the first starting `eyJ`).
2. **`Bearer` tokens:** the word `Bearer` (any case), then a token of 20 or more characters.
3. **Labelled values:** a label (`password`, `passwd`, `pwd`, `passphrase`, `secret`, `token`, `api_key`, `api-key`, `apikey`, `access_key`, `access-key`, `accesskey` or `รหัสผ่าน`; any case), then `:` or `=`, then the value. The value is either a quoted string (single or double quotes, escapes respected, spaces kept) or an unquoted run up to a space, quote, comma or semicolon.
   - **Ignored** when the value looks like code: a type name (`string`, `number`, `boolean`, `any`, `unknown`, `undefined`, `null`, `true`, `false`, `void`, `never`, `object`, `str`, `int`, `bool`, `None`, `Optional…`, `Record…`), a dotted path or a call (`config.token`, `process.env.API_KEY`, `os.environ["SECRET"]`, `get_token()`), a template or a variable (`${…}`, `$NAME`, `{{…}}`, `<…>`, `%(…`), or a mask (one or more `*`, or `...`). This check looks only at the shape, so a real password or token of one of these shapes is not redacted either, for example two words joined by a dot, a value that is only `$` followed by a name (letters, digits or underscores, such as `$NAME`), or a value in angle brackets.
   - The label has no word boundary, so `client_secret:`, `csrf_token=` and `PWD=` match too. The full-width colon `：` is not accepted for this rule.

Example with an obviously fake value: `password: not-a-real-one` becomes `password: [REDACTED:SECRET_1~k3x9q]`.

This is not a secret scanner. Only the shapes above are matched: PEM private keys and unlabelled keys written with an underscore, such as `sk_live_…`, are not, and values that look like code are skipped. Keep secrets out of sessions and use a dedicated secret scanner.

### Labelled values (`SENSITIVE`, `ADDRESS`, `NAME`)

The format is: label, optional quote, optional spaces, then `:`, the full-width `：` or `=`, optional spaces, optional quote, then the value. The value starts at the first non-blank character on the label's line (a value on the next line is not matched) and runs to the end of the line, or to the first comma, semicolon, quote or `}`; trailing spaces are not included. A value that opens with `[` or `{` (a JSON array or object) is not matched at all, so nothing in it is replaced unless another rule, such as `PHONE` or `EMAIL`, matches it. There is no length cap. Labels are matched in any letter case and without word boundaries.

| Kind | Thai labels | English labels |
|---|---|---|
| `SENSITIVE` | เชื้อชาติ, เผ่าพันธุ์, ศาสนา, ความเชื่อ, ลัทธิ, ความคิดเห็นทางการเมือง, พฤติกรรมทางเพศ, ประวัติอาชญากรรม, โรคประจำตัว, ประวัติการรักษา, ข้อมูลสุขภาพ, ความพิการ, สหภาพแรงงาน, ข้อมูลพันธุกรรม, ข้อมูลชีวภาพ | race, ethnicity, religion, political, political opinion, sexual orientation, sexual behaviour (or behavior), criminal record, criminal history, medical history, diagnosis, health condition, health data, disability, trade union, genetic, genetic data, biometric, biometric data |
| `ADDRESS` | ที่อยู่ | home address, mailing address |
| `NAME` | ชื่อ, ชื่อจริง, นามสกุล, ชื่อ-นามสกุล, ชื่อนามสกุล, ชื่อ-สกุล | full name, first name, last name (with a space, an underscore or nothing between the words, so `firstName` counts), surname |

- `address` and `name` on their own are **not** labels, so code such as `const address: string` or the `"name"` key of a `package.json` is left alone.
- Labels must appear as listed. `home_address`, `homeAddress`, `political opinions` (plural), `ชื่อเล่น` and `หนังสือเดินทาง` on its own are not labels. The `DOB` rule accepts only `:`, `：` or no separator, so `dob=` is missed.
- The `SENSITIVE` labels are chosen to approximate the sensitive-data categories in section 26 of the Personal Data Protection Act B.E. 2562 (2019): race, ethnicity, political opinions, creed, religion or philosophy, sexual behaviour, criminal record, health data, disability, trade union data, genetic data, biometric data, and other data that the Personal Data Protection Committee prescribes ([PDPC-hosted copy of the Act](https://www.pdpc.or.th/wp-content/uploads/2023/12/1_Personal-Data-Protection-2562.pdf), checked 2026-10-04). Not every category has a label: there is none for philosophy, and none in English for creed or belief. Some labels, such as sexual orientation, diagnosis and medical history (and the Thai โรคประจำตัว and ประวัติการรักษา), are the mod's own additions. A regular expression cannot recognise these facts in a sentence, so only the `label: value` form is caught.
- **Consequence:** an address written with commas or over several lines is only partly replaced. Everything after the first comma or line break is sent as written, and a list written as a JSON array is not matched at all.

Example: `ศาสนา: ตัวอย่าง` becomes `ศาสนา: [REDACTED:SENSITIVE_1~k3x9q]`.

### Passport, bank account, date of birth

- **`PASSPORT`:** the label `passport` (any case), `เลขที่หนังสือเดินทาง`, `เลขพาสปอร์ต` or `พาสปอร์ต`, then up to 20 non-digit characters, then 1–2 letters and 6–8 digits (any case).
- **`BANK_ACCOUNT`:** the label `เลขที่บัญชี`, `หมายเลขบัญชี`, `บัญชี`, `account no`, `account number`, `account #`, `acct`, `พร้อมเพย์` or `promptpay` (any case), then up to 15 non-digit characters, then 10 to 15 digits with single spaces or dashes allowed between digits. Because `บัญชี` on its own is a label, any 10- to 15-digit number shortly after it is replaced, including a user-account (`บัญชีผู้ใช้`) number. A longer run of digits after the label is cut after 15 digits; the remaining digits are sent as written.
- **`DOB`:** the label `วันเกิด`, `date of birth`, `birth date`, `birthdate` or `dob` (any case), an optional colon, then a numeric date: 1–4 digits, 1–2 digits and 1–4 digits separated by `/`, `.` or `-`. Buddhist-era years and Thai digits work. Dates with month names do not.

### Names after a title (`NAME`)

- **Thai:** `นาย`, `นาง`, `นางสาว`, `น.ส.`, `ด.ช.` or `ด.ญ.`, not directly preceded by a Thai character, then a Thai word of 2 to 31 characters, optionally followed by a second word (the surname).
- **Excluded:** common words that merely start with a title, for example นายจ้าง, นายกรัฐมนตรี, นายกเทศมนตรี, นายหน้า, นายทะเบียน, นายแพทย์, นายตำรวจ, นางพยาบาล, นางฟ้า and นางงาม. The full list is `NOT_A_NAME` in `detect.ts`. Because the check looks at the letters directly after the title, a real given name that begins with one of these words and is written directly after the title, for example one starting with ฟ้า or งาม after `นาง`, is missed too.
- **Latin:** `Mr`, `Mrs`, `Ms`, `Miss` or `Dr`, with or without a full stop, then one or two capitalised words. Case-sensitive and ASCII letters only.
- **Misses:** names with no title and no label, in Thai or in English.

## Placeholders

A replaced value becomes `[REDACTED:KIND_n~suffix]`, for example `[REDACTED:PHONE_1~k3x9q]`.

- **Same value, same tag.** Within one piece of text handled together (one prompt, one conversation row, one attachment, or the set of context blocks computed for one conversation), the same value always gets the same tag and each new value gets the next number for its kind. "Same value" means the same characters after normalisation: a number in Thai digits and the same number in Arabic digits share a tag, but the same number written once with spaces and once with dashes gets two tags.
- **Numbers are not reused.** If the text already contains a placeholder (for example you pasted `PHONE_3` back in), new values of that kind are numbered above the highest number present.
- **Numbering starts again for each row.** `PHONE_1` in one message and `PHONE_1` in a later message can be different values, and the model cannot tell them apart.
- **Idempotent.** Text already in placeholder form is never scanned again, so redacting twice gives the same result. A side effect: a value deliberately wrapped in placeholder-shaped text is not redacted either.
- **Per-session suffix.** The part after `~` is a short code of lowercase letters and digits (5 characters), taken from the clock when the guard first needs it in a session and kept in the mod's state. It lets the guard recognise the placeholders that *this session* issued, so a file that only shows the placeholder format (a test, or the format examples on this page) is not refused when Claude edits it. Other example values in such a file are still redacted when Claude reads it: read through the guard, this page itself comes back with many of its examples replaced. Edit those lines yourself, or run `/pdpa-guard off` while you work on such a file.
- **Tool calls are checked.** If a tool call's input contains a placeholder issued this session, the call is refused, and the model is told to ask you for the value or to have you run `/pdpa-guard off`. This helps keep a placeholder from being written into a real file, command or request. The check only recognises this session's suffix: a placeholder retyped without the suffix, or one carrying another session's suffix, is not refused. After Claude Code restarts (including `claude --resume`), the session gets a new suffix, so placeholders already in the resumed conversation are no longer refused.
- **One-way.** The mod keeps no table from placeholder back to value. A placeholder cannot be turned back into the original.

## What is rewritten

| Where the text comes from | Hook | `redact` | `block` | `off` |
|---|---|---|---|---|
| The prompt you type | `prompt.submit` | values replaced | prompt not sent | unchanged |
| Rows the conversation keeps: tool results, hook output and other delivered messages | `session.append` | values replaced | values replaced | unchanged |
| `@file` mentions, edited files, `CLAUDE.md` files in subfolders read later, reminders and context from hooks in your settings | `prompt.attachment` | values replaced | values replaced | unchanged |
| Context blocks on the first message: `CLAUDE.md` and other instruction files, your account email, project and date | `prompt.context` | values replaced | values replaced | unchanged |
| A tool call whose input holds a placeholder from this session | `tool.call` | refused | refused | allowed |

Inside a conversation row only text is rewritten: plain text blocks, and the text inside tool results. Images, documents, tool-call (`tool_use`) blocks and the model's thinking are passed on whole. Model replies, compaction summaries and notices are not scanned. The on-screen mask (`/pdpa-blur`) is separate and does not depend on the mode; see [`/pdpa-blur` is not the guard](#pdpa-blur-is-not-the-guard).

## Known limits

These are the same limits as in the [README](../README.en.md#limits), in the same order, followed by a few that only this page covers in detail. An italic note after a limit says what it means in practice.

1. Every rule is a best-effort regular expression. It **will** miss some personal data and **will** flag some harmless text. *Do not rely on the guard as your only control; keep personal data out of prompts where you can.*
2. It is not a secret scanner. Only the token shapes and labels listed in [Secrets](#secrets-secret) are matched, and values that look like code are skipped. Keep secrets out of sessions and use a dedicated secret scanner.
3. Labelled values (`SENSITIVE`, `ADDRESS`, `NAME`) stop at the first comma, semicolon, quote, `}` or line break; the rest of an address or list is sent as written. A labelled value that opens with `[` or `{` (a JSON array or object) is not matched at all; only other rules, such as `PHONE` or `EMAIL`, can still replace something inside it.
4. Names and addresses without a label or a title, such as a name in the middle of a sentence, are not detected. *An address without a label such as `ที่อยู่:` reaches the model as it is.*
5. Images and documents attached as separate blocks are not inspected. *A scanned ID card, a screenshot or a PDF reaches the model as it is; remove such data before you share the file.*
6. Some content cannot be rewritten by mods, so it is not redacted: model thinking and tool_use inputs. *If a value got into one of these (for example the model typed a value it read from an image into a command), it stays there and is sent again with later requests.*
7. Resumed history and saved subagent transcripts are not checked again; anything in them that was not redacted when first written is sent as is. *This includes history stored while the guard was off or before the mod was installed.*
8. Claude Code keeps structured tool results and attachment payloads (such as files mentioned with `@`) in their original form, so they stay unredacted in the stored transcript, and tool-result display is not masked. *Protect your machine and transcript files as you normally would.*
9. Claude Code's own prompt history (up-arrow recall) is outside the mod's control and may keep what you typed, unredacted, on your machine.
10. The system prompt (environment details, MCP server instructions and sections other plugins add) and tool and skill descriptions are not inspected.
11. Claude's responses, compaction summaries and notices are not redacted. *If the model writes personal data in a reply, for example something it read from an image, that reply is stored and sent back in later requests unchanged.*
12. A value split across several messages can evade detection. *Half a phone number in one prompt and the rest in the next both go through.*
13. If one of the mod's hooks throws an error or runs past Claude Code's per-hook time limit, Claude Code skips it and sends the text unchanged, with no notice (fail-open). *The tests check that deliberately awkward inputs still finish quickly; see [Performance](#performance).*
14. If the mod does not load, nothing is redacted, and the only sign is that the `PDPA:` entry is missing from the status line; run `claude --debug` to see why. Headless runs (such as `claude -p`) show no status line. *After you switch the guard off, the status line shows `PDPA: off`; see [The three modes](#the-three-modes).*
15. The hook API is early access. The mod is tested only with Claude Code 2.1.289; an older or newer build may skip some or all of the guard without warning, and the CI badge shows only that the unit tests pass on the latest build.
16. Hooks of other plugins that run before this mod's may see the original text.
17. A tool result or other conversation message can appear in its original form, just before it is redacted, on your screen or wherever the session is shown (Remote Control, which is relayed through Anthropic's service to claude.ai or the Claude app, or an SDK stream). *If you stream the session to an SDK client or use Remote Control, an original value can reach that client.*
18. The guard rewrites only what Claude Code sends to the model. Other channels are separate, are not covered and may receive original values: Remote Control (relayed through Anthropic's service to claude.ai or the Claude app), command hooks in your settings, a telemetry collector your organisation configured, and reports you send to Anthropic.
19. The on-screen mask is visual only: copying, selecting, screen readers, terminal search, and terminal recordings or logs (for example tmux capture or asciinema) still get the real text, and a screen recording shows it whenever the pointer hovers over it unless recording mode (`/pdpa-blur record`) is on. Recording mode does not cover the prompt box before you send, tool or command output, or the original text shown anywhere else. Terminals that raise text contrast automatically (for example VS Code's integrated terminal, with its minimum contrast ratio setting on by default) may draw the masked text readable. The mask works only in the terminal and the desktop app, and text longer than 100,000 characters is not masked. *See [`/pdpa-blur` is not the guard](#pdpa-blur-is-not-the-guard).*
20. The tool-call refusal catches only this session's placeholders written exactly as issued, and does nothing while the guard is `off`. *A placeholder retyped without its suffix, or one from another session, is not refused; after a restart or `claude --resume` the session gets a new suffix.*
21. A notice counts only what the rules matched. No notice does not mean that no personal data was sent, and a notice does not mean that the text is now clean.
22. Claude sees only placeholders, so it cannot act on the real value, and redaction cannot be undone: turning the guard off does not bring back values already redacted. When a task needs the real value, run `/pdpa-guard off`, send the value again, and run `/pdpa-guard redact` when the task is done. While the guard is off, tool calls that contain earlier placeholders are not refused, so check what Claude writes.
23. Anything sent while the guard is `off` stays in the conversation as it was sent. Turning the guard back on does not redact it, and it is sent again with every later request in that conversation. Run `/clear` or start a new session to drop it.
24. `CLAUDE.md`, other context blocks and attachments keep the result from when Claude Code first prepared them, so changing the mode later does not affect content already prepared. Context blocks are prepared again after `/clear` or compaction. *Context blocks are prepared once per conversation and attachments once per process; attachments are prepared again when you resume.*
25. `CLAUDE.md` and other context blocks are redacted too, so Claude does not see values you put there on purpose, such as your own email address. *Instructions that depend on the exact value, such as an email address for commit attribution, stop working.*
26. Public data, such as an agency's published contact number, is redacted too if it matches a rule.
27. The guard reduces what is sent. It does not stop Claude Code from sending the (redacted) conversation to your configured model provider (Anthropic by default).
28. The mod works per user and per machine, and the user can switch it off at any time (`/pdpa-guard off`, `claude plugin disable`). It cannot be enforced centrally and keeps no audit log of what it redacted or what was sent, so it cannot show that a control was in place.

Further gaps that follow from the code:

- **Formatting tricks defeat matches:** zero-width characters, full-width digits, dots or brackets inside numbers, a digit written directly against a card number, an IPv4 address directly followed by a full stop.
- **Messages longer than 100,000 characters are not masked on screen.** They are still scanned in full before sending, unless the hook fails or runs past its time limit (known limit 13).

## False positives you may see

In Thai text:

- Words that start with a title and are not on the exclusion list are treated as names, for example นางแบบ, นางเอก, นายทุน and นายพล. The title `นางสาว` written on its own (say, in a list of titles) is also caught, because it reads as `นาง` followed by a word.
- `ชื่อ:` followed by anything, such as a project or product name, becomes `NAME`. Because labels have no word boundary, a word that ends in `ชื่อ` and is followed by a colon (for example `ไม่เชื่อ:`) also triggers it.
- `บัญชี` followed by any 10- to 15-digit number becomes `BANK_ACCOUNT`.
- Public phone numbers and zero-padded reference numbers that look like Thai phone numbers become `PHONE`.

In code and logs:

- Labels match inside longer words: `Stack trace:` or `trace =` (contains `race`) and `geopolitical:` (contains `political`) become `SENSITIVE`.
- Type annotations and keys with name labels, such as `firstName: string` or a `"lastName"` key, become `NAME`. The code-value exclusion applies to `SECRET` only.
- `PWD=/some/path`, `token: 512` and the word `secret:` in a sentence become `SECRET`.
- 13-digit millisecond timestamps and long numeric IDs sometimes pass the ID checksum or the Luhn check. Each check passes about 1 in 10 arbitrary numbers, so roughly 1 in 5 such 13-digit numbers is flagged by one or the other.
- Four-part version numbers without `v`, and private network addresses, become `IP`.
- SSH Git remotes (`git@` plus a dotted host) and addresses at subdomains of `example.com`, `.test` or `.local` become `EMAIL`.
- Made-up names in sample data, such as `Dr Foo Bar`, become `NAME`.

How to cope:

- **Turn the guard off for one task.** Run `/pdpa-guard off`, do the task, then `/pdpa-guard redact`. Remember that anything sent while off stays in the conversation.
- **Keep the value out of the prompt.** For real personal data, describe it instead of pasting it. For harmless text that trips a label, rephrase it so it is not in `label: value` form.
- **Report it with a synthetic example.** Open an issue with a made-up value of the same shape. Never paste real personal data, a real token or a real ID into an issue.

## The three modes

| Mode | What happens | When to use it |
|---|---|---|
| `redact` (default) | Detected values are replaced with placeholders before the model sees them; tool calls that carry this session's placeholders are refused. | Everyday work, especially when files, logs or tool output may contain personal data that the task does not need. |
| `block` | A typed prompt that contains detected data is not sent; you see a notice and edit it. Tool results, attachments and context blocks are still redacted, and the tool-call check still applies. | When you would rather fix the prompt yourself than have it changed, for example in a demo or a training session, or on a team that wants people to stop pasting personal data out of habit. |
| `off` | Nothing is scanned or replaced, and tool calls are not checked. The blur, if on, still works. | When the task needs the real value, or false positives get in the way. Switch back afterwards. |

Run `/pdpa-guard` with no argument to see the current mode. An argument other than `redact`, `block` or `off` changes nothing and only shows the current mode. The status line shows `PDPA: <mode>`, followed by ` · REC` in recording mode; if it shows no `PDPA:` entry at all, the mod did not load and nothing is redacted (see known limit 14). A short notice tells you how many items were replaced in a prompt or a stored row, or why a prompt was blocked. Replacements in attachments and context blocks (for example in `CLAUDE.md`) show no notice. A notice counts only what the rules matched, so no notice does not mean nothing personal was sent.

The mode and the mask settings are not saved to disk and start as `redact` with the mask on and recording mode off whenever Claude Code starts; whether `/clear` keeps the current mode has not been verified by the maintainer (run `/pdpa-guard` with no argument, or look at the status line, to see the current mode). If you rely on `block`, set it again after every start or resume.

## `/pdpa-blur` is not the guard

`/pdpa-blur` controls an on-screen mask. It is on by default.

| Command | Effect |
|---|---|
| `/pdpa-blur` | Toggles: on if the mask was off, off if it was on or in recording mode |
| `/pdpa-blur on` | Mask on; hovering over a block reveals it |
| `/pdpa-blur off` | Mask off |
| `/pdpa-blur record` | Recording mode: mask on, and hovering reveals nothing |

Any other argument changes nothing and prints a usage line.

- It uses the same rules as the guard, but only changes how your messages and Claude's messages are drawn. It does not change what is sent, and it works the same in every guard mode, including `off`.
- The real text is drawn grey on grey, so the layout does not shift. Hovering over a block reveals it, except in recording mode; selecting and copying yields the real text in every mode.
- It works on the terminal and desktop surfaces only. Tool output is not blurred, and messages longer than 100,000 characters are drawn normally.
- Terminals that raise text contrast automatically (for example VS Code's integrated terminal, with its minimum contrast ratio setting on by default) may draw the masked text readable. Outside recording mode, a screen share or screen recording shows the value whenever the pointer hovers over it. Terminal logs and text-level recordings (for example tmux capture or asciinema) keep the real text in every mode.
- Use it to reduce shoulder-surfing. It is not a security control.

### Recording mode

`/pdpa-blur record` is for screen recording and screen sharing. The mask stays on, and hovering does not reveal a masked value while recording mode is on. The status line then reads `PDPA: <mode> · REC` (for example `PDPA: redact · REC`). Like the rest of the mask, it applies on the terminal and desktop surfaces only and is not saved to disk; Claude Code starts with the mask on and recording mode off. `/pdpa-blur on` or `/pdpa-blur off` leaves it. Stop recording before you leave recording mode: `/pdpa-blur on` brings hover reveal back, and `/pdpa-blur` with no argument turns the mask off. Claude Code also starts again with recording mode off, so check the status line after any restart or resume.

Recording mode masks detected values only in your messages and Claude's messages. Everything else Claude Code draws, including tool calls and their output, file diffs, thinking, notices and other panes, is shown as is.

Recording mode does not cover:

- personal data the rules do not detect, such as a name without a label or title (see [Known limits](#known-limits)): it is shown as written and is not masked;
- text you type in the prompt box before you send it (the guard replaces it only on submit);
- tool calls, tool output and command output on screen;
- the original text if it is on screen for any other reason, for example a file open in another window;
- selecting text, which may make the masked text readable on screen; copying yields the real text.

In `redact` mode your own sent prompts already show placeholders, so the mask matters mainly for Claude's replies and for text sent while the guard was `off`.

Before you record or share your screen: set the guard to `redact` or `block`, run `/pdpa-blur record`, and check the recording before you share it. It is a visual mask, not a guarantee.

## Performance

- The rules are written so that the time they take grows in proportion to the input. The email rule, for example, looks at most 64 characters back and 255 forward from each `@`, and a labelled value must start with a non-blank character, so a long run of spaces or tabs after a label is passed over in linear time. Scanning runs on every prompt, tool result, attachment and context block, and, while the mask is on, each time a message is drawn.
- Large inputs are scanned in full; there is no size cut-off for redaction. A hook that fails or runs past Claude Code's per-hook time limit is still skipped, and the text is sent unchanged (known limit 13). (The on-screen mask skips messages over 100,000 characters.)
- The tests include an oversized text that must still be scanned, and deliberately awkward inputs that must finish within a time limit: long runs of `@`, digits or `password:` labels, and 150,000 spaces, tabs or no-break spaces after labels such as `dob`, `full name:` and `ศาสนา:`.

## Privacy

- Detection runs locally, inside the Claude Code process: on your machine, or in the cloud or remote environment where you run Claude Code.
- `pdpa-thai` and `context-bar` make no network, process, model or MCP calls of their own; `agents-panel` starts a subagent (`$.agent.spawn`) only when you press `▶ run`, and that subagent talks to your configured model provider (Anthropic by default) like any agent. CI checks the hook code on every push and pull request (see [Verify it yourself](#verify-it-yourself)). These checks are not a proof; read the code to confirm.
- The redacted conversation is still sent to your configured model provider (Anthropic by default), like any Claude Code conversation. Redaction applies to the copy the model reads: the original values the guard replaced are not in what is sent to the model, but Claude Code's own stored copies are not changed (known limits 8 and 9). If the same value also appears somewhere the guard does not rewrite, it is sent; a row can reach your screen, an SDK client or Remote Control in its original form just before it is rewritten (known limit 17); and other channels are not covered (known limit 18).
- Redaction is not anonymisation. The text around a placeholder can still identify a person directly or indirectly (section 6 of the PDPA), so the redacted conversation may still be personal data; see [PDPA.en.md](PDPA.en.md).
- Nothing here claims PDPA compliance. Whether your use of an AI service is lawful, including any cross-border transfer question, depends on your situation; see [PDPA.en.md](PDPA.en.md) and ask a qualified lawyer or your organisation's data protection officer.

## Verify it yourself

You need a Claude Code build that supports hook-module plugins; the mods were tested only with Claude Code 2.1.289 (see known limit 15).

1. **Read the code.** [`detect.ts`](../pdpa-thai/hooks/detect.ts) is under 300 lines and every rule is in the `RULES` list. [`register.tsx`](../pdpa-thai/hooks/register.tsx) shows each hook and what it rewrites.
2. **Run the tests** from the repository root:
   ```bash
   claude plugin test pdpa-thai
   ```
   The sample values in [`pdpa-thai/tests/`](../pdpa-thai/tests/) are made up: some are assembled from fragments, some are obviously fictional. Some must have a valid format, such as a correct check digit, so that the rules match them.
3. **Check what the mod calls.**
   ```bash
   claude plugin validate pdpa-thai
   ```
   The `calls:` line is the engine's own static analysis of which engine calls each module makes. For pdpa-thai they are the clock, command registration, the mod's own state, and the screen (status, notices, drawing); there are no network, process, model or MCP calls.
4. **Know what CI checks.** [`.github/workflows/test.yml`](../.github/workflows/test.yml) validates every mod, runs the tests, and runs two local-only checks: a text search of every mod's hook code for network, process, model and MCP calls and for `fetch(`, and a check that every engine call on the `calls:` line printed by `claude plugin validate pdpa-thai` is a state, ui, clock or command call (step 3). Neither check replaces reading the code, and neither proves anything about other mods or about Claude Code itself. Both checks, and what they miss, are described in one place: [What CI runs](../CONTRIBUTING.md#what-ci-runs).
5. **Try it with fake data.** With the guard in `redact` mode, send a prompt containing `password: not-a-real-one` or `ศาสนา: ตัวอย่าง` and check the notice and the placeholder in the transcript.

## Report a miss or a false positive

Open an issue at <https://github.com/Boom-Vitt/claude-mods-boombignose/issues/new/choose> with a synthetic example of the same shape and say which kind you expected. For a way to get around the guard that you think is a security problem, use a private security advisory as described in [SECURITY.md](../SECURITY.md) instead of a public issue.

---

pdpa-thai is designed to help reduce the risk of sending personal data to an AI service. It is not legal advice, not a certification, and not a substitute for your organisation's own controls.
