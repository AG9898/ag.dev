# ag.dev

Shared agent setup and reusable skill definitions.

This repo is intended to be the source of truth for reusable, cross-project skills. Harness-specific wrappers (Codex, Claude, etc.) should be generated from `skills-core/` rather than hand-maintained in each project.

## Structure

- `skills-core/`: Canonical, harness-neutral skills.
- `scripts/sync-skills.sh`: Sync/render script for target repos.
- `adapters/`: Adapter notes and conventions.

## Sync Skills

Run from this repo:

```bash
cd /home/ag9898/projects/ag.dev
./scripts/sync-skills.sh --target /path/to/target-repo --symlink-codex
```

What it does by default:

- Syncs all skills under `skills-core/*` (dynamic; not hardcoded by name)
- Renders `.claude/skills/*` with `{{CMD_PREFIX}}=/`
- Renders `.agents/skills/*` with `{{CMD_PREFIX}}=$`
- With `--symlink-codex`, links `.codex/skills/*` to `.agents/skills/*`

Useful options:

```bash
./scripts/sync-skills.sh --help
./scripts/sync-skills.sh --target /path/to/repo --dry-run
./scripts/sync-skills.sh --target /path/to/repo --no-claude
./scripts/sync-skills.sh --target /path/to/repo --no-agents
./scripts/sync-skills.sh --target /path/to/repo --no-codex
./scripts/sync-skills.sh --target /path/to/repo --claude-prefix / --codex-prefix '$'
```

## Running Skills (in harness chat)

After syncing into a target repo, invoke skills in the harness chat:

- Slash-style examples: `/query-workboard`, `/start-task`
- Dollar-style examples: `$query-workboard`, `$start-task`

Loop example:

- `/ralphloop start-task iterations:3`
- `$ralphloop start-task iterations:3`
