---
"@citypaul/dotfiles": minor
---

Add `install-rich.sh`, a fork wrapper around `install-claude.sh`. It installs from this fork, layers a local CLAUDE.md over upstream's, and installs the fork's own skills (`browser-ux-walkthrough`, `delegating-github-issues`), which upstream's manifest does not name. The installer's source repository, CLAUDE.md destination and extra skill names can now be overridden from the environment through `DOTFILES_BASE_URL`, `DOTFILES_OWN_SKILLS_REPO`, `DOTFILES_CLAUDE_MD_DEST` and `DOTFILES_EXTRA_SKILLS`. Unset, the installer behaves exactly as before.
