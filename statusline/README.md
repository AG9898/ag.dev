# Status Line Configs

Reusable status-line settings for Codex and Claude.

## Install

From this repo:

```bash
./scripts/install-statusline.sh
```

Use `--dry-run` to preview changes:

```bash
./scripts/install-statusline.sh --dry-run
```

Useful options:

```bash
./scripts/install-statusline.sh --codex-only
./scripts/install-statusline.sh --claude-only
./scripts/install-statusline.sh --home /path/to/home
```

## Files

- `codex/config.toml`: TOML fragment for `~/.codex/config.toml`.
- `claude/settings.json`: JSON fragment for `~/.claude/settings.json`.
- `claude/statusline-command.sh`: Claude status-line command script.

The installer writes machine-local absolute paths where needed. Claude's 5-hour
window state is runtime data and is intentionally not stored in this repo.
