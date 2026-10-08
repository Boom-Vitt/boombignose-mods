# boombignose-mods

Mods for Claude Code: a guard that helps reduce the personal data sent to the model (`pdpa-thai`), a context usage bar (`context-bar`), an agents side pane (`agents-panel`) and a multi-agent workflow (`boom-big-nose-workflow`).

[![License: MIT](https://img.shields.io/badge/License-MIT-1F7A4D?style=flat-square)](LICENSE)
[![tests](https://img.shields.io/github/actions/workflow/status/Boom-Vitt/boombignose-mods/test.yml?branch=main&style=flat-square&label=tests)](https://github.com/Boom-Vitt/boombignose-mods/actions/workflows/test.yml)
[![For Claude Code](https://img.shields.io/badge/for-Claude_Code-555555?style=flat-square)](https://code.claude.com/docs/en/plugins)

[ไทย](README.md) · **English**

[Install](#install) · [Mods](#mods) · [pdpa-thai](#pdpa-thai) · [Limits](#limits) · [Can I trust it?](#can-i-trust-it) · [FAQ](#faq) · [PDPA and this mod](docs/PDPA.en.md) · [Detection rules](docs/DETECTION.en.md)

> **Notice.** This is an unofficial community project maintained by one individual. It is not affiliated with, endorsed by, or certified by Anthropic, the Personal Data Protection Committee Office (PDPC), the Electronic Transactions Development Agency (ETDA), the Digital Government Development Agency (DGA), the Ministry of Digital Economy and Society (MDES), or any Thai government body. The names `pdpa-thai` and `/pdpa-guard` and the status text `PDPA: <mode>` refer to Thailand's Personal Data Protection Act only because the rules are modelled on the kinds of data it covers; they do not indicate compliance. Claude and Claude Code are Anthropic's products; the names only say what these mods work with.
>
> Nothing here is legal advice. For legal questions, ask a qualified lawyer or your organisation's data protection officer (DPO). For official interpretation, refer to the [PDPC](https://www.pdpc.or.th/). The software is provided as is, without warranty of any kind (see the [MIT licence](LICENSE)). Detection uses regular expressions on a best-effort basis: it **will** miss some personal data, and it **will** flag some harmless text.

## What and why

Everything in a Claude Code conversation is sent to the model: what you type, files Claude reads, command output and your `CLAUDE.md`. When you work with customer records, job applications or system logs, personal data such as Thai national ID numbers, phone numbers or email addresses can end up in a request without anyone meaning to send it.

`pdpa-thai` looks for common Thai and international personal data formats inside the Claude Code process and replaces each detected value with a placeholder before Claude Code sends the conversation. It is designed to help reduce risk. Installing it does not make an organisation compliant with Thailand's Personal Data Protection Act B.E. 2562 (2019) (PDPA) or any other law, and it does not replace a review by a qualified person.

The other mods are general productivity tools and have nothing to do with the PDPA.

## Install

Requires a Claude Code build that supports hook-module plugins. Tested only with Claude Code 2.1.289. The hook API is early access, so an older or newer build may skip some or all of the guard without warning; the CI badge shows only that the unit tests pass on the latest build.

```bash
claude plugin marketplace add Boom-Vitt/boombignose-mods
claude plugin install pdpa-thai@boombignose-mods
claude plugin install context-bar@boombignose-mods
claude plugin install agents-panel@boombignose-mods
claude plugin install boom-big-nose-workflow@boombignose-mods
```

Each mod works on its own; install only the ones you want.

In Codex, only `boom-big-nose-workflow` is available, because the other mods rely on Claude Code-only features:

```bash
codex plugin marketplace add Boom-Vitt/boombignose-mods
codex plugin add boom-big-nose-workflow@boombignose-mods
```

Update to the latest version:

```bash
claude plugin marketplace update boombignose-mods
claude plugin update pdpa-thai@boombignose-mods
```

Restart Claude Code to apply the update.

Disable for now, or uninstall:

```bash
claude plugin disable pdpa-thai@boombignose-mods
claude plugin uninstall pdpa-thai@boombignose-mods
```

## Mods

| Mod | Version | Command | What it does |
|---|---|---|---|
| `pdpa-thai` | 0.3.0 | `/pdpa-guard [redact\|block\|off]`, `/pdpa-blur [on\|off\|record]` | Redacts personal data it detects before it is sent to Claude, and masks it on screen (hover to reveal; in recording mode hovering does not reveal it) |
| `context-bar` | 0.4.0 | `/context-bar` | A bar above the prompt showing context window use by category and the time left on the prompt cache |
| `agents-panel` | 0.1.0 | `/agents-panel` | A side pane listing project, user and plugin agents, each with a run button |
| `boom-big-nose-workflow` | 0.4.0 | `/bbn-plan`, `/bbn-review`, `/bbn-merge` and the other `/bbn-*` commands | The BBN workflow: one worktree per feature, planner, implementer, integrator and reviewer agents, merge through a gate ([README](boom-big-nose-workflow/README.md#english), [diagram](boom-big-nose-workflow/docs/workflow-diagram.md)) |

`/context-bar` and `/agents-panel` toggle on and off. `/pdpa-blur` toggles too, or takes `on`, `off` or `record`. `/pdpa-guard` takes a mode name.

- `context-bar` counts down assuming a 5-minute prompt-cache lifetime (a constant in the code).
- The `▶ run` button in `agents-panel` starts that subagent with the fixed prompt `Run the <name> agent on the current project.` The subagent runs like any other agent: its conversation goes to your configured model provider (Anthropic by default), and it can act on the project under your usual permissions.

Per-mod release notes are in [CHANGELOG.md](CHANGELOG.md).

## pdpa-thai

### Three layers

1. **Outbound guard.** Detects and redacts data before it is sent to the model. It covers:
   - the prompt you type;
   - messages the conversation keeps, such as tool result text and context added by other hooks;
   - text attached to a request, such as files mentioned with `@`, `CLAUDE.md` and other context blocks.

   Only text blocks and the text inside tool results are rewritten. Other blocks, such as images and documents, are sent unchanged.
2. **Tool-call refusal.** While the guard is on (`redact` or `block`), a tool call from Claude that contains a placeholder issued in this session, written exactly as issued, is refused, and Claude is told to ask you for the real value. This helps keep placeholders out of real files and commands. It does not catch a placeholder Claude has altered or one from an earlier session, and it does nothing while the guard is `off`.
3. **On-screen mask (hover blur).** Detected data that is still on screen in your messages and Claude's messages is drawn as a grey block; hover to reveal it. In `redact` mode your prompt is already shown with placeholders, the conversation keeps only the redacted prompt, and the mod keeps no copy of the original, so the mask mainly matters for Claude's replies and for text sent while the guard is `off`. The mask is on by default and works in the terminal and the desktop app only. For screen recording or screen sharing, `/pdpa-blur record` keeps the mask on and stops hover from revealing anything; see [Recording or sharing your screen](#recording-or-sharing-your-screen).

### Modes

| Mode | Behaviour |
|---|---|
| `redact` (default) | Replaces each detected value with a placeholder before it is sent to Claude |
| `block` | Refuses to send a prompt that contains detected personal data; rewrite it without the personal data and send again. Tool results, attachments and context are still redacted as in `redact` |
| `off` | Turns off both redaction and the tool-call refusal (the on-screen mask is controlled separately by `/pdpa-blur`) |

The mode and the mask settings are not saved to disk and start as `redact` with the mask on and recording mode off whenever Claude Code starts; whether `/clear` keeps the current mode has not been verified by the maintainer (run `/pdpa-guard` with no argument, or look at the status line, to see the current mode).

### Commands

```text
/pdpa-guard           show the current mode
/pdpa-guard redact    redact before sending (default)
/pdpa-guard block     refuse prompts that contain detected personal data
/pdpa-guard off       turn the guard off
/pdpa-blur            toggle the on-screen mask (on if it is off; off if it is on or recording)
/pdpa-blur on         mask on, hover to reveal
/pdpa-blur off        mask off
/pdpa-blur record     recording mode: mask on, hover does not reveal
```

Any other argument to `/pdpa-blur` changes nothing and prints a usage line.

The status line shows `PDPA: <mode>`, with ` · REC` added in recording mode (for example `PDPA: redact · REC`). When the mod redacts a prompt or a message the conversation keeps, or holds back a prompt, a toast reports how many items it found. Redaction of `CLAUDE.md`, other context blocks and attachments such as files mentioned with `@` is silent. A notice counts only what the rules matched: no notice does not mean that no personal data was sent, and a notice does not mean that the text is now clean.

**Check that it is running.** After Claude Code starts, the status line should show `PDPA: redact` or `PDPA: block`. If it does not, the mod did not load and nothing is redacted; run `claude --debug` to see why. Headless runs (such as `claude -p`) show no status line, so check the debug output before you rely on the guard there.

### Recording or sharing your screen

`/pdpa-blur record` turns on recording mode, for screen recording and screen sharing. The mask stays on, and hovering does not reveal a masked value while recording mode is on. Like the rest of the mask, it works only in the terminal and the desktop app, it is not saved to disk, and Claude Code starts with the mask on and recording mode off. Run `/pdpa-blur on` or `/pdpa-blur off` to leave it. Stop recording before you leave recording mode: `/pdpa-blur on` brings hover reveal back, and `/pdpa-blur` with no argument turns the mask off. Claude Code also starts again with recording mode off, so check the status line after any restart or resume.

Recording mode masks detected values only in your messages and Claude's messages. Everything else Claude Code draws, including tool calls and their output, file diffs, thinking, notices and other panes, is shown as is.

Recording mode does **not** cover:

- personal data the rules do not detect, such as a name without a label or title (see [Limits](#limits)): it is shown as written and is not masked;
- text you type in the prompt box before you send it (the guard replaces it only when you submit);
- tool calls, tool output and command output on screen;
- the original text if it is on screen for any other reason, such as a file open in another window;
- selecting text, which may make the masked text readable on screen; copying yields the real text.

In `redact` mode your own sent prompts already show placeholders, so the mask matters mainly for Claude's replies and for text sent while the guard was `off`. The other mask limits under [Limits](#limits) still apply.

Before you record or share:

1. Set the guard to `redact` or `block` (`/pdpa-guard redact`).
2. Run `/pdpa-blur record` and check that the status line ends in `· REC`.
3. Check the recording before you share it.

It is a visual mask, not a guarantee.

### Before and after

What you type (real values are described in angle brackets):

```text
Draft an email to the customer, phone <10-digit Thai mobile number>, email <customer's email address>
```

What Claude receives in `redact` mode:

```text
Draft an email to the customer, phone [REDACTED:PHONE_1~k3x9q], email [REDACTED:EMAIL_1~k3x9q]
```

The placeholder format is `[REDACTED:<KIND>_<n>~<session suffix>]`.

- The kind tells Claude what sort of value was there, so it can still write a reply that refers to it.
- The same value repeated within one piece of text (your prompt, one tool result, one attached file, or the context blocks) gets the same placeholder. Numbering restarts for each of these, so `PHONE_1` in your prompt and `PHONE_1` in a file you attach with `@`, or in a later tool result, may be different numbers.
- The 5-character session suffix lets the mod tell the placeholders it issued in this session apart from text that merely mentions the format, such as this README.
- Redaction is one-way. The mod keeps no table for turning a placeholder back into the original value.

### What it detects

| Kind | What is matched |
|---|---|
| `THAI_ID` | 13-digit Thai national ID number whose check digit is valid under the mod-11 formula |
| `CARD` | 13- to 19-digit payment card number that passes the Luhn check |
| `PHONE` | Thai mobile and landline numbers, including the +66 and 0066 forms |
| `EMAIL` | Email addresses, except those at exactly example.com, example.org or example.net (subdomains are still redacted) |
| `IP` | IPv4 addresses, except 127.x.x.x and 0.0.0.0 |
| `SECRET` | Tokens with known prefixes, `Bearer` tokens, and values after labels such as password, secret, token, api_key, รหัสผ่าน. Not a secret scanner: only the shapes listed in [DETECTION](docs/DETECTION.en.md) are matched, and values that look like code are skipped |
| `PASSPORT` | Passport numbers next to a label such as passport, เลขที่หนังสือเดินทาง, พาสปอร์ต |
| `BANK_ACCOUNT` | 10 to 15 digits next to a label such as เลขที่บัญชี, บัญชี, account no., พร้อมเพย์, PromptPay |
| `DOB` | A numeric date (digits separated by /, . or -) next to a label such as วันเกิด, date of birth, DOB. Dates written with month names are not matched |
| `SENSITIVE` | The value after a label for most section 26 sensitive categories, only when written as `label: value` in Thai or English, e.g. religion, health condition, criminal record. Other wordings, and other data the Personal Data Protection Committee may prescribe, are not covered |
| `ADDRESS` | A value written as `label: value` when the label is ที่อยู่, home address or mailing address; a plain `address:` label is not matched |
| `NAME` | A value written as `label: value` with a label such as ชื่อ, นามสกุล, full name, surname; and names after the Thai titles นาย, นาง, นางสาว, น.ส., ด.ช., ด.ญ. or Mr, Mrs, Ms, Miss, Dr |

For `SENSITIVE`, `ADDRESS` and `NAME`, `label: value` also covers `label = value`, a full-width colon (`：`), and quoted JSON keys such as `"label": "value"`. A labelled value stops at the first comma, semicolon, quote, `}` or line break; the rest of an address or list is sent as written. A value that opens with `[` or `{` (a JSON array or object) is not matched by these rules at all, so nothing in it is replaced unless another rule, such as `PHONE` or `EMAIL`, matches it.

Every rule reads Thai digits (๐-๙) as Arabic digits.

The sensitive categories follow section 26 of the Personal Data Protection Act B.E. 2562 (2019) ([PDF hosted by the PDPC](https://www.pdpc.or.th/wp-content/uploads/2023/12/1_Personal-Data-Protection-2562.pdf), checked 2026-10-04). The full label lists, exceptions and known false positives are in [docs/DETECTION.en.md](docs/DETECTION.en.md).

### Where your data goes

- Detection and redaction run inside the Claude Code process: on your machine for a local session, or wherever a cloud or remote session runs. In a cloud or remote session the original values are already on that machine before the mod runs; the mod only changes what is sent from there to the model.
- `pdpa-thai` and `context-bar` make no network, external process, model or MCP calls of their own. `agents-panel` starts a subagent (`$.agent.spawn`) only when you press `▶ run`; that subagent runs like any other agent.
- `boom-big-nose-workflow` has no hook code. Its commands run its own scripts (git, node, `claude mcp list`, and `gh` for the `/bbn-doctor` sign-in check and `/bbn-merge --apply --pr`) and start planner, implementer, integrator and reviewer subagents, which run like any other agent. It also adds two remote MCP servers, Context7 (`https://mcp.context7.com/mcp`) and Perplexity (`https://api.perplexity.ai/mcp`, sign-in required); queries the agents send to a connected server go to that service.
- On every push and pull request, CI runs two local-only checks: a text search of every mod's hook code for network, process, model and MCP calls and for `fetch(`, and a check that every engine call on the `calls:` line printed by `claude plugin validate pdpa-thai` is a state, ui, clock or command call. Neither check proves anything about other mods or about Claude Code itself. Both checks, and what they miss, are described in one place: [What CI runs](CONTRIBUTING.md#what-ci-runs).
- The redacted conversation is still sent to your configured model provider (Anthropic by default, or for example Amazon Bedrock or Google Cloud Vertex AI), like any Claude Code conversation.
- This mod does not change how your configured model provider (Anthropic by default) stores, retains or uses what it receives; that is set by your agreement and settings with that provider.
- Redaction applies to the copy the model reads: each detected occurrence is replaced with a placeholder before it is sent to the model. The same value can still be sent if it also appears somewhere the guard does not rewrite (see [Limits](#limits)), and anything the rules miss is sent as is.
- Redaction is not anonymisation. The redacted conversation can still identify a person directly or indirectly, which is how section 6 of the PDPA defines personal data ([PDF hosted by the PDPC](https://www.pdpc.or.th/wp-content/uploads/2023/12/1_Personal-Data-Protection-2562.pdf), checked 2026-10-04), so it may still be personal data, and questions such as lawful basis and cross-border transfer may still apply. Ask a qualified lawyer or your organisation's DPO.
- The guard rewrites only what Claude Code sends to the model. Other channels are separate, are not covered and may receive original values: Remote Control (relayed through Anthropic's service to claude.ai or the Claude app), command hooks in your settings, a telemetry collector your organisation configured, and reports you send to Anthropic.

### Limits

- Every rule is a best-effort regular expression. It **will** miss some personal data and **will** flag some harmless text.
- It is not a secret scanner. Only the token shapes and labels listed in [DETECTION](docs/DETECTION.en.md#secrets-secret) are matched, and values that look like code are skipped. Keep secrets out of sessions and use a dedicated secret scanner.
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
- The on-screen mask is visual only: copying, selecting, screen readers, terminal search, and terminal recordings or logs (for example tmux capture or asciinema) still get the real text, and a screen recording shows it whenever the pointer hovers over it unless recording mode (`/pdpa-blur record`) is on. Recording mode does not cover the prompt box before you send, tool or command output, or the original text shown anywhere else (see [Recording or sharing your screen](#recording-or-sharing-your-screen)). Terminals that raise text contrast automatically (for example VS Code's integrated terminal, with its minimum contrast ratio setting on by default) may draw the masked text readable. The mask works only in the terminal and the desktop app, and text longer than 100,000 characters is not masked.
- The tool-call refusal catches only this session's placeholders written exactly as issued, and does nothing while the guard is `off`.
- A notice counts only what the rules matched. No notice does not mean that no personal data was sent, and a notice does not mean that the text is now clean.
- Claude sees only placeholders, so it cannot act on the real value, and redaction cannot be undone: turning the guard off does not bring back values already redacted. When a task needs the real value, run `/pdpa-guard off`, send the value again, and run `/pdpa-guard redact` when the task is done. While the guard is off, tool calls that contain earlier placeholders are not refused, so check what Claude writes.
- Anything sent while the guard is `off` stays in the conversation as it was sent. Turning the guard back on does not redact it, and it is sent again with every later request in that conversation. Run `/clear` or start a new session to drop it.
- `CLAUDE.md`, other context blocks and attachments keep the result from when Claude Code first prepared them, so changing the mode later does not affect content already prepared. Context blocks are prepared again after `/clear` or compaction.
- `CLAUDE.md` and other context blocks are redacted too, so Claude does not see values you put there on purpose, such as your own email address.
- Public data, such as an agency's published contact number, is redacted too if it matches a rule.
- The guard reduces what is sent. It does not stop Claude Code from sending the (redacted) conversation to your configured model provider (Anthropic by default).
- The mod works per user and per machine, and the user can switch it off at any time (`/pdpa-guard off`, `claude plugin disable`). It cannot be enforced centrally and keeps no audit log of what it redacted or what was sent, so it cannot show that a control was in place.

## Can I trust it?

Do not take this README's word for it; check it yourself.

- All code is open source under the MIT licence. There is no `package.json`, so there are no third-party dependencies; code in `hooks/` imports only the Claude Code API (`claude-code`) and the mod's own files.
- The `pdpa-thai` tests live in `pdpa-thai/tests/`. The samples are made-up values: some are assembled from fragments, some are obviously fictional, and some must have a valid format (such as a passing check digit) so that the rules match them.
- CI in [`.github/workflows/test.yml`](.github/workflows/test.yml) runs on every push and pull request. It validates the marketplace and every mod manifest, runs the tests, and runs the two local-only checks described under [Where your data goes](#where-your-data-goes).
- Both checks read the source code; they are not a formal proof, and a call written in an unusual way can slip past them. They say nothing about other mods or about Claude Code itself. What they cover and miss is listed in [CONTRIBUTING.md](CONTRIBUTING.md#what-ci-runs). Read the code as well.

### Audit it in 10 minutes

```bash
git clone https://github.com/Boom-Vitt/boombignose-mods
cd boombignose-mods
```

1. Read `pdpa-thai/hooks/detect.ts` (about 280 lines). The `RULES` array is every detection rule; `redact()` does the replacement.
2. Read `pdpa-thai/hooks/register.tsx` (about 190 lines). Every point where the mod hooks into Claude Code is an `on(...)` call: `session.start`, `prompt.submit`, `session.append`, `prompt.attachment`, `prompt.context`, `tool.call`, `ui.render` and `command.run`.
3. Run the main CI checks. The first command should print nothing. In the output of `claude plugin validate pdpa-thai`, the `calls:` line should list only `$.state`, `$.ui`, `$.clock` and `$.command` calls.

```bash
grep -rnE '\$\.(http|process|model|mcp)\b|\bfetch\(' --include='*.ts' --include='*.tsx' --exclude-dir=tests */hooks
claude plugin validate .
claude plugin validate pdpa-thai
claude plugin test pdpa-thai
```

## FAQ

**Does installing this make me PDPA compliant?**

No. Installing this mod alone does not make an organisation compliant with the PDPA. The mod is only a technical tool designed to help reduce how much personal data is sent; whether it counts towards any measure the law requires is for your organisation to assess. Note that the mod is per user, the user can switch it off, and it keeps no audit log (see [Limits](#limits)). Duties under the Personal Data Protection Act B.E. 2562 ([PDF hosted by the PDPC](https://www.pdpc.or.th/wp-content/uploads/2023/12/1_Personal-Data-Protection-2562.pdf), checked 2026-10-04), such as the rules on consent (section 19), security measures (section 37) and cross-border transfer (sections 28-29), depend on your organisation's facts. Whether using a cloud AI service counts as a cross-border transfer also depends on the facts (see the [section 28 notification](https://www.pdpc.or.th/2500/), checked 2026-10-04). Ask a qualified lawyer or your organisation's DPO, and look to the [PDPC](https://www.pdpc.or.th/) for official interpretation. A summary with sources is in [docs/PDPA.en.md](docs/PDPA.en.md).

**Does Anthropic still receive my conversation?**

Yes, or your configured model provider does. Claude Code still sends the conversation as usual. What changes is that detected values are replaced with placeholders before sending. Anything the rules miss is sent as is.

**How do I turn it off?**

`/pdpa-guard off` turns off redaction and the tool-call refusal. The mode and the mask settings are not saved to disk and start as `redact` with the mask on and recording mode off whenever Claude Code starts; whether `/clear` keeps the current mode has not been verified by the maintainer (run `/pdpa-guard` with no argument, or look at the status line, to see the current mode). `/pdpa-blur off` turns the on-screen mask off, and `/pdpa-blur` with no argument toggles it. To turn off the whole mod, run `claude plugin disable pdpa-thai@boombignose-mods`.

**Harmless text was redacted (a false positive). What should I do?**

Common cases are 13-digit numbers such as millisecond timestamps or order numbers (roughly 1 in 10 passes the national ID check), a reference number that happens to pass the Luhn check, a server's internal IP address that is not linked to a person or a four-part version number, and log lines such as `stack trace: ...` (the label `race` matches inside `trace`) or `pwd: /srv/app`. Rephrase the text, or run `/pdpa-guard off`, send it again, then run `/pdpa-guard redact` (what is sent meanwhile stays in the conversation; see [Limits](#limits)). To report it, open an issue with a made-up example only. Never paste real personal data.

**Why does Claude say it cannot see the real value, or refuse a tool call?**

Claude sees only the placeholder, and the mod refuses tool calls that use one of this session's placeholders as a real value in a file or command. Enter the real value yourself, or, if you, and your organisation's policy, accept sending it, run `/pdpa-guard off` and send it again (what is sent meanwhile stays in the conversation; see [Limits](#limits)).

## Reporting a vulnerability

Please do not open a public issue for a security problem. [SECURITY.md](SECURITY.md) explains how to report privately: through a GitHub private security advisory if the **Report a vulnerability** option is shown on the repository's Security tab, or otherwise through the fallback described there.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md). All sample data in tests and issues must be made up, and any statement about law needs a source URL and the date it was checked.

## Licence

[MIT](LICENSE) © 2026 Boom-Vitt

## Original repository

This project is published only at https://github.com/Boom-Vitt/boombignose-mods and through the `boombignose-mods` marketplace added from it. Forks, mirrors and re-uploads elsewhere are not maintained by this project's maintainer; review the code before installing from any other source.
