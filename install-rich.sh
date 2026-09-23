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
FORK_SKILLS="browser-ux-walkthrough delegating-github-issues"

BASE_URL="https://raw.githubusercontent.com/$FORK" \
OWN_SKILLS_REPO_BASE="$FORK" \
CLAUDE_MD_DEST="$HOME/.claude/base-CLAUDE.md" \
EXTRA_SKILLS="$FORK_SKILLS" \
  "$SCRIPT_DIR/install-claude.sh" "$@"

# The overlay is this fork's own file; install-claude.sh knows nothing about it.
# It is only half of a pair: it @-imports the base that install-claude.sh writes
# to ~/.claude/base-CLAUDE.md. Installing it when the base was never written
# would replace the user's real CLAUDE.md with a dangling import, so it follows
# the same gate -- --help exits before doing any work, and the mode flags below
# set INSTALL_CLAUDE=false.
overlay_wanted=true
for arg in "$@"; do
  case "$arg" in
    --help|-h|--skills-only|--agents-only|--opencode-only) overlay_wanted=false ;;
  esac
done

if [[ "$overlay_wanted" == true && -f "$OVERLAY_SRC" ]]; then
  if [[ -e "$OVERLAY_DEST" || -L "$OVERLAY_DEST" ]]; then
    backup="$(mktemp "${OVERLAY_DEST}.backup.XXXXXXXX")"
    echo "→ Backing up existing CLAUDE.md to $backup"
    mv "$OVERLAY_DEST" "$backup"
  fi
  mkdir -p "$(dirname "$OVERLAY_DEST")"
  cp "$OVERLAY_SRC" "$OVERLAY_DEST"
  echo "✓ CLAUDE.md overlay installed (imports ~/.claude/base-CLAUDE.md)"
fi
