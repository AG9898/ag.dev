# ag.dev — Agent Working Guide

<!-- AGENTS.md is the canonical file. CLAUDE.md is a symlink to it. -->
<!-- To set up: ln -sf AGENTS.md CLAUDE.md                           -->

This repo is the single source of truth for harness-neutral, cross-project agent skills
and project templates. You are operating inside ag.dev. Your job here is to author,
maintain, and sync skills — not to execute them against a product codebase.

---

## What This Repo Is

- `skills-core/` — canonical skill definitions. Each skill lives in its own folder
  with a `SKILL.md`. Skills are harness-neutral: they use `{{CMD_PREFIX}}` as a
  placeholder instead of a harness-specific prefix (`/` for Claude, `$` for Codex).
- `statusline/` — reusable machine-level status-line config for Codex and Claude.
- `adapters/README.md` — conventions for rendering skills into harness-specific
  directories (`.claude/skills/`, `.agents/skills/`, `.codex/skills/`).
- `scripts/sync-skills-claude.sh` — renders skills for Claude (`.claude/skills/`).
- `scripts/sync-skills-codex.sh` — renders skills for Codex (`.agents/skills/`, `.codex/skills/`).
- `scripts/sync-skills-all.sh` — thin wrapper that runs both scripts against the same target.
- `scripts/resync-skills.py` — registry-driven, drift-safe refresh for opted-in skills across local target repos.
- `scripts/install-statusline.sh` — installs reusable status-line config into a machine home.
- `skills-core/skills-suggestions.md` — backlog of candidate skills and research notes.

Do not hand-maintain harness-specific copies. Render them with the sync script.

---

## Skill Structure

Every skill follows this layout:

```
skills-core/
  <skill-name>/
    SKILL.md        ← required, harness-neutral, uses {{CMD_PREFIX}}
```

`SKILL.md` required front matter:

```markdown
---
name: <skill-name>
description: <one sentence>
version: 1.0.0
---
```

Available placeholders and their per-harness rendered values:

| Placeholder | Claude | Codex |
|---|---|---|
| `{{CMD_PREFIX}}` | `/` | `$` |
| `{{INSTRUCTION_FILE}}` | `CLAUDE.md` | `AGENTS.md` |
| `{{USER_INPUT_TOOL}}` | `AskUserQuestion` | `request_user_input` |

`{{CMD_PREFIX}}` must appear in any invocation example. `{{INSTRUCTION_FILE}}` must be
used wherever a skill tells the agent to read the repo instruction dispatcher, and
`{{USER_INPUT_TOOL}}` wherever it directs structured user input. Never hard-code `/`,
`$`, `CLAUDE.md`, `AGENTS.md`, `AskUserQuestion`, or `request_user_input` directly in a
`SKILL.md`. Every `SKILL.md` must have a `## Guardrails` section.

---

## How to Add a New Skill

1. Create `skills-core/<skill-name>/SKILL.md` with YAML front matter (`name`,
   `description`, `version`).
2. Write a concise workflow or rule set. Use `{{CMD_PREFIX}}<skill-name>` in examples.
3. Add a `## Guardrails` section — hard rules the skill enforces.
4. Never reference harness-specific paths (`.claude/`, `.agents/`) inside the skill body.
5. Never remove or soften guardrails from existing skills.
6. If derived from the suggestions backlog, mark it implemented in
   `skills-core/skills-suggestions.md`.
7. Use `{{INSTRUCTION_FILE}}` wherever the skill references the repo instruction
   dispatcher (e.g., `CLAUDE.md` / `AGENTS.md`), and `{{USER_INPUT_TOOL}}` for
   structured user-input instructions.
8. Run a dry-run sync to verify rendering is clean:

```bash
./scripts/sync-skills-all.sh --target /tmp/smoke-test --dry-run
```

---

## How to Sync Skills to a Target Repo

```bash
# Sync all harnesses at once (recommended for new repos):
./scripts/sync-skills-all.sh --target /path/to/target-repo

# Claude only:
./scripts/sync-skills-claude.sh --target /path/to/target-repo

# Codex only (agents + codex dirs):
./scripts/sync-skills-codex.sh --target /path/to/target-repo

# Codex with symlinks instead of copies for .codex/:
./scripts/sync-skills-codex.sh --target /path/to/target-repo --symlink-codex

# Sync only one skill:
./scripts/sync-skills-all.sh --target /path/to/target-repo --skill project-plan

# Update only a skill's SKILL.md and preserve its target-specific references:
./scripts/sync-skills-all.sh --target /path/to/target-repo --skill project-plan --skill-md-only

# Dry-run any of the above by appending --dry-run:
./scripts/sync-skills-all.sh --target /path/to/target-repo --dry-run
```

What the scripts do:

- Discover all subdirectories of `skills-core/` dynamically — no hardcoded skill list.
- `sync-skills-claude.sh` renders `.claude/skills/<skill>/SKILL.md` substituting
  `{{CMD_PREFIX}}` → `/`, `{{INSTRUCTION_FILE}}` → `CLAUDE.md`, and
  `{{USER_INPUT_TOOL}}` → `AskUserQuestion`.
- `sync-skills-codex.sh` renders `.agents/skills/` and `.codex/skills/` substituting
  `{{CMD_PREFIX}}` → `$`, `{{INSTRUCTION_FILE}}` → `AGENTS.md`, and
  `{{USER_INPUT_TOOL}}` → `request_user_input`.
- `sync-skills-all.sh` delegates to both scripts; Codex-only flags (`--no-agents`,
  `--no-codex`, `--symlink-codex`) are forwarded and ignored by the Claude script.
- `--skill <name>` limits a sync to one source skill. `--skill-md-only` renders only
  its `SKILL.md`, preserving target-specific files such as `references/`.

No script ever modifies source files in `skills-core/`.

### Re-syncing Registered Target Repos

Use `config/skill-targets.example.json` as the template for the ignored local registry
`config/skill-targets.local.json`. Each target explicitly declares its output layout,
skills, and whether new source skills may be created there; never infer targets by
scanning a broad projects directory.

```bash
# Read-only status report (the default).
python3 scripts/resync-skills.py

# Establish a baseline for existing target files without changing them.
python3 scripts/resync-skills.py --adopt

# Write only source changes whose target copy is unchanged since that baseline.
python3 scripts/resync-skills.py --apply
```

The state file is ignored and stores hashes per target, output, skill, and file.
`--apply` reports target-local changes as `customized` or `conflict` rather than
overwriting them, skips dirty Git worktrees unless `--allow-dirty` is explicit, and
never deletes target files.

---

## How to Install Status Lines

```bash
./scripts/install-statusline.sh
./scripts/install-statusline.sh --dry-run
./scripts/install-statusline.sh --codex-only
./scripts/install-statusline.sh --claude-only
```

The status-line installer reads from `statusline/`, merges Codex `[tui]` keys into
`~/.codex/config.toml`, copies Claude's command script into `~/.claude/`, and sets
Claude's `statusLine` command in `~/.claude/settings.json`. Existing files are
backed up before modification.

---

## What Adapters Are

Adapters are the rendering conventions documented in `adapters/README.md`. The sync
script implements them automatically. Read `adapters/README.md` only when:

- Designing a skill that needs rendering logic beyond `{{CMD_PREFIX}}` substitution.
- Extending the sync scripts to support a new harness.
- Auditing whether rendered copies in a target repo are stale.

Adapter invariants that are never overridden during rendering:
- The `name` field is never changed.
- Safety guardrails are never removed.
- Only declared placeholders (`{{CMD_PREFIX}}`, `{{INSTRUCTION_FILE}}`,
  `{{USER_INPUT_TOOL}}`) are substituted — no other content is rewritten.

---

## Hard Rules

- Never edit rendered skill files (`.claude/skills/`, `.agents/skills/`) in any
  target repo. Edit source in `skills-core/` and re-run sync.
- Never hardcode a skill name list inside any sync script. Skills are discovered
  dynamically via `find`.
- Never commit a `SKILL.md` without a `## Guardrails` section.
- Never commit a `SKILL.md` whose invocation example uses a hard-coded `/` or `$`
  without a `{{CMD_PREFIX}}` equivalent.
- Never hard-code `CLAUDE.md` or `AGENTS.md` in a `SKILL.md` — use `{{INSTRUCTION_FILE}}`.
- Never hard-code `AskUserQuestion` or `request_user_input` in a `SKILL.md` — use
  `{{USER_INPUT_TOOL}}`.
- Never run a sync script against a target repo with uncommitted changes without
  `--dry-run` first.
- Never use `{{CMD_PREFIX}}`, `{{INSTRUCTION_FILE}}`, or `{{USER_INPUT_TOOL}}` in
  `AGENTS_EX.md`. Placeholders are rendered only inside `skills-core/*/SKILL.md`; a
  target repo's `AGENTS.md` is never processed, so a placeholder there ships as literal
  text. Name skills without a prefix.

---

## Repo Validation Commands

```bash
# Check all skill files have required front matter:
for f in skills-core/*/SKILL.md; do
  grep -q '^name:' "$f"    || echo "MISSING name: $f"
  grep -q '^version:' "$f" || echo "MISSING version: $f"
  grep -q 'Guardrails' "$f" || echo "MISSING Guardrails: $f"
done

# Check for hardcoded prefixes in skill sources:
grep -rn '`/' skills-core/
grep -rn '`\$' skills-core/

# Dry-run sync against a temp dir:
./scripts/sync-skills-all.sh --target /tmp/ag-dev-smoke --dry-run
```

---

## Living Document

This file is a running notebook. After completing any task in this repo, update this
file if you discovered:

- A new pattern for structuring skill guardrails.
- A rendering edge case in the sync scripts.
- A new candidate harness that needs an adapter convention.
- A hard rule that would have prevented a mistake you nearly made.

Append under `## Discoveries` below. Keep each entry to 2–3 sentences with a date.
Do not reorganize or rewrite existing entries — append only.

```
### YYYY-MM-DD — <short title>
<What you found and why future agents working here should know it.>
```

---

## Discoveries

<!-- Agents: append new entries here after each task cycle. -->

### 2026-05-03 — Skill reference files are copied without placeholder rendering
The sync scripts render placeholders only in each skill's `SKILL.md`; additional files such as `references/*.md` are copied as-is. Keep harness-specific strings out of reference files, or extend the sync scripts before adding placeholders there.

### 2026-04-23 — Split unified sync into per-harness scripts; added {{INSTRUCTION_FILE}} placeholder
The single `sync-skills.sh` treated Claude and Codex as a 1:1 copy beyond prefix substitution, but three real divergences existed: cross-skill references lacked `{{CMD_PREFIX}}`, the instruction dispatcher filename (`CLAUDE.md` vs `AGENTS.md`) was hardcoded as both names in every rendered file, and sub-agent launch language was undifferentiated. Replaced with `sync-skills-claude.sh` and `sync-skills-codex.sh` (plus `sync-skills-all.sh` wrapper), each substituting their own placeholder set. New rule: any harness-specific string in a skill body must become a `{{PLACEHOLDER}}` — never hardcode.

### 2026-04-29 — Porting repo-local skills into core requires explicit dispatcher and prefix neutralization
When promoting a repo-local skill into `skills-core`, command handoffs that were written as literal harness invocations (for example `$start-task`) must be rewritten to `{{CMD_PREFIX}}...` or rendered copies will drift semantically between harnesses. If the skill workflow tells the agent to consult repo instructions, it should reference `{{INSTRUCTION_FILE}}` directly in the core source to keep both Claude and Codex render outputs correct without post-editing.

### 2026-05-06 — Skills with reference files can carry a `references/` subdirectory in skills-core
The sync scripts copy all files in a skill directory, not just `SKILL.md` — only `SKILL.md` receives placeholder substitution, everything else is copied as-is. This means project-specific reference documents (doc routing tables, workboard format specs) can be generalized and placed in `skills-core/<skill>/references/` and will render correctly into all harness targets. Keep reference files harness-neutral too; they will not receive `{{CMD_PREFIX}}` or `{{INSTRUCTION_FILE}}` substitution.

### 2026-07-06 — Machine-level status-line config lives outside skills-core
Codex and Claude status-line settings are machine-level config, not repo-rendered skills. Keep reusable source under `statusline/` and use `scripts/install-statusline.sh` to merge it into a local home directory with backups.

### 2026-07-20 — AGENTS_EX.md cannot use placeholders, and cannot carry a harness prefix at all
`AGENTS_EX.md` used `{{CMD_PREFIX}}query-workboard` with a note claiming the sync script rendered it, but the scripts only process `skills-core/*/SKILL.md` — a target repo's `AGENTS.md` is never touched, so the placeholder shipped as literal text (caught during the cloo scaffold). Substitution is also not the fix: `CLAUDE.md` is a symlink to `AGENTS.md`, so one file cannot hold both `/` and `$`. Skills are now named unprefixed in bold with a short "Invoking Skills" section explaining the convention. The same constraint applies to any future template file that lands outside `skills-core/`.

### 2026-07-21 — Structured input requires a harness-specific placeholder
`project-plan` needs Claude's `AskUserQuestion` and Codex's `request_user_input`; preserve a neutral source by using `{{USER_INPUT_TOOL}}` and rendering it in both per-harness scripts. Use `--skill <name> --skill-md-only` for an instruction-only rollout when target skills contain repo-specific reference files.

### 2026-09-13 — Documentation audits must discover routing topology before scoring health
Projects use both `docs/INDEX.md` and `docs/README.md` as canonical hubs, often with nested parent README indexes. Documentation-health tooling must discover those routes from the instruction dispatcher and nearest indexes rather than assuming one flat index or treating length alone as a problem.

### 2026-09-13 — Link validation must ignore commented documentation templates
Documentation indexes can keep planned-document examples in HTML comments, which are not live navigation links. Audit helpers should remove comments before checking links or code references while preserving real source line positions for reported findings.

### 2026-09-13 — Selective skill sync preserves resources but not target SKILL.md edits
The `--skill-md-only` mode is useful for refreshing a core skill's rendered instructions while retaining target-specific reference files, but it overwrites the target `SKILL.md` without a drift check. A universal re-sync tool therefore needs per-file baselines and must classify local instruction edits as conflicts rather than treating selective sync as inherently safe.

### 2026-09-13 — Global skill re-sync needs explicit targets and per-file baselines
Do not discover targets by scanning a broad projects directory: repositories can have different harness layouts and local-only skills. Use an ignored local registry to opt in each target, then update only files unchanged since their recorded rendered baseline; classify any untracked or changed target copy as unmanaged, customized, or conflicting instead of overwriting it.
