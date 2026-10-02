# Fork release line

`conjurer-rich/.dotfiles` pulls from `citypaul/.dotfiles` and never merges back.
Its releases live here, not in the root `CHANGELOG.md` and `package.json`, so
pulling from upstream never conflicts over release history.

| File | Owner |
| --- | --- |
| `/CHANGELOG.md`, `/package.json` | upstream — never edit in the fork |
| `fork/CHANGELOG.md`, `fork/package.json` | this fork |
| `claude/.claude/.claude-plugin/plugin.json` `version` | this fork — written by `fork/sync-plugin-version.mjs`, never by hand |

## Adding a changeset

Name the fork's package, not upstream's:

```md
---
"@conjurer-rich/dotfiles": patch
---

What changed, for someone installing the fork.
```

`release.yml` tags `v<fork/package.json version>`, which `install-rich.sh`
resolves as the latest release. Its `version` command is `bash fork/version.sh`:
changesets/action execs that input without a shell, so it has to be one
command, and the script runs `changeset version` and then copies the new
version into the craft plugin manifest (`claude/.claude/.claude-plugin/plugin.json`): Claude
Code offers a marketplace plugin update when the manifest version changes,
not when commits land, so a manifest left behind pins installed copies to an
old release. `test/plugin-version-sync.sh` fails when the two drift.

## Pulling from upstream

```sh
git fetch upstream   # remote.upstream.tagOpt is --no-tags: upstream's v* tags would clash with ours
git merge upstream/main
```

If the merge brings in an upstream changeset naming `@citypaul/dotfiles`
that upstream has not released yet, delete it: this workspace has no package
by that name, so `changeset version` fails on it.
