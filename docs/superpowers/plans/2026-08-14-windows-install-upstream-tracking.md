# Windows Install + Upstream Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make this fork installable on Windows with its own content, while tracking `citypaul/.dotfiles` upstream through routine `git merge`.

**Architecture:** Four constants in `install-claude.sh` become environment-overridable, following the existing `VERSION="${VERSION:-}"` pattern. A thin `install-rich.sh` wrapper sets them for this fork and installs a CLAUDE.md overlay that `@`-imports upstream's file. Defaults are unchanged, so upstream behaviour is byte-identical when the variables are unset — keeping the permanent delta small enough that merges stay mechanical.

**Tech Stack:** Bash 5.x (Git Bash / MSYS2 on Windows), git, `skills@1.5.22` CLI via npx, Node >= 22.20.0.

**Spec:** `docs/superpowers/specs/2026-08-14-windows-install-upstream-tracking-design.md`

## Global Constraints

- **Node floor:** `>=22.20.0` — required by `skills@1.5.22`. npm emits `EBADENGINE` as a warning only and proceeds, so an older Node silently runs an unsupported CLI.
- **Defaults must not change.** With no environment overrides set, `install-claude.sh` must resolve `citypaul/.dotfiles` exactly as it does today. Every task preserves this.
- **Environment variables cannot carry bash arrays.** `EXTRA_SKILLS` is a space-separated string, split on read.
- **Tests never perform a live install.** The skills CLI resolves `~` from Windows `USERPROFILE` and escapes any `HOME`/`CLAUDE_CONFIG_DIR` redirection. All tests stub `git`, `npx`, and `curl` on `PATH`, following `test/install-claude-unpushed-version.sh`.
- **Fork identity:** `conjurer-rich/.dotfiles`. Upstream: `citypaul/.dotfiles`.
- **Test style:** match `test/install-claude-unpushed-version.sh` — `set -e`, `FAILURES` counter, `pass`/`fail` helpers, `mktemp -d` with a cleanup trap.

---

## File Structure

| File | Responsibility |
|---|---|
| `install-claude.sh` (modify) | Gains four `${VAR:-default}` overrides. No logic changes. |
| `install-rich.sh` (create) | Fork wrapper: sets overrides, calls through, installs the overlay. |
| `claude/.claude/CLAUDE.rich.md` (create) | The local CLAUDE.md overlay. Upstream never creates this path. |
| `test/install-claude-fork-overrides.sh` (create) | Covers all four overrides plus default preservation. |
| `test/run.sh` (modify) | Registers the new test file. |
| `.gitattributes` (create) | Forces LF for shell scripts. |
| `README.md` (modify) | Windows install instructions. |

---

### Task 1: Verify the `@~/` import actually resolves

The entire CLAUDE.md layering rests on Claude Code resolving `@~/.claude/base-CLAUDE.md` from the global `~/.claude/CLAUDE.md`. `MIGRATION.md:199-221` documents it and this repo's v2.0.0 shipped on it, but it is unverified against current Claude Code. **This task is a gate: if it fails, stop and switch to the documented fallback.**

**Files:**
- Create: `/tmp/import-probe/base-probe.md` (throwaway)

**Interfaces:**
- Consumes: nothing
- Produces: a go/no-go decision for Task 6

- [ ] **Step 1: Create a sentinel file the import should pull in**

```bash
mkdir -p ~/.claude
cat > ~/.claude/base-probe.md <<'EOF'
## Import Probe Sentinel
If you can read this section, respond with exactly: IMPORT-PROBE-OK-7731
EOF
```

- [ ] **Step 2: Back up the real CLAUDE.md, then add the import line**

```bash
cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.probe-backup
printf '\n@~/.claude/base-probe.md\n' >> ~/.claude/CLAUDE.md
```

- [ ] **Step 3: Start a fresh Claude Code session and ask for the sentinel**

Run: `claude` in a new terminal, then prompt: `What is the import probe sentinel value?`
Expected: the reply contains `IMPORT-PROBE-OK-7731`.

- [ ] **Step 4: Restore the real CLAUDE.md and clean up**

```bash
mv ~/.claude/CLAUDE.md.probe-backup ~/.claude/CLAUDE.md
rm -f ~/.claude/base-probe.md
```

- [ ] **Step 5: Record the decision**

If the sentinel came back: continue to Task 2.
If it did **not**: stop. Switch to the spec's documented fallback ("own it outright") — `claude/.claude/CLAUDE.rich.md` becomes the whole file rather than an overlay, Task 4 (`CLAUDE_MD_DEST`) is dropped, and Task 6 installs the file directly to `~/.claude/CLAUDE.md`. Report this before proceeding.

No commit — this task changes nothing permanent.

---

### Task 2: Raise the Node floor and force LF line endings

Two environment blockers. Node `v20.20.0` is below `skills@1.5.22`'s `>=22.20.0` floor, and npm only warns. Separately, `core.autocrlf=true` with no `.gitattributes` gives a CRLF working tree — shebangs currently carry a CR; MSYS2 tolerates it, WSL does not, and files copied out of the tree carry CRs into `~/.claude`.

**Files:**
- Create: `.gitattributes`

**Interfaces:**
- Consumes: nothing
- Produces: a Node runtime meeting the CLI's floor, and LF-normalised `*.sh` in the working tree

- [ ] **Step 0a: Install and default to Node 22**

```bash
fnm install 22
fnm default 22
```

- [ ] **Step 0b: Verify the floor is met**

Run: `node --version`
Expected: `v22.20.0` or higher. If it still reports v20, open a new shell so fnm's default applies, then re-check.

- [ ] **Step 0c: Verify the Skills CLI no longer warns**

Run: `npx --yes skills@1.5.22 --version`
Expected: no `EBADENGINE` warning in the output.

- [ ] **Step 1: Confirm the line-ending problem exists**

Run: `file install-claude.sh`
Expected: output contains `with CRLF line terminators`

- [ ] **Step 2: Create `.gitattributes`**

```gitattributes
# Shell scripts must be LF in the working tree. A CR in the shebang breaks
# direct execution outside MSYS2 (WSL, Linux, macOS), and files copied out of
# the tree carry the CRs with them.
*.sh text eol=lf

# Markdown installed into ~/.claude is read by tooling that does not expect CRs.
*.md text eol=lf
```

- [ ] **Step 3: Renormalise the working tree**

```bash
git add --renormalize .
```

- [ ] **Step 4: Verify the CRs are gone**

Run: `file install-claude.sh test/run.sh`
Expected: no `CRLF` in either line of output.

- [ ] **Step 5: Verify the test suite still runs**

Run: `bash test/run.sh`
Expected: `All tests passed` (or the suite's existing pass output) with exit 0.

- [ ] **Step 6: Commit**

```bash
git add .gitattributes
git commit -m "fix: force LF line endings for shell scripts and markdown"
```

---

### Task 3: Make the source repository overridable

`BASE_URL` (`install-claude.sh:41`) and `OWN_SKILLS_REPO_BASE` (`install-claude.sh:51`) are hardcoded to `citypaul/.dotfiles`, so this fork's content is never installed.

**Files:**
- Create: `test/install-claude-fork-overrides.sh`
- Modify: `install-claude.sh:41`, `install-claude.sh:51`
- Modify: `test/run.sh:16` (append the new test)

**Interfaces:**
- Consumes: nothing
- Produces: `BASE_URL` and `OWN_SKILLS_REPO_BASE` as overridable environment variables, both defaulting to their current values

- [ ] **Step 1: Write the failing test**

Create `test/install-claude-fork-overrides.sh`:

```bash
#!/usr/bin/env bash
#
# A fork needs to install its own content without editing the installer, so the
# source repository, the CLAUDE.md destination, and the first-party skill list
# are all environment-overridable. Defaults must stay exactly as upstream ships
# them: an unset variable installs citypaul/.dotfiles, unchanged.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMPDIR=$(mktemp -d)
FAILURES=0

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

fail() { echo -e "${RED}FAIL${NC}: $1"; FAILURES=$((FAILURES + 1)); }
pass() { echo -e "${GREEN}PASS${NC}: $1"; }

RELEASE_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
mkdir -p "$TMPDIR/bin"

# git stub: the remote publishes one release tag. Local queries stay real so
# own_checkout / rev-parse behave normally.
cat > "$TMPDIR/bin/git" <<STUB
#!/usr/bin/env bash
args="\$*"
case "\$args" in
  *ls-remote*--tags*)
    echo "$RELEASE_SHA	refs/tags/v4.12.1"
    exit 0 ;;
  *ls-remote*)
    echo "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb	refs/heads/main"
    exit 0 ;;
  *"remote -v"*) exec /usr/bin/git "\$@" ;;
  *merge-base*) exit 1 ;;
  *fetch*) exit 0 ;;
  *rev-parse*|*show-ref*) exec /usr/bin/git "\$@" ;;
esac
exit 0
STUB

cat > "$TMPDIR/bin/npx" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$NPX_LOG"
exit 0
STUB

# curl stub: log every URL, and create whatever -o target was requested so
# download_file's success path runs.
cat > "$TMPDIR/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CURL_LOG"
out=""; prev=""
for a in "$@"; do
  [[ "$prev" == "-o" ]] && out="$a"
  prev="$a"
done
[[ -n "$out" ]] && printf '# stub content\n' > "$out"
exit 0
STUB

chmod +x "$TMPDIR/bin/git" "$TMPDIR/bin/npx" "$TMPDIR/bin/curl"

run_installer() {
  ( cd "$REPO_ROOT" && HOME="$HOME_DIR" PATH="$TMPDIR/bin:$PATH" \
      NPX_LOG="$NPX_LOG" CURL_LOG="$CURL_LOG" \
      "$REPO_ROOT/install-claude.sh" "$@" 2>&1 )
}

new_case() {
  HOME_DIR="$TMPDIR/home_$1"; NPX_LOG="$TMPDIR/npx_$1.log"; CURL_LOG="$TMPDIR/curl_$1.log"
  mkdir -p "$HOME_DIR/.claude"
  : > "$NPX_LOG"; : > "$CURL_LOG"
}

echo "Testing fork overrides..."
echo ""

# --- 1. OWN_SKILLS_REPO_BASE redirects the skills source --------------------
new_case own
set +e
OUT=$(OWN_SKILLS_REPO_BASE="conjurer-rich/.dotfiles" \
      run_installer --skills-only --no-external --no-impeccable)
set -e

if printf '%s' "$OUT" | grep -q "conjurer-rich/.dotfiles"; then
  pass "OWN_SKILLS_REPO_BASE redirects the skills source"
else
  fail "the overridden skills repo must be used"
fi

# --- 2. Default is unchanged when unset ------------------------------------
new_case own_default
set +e
OUT2=$(run_installer --skills-only --no-external --no-impeccable)
set -e

if printf '%s' "$OUT2" | grep -q "citypaul/.dotfiles"; then
  pass "an unset OWN_SKILLS_REPO_BASE still resolves citypaul/.dotfiles"
else
  fail "the default source must be preserved"
fi

# --- 3. BASE_URL redirects artifact downloads ------------------------------
new_case base
set +e
BASE_URL="https://raw.githubusercontent.com/conjurer-rich/.dotfiles" \
  run_installer --claude-only >/dev/null
set -e

if grep -q "conjurer-rich/.dotfiles" "$CURL_LOG"; then
  pass "BASE_URL redirects artifact downloads"
else
  fail "the overridden base URL must be used for downloads"
fi

# --- 4. BASE_URL default is unchanged when unset ---------------------------
new_case base_default
set +e
run_installer --claude-only >/dev/null
set -e

if grep -q "citypaul/.dotfiles" "$CURL_LOG"; then
  pass "an unset BASE_URL still downloads from citypaul/.dotfiles"
else
  fail "the default base URL must be preserved"
fi

echo ""
if [[ $FAILURES -gt 0 ]]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi
echo -e "${GREEN}All tests passed${NC}"
```

- [ ] **Step 2: Make it executable and run it to verify it fails**

Run: `chmod +x test/install-claude-fork-overrides.sh && bash test/install-claude-fork-overrides.sh`
Expected: FAIL on "OWN_SKILLS_REPO_BASE redirects the skills source" and "BASE_URL redirects artifact downloads" — the constants are hardcoded, so overrides are ignored.

- [ ] **Step 3: Make both constants overridable**

In `install-claude.sh:41`, change:

```bash
BASE_URL="https://raw.githubusercontent.com/citypaul/.dotfiles"
```

to:

```bash
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/citypaul/.dotfiles}"
```

In `install-claude.sh:51`, change:

```bash
OWN_SKILLS_REPO_BASE="citypaul/.dotfiles"
```

to:

```bash
OWN_SKILLS_REPO_BASE="${OWN_SKILLS_REPO_BASE:-citypaul/.dotfiles}"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash test/install-claude-fork-overrides.sh`
Expected: all four cases PASS.

- [ ] **Step 5: Register the test in the suite**

In `test/run.sh`, after line 16 (`"$SCRIPT_DIR/install-claude-herdr-skill.sh"`), add:

```bash
"$SCRIPT_DIR/install-claude-fork-overrides.sh"
```

- [ ] **Step 6: Run the full suite**

Run: `bash test/run.sh`
Expected: exit 0, no failures.

- [ ] **Step 7: Commit**

```bash
git add install-claude.sh test/install-claude-fork-overrides.sh test/run.sh
git commit -m "feat: make installer source repository overridable for forks"
```

---

### Task 4: Make the CLAUDE.md destination overridable

Upstream's CLAUDE.md must install to `~/.claude/base-CLAUDE.md` so the fork's overlay can own `~/.claude/CLAUDE.md`.

**Files:**
- Modify: `install-claude.sh:771-775`
- Modify: `test/install-claude-fork-overrides.sh` (append a case)

**Interfaces:**
- Consumes: `BASE_URL` override from Task 3
- Produces: `CLAUDE_MD_DEST`, defaulting to `$HOME/.claude/CLAUDE.md`

- [ ] **Step 1: Write the failing test**

In `test/install-claude-fork-overrides.sh`, insert before the `echo ""` / failure-summary block at the end:

```bash
# --- 5. CLAUDE_MD_DEST redirects where CLAUDE.md lands ---------------------
new_case claudemd
set +e
CLAUDE_MD_DEST="$HOME_DIR/.claude/base-CLAUDE.md" \
  run_installer --claude-only >/dev/null
set -e

if [[ -f "$HOME_DIR/.claude/base-CLAUDE.md" ]]; then
  pass "CLAUDE_MD_DEST redirects the CLAUDE.md destination"
else
  fail "CLAUDE.md must land at the overridden destination"
fi

if [[ ! -f "$HOME_DIR/.claude/CLAUDE.md" ]]; then
  pass "the default CLAUDE.md path is left untouched when redirected"
else
  fail "redirecting must not also write the default path"
fi

# --- 6. CLAUDE.md destination default is unchanged when unset --------------
new_case claudemd_default
set +e
run_installer --claude-only >/dev/null
set -e

if [[ -f "$HOME_DIR/.claude/CLAUDE.md" ]]; then
  pass "an unset CLAUDE_MD_DEST still writes ~/.claude/CLAUDE.md"
else
  fail "the default CLAUDE.md destination must be preserved"
fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash test/install-claude-fork-overrides.sh`
Expected: FAIL on "CLAUDE_MD_DEST redirects the CLAUDE.md destination" — the destination is hardcoded.

- [ ] **Step 3: Make the destination overridable**

In `install-claude.sh:771-775`, change:

```bash
  download_file \
    "$BASE_URL/$VERSION/claude/.claude/CLAUDE.md" \
    ~/.claude/CLAUDE.md \
    "CLAUDE.md"
```

to:

```bash
  download_file \
    "$BASE_URL/$VERSION/claude/.claude/CLAUDE.md" \
    "${CLAUDE_MD_DEST:-$HOME/.claude/CLAUDE.md}" \
    "CLAUDE.md"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash test/install-claude-fork-overrides.sh`
Expected: all cases PASS.

- [ ] **Step 5: Commit**

```bash
git add install-claude.sh test/install-claude-fork-overrides.sh
git commit -m "feat: make CLAUDE.md install destination overridable"
```

---

### Task 5: Allow a fork to contribute extra skill names

A fork's own skills must join the install manifest without editing `FIRST_PARTY_SKILLS`, which upstream also edits.

**Files:**
- Modify: `install-claude.sh` (immediately after the `FIRST_PARTY_SKILLS` array ends at line 84)
- Modify: `test/install-claude-fork-overrides.sh` (append a case)

**Interfaces:**
- Consumes: nothing
- Produces: `EXTRA_SKILLS`, a **space-separated string** of skill names appended to `FIRST_PARTY_SKILLS`

- [ ] **Step 1: Write the failing test**

In `test/install-claude-fork-overrides.sh`, insert before the failure-summary block:

```bash
# --- 7. EXTRA_SKILLS adds fork-owned names to the manifest -----------------
new_case extra
set +e
EXTRA_SKILLS="rich-one rich-two" \
  run_installer --skills-only --no-external --no-impeccable >/dev/null
set -e

if grep -q "rich-one" "$NPX_LOG" && grep -q "rich-two" "$NPX_LOG"; then
  pass "EXTRA_SKILLS names are passed to the Skills CLI"
else
  fail "fork-contributed skill names must reach the Skills CLI"
fi

if grep -q "tdd" "$NPX_LOG"; then
  pass "EXTRA_SKILLS adds to rather than replaces the first-party list"
else
  fail "the upstream skill list must survive EXTRA_SKILLS"
fi

# --- 8. A duplicate introduced via EXTRA_SKILLS is still rejected ----------
new_case extra_dup
set +e
OUT8=$(EXTRA_SKILLS="tdd" \
  run_installer --skills-only --no-external --no-impeccable); STATUS8=$?
set -e

if [[ $STATUS8 -ne 0 ]] && printf '%s' "$OUT8" | grep -q "Duplicate skill name"; then
  pass "a duplicate name from EXTRA_SKILLS is rejected"
else
  fail "validate_unique_skill_names must still catch duplicates"
fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash test/install-claude-fork-overrides.sh`
Expected: FAIL on "EXTRA_SKILLS names are passed to the Skills CLI" — the variable is not read anywhere.

- [ ] **Step 3: Append `EXTRA_SKILLS` to the first-party list**

In `install-claude.sh`, immediately after the closing `)` of the `FIRST_PARTY_SKILLS` array (line 84), add:

```bash
# Additional first-party skill names contributed by a fork. Environment
# variables cannot carry bash arrays, so the value is a space-separated string
# split on read. Names join the reviewed manifest and are still subject to
# validate_unique_skill_names.
if [[ -n "${EXTRA_SKILLS:-}" ]]; then
  read -ra _extra_skills <<< "$EXTRA_SKILLS"
  FIRST_PARTY_SKILLS+=("${_extra_skills[@]}")
fi
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash test/install-claude-fork-overrides.sh`
Expected: all cases PASS.

- [ ] **Step 5: Run the full suite**

Run: `bash test/run.sh`
Expected: exit 0, no failures.

- [ ] **Step 6: Commit**

```bash
git add install-claude.sh test/install-claude-fork-overrides.sh
git commit -m "feat: let a fork contribute extra first-party skill names"
```

---

### Task 6: Add the fork wrapper and CLAUDE.md overlay

**Depends on Task 1 passing.** If the import probe failed, use the fallback noted in Task 1 Step 5.

**Files:**
- Create: `install-rich.sh`
- Create: `claude/.claude/CLAUDE.rich.md`

**Interfaces:**
- Consumes: `BASE_URL`, `OWN_SKILLS_REPO_BASE`, `CLAUDE_MD_DEST`, `EXTRA_SKILLS` from Tasks 3-5
- Produces: `bash ./install-rich.sh` as the fork's install entry point

- [ ] **Step 1: Write the overlay header**

```bash
cat > claude/.claude/CLAUDE.rich.md <<'EOF'
# Rich's Development Guidelines

> This file layers on top of the upstream base at `~/.claude/base-CLAUDE.md`,
> which is installed verbatim from citypaul/.dotfiles. Keep additions here so
> upstream updates never conflict.

@~/.claude/base-CLAUDE.md

EOF
```

- [ ] **Step 2: Append the three local sections, extracted verbatim**

`## Global preferences (Rich)`, `## Skill Routing` (with every `###` subsection), and `## Skill Inventory` are the only sections in `~/.claude/CLAUDE.md` that are not upstream's. This awk extraction copies each from its heading up to the next `## ` heading:

```bash
for section in "Global preferences (Rich)" "Skill Routing" "Skill Inventory"; do
  awk -v want="## $section" '
    $0 == want { printing = 1 }
    printing && /^## / && $0 != want { printing = 0 }
    printing { print }
    END { }
  ' ~/.claude/CLAUDE.md >> claude/.claude/CLAUDE.rich.md
  printf '\n' >> claude/.claude/CLAUDE.rich.md
done
```

- [ ] **Step 3: Verify all three sections landed and the import is first**

```bash
grep -c "^## " claude/.claude/CLAUDE.rich.md          # expect 3
grep -n "@~/.claude/base-CLAUDE.md" claude/.claude/CLAUDE.rich.md
grep -E "^## " claude/.claude/CLAUDE.rich.md
```
Expected: exactly 3 `## ` headings — `Global preferences (Rich)`, `Skill Routing`, `Skill Inventory` — and the `@~/` import appearing before all of them.

- [ ] **Step 4: Verify the overlay carries no CRs**

Run: `file claude/.claude/CLAUDE.rich.md`
Expected: no `CRLF` in the output (Task 2's `.gitattributes` covers `*.md`).

- [ ] **Step 5: Create the wrapper**

Create `install-rich.sh`:

```bash
#!/usr/bin/env bash
#
# Install this fork's Claude framework.
#
# Wraps install-claude.sh with the fork's own source repository and layers a
# local CLAUDE.md on top of upstream's, which installs verbatim to
# ~/.claude/base-CLAUDE.md. Every flag is forwarded, so:
#
#   ./install-rich.sh --skills-only
#   ./install-rich.sh --no-external
#
# On Windows, run this under Git Bash with Node >= 22.20.0.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FORK="conjurer-rich/.dotfiles"
OVERLAY_SRC="$SCRIPT_DIR/claude/.claude/CLAUDE.rich.md"
OVERLAY_DEST="$HOME/.claude/CLAUDE.md"

# Skills owned by this fork rather than upstream. Space-separated: environment
# variables cannot carry bash arrays.
FORK_SKILLS=""

BASE_URL="https://raw.githubusercontent.com/$FORK" \
OWN_SKILLS_REPO_BASE="$FORK" \
CLAUDE_MD_DEST="$HOME/.claude/base-CLAUDE.md" \
EXTRA_SKILLS="$FORK_SKILLS" \
  "$SCRIPT_DIR/install-claude.sh" "$@"

# The overlay is this fork's own file; install-claude.sh knows nothing about it.
if [[ -f "$OVERLAY_SRC" ]]; then
  if [[ -e "$OVERLAY_DEST" || -L "$OVERLAY_DEST" ]]; then
    backup="$(mktemp "${OVERLAY_DEST}.backup.XXXXXXXX")"
    echo "→ Backing up existing CLAUDE.md to $backup"
    mv "$OVERLAY_DEST" "$backup"
  fi
  mkdir -p "$(dirname "$OVERLAY_DEST")"
  cp "$OVERLAY_SRC" "$OVERLAY_DEST"
  echo "✓ CLAUDE.md overlay installed (imports ~/.claude/base-CLAUDE.md)"
fi
```

- [ ] **Step 6: Make it executable and verify it forwards flags**

Run: `chmod +x install-rich.sh && bash ./install-rich.sh --help`
Expected: `install-claude.sh`'s help text, exit 0. (`--help` exits before any install work, so nothing is written.)

- [ ] **Step 7: Verify the overlay backup logic without a live install**

```bash
probe_home=$(mktemp -d)
mkdir -p "$probe_home/.claude"
echo "# pre-existing" > "$probe_home/.claude/CLAUDE.md"
HOME="$probe_home" bash -c '
  OVERLAY_DEST="$HOME/.claude/CLAUDE.md"
  backup="$(mktemp "${OVERLAY_DEST}.backup.XXXXXXXX")"
  mv "$OVERLAY_DEST" "$backup"
  ls "$HOME/.claude/"
'
```
Expected: a `CLAUDE.md.backup.*` file is listed, confirming the backup pattern works before it runs for real.

- [ ] **Step 8: Commit**

```bash
git add install-rich.sh claude/.claude/CLAUDE.rich.md
git commit -m "feat: add fork installer wrapper and CLAUDE.md overlay"
```

---

### Task 7: Wire up upstream tracking and document Windows install

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: `install-rich.sh` from Task 6
- Produces: the documented update and install workflow

- [ ] **Step 1: Add the upstream remote**

```bash
git remote add upstream https://github.com/citypaul/.dotfiles.git
git remote -v
```
Expected: both `origin` (conjurer-rich) and `upstream` (citypaul) are listed.

- [ ] **Step 2: Verify a merge from upstream is clean**

```bash
git fetch upstream
git merge --no-commit --no-ff upstream/main || true
git merge --abort 2>/dev/null || true
```
Expected: no conflicts in `install-claude.sh`. If there are, resolve by keeping the `${VAR:-default}` forms — the defaults are identical to upstream's values, so upstream's intent is preserved.

- [ ] **Step 3: Tag a release so version resolution finds this fork**

Without a `v*` tag, `resolve_latest_release()` falls through to citypaul's releases.

```bash
git tag v0.1.0
git push origin v0.1.0
```

- [ ] **Step 4: Add the Windows section to the README**

Insert after the existing install options block (near `README.md:1601`):

````markdown
### Windows install

The installer is bash, and runs under **Git Bash** — no PowerShell port is
needed. `install.sh` (terminal dotfiles) remains macOS-only; this covers the
Claude framework only.

**Prerequisite — Node 22 or newer.** The pinned `skills@1.5.22` CLI requires
`>=22.20.0`. npm treats an older version as a warning (`EBADENGINE`) and runs
anyway, so check explicitly:

```bash
node --version        # must be >= v22.20.0
fnm install 22 && fnm default 22
```

**Install:**

```bash
bash ./install-rich.sh
```

Notes:

- Skills install with `--copy`, so Windows symlink privileges are not required.
- Every install run is live. The Skills CLI resolves `~` from `USERPROFILE` and
  ignores a redirected `HOME`, so there is no dry-run — back up `~/.claude`
  before the first run.

### Updating from upstream

```bash
git fetch upstream
git merge upstream/main
```

Local customisations live in files upstream does not own — `install-rich.sh`,
`claude/.claude/CLAUDE.rich.md`, `.gitattributes`, and fork-owned skill
directories. The only shared file with a permanent delta is
`install-claude.sh`, where four constants are `${VAR:-default}` forms whose
defaults match upstream exactly.
````

- [ ] **Step 5: Run the full suite**

Run: `bash test/run.sh`
Expected: exit 0, no failures.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: document Windows install and upstream update workflow"
```

---

## Post-implementation verification

Against the spec's "Verification" section:

- [ ] `bash ./install-rich.sh` installs this fork's skills, agents, and commands, with upstream's CLAUDE.md at `~/.claude/base-CLAUDE.md`
- [ ] `~/.claude/CLAUDE.md` loads with both upstream and local sections active
- [ ] `git merge upstream/main` completes without conflict on an upstream change to an untouched file
- [ ] `bash test/run.sh` passes including the new override cases
- [ ] `bash ./install-claude.sh` with no overrides still resolves `citypaul/.dotfiles`

## Known follow-up (out of scope)

Hand-copied skills outside the install manifest — `flow-canvas-*`, `agent-browser`, `frontend-design` — are untouched by the installer and will drift. Reconciling that inventory is separate work.
