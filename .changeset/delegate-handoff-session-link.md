---
"@conjurer-rich/dotfiles": patch
---

delegating-github-issues: every run that hits its context or tool-call limit hands off, and the report links to the new session

**Hand-off** step 5 now reports the new session as a clickable link, `[<id>](https://claude.ai/code/<session id>)`, instead of a bare id, so the human can open the session that carries the loop on without hunting for it in the sidebar. The `[handed off → <id>] <title>` retitle is unchanged.

A run started by hand (`/delegate #<n>`, `/delegate review #<n>`) that trips the **Stop rule** on context or tool calls now hands off too, not only a run under `/loop`: the new session runs the same `/delegate` command with a fresh context. A stop on isolation-guard refusals still never hands off.
