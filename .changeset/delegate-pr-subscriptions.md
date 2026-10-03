---
"@conjurer-rich/dotfiles": patch
---

`delegating-github-issues`: in Claude Code on the web, where the `subscribe_pr_activity` tool of the `claude-code-remote` MCP server is available, Watch subscribes each delegated PR once (Work subscribes the PR it opens) and leaves no background poll: a comment, a Ready click or a CI result wakes the session for one Watch pass. Elsewhere, the minute-by-minute background poll stays, over REST. `/delegate` pre-approves the subscribe and unsubscribe tools.
