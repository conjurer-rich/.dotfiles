# Spec: move the craft skills into their own repository

Status: proposal — nothing here is built yet. D1 (repository name) and D5
(`CLAUDE.md`) are decided. The one item still marked **(decide)** (what
`.dotfiles` becomes, Phase 5) is not needed until the end.

## Why

- This repository is a fork of `citypaul/.dotfiles`. The only part of it in use
  is the `craft` Claude Code plugin (`claude/.claude/`), published through
  `.claude-plugin/marketplace.json`.
- The fork's own work is increasingly the point: `delegating-github-issues`,
  `browser-ux-walkthrough`, `/delegate`, the stop hook, the
  `engineering-practice` additions and the fork release line (`fork/`). Against
  `upstream/main` the fork adds ~1,500 lines under `claude/.claude/`, and
  removes almost nothing.
- Keeping the fork costs real effort that buys nothing for the skills:
  - every upstream merge risks conflicts and broken releases (the
    `@citypaul/dotfiles` changeset that failed Release runs 41–43);
  - the `fork/` release line, `CLAUDE.rich.md` overlay, `install-rich.sh`
    wrapper and `FORK_SKILLS` list exist only to sit beside upstream;
  - the shell, terminal, editor and installer files are carried but unused.
- Matt Pocock's [`mattpocock/skills`](https://github.com/mattpocock/skills)
  shows a cleaner shape: a repository whose root *is* the plugin, with
  categorised skills and an explicit skill list in `plugin.json`.

## Goal

A new repository, owned outright, that:

1. installs as a Claude Code plugin with one `marketplace add` + `plugin install`
   and updates itself;
2. holds only the skills, agents, commands and hooks in use, plus their tests
   and evals;
3. has no git relationship with `citypaul/.dotfiles` — Paul's and Matt's work
   become **sources we watch and borrow from**, not branches we merge;
4. is told, on a schedule, what changed upstream and which local skills it
   affects, so borrowing stays a deliberate choice.

## Non-goals

- Re-publishing Paul's or Matt's skills wholesale. We adopt what is used and
  evolve it as our own.
- Moving the personal dotfiles (zsh, tmux, ghostty, …). They stay here or are
  dropped; that is a separate decision (see Phase 5).
- Rewriting skill content during the move. The move is mechanical; evolution
  happens afterwards, in normal PRs.

## Decisions

### D1. Repository and plugin identity

| Thing | Today | Proposed |
| --- | --- | --- |
| Repository | `conjurer-rich/.dotfiles` | `conjurer-rich/skills` (decided) |
| Marketplace name | `conjurer-dotfiles` | `conjurer` |
| Plugin name | `craft` | `craft` (unchanged) |
| Install id | `craft@conjurer-dotfiles` | `craft@conjurer` |

Keep the plugin name `craft`. Every skill, agent and command is addressed as
`craft:<name>` — in routing text, in `/delegate`, in `.claude/delegation.md`
files in other repositories, and in muscle memory. Changing it breaks all of
those for no gain. Only the marketplace name changes, which is a one-off
reinstall.

### D2. History: fresh import, not `git filter-repo`

Start the new repository with one import commit that copies the files from a
named `.dotfiles` commit, and record that SHA in `PROVENANCE.md`.

- `filter-repo` would drag Paul's 2024–2026 history (and upstream merge
  commits) into a repository whose purpose is to stand apart from it.
- Full history stays readable in `.dotfiles`, which is not deleted.
- Per-skill provenance already lives in `skills/REFERENCES.md`, each adapted
  skill's `LICENSE` / `NOTICE` and `references/source-notes.md`. That is the
  record that matters for licensing, and it moves with the files.

### D3. Layout (borrowed from Matt's repository)

```
.claude-plugin/
  marketplace.json      # name "conjurer", one plugin, source "./"
  plugin.json           # name "craft", version, explicit "skills" list
skills/
  engineering/          # tdd, testing, refactoring, codebase-design, …
  architecture/         # hexagonal, ddd, event-sourcing, bff-*, api-design, …
  delivery/             # delegating-github-issues, planning, stack-pull-requests, panel-review, …
  writing/              # technical-writing, diagrams, expectations, wtf, …
  in-progress/          # drafts: in the repo, NOT listed in plugin.json
  deprecated/           # aliases kept for a release, then deleted
  REFERENCES.md
agents/                 # the nine agents
commands/               # continue, delegate, plan, setup
hooks/
  hooks.json            # Stop → stop-hook-git-check.sh (ships with the plugin)
  stop-hook-git-check.sh
upstream/
  sources.json          # what the watch routine tracks (see D6)
  skill-map.json        # upstream skill ↔ local skill
test/                   # skill-only tests, paths rewritten
evals/skills/           # promptfoo suites
.changeset/  package.json  CHANGELOG.md
global/
  CLAUDE.md             # thin global instructions (D5)
  AGENTS.md -> CLAUDE.md
scripts/
  skill-usage.py        # usage count for triage (D4)
  install-global        # links global/ into ~/.claude, ~/.codex, ~/.config/opencode
CLAUDE.md               # how to work on THIS repository
AGENTS.md -> CLAUDE.md
README.md  LICENSE  PROVENANCE.md
```

- Categories are for humans; Claude Code sees only the names in
  `plugin.json` → `skills`. Category names above are a starting point; settle
  them during triage.
- `in-progress/` is Matt's best idea for this: a skill can live in `main`,
  be reviewed and evalled, and not ship until it is added to the list.
- A test fails when a directory under `skills/<category>/` is neither listed
  in `plugin.json` nor under `in-progress/` / `deprecated/`, and when a listed
  path does not exist.
- The Stop hook moves from `settings.json` (installed by script) into the
  plugin's `hooks/hooks.json`, so installing the plugin is the whole install.

### D4. What moves — triage, not a blanket copy

Today the plugin ships 54 skill directories, 9 agents and 4 commands. Most
skill files were written upstream; the fork owns
`delegating-github-issues`, `browser-ux-walkthrough`, the `delegate` command,
the stop hook and the `engineering-practice` additions.

Triage every item into one of:

| Bucket | Meaning |
| --- | --- |
| **Own** | Moves; from now on it is ours and evolves freely. |
| **Drop** | Not used; does not move. The watch routine can still flag upstream changes to it if wanted. |
| **Replace** | Matt (or another source) has a better version; adopt that instead, with provenance. |

Use evidence, not memory, for "in use": count `Skill` tool calls and
`craft:` references in local Claude Code transcripts
(`~/.claude/projects/**/*.jsonl`) over the last 60–90 days, plus anything
another skill or command routes to. `scripts/skill-usage.py` (in this repository
now, moving with the skills) produces the table:

```sh
scripts/skill-usage.py                  # Markdown, last 90 days, ~/.claude/projects
scripts/skill-usage.py --days 60 --format json
scripts/skill-usage.py --projects ~/.claude/projects --projects ~/other-mac-projects
```

It counts `Skill` tool calls, `Agent` spawns and slash commands, for both
`craft:<name>` and bare `<name>` (skills installed by `install-rich.sh` have no
prefix), and suggests **own** (used), **review** (unused, but a used item
routes to it) or **drop?** (neither). Routing from `CLAUDE.md` alone does not
count, since that file is being rewritten. A "Used, but not part of craft"
section lists other skills and agents you call, which is where **Replace**
candidates show up. Transcripts are per machine and cloud sessions keep none,
so run it on each machine you work on. The triage result goes in the import PR
description.

Known starting points:

- `folder-structure` is a deprecated alias of `structure-codebase` →
  `deprecated/`, delete after one release.
- `engineering-practice` stands in for `~/.claude/CLAUDE.md` in plugin
  installs → **Own**, and it absorbs whatever of `CLAUDE.md` +
  `CLAUDE.rich.md` is still wanted (see D5).
- Matt overlaps: his `tdd`, `codebase-design`, `improve-codebase-architecture`
  (ours already adapt pinned commit `66898f60`), `diagnosing-bugs` ↔
  `debugging`, `grill-me`/`grilling` ↔ `find-gaps`/`specification`,
  `to-spec`/`to-tickets` ↔ `specification`/`story-splitting`. Record these
  pairs in `upstream/skill-map.json`; whether to **Replace** any of them is a
  later, per-skill decision, not part of the move.

### D5. `CLAUDE.md` folds into `engineering-practice` (decided)

Today `~/.claude/CLAUDE.md` is the fork overlay (`CLAUDE.rich.md`), which
`@`-imports Paul's file installed verbatim as `~/.claude/base-CLAUDE.md`, and
`engineering-practice` only points at a copy of that base at
`${CLAUDE_PLUGIN_ROOT}/CLAUDE.md`. Decoupling means the import, the overlay and
the pointer all go.

`engineering-practice` becomes the single source of truth for the guidelines:

- `SKILL.md` holds the core policy from `CLAUDE.md` (philosophy, testing,
  TypeScript, code style, workflow, output guardrails), edited down to what is
  still wanted. No `CLAUDE.md` ships at the new repository's root except the
  one that guides work *on* the repository.
- `references/routing.md` holds the skill-routing table, merged from both
  files: `CLAUDE.md`'s Quick Reference and `CLAUDE.rich.md`'s "Skill Routing".
  Lines for skills that are dropped or not installed (for example `pre-commit`,
  `quality`, `scaffold-new-project`) are removed, and the CI link check (D8)
  keeps it honest.
- The skill description keeps "load this first in any coding task".

**A thin global `CLAUDE.md`, with `AGENTS.md` pointing at it (decided).** The
guidelines live in the skill, but a short global file makes sure every session
loads it, and carries the personal preferences that are not engineering policy.
It is the same file for every agent: `AGENTS.md` is a symlink to `CLAUDE.md`,
as in Matt's repository, so Codex, OpenCode and other `AGENTS.md` readers get
the same pointer.

```
global/
  CLAUDE.md             # the thin global file (draft below)
  AGENTS.md -> CLAUDE.md
```

Draft `global/CLAUDE.md`, written agent-neutrally so it reads correctly as
`AGENTS.md` too:

```md
# Global instructions

Before any coding task, load the `engineering-practice` skill
(`craft:engineering-practice` in Claude Code). It holds the engineering
guidelines and the routing table for every other skill; this file does not
repeat them.

## Personal preferences

- Visual companion: always allowed. When a design workflow could use the
  browser-based visual companion, use it without asking each time.
- Skills live globally. A project vendors a skill into its own
  `.claude/skills/` only when the skill is genuinely project-specific.
```

`CLAUDE.rich.md`'s "Global preferences" move here, not into the skill.

`scripts/install-global` links them into place from a clone of the
repository, so a `git pull` updates them:

| Link | Target |
| --- | --- |
| `~/.claude/CLAUDE.md` | `<clone>/global/CLAUDE.md` |
| `~/.codex/AGENTS.md` | `<clone>/global/AGENTS.md` |
| `~/.config/opencode/AGENTS.md` | `<clone>/global/AGENTS.md` |

It backs up an existing file before replacing it, skips an agent whose config
directory does not exist, and copies instead of linking where symlinks are
unavailable (Git Bash on Windows without developer mode). A plugin install
cannot write these files, which is why this is a separate script.

The repository's own root follows the same pattern: `CLAUDE.md` says how to
work on the repository (buckets, `plugin.json` list, changesets, tests) and
`AGENTS.md -> CLAUDE.md`.

`base-CLAUDE.md` and the overlay go: at cut-over (Phase 4) the old
`~/.claude/CLAUDE.md` and `~/.claude/base-CLAUDE.md` are backed up and replaced
by the link, so the guidelines are not loaded from two diverging sources.

### D6. Upstream watch: a weekly Claude Code Routine that files one issue

**What it watches** — `upstream/sources.json`:

```json
[
  {
    "repo": "citypaul/.dotfiles",
    "paths": ["claude/.claude/skills", "claude/.claude/agents",
              "claude/.claude/commands", "claude/.claude/CLAUDE.md"],
    "baseline": "<sha of the import commit's source>"
  },
  {
    "repo": "mattpocock/skills",
    "paths": ["skills/engineering", "skills/productivity"],
    "baseline": "<sha at time of setup>"
  }
]
```

**How it runs** — a Claude Code Routine (`create_trigger`,
`create_new_session_on_fire: true`, cron weekly, e.g. Monday 07:52
Europe/London) against the new repository. Each run:

1. Finds the last `upstream-watch` issue and reads the "reviewed up to" SHA per
   source from its body; falls back to `baseline` on the first run.
2. Lists commits on each source since that SHA, limited to the watched paths.
   No new commits on any source → stop silently, file nothing.
3. For each changed upstream skill, reads the diff and classifies it via
   `skill-map.json`:
   - **Counterpart change** — upstream skill we own a version of changed:
     summarise the change and whether it applies to ours.
   - **New skill** — summarise, and say whether it overlaps an existing one.
   - **Not relevant** — dropped skill, docs-only, tooling: one line.
4. Opens one issue, `upstream-watch: <date>`, with a checklist per item
   (`adopt` / `adapt` / `ignore` suggestion and a one-line reason), the commit
   links, and the new "reviewed up to" SHAs. Labels: `upstream-watch`.
5. Never edits skills, never opens PRs, never merges upstream code.

Turning a checklist item into work is a normal issue → PR flow; an item
promoted to its own issue with the delegation label can go through `/delegate`
like anything else. Any adopted text gets the provenance treatment already
used in `REFERENCES.md` and `source-notes.md` (pinned commit, license).

Why a Routine and not a GitHub Action: the value is the judgement in step 3
(mapping upstream changes onto our diverged skills), which needs a model. A
plain Action could only list commits. If cost matters, a cheap Action can do
step 2 and fire the Routine only when something changed (`fire_trigger`).

Both upstreams are MIT; Paul's repository has nested CC BY-SA 4.0 material
(`cli-design`). The routine's issue template reminds the reviewer to check the
license of anything adopted.

### D7. Releases

Keep changesets and the plugin-manifest version sync — they work and Claude
Code needs `plugin.json`'s `version` to change for installs to update. Drop the
`fork/` indirection: the root `package.json` (`@conjurer-rich/skills`) is the
release line, and `scripts/version.sh` runs `changeset version` then syncs
`plugin.json`. Start at `5.0.0`: the marketplace identity changes, and it
signals the break from the `4.x` fork line.

### D8. CI in the new repository

Carry over only skill-related checks, with paths rewritten from
`claude/.claude/…`:

- `skills-frontmatter.sh`, `plugin-version-sync.sh`,
  `delegate-status.sh`, `delegate-command.sh`,
  `delegation-landing-workflow.sh`, `stop-hook-delegator-exemption.sh`,
  `mutation-workflow.sh`, `tdd-watch-workflow.sh`,
  `architecture-guidance.sh`, `cli-guidance.sh`,
  `skill-evals-quality.sh`, `skill-evals-routing.sh`;
- new: plugin manifest ↔ directory check (D3), and a link check that every
  `craft:<name>` and relative path referenced from a skill, agent or command
  resolves;
- `skill-evals.yml` (promptfoo, weekly + `run-evals` label), needing the
  `ANTHROPIC_API_KEY` secret in the new repository;
- changeset validation + release dry-run.

Left behind: `setup-dotfiles.py`, `opencode-compat.sh`, the
`install-claude-*` tests and the macOS/Debian install matrix.

## Plan

Each phase ends in a working state; nothing breaks the current install until
Phase 4.

### Phase 0 — decide (this PR)

- ~~Answer the repository-name and `CLAUDE.md` decisions~~ — done (D1, D5).
- Run the usage count (D4) locally and fill in the triage table:
  `scripts/skill-usage.py` in this repository (see below).

### Phase 1 — create the repository and import

- Create `conjurer-rich/skills` (private or public), MIT `LICENSE` naming both
  Paul Hammond (2024, for the adopted material) and you, plus `PROVENANCE.md`
  with the source `.dotfiles` SHA and the triage table.
- Copy **Own** items into the D3 layout; `deprecated/` aliases as noted.
- Write `marketplace.json`, `plugin.json` (explicit skill list, `5.0.0`),
  `hooks/hooks.json`.
- Rewrite `claude/.claude/…` paths in skills, agents, commands and tests (13
  skill/agent/command files and ~30 test references today).
- Port the tests and evals (D8); CI green.

Done when: `claude plugin marketplace add conjurer-rich/skills` and
`claude plugin install craft@conjurer` in a clean home give the same
`craft:` skills, agents, commands and Stop hook as today, minus **Drop**ped
items.

### Phase 2 — fold `CLAUDE.md`

- Rewrite `engineering-practice` as D5 describes: policy in `SKILL.md`,
  merged routing table in `references/routing.md`; drop the
  `${CLAUDE_PLUGIN_ROOT}/CLAUDE.md` pointer.
- Add `global/CLAUDE.md`, the `global/AGENTS.md` symlink and
  `scripts/install-global` (with a test that runs it against a temporary
  home: links made, existing file backed up, missing agent skipped).
- Add the repository's root `CLAUDE.md` and `AGENTS.md -> CLAUDE.md`.
- Prune routing lines for dropped or uninstalled skills; the link check
  passes.
- Check in a fresh session that a coding prompt loads
  `craft:engineering-practice` without being asked (and a promptfoo routing
  case for it, if cheap).

### Phase 3 — upstream watch

- Add `upstream/sources.json` and `upstream/skill-map.json`.
- Create the `upstream-watch` label.
- Create the Routine (D6) with a standalone prompt that reads those two files;
  fire it once by hand to check the issue it files.

### Phase 4 — cut over

- On each machine and in Claude Code on the web settings:
  `claude plugin uninstall craft@conjurer-dotfiles`, then add the new
  marketplace and install `craft@conjurer`. Check `/delegate` in a project
  that uses it.
- Update any `extraKnownMarketplaces` / `enabledPlugins` settings that name
  `conjurer-dotfiles`.
- Run `scripts/install-global` from a clone: it backs up and replaces
  `~/.claude/CLAUDE.md` and links `AGENTS.md` for Codex and OpenCode. Delete
  `~/.claude/base-CLAUDE.md`.

### Phase 5 — retire the fork's plugin

- Final `.dotfiles` release: plugin description and README say "moved to
  `conjurer-rich/skills`"; the marketplace entry stays for one release so a
  stale install updates to a version that says so, then is removed with
  `claude/.claude/`, `fork/`, `.changeset/`, `install-rich.sh`.
- **(decide)** what `.dotfiles` becomes: (a) archive it; (b) detach from
  `citypaul` and keep only the personal dotfiles; (c) leave as is.
  Recommended: (b) if any of the shell/terminal config is used, otherwise (a).

## Risks

| Risk | Mitigation |
| --- | --- |
| A skill or command routes to a dropped skill | Link check in CI (D8); triage counts routing references as use. |
| Stop hook behaves differently as a plugin hook (`$HOME/.claude/hooks/…` path) | Use `${CLAUDE_PLUGIN_ROOT}` in `hooks.json`; keep the delegator-exemption test. |
| Two plugins installed at once during cut-over → duplicate skills | Uninstall the old one before installing the new one (Phase 4 order). |
| Watch issues become noise | Silent when nothing changed; one issue per run; drop a source from `sources.json` when it stops being useful. |
| `engineering-practice` is skipped on a coding task | The global `CLAUDE.md` / `AGENTS.md` tells every session to load it; Phase 2 checks it fires in a fresh session. |
| A machine has the plugin but not the global file (cloud sessions) | The skill description still says "load first in any coding task"; for Claude Code on the web, add the same line to the environment's setup or the project's own `CLAUDE.md`. |
| Licensing drift when adopting from upstream | Keep the existing provenance pattern; the routine's issue template asks for the license check. |

## Appendix: triage proposal (Windows machine, 2026-10-08)

Source: `scripts/skill-usage.py` on the Windows machine, 500 transcript files.
Claude Code keeps transcripts for 30 days by default, so this is roughly one
month of use (oldest "last used" is 2026-09-07). "Leaned on by" counts
references from the **used** items only.

### Own: used (25 skills, 1 agent, 1 command)

`tdd` 43 · `testing` 28 · `delegating-github-issues` 22 ·
`browser-ux-walkthrough` 18 · `acceptance-review` 14 · `refactoring` 8 ·
`react-testing` 6 · `find-gaps` 5 · `ubiquitous-language` 5 · `planning` 4 ·
`stack-pull-requests` 4 · `story-splitting` 4 · `typescript-strict` 4 ·
`characterisation-tests` 3 · `ci-debugging` 2 · `event-sourcing` 2 ·
`mutation-testing` 2 · `reduce-system-complexity` 2 · `debugging` 1 ·
`hexagonal-architecture` 1 · `secure-oauth-oidc` 1 · `specification` 1 ·
`storyboard` 1 · `technical-writing` 1 · `twelve-factor` 1 ·
agent `tdd-guardian` 37 · command `/delegate` 16.

Plus `engineering-practice`: never invoked because the local `CLAUDE.md`
already supplies it, but it is where `CLAUDE.md` folds into (D5).

### Own: a used item depends on it

| Item | Leaned on by |
| --- | --- |
| `finding-seams` | characterisation-tests ×5, testing, stack-pull-requests, reduce-system-complexity, debugging, hexagonal-architecture |
| `structure-codebase` | hexagonal-architecture ×7, ubiquitous-language, reduce-system-complexity |
| `front-end-testing` | react-testing ×6, testing |
| `domain-driven-design` | hexagonal-architecture ×3, ubiquitous-language ×2, event-sourcing ×2 |
| `functional` | typescript-strict ×2, event-sourcing ×2, reduce-system-complexity ×2, twelve-factor |
| `observability` | hexagonal-architecture ×4, ci-debugging, debugging, twelve-factor |
| `codebase-design` | reduce-system-complexity ×2, refactoring, hexagonal-architecture |
| `evaluate-existing-solutions` | reduce-system-complexity ×2, planning, specification |
| `expectations` | planning ×2, storyboard, technical-writing |
| `bff-entry-points` | hexagonal-architecture, secure-oauth-oidc |
| `test-design-reviewer` | testing |
| `double-check` | acceptance-review |
| agent `refactor-scan` | tdd-guardian ×2 |

### Your call: thin dependency

| Item | Leaned on by | Recommendation |
| --- | --- | --- |
| `panel-review` (+ `graph-engineering`, which it is built on) | tdd ×2, planning, tdd-guardian | Drop both and repoint those lines at `/code-review` (26 uses) and the project `pr-reviewer` agent (19), which is what you actually use. |
| `improve-codebase-architecture` | refactoring, reduce-system-complexity | Keep; it is already an adaptation of Matt's, so the watch routine tracks it. |
| `xstate`, `react-performance` | react-testing | Keep if React work continues. |
| `api-design`, `cli-design`, `diagrams` | technical-writing ×1 each | Keep `api-design`; drop the other two. |
| agents `adr`, `learn` | planning | Drop; repoint planning at `expectations`. |
| commands `/plan`, `/continue` | planning | Drop unless you type them. |

### Drop: nothing used depends on it

`folder-structure` (deprecated alias), `find-skills`, `teach-me`,
`render-code-shape`, `production-parity-skill-builder`, `bff-design`, `wtf`,
command `/setup`, agents `docs-guardian`, `progress-guardian`, `ts-enforcer`,
`twelve-factor-audit`, `use-case-data-patterns`. References to them from kept
items are removed during import; the D8 link check confirms none are left.

### Used, but not part of craft: candidates to adopt or watch

- `grill-me` (Matt) ×8: adopt into the plugin, with provenance.
- `superpowers:*` (brainstorming ×11, writing/executing plans, git worktrees,
  systematic debugging): overlaps `planning`, `specification` and `debugging`.
  Consider adding `obra/superpowers` to `upstream/sources.json`.
- `code-review` ×26, `simplify` ×14: built into Claude Code; nothing to move.
- `flow-canvas-*`, `pr-reviewer`, `steward`, `pre-commit`: project-local; they
  stay in their projects.
