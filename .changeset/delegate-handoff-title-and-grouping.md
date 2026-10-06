---
"@conjurer-rich/dotfiles": patch
---

delegating-github-issues: a handed-off session says so in its title, and its successor is grouped under the repository

When **Hand-off** starts the next session, the stopped session renames itself `[handed off → <id>] <title>`, where `<id>` is the last 8 characters of the new session's id (the end of its URL). A loop that ends without a next session renames itself `[loop ended] <title>`. Both keep the last item's title after the prefix.

`create_session` is now called with `outcome_branch` (this session's own outcome branch, kept in `ccr-outcome-branch` alongside `ccr-session-id`). Without it the new session recorded no repository and the Claude Code on the web sidebar filed it under "Other" instead of with the repository's other sessions.
