# Windows install + upstream tracking

**Date:** 2026-08-14
**Status:** Approved design, not yet implemented

## Problem

This repository is a fork of `citypaul/.dotfiles` at `conjurer-rich/.dotfiles`. Two
things do not work today:

1. **The installer ignores this fork.** `install-claude.sh` hardcodes
   `citypaul/.dotfiles` as both the download base and the skills source. Running it
   here installs citypaul's latest release, never this working tree.
2. **Windows installation is undocumented and partly blocked.** The bash installer
   runs under Git Bash, but the Node toolchain is too old for the pinned skills CLI.

The goal is a fork that takes citypaul's work as a base, adds local customisations on
top, and can pull upstream changes in with low friction — installable on Windows.

## Goals

- Install this fork's content (upstream base + local additions) on Windows
- Update from upstream with a routine `git merge`, not conflict archaeology
- Keep local customisations additive, in files upstream does not own
- Preserve the installer's existing safety properties: pinned revisions, declared
  skill names, backup-before-replace

## Non-goals

- A PowerShell port of the installer. Git Bash runs it; a port would be a second
  implementation to keep in sync for no benefit.
- Windows support for `install.sh` (the stow-based terminal dotfiles). Out of scope;
  it targets macOS tooling (`pinentry-mac`, karabiner, `~/Library/...`).
- Editing upstream's skill content. Customisation is additive by decision.

## Verified environment facts

Established by direct probe on 2026-08-14, not assumed:

| Fact | Detail |
|---|---|
| Git Bash present | GNU bash 5.2.37 (MSYS), with git, curl, GNU `mktemp`/`sed`/`sort`/`grep` |
| Installer parses and runs | `bash ./install-claude.sh --help` exits 0 |
| Version resolution works | `git ls-remote` + `sed` + `sort -k2 -V` resolve citypaul's `v4.12.2` correctly |
| Node too old | `v20.20.0` installed; `skills@1.5.22` requires `>=22.20.0`. npm warns `EBADENGINE` and proceeds anyway |
| No symlink problem | Installer passes `--copy` to the skills CLI, sidestepping Windows symlink privilege |
| Fork not detected | `own_checkout()` greps the remote for `citypaul/.dotfiles`; this remote is `conjurer-rich/.dotfiles`, so it returns false |
| Fork has no tags | `git ls-remote --tags origin 'v*'` returns nothing |
| Working tree is CRLF | `core.autocrlf=true`, no `.gitattributes`. Shebangs carry a CR; MSYS2 tolerates it, WSL would not |
| CLAUDE.md divergence | 159 real differing lines (not 213 — the rest was CRLF noise). Local file is a strict superset by section |

### No safe dry-run exists

The skills CLI resolves `~` from Windows `USERPROFILE`, ignoring both `HOME` and
`CLAUDE_CONFIG_DIR` when those are redirected under Git Bash. A sandboxed
`list -g` reported the real `~\.agents\skills` and `~\.codex\skills`. Any install
attempt writes to the real `C:\Users\Rich\.claude`. Implementation must therefore
treat every install run as live, and rely on the installer's own
`backup_selected_skills` and `backup_file` for recovery.

## Decisions

**Approach: fork with env-overridable installer constants.**

Rejected alternatives:

- *Slim overlay repo* (keep only local content; pin upstream as a ninth external
  source). Cleaner separation than needed given additive-only customisation, and it
  means owning a 1000-line installer with no git assistance when upstream improves it.
- *Hard-edited constants*. Five minutes today, then a merge conflict in
  `install-claude.sh` on every upstream update of an actively-developed file.

**CLAUDE.md: import layering.** Upstream's file installs verbatim to a separate
path; the local file imports it and appends local sections.

## Design

### 1. Repo relationship and update flow

Add an `upstream` remote pointing at `citypaul/.dotfiles`. Local customisations live
only in files upstream does not own:

- new skill directories under `claude/.claude/skills/`
- `claude/.claude/CLAUDE.rich.md` (the overlay, see §3)
- `install-rich.sh` (the wrapper, see §2)
- `.gitattributes`

Updating upstream becomes:

```bash
git fetch upstream
git merge upstream/main
```

Tag local releases as `v*` so `resolve_latest_release()` finds this fork. Without a
tag, version resolution falls through to citypaul's releases — the current behaviour.

### 2. Installer parameterisation

Four constants become environment-overridable, following the existing pattern of
`VERSION="${VERSION:-}"`:

| Location | Change |
|---|---|
| `install-claude.sh:41` | `BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/citypaul/.dotfiles}"` |
| `install-claude.sh:51` | `OWN_SKILLS_REPO_BASE="${OWN_SKILLS_REPO_BASE:-citypaul/.dotfiles}"` |
| `install-claude.sh:70` | `FIRST_PARTY_SKILLS` gains the names parsed from `$EXTRA_SKILLS` |
| `install-claude.sh:771` | CLAUDE.md destination becomes `${CLAUDE_MD_DEST:-$HOME/.claude/CLAUDE.md}` |

Defaults are unchanged, so upstream behaviour is identical when the variables are
unset. This keeps the permanent delta at four lines in a file upstream edits, which
is small enough that merges stay mechanical.

`EXTRA_SKILLS` is a **space-separated string**, not an array — environment variables
cannot carry bash arrays, so the installer splits it into names on read. This is a
correctness constraint, not a style choice.

A wrapper, `install-rich.sh`, sets the overrides, calls through, and then installs the
CLAUDE.md overlay:

```bash
#!/usr/bin/env bash
set -e

BASE_URL="https://raw.githubusercontent.com/conjurer-rich/.dotfiles" \
OWN_SKILLS_REPO_BASE="conjurer-rich/.dotfiles" \
CLAUDE_MD_DEST="$HOME/.claude/base-CLAUDE.md" \
EXTRA_SKILLS="skill-one skill-two" \
  ./install-claude.sh "$@"

# The overlay is this fork's own file; the base installer knows nothing about it.
install_overlay   # claude/.claude/CLAUDE.rich.md -> ~/.claude/CLAUDE.md, backed up first
```

The overlay installation is the wrapper's own responsibility and must back up any
existing `~/.claude/CLAUDE.md` before writing, matching `backup_file`'s behaviour at
`install-claude.sh:431`.

These four changes are upstreamable as a PR — they benefit anyone forking the repo,
and landing them upstream would reduce the local delta to zero.

### 3. CLAUDE.md layering

Two files, with a clean ownership split:

| File | Owner | Content |
|---|---|---|
| `~/.claude/base-CLAUDE.md` | upstream | citypaul's `claude/.claude/CLAUDE.md`, verbatim |
| `~/.claude/CLAUDE.md` | local | `@~/.claude/base-CLAUDE.md` import, then local sections |

The local overlay is short — an import line followed by the three sections that are
already local additions:

```markdown
@~/.claude/base-CLAUDE.md

## Global preferences (Rich)
...
## Skill Routing
...
## Skill Inventory
...
```

It is stored in the fork at `claude/.claude/CLAUDE.rich.md` and installed by the
wrapper. Upstream never creates that path, so it never conflicts.

This uses the pattern upstream documents at `MIGRATION.md:199-204`, with the absolute
`@~/.claude/...` form that `MIGRATION.md:221` recommends for reliability.

### 4. Windows enablement

Three items, in order of necessity:

1. **`fnm install 22 && fnm default 22`.** Hard blocker. `skills@1.5.22` requires
   Node `>=22.20.0`; npm's `EBADENGINE` is a warning, not a stop, so an unsupported
   CLI would otherwise perform filesystem mutations.
2. **`.gitattributes` with `*.sh text eol=lf`.** Removes the CRLF landmine. Scripts
   currently work only because MSYS2 tolerates a CR in the shebang; the same checkout
   fails under WSL, and files copied out of the tree carry CRs into `~/.claude`.
3. **Document `bash ./install-claude.sh`** as the Windows entry point in the README.

No installer logic changes for Windows.

### 5. Testing

`test/run.sh` already covers installer behaviour, including
`install-claude-unpushed-version.sh` for version resolution. The overrides are a
behaviour change, so per CLAUDE.md they are test-first. New cases:

- each override redirects its target when set
- defaults resolve to `citypaul/.dotfiles` when unset (upstream behaviour preserved)
- `EXTRA_SKILLS` names are appended to the install manifest
- `validate_unique_skill_names` still rejects a duplicate introduced via `EXTRA_SKILLS`

Tests must not perform a live install, given no safe dry-run exists. They should
assert on resolved variables and constructed arguments, following the existing tests'
approach.

## Risks

**The `@~/` import is documented but unverified here.** `MIGRATION.md` prescribes it
and this repo's v2.0.0 shipped on it, but that behaviour has not been confirmed
against the current Claude Code in the global `~/.claude/CLAUDE.md` position. The
whole layering design rests on it, so implementation must verify the import actually
loads before anything else is built. If it does not resolve, fall back to "own it
outright" — the local file becomes authoritative and upstream's CLAUDE.md is consulted
manually.

**Every install run is live.** No sandbox can contain the skills CLI on Windows. Back
up `~/.claude` before the first real run, independently of the installer's own
backups.

**Skill drift.** Local `~/.claude/skills` was populated by hand-copying, so the CLI
has no record of it — `list -g` shows only `~/.agents` and `~/.codex`. Names matching
the install manifest get backed up and replaced; names outside it
(`flow-canvas-*`, `agent-browser`, `frontend-design`) are left untouched and will
drift. Reconciling that inventory is follow-up work, not part of this design.

**Upstream may change the constants.** If citypaul restructures `install-claude.sh`
around those four lines, merges get harder. Upstreaming the parameterisation as a PR
is the durable mitigation.

## Verification

The design is delivered when:

- `bash ./install-rich.sh` on Windows installs this fork's skills, agents, and
  commands, plus upstream's CLAUDE.md at `base-CLAUDE.md`
- `~/.claude/CLAUDE.md` loads with both upstream and local sections active
- `git merge upstream/main` completes without conflict on a synthetic upstream change
  to an untouched file
- `test/run.sh` passes, including the new override cases
- Running `install-claude.sh` with no overrides still resolves citypaul's repo
