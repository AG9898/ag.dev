#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
Usage:
  sync-skills-codex.sh --target <repo-path> [options]

Options:
  --target PATH     Target repo root (required)
  --source PATH     Source skills-core path (default: <this-repo>/skills-core)
  --no-agents       Skip syncing .agents/skills
  --no-codex        Skip syncing .codex/skills
  --symlink-codex   Symlink .codex/skills/<skill> -> ../../.agents/skills/<skill>
                    (requires agents sync enabled)
  --dry-run         Print planned actions only
  -h, --help        Show this help

Renders skills-core into .agents/skills/ and .codex/skills/ with Codex-specific substitutions:
  {{CMD_PREFIX}}       -> $
  {{INSTRUCTION_FILE}} -> AGENTS.md
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SOURCE="$(cd "$SCRIPT_DIR/.." && pwd)/skills-core"

TARGET=""
SOURCE="$DEFAULT_SOURCE"
SYNC_AGENTS=1
SYNC_CODEX=1
SYMLINK_CODEX=0
DRY_RUN=0

while (($# > 0)); do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --source)
      SOURCE="${2:-}"
      shift 2
      ;;
    --no-agents)
      SYNC_AGENTS=0
      shift
      ;;
    --no-codex)
      SYNC_CODEX=0
      shift
      ;;
    --symlink-codex)
      SYMLINK_CODEX=1
      shift
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

if [[ -z "$TARGET" ]]; then
  echo "Error: --target is required." >&2
  usage >&2
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "Error: target repo does not exist: $TARGET" >&2
  exit 1
fi

if [[ ! -d "$SOURCE" ]]; then
  echo "Error: source skills directory does not exist: $SOURCE" >&2
  exit 1
fi

if (( SYMLINK_CODEX == 1 )) && (( SYNC_AGENTS == 0 )); then
  echo "Error: --symlink-codex requires agents sync (do not pass --no-agents)." >&2
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

ensure_dir() {
  run_cmd mkdir -p "$1"
}

escape_sed_replacement() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//&/\\&}"
  value="${value//\//\\/}"
  printf '%s' "$value"
}

render_skill_file() {
  local src="$1"
  local dst="$2"
  local escaped_cmd escaped_inst
  escaped_cmd="$(escape_sed_replacement '$')"
  escaped_inst="$(escape_sed_replacement "AGENTS.md")"
  if (( DRY_RUN == 1 )); then
    printf '[dry-run] render %s -> %s ({{CMD_PREFIX}}=$ {{INSTRUCTION_FILE}}=AGENTS.md)\n' "$src" "$dst"
  else
    sed \
      -e "s/{{CMD_PREFIX}}/${escaped_cmd}/g" \
      -e "s/{{INSTRUCTION_FILE}}/${escaped_inst}/g" \
      "$src" > "$dst"
  fi
}

copy_skill_dir() {
  local skill_name="$1"
  local out_root="$2"
  local src_dir="$SOURCE/$skill_name"
  local out_dir="$out_root/$skill_name"

  ensure_dir "$out_dir"

  while IFS= read -r src_file; do
    local rel_path="${src_file#"$src_dir"/}"
    local dst_file="$out_dir/$rel_path"
    ensure_dir "$(dirname "$dst_file")"
    if [[ "$rel_path" == "SKILL.md" ]]; then
      render_skill_file "$src_file" "$dst_file"
    else
      run_cmd cp "$src_file" "$dst_file"
    fi
  done < <(find "$src_dir" -type f | sort)
}

symlink_codex_skill() {
  local skill_name="$1"
  local codex_skill_dir="$TARGET/.codex/skills/$skill_name"
  local rel_target="../../.agents/skills/$skill_name"

  ensure_dir "$TARGET/.codex/skills"
  if (( DRY_RUN == 1 )); then
    printf '[dry-run] rm -rf %q\n' "$codex_skill_dir"
    printf '[dry-run] ln -s %q %q\n' "$rel_target" "$codex_skill_dir"
  else
    rm -rf "$codex_skill_dir"
    ln -s "$rel_target" "$codex_skill_dir"
  fi
}

mapfile -t SKILLS < <(find "$SOURCE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

if ((${#SKILLS[@]} == 0)); then
  echo "Error: no skills found under source path: $SOURCE" >&2
  exit 1
fi

echo "Syncing skills (Codex) from: $SOURCE"
echo "Target repo: $TARGET"
echo "Skills: ${SKILLS[*]}"
echo "Modes: agents=$SYNC_AGENTS codex=$SYNC_CODEX symlink_codex=$SYMLINK_CODEX dry_run=$DRY_RUN"

if (( SYNC_AGENTS == 1 )); then
  ensure_dir "$TARGET/.agents/skills"
fi
if (( SYNC_CODEX == 1 )); then
  ensure_dir "$TARGET/.codex/skills"
fi

for skill in "${SKILLS[@]}"; do
  if (( SYNC_AGENTS == 1 )); then
    copy_skill_dir "$skill" "$TARGET/.agents/skills"
  fi
  if (( SYNC_CODEX == 1 )); then
    if (( SYMLINK_CODEX == 1 )); then
      symlink_codex_skill "$skill"
    else
      copy_skill_dir "$skill" "$TARGET/.codex/skills"
    fi
  fi
done

echo "Done."
