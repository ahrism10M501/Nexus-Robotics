#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/scripts/lib/config.bash"
source "$ROOT/scripts/lib/profile.bash"
cd "$ROOT"

usage() {
  cat <<'USAGE'
Usage: ./run.sh <command>

Commands:
  init
  doctor, build, up, shell, dev, check, status, down
  <profile>-doctor, <profile>-build, <profile>-up, <profile>-shell
  <profile>-dev, <profile>-check, <profile>-status, <profile>-down

Unprefixed actions use the core profile. The standard host diagnostic is
./run.sh isaac-host-doctor.
USAGE
}

dispatch_error() {
  printf 'E_PROFILE: %s\n' "$*" >&2
  return 1
}

parse_command() {
  local command="$1" candidate suffix
  profile=''
  action=''

  case "$command" in
    doctor|build|up|shell|dev|check|status|down)
      profile=core
      action="$command"
      return 0
      ;;
  esac

  for candidate in doctor build up shell dev check status down; do
    suffix="-$candidate"
    if [[ "$command" == *"$suffix" ]]; then
      profile="${command%"$suffix"}"
      action="$candidate"
      return 0
    fi
  done
  dispatch_error "unknown command: $command"
}

require_direct_command() {
  local label="$1" path="$2"
  [[ -f "$path" ]] || dispatch_error "$label command is not a regular file: $path" || return 1
  [[ -x "$path" ]] || dispatch_error "$label command is not executable: $path" || return 1
}

require_compose_files() {
  local path
  for path in "${compose_files[@]}"; do
    [[ -f "$path" ]] || dispatch_error "Compose file does not exist: $path" || return 1
  done
}

require_normalized_service() {
  local services_output
  if ! services_output="$("${compose_argv[@]}" config --services)"; then
    dispatch_error 'Compose normalization failed'
    return 1
  fi
  if ! grep -Fxq -- "$service" <<< "$services_output"; then
    dispatch_error "SERVICE is absent from normalized Compose output: $service"
    return 1
  fi
}

dispatch_lifecycle() {
  nexus_validate_env
  nexus_compose_args
  require_compose_files
  require_normalized_service

  case "$action" in
    build)
      "${compose_argv[@]}" build "$service"
      ;;
    up)
      "${compose_argv[@]}" up -d "$service"
      ;;
    shell)
      "${compose_argv[@]}" exec "$service" bash
      ;;
    dev)
      "${compose_argv[@]}" up -d "$service"
      "${compose_argv[@]}" exec "$service" bash
      ;;
    status)
      "${compose_argv[@]}" ps "$service"
      ;;
    down)
      "${compose_argv[@]}" down
      ;;
  esac
}

command="${1:-}"
if [[ "$command" == init ]]; then
  shift
  (($# == 0)) || dispatch_error 'init does not accept arguments' || exit 1
  nexus_init_env
  exit 0
fi

case "$command" in
  ''|-h|--help|help)
    usage
    exit 0
    ;;
esac

shift
parse_command "$command"
nexus_load_profile "$profile"

case "$action" in
  doctor)
    require_direct_command doctor "${doctor_argv[0]}"
    doctor_argv+=("$@")
    "${doctor_argv[@]}"
    ;;
  check)
    require_direct_command check "${check_argv[0]}"
    check_argv+=("$@")
    "${check_argv[@]}"
    ;;
  build|up|shell|dev|status|down)
    (($# == 0)) || dispatch_error "$action does not accept arguments" || exit 1
    dispatch_lifecycle
    ;;
esac
