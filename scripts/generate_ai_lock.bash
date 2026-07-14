#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSIONS_FILE="$ROOT/docker/versions.env"
REQUIREMENTS_DIR="$ROOT/docker/requirements"
EXPECTED_ROS_BASE_IMAGE='ros:jazzy-ros-base-noble@sha256:31daab66eef9139933379fb67159449944f4e2dcf2e22c2d12cc715f29873e0f'
EXPECTED_UV_IMAGE='ghcr.io/astral-sh/uv:0.8.3@sha256:ef11ed817e6a5385c02cd49fdcc99c23d02426088252a8eace6b6e6a2a511f36'

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

case "${1:-}" in
  '') mode='generate' ;;
  --validate-only) mode='validate' ;;
  *) fail "usage: $0 [--validate-only]" ;;
esac
test "$#" -le 1 || fail "usage: $0 [--validate-only]"

tmp="$(mktemp -d)"
uv_container=''
cleanup() {
  test -z "$uv_container" || docker rm -f "$uv_container" >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -m 0700 "$tmp/bin" "$tmp/out"

awk '
  BEGIN {
    required["ROS_BASE_IMAGE"] = 1
    required["UV_IMAGE"] = 1
  }
  {
    separator = index($0, "=")
    if (separator == 0) {
      printf "invalid versions.env record at line %d\n", FNR > "/dev/stderr"
      invalid = 1
      next
    }
    key = substr($0, 1, separator - 1)
    value = substr($0, separator + 1)
    if (!(key in required)) {
      printf "unknown versions.env key at line %d: %s\n", FNR, key > "/dev/stderr"
      invalid = 1
      next
    }
    if (key in seen) {
      printf "duplicate versions.env key at line %d: %s\n", FNR, key > "/dev/stderr"
      invalid = 1
      next
    }
    seen[key] = 1
    if (value == "") {
      printf "empty versions.env value at line %d: %s\n", FNR, key > "/dev/stderr"
      invalid = 1
      next
    }
    values[key] = value
  }
  END {
    if (!("ROS_BASE_IMAGE" in seen)) {
      print "missing versions.env key: ROS_BASE_IMAGE" > "/dev/stderr"
      invalid = 1
    }
    if (!("UV_IMAGE" in seen)) {
      print "missing versions.env key: UV_IMAGE" > "/dev/stderr"
      invalid = 1
    }
    if (invalid) {
      exit 1
    }
    print values["ROS_BASE_IMAGE"]
    print values["UV_IMAGE"]
  }
' "$VERSIONS_FILE" > "$tmp/versions"

mapfile -t version_values < "$tmp/versions"
test "${#version_values[@]}" -eq 2 || fail 'versions.env did not produce exactly two values'
ROS_BASE_IMAGE="${version_values[0]}"
UV_IMAGE="${version_values[1]}"
test "$ROS_BASE_IMAGE" = "$EXPECTED_ROS_BASE_IMAGE" || fail 'ROS_BASE_IMAGE does not match the required index pin'
test "$UV_IMAGE" = "$EXPECTED_UV_IMAGE" || fail 'UV_IMAGE does not match the required index pin'

test -f "$REQUIREMENTS_DIR/ai.in" || fail 'missing docker/requirements/ai.in'
if [ "$mode" = 'validate' ]; then
  test -f "$REQUIREMENTS_DIR/ai.lock" || fail 'missing docker/requirements/ai.lock'
fi

uv_container="$(docker create "$UV_IMAGE")"
docker cp "$uv_container:/uv" "$tmp/bin/uv"
docker rm "$uv_container" >/dev/null
uv_container=''
chmod 0555 "$tmp/bin/uv"

if [ "$mode" = 'generate' ]; then
  docker run --rm --read-only --user "$(id -u):$(id -g)" \
    --tmpfs /tmp:rw,nosuid,nodev,mode=1777 \
    --env HOME=/tmp --env UV_CACHE_DIR=/tmp/uv-cache \
    --mount "type=bind,src=$tmp/bin/uv,dst=/usr/local/bin/uv,readonly" \
    --mount "type=bind,src=$REQUIREMENTS_DIR,dst=/requirements,readonly" \
    --mount "type=bind,src=$tmp/out,dst=/out" \
    "$ROS_BASE_IMAGE" /usr/local/bin/uv pip compile \
      --universal --python-version 3.12 --generate-hashes \
      --output-file /out/ai.lock /requirements/ai.in
  install -m 0644 "$tmp/out/ai.lock" "$REQUIREMENTS_DIR/ai.lock"
  exit 0
fi

docker run --rm --read-only --user "$(id -u):$(id -g)" \
  --tmpfs /tmp:rw,nosuid,nodev,mode=1777 \
  --env HOME=/tmp --env UV_CACHE_DIR=/tmp/uv-cache \
  --mount "type=bind,src=$tmp/bin/uv,dst=/usr/local/bin/uv,readonly" \
  --mount "type=bind,src=$REQUIREMENTS_DIR,dst=/requirements,readonly" \
  "$ROS_BASE_IMAGE" /bin/bash -c '
    set -euo pipefail
    /usr/local/bin/uv pip install --dry-run --target /tmp/target-amd64 \
      --require-hashes --only-binary=:all: --python-version 3.12 \
      --python-platform x86_64-manylinux_2_39 -r /requirements/ai.lock
    /usr/local/bin/uv pip install --dry-run --target /tmp/target-arm64 \
      --require-hashes --only-binary=:all: --python-version 3.12 \
      --python-platform aarch64-manylinux_2_39 -r /requirements/ai.lock
  '
