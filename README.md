# ag.dev

Shared agent setup and reusable skill definitions.

This repo is intended to be the source of truth for reusable, cross-project skills. Harness-specific wrappers (Codex, Claude, etc.) should be generated from `skills-core/` rather than hand-maintained in each project.

## Structure

- `skills-core/`: Canonical, harness-neutral skills.
- `statusline/`: Reusable Codex and Claude status-line config.
- `scripts/sync-skills-all.sh`: Sync/render script for target repos.
- `scripts/resync-skills.py`: Safely re-sync opted-in skills across registered local repos.
- `config/skill-targets.example.json`: Template for the machine-local re-sync registry.
- `scripts/install-statusline.sh`: Install status-line config on a machine.
- `adapters/`: Adapter notes and conventions.

## Sync Skills

Run from this repo:

```bash
cd /home/ag9898/projects/ag.dev
./scripts/sync-skills-all.sh --target /path/to/target-repo --symlink-codex
```

What it does by default:

- Syncs all skills under `skills-core/*` (dynamic; not hardcoded by name)
- Renders `.claude/skills/*` with `{{CMD_PREFIX}}=/`
- Renders `.agents/skills/*` with `{{CMD_PREFIX}}=$`
- With `--symlink-codex`, links `.codex/skills/*` to `.agents/skills/*`

Useful options:

```bash
./scripts/sync-skills-all.sh --help
./scripts/sync-skills-all.sh --target /path/to/repo --dry-run
./scripts/sync-skills-claude.sh --target /path/to/repo
./scripts/sync-skills-codex.sh --target /path/to/repo --symlink-codex
```

## Re-sync Skills Across Projects

Use `config/skill-targets.example.json` to create the ignored local registry at
`config/skill-targets.local.json`. Register each project deliberately: its existing
output directories, opted-in skills, and whether new skills may be installed.

```bash
# Inspect every registered target. This never writes.
python3 scripts/resync-skills.py

# Record the current rendered copies as a baseline without changing target files.
python3 scripts/resync-skills.py --adopt

# Apply only files unchanged since the recorded baseline.
python3 scripts/resync-skills.py --apply

# Limit a review or update to one target and skill.
python3 scripts/resync-skills.py --target example-project --skill project-plan
```

The state file is local and ignored. Files changed in a target after their baseline
are reported as `customized` or `conflict` and are never overwritten by this script.
Targets with a dirty Git worktree are skipped by `--apply` unless `--allow-dirty` is
explicitly supplied. The script never deletes target files.

## Install Status Lines

Run from this repo:

```bash
cd /home/ag9898/projects/ag.dev
./scripts/install-statusline.sh
```

This merges the Codex `[tui]` status-line settings into `~/.codex/config.toml`,
copies the Claude status-line command to `~/.claude/statusline-command.sh`, and
sets `statusLine` in `~/.claude/settings.json`.

## Running Skills (in harness chat)

After syncing into a target repo, invoke skills in the harness chat:

- Slash-style examples: `/query-workboard`, `/start-task`
- Dollar-style examples: `$query-workboard`, `$start-task`

Loop example:

- `/ralphloop start-task iterations:3`
- `$ralphloop start-task iterations:3`
