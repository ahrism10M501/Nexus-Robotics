#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source tests/helpers/assert.bash

image_prefix="ros2-dev-core-runtime-test"

build_python_image() {
  local uid="$1"
  local gid="$2"
  local image="$3"
  docker build \
    --target ros-python-dev \
    --build-arg "DEVELOPER_UID=${uid}" \
    --build-arg "DEVELOPER_GID=${gid}" \
    --tag "$image" \
    .
}

assert_python_runtime() {
  local image="$1"
  docker run --rm "$image" bash -lc '
    set -euo pipefail
    test "$(id -un)" = developer
    test "$(id -u)" != 0
    test "$(stat -c %U /home/developer/.bashrc)" = developer
    test "$(stat -c %U /workspace)" = developer
    test "$(stat -c %U /opt/venv)" = developer
    python -c '\''import sys; assert sys.version_info[:2] == (3, 12)'\''
    test "$(uv --version)" = "uv 0.8.3"
    test "$ROS_DISTRO" = jazzy
    ros2 pkg prefix demo_nodes_cpp
  '
}

assert_zero_id_build_fails() {
  local uid="$1"
  local gid="$2"
  if docker build \
    --target ros-base \
    --build-arg "DEVELOPER_UID=${uid}" \
    --build-arg "DEVELOPER_GID=${gid}" \
    .; then
    fail "Docker build accepted developer IDs ${uid}:${gid}"
  fi
}

for ids in '1000 1000' '12345 12345'; do
  read -r uid gid <<< "$ids"
  image="${image_prefix}:python-${uid}-${gid}"
  build_python_image "$uid" "$gid" "$image"
  assert_python_runtime "$image"
done

assert_zero_id_build_fails 0 1000
assert_zero_id_build_fails 1000 0

ai_image="${image_prefix}:ai"
docker build --target ros-ai-dev --tag "$ai_image" .
docker run --rm "$ai_image" bash -lc '
  set -euo pipefail
  test "$(id -un)" = developer
  uv pip check --python /opt/venv/bin/python
  /opt/venv/bin/python -c \
    "import diffusers, einops, huggingface_hub, timm, torch, torchvision"
'

printf 'Docker runtime contract passed\n'
