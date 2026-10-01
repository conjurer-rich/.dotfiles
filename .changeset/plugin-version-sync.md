---
"@conjurer-rich/dotfiles": patch
---

The craft plugin manifest (`claude/.claude/.claude-plugin/plugin.json`) now carries the fork's release version. Claude Code detects a marketplace plugin update from that field, and it had been pinned at 4.12.2 since the manifest was added, so installed copies were never offered newer releases. `release.yml` syncs it on every version bump through `fork/sync-plugin-version.mjs`, and a test fails when the two drift.
