#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$REPO_ROOT/scripts/check_isaac_host.bash" ]] ||
  fail 'scripts/check_isaac_host.bash is absent'

link_tool() {
  local bin="$1" name="$2" path
  path="$(command -v "$name")" || fail "test host lacks $name"
  ln -s "$path" "$bin/$name"
}

write_env() {
  local root="$1" isaac_root="${2-}"
  cat > "$root/.env" <<EOF
COMPOSE_PROJECT_NAME=isaac-fixture
LOCAL_UID=1000
LOCAL_GID=1000
ROS_DOMAIN_ID=42
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
DISPLAY=:0
ISAAC_SIM_ROOT=$isaac_root
ISAAC_SIM_COMPAT_VERSION=6.0.1
NEXUS_XAUTH_FILE=/tmp/nexus.xauth
EOF
}

write_sentinel_launcher() {
  local path="$1"
  cat > "$path" <<'EOF'
#!/usr/bin/env bash
: "${LAUNCHER_SENTINEL:?}"
: > "$LAUNCHER_SENTINEL"
exit 93
EOF
  chmod 0755 "$path"
}

write_fake_docker() {
  local bin="$1"
  cat > "$bin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${DOCKER_CAPTURE_DIR:?}"
count=0
[[ ! -f "$DOCKER_CAPTURE_DIR/count" ]] || read -r count < "$DOCKER_CAPTURE_DIR/count"
count=$((count + 1))
printf '%s\n' "$count" > "$DOCKER_CAPTURE_DIR/count"
printf '%s\0' "$@" > "$DOCKER_CAPTURE_DIR/$count.argv"

if [[ "${1:-}" == inspect ]]; then
  [[ $# -eq 4 && "${2:-}" == --format && "${4:-}" == 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef ]] || exit 97
  printf '%s\n' "${FAKE_ACTUAL_NETWORK:-host}"
  exit
fi
[[ "${1:-}" == compose ]] || exit 98
verb=''
verb_index=0
index=0
for argument in "$@"; do
  index=$((index + 1))
  case "$argument" in
    config|ps|exec) verb="$argument"; verb_index=$index; break ;;
    build|pull|create|up|run|start|restart|stop|down|version) exit 99 ;;
  esac
done
case "$verb" in
  config)
    [[ "${FAKE_COMPOSE:-ok}" == ok ]] || exit 1
    cat <<YAML
services:
  ros2_dev:
    environment:
      FASTDDS_DEFAULT_PROFILES_FILE: ${FAKE_FASTDDS:-/workspace/config/fastdds.xml}
      FASTRTPS_DEFAULT_PROFILES_FILE: ${FAKE_FASTRTPS:-/workspace/config/fastdds.xml}
      RMW_IMPLEMENTATION: ${FAKE_CONFIG_RMW:-rmw_fastrtps_cpp}
      ROS_DOMAIN_ID: "${FAKE_CONFIG_DOMAIN:-42}"
    network_mode: ${FAKE_NETWORK:-host}
    volumes:
      - type: ${FAKE_BIND_TYPE:-bind}
        source: ${FAKE_BIND_SOURCE:-$FAKE_REPO_ROOT}
        target: ${FAKE_BIND_TARGET:-/workspace}
YAML
    ;;
  ps)
    [[ "${FAKE_PS_STATUS:-ok}" == ok ]] || exit 1
    printf '%b' "${FAKE_IDS-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\\n}"
    ;;
  exec)
    case "${FAKE_EXEC_COUNT:-0}" in
      0) export FAKE_EXEC_COUNT=1 ;;
    esac
    command_string="${!#}"
    case "$command_string" in
      'source /etc/profile.d/nexus_env.bash; exec ros2 topic list')
        [[ "${FAKE_LIST_STATUS:-ok}" == ok ]] || {
          [[ "${FAKE_LIST_STATUS:-}" != timeout ]] || exit 124
          exit 1
        }
        printf '%b' "${FAKE_TOPICS:-/clock\\n/rosout\\n}"
        ;;
      'source /etc/profile.d/nexus_env.bash; exec ros2 topic echo /clock --once')
        [[ "${FAKE_ECHO_STATUS:-ok}" == ok ]] || {
          [[ "${FAKE_ECHO_STATUS:-}" != timeout ]] || exit 124
          exit 1
        }
        printf 'clock:\n  sec: 1\n'
        ;;
      *) exit 96 ;;
    esac
    ;;
  *) exit 95 ;;
esac
EOF
  chmod 0755 "$bin/docker"
}

new_fixture() {
  local root
  root="$(mktemp -d "$tmp/isaac.XXXXXX")"
  mkdir -p "$root/scripts/lib" "$root/profiles" "$root/compose" \
    "$root/config" "$root/docker" "$root/fake-bin" "$root/capture" \
    "$root/home/isaacsim"
  cp "$REPO_ROOT/scripts/check_isaac_host.bash" "$root/scripts/check_isaac_host.bash"
  cp "$REPO_ROOT/scripts/doctor.bash" "$root/scripts/doctor.bash"
  cp "$REPO_ROOT/scripts/launch_isaac_sim.sh" "$root/scripts/launch_isaac_sim.sh"
  cp "$REPO_ROOT/scripts/lib/config.bash" "$root/scripts/lib/config.bash"
  cp "$REPO_ROOT/scripts/lib/profile.bash" "$root/scripts/lib/profile.bash"
  cp "$REPO_ROOT/profiles/isaac-host.conf" "$root/profiles/isaac-host.conf"
  cp "$REPO_ROOT/compose.yml" "$root/compose.yml"
  cp "$REPO_ROOT/compose/host-dds.yml" "$root/compose/host-dds.yml"
  cp "$REPO_ROOT/config/fastdds.xml" "$root/config/fastdds.xml"
  cp "$REPO_ROOT/.env.example" "$root/.env.example"
  cp "$REPO_ROOT/docker/versions.env" "$root/docker/versions.env"
  write_env "$root" "$root/home/isaacsim"
  printf '6.0.1-rc.7\n' > "$root/home/isaacsim/VERSION"
  write_sentinel_launcher "$root/home/isaacsim/isaac-sim.sh"
  for tool in bash cat dirname grep awk realpath; do
    link_tool "$root/fake-bin" "$tool"
  done
  cat > "$root/fake-bin/uname" <<'EOF'
#!/usr/bin/env bash
: "${DOCKER_CAPTURE_DIR:?}"
printf '%s\0' "$@" > "$DOCKER_CAPTURE_DIR/uname.argv"
[[ "${1:-}" == -m && $# -eq 1 ]] || exit 94
printf '%s\n' "${FAKE_ARCH:-x86_64}"
EOF
  cat > "$root/fake-bin/nvidia-smi" <<'EOF'
#!/usr/bin/env bash
: "${DOCKER_CAPTURE_DIR:?}"
printf '%s\0' "$@" > "$DOCKER_CAPTURE_DIR/nvidia.argv"
[[ "${1:-}" == -L && $# -eq 1 ]] || exit 93
[[ "${FAKE_NVIDIA:-ok}" == ok ]]
EOF
  cat > "$root/fake-bin/timeout" <<'EOF'
#!/usr/bin/env bash
: "${DOCKER_CAPTURE_DIR:?}"
count=0
[[ ! -f "$DOCKER_CAPTURE_DIR/timeout-count" ]] || read -r count < "$DOCKER_CAPTURE_DIR/timeout-count"
count=$((count + 1))
printf '%s\n' "$count" > "$DOCKER_CAPTURE_DIR/timeout-count"
printf '%s\0' "$@" > "$DOCKER_CAPTURE_DIR/timeout-$count.argv"
[[ "${1:-}" == --kill-after=2s && "${2:-}" == 10s ]] || exit 92
shift 2
exec "$@"
EOF
  chmod 0755 "$root/fake-bin/uname" "$root/fake-bin/nvidia-smi" "$root/fake-bin/timeout"
  write_fake_docker "$root/fake-bin"
  printf '%s\n' "$root"
}

output=''
status=0
run_check() {
  local root="$1"
  shift
  set +e
  output="$(
    cd "$tmp"
    /usr/bin/env -i \
      PATH="$root/fake-bin" \
      HOME="$root/home" \
      ISAAC_SIM_ROOT="$root/home/isaacsim" \
      DOCKER_CAPTURE_DIR="$root/capture" \
      FAKE_REPO_ROOT="$root" \
      LAUNCHER_SENTINEL="$root/launcher-ran" \
      "$@" \
      /bin/bash "$root/scripts/check_isaac_host.bash" 2>&1
  )"
  status=$?
  set -e
  [[ ! -e "$root/launcher-ran" ]] || fail 'acceptance executed the Isaac launcher'
}

assert_result() {
  local label="$1" expected_status="$2" expected_head="$3" expected_text="${4-}"
  [[ $status -eq $expected_status ]] ||
    fail "$label status: expected $expected_status, got $status: $output"
  [[ "${output%%$'\n'*}" == "$expected_head" ]] ||
    fail "$label first line: expected '$expected_head': $output"
  [[ "$(printf '%s\n' "$output" | awk 'END { print NR }')" -eq 3 ]] ||
    fail "$label output was not exactly three lines: $output"
  [[ -z "$expected_text" || "$output" == *"$expected_text"* ]] ||
    fail "$label output did not mention '$expected_text': $output"
}

assert_pass() {
  assert_result "$1" 0 PASS '/clock observed'
  [[ "$output" == $'PASS\n/clock observed\nno action required' ]] ||
    fail "$1 did not use exact PASS output: $output"
}

assert_skip() { assert_result "$1" 77 'SKIP E_PREREQUISITE' "${2-}"; }

assert_fail() {
  local label="$1" expected="${2-}"
  [[ $status -ne 0 && $status -ne 77 ]] ||
    fail "$label was not a blocking non-77 failure ($status): $output"
  [[ "${output%%$'\n'*}" == 'FAIL E_PREREQUISITE' ]] ||
    fail "$label did not use FAIL E_PREREQUISITE: $output"
  [[ "$(printf '%s\n' "$output" | awk 'END { print NR }')" -eq 3 ]] ||
    fail "$label output was not exactly three lines: $output"
  [[ -z "$expected" || "$output" == *"$expected"* ]] ||
    fail "$label did not mention '$expected': $output"
}

# PASS proves a compatible prerelease, exact topic discovery, bounded echo, and no host ros2.
root="$(new_fixture)"
run_check "$root"
assert_pass 'bridge acceptance'

# Explicit root wins, then parsed .env, then the HOME fallback.
root="$(new_fixture)"
write_env "$root" "$root/parsed-root-does-not-exist"
run_check "$root"
assert_pass 'ambient Isaac root precedence'

root="$(new_fixture)"
parsed_root="$root/parsed-isaac"
mkdir -p "$parsed_root"
printf '6.0.1\n' > "$parsed_root/VERSION"
write_sentinel_launcher "$parsed_root/isaac-sim.sh"
write_env "$root" "$parsed_root"
run_check "$root" ISAAC_SIM_ROOT=
assert_pass 'parsed Isaac root precedence'

root="$(new_fixture)"
write_env "$root" ''
run_check "$root" ISAAC_SIM_ROOT=
assert_pass 'HOME Isaac root fallback'

# Exit 77 is limited to platform or absent installation prerequisites.
root="$(new_fixture)"
run_check "$root" FAKE_ARCH=aarch64
assert_skip 'non-x86_64' 'x86_64'

root="$(new_fixture)"
rm "$root/fake-bin/nvidia-smi"
run_check "$root"
assert_skip 'missing NVIDIA probe' 'NVIDIA'

root="$(new_fixture)"
run_check "$root" FAKE_NVIDIA=fail
assert_skip 'failed NVIDIA probe' 'NVIDIA'

root="$(new_fixture)"
run_check "$root" ISAAC_SIM_ROOT="$root/absent"
assert_skip 'missing Isaac root' 'Isaac Sim root'

root="$(new_fixture)"
invalid_root="$root/regular-file-root"
: > "$invalid_root"
run_check "$root" ISAAC_SIM_ROOT="$invalid_root"
assert_fail 'regular-file Isaac root' 'Isaac Sim root'

root="$(new_fixture)"
invalid_root="$root/dangling-root"
ln -s "$root/missing-symlink-target" "$invalid_root"
run_check "$root" ISAAC_SIM_ROOT="$invalid_root"
assert_fail 'dangling-symlink Isaac root' 'Isaac Sim root'

root="$(new_fixture)"
rm "$root/home/isaacsim/isaac-sim.sh"
run_check "$root"
assert_skip 'missing launcher path' 'Isaac Sim launcher'

# Installed-but-invalid states are blocking failures.
root="$(new_fixture)"
chmod 0644 "$root/home/isaacsim/isaac-sim.sh"
run_check "$root"
assert_fail 'non-executable launcher' 'executable'

for version in 6.0.10 6.0.0 ''; do
  root="$(new_fixture)"
  printf '%s\n' "$version" > "$root/home/isaacsim/VERSION"
  run_check "$root"
  assert_fail "incompatible version '$version'" 'Isaac Sim version'
done

for version in 6.0.1 6.0.1+build.4; do
  root="$(new_fixture)"
  printf '%s\n' "$version" > "$root/home/isaacsim/VERSION"
  run_check "$root"
  assert_pass "compatible version $version"
done

root="$(new_fixture)"
printf '6.0.1\r\nignored-secret-second-line\n' > "$root/home/isaacsim/VERSION"
run_check "$root"
assert_pass 'CR and multiline VERSION'
[[ "$output" != *ignored-secret* ]] || fail 'VERSION later line leaked to output'

root="$(new_fixture)"
rm "$root/home/isaacsim/VERSION"
run_check "$root"
assert_fail 'missing VERSION' 'Isaac Sim version'

root="$(new_fixture)"
rm "$root/home/isaacsim/VERSION"
mkdir "$root/home/isaacsim/VERSION"
run_check "$root"
assert_fail 'non-regular VERSION' 'Isaac Sim version'

root="$(new_fixture)"
chmod 000 "$root/home/isaacsim/VERSION"
if [[ ! -r "$root/home/isaacsim/VERSION" ]]; then
  run_check "$root"
  assert_fail 'unreadable VERSION' 'Isaac Sim version'
fi

root="$(new_fixture)"
printf 'UNKNOWN=value\n' >> "$root/.env"
run_check "$root"
assert_fail 'invalid environment' 'environment'

root="$(new_fixture)"
rm "$root/config/fastdds.xml"
run_check "$root"
assert_fail 'missing FastDDS profile' 'Compose contract'

root="$(new_fixture)"
chmod 000 "$root/config/fastdds.xml"
if [[ ! -r "$root/config/fastdds.xml" ]]; then
  run_check "$root"
  assert_fail 'unreadable FastDDS profile' 'Compose contract'
fi

root="$(new_fixture)"
rm "$root/fake-bin/docker"
run_check "$root"
assert_fail 'missing Docker' 'Docker'

root="$(new_fixture)"
run_check "$root" FAKE_COMPOSE=fail
assert_fail 'missing Compose' 'Docker Compose'

for variable_and_value in \
  'FAKE_NETWORK=bridge' \
  'FAKE_FASTDDS=/wrong/fastdds.xml' \
  'FAKE_FASTRTPS=/wrong/fastdds.xml' \
  'FAKE_CONFIG_RMW=rmw_cyclonedds_cpp' \
  'FAKE_CONFIG_DOMAIN=7' \
  'FAKE_BIND_TYPE=volume' \
  'FAKE_BIND_SOURCE=/wrong/repository' \
  'FAKE_BIND_TARGET=/wrong/workspace'; do
  root="$(new_fixture)"
  run_check "$root" "$variable_and_value"
  assert_fail "normalized mismatch $variable_and_value" 'Compose contract'
done

root="$(new_fixture)"
run_check "$root" FAKE_IDS=
assert_fail 'zero running IDs' 'running container'

root="$(new_fixture)"
run_check "$root" FAKE_IDS=$'fixture-container\nsecond-container\n'
assert_fail 'multiple running IDs' 'running container'

root="$(new_fixture)"
run_check "$root" FAKE_IDS=$'not-a-container-id\n'
assert_fail 'invalid running ID' 'running container'

root="$(new_fixture)"
run_check "$root" FAKE_ACTUAL_NETWORK=bridge
assert_fail 'actual non-host network' 'actual network'

root="$(new_fixture)"
run_check "$root" FAKE_LIST_STATUS=fail
assert_fail 'graph list failure' 'ROS graph'

root="$(new_fixture)"
run_check "$root" FAKE_LIST_STATUS=timeout
assert_fail 'graph list timeout' 'ROS graph'

root="$(new_fixture)"
run_check "$root" FAKE_TOPICS=$'/clock_extra\n/rosout\n'
assert_fail 'missing exact /clock' '/clock topic'

root="$(new_fixture)"
run_check "$root" FAKE_ECHO_STATUS=timeout
assert_fail '/clock echo timeout' '/clock observation'

# Every Docker invocation is allow-listed and the two ROS commands are literal argv.
root="$(new_fixture)"
run_check "$root"
assert_pass 'argv audit fixture'
[[ -f "$root/capture/count" ]] || fail 'Docker argv was not recorded'
read -r call_count < "$root/capture/count"
[[ $call_count -eq 5 ]] || fail "expected five Docker calls, got $call_count"

read_nul_array() {
  local path="$1" destination="$2"
  local -n target="$destination"
  mapfile -d '' -t target < "$path"
}

assert_call() {
  local path="$1"
  shift
  local -a actual=() expected=("$@")
  read_nul_array "$path" actual
  [[ ${#actual[@]} -eq ${#expected[@]} ]] ||
    fail "$path argv length: expected ${#expected[@]}, got ${#actual[@]}"
  local index
  for ((index = 0; index < ${#expected[@]}; index++)); do
    [[ "${actual[$index]}" == "${expected[$index]}" ]] ||
      fail "$path argv[$index]: expected '${expected[$index]}', got '${actual[$index]}'"
  done
}

declare -a call=()
compose_prefix=(compose --env-file docker/versions.env --env-file .env -f compose.yml -f compose/host-dds.yml)
assert_call "$root/capture/1.argv" "${compose_prefix[@]}" config
assert_call "$root/capture/2.argv" "${compose_prefix[@]}" ps -q ros2_dev
container_id=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
assert_call "$root/capture/3.argv" inspect --format '{{.HostConfig.NetworkMode}}' "$container_id"
list_command='source /etc/profile.d/nexus_env.bash; exec ros2 topic list'
echo_command='source /etc/profile.d/nexus_env.bash; exec ros2 topic echo /clock --once'
assert_call "$root/capture/4.argv" "${compose_prefix[@]}" exec -T ros2_dev \
  bash --noprofile --norc -c "$list_command"
assert_call "$root/capture/5.argv" "${compose_prefix[@]}" exec -T ros2_dev \
  bash --noprofile --norc -c "$echo_command"
assert_call "$root/capture/uname.argv" -m
assert_call "$root/capture/nvidia.argv" -L
assert_call "$root/capture/timeout-1.argv" --kill-after=2s 10s docker "${compose_prefix[@]}" exec -T ros2_dev \
  bash --noprofile --norc -c "$list_command"
assert_call "$root/capture/timeout-2.argv" --kill-after=2s 10s docker "${compose_prefix[@]}" exec -T ros2_dev \
  bash --noprofile --norc -c "$echo_command"

for argv_file in "$root"/capture/*.argv; do
  read_nul_array "$argv_file" call
  joined=" ${call[*]} "
  for forbidden in build pull create up run start restart stop down pub service action send_goal; do
    [[ "$joined" != *" $forbidden "* ]] || fail "forbidden command '$forbidden' was observed"
  done
done

# The shared semantic version parser accepts the supported Compose families without
# adding a forbidden acceptance-time `docker compose version` call.
for compose_version in v2.30.0 2.30.4-rc.2 2.30.4+build 5.3.1; do
  /usr/bin/env -i PATH="$root/fake-bin" HOME="$root/home" /bin/bash -c \
    'source "$1/scripts/doctor.bash"; nexus_compose_version_supported "$2"' \
    task6 "$root" "$compose_version" || fail "Compose parser rejected $compose_version"
done

# Launcher uses safe env parsing, root precedence, canonical FastDDS, and exact argv forwarding.
install_recording_launcher() {
  local root="$1" isaac_root="$2"
  mkdir -p "$isaac_root"
  printf '6.0.1+fixture\n' > "$isaac_root/VERSION"
  cat > "$isaac_root/isaac-sim.sh" <<'EOF'
#!/usr/bin/env bash
: "${LAUNCH_ARGS_CAPTURE:?}" "${LAUNCH_ENV_CAPTURE:?}"
printf '%s\0' "$@" > "$LAUNCH_ARGS_CAPTURE"
printf '%s\0' "$ROS_DOMAIN_ID" "$RMW_IMPLEMENTATION" \
  "$FASTDDS_DEFAULT_PROFILES_FILE" "$FASTRTPS_DEFAULT_PROFILES_FILE" > "$LAUNCH_ENV_CAPTURE"
EOF
  chmod 0755 "$isaac_root/isaac-sim.sh"
}

run_launcher() {
  local root="$1" ambient_root="$2"
  shift 2
  set +e
  output="$(
    cd "$tmp"
    /usr/bin/env -i PATH="$root/fake-bin" HOME="$root/home" \
      ISAAC_SIM_ROOT="$ambient_root" LAUNCH_ARGS_CAPTURE="$root/launch.argv" \
      LAUNCH_ENV_CAPTURE="$root/launch.env" \
      /bin/bash "$root/scripts/launch_isaac_sim.sh" "$@" 2>&1
  )"
  status=$?
  set -e
}

root="$(new_fixture)"
explicit_root="$root/explicit-isaac"
install_recording_launcher "$root" "$explicit_root"
run_launcher "$root" "$explicit_root" --reset-user 'two words' '$literal' ''
[[ $status -eq 0 ]] || fail "explicit-root launcher failed: $output"
read_nul_array "$root/launch.argv" call
[[ ${#call[@]} -eq 4 && "${call[0]}" == --reset-user && "${call[1]}" == 'two words' && \
   "${call[2]}" == '$literal' && -z "${call[3]}" ]] || fail 'launcher argv was not byte-preserved'
read_nul_array "$root/launch.env" call
[[ ${#call[@]} -eq 4 && "${call[0]}" == 42 && "${call[1]}" == rmw_fastrtps_cpp && \
   "${call[2]}" == "$root/config/fastdds.xml" && "${call[3]}" == "$root/config/fastdds.xml" ]] ||
  fail 'launcher ROS/FastDDS environment differed'

root="$(new_fixture)"
write_env "$root" ''
install_recording_launcher "$root" "$root/home/isaacsim"
run_launcher "$root" '' --fallback
[[ $status -eq 0 ]] || fail "HOME fallback launcher failed: $output"

root="$(new_fixture)"
rm "$root/home/isaacsim/isaac-sim.sh"
run_launcher "$root" "$root/home/isaacsim"
[[ $status -ne 0 && ! -e "$root/launch.argv" ]] || fail 'missing launcher executed or succeeded'

root="$(new_fixture)"
run_launcher "$root" "$root/absent" --help
[[ $status -eq 0 && ! -e "$root/launch.argv" ]] || fail 'launcher help consulted or executed Isaac'

for mutation in rmw compat fastdds version; do
  root="$(new_fixture)"
  install_recording_launcher "$root" "$root/home/isaacsim"
  case "$mutation" in
    rmw) sed -i 's/rmw_fastrtps_cpp/rmw_cyclonedds_cpp/' "$root/.env" ;;
    compat) sed -i 's/ISAAC_SIM_COMPAT_VERSION=6.0.1/ISAAC_SIM_COMPAT_VERSION=6.0.10/' "$root/.env" ;;
    fastdds) rm "$root/config/fastdds.xml" ;;
    version) printf '6.0.10\n' > "$root/home/isaacsim/VERSION" ;;
  esac
  run_launcher "$root" "$root/home/isaacsim"
  [[ $status -ne 0 && ! -e "$root/launch.argv" ]] ||
    fail "launcher mutation '$mutation' did not fail before exec"
done

printf 'Isaac host contract passed\n'
