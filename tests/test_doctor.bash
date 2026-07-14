#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$REPO_ROOT/scripts/doctor.bash" ]] || fail 'scripts/doctor.bash is absent'

link_tool() {
  local bin="$1" name="$2" path
  path="$(command -v "$name")" || fail "test host lacks $name"
  ln -s "$path" "$bin/$name"
}

write_env() {
  local root="$1" isaac_root="${2-}"
  cat > "$root/.env" <<EOF
COMPOSE_PROJECT_NAME=doctor-fixture
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

if [[ "${1:-}" == info && $# -eq 1 ]]; then
  [[ "${FAKE_ENGINE:-ok}" == ok ]]
  exit
fi
if [[ "${1:-}" == buildx && "${2:-}" == inspect && $# -eq 2 ]]; then
  [[ "${FAKE_BUILDKIT:-ok}" == ok ]]
  exit
fi
if [[ "${1:-}" != compose ]]; then
  exit 97
fi

verb=''
for argument in "$@"; do
  case "$argument" in
    version|config) verb="$argument"; break ;;
  esac
done
case "$verb" in
  version)
    [[ "${FAKE_COMPOSE:-ok}" == ok ]] || exit 1
    printf '%s\n' "${FAKE_COMPOSE_VERSION:-2.30.0}"
    ;;
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
  *) exit 98 ;;
esac
EOF
  chmod 0755 "$bin/docker"
}

new_fixture() {
  local root
  root="$(mktemp -d "$tmp/doctor.XXXXXX")"
  mkdir -p "$root/scripts/lib" "$root/profiles" "$root/compose" \
    "$root/config" "$root/docker" "$root/fake-bin" "$root/capture" \
    "$root/home/isaacsim"
  cp "$REPO_ROOT/scripts/doctor.bash" "$root/scripts/doctor.bash"
  cp "$REPO_ROOT/scripts/lib/config.bash" "$root/scripts/lib/config.bash"
  cp "$REPO_ROOT/scripts/lib/profile.bash" "$root/scripts/lib/profile.bash"
  cp "$REPO_ROOT/profiles/core.conf" "$root/profiles/core.conf"
  cp "$REPO_ROOT/profiles/isaac-host.conf" "$root/profiles/isaac-host.conf"
  cp "$REPO_ROOT/compose.yml" "$root/compose.yml"
  cp "$REPO_ROOT/compose/host-dds.yml" "$root/compose/host-dds.yml"
  cp "$REPO_ROOT/config/fastdds.xml" "$root/config/fastdds.xml"
  cp "$REPO_ROOT/.env.example" "$root/.env.example"
  cp "$REPO_ROOT/docker/versions.env" "$root/docker/versions.env"
  : > "$root/Dockerfile"
  write_env "$root" "$root/home/isaacsim"
  printf '6.0.1\n' > "$root/home/isaacsim/VERSION"
  cat > "$root/home/isaacsim/isaac-sim.sh" <<'EOF'
#!/usr/bin/env bash
: "${LAUNCHER_SENTINEL:?}"
: > "$LAUNCHER_SENTINEL"
exit 93
EOF
  chmod 0755 "$root/home/isaacsim/isaac-sim.sh"

  for tool in bash cat dirname grep awk realpath; do
    link_tool "$root/fake-bin" "$tool"
  done
  cat > "$root/fake-bin/uname" <<'EOF'
#!/usr/bin/env bash
: "${DOCKER_CAPTURE_DIR:?}"
printf '%s\0' "$@" > "$DOCKER_CAPTURE_DIR/uname.argv"
[[ "${1:-}" == -m && $# -eq 1 ]] || exit 96
printf '%s\n' "${FAKE_ARCH:-x86_64}"
EOF
  cat > "$root/fake-bin/nvidia-smi" <<'EOF'
#!/usr/bin/env bash
: "${DOCKER_CAPTURE_DIR:?}"
printf '%s\0' "$@" > "$DOCKER_CAPTURE_DIR/nvidia.argv"
[[ "${1:-}" == -L && $# -eq 1 ]] || exit 95
[[ "${FAKE_NVIDIA:-ok}" == ok ]]
EOF
  chmod 0755 "$root/fake-bin/uname" "$root/fake-bin/nvidia-smi"
  write_fake_docker "$root/fake-bin"
  printf '%s\n' "$root"
}

output=''
status=0
run_doctor() {
  local root="$1" mode="$2"
  shift 2
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
      /bin/bash "$root/scripts/doctor.bash" "$mode" 2>&1
  )"
  status=$?
  set -e
  [[ ! -e "$root/launcher-ran" ]] || fail 'doctor executed the Isaac launcher'
}

assert_pass() {
  local label="$1"
  [[ $status -eq 0 ]] || fail "$label failed ($status): $output"
  [[ "$output" == PASS ]] || fail "$label output was not exactly PASS: $output"
}

assert_fail() {
  local label="$1" expected="${2-}"
  [[ $status -ne 0 ]] || fail "$label unexpectedly succeeded"
  [[ "${output%%$'\n'*}" == 'FAIL E_PREREQUISITE' ]] ||
    fail "$label first line was not FAIL E_PREREQUISITE: $output"
  [[ "$(printf '%s\n' "$output" | awk 'END { print NR }')" -eq 3 ]] ||
    fail "$label was not exactly three lines: $output"
  [[ "$(printf '%s\n' "$output" | awk 'END { print NR }')" -le 6 ]] ||
    fail "$label exceeded six lines: $output"
  [[ -z "$expected" || "$output" == *"$expected"* ]] ||
    fail "$label did not mention '$expected': $output"
}

# Core diagnostics stay architecture-neutral and remain compact.
root="$(new_fixture)"
run_doctor "$root" base FAKE_ARCH=aarch64
assert_pass 'base doctor on aarch64'
[[ ! -e "$root/capture/uname.argv" ]] || fail 'base doctor inspected host architecture'

root="$(new_fixture)"
run_doctor "$root" unsupported-mode
[[ $status -eq 2 && "${output%%$'\n'*}" == E_USAGE ]] ||
  fail "unsupported doctor mode was not a distinct usage error: $status: $output"

root="$(new_fixture)"
rm "$root/fake-bin/docker"
run_doctor "$root" base
assert_fail 'missing Docker' 'Docker Engine'

root="$(new_fixture)"
run_doctor "$root" base FAKE_ENGINE=fail
assert_fail 'unavailable Docker daemon' 'Docker Engine'

root="$(new_fixture)"
run_doctor "$root" base FAKE_COMPOSE_VERSION=2.29.9
assert_fail 'old Compose' 'Docker Compose 2.30+'
for compose_version in 2.30.0 v2.30.0-rc.1 2.30.7+build 5.3.1; do
  root="$(new_fixture)"
  run_doctor "$root" base FAKE_COMPOSE_VERSION="$compose_version"
  assert_pass "Compose $compose_version"
done

root="$(new_fixture)"
run_doctor "$root" base FAKE_BUILDKIT=fail
assert_fail 'BuildKit unavailable' 'BuildKit'

root="$(new_fixture)"
printf 'ROS_DOMAIN_ID=7\n' >> "$root/.env"
run_doctor "$root" base
assert_fail 'duplicate env' 'environment'

root="$(new_fixture)"
rm "$root/.env"
run_doctor "$root" base
assert_fail 'missing env' 'environment'

root="$(new_fixture)"
rm "$root/config/fastdds.xml"
run_doctor "$root" base
assert_fail 'missing repository file' 'repository files'

# Isaac-host-only platform and installation checks.
root="$(new_fixture)"
run_doctor "$root" isaac-host FAKE_ARCH=aarch64
assert_fail 'Isaac on aarch64' 'x86_64'

root="$(new_fixture)"
rm "$root/fake-bin/nvidia-smi"
run_doctor "$root" isaac-host
assert_fail 'missing NVIDIA probe' 'NVIDIA'

root="$(new_fixture)"
run_doctor "$root" isaac-host FAKE_NVIDIA=fail
assert_fail 'failed NVIDIA probe' 'NVIDIA'

# Root precedence is ambient override, parsed .env value, then HOME fallback.
root="$(new_fixture)"
write_env "$root" "$root/parsed-root-does-not-exist"
run_doctor "$root" isaac-host
assert_pass 'ambient Isaac root precedence'

root="$(new_fixture)"
parsed_root="$root/parsed-isaac"
mkdir -p "$parsed_root"
printf '6.0.1\n' > "$parsed_root/VERSION"
cp "$root/home/isaacsim/isaac-sim.sh" "$parsed_root/isaac-sim.sh"
chmod 0755 "$parsed_root/isaac-sim.sh"
write_env "$root" "$parsed_root"
run_doctor "$root" isaac-host ISAAC_SIM_ROOT=
assert_pass 'parsed Isaac root precedence'

root="$(new_fixture)"
write_env "$root" ''
run_doctor "$root" isaac-host ISAAC_SIM_ROOT=
assert_pass 'HOME Isaac root fallback'

root="$(new_fixture)"
write_env "$root" ''
run_doctor "$root" isaac-host ISAAC_SIM_ROOT= HOME=
assert_fail 'missing HOME for fallback' 'HOME'

root="$(new_fixture)"
run_doctor "$root" isaac-host ISAAC_SIM_ROOT="$root/absent"
assert_fail 'missing Isaac root' 'Isaac Sim root'

root="$(new_fixture)"
rm "$root/home/isaacsim/isaac-sim.sh"
run_doctor "$root" isaac-host
assert_fail 'missing Isaac launcher' 'Isaac Sim launcher'

root="$(new_fixture)"
chmod 0644 "$root/home/isaacsim/isaac-sim.sh"
run_doctor "$root" isaac-host
assert_fail 'non-executable Isaac launcher' 'executable'

for version in 6.0.1 6.0.1-rc.7 6.0.1+build.4; do
  root="$(new_fixture)"
  printf '%s\n' "$version" > "$root/home/isaacsim/VERSION"
  run_doctor "$root" isaac-host
  assert_pass "Isaac version $version"
done

for version in 6.0.0 6.0.10 ''; do
  root="$(new_fixture)"
  printf '%s\n' "$version" > "$root/home/isaacsim/VERSION"
  run_doctor "$root" isaac-host
  assert_fail "Isaac version '$version'" 'Isaac Sim version'
done

root="$(new_fixture)"
rm "$root/home/isaacsim/VERSION"
run_doctor "$root" isaac-host
assert_fail 'missing VERSION' 'Isaac Sim version'

root="$(new_fixture)"
rm "$root/home/isaacsim/VERSION"
mkdir "$root/home/isaacsim/VERSION"
run_doctor "$root" isaac-host
assert_fail 'non-regular VERSION' 'Isaac Sim version'

root="$(new_fixture)"
chmod 000 "$root/home/isaacsim/VERSION"
if [[ ! -r "$root/home/isaacsim/VERSION" ]]; then
  run_doctor "$root" isaac-host
  assert_fail 'unreadable VERSION' 'Isaac Sim version'
fi

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
  run_doctor "$root" isaac-host "$variable_and_value"
  assert_fail "normalized mismatch $variable_and_value" 'Compose contract'
done

root="$(new_fixture)"
sed -i 's/RMW_IMPLEMENTATION=rmw_fastrtps_cpp/RMW_IMPLEMENTATION=rmw_cyclonedds_cpp/' "$root/.env"
run_doctor "$root" isaac-host
assert_fail 'invalid RMW pin' 'environment'

root="$(new_fixture)"
sed -i 's/ISAAC_SIM_COMPAT_VERSION=6.0.1/ISAAC_SIM_COMPAT_VERSION=6.0.10/' "$root/.env"
run_doctor "$root" isaac-host
assert_fail 'invalid compatibility pin' 'environment'

root="$(new_fixture)"
set +e
output="$(
  cd "$tmp"
  /usr/bin/env -i PATH="$root/fake-bin" HOME="$root/home" \
    ISAAC_SIM_ROOT="$root/home/isaacsim" DOCKER_CAPTURE_DIR="$root/capture" \
    FAKE_REPO_ROOT="$root" LAUNCHER_SENTINEL="$root/launcher-ran" \
    /bin/bash "$root/scripts/doctor.bash" isaac-host --verbose 2>&1
)"
status=$?
set -e
[[ $status -eq 0 ]] || fail "verbose doctor failed: $output"
[[ "$output" == *'CHECK '* && "${output##*$'\n'}" == PASS ]] ||
  fail "verbose doctor lacked fixed check lines or final PASS: $output"
[[ "$output" != *'6.0.1'* ]] || fail 'verbose doctor leaked VERSION content'

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

assert_call "$root/capture/1.argv" info
assert_call "$root/capture/2.argv" compose version --short
assert_call "$root/capture/3.argv" buildx inspect
assert_call "$root/capture/4.argv" compose --env-file docker/versions.env --env-file .env \
  -f compose.yml -f compose/host-dds.yml config
assert_call "$root/capture/uname.argv" -m
assert_call "$root/capture/nvidia.argv" -L

printf 'Doctor contract passed\n'
