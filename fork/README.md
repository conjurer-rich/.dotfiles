# Fork release line

`conjurer-rich/.dotfiles` pulls from `citypaul/.dotfiles` and never merges back.
Its releases live here, not in the root `CHANGELOG.md` and `package.json`, so
pulling from upstream never conflicts over release history.

| File | Owner |
| --- | --- |
| `/CHANGELOG.md`, `/package.json` | upstream — never edit in the fork |
| `fork/CHANGELOG.md`, `fork/package.json` | this fork |

## Adding a changeset

Name the fork's package, not upstream's:

```md
---
"@conjurer-rich/dotfiles": patch
---

What changed, for someone installing the fork.
```

`release.yml` tags `v<fork/package.json version>`, which `install-rich.sh`
resolves as the latest release.

## Pulling from upstream

```sh
git fetch upstream   # remote.upstream.tagOpt is --no-tags: upstream's v* tags would clash with ours
git merge upstream/main
```

If the merge brings in an upstream changeset naming `@citypaul/dotfiles`
that upstream has not released yet, delete it: this workspace has no package
by that name, so `changeset version` fails on it.
