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
- `adapters/README.md` — conventions for rendering skills into harness-specific
  directories (`.claude/skills/`, `.agents/skills/`, `.codex/skills/`).
- `scripts/sync-skills.sh` — renders `{{CMD_PREFIX}}` and copies skills into a target repo.
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

The `{{CMD_PREFIX}}` placeholder must appear in any invocation example. Never
hard-code `/` or `$` directly in a `SKILL.md` invocation line. Every `SKILL.md`
must have a `## Guardrails` section.

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
7. Run a dry-run sync to verify rendering is clean:

```bash
./scripts/sync-skills.sh --target /tmp/smoke-test --dry-run
```

---

## How to Sync Skills to a Target Repo

```bash
# Standard sync (all harnesses):
./scripts/sync-skills.sh --target /path/to/target-repo

# With .codex symlinks instead of copies:
./scripts/sync-skills.sh --target /path/to/target-repo --symlink-codex

# Dry-run to preview:
./scripts/sync-skills.sh --target /path/to/target-repo --dry-run

# Claude harness only:
./scripts/sync-skills.sh --target /path/to/target-repo --no-agents --no-codex

# Override prefixes:
./scripts/sync-skills.sh --target /path/to/target-repo --claude-prefix / --codex-prefix '$'
```

What the script does:

- Discovers all subdirectories of `skills-core/` dynamically — no hardcoded skill list.
- Renders `.claude/skills/<skill>/SKILL.md` with `{{CMD_PREFIX}}` → `/`.
- Renders `.agents/skills/<skill>/SKILL.md` with `{{CMD_PREFIX}}` → `$`.
- With `--symlink-codex`, creates `.codex/skills/<skill>` as a symlink to
  `../../.agents/skills/<skill>` (requires agents sync to be enabled).

The script never modifies source files in `skills-core/`.

---

## What Adapters Are

Adapters are the rendering conventions documented in `adapters/README.md`. The sync
script implements them automatically. Read `adapters/README.md` only when:

- Designing a skill that needs rendering logic beyond `{{CMD_PREFIX}}` substitution.
- Extending `sync-skills.sh` to support a new harness.
- Auditing whether rendered copies in a target repo are stale.

Adapter invariants that are never overridden during rendering:
- The `name` field is never changed.
- Safety guardrails are never removed.
- Only `{{CMD_PREFIX}}` is substituted — no other content is rewritten.

---

## Hard Rules

- Never edit rendered skill files (`.claude/skills/`, `.agents/skills/`) in any
  target repo. Edit source in `skills-core/` and re-run sync.
- Never hardcode a skill name list inside `sync-skills.sh`. Skills are discovered
  dynamically via `find`.
- Never commit a `SKILL.md` without a `## Guardrails` section.
- Never commit a `SKILL.md` whose invocation example uses a hard-coded `/` or `$`
  without a `{{CMD_PREFIX}}` equivalent.
- Never run `sync-skills.sh` against a target repo with uncommitted changes without
  `--dry-run` first.

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
./scripts/sync-skills.sh --target /tmp/ag-dev-smoke --dry-run
```

---

## Living Document

This file is a running notebook. After completing any task in this repo, update this
file if you discovered:

- A new pattern for structuring skill guardrails.
- A rendering edge case in `sync-skills.sh`.
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
