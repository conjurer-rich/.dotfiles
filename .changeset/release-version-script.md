---
"@conjurer-rich/dotfiles": patch
---

Fix the release workflow: changesets/action execs its `version` input without a shell, so the `pnpm changeset version && node …` chain from the manifest-sync change handed changesets a literal `&&` and every release run since failed before versioning anything. The workflow now runs `bash fork/version.sh`, which does both steps. Also register the commit-and-push stop hook (`claude/.claude/hooks/stop-hook-git-check.sh`, with its delegator exemption) as a `Stop` hook in the stowed `settings.json`.
