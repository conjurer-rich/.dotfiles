---
"@conjurer-rich/dotfiles": patch
---

`/delegate` reads `.claude/delegation.md` from the repository's top level instead of the session's working directory, so it finds the project's settings when the session starts in a subdirectory. In a linked worktree it reads that worktree's own copy. Outside a repository it still reports `none`.
