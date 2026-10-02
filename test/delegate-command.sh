#!/usr/bin/env bash
#
# Guard the global /delegate command: it is installed into every project, so
# it must carry no project's settings, must read them from the project's own
# .claude/delegation.md, and must not fail before the skill loads when gh is
# missing.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMMAND="$REPO_ROOT/claude/.claude/commands/delegate.md"
INSTALLER="$REPO_ROOT/install-claude.sh"
FAILURES=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

fail() {
  echo -e "${RED}FAIL${NC}: $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo -e "${GREEN}PASS${NC}: $1"
}

require_text() {
  local file="$1" pattern="$2" label="$3"

  if grep -Fq -- "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

reject_regex() {
  local file="$1" pattern="$2" label="$3"

  if grep -Eiq -- "$pattern" "$file"; then
    fail "$label"
  else
    pass "$label"
  fi
}

require_text "$INSTALLER" 'COMMAND_FILES=(setup.md plan.md continue.md delegate.md)' "the installer ships /delegate"
reject_regex "$COMMAND" 'fast-flow-board|conjurer-rich|flow-canvas|apps/web|ux-evidence|agent-ready' "the command names no project or its settings"
require_text "$COMMAND" 'cat .claude/delegation.md' "the command reads the project's settings file"
require_text "$COMMAND" 'is not set up here' "a project without settings stops instead of guessing"
require_text "$COMMAND" 'gh repo view --json nameWithOwner' "owner and repo come from the repository"

require_text "$COMMAND" 'No arguments, or `run` → one **Run** pass' "a bare /delegate runs one Run pass"
require_text "$COMMAND" 'Run it as `/loop /delegate` to keep delegating' "the Run pass is built for /loop"
require_text "$COMMAND" '**Run**, **Watch**, the **Work**' "a Run pass commits without asking"
require_text "$COMMAND" 'Several sessions can run `/loop /delegate` at once' "the command says parallel sessions are supported"
require_text "$COMMAND" '- **Session title** (skill):' "the command says the chat is named after the item held"
require_text "$COMMAND" 'Bash(jq:*)' "the CLI rename's jq call needs no permission prompt"
require_text "$COMMAND" 'mcp__claude-code-remote__set_session_title' "the cloud rename tool needs no permission prompt"
# The orchestrator mostly routes once the bookkeeping is a script, so the
# loop session can run on a cheaper model; the implementer and Land's
# reviewer stay on the strongest. Recommend it, never pin it.
require_text "$COMMAND" '## Model' "the command has model guidance"
require_text "$COMMAND" 'can run on a cheaper model' "the loop session may run on a cheaper model"
require_text "$COMMAND" 'keep `model: opus`' "the implementer and Land reviewer stay on the strongest model"
if sed -n '1,/^---$/{/^---$/!p}' "$COMMAND" | tail -n +2 | grep -q '^model:'; then
  fail "the command does not pin a model for the loop session"
else
  pass "the command does not pin a model for the loop session"
fi
SKILL_DIR="$REPO_ROOT/claude/.claude/skills/delegating-github-issues"
require_text "$SKILL_DIR/references/work.md" '6. **Handoff.** Renew the claim (**Claims**), then dispatch one subagent with `subagent_type: general-purpose`, `model: opus`' "the implementer is dispatched on opus"
require_text "$SKILL_DIR/references/land.md" '`model: opus`, `run_in_background: true`' "Land's reviewer is dispatched on opus"
require_text "$COMMAND" 'Bash(*/delegating-github-issues/scripts/delegate-status:*)' "the bookkeeping script needs no permission prompt"
require_text "$COMMAND" '`tier_small_max_lines` 150, `tier_small_max_packages` 1, no `risk_paths`' "the command lists the size-tier defaults"

if grep -E '^!`[^`]*\bgh ' "$COMMAND" | grep -vq '||'; then
  fail "every gh line before the skill loads tolerates a missing gh"
else
  pass "every gh line before the skill loads tolerates a missing gh"
fi

echo ""

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed${NC}"
