#!/usr/bin/env bash

_nexus_config_error() {
  printf 'E_PROFILE: %s\n' "$*" >&2
  return 1
}

_nexus_env_file() {
  if [[ -n "${NEXUS_ENV_FILE:-}" ]]; then
    printf '%s\n' "$NEXUS_ENV_FILE"
  elif [[ -n "${ROOT:-}" ]]; then
    printf '%s/.env\n' "$ROOT"
  else
    _nexus_config_error 'ROOT is not set'
  fi
}

_nexus_env_template() {
  if [[ -n "${ROOT:-}" ]]; then
    printf '%s/.env.example\n' "$ROOT"
  else
    _nexus_config_error 'ROOT is not set'
  fi
}

nexus_init_env() {
  local file template directory temporary
  file="$(_nexus_env_file)" || return 1
  template="$(_nexus_env_template)" || return 1

  if [[ -e "$file" || -L "$file" ]]; then
    return 0
  fi
  [[ -f "$template" ]] || _nexus_config_error "missing environment template: $template" || return 1
  directory="$(dirname -- "$file")"
  mkdir -p -- "$directory" ||
    _nexus_config_error "cannot create environment directory: $directory" || return 1
  temporary="$(mktemp "$directory/.env.tmp.XXXXXX")" ||
    _nexus_config_error "cannot create temporary environment file under: $directory" || return 1
  if ! cp -- "$template" "$temporary"; then
    rm -f -- "$temporary"
    _nexus_config_error "cannot copy environment template: $template"
    return 1
  fi
  if ln -- "$temporary" "$file" 2>/dev/null; then
    rm -f -- "$temporary"
    return 0
  fi
  rm -f -- "$temporary"
  if [[ -e "$file" || -L "$file" ]]; then
    return 0
  fi
  _nexus_config_error "cannot create environment file: $file"
}

_nexus_require_env_key() {
  local key="$1"
  local -n parsed_keys="$2"
  [[ -v "parsed_keys[$key]" ]] || _nexus_config_error "missing environment key: $key"
}

_nexus_positive_integer() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ && -n "${value//0/}" ]]
}

_nexus_domain_in_range() {
  local value="$1" normalized
  [[ "$value" =~ ^[0-9]+$ ]] || return 1
  normalized="$value"
  while [[ ${#normalized} -gt 1 && "$normalized" == 0* ]]; do
    normalized="${normalized#0}"
  done
  [[ ${#normalized} -lt 3 ]] && return 0
  [[ ${#normalized} -eq 3 && "$normalized" -le 232 ]]
}

nexus_validate_env() {
  local file line key value
  local -A seen=()

  file="$(_nexus_env_file)" || return 1
  [[ -f "$file" ]] || _nexus_config_error "missing environment file: $file" || return 1

  unset COMPOSE_PROJECT_NAME LOCAL_UID LOCAL_GID ROS_DOMAIN_ID RMW_IMPLEMENTATION
  unset DISPLAY ISAAC_SIM_ROOT ISAAC_SIM_COMPAT_VERSION NEXUS_XAUTH_FILE

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ ! "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
      _nexus_config_error "invalid environment line: $line"
      return 1
    fi
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    case "$key" in
      COMPOSE_PROJECT_NAME|LOCAL_UID|LOCAL_GID|ROS_DOMAIN_ID|RMW_IMPLEMENTATION|DISPLAY|ISAAC_SIM_ROOT|ISAAC_SIM_COMPAT_VERSION|NEXUS_XAUTH_FILE) ;;
      *)
        _nexus_config_error "unknown environment key: $key"
        return 1
        ;;
    esac
    if [[ -v "seen[$key]" ]]; then
      _nexus_config_error "duplicate environment key: $key"
      return 1
    fi
    seen["$key"]=1
    if [[ ! "$value" =~ ^[A-Za-z0-9_./,:-]*$ ]]; then
      _nexus_config_error "unsafe environment value for $key"
      return 1
    fi
    if [[ -z "$value" && "$key" != ISAAC_SIM_ROOT ]]; then
      _nexus_config_error "empty environment value for $key"
      return 1
    fi
    printf -v "$key" '%s' "$value"
    export "$key"
  done < "$file"

  _nexus_require_env_key COMPOSE_PROJECT_NAME seen || return 1
  _nexus_require_env_key LOCAL_UID seen || return 1
  _nexus_require_env_key LOCAL_GID seen || return 1
  _nexus_require_env_key ROS_DOMAIN_ID seen || return 1

  [[ "$COMPOSE_PROJECT_NAME" =~ ^[a-z0-9][a-z0-9_-]*$ ]] ||
    _nexus_config_error 'invalid COMPOSE_PROJECT_NAME' || return 1
  _nexus_positive_integer "$LOCAL_UID" ||
    _nexus_config_error 'LOCAL_UID must be a positive integer' || return 1
  _nexus_positive_integer "$LOCAL_GID" ||
    _nexus_config_error 'LOCAL_GID must be a positive integer' || return 1
  _nexus_domain_in_range "$ROS_DOMAIN_ID" ||
    _nexus_config_error 'ROS_DOMAIN_ID must be in 0..232' || return 1
}
