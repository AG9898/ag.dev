#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
Usage:
  install-statusline.sh [options]

Options:
  --codex-only    Install only Codex status-line config
  --claude-only   Install only Claude status-line config
  --home PATH     Home directory to install into (default: $HOME)
  --dry-run       Print planned changes only
  -h, --help      Show this help

Installs reusable status-line config from statusline/ into:
  ~/.codex/config.toml
  ~/.claude/settings.json
  ~/.claude/statusline-command.sh
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/statusline"

INSTALL_CODEX=1
INSTALL_CLAUDE=1
HOME_DIR="${HOME:?HOME is required}"
DRY_RUN=0

while (($# > 0)); do
  case "$1" in
    --codex-only)
      INSTALL_CLAUDE=0
      shift
      ;;
    --claude-only)
      INSTALL_CODEX=0
      shift
      ;;
    --home)
      HOME_DIR="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$HOME_DIR" ]]; then
  echo "Error: --home requires a non-empty path." >&2
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: missing source directory: $SOURCE_DIR" >&2
  exit 1
fi

run_cmd() {
  if (( DRY_RUN == 1 )); then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

backup_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    local backup="$path.bak.$(date +%Y%m%d%H%M%S)"
    run_cmd cp "$path" "$backup"
  fi
}

install_codex() {
  local codex_dir="$HOME_DIR/.codex"
  local config="$codex_dir/config.toml"

  run_cmd mkdir -p "$codex_dir"
  if (( DRY_RUN == 1 )); then
    printf '[dry-run] upsert Codex [tui] status_line config into %q\n' "$config"
    return
  fi

  backup_file "$config"
  [[ -f "$config" ]] || touch "$config"

  python3 - "$config" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
desired = {
    "status_line": 'status_line = ["current-dir", "five-hour-limit", "context-remaining", "run-state"]',
    "status_line_use_colors": "status_line_use_colors = true",
}

tui_start = None
for index, line in enumerate(lines):
    if line.strip() == "[tui]":
        tui_start = index
        break

if tui_start is None:
    if lines and lines[-1].strip():
        lines.append("")
    lines.append("[tui]")
    lines.extend(desired.values())
else:
    tui_end = len(lines)
    for index in range(tui_start + 1, len(lines)):
        stripped = lines[index].strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            tui_end = index
            break

    seen = set()
    key_re = re.compile(r"^\s*([A-Za-z0-9_-]+)\s*=")
    for index in range(tui_start + 1, tui_end):
        match = key_re.match(lines[index])
        if match and match.group(1) in desired:
            key = match.group(1)
            lines[index] = desired[key]
            seen.add(key)

    missing = [line for key, line in desired.items() if key not in seen]
    if missing:
        lines[tui_end:tui_end] = missing

path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

install_claude() {
  local claude_dir="$HOME_DIR/.claude"
  local settings="$claude_dir/settings.json"
  local command_src="$SOURCE_DIR/claude/statusline-command.sh"
  local command_dst="$claude_dir/statusline-command.sh"

  run_cmd mkdir -p "$claude_dir"
  backup_file "$command_dst"
  run_cmd cp "$command_src" "$command_dst"
  run_cmd chmod 755 "$command_dst"

  if (( DRY_RUN == 1 )); then
    printf '[dry-run] upsert Claude statusLine command into %q\n' "$settings"
    return
  fi

  backup_file "$settings"
  [[ -f "$settings" ]] || printf '{}\n' > "$settings"

  python3 - "$settings" "$command_dst" <<'PY'
import json
import sys
from pathlib import Path

settings_path = Path(sys.argv[1])
command_path = Path(sys.argv[2])

try:
    settings = json.loads(settings_path.read_text(encoding="utf-8") or "{}")
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid JSON in {settings_path}: {exc}") from exc

if not isinstance(settings, dict):
    raise SystemExit(f"Expected JSON object in {settings_path}")

settings["statusLine"] = {
    "type": "command",
    "command": f"bash {command_path}",
}

settings_path.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
PY
}

if (( INSTALL_CODEX == 1 )); then
  install_codex
fi

if (( INSTALL_CLAUDE == 1 )); then
  install_claude
fi

echo "Done."
