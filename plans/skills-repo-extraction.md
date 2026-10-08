# Spec: move the craft skills into their own repository

Status: proposal — nothing here is built yet. Decisions marked **(decide)** need
an answer before Phase 1 starts; everything else has a recommended default.

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
| Repository | `conjurer-rich/.dotfiles` | `conjurer-rich/skills` **(decide name)** |
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
CLAUDE.md               # how to work on THIS repository
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
another skill or command routes to. A small script in the new repository
(`scripts/skill-usage`) produces the table; the triage result goes in the
import PR description.

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

### D5. `CLAUDE.md` and the base/overlay split

Today `~/.claude/CLAUDE.md` is the fork overlay, which `@`-imports Paul's file
installed verbatim as `~/.claude/base-CLAUDE.md`. Decoupling means that import
goes.

Recommended: fold the parts of `CLAUDE.md` and `CLAUDE.rich.md` that are
engineering policy into `engineering-practice` (where plugin users already
get them), and reduce `~/.claude/CLAUDE.md` to a short personal file — personal
preferences plus "load `craft:engineering-practice` before coding". That file is
a dotfile, not plugin content. **(decide: keep a global `CLAUDE.md` at all, and
where it lives.)**

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

- Answer the **(decide)** items: repository name, global `CLAUDE.md`.
- Run the usage count (D4) locally and fill in the triage table.

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

- Move the wanted policy from `CLAUDE.md` / `CLAUDE.rich.md` into
  `engineering-practice`; prune routing lines for dropped skills.
- Write the slim personal `~/.claude/CLAUDE.md` wherever D5 decides.

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
| Licensing drift when adopting from upstream | Keep the existing provenance pattern; the routine's issue template asks for the license check. |
