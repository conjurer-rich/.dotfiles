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
render_settings_line() {
  local dir="$1" line

  line="$(grep -A1 -F 'Project delegation settings' "$COMMAND" | sed -n '2s/^!`\(.*\)`$/\1/p')"
  (cd "$dir" && GIT_CEILING_DIRECTORIES="$SANDBOX" bash -c "$line")
}

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
git init -q "$SANDBOX/project"
mkdir -p "$SANDBOX/project/.claude" "$SANDBOX/project/apps/web/src" "$SANDBOX/elsewhere"
echo "project settings" > "$SANDBOX/project/.claude/delegation.md"

if [ "$(render_settings_line "$SANDBOX/project/apps/web/src")" = "project settings" ]; then
  pass "the command reads the project's settings file from a subdirectory"
else
  fail "the command reads the project's settings file from a subdirectory"
fi

if [ "$(render_settings_line "$SANDBOX/elsewhere")" = "none" ]; then
  pass "outside a repository the settings read none"
else
  fail "outside a repository the settings read none"
fi

require_text "$COMMAND" 'is not set up here' "a project without settings stops instead of guessing"
require_text "$COMMAND" 'gh repo view --json nameWithOwner' "owner and repo come from the repository"

require_text "$COMMAND" 'No arguments, or `run` → one **Run** pass' "a bare /delegate runs one Run pass"
require_text "$COMMAND" 'Run it as `/loop /delegate` to keep delegating' "the Run pass is built for /loop"
require_text "$COMMAND" '**Run**, **Watch**, the **Work**' "a Run pass commits without asking"
require_text "$COMMAND" 'Several sessions can run `/loop /delegate` at once' "the command says parallel sessions are supported"

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
