#!/usr/bin/env bash

NEXUS_SERVICE=''
declare -ag NEXUS_COMPOSE_FILES=()
declare -ag NEXUS_COMPOSE_PROFILES=()
declare -ag NEXUS_DOCTOR_ARGV=()
declare -ag NEXUS_CHECK_ARGV=()
declare -ag NEXUS_COMPOSE_ARGV=()

service=''
declare -ag compose_files=()
declare -ag compose_profiles=()
declare -ag doctor_argv=()
declare -ag check_argv=()
declare -ag compose_argv=()

_nexus_profile_error() {
  printf 'E_PROFILE: %s\n' "$*" >&2
  return 1
}

_nexus_contained_path() {
  local base="$1" candidate="$2"
  [[ "$candidate" == "$base"/* ]]
}

_nexus_validate_repo_path() {
  local path="$1" root_real="$2" canonical
  [[ -n "$path" ]] || _nexus_profile_error 'empty repository path' || return 1
  [[ "$path" != /* ]] || _nexus_profile_error "absolute path is not allowed: $path" || return 1
  case "/$path/" in
    */../*)
      _nexus_profile_error ".. path component is not allowed: $path"
      return 1
      ;;
  esac
  canonical="$(realpath -m -- "$root_real/$path")" ||
    _nexus_profile_error "cannot canonicalize repository path: $path" || return 1
  _nexus_contained_path "$root_real" "$canonical" ||
    _nexus_profile_error "repository path escapes ROOT: $path" || return 1
}

_nexus_split_list() {
  local value="$1" destination="$2" label="$3"
  local -n output="$destination"
  local -a items=()
  local -A seen=()
  local item

  output=()
  [[ -n "$value" ]] || return 0
  if [[ "$value" == ,* || "$value" == *, || "$value" == *,,* ]]; then
    _nexus_profile_error "$label contains an empty item"
    return 1
  fi
  IFS=, read -r -a items <<< "$value"
  for item in "${items[@]}"; do
    if [[ -v "seen[$item]" ]]; then
      _nexus_profile_error "$label contains a duplicate item: $item"
      return 1
    fi
    seen["$item"]=1
    output+=("$item")
  done
}

_nexus_split_command() {
  local value="$1" destination="$2" label="$3"
  local -n output="$destination"
  local -a items=()
  local item index

  output=()
  if [[ -z "$value" || "$value" == ,* || "$value" == *, || "$value" == *,,* ]]; then
    _nexus_profile_error "$label contains an empty argv item"
    return 1
  fi
  IFS=, read -r -a items <<< "$value"
  for ((index = 1; index < ${#items[@]}; index++)); do
    item="${items[$index]}"
    if [[ ! "$item" =~ ^[A-Za-z0-9_.:-]+$ ]]; then
      _nexus_profile_error "$label contains an unsafe scalar argv item: $item"
      return 1
    fi
  done
  output=("${items[@]}")
}

_nexus_require_profile_key() {
  local key="$1"
  local -n parsed_keys="$2"
  [[ -v "parsed_keys[$key]" ]] || _nexus_profile_error "missing profile key: $key"
}

nexus_load_profile() {
  local profile_name="$1" root_real profiles_real requested profile_file
  local line key value item
  local -A seen=() values=()
  local -a required_keys=(
    PROFILE_VERSION
    SERVICE
    COMPOSE_FILES
    COMPOSE_PROFILES
    DOCTOR_COMMAND
    CHECK_COMMAND
  )

  NEXUS_SERVICE=''
  NEXUS_COMPOSE_FILES=()
  NEXUS_COMPOSE_PROFILES=()
  NEXUS_DOCTOR_ARGV=()
  NEXUS_CHECK_ARGV=()
  NEXUS_COMPOSE_ARGV=()
  service=''
  compose_files=()
  compose_profiles=()
  doctor_argv=()
  check_argv=()
  compose_argv=()

  [[ "$profile_name" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
    _nexus_profile_error "invalid profile name: $profile_name" || return 1
  [[ -n "${ROOT:-}" ]] || _nexus_profile_error 'ROOT is not set' || return 1
  root_real="$(realpath -e -- "$ROOT")" ||
    _nexus_profile_error "cannot resolve ROOT: $ROOT" || return 1
  [[ -d "$root_real" ]] || _nexus_profile_error "ROOT is not a directory: $ROOT" || return 1
  profiles_real="$(realpath -e -- "$root_real/profiles")" ||
    _nexus_profile_error "cannot resolve profiles directory under ROOT" || return 1
  _nexus_contained_path "$root_real" "$profiles_real" ||
    _nexus_profile_error 'profiles directory escapes ROOT' || return 1

  requested="$root_real/profiles/$profile_name.conf"
  profile_file="$(realpath -e -- "$requested" 2>/dev/null)" ||
    _nexus_profile_error "missing profile: $profile_name" || return 1
  _nexus_contained_path "$profiles_real" "$profile_file" ||
    _nexus_profile_error "profile escapes profiles directory: $profile_name" || return 1
  [[ -f "$profile_file" ]] || _nexus_profile_error "profile is not a regular file: $profile_name" || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ ! "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
      _nexus_profile_error "invalid profile line: $line"
      return 1
    fi
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    case "$key" in
      PROFILE_VERSION|SERVICE|COMPOSE_FILES|COMPOSE_PROFILES|DOCTOR_COMMAND|CHECK_COMMAND) ;;
      *)
        _nexus_profile_error "unknown profile key: $key"
        return 1
        ;;
    esac
    if [[ -v "seen[$key]" ]]; then
      _nexus_profile_error "duplicate profile key: $key"
      return 1
    fi
    seen["$key"]=1
    if [[ ! "$value" =~ ^[A-Za-z0-9_./,:-]*$ ]]; then
      _nexus_profile_error "unsafe profile value for $key"
      return 1
    fi
    if [[ -z "$value" && "$key" != COMPOSE_PROFILES ]]; then
      _nexus_profile_error "empty profile value for $key"
      return 1
    fi
    values["$key"]="$value"
  done < "$profile_file"

  for key in "${required_keys[@]}"; do
    _nexus_require_profile_key "$key" seen || return 1
  done
  [[ "${values[PROFILE_VERSION]}" == 1 ]] ||
    _nexus_profile_error 'unsupported PROFILE_VERSION' || return 1
  [[ "${values[SERVICE]}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] ||
    _nexus_profile_error 'unsafe SERVICE identifier' || return 1

  _nexus_split_list "${values[COMPOSE_FILES]}" NEXUS_COMPOSE_FILES COMPOSE_FILES || return 1
  ((${#NEXUS_COMPOSE_FILES[@]} > 0)) ||
    _nexus_profile_error 'COMPOSE_FILES must not be empty' || return 1
  _nexus_split_list "${values[COMPOSE_PROFILES]}" NEXUS_COMPOSE_PROFILES COMPOSE_PROFILES || return 1
  _nexus_split_command "${values[DOCTOR_COMMAND]}" NEXUS_DOCTOR_ARGV DOCTOR_COMMAND || return 1
  _nexus_split_command "${values[CHECK_COMMAND]}" NEXUS_CHECK_ARGV CHECK_COMMAND || return 1

  for item in "${NEXUS_COMPOSE_FILES[@]}"; do
    _nexus_validate_repo_path "$item" "$root_real" || return 1
  done
  _nexus_validate_repo_path "${NEXUS_DOCTOR_ARGV[0]}" "$root_real" || return 1
  _nexus_validate_repo_path "${NEXUS_CHECK_ARGV[0]}" "$root_real" || return 1

  NEXUS_SERVICE="${values[SERVICE]}"
  service="$NEXUS_SERVICE"
  compose_files=("${NEXUS_COMPOSE_FILES[@]}")
  compose_profiles=("${NEXUS_COMPOSE_PROFILES[@]}")
  doctor_argv=("${NEXUS_DOCTOR_ARGV[@]}")
  check_argv=("${NEXUS_CHECK_ARGV[@]}")
}

nexus_compose_args() {
  local item
  [[ -n "$NEXUS_SERVICE" ]] || _nexus_profile_error 'no profile is loaded' || return 1
  NEXUS_COMPOSE_ARGV=(
    docker compose
    --env-file docker/versions.env
    --env-file .env
  )
  for item in "${NEXUS_COMPOSE_FILES[@]}"; do
    NEXUS_COMPOSE_ARGV+=(-f "$item")
  done
  for item in "${NEXUS_COMPOSE_PROFILES[@]}"; do
    NEXUS_COMPOSE_ARGV+=(--profile "$item")
  done
  compose_argv=("${NEXUS_COMPOSE_ARGV[@]}")
}
