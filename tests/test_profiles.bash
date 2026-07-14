#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/lib/profile.bash"

tmp="$(mktemp -d)"
fixture_dir=''
generic_profile="$REPO_ROOT/profiles/generic.conf"
pathless_profile="$REPO_ROOT/profiles/pathless.conf"
pathless_doctor="$REPO_ROOT/task5-pathless-doctor"
pathless_check="$REPO_ROOT/task5-pathless-check"
saved_env=''

cleanup() {
  rm -f "$generic_profile" "$pathless_profile" "$pathless_doctor" "$pathless_check"
  if [[ -n "$fixture_dir" ]]; then
    rm -rf "$fixture_dir"
  fi
  rm -f "$REPO_ROOT/.env"
  if [[ -n "$saved_env" && -e "$saved_env" ]]; then
    mv "$saved_env" "$REPO_ROOT/.env"
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
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

new_profile_root() {
  local root
  root="$(mktemp -d "$tmp/profile-root.XXXXXX")"
  mkdir -p "$root/profiles" "$root/scripts" "$root/compose"
  : > "$root/compose.yml"
  printf '%s\n' "$root"
}

write_profile() {
  local root="$1" name="$2" service="${3:-ros2_dev}"
  local compose_files="${4:-compose.yml}" compose_profiles="${5-}"
  local doctor="${6:-scripts/doctor.bash,base}"
  local check="${7:-scripts/check.bash}"
  {
    printf 'PROFILE_VERSION=1\n'
    printf 'SERVICE=%s\n' "$service"
    printf 'COMPOSE_FILES=%s\n' "$compose_files"
    printf 'COMPOSE_PROFILES=%s\n' "$compose_profiles"
    printf 'DOCTOR_COMMAND=%s\n' "$doctor"
    printf 'CHECK_COMMAND=%s\n' "$check"
  } > "$root/profiles/$name.conf"
}

load_from() {
  local root="$1" name="$2"
  (ROOT="$root"; nexus_load_profile "$name")
}

assert_array() {
  local label="$1" array_name="$2"
  shift 2
  local -n actual="$array_name"
  local -a expected=("$@")
  [[ "${#actual[@]}" -eq "${#expected[@]}" ]] ||
    fail "$label length: expected ${#expected[@]}, got ${#actual[@]}"
  local i
  for ((i = 0; i < ${#expected[@]}; i++)); do
    [[ "${actual[$i]}" == "${expected[$i]}" ]] ||
      fail "$label[$i]: expected '${expected[$i]}', got '${actual[$i]}'"
  done
}

# Names are data and cannot select anything outside profiles/<name>.conf.
root="$(new_profile_root)"
write_profile "$root" good
for name in '' A Upper .hidden -leading trailing-underscore_ has.dot has/slash 'two words'; do
  expect_e_profile "invalid profile name '$name'" load_from "$root" "$name"
done
expect_e_profile 'missing profile' load_from "$root" missing

# The manifest schema is exact: no unknown/duplicate/missing key is accepted.
root="$(new_profile_root)"
write_profile "$root" unknown
printf 'UNKNOWN_KEY=value\n' >> "$root/profiles/unknown.conf"
expect_e_profile 'unknown profile key' load_from "$root" unknown

root="$(new_profile_root)"
write_profile "$root" duplicate
printf 'SERVICE=another\n' >> "$root/profiles/duplicate.conf"
expect_e_profile 'duplicate profile key' load_from "$root" duplicate

for key in PROFILE_VERSION SERVICE COMPOSE_FILES COMPOSE_PROFILES DOCTOR_COMMAND CHECK_COMMAND; do
  root="$(new_profile_root)"
  write_profile "$root" missing-key
  sed -i "/^${key}=/d" "$root/profiles/missing-key.conf"
  expect_e_profile "missing profile key $key" load_from "$root" missing-key
done

for key in SERVICE COMPOSE_FILES DOCTOR_COMMAND CHECK_COMMAND; do
  root="$(new_profile_root)"
  write_profile "$root" empty-key
  sed -i "s|^${key}=.*$|${key}=|" "$root/profiles/empty-key.conf"
  expect_e_profile "empty profile key $key" load_from "$root" empty-key
done

root="$(new_profile_root)"
write_profile "$root" empty-profiles
load_from "$root" empty-profiles || fail 'empty COMPOSE_PROFILES was rejected'

# List parsing rejects every empty item and every duplicate.
for value in ',compose.yml' 'compose.yml,' 'compose.yml,,compose/other.yml'; do
  root="$(new_profile_root)"
  write_profile "$root" bad-files ros2_dev "$value"
  expect_e_profile "bad COMPOSE_FILES '$value'" load_from "$root" bad-files
done

for value in ',gpu' 'gpu,' 'gpu,,gui'; do
  root="$(new_profile_root)"
  write_profile "$root" bad-profiles ros2_dev compose.yml "$value"
  expect_e_profile "bad COMPOSE_PROFILES '$value'" load_from "$root" bad-profiles
done

root="$(new_profile_root)"
write_profile "$root" duplicate-files ros2_dev 'compose.yml,compose.yml'
expect_e_profile 'duplicate COMPOSE_FILES item' load_from "$root" duplicate-files

root="$(new_profile_root)"
write_profile "$root" duplicate-profiles ros2_dev compose.yml 'gpu,gpu'
expect_e_profile 'duplicate COMPOSE_PROFILES item' load_from "$root" duplicate-profiles

# Repository paths are relative, contain no .. component, and remain contained after symlinks.
for value in /tmp/compose.yml ../compose.yml compose/../compose.yml compose/a/../../compose.yml; do
  root="$(new_profile_root)"
  write_profile "$root" bad-compose ros2_dev "$value"
  expect_e_profile "unsafe Compose path '$value'" load_from "$root" bad-compose
done

for key_and_value in \
  'doctor|/bin/true' \
  'doctor|../doctor.bash' \
  'doctor|scripts/../doctor.bash' \
  'check|/bin/true' \
  'check|../check.bash' \
  'check|scripts/../check.bash'; do
  kind="${key_and_value%%|*}"
  value="${key_and_value#*|}"
  root="$(new_profile_root)"
  if [[ "$kind" == doctor ]]; then
    write_profile "$root" bad-command ros2_dev compose.yml '' "$value" scripts/check.bash
  else
    write_profile "$root" bad-command ros2_dev compose.yml '' scripts/doctor.bash,base "$value"
  fi
  expect_e_profile "unsafe $kind command path '$value'" load_from "$root" bad-command
done

root="$(new_profile_root)"
outside_profile="$tmp/outside-profile.conf"
write_profile "$root" source-profile
cp "$root/profiles/source-profile.conf" "$outside_profile"
ln -s "$outside_profile" "$root/profiles/profile-escape.conf"
expect_e_profile 'profile symlink escape' load_from "$root" profile-escape

root="$(new_profile_root)"
outside_compose="$tmp/outside-compose.yml"
: > "$outside_compose"
ln -s "$outside_compose" "$root/compose-escape.yml"
write_profile "$root" compose-escape ros2_dev compose-escape.yml
expect_e_profile 'Compose symlink escape' load_from "$root" compose-escape

root="$(new_profile_root)"
outside_check="$tmp/outside-check"
: > "$outside_check"
ln -s "$outside_check" "$root/scripts/check-escape"
write_profile "$root" command-escape ros2_dev compose.yml '' scripts/doctor.bash,base scripts/check-escape
expect_e_profile 'check-command symlink escape' load_from "$root" command-escape

# SERVICE and all manifest values remain inert scalar data.
for service in _leading .leading -leading 'two words' 'svc;touch' 'svc$HOME' 'svc|other'; do
  root="$(new_profile_root)"
  write_profile "$root" unsafe-service "$service"
  expect_e_profile "unsafe SERVICE '$service'" load_from "$root" unsafe-service
done

for value in 'compose.yml;touch' 'compose.yml$(id)' 'compose.yml`id`' 'compose.yml value'; do
  root="$(new_profile_root)"
  write_profile "$root" shell-data ros2_dev "$value"
  expect_e_profile "shell metacharacters '$value'" load_from "$root" shell-data
done

root="$(new_profile_root)"
write_profile "$root" scalar-path ros2_dev compose.yml '' 'scripts/doctor.bash,dir/argument' scripts/check.bash
expect_e_profile 'path-like command scalar' load_from "$root" scalar-path

# Approved manifests resolve to their exact services and Compose-file arrays.
ROOT="$REPO_ROOT"
nexus_load_profile core
[[ "$NEXUS_SERVICE" == ros2_dev ]] || fail "core SERVICE is '$NEXUS_SERVICE'"
assert_array 'core Compose files' NEXUS_COMPOSE_FILES compose.yml
assert_array 'core doctor argv' NEXUS_DOCTOR_ARGV "$REPO_ROOT/scripts/doctor.bash" base
assert_array 'core check argv' NEXUS_CHECK_ARGV "$REPO_ROOT/scripts/check_dev_workflow.sh"

nexus_load_profile isaac-host
[[ "$NEXUS_SERVICE" == ros2_dev ]] || fail "isaac-host SERVICE is '$NEXUS_SERVICE'"
assert_array 'isaac-host Compose files' NEXUS_COMPOSE_FILES compose.yml compose/host-dds.yml
assert_array 'isaac-host doctor argv' NEXUS_DOCTOR_ARGV "$REPO_ROOT/scripts/doctor.bash" isaac-host
assert_array 'isaac-host check argv' NEXUS_CHECK_ARGV "$REPO_ROOT/scripts/check_dev_workflow.sh"

# Real dispatcher fixtures live under the repository so containment checks exercise real paths.
[[ ! -e "$generic_profile" ]] || fail "$generic_profile already exists"
fixture_dir="$(mktemp -d "$REPO_ROOT/.task5-fixtures.XXXXXX")"
fixture_rel="${fixture_dir#"$REPO_ROOT/"}"

for fixture in record-doctor record-check; do
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -euo pipefail\n'
    printf ': "${ARGV_CAPTURE:?}"\n'
    printf 'printf "%%s\\0" "$@" > "$ARGV_CAPTURE"\n'
  } > "$fixture_dir/$fixture"
  chmod 0755 "$fixture_dir/$fixture"
done

write_profile "$REPO_ROOT" generic ros2_dev compose.yml '' \
  "$fixture_rel/record-doctor,diagnose,--verbose" \
  "$fixture_rel/record-check,--mode,static"

if [[ -e "$REPO_ROOT/.env" || -L "$REPO_ROOT/.env" ]]; then
  saved_env="$tmp/saved.env"
  mv "$REPO_ROOT/.env" "$saved_env"
fi
cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"

write_expected() {
  local path="$1"
  shift
  : > "$path"
  printf '%s\0' "$@" > "$path"
}

assert_bytes() {
  local label="$1" expected="$2" actual="$3"
  if ! cmp -s "$expected" "$actual"; then
    printf 'expected %s argv:\n' "$label" >&2
    od -An -tx1 "$expected" >&2
    printf 'actual %s argv:\n' "$label" >&2
    od -An -tx1 "$actual" >&2
    fail "$label argv differed"
  fi
}

doctor_capture="$tmp/doctor.argv"
doctor_expected="$tmp/doctor.expected"
(cd "$REPO_ROOT"; ARGV_CAPTURE="$doctor_capture" ./run.sh generic-doctor)
write_expected "$doctor_expected" diagnose --verbose
assert_bytes 'generic doctor' "$doctor_expected" "$doctor_capture"

check_capture="$tmp/check.argv"
check_expected="$tmp/check.expected"
(cd "$REPO_ROOT"; ARGV_CAPTURE="$check_capture" ./run.sh generic-check)
write_expected "$check_expected" --mode static
assert_bytes 'generic check' "$check_expected" "$check_capture"

expect_e_profile 'missing-dev on main' bash -c "cd '$REPO_ROOT' && ./run.sh missing-dev"

# Fake Docker records each invocation separately as NUL-delimited argv.
fake_bin="$fixture_dir/fake-bin"
mkdir -p "$fake_bin"
{
  printf '#!/usr/bin/env bash\n'
  printf 'set -euo pipefail\n'
  printf ': "${DOCKER_CAPTURE_DIR:?}"\n'
  printf 'count=0\n'
  printf 'if [[ -f "$DOCKER_CAPTURE_DIR/count" ]]; then read -r count < "$DOCKER_CAPTURE_DIR/count"; fi\n'
  printf 'count=$((count + 1))\n'
  printf 'printf "%%s\\n" "$count" > "$DOCKER_CAPTURE_DIR/count"\n'
  printf 'printf "%%s\\0" "$@" > "$DOCKER_CAPTURE_DIR/$count.argv"\n'
  printf 'if (( $# >= 2 )) && [[ "${*: -2}" == "config --services" ]]; then\n'
  printf '  printf "%%s\\n" "${FAKE_SERVICES:-ros2_dev}"\n'
  printf 'fi\n'
} > "$fake_bin/docker"
chmod 0755 "$fake_bin/docker"

docker_capture="$tmp/docker-capture"
mkdir -p "$docker_capture"

reset_docker_capture() {
  rm -f "$docker_capture"/*
}

docker_call_count() {
  if [[ -f "$docker_capture/count" ]]; then
    read -r count < "$docker_capture/count"
    printf '%s\n' "$count"
  else
    printf '0\n'
  fi
}

run_dispatch() {
  local command="$1" services="${2:-ros2_dev}"
  (cd "$REPO_ROOT"; \
    PATH="$fake_bin:$PATH" \
    DOCKER_CAPTURE_DIR="$docker_capture" \
    FAKE_SERVICES="$services" \
    ./run.sh "$command")
}

run_dispatch_with_env_hook() {
  local command="$1" hook="$2"
  (cd "$REPO_ROOT"; \
    PATH="$fake_bin:$PATH" \
    DOCKER_CAPTURE_DIR="$docker_capture" \
    FAKE_SERVICES=ros2_dev \
    NEXUS_ENV_FILE="$hook" \
    ./run.sh "$command")
}

assert_docker_call() {
  local number="$1"
  shift
  local expected="$tmp/docker-$number.expected"
  write_expected "$expected" "$@"
  assert_bytes "Docker call $number" "$expected" "$docker_capture/$number.argv"
}

core_prefix=(compose --env-file docker/versions.env --env-file .env -f compose.yml)
host_prefix=(compose --env-file docker/versions.env --env-file .env -f compose.yml -f compose/host-dds.yml)

assert_lifecycle() {
  local command="$1" prefix_name="$2" lifecycle_count="$3"
  local -n prefix="$prefix_name"
  reset_docker_capture
  run_dispatch "$command"
  [[ "$(docker_call_count)" == "$lifecycle_count" ]] ||
    fail "$command made $(docker_call_count) Docker calls, expected $lifecycle_count"
  assert_docker_call 1 "${prefix[@]}" config --services
  case "$command" in
    dev|isaac-host-dev)
      assert_docker_call 2 "${prefix[@]}" up -d ros2_dev
      assert_docker_call 3 "${prefix[@]}" exec ros2_dev bash
      ;;
    status|isaac-host-status)
      assert_docker_call 2 "${prefix[@]}" ps ros2_dev
      ;;
    down|isaac-host-down)
      assert_docker_call 2 "${prefix[@]}" down
      ;;
  esac
}

assert_lifecycle dev core_prefix 3
assert_lifecycle status core_prefix 2
assert_lifecycle down core_prefix 2
assert_lifecycle isaac-host-dev host_prefix 3
assert_lifecycle isaac-host-status host_prefix 2
assert_lifecycle isaac-host-down host_prefix 2

# A normalized model without the configured service fails before any lifecycle argv.
reset_docker_capture
expect_e_profile 'SERVICE absent from normalized Compose output' run_dispatch dev other_service
[[ "$(docker_call_count)" == 1 ]] || fail 'lifecycle ran after service validation failed'
assert_docker_call 1 "${core_prefix[@]}" config --services

# init/doctor/check are deliberately independent of Compose and Docker availability.
reset_docker_capture
run_dispatch init
[[ "$(docker_call_count)" == 0 ]] || fail 'init invoked Docker'
(cd "$REPO_ROOT"; PATH="$fake_bin:$PATH" DOCKER_CAPTURE_DIR="$docker_capture" \
  ARGV_CAPTURE="$doctor_capture" ./run.sh generic-doctor)
(cd "$REPO_ROOT"; PATH="$fake_bin:$PATH" DOCKER_CAPTURE_DIR="$docker_capture" \
  ARGV_CAPTURE="$check_capture" ./run.sh generic-check)
[[ "$(docker_call_count)" == 0 ]] || fail 'doctor/check invoked Docker normalization'

# Public dispatch never trusts PATH for a slashless repo command and never
# inherits the library-only NEXUS_ENV_FILE test hook. Accumulate all four
# regressions so one RED run shows every vulnerable boundary.
hostile_bin="$fixture_dir/hostile-bin"
mkdir -p "$hostile_bin"
for action_name in doctor check; do
  legitimate="$REPO_ROOT/task5-pathless-$action_name"
  hostile="$hostile_bin/task5-pathless-$action_name"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -euo pipefail\n'
    printf ': "${ARGV_CAPTURE:?}"\n'
    printf 'printf "%%s\\0" "$@" > "$ARGV_CAPTURE"\n'
  } > "$legitimate"
  chmod 0755 "$legitimate"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -euo pipefail\n'
    printf ': "${HOSTILE_SENTINEL:?}"\n'
    printf 'printf hostile > "$HOSTILE_SENTINEL"\n'
  } > "$hostile"
  chmod 0755 "$hostile"
done
write_profile "$REPO_ROOT" pathless ros2_dev compose.yml '' \
  'task5-pathless-doctor,diagnose,--verbose' \
  'task5-pathless-check,--mode,static'

regression_failures=0
for action_name in doctor check; do
  capture="$tmp/pathless-$action_name.argv"
  expected="$tmp/pathless-$action_name.expected"
  sentinel="$tmp/hostile-$action_name"
  if [[ "$action_name" == doctor ]]; then
    write_expected "$expected" diagnose --verbose
  else
    write_expected "$expected" --mode static
  fi
  (cd "$REPO_ROOT"; \
    PATH="$hostile_bin:$PATH" \
    ARGV_CAPTURE="$capture" \
    HOSTILE_SENTINEL="$sentinel" \
    ./run.sh "pathless-$action_name")
  if [[ -e "$sentinel" ]]; then
    printf 'REGRESSION: hostile PATH intercepted pathless %s command\n' "$action_name" >&2
    regression_failures=$((regression_failures + 1))
  fi
  if [[ ! -f "$capture" ]] || ! cmp -s "$expected" "$capture"; then
    printf 'REGRESSION: repository %s argv fixture did not execute directly\n' "$action_name" >&2
    regression_failures=$((regression_failures + 1))
  fi
done

external_env="$tmp/external-valid.env"
cp "$REPO_ROOT/.env.example" "$external_env"
sed -i 's/^LOCAL_UID=.*/LOCAL_UID=0/' "$REPO_ROOT/.env"
reset_docker_capture
if hook_output="$(run_dispatch_with_env_hook status "$external_env" 2>&1)"; then
  printf 'REGRESSION: inherited NEXUS_ENV_FILE bypassed invalid ROOT/.env\n' >&2
  regression_failures=$((regression_failures + 1))
elif [[ "$hook_output" != *E_PROFILE* ]]; then
  printf 'REGRESSION: invalid ROOT/.env did not report E_PROFILE: %s\n' "$hook_output" >&2
  regression_failures=$((regression_failures + 1))
fi
if [[ "$(docker_call_count)" != 0 ]]; then
  printf 'REGRESSION: lifecycle reached Docker after invalid ROOT/.env\n' >&2
  regression_failures=$((regression_failures + 1))
fi

cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
external_init="$tmp/external-init.env"
rm -f "$REPO_ROOT/.env" "$external_init"
(cd "$REPO_ROOT"; NEXUS_ENV_FILE="$external_init" ./run.sh init)
if [[ ! -f "$REPO_ROOT/.env" ]] || ! cmp -s "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"; then
  printf 'REGRESSION: inherited NEXUS_ENV_FILE redirected public init\n' >&2
  regression_failures=$((regression_failures + 1))
fi
if [[ -e "$external_init" ]]; then
  printf 'REGRESSION: public init created the inherited external env path\n' >&2
  regression_failures=$((regression_failures + 1))
fi
if [[ ! -f "$REPO_ROOT/.env" ]]; then
  cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
fi

((regression_failures == 0)) || fail "$regression_failures repository-input regressions detected"

printf 'profile tests passed\n'
