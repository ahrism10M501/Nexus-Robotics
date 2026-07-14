#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
export ROOT NEXUS_ENV_FILE="$ROOT/.env"

source "$ROOT/scripts/lib/config.bash"
source "$ROOT/scripts/lib/profile.bash"

NEXUS_ISAAC_COMPAT_VERSION=6.0.1
NEXUS_CONTAINER_FASTDDS=/workspace/config/fastdds.xml
NEXUS_SERVICE_BLOCK=''
NEXUS_NORMALIZED_CONFIG=''
NEXUS_VERBOSE=0
NEXUS_MISSING_REPOSITORY_FILES=''

nexus_usage_error() {
  printf 'E_USAGE\n%s\n' "$1" >&2
  return 2
}

nexus_doctor_fail() {
  printf 'FAIL E_PREREQUISITE\n%s\n%s\n' "$1" "$2" >&2
  return 1
}

nexus_acceptance_fail() {
  printf 'FAIL E_PREREQUISITE\n%s\n%s\n' "$1" "$2" >&2
  return 1
}

nexus_acceptance_skip() {
  printf 'SKIP E_PREREQUISITE\n%s\n%s\n' "$1" "$2" >&2
  return 77
}

nexus_check_note() {
  ((NEXUS_VERBOSE == 0)) || printf 'CHECK %s PASS\n' "$1"
}

nexus_compose_version_supported() {
  local value="$1" major minor patch suffix
  [[ "$value" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)([-+][0-9A-Za-z.-]+)?$ ]] || return 1
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  patch="${BASH_REMATCH[3]}"
  suffix="${BASH_REMATCH[4]-}"
  : "$patch" "$suffix"
  ((10#$major > 2 || (10#$major == 2 && 10#$minor >= 30)))
}

nexus_read_compatible_version() {
  local path="$1" expected="$2" value=''
  [[ -f "$path" && -r "$path" ]] || return 1
  IFS= read -r value < "$path" || [[ -n "$value" ]] || return 1
  value="${value%$'\r'}"
  [[ "$value" == "$expected" || "$value" == "$expected"-* || "$value" == "$expected"+* ]]
}

nexus_resolve_isaac_root() {
  local ambient_root="$1" parsed_root="$2"
  if [[ -n "$ambient_root" ]]; then
    ISAAC_SIM_ROOT="$ambient_root"
  elif [[ -n "$parsed_root" ]]; then
    ISAAC_SIM_ROOT="$parsed_root"
  else
    [[ -n "${HOME:-}" ]] || return 1
    ISAAC_SIM_ROOT="${ISAAC_SIM_ROOT:-$HOME/isaacsim}"
  fi
  export ISAAC_SIM_ROOT
}

nexus_yaml_scalar() {
  local block="$1" indent="$2" key="$3" line value=''
  while IFS= read -r line; do
    if [[ "$line" == "${indent}${key}:"* ]]; then
      value="${line#"${indent}${key}:"}"
      value="${value#${value%%[![:space:]]*}}"
      value="${value%${value##*[![:space:]]}}"
      if [[ ${#value} -ge 2 ]]; then
        if [[ "$value" == \"*\" && "$value" == *\" ]]; then
          value="${value:1:${#value}-2}"
        elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
          value="${value:1:${#value}-2}"
        fi
      fi
      printf '%s\n' "$value"
      return 0
    fi
  done <<< "$block"
  return 1
}

nexus_extract_service_block() {
  local config="$1" selected_service="$2"
  awk -v selected="$selected_service" '
    $0 == "services:" { in_services = 1; next }
    in_services && $0 ~ /^  [^[:space:]][^:]*:$/ {
      if (found) exit
      if ($0 == "  " selected ":") {
        found = 1
        print
      }
      next
    }
    found { print }
  ' <<< "$config"
}

nexus_has_workspace_bind() {
  local block="$1" expected_root="$2"
  awk -v expected="$expected_root" '
    function scalar(line, value) {
      value = line
      sub(/^[^:]*:[[:space:]]*/, "", value)
      if (value ~ /^".*"$/ || value ~ /^\047.*\047$/) {
        value = substr(value, 2, length(value) - 2)
      }
      return value
    }
    function complete() {
      if (volume_type == "bind" && source == expected && target == "/workspace") found = 1
    }
    /^      - / {
      complete()
      volume_type = ""
      source = ""
      target = ""
      if ($0 ~ /^      - type:/) volume_type = scalar($0)
    }
    /^        type:/ { volume_type = scalar($0) }
    /^        source:/ { source = scalar($0) }
    /^        target:/ { target = scalar($0) }
    END { complete(); exit(found ? 0 : 1) }
  ' <<< "$block"
}

nexus_prepare_isaac_compose() {
  if ! nexus_load_profile isaac-host >/dev/null 2>&1; then
    return 1
  fi
  nexus_compose_args
  if ! NEXUS_NORMALIZED_CONFIG="$("${compose_argv[@]}" config 2>/dev/null)"; then
    return 2
  fi
  NEXUS_SERVICE_BLOCK="$(nexus_extract_service_block "$NEXUS_NORMALIZED_CONFIG" "$service")"
  [[ -n "$NEXUS_SERVICE_BLOCK" ]] || return 3
}

nexus_validate_isaac_compose_contract() {
  local network fastdds fastrtps rmw domain
  [[ -f "$ROOT/config/fastdds.xml" && -r "$ROOT/config/fastdds.xml" ]] || return 1
  network="$(nexus_yaml_scalar "$NEXUS_SERVICE_BLOCK" '    ' network_mode)" || return 1
  fastdds="$(nexus_yaml_scalar "$NEXUS_SERVICE_BLOCK" '      ' FASTDDS_DEFAULT_PROFILES_FILE)" || return 1
  fastrtps="$(nexus_yaml_scalar "$NEXUS_SERVICE_BLOCK" '      ' FASTRTPS_DEFAULT_PROFILES_FILE)" || return 1
  rmw="$(nexus_yaml_scalar "$NEXUS_SERVICE_BLOCK" '      ' RMW_IMPLEMENTATION)" || return 1
  domain="$(nexus_yaml_scalar "$NEXUS_SERVICE_BLOCK" '      ' ROS_DOMAIN_ID)" || return 1
  [[ "$network" == host ]] || return 1
  [[ "$fastdds" == "$NEXUS_CONTAINER_FASTDDS" ]] || return 1
  [[ "$fastrtps" == "$NEXUS_CONTAINER_FASTDDS" ]] || return 1
  [[ "$rmw" == rmw_fastrtps_cpp ]] || return 1
  [[ "$domain" == "$ROS_DOMAIN_ID" ]] || return 1
  nexus_has_workspace_bind "$NEXUS_SERVICE_BLOCK" "$ROOT"
}

nexus_validate_core_env() {
  nexus_validate_env >/dev/null 2>&1 || return 1
  [[ "${RMW_IMPLEMENTATION:-}" == rmw_fastrtps_cpp ]] || return 1
  [[ "${ISAAC_SIM_COMPAT_VERSION:-}" == "$NEXUS_ISAAC_COMPAT_VERSION" ]] || return 1
}

nexus_check_repository_files() {
  local path
  local -a missing=()
  local -a required=(
    .env.example
    Dockerfile
    compose.yml
    compose/host-dds.yml
    config/fastdds.xml
    docker/versions.env
    profiles/core.conf
    profiles/isaac-host.conf
    scripts/lib/config.bash
    scripts/lib/profile.bash
  )
  for path in "${required[@]}"; do
    [[ -f "$ROOT/$path" && -r "$ROOT/$path" ]] || missing+=("$path")
  done
  ((${#missing[@]} == 0)) && return 0
  printf -v NEXUS_MISSING_REPOSITORY_FILES '%s ' "${missing[@]}"
  NEXUS_MISSING_REPOSITORY_FILES="${NEXUS_MISSING_REPOSITORY_FILES% }"
  return 1
}

nexus_doctor_main() {
  local mode='base' compose_version ambient_root parsed_root
  ambient_root="${ISAAC_SIM_ROOT-}"

  if (($# > 0)); then
    mode="$1"
    shift
  fi
  case "$mode" in
    base|isaac-host) ;;
    *) nexus_usage_error 'usage: scripts/doctor.bash [base|isaac-host] [--verbose]'; return ;;
  esac
  if (($# > 0)); then
    [[ "$1" == --verbose && $# -eq 1 ]] || {
      nexus_usage_error 'usage: scripts/doctor.bash [base|isaac-host] [--verbose]'
      return
    }
    NEXUS_VERBOSE=1
  fi

  cd "$ROOT"
  command -v docker >/dev/null 2>&1 || {
    nexus_doctor_fail 'Docker Engine is unavailable' 'install Docker Engine and start its daemon'
    return
  }
  docker info >/dev/null 2>&1 || {
    nexus_doctor_fail 'Docker Engine is unavailable' 'docker info'
    return
  }
  nexus_check_note 'docker-engine'

  if ! compose_version="$(docker compose version --short 2>/dev/null)" ||
     ! nexus_compose_version_supported "$compose_version"; then
    nexus_doctor_fail 'Docker Compose 2.30+ is unavailable' 'install Docker Compose 2.30 or newer'
    return
  fi
  nexus_check_note 'docker-compose'

  docker buildx inspect >/dev/null 2>&1 || {
    nexus_doctor_fail 'BuildKit is unavailable' 'docker buildx inspect'
    return
  }
  nexus_check_note 'buildkit'

  if ! nexus_validate_core_env; then
    nexus_doctor_fail 'repository environment is missing or invalid' 'cp .env.example .env'
    return
  fi
  parsed_root="${ISAAC_SIM_ROOT-}"
  nexus_check_note 'environment'

  if ! nexus_check_repository_files; then
    nexus_doctor_fail 'required repository files are missing or unreadable' \
      "inspect local changes, then restore only: $NEXUS_MISSING_REPOSITORY_FILES"
    return
  fi
  nexus_check_note 'repository-files'

  if [[ "$mode" == base ]]; then
    printf 'PASS\n'
    return 0
  fi

  [[ "$(uname -m 2>/dev/null)" == x86_64 ]] || {
    nexus_doctor_fail 'Isaac host requires x86_64' 'use an x86_64 Isaac Sim host'
    return
  }
  nexus_check_note 'host-architecture'

  command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1 || {
    nexus_doctor_fail 'NVIDIA read-only prerequisite probe failed' 'nvidia-smi -L'
    return
  }
  nexus_check_note 'nvidia'

  if ! nexus_resolve_isaac_root "$ambient_root" "$parsed_root"; then
    nexus_doctor_fail 'HOME is required for the Isaac Sim fallback root' 'export HOME=/home/your-user'
    return
  fi
  [[ -d "$ISAAC_SIM_ROOT" ]] || {
    nexus_doctor_fail 'Isaac Sim root is absent' 'export ISAAC_SIM_ROOT=/path/to/isaacsim'
    return
  }
  [[ -e "$ISAAC_SIM_ROOT/isaac-sim.sh" || -L "$ISAAC_SIM_ROOT/isaac-sim.sh" ]] || {
    nexus_doctor_fail 'Isaac Sim launcher is absent' 'export ISAAC_SIM_ROOT=/path/to/isaacsim'
    return
  }
  [[ -f "$ISAAC_SIM_ROOT/isaac-sim.sh" && -x "$ISAAC_SIM_ROOT/isaac-sim.sh" ]] || {
    nexus_doctor_fail 'Isaac Sim launcher is not executable' 'chmod +x "$ISAAC_SIM_ROOT/isaac-sim.sh"'
    return
  }
  nexus_check_note 'isaac-launcher'

  nexus_read_compatible_version "$ISAAC_SIM_ROOT/VERSION" "$NEXUS_ISAAC_COMPAT_VERSION" || {
    nexus_doctor_fail 'Isaac Sim version is missing, unreadable, or incompatible' 'install the compatible Isaac Sim release'
    return
  }
  nexus_check_note 'isaac-version'

  if ! nexus_prepare_isaac_compose; then
    nexus_doctor_fail 'Docker Compose normalization failed' 'docker compose config'
    return
  fi
  if ! nexus_validate_isaac_compose_contract; then
    nexus_doctor_fail 'normalized Compose contract is invalid' 'docker compose config'
    return
  fi
  nexus_check_note 'compose-contract'

  printf 'PASS\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  nexus_doctor_main "$@"
fi
