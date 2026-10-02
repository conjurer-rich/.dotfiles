#!/usr/bin/env bash
#
# The fork's `version` command for changesets/action.
#
# The action does not run its `version` input through a shell: it splits the
# string on whitespace and execs the first word with the rest as arguments.
# `pnpm changeset version && node …` therefore handed changesets a literal
# `&&` and it refused with "Too many arguments" (runs 27 and 28 of release.yml).
# This script is the one word the action execs; it runs the two steps itself.
#
#   1. `changeset version` consumes .changeset/*.md, bumps fork/package.json
#      and writes fork/CHANGELOG.md.
#   2. sync-plugin-version.mjs copies the new version into the craft plugin
#      manifest, so the "chore: version packages" PR carries both bumps.

set -euo pipefail

cd "$(dirname "$0")/.."

pnpm changeset version
node fork/sync-plugin-version.mjs
