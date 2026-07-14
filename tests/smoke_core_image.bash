#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: bash tests/smoke_core_image.bash <platform> <tag> <expected-machine>\n' >&2
}

if (($# != 3)); then
  usage
  exit 2
fi

platform="$1"
tag="$2"
expected_machine="$3"
case "$platform:$expected_machine" in
  linux/amd64:x86_64) container_name=nexus-core-smoke-amd64 ;;
  linux/arm64:aarch64) container_name=nexus-core-smoke-arm64 ;;
  *)
    usage
    exit 2
    ;;
esac

tag_pattern='^[a-z0-9]+([._/-][a-z0-9]+)*(:[A-Za-z0-9_][A-Za-z0-9_.-]{0,127})?$'
if [[ ! "$tag" =~ $tag_pattern ]]; then
  usage
  exit 2
fi

# Never claim or remove a container that predates this invocation.
if docker container inspect "$container_name" >/dev/null 2>&1; then
  printf 'E_STALE_CONTAINER: %s already exists\n' "$container_name" >&2
  exit 1
fi

if ! actual_platform="$(
  docker image inspect --format '{{.Os}}/{{.Architecture}}' "$tag"
)"; then
  printf 'E_IMAGE: local image is unavailable: %s\n' "$tag" >&2
  exit 1
fi
if [[ "$actual_platform" != "$platform" ]]; then
  printf 'E_PLATFORM: expected %s, got %s\n' "$platform" "$actual_platform" >&2
  exit 1
fi

umask 077
cid_dir="$(mktemp -d "${TMPDIR:-/tmp}/nexus-core-smoke.XXXXXX")"
cidfile="$cid_dir/container.cid"
owned_cid=''

load_owned_cid() {
  local candidate bytes
  [[ -f "$cidfile" ]] || return 1
  bytes="$(wc -c < "$cidfile")" || return 1
  [[ "$bytes" == 64 ]] || return 1
  candidate="$(< "$cidfile")"
  [[ "$candidate" =~ ^[0-9a-f]{64}$ ]] || return 1
  owned_cid="$candidate"
}

finalize() {
  local original_status="$?"
  local final_status="$original_status"
  trap - EXIT INT TERM

  if load_owned_cid; then
    if timeout --kill-after=2s 10s \
      docker container inspect "$owned_cid" >/dev/null 2>&1; then
      if ! timeout --kill-after=2s 10s docker rm -f "$owned_cid" >/dev/null 2>&1; then
        printf 'E_CLEANUP: could not remove owned container %s\n' "$owned_cid" >&2
        if ((original_status == 0)); then
          final_status=1
        fi
      fi
    fi
  elif ((original_status == 0)); then
    printf 'E_CIDFILE: Docker succeeded without a valid owned container ID\n' >&2
    final_status=1
  fi

  rm -rf "$cid_dir" || true
  exit "$final_status"
}

trap finalize EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

container_script=''
read -r -d '' container_script <<'CONTAINER_SCRIPT' || true
set -eo pipefail
source /etc/profile.d/nexus_env.bash
set -u
expected_machine="$1"
runtime_dir="$(mktemp -d)"
listener_log="$runtime_dir/listener.log"
talker_log="$runtime_dir/talker.log"
listener_pid=''
talker_pid=''

cleanup_processes() {
  local original_status="$?"
  local deadline pid
  trap - EXIT INT TERM

  for pid in "$talker_pid" "$listener_pid"; do
    if [[ -n "$pid" ]]; then
      kill -TERM "$pid" 2>/dev/null || true
    fi
  done
  deadline=$((SECONDS + 5))
  while ((SECONDS < deadline)); do
    if ! { [[ -n "$talker_pid" ]] && kill -0 "$talker_pid" 2>/dev/null; } &&
       ! { [[ -n "$listener_pid" ]] && kill -0 "$listener_pid" 2>/dev/null; }; then
      break
    fi
    sleep 0.1
  done
  for pid in "$talker_pid" "$listener_pid"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
    if [[ -n "$pid" ]]; then
      wait "$pid" 2>/dev/null || true
    fi
  done
  rm -rf "$runtime_dir" || true
  exit "$original_status"
}

trap cleanup_processes EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

test "$(id -un)" = developer
test "$(id -u)" != 0
test "$(uname -m)" = "$expected_machine"
python -c 'import sys; assert sys.version_info[:2] == (3, 12)'
test "$(uv --version)" = 'uv 0.8.3'
ros2 pkg prefix demo_nodes_cpp
test "$ROS_DISTRO" = jazzy

ros2 run demo_nodes_cpp listener >"$listener_log" 2>&1 &
listener_pid=$!
ros2 run demo_nodes_cpp talker >"$talker_log" 2>&1 &
talker_pid=$!

deadline=$((SECONDS + 30))
while ((SECONDS < deadline)); do
  if grep -Fq 'I heard:' "$listener_log"; then
    exit 0
  fi
  if ! kill -0 "$listener_pid" 2>/dev/null || ! kill -0 "$talker_pid" 2>/dev/null; then
    break
  fi
  sleep 0.25
done
printf 'listener output:\n' >&2
cat "$listener_log" >&2 || true
printf 'talker output:\n' >&2
cat "$talker_log" >&2 || true
exit 1
CONTAINER_SCRIPT

set +e
timeout --kill-after=10s 180s docker run \
  --pull=never \
  --rm \
  --init \
  --platform "$platform" \
  --name "$container_name" \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  --cidfile "$cidfile" \
  "$tag" \
  bash -c "$container_script" -- "$expected_machine"
run_status=$?
set -e
exit "$run_status"
