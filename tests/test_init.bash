#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/lib/config.bash"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

new_root() {
  local root
  root="$(mktemp -d "$tmp/root.XXXXXX")"
  cp "$REPO_ROOT/.env.example" "$root/.env.example"
  cp "$REPO_ROOT/.env.example" "$root/.env"
  printf '%s\n' "$root"
}

validate_root() {
  local root="$1"
  (ROOT="$root"; NEXUS_ENV_FILE=; nexus_validate_env)
}

init_root() {
  local root="$1"
  (ROOT="$root"; NEXUS_ENV_FILE=; nexus_init_env)
}

expect_e_profile() {
  local label="$1"
  shift
  local output
  if output="$("$@" 2>&1)"; then
    fail "$label unexpectedly succeeded"
  fi
  case "$output" in
    *E_PROFILE*) ;;
    *) fail "$label did not report E_PROFILE: $output" ;;
  esac
}

set_value() {
  local file="$1" key="$2" value="$3"
  sed -i "s|^${key}=.*$|${key}=${value}|" "$file"
}

remove_key() {
  local file="$1" key="$2"
  sed -i "/^${key}=/d" "$file"
}

# init copies the template once and preserves an existing local file byte-for-byte.
root="$(new_root)"
rm "$root/.env"
init_root "$root"
cmp -s "$root/.env.example" "$root/.env" || fail 'init did not copy .env.example'
set_value "$root/.env" COMPOSE_PROJECT_NAME preserved-project
before="$(sha256sum "$root/.env")"
init_root "$root"
test "$before" = "$(sha256sum "$root/.env")" || fail 'init overwrote an existing .env'

# Direct library callers retain the explicit fixture hook used by tests and CI.
root="$(new_root)"
override="$tmp/library-override.env"
rm "$root/.env" "$override" 2>/dev/null || true
(ROOT="$root"; NEXUS_ENV_FILE="$override"; nexus_init_env; nexus_validate_env)
cmp -s "$root/.env.example" "$override" || fail 'direct NEXUS_ENV_FILE hook was ignored'
[[ ! -e "$root/.env" ]] || fail 'direct NEXUS_ENV_FILE hook wrote ROOT/.env'

# Runtime identity is explicit: absent, empty, zero/root, non-numeric, and negative all fail.
for key in LOCAL_UID LOCAL_GID; do
  root="$(new_root)"
  remove_key "$root/.env" "$key"
  expect_e_profile "$key missing" validate_root "$root"

  for value in '' 0 root -1; do
    root="$(new_root)"
    set_value "$root/.env" "$key" "$value"
    expect_e_profile "$key=$value" validate_root "$root"
  done
done

# Domain and project values are validated as data, not interpreted by a shell.
for value in '' -1 233 nope '42;touch'; do
  root="$(new_root)"
  set_value "$root/.env" ROS_DOMAIN_ID "$value"
  expect_e_profile "ROS_DOMAIN_ID=$value" validate_root "$root"
done

for value in '' Uppercase 'bad.name' 'bad/name' '-leading' 'has space'; do
  root="$(new_root)"
  set_value "$root/.env" COMPOSE_PROJECT_NAME "$value"
  expect_e_profile "COMPOSE_PROJECT_NAME=$value" validate_root "$root"
done

root="$(new_root)"
remove_key "$root/.env" ROS_DOMAIN_ID
expect_e_profile 'ROS_DOMAIN_ID missing' validate_root "$root"
root="$(new_root)"
remove_key "$root/.env" COMPOSE_PROJECT_NAME
expect_e_profile 'COMPOSE_PROJECT_NAME missing' validate_root "$root"

# Unknown and duplicate keys fail, while the one explicitly nullable key is accepted.
root="$(new_root)"
printf 'UNKNOWN_KEY=value\n' >> "$root/.env"
expect_e_profile 'unknown .env key' validate_root "$root"

root="$(new_root)"
printf 'LOCAL_UID=1234\n' >> "$root/.env"
expect_e_profile 'duplicate .env key' validate_root "$root"

root="$(new_root)"
set_value "$root/.env" ISAAC_SIM_ROOT ''
validate_root "$root" || fail 'empty ISAAC_SIM_ROOT was rejected'

printf 'init tests passed\n'
