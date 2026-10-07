---
"@conjurer-rich/dotfiles": patch
---

delegating-github-issues: on Claude Code on the web, `/loop /delegate` schedules its next pass with a server-side `send_later` reminder

The container behind a web session is reclaimed while the session is idle, and a `ScheduleWakeup` timer is lost with it, so the loop stalled until a PR event or the human woke it. **Watch** step 6 now calls `send_later` where the tool exists, and never `ScheduleWakeup` as well; the CLI keeps `ScheduleWakeup`. The reminder's id is kept in `run-state.json` as `next_pass_trigger`, every pass cancels a reminder that has not fired yet before it starts, and **Hand-off** cancels it too, so at most one pending pass exists and a handed-off session never wakes again. `/delegate` pre-approves `send_later` and `delete_trigger`.
