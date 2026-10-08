# PDPA and AI coding assistants such as Claude Code

[ไทย](PDPA.md) · **English**

> [!IMPORTANT]
> - This document is **not legal advice**. It is background for developers. For a legal decision, ask a qualified lawyer or your organisation's data protection officer (DPO). For an official interpretation, ask the Personal Data Protection Committee Office (PDPC), which runs pdpc.or.th.
> - This is an unofficial community project run by an individual maintainer. It is **not affiliated with, endorsed by, or certified by** Anthropic, the PDPC, the Electronic Transactions Development Agency (ETDA), the Digital Government Development Agency (DGA), the Ministry of Digital Economy and Society (MDES), or any Thai government body. Claude and Claude Code are Anthropic's products; the names are used only to say what this mod works with.
> - Installing pdpa-thai does not make an organisation compliant with the Personal Data Protection Act B.E. 2562 (2019) (PDPA). The mod is designed to help reduce risk, nothing more.
> - Provided as is, without warranty, under the [MIT License](../LICENSE). You remain responsible for how you handle personal data.
> - Law and regulator facts here were checked on 2026-10-04. Laws and notifications change; always check the original.

## Contents

- [Purpose](#purpose)
- [Why prompts can contain personal data](#why-prompts-can-contain-personal-data)
- [Relevant sections of the Act](#relevant-sections-of-the-act)
- [Cross-border transfer and cloud processing](#cross-border-transfer-and-cloud-processing)
- [Security measures and breach notification](#security-measures-and-breach-notification)
- [Sensitive data under section 26](#sensitive-data-under-section-26)
- [What pdpa-thai does](#what-pdpa-thai-does)
- [What pdpa-thai does not do](#what-pdpa-thai-does-not-do)
- [AI guidance from Thai agencies](#ai-guidance-from-thai-agencies)
- [Where to complain or ask](#where-to-complain-or-ask)
- [Developer checklist](#developer-checklist)
- [Sources and verification](#sources-and-verification)
- [What was not verified](#what-was-not-verified)

## Purpose

This document is for developers and small teams in Thailand who use a cloud AI coding assistant such as Claude Code. It covers:

1. How personal data ends up in prompts without anyone meaning to send it.
2. The parts of the Personal Data Protection Act B.E. 2562 (2019), the PDPA, that are relevant here, limited to sections checked against the source.
3. What pdpa-thai does, and what it does not do.
4. A checklist you can use today.

It does not cover penalties, fines or legal deadlines, and it is not a PDPA compliance programme.

## Why prompts can contain personal data

On every turn, Claude Code sends the conversation to your configured model provider (Anthropic by default, or a cloud platform such as Amazon Bedrock or Google Cloud Vertex AI if your organisation set that up). The conversation is more than what you type: it includes the contents of files Claude reads, the output of commands Claude runs, `CLAUDE.md`, and other context. Anything Claude can read can become part of what is sent.

Common sources:

| Source | What tends to come along |
| --- | --- |
| Code and test data (fixtures, seed data) | Real customer records copied in as examples |
| Application logs | Emails, IP addresses, phone numbers, session tokens the system logged |
| Database dumps and CSV exports | Whole user or order tables |
| Customer chats and support tickets | Names, addresses, account numbers customers typed |
| `CLAUDE.md` and other context files | Team contact details, server access details |
| Command output | Results of a query against a production database, an API call that returns user records |
| Images and documents | Screenshots of an admin panel, PDFs with customer data |

Most of this is accidental. You ask Claude to fix a bug, Claude opens a log file to find the cause, and the log contains customer emails.

## Relevant sections of the Act

The table covers only the sections of the PDPA that were checked in the [PDF hosted on the PDPC website](https://www.pdpc.or.th/wp-content/uploads/2023/12/1_Personal-Data-Protection-2562.pdf) (checked 2026-10-04). The descriptions are summaries, not the legal text. Read the original.

| Section | Subject | Why it matters when using AI |
| --- | --- | --- |
| 6 | Definitions, including personal data, data controller and data processor | Personal data is data that identifies a person directly or indirectly. It is much wider than a national ID number or a phone number. |
| 19 | Consent. The general rule is that collecting, using or disclosing personal data requires consent, unless this Act or another law allows it. | Giving customer data to an AI tool may count as using or disclosing it. Ask your DPO whether it falls under the lawful basis your organisation relies on. |
| 26 | Sensitive personal data | Stricter conditions than ordinary personal data. See [section 26](#sensitive-data-under-section-26). |
| 28–29 | Sending or transferring personal data abroad | See [cross-border transfer](#cross-border-transfer-and-cloud-processing). |
| 37 | Duties of the data controller, including appropriate security measures | Deciding which tools can see personal data can be part of this. |
| 40 | Duties of the data processor | A team that builds or runs systems for a client may be acting as a data processor. Read this section together with your client contract. |

## Cross-border transfer and cloud processing

- Section 28 deals with sending or transferring personal data to a foreign country, which involves the destination's data protection standard under criteria set by the Personal Data Protection Committee. Section 29 sets out further cases of sending or transferring personal data abroad.
- Notification under section 28 (B.E. 2566 / 2023): [page](https://www.pdpc.or.th/2500/), [PDF](https://www.pdpc.or.th/wp-content/uploads/2024/01/M28.pdf).
- Notification under section 29: [page](https://www.pdpc.or.th/2507/).

Using a cloud AI service raises the question of whether sending a prompt that contains personal data to that service is a "sending or transfer" abroad under these sections. The answer **depends on the facts**, in particular whether a third party can access the data. This document **does not draw a conclusion**.

In practice:

- Ask your DPO or lawyer.
- Read the provider's terms and your contract with it: where data is processed, who can access it, how long it is kept.
- Check whether your organisation already has an agreement with the AI provider.
- Minimise at the source. Data that is never sent narrows the question in practice.

## Security measures and breach notification

- Section 37 sets out the data controller's duties, including providing appropriate security measures.
- The Committee issued a notification on security measures (B.E. 2565 / 2022): [page](https://www.pdpc.or.th/2971/). Read the requirements in the notification itself; this document does not summarise it.
- pdpa-thai is designed to help reduce what is sent to an AI tool. This document does not assess whether it counts as a measure under section 37 or the notification above, and it does not replace your organisation's other measures.

If personal data has been sent somewhere it should not have gone, follow your organisation's breach response process and see the PDPC pages on [personal data breach notification](https://www.pdpc.or.th/2405/) and the [breach report form](https://www.pdpc.or.th/17259/). Conditions and time limits for notification are not covered here; check the original.

## Sensitive data under section 26

Section 26 lists the categories of personal data that the Act treats more strictly (commonly called sensitive personal data): race, ethnicity, political opinions, creed, religious or philosophical beliefs, sexual behaviour, criminal records, health data, disability, trade union information, genetic data, biometric data, and other data that affects the data subject in a similar way, as the Committee prescribes. This kind of data turns up in HR, healthcare and insurance systems.

### Why pdpa-thai only catches these when they are labelled

A regular expression cannot read a sentence and reliably decide that it reveals someone's health or religion. Flagging every related word would redact large amounts of ordinary documentation, code and text. So pdpa-thai detects section 26 data **only when it is written as `label: value`**: a Thai or English label, then a colon (`:` or the full-width `：`) or an equals sign (`=`), then the value. That shape is common in form data, JSON and YAML. CSV files and SQL dumps, where the label sits in a header row or column list rather than next to the value, are **not detected**. Do not rely on pdpa-thai to make it safe to show Claude real health or HR records; keep them out of the session.

- When it matches, the label stays and the value is replaced with a placeholder such as `[REDACTED:SENSITIVE_1~k3x9q]`. The value ends at the first comma, semicolon, quote, closing brace or line break, so the rest of a list is **not** redacted: of two conditions separated by a comma only the first is replaced, and a value that opens with `[` or `{` (a JSON array or object) is not matched at all, so nothing in it is replaced unless another rule, such as `PHONE` or `EMAIL`, matches it.
- Thai label examples: เชื้อชาติ, ศาสนา, ความคิดเห็นทางการเมือง, ประวัติอาชญากรรม, โรคประจำตัว, ประวัติการรักษา, ความพิการ, สหภาพแรงงาน, ข้อมูลพันธุกรรม, ข้อมูลชีวภาพ.
- English label examples: race, religion, political opinion, criminal record, medical history, diagnosis, disability, trade union, genetic data, biometric data.
- Prose that describes someone's illness or beliefs is **not detected**.
- Biometric data stored as images, such as face photos, is **not inspected**; pdpa-thai does not look at images.

The full label list is in [DETECTION.en.md](DETECTION.en.md).

## What pdpa-thai does

pdpa-thai (version 0.3.0) is a Claude Code mod. It needs a Claude Code build that supports hook-module plugins and has been tested only with Claude Code 2.1.289. The hook API is early access, so an older or newer build may skip some or all of the guard without warning; the CI badge shows only that the unit tests pass on the latest build. Technically, it is designed to help reduce what is sent (data minimisation, a general privacy practice). Whether it counts as a measure under the Act or any notification is for your organisation and DPO to decide.

- **Looks for 12 kinds of data** (best effort): `THAI_ID`, `CARD`, `PHONE`, `EMAIL`, `IP`, `SECRET`, `PASSPORT`, `BANK_ACCOUNT`, `DOB`, `SENSITIVE`, `ADDRESS` and `NAME`, using rules that run inside the Claude Code process. Each rule and its limits are described in [DETECTION.en.md](DETECTION.en.md).
- **`redact` mode (default)** replaces each detected value with a placeholder such as `[REDACTED:PHONE_1~k3x9q]` **before** the model sees it. Within one message the same value gets the same placeholder, so the model can still refer to it. Numbering restarts in each message, so `PHONE_1` in two different messages may be two different values. It covers:
  - prompts you type;
  - tool results (file contents and command output) and other content the conversation keeps for the model to read, such as context added by other hooks;
  - `@` file attachments, `CLAUDE.md` and the other context blocks sent with the first message.
- **`block` mode** refuses to send a typed prompt that contains detected data, and still redacts tool results and other content as in `redact` mode.
- **`off` mode** turns the guard off, including the tool-call check; the on-screen mask is controlled separately with `/pdpa-blur`.
- **Refuses tool calls** whose input contains a placeholder issued in this session, to reduce the chance that Claude writes one into a real file or command by mistake. The check runs only while the guard is on (`redact` or `block`) and matches only the exact placeholder with this session's suffix. A placeholder from an earlier session, or one Claude retypes without its suffix, is not refused.
- **`/pdpa-blur [on | off | record]`** controls an on-screen mask; it is on by default. With no argument it toggles (on if it was off, off if it was on or recording); any other argument changes nothing and prints a usage line. Detected data in your messages and Claude's messages is drawn grey on grey and hovering reveals it. In `redact` mode your sent prompts already show placeholders, and in `block` mode a prompt with detected data is not sent, so the mask matters mainly for Claude's replies and for text sent while the guard is off. It works on the terminal and desktop surfaces only, does not cover tool output, and skips messages longer than 100,000 characters. Copying, selecting, screen readers, terminal search, and terminal recordings or logs (for example tmux capture or asciinema) still get the real text, and a screen recording shows it whenever the pointer hovers over it. Terminals that raise text contrast automatically (for example VS Code's integrated terminal, with its minimum contrast ratio setting on by default) may draw the masked text readable. It is a visual mask and does not change what is sent to the model.
- **`/pdpa-blur record`** (recording mode) is for screen recording and screen sharing: the mask stays on, hovering does not reveal a masked value while recording mode is on, and the status line reads `PDPA: <mode> · REC`. It masks detected values only in your messages and Claude's messages; everything else Claude Code draws, including tool calls and their output, file diffs, thinking, notices and other panes, is shown as is. It does not cover personal data the rules do not detect, such as a name without a label or title, which is shown as written; text you type in the prompt box before you send it (the guard replaces it only on submit); tool calls, tool output and command output on screen; the original text if it is on screen for any other reason (for example a file open in another window); or selecting text, which may make the masked text readable on screen, and copying, which yields the real text. Before you record, set the guard to `redact` or `block`, run `/pdpa-blur record`, and check the recording before you share it. It is a visual mask, not a guarantee.

The mode and the mask settings are not saved to disk and start as `redact` with the mask on and recording mode off whenever Claude Code starts; whether `/clear` keeps the current mode has not been verified by the maintainer (run `/pdpa-guard` with no argument, or look at the status line, to see the current mode).

**Check that it is running.** While the guard is on, the status line shows `PDPA: redact` or `PDPA: block` (followed by ` · REC` in recording mode). If it shows neither, nothing is redacted: `PDPA: off` means the guard is off, and no `PDPA:` entry means the mod did not load (run `claude --debug` to see why). Headless runs (`claude -p`) show no status line, so the status line cannot confirm the guard there.

### Privacy facts

- Detection runs inside the Claude Code process, on your machine or wherever a cloud or remote session runs.
- pdpa-thai makes no network, process, model or MCP calls of its own. Its code uses only the clock, command registration, its own session state and the screen. On every push and pull request, CI runs two local-only checks: a text search of every mod's hook code for network, process, model and MCP calls and for `fetch(`, and a check that every engine call on the `calls:` line printed by `claude plugin validate pdpa-thai` is a state, ui, clock or command call. Neither check proves anything about other mods or about Claude Code itself. Both checks, and what they miss, are described in one place: [What CI runs](../CONTRIBUTING.md#what-ci-runs). The agents-panel mod starts a subagent only when you press ▶ run, and that subagent talks to your configured model provider (Anthropic by default) like any agent. The code is in [`pdpa-thai/hooks/`](../pdpa-thai/hooks/).
- **The redacted conversation is still sent to your configured model provider (Anthropic by default)**, like any Claude Code conversation. Each occurrence the guard replaced is left out of the requests to the model provider, but the same value is still sent if it also appears somewhere the guard does not rewrite (see [What pdpa-thai does not do](#what-pdpa-thai-does-not-do)), and anything the rules miss is sent as is.
- **Redaction applies to the copy the model reads, not every copy.** The guard rewrites only what Claude Code sends to the model. Other channels are separate, are not covered and may receive original values: Remote Control (relayed through Anthropic's service to claude.ai or the Claude app), command hooks in your settings, a telemetry collector your organisation configured, and reports you send to Anthropic. An SDK client the session streams to can also see a row in its original form just before it is rewritten. Claude Code's own stored files keep some original values raw (see below). pdpa-thai runs wherever Claude Code runs: if that is a cloud session rather than your computer, the original values are already on that cloud machine.

## What pdpa-thai does not do

### Legal and organisational

- It does not give or replace consent, and it does not create a lawful basis for processing.
- It does not replace a data processing agreement, a privacy notice, records of processing, a DPO, or a breach response and notification process.
- It does not answer whether using a cloud AI service is a cross-border transfer.
- It does not make your organisation PDPA compliant. For the duties above, see the Act and take advice.
- It does not anonymise. Redaction is not anonymisation: the redacted conversation can still identify a person directly or indirectly (section 6), so it may still be personal data, and the questions about lawful basis and cross-border transfer still apply. Ask your DPO.
- It is not an organisational control. It runs per user and per machine, any user can switch it off (`/pdpa-guard off`, or by disabling the plugin), it has no setting an administrator can lock, and it keeps no audit record of what was redacted or sent. It cannot be enforced centrally and cannot show that a control was in place.
- It does not stop Claude Code from sending the (redacted) conversation to your configured model provider (Anthropic by default).
- It does not control what other plugins, MCP servers or the commands Claude runs do with raw files on your machine. A command can still read a raw file and send it elsewhere; only what comes back to the model is redacted.
- It does not cover other tools, such as AI chat in a web browser or AI plugins in other editors.

### Technical

These are the same limits as in the README's [Limits](../README.en.md#limits) section, in the same order. Details are in [DETECTION.en.md](DETECTION.en.md#known-limits).

- Every rule is a best-effort regular expression. It **will** miss some personal data and **will** flag some harmless text.
- It is not a secret scanner. Only the token shapes and labels listed in [DETECTION.en.md](DETECTION.en.md#secrets-secret) are matched, and values that look like code are skipped. Keep secrets out of sessions and use a dedicated secret scanner.
- Labelled values (`SENSITIVE`, `ADDRESS`, `NAME`) stop at the first comma, semicolon, quote, `}` or line break; the rest of an address or list is sent as written. A labelled value that opens with `[` or `{` (a JSON array or object) is not matched at all; only other rules, such as `PHONE` or `EMAIL`, can still replace something inside it.
- Names and addresses without a label or a title, such as a name in the middle of a sentence, are not detected.
- Images and documents attached as separate blocks are not inspected.
- Some content cannot be rewritten by mods, so it is not redacted: model thinking and tool_use inputs.
- Resumed history and saved subagent transcripts are not checked again; anything in them that was not redacted when first written is sent as is.
- Claude Code keeps structured tool results and attachment payloads (such as files mentioned with `@`) in their original form, so they stay unredacted in the stored transcript, and tool-result display is not masked.
- Claude Code's own prompt history (up-arrow recall) is outside the mod's control and may keep what you typed, unredacted, on your machine.
- The system prompt (environment details, MCP server instructions and sections other plugins add) and tool and skill descriptions are not inspected.
- Claude's responses, compaction summaries and notices are not redacted.
- A value split across several messages can evade detection.
- If one of the mod's hooks throws an error or runs past Claude Code's per-hook time limit, Claude Code skips it and sends the text unchanged, with no notice (fail-open).
- If the mod does not load, nothing is redacted, and the only sign is that the `PDPA:` entry is missing from the status line; run `claude --debug` to see why. Headless runs (such as `claude -p`) show no status line.
- The hook API is early access. The mod is tested only with Claude Code 2.1.289; an older or newer build may skip some or all of the guard without warning, and the CI badge shows only that the unit tests pass on the latest build.
- Hooks of other plugins that run before this mod's may see the original text.
- A tool result or other conversation message can appear in its original form, just before it is redacted, on your screen or wherever the session is shown (Remote Control, which is relayed through Anthropic's service to claude.ai or the Claude app, or an SDK stream).
- The guard rewrites only what Claude Code sends to the model. Other channels are separate, are not covered and may receive original values: Remote Control (relayed through Anthropic's service to claude.ai or the Claude app), command hooks in your settings, a telemetry collector your organisation configured, and reports you send to Anthropic.
- The on-screen mask is visual only: copying, selecting, screen readers, terminal search, and terminal recordings or logs (for example tmux capture or asciinema) still get the real text, and a screen recording shows it whenever the pointer hovers over it unless recording mode (`/pdpa-blur record`) is on. Recording mode does not cover the prompt box before you send, tool or command output, or the original text shown anywhere else. Terminals that raise text contrast automatically (for example VS Code's integrated terminal, with its minimum contrast ratio setting on by default) may draw the masked text readable. The mask works only in the terminal and the desktop app, and text longer than 100,000 characters is not masked.
- The tool-call refusal catches only this session's placeholders written exactly as issued, and does nothing while the guard is `off`.
- A notice counts only what the rules matched. No notice does not mean that no personal data was sent, and a notice does not mean that the text is now clean.
- Claude sees only placeholders, so it cannot act on the real value, and redaction cannot be undone: turning the guard off does not bring back values already redacted. When a task needs the real value, run `/pdpa-guard off`, send the value again, and run `/pdpa-guard redact` when the task is done. While the guard is off, tool calls that contain earlier placeholders are not refused, so check what Claude writes.
- Anything sent while the guard is `off` stays in the conversation as it was sent. Turning the guard back on does not redact it, and it is sent again with every later request in that conversation. Run `/clear` or start a new session to drop it.
- `CLAUDE.md`, other context blocks and attachments keep the result from when Claude Code first prepared them, so changing the mode later does not affect content already prepared. Context blocks are prepared again after `/clear` or compaction.
- `CLAUDE.md` and other context blocks are redacted too, so Claude does not see values you put there on purpose, such as your own email address.
- Public data, such as an agency's published contact number, is redacted too if it matches a rule.
- The guard reduces what is sent. It does not stop Claude Code from sending the (redacted) conversation to your configured model provider (Anthropic by default).
- The mod works per user and per machine, and the user can switch it off at any time (`/pdpa-guard off`, `claude plugin disable`). It cannot be enforced centrally and keeps no audit log of what it redacted or what was sent, so it cannot show that a control was in place.

Notes that only this page adds:

- Names and addresses are caught only after specific labels (such as `ชื่อ`, `นามสกุล`, `full name`, `first name`, `ที่อยู่`, `home address`) or, for names, after a title (such as `นาย`, `นาง`, `Mr`, `Dr`); a bare English `name:` or `address:` label is not enough.
- An image or document block itself is not inspected, but text that a tool returns as a tool result, such as command output that prints a file's text, is.
- The system prompt also holds environment details such as the working-directory path, and its `memory` section. `CLAUDE.md` is not part of the system prompt; it is sent as a context block and is redacted.
- Do not rely on pdpa-thai to keep original values from Remote Control or an SDK client the session streams to.

## AI guidance from Thai agencies

- **A draft AI guideline is on the PDPC website.** It was open for public comment from 19 to 25 February 2026 (B.E. 2569) ([page](https://www.pdpc.or.th/22291/)). It was **still a draft when checked on 2026-10-04**, and its content **has not been reviewed**. Check its current status with the PDPC.
- **ETDA and MDES** have published a guide on governance of generative AI ([ETDA news page](https://www.etda.or.th/th/pr-news/AI_Gov_Anual.aspx)). Only the title was checked.

## Where to complain or ask

| Need | Where |
| --- | --- |
| PDPC information and notifications | [pdpc.or.th](https://www.pdpc.or.th/) |
| Personal data complaint | [complaint.pdpc.or.th](https://complaint.pdpc.or.th/) |
| Legal questions | [consult.pdpc.or.th](https://consult.pdpc.or.th/) |
| A bug or mistake in pdpa-thai | [GitHub Issues](https://github.com/Boom-Vitt/boombignose-mods/issues) |
| A vulnerability in pdpa-thai | Follow [SECURITY.md](../SECURITY.md): report privately through GitHub's **Report a vulnerability** option if it is shown, otherwise use the fallback described there |

Never put real personal data in a public issue. Describe the format with made-up data instead.

## Developer checklist

- [ ] **Minimise at the source.** Let Claude read only what the task needs. Do not hand over a whole database dump or log file; pick the columns or lines you need.
- [ ] **Use synthetic test data** instead of real customer records in fixtures and seeds.
- [ ] **Review prompts before sending**, especially text copied from customer chats, tickets or admin panels.
- [ ] **Keep secrets in environment variables** or a secrets manager, not in code or `CLAUDE.md`.
- [ ] **Keep personal data out of `CLAUDE.md`** and other context files that are sent on every turn.
- [ ] **Use Claude Code permission settings** to deny access to files and folders that hold real data, and check the Claude Code documentation for what those rules do and do not cover.
- [ ] **Mask personal data in application logs** when it is logged.
- [ ] **Run pdpa-thai in `redact` or `block` mode**, and read the limits in [DETECTION.en.md](DETECTION.en.md).
- [ ] **Before you record or share your screen**, run `/pdpa-blur record`, keep personal data out of the prompt box, other windows, and tool or command output, and check the recording before you share it.
- [ ] **Check your organisation's policy**: which AI tools are allowed, for which kinds of data, and whether there is an agreement with the provider.
- [ ] **Check your client contract** if your team processes data on a client's behalf.
- [ ] **Get advice** from your DPO or a lawyer, and ask the PDPC for an official interpretation.
- [ ] **Know what to do when it goes wrong.** If personal data was sent by mistake, report it through your organisation's breach response process.

## Sources and verification

| Claim in this document | Source | Checked |
| --- | --- | --- |
| Definitions in section 6 | [Personal Data Protection Act B.E. 2562, PDF hosted by the PDPC](https://www.pdpc.or.th/wp-content/uploads/2023/12/1_Personal-Data-Protection-2562.pdf) | 2026-10-04 |
| Consent, section 19 | Same as above | 2026-10-04 |
| Sensitive data categories, section 26 | Same as above | 2026-10-04 |
| Cross-border transfer, sections 28–29 | Same as above | 2026-10-04 |
| Security measures duty, section 37 | Same as above | 2026-10-04 |
| Data processor duties, section 40 | Same as above | 2026-10-04 |
| Section 28 criteria notification (B.E. 2566) | https://www.pdpc.or.th/2500/ and https://www.pdpc.or.th/wp-content/uploads/2024/01/M28.pdf | 2026-10-04 |
| Section 29 notification | https://www.pdpc.or.th/2507/ | 2026-10-04 |
| Whether sending a prompt to a cloud service counts as a transfer depends on the facts, including whether a third party can access the data | Section 28 and 29 notifications above | 2026-10-04 |
| Security measures notification (B.E. 2565) | https://www.pdpc.or.th/2971/ | 2026-10-04 |
| Breach notification page (title only) | https://www.pdpc.or.th/2405/ | 2026-10-04 |
| Breach report form page | https://www.pdpc.or.th/17259/ | 2026-10-04 |
| Draft AI guideline, public comment 19–25 February 2026 | https://www.pdpc.or.th/22291/ | 2026-10-04 |
| ETDA/MDES generative AI governance guide (title only) | https://www.etda.or.th/th/pr-news/AI_Gov_Anual.aspx | 2026-10-04 |
| PDPC channels | https://www.pdpc.or.th/ , https://complaint.pdpc.or.th/ , https://consult.pdpc.or.th/ | 2026-10-04 |
| pdpa-thai 0.3.0 behaviour | [`pdpa-thai/hooks/detect.ts`](../pdpa-thai/hooks/detect.ts), [`pdpa-thai/hooks/register.tsx`](../pdpa-thai/hooks/register.tsx), [`.github/workflows/test.yml`](../.github/workflows/test.yml) | 2026-10-06 |

## What was not verified

- **The Royal Gazette.** Its website blocked automated access, so the Act text used here is the PDF hosted by the PDPC. It has not been compared with the Gazette.
- **The content of the draft AI guideline on the PDPC website.** Not reviewed. The draft may change before it is issued.
- **The ETDA/MDES guide.** Title checked, content not reviewed.
- **The PDPC breach notification page.** Only the title was read, so notification conditions and time limits are not in this document.
- **Whether using a cloud AI service is a cross-border transfer.** No conclusion is drawn; it depends on the facts.
- **Penalties, fines and deadlines.** Deliberately out of scope.
- **The model provider's data handling** (Anthropic, or the cloud platform Claude Code is configured to use), such as where data is processed, how long it is kept and how it is used. Not covered here; check the provider's terms and your organisation's agreement.

Found something wrong or out of date? Please open a [GitHub issue](https://github.com/Boom-Vitt/boombignose-mods/issues).
