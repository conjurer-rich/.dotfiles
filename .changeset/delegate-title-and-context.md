---
"@conjurer-rich/dotfiles": minor
---

`/delegate` now stops a run at 80 % context instead of 60 %. A delegator session also keeps the title of the last item it worked on after releasing its claim, instead of renaming itself `/delegate watching <owner>/<repo>` at the end of every pass, so each PR can be traced back to the session that handled it. Work renames the session to `PR #P (#N) <issue title>` once it opens the PR; only a session that has not worked an item yet uses the watching form.
