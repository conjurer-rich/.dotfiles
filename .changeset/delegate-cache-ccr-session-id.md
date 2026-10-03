---
"@conjurer-rich/dotfiles": patch
---

`delegating-github-issues`: in Claude Code on the web, the session id that `set_session_title` needs is fetched with `get_session` once per session instead of once per run. It is kept in `ccr-session-id` in the session's scratch directory, so every later `/loop /delegate` pass reuses it.
