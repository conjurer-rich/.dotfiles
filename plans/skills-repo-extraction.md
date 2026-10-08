# Spec: move the craft skills into their own repository

Status: proposal — nothing here is built yet. D1, D5 and D9–D11 are decided; D12 is proposed.
Still open: the copyright holder name (D11, before Phase 1) and what
`.dotfiles` becomes (Phase 5).

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
  delivery/             # delegating-github-issues, planning, stack-pull-requests, review, …
  writing/              # technical-writing, diagrams, expectations, wtf, …
  in-progress/          # drafts: in the repo, NOT listed in plugin.json
  shelf/                # kept but not shipped; craft:ask can point at them
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

Triage every item into one of (see the appendix for the result):

| Bucket | Meaning |
| --- | --- |
| **Own** | Moves; from now on it is ours and evolves freely. |
| **Shelf** | Not used now; moves to `shelf/`, outside `plugin.json`. Promote it with a one-line change. |
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
  resolves to a shipped item. Only `craft:ask` may name a shelved one;
- new: every shipped skill appears in `craft:ask`, so nothing ships that the
  router cannot point you at;
- `skill-evals.yml` (promptfoo, weekly + `run-evals` label), needing the
  `ANTHROPIC_API_KEY` secret in the new repository;
- changeset validation + release dry-run.

Left behind: `setup-dotfiles.py`, `opencode-compat.sh`, the
`install-claude-*` tests and the macOS/Debian install matrix.

### D9. `craft:review`: a portable two-axis review (decided)

Claude Code's built-in `/code-review` finds correctness bugs, but it exists
only in Claude Code. Codex has its own `/review` (and `codex review`), and
neither one knows your standards or the issue the change was for.
`craft:review` covers what both built-ins miss, and works the same in either:

| Axis | Checks | Source |
| --- | --- | --- |
| **Standards** | Does the diff follow the repository's written standards, and the craft skills that apply to it? | `CLAUDE.md` / `AGENTS.md`, `CODING_STANDARDS.md`, `CONTRIBUTING.md`; up to three craft skills picked from the diff's traits (`typescript-strict` for `.ts`, `testing` for test files, `hexagonal-architecture` when the repository has opted in, …); Matt's Fowler smell baseline as the fallback. A documented repo standard always overrides a smell. |
| **Spec** | Does the diff do what the issue asked, no more and no less? | Runs `acceptance-review` against the issue named in the commits or branch, or a path you pass. It is skipped, and the report says so, when there is no spec. |

- **Not a correctness reviewer.** It leaves bugs to the host's own reviewer:
  `/code-review` in Claude Code, `/review` in Codex. `craft:ask` says to run
  both.
- **Shape.** It is adapted from Matt's `code-review`: pin a fixed point (by
  default the merge-base with the default branch), then run the two axes as
  separate subagents where the harness has them, or one after the other where
  it does not. The two reports are presented side by side and never merged
  or re-ranked, so a pass on one axis cannot hide a failure on the other.
- **Invocation.** It is user-invoked and model-invoked: `/craft:review [ref]`
  in Claude Code, `$review [ref]` in Codex.
- **Where it plugs in.** It replaces `panel-review` wherever `tdd`, `planning`
  and `tdd-guardian` point at it today. `/delegate` keeps its own pipeline
  (`tdd-guardian`, `acceptance-review`, `/code-review`), which already
  covers the same ground.
- **Provenance.** Matt's MIT licence and pinned commit go in
  `review/references/source-notes.md`, as for the other adapted skills.

### D10. Portability: Claude Code and Codex (decided)

craft targets Claude Code first, but everything that can run in Codex should.
Codex reads the same `SKILL.md` format, loads skills on demand, reads
`AGENTS.md` (D5) and installs plugins. Matt ships his repository to Codex with
`codex plugin marketplace add mattpocock/skills`, using his `.claude-plugin/`
manifests plus an `agents/openai.yaml` per skill. Each shipped item gets one of
three tiers:

| Tier | Meaning | Examples |
| --- | --- | --- |
| **portable** | Plain instructions; it works in either harness. | `tdd`, `testing`, `refactoring`, `find-gaps`, `specification`, `story-splitting`, `ubiquitous-language`, `technical-writing`, `grilling` / `grill-me`, `teach`, `writing-for-agents`, `ask` |
| **degrades** | It uses subagents, which it runs in parallel where the harness has them and one after another where it does not. | `review`, `acceptance-review`, `double-check`, `improve-codebase-architecture`, `retro` |
| **claude-only** | It depends on Claude Code tools (Workflow, `send_later`, `create_session`, `/code-review`), Claude agent files or hooks. | `delegating-github-issues`, `/delegate`, `browser-ux-walkthrough`, the Stop hook, `agents/*.md` |

Rules for every skill written or adapted from Phase 1 on:

- **Name capabilities, not tools.** Write "spawn a subagent", not "use the
  Agent tool". Where a Claude Code tool is the only way, put it in a note
  labelled "Claude Code:", with what to do elsewhere. Matt's `codebase-design`
  has an open issue (#564) because its "Agent tool" wording does not port.
- **No harness paths.** Skills do not name `~/.claude/...`. They refer to
  their own folder relatively, and to global instructions as "your global
  `CLAUDE.md` / `AGENTS.md`".
- **Don't rely on temp files across sessions.** Codex clears its temp
  directory between sessions, so anything handed over goes in the repository
  or the project's scratch directory.
- **Invocation is written both ways** where it matters: `/craft:name` in
  Claude Code and `$name` in Codex.
- **The tier is declared in `craft:ask`**, so the router never sends you to a
  claude-only skill in Codex.

### D11. Licences and acknowledgements (decided)

Everything in craft comes from somewhere. The move keeps every notice the
licences require, and makes the credit visible rather than buried in
subfolders.

**What craft carries today** (audited at `.dotfiles` `HEAD`):

| Material | Licence | Copyright / authors | Where the notice lives |
| --- | --- | --- | --- |
| Most skills, agents and commands, and `CLAUDE.md` | MIT | Paul Hammond (2024) | root `LICENSE` |
| `acceptance-review`, `reduce-system-complexity`, `render-code-shape`, `technical-writing`, `wtf` | MIT | Adam Bulmer (2025), `mintuz/skills` | each skill's `LICENSE` + `source-notes.md` (pinned commit) |
| `codebase-design`, `improve-codebase-architecture` | MIT | Matt Pocock (2026), `mattpocock/skills@66898f60` | each skill's `LICENSE` + `source-notes.md` |
| `api-design` | MIT | Addy Osmani (2025) | `LICENSE` + `source-notes.md` |
| `find-skills` | MIT | Vercel, Inc. (2026) | `LICENSE` + `source-notes.md` |
| `cli-design` | **CC BY-SA 4.0** | Aanand Prasad, Ben Firshman, Carl Tashian, Eva Parish, *Command Line Interface Guidelines* | `LICENSE` + `source-notes.md`. Root `LICENSE` says nested notices take precedence |
| `diagrams` | MIT (original rewrite) | — | `NOTICE`: earlier versions held unlicensed text from `markdown-viewer/skills`; the current tree is a rewrite |
| Ideas and methods cited (Fowler, Evans, Feathers, Ousterhout, Cockburn, Ottinger, …) | not copied text, so no licence applies | — | `skills/REFERENCES.md` and per-skill `source-notes.md` |

**Rules in the new repository**

1. **Root `LICENSE`: MIT, with both notices.** It keeps
   `Copyright (c) 2024 Paul Hammond`, which MIT requires because most of
   craft derives from his work, and adds `Copyright (c) 2026 Richard Allen`
   **(confirm: your name, or Conjurer Solutions)**. It keeps the paragraph
   that says nested `LICENSE` / `NOTICE` files govern their directories.
2. **Nested notices move with their directory, byte for byte,** including
   into `shelf/`. Shelving a skill does not remove its licence obligations.
3. **Every adopted or adapted skill gets its own `LICENSE`** (the upstream
   text verbatim, with the upstream copyright line) and
   `references/source-notes.md`. The notes give the pinned commit URL, what
   was taken, and what was changed, with a dated "Modified by …" line. MIT
   does not require the change note, but CC BY-SA and Apache 2.0 do, and one
   habit for all three is simpler. This covers every Matt skill in the
   triage: `grilling`, `grill-me`, `grill-with-docs`, `teach`, `retro`,
   `ask`, `writing-for-agents` and `review`.
4. **Share-alike stays separate.** `cli-design` and anything derived from it
   stay CC BY-SA 4.0. Its text is never pasted into an MIT skill. A skill may
   link to it.
5. **Apache 2.0 needs its `NOTICE` too.** craft has none today. Adopting one
   (Anthropic's skills, `impeccable`) means carrying `LICENSE`, the upstream
   `NOTICE`, and a change notice in each modified file.
6. **No licence, no text.** A source without a clear licence can inform a
   skill as an idea with a citation, but its wording is not copied. The
   `diagrams` notice is the reason for this rule. The fresh import (D2) means
   the new repository's history never contains that material.
7. **One place to see the credits: `ACKNOWLEDGEMENTS.md`** at the root, also
   linked from the README and `craft:ask`:
   - a **licensed sources** table: item, upstream, licence, copyright, pinned
     commit, path to the local notice;
   - **people and projects**: Paul Hammond for the original framework and
     most of the skills; Matt Pocock, Adam Bulmer, Addy Osmani, Vercel and the
     CLI Guidelines authors; Paul Bakaus is not listed, since none of
     `impeccable` is in craft;
   - **ideas**: a pointer to `skills/REFERENCES.md`, which moves unchanged.
8. **`plugin.json`** keeps `"license": "SEE LICENSE IN LICENSE"`, because
   the plugin mixes MIT and CC BY-SA. `author` becomes you, and `homepage`
   points at `ACKNOWLEDGEMENTS.md`.
9. **CI keeps it true** (D8):
   - every directory with a `LICENSE` or `NOTICE` has a row in
     `ACKNOWLEDGEMENTS.md`, and every row's path exists;
   - every `source-notes.md` that names an upstream repository has a
     `LICENSE` beside it, or says "ideas only, no text copied";
   - the root `LICENSE` still contains Paul Hammond's notice.
10. **The upstream watch issue** (D6) carries a licence line for each
    "adopt" or "adapt" suggestion, and rule 3 is part of done for any PR that
    acts on one.

### D12. Delegation without lock-in: a Ralph runner beside `/loop` (proposed)

**How `/loop /delegate` works today.** `/loop` is built into Claude Code, and
it keeps running passes **in the same session and context window**. The
delegation skill also relies on other Claude Code features:

- `ScheduleWakeup` (CLI), plus `send_later`, `create_session`,
  `subscribe_pr_activity`, `get_session` and `set_session_title` (Claude Code
  on the web);
- the Agent tool, for the implementer and reviewer subagents;
- the built-in `/code-review` and `/simplify`;
- `model: opus` pins.

The **Stop rule** (80 % context or 150 tool calls) and **Hand-off**
(`create_session` into a fresh session) exist only because `/loop` reuses one
context.

**What is already neutral.** All state lives on GitHub: claims, the
`in-progress` label, PRs and markers. `delegate-status` is plain bash over
`gh api` REST. A Run pass "holds no state between passes beyond its session
name and pending next pass". That is the precondition for a Ralph loop.

**The Ralph loop** (Geoffrey Huntley's technique): a shell loop that starts a
headless agent CLI with the same prompt over and over. Every iteration is a
new process with an empty context, and state lives on disk and in git. It
needs no harness features, so the CLI is swappable.

**Proposal:** keep `/loop /delegate` for Claude Code, where it works today and
is the only option inside a web session. Add `scripts/delegate-loop`, a
harness-neutral outer loop:

```sh
AGENT=codex scripts/delegate-loop            # or claude | opencode
```

```text
loop:
  status = delegate-status status          # bash + gh, costs no tokens
  if nothing to watch, land or pick:       # most passes end here
    sleep $IDLE (e.g. 15 min); continue
  run one pass with a fresh context:
    claude -p   "$(cat prompts/delegate-run.md)"   |
    codex exec  "$(cat prompts/delegate-run.md)"   |
    opencode run "$(cat prompts/delegate-run.md)"
  stop on: a STOP file, N consecutive failures, or a daily pass/cost budget
```

What this buys:

- **No lock-in.** The same skill runs under Claude Code, Codex or OpenCode.
  OpenCode can drive many providers, including local models, so the
  fallback when prices rise is a config change, not a rewrite.
- **Cheaper idle time.** Today every `/loop` pass spends model tokens just to
  find out that there is nothing to do. The runner asks `delegate-status`
  first and spends tokens only when there is work.
- **Fresh context every pass.** Under the runner the Stop rule rarely trips,
  and Hand-off becomes unnecessary.
- **Mix models by role.** The routing pass can run on a cheap model while
  the implementer runs on a strong one, set per harness in
  `.claude/delegation.md` (`implementer_model`, `review_model`), not pinned
  in the skill.

Where it runs: any always-on machine (your Windows box under WSL or Git Bash,
a small VM) or a scheduled CI job. A cloud Claude Code session cannot host it,
because its container is reclaimed when idle. Headless runs may bill by API
usage rather than a subscription, depending on the CLI and plan. The runner
reports usage per pass so the cost is visible.

**What the skill must change to support it** (Phase 7):

1. **Harness capabilities become optional.** Scheduling, PR subscriptions,
   session titles and Hand-off are each used "where the harness provides
   it". Under the runner they are skipped, because the runner does the
   scheduling.
2. **Subagents by capability.** Implementer and reviewers are "a subagent
   with a fresh context". In Claude Code that is the Agent tool, in Codex its
   configured agents, and under the runner, if the harness has neither, a
   nested `codex exec` / `claude -p` call per role.
3. **Review steps go through `craft:review` (D9)** plus a configurable
   `correctness_review` command (`/code-review`, `codex review`, or none),
   instead of naming Claude's built-ins. The same applies to `/simplify`.
4. **`/delegate` becomes a user-invoked skill** (`$delegate` in Codex), with
   `prompts/delegate-run.md` as the runner's prompt. Permissions move from
   Claude's `allowed-tools` to the runner's sandbox and approval flags per CLI.
5. **The Stop rule stays** as a safety net, but under the runner it ends the
   pass and lets the next iteration start fresh.

## Plan

Each phase ends in a working state; nothing breaks the current install until
Phase 4.

### Phase 0 — decide (this PR)

- ~~Answer the repository-name and `CLAUDE.md` decisions~~ — done (D1, D5).
- Confirm the copyright holder for your share of the root `LICENSE` (D11).
- Run the usage count (D4) locally and fill in the triage table:
  `scripts/skill-usage.py` in this repository (see below).

### Phase 1 — create the repository and import

- Create `conjurer-rich/skills` (private or public), with the root `LICENSE`,
  `ACKNOWLEDGEMENTS.md` and `PROVENANCE.md` (source `.dotfiles` SHA and the
  triage table) as D11 describes.
- Copy **Own** items into the D3 layout; `deprecated/` aliases as noted.
- Write `marketplace.json`, `plugin.json` (explicit skill list, `5.0.0`),
  `hooks/hooks.json`.
- Rewrite `claude/.claude/…` paths in skills, agents, commands and tests (13
  skill/agent/command files and ~30 test references today).
- Licensing pass (D11): nested notices copied verbatim; `LICENSE` and
  `source-notes.md` for each newly adopted Matt skill; the acknowledgements
  check added to CI.
- Port the tests and evals (D8); CI green.

Done when: `claude plugin marketplace add conjurer-rich/skills` and
`claude plugin install craft@conjurer` in a clean home give the same
`craft:` skills, agents, commands and Stop hook as today, minus **Shelf**ed
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

### Phase 6 — Codex

Can start any time after Phase 1; it is independent of the cut-over.

- Confirm which manifest Codex reads when it installs from a repository.
  Matt's repository installs with `.claude-plugin/` plus per-skill
  `agents/openai.yaml` and nothing Codex-specific, but verify this against
  Codex's current docs. Add whatever is missing, and test
  `codex plugin marketplace add conjurer-rich/skills` and
  `codex plugin add craft@conjurer` on a clean machine.
- Give every **portable** and **degrades** skill an `agents/openai.yaml`.
  Many already have one, inherited from upstream.
- Tag every shipped item with its D10 tier in `craft:ask` and the README.
- Add a CI check that **portable** and **degrades** skills do not name
  Claude Code tools (`Agent`, `Skill`, `Workflow`, `ToolSearch`,
  `send_later`, `create_session`) or `~/.claude` paths outside a "Claude
  Code:" note.
- Port the two agents that portable skills lean on (`tdd-guardian`,
  `refactor-scan`). Either express them as skills that any harness can run in
  a subagent, or add Codex agent definitions (`.codex/agents/<name>.toml`)
  next to the Claude ones. Choose one approach for both.
- Turn the `/plan` and `/continue` commands into user-invoked skills
  (`disable-model-invocation: true`) so they work in both harnesses.
  `/delegate` stays Claude-only.
- `scripts/install-global` (D5) already links `~/.codex/AGENTS.md`; check that
  Codex picks it up.
- Smoke test in Codex: `$ask` routes a bug report to `debugging`, `$tdd`
  drives one red-green cycle, `$review` on a small branch produces both
  sections, `$retro` runs. Record the results in the PR.

Done when Codex installs craft from the marketplace on a clean machine, the
portable skills appear and run, `craft:review` produces both axes, and
`craft:ask` marks every claude-only item.

### Phase 7 — harness-neutral delegation

After Phase 6. It follows D12.

- Make the four harness-specific capability groups in
  `delegating-github-issues` optional (D12 change 1), keeping today's
  behaviour under `/loop` in Claude Code. The `delegate-command` and
  `delegation-landing-workflow` tests keep passing.
- Add `delegate-status next-action`, which prints `idle | watch | land | pick`
  plus a reason, as the runner's zero-token gate.
- Write `scripts/delegate-loop` and `prompts/delegate-run.md`, with
  `AGENT=claude|codex|opencode`, an idle sleep, a STOP file, a failure limit
  and a daily pass budget. Test it against a stubbed agent CLI: idle sleeps
  without calling the agent, work calls it once, STOP and the failure limit
  exit cleanly.
- Move the model pins into `.claude/delegation.md` parameters.
- Dry run: one issue end to end in a scratch repository with
  `AGENT=codex`, then with `AGENT=claude`. Compare tokens and wall-clock time
  with `/loop /delegate` on the same issue, and record the results in the PR.

Done when the same labelled issue goes from Pick to an open PR under both
CLIs through `scripts/delegate-loop`, and `/loop /delegate` still works
unchanged in Claude Code.

## Risks

| Risk | Mitigation |
| --- | --- |
| A skill or command routes to a dropped skill | Link check in CI (D8); triage counts routing references as use. |
| Stop hook behaves differently as a plugin hook (`$HOME/.claude/hooks/…` path) | Use `${CLAUDE_PLUGIN_ROOT}` in `hooks.json`; keep the delegator-exemption test. |
| Two plugins installed at once during cut-over → duplicate skills | Uninstall the old one before installing the new one (Phase 4 order). |
| Watch issues become noise | Silent when nothing changed; one issue per run; drop a source from `sources.json` when it stops being useful. |
| `engineering-practice` is skipped on a coding task | The global `CLAUDE.md` / `AGENTS.md` tells every session to load it; Phase 2 checks it fires in a fresh session. |
| A machine has the plugin but not the global file (cloud sessions) | The skill description still says "load first in any coding task"; for Claude Code on the web, add the same line to the environment's setup or the project's own `CLAUDE.md`. |
| A licence notice is lost in the move or on a later adoption | D11's CI checks; nested notices are copied, never rewritten. |
| `review` is shadowed by a harness built-in (Claude Code once shipped `/review`; Codex has `/review`) | In Claude Code it is namespaced as `craft:review`, and in Codex it is called with `$review`, not `/review`. If either harness still shadows it, rename it to `two-axis-review`. |
| A "portable" skill quietly picks up Claude-only wording | The Phase 6 CI check, and `$`-invocation smoke tests in Codex. |
| A runner left alone spends money on a loop of failures | The failure limit, daily pass budget, STOP file and per-pass usage log (Phase 7). |
| The headless CLIs change their flags | The runner keeps one small adapter function per CLI, with a stubbed-CLI test. |
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

### Unused is not the same as useless

The items below went unused in the last month, but some may simply never have
come to mind at the right moment. Two changes address that, rather than
deleting skills or keeping all of them loaded:

1. **A `shelf/` bucket** (Matt's `misc/`, renamed). A shelved skill stays in
   the repository but is not listed in `plugin.json`, so its description costs
   no context in every session and does not compete for routing. Promoting it
   back is a one-line `plugin.json` change. "Drop" now means only that a
   skill moves to the shelf, not that it is deleted.
2. **Make use visible.** Two new skills, both adapted from Matt:
   - **`craft:ask`** (from `ask-matt`): a user-invoked router. You describe
     the situation and it names the skill or flow, including shelved skills
     ("there's a shelved `twelve-factor-audit` for this; promote it?"). It is
     written as **flows** (idea → ship, plus on-ramps), not as a list of
     skills, and it also serves as the README.
   - **`craft:retro`** (from `retro`): run at the end of a session to suggest
     changes to the environment (checks, standards, navigation pointers). The
     adaptation adds one category: **missed skills**, where the session did by
     hand something a craft skill or shelved skill covers. Over time this, and
     re-running `scripts/skill-usage.py` each quarter, is what moves skills
     between the plugin and the shelf.

### When each dormant item earns its place

The trigger for each item goes into `craft:ask`. The **Where** column says
whether it ships in the plugin or sits on the shelf.

| Item | Reach for it when… | Where |
| --- | --- | --- |
| `twelve-factor-audit` (agent) | before a service's first production deploy, or when a deploy works in one environment and not another | plugin (pairs with `twelve-factor`, which you use) |
| `production-parity-skill-builder` | the first time a bug shows up only in production; it builds a per-app parity skill once | shelf |
| `find-skills` | the same kind of task has come up three times with no skill behind it, or `craft:retro` reports a missed skill that craft lacks | plugin (user-invoked) |
| `double-check` | before merging something high-stakes (auth, payments, migrations) for an independent second opinion | plugin |
| `diagrams` | a PR or doc explains a flow, a state machine or a boundary in more than a paragraph | plugin |
| `api-design` | adding an endpoint another team or client consumes | plugin |
| `bff-design` | deciding whether to add a backend-for-frontend, or splitting one | shelf (`bff-entry-points` stays: hexagonal and oauth lean on it) |
| `cli-design` | building a CLI tool (it is 3,000 lines; heavy for a rare need) | shelf |
| `xstate`, `react-performance` | a UI flow has more than three states, or a React screen feels slow | plugin while React work continues |
| `render-code-shape` | you want a cited map of existing code's modules and types before changing it | shelf (`codebase-design` covers most of it) |
| `improve-codebase-architecture` | a spare afternoon of upkeep; it finds the candidates | plugin |
| `panel-review` + `graph-engineering` | a multi-lens review of a large change | shelf: you review with `/code-review` (26) and `pr-reviewer` (19) |
| agents `adr`, `learn` | recording a hard-to-reverse decision or a lesson | plugin (they are what `grill-with-docs` should write through, below) |
| commands `/plan`, `/continue` | starting a planned slice; resuming after a merged PR in a stack | plugin (cheap; `planning` points at them) |
| `/setup`, agents `docs-guardian`, `progress-guardian`, `ts-enforcer`, `use-case-data-patterns`, `folder-structure` | — | shelf; `folder-structure` is deleted after one release |

### Where Matt's library has a better-formed version

| Ours | Matt's | Call |
| --- | --- | --- |
| `teach-me` (1,753 lines, many resources) | `teach` (140 lines): a stateful workspace with a mission, lessons, reference sheets and learning records that build up across sessions | **Replace** with an adaptation of `teach`. It is shorter and fits "learn this over weeks" better. |
| `wtf` (70 lines, UK English) | `wait-what` (7 lines, uses the glossary's vocabulary) | Keep one: `wtf` with one line added to use `GLOSSARY.md` terms. |
| (none, but you used `grill-me` 8 times and `superpowers:brainstorming` 11 times) | `grilling`, `grill-me`, `grill-with-docs` | **Adopt** all three. Adapt `grill-with-docs` to record terms through `ubiquitous-language` and decisions through `adr`, instead of Matt's `domain-modeling`, so there is one glossary system. This becomes step 1 of the main flow, ahead of `find-gaps`. |
| (none) | `retro` | **Adopt** as `craft:retro`, as above. |
| (none) | `ask-matt` | **Adopt** as `craft:ask`, rewritten for craft's flows. |
| (none) | `writing-for-agents` | **Adopt**: you are now the author of your skills, and it is the style guide for skills and `CLAUDE.md` / `AGENTS.md`. `retro` loads it. |
| `panel-review` | `code-review` (two axes: standards and spec) | Shelve `panel-review`. **Adapt** Matt's into `craft:review` (D9), which runs the same in Claude Code and Codex. It is not called `code-review`, because that name collides with Claude Code's built-in. |
| `improve-codebase-architecture`, `codebase-design` | same names; ours are adaptations of `66898f60` | Keep ours; the watch routine flags Matt's changes. |
| `debugging` | `diagnosing-bugs` | Keep ours (you use it); watch. |
| `specification`, `story-splitting`, `planning` | `to-spec`, `to-tickets`, `wayfinder` | Keep ours: they feed `/delegate`. Note `wayfinder` for a greenfield or multi-week effort; shelf it if adopted. |
| (none) | `research`, `prototype`, `handoff` | Optional. `research` (background agent, cited Markdown file in the repo) is the most likely to help. |

### Used, but not part of craft: candidates to adopt or watch

- `grill-me` (Matt) ×8: adopt, with `grilling` and `grill-with-docs` (above).
- `superpowers:*` (brainstorming ×11, writing/executing plans, git worktrees,
  systematic debugging): overlaps `planning`, `specification` and `debugging`.
  Consider adding `obra/superpowers` to `upstream/sources.json`.
- `code-review` ×26, `simplify` ×14: built into Claude Code; nothing to move.
- `flow-canvas-*`, `pr-reviewer`, `steward`, `pre-commit`: project-local; they
  stay in their projects.
