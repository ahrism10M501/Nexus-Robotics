#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source tests/helpers/assert.bash

keys=(ROS_BASE_IMAGE UV_IMAGE)
expected=(
  'ros:jazzy-ros-base-noble@sha256:31daab66eef9139933379fb67159449944f4e2dcf2e22c2d12cc715f29873e0f'
  'ghcr.io/astral-sh/uv:0.8.3@sha256:ef11ed817e6a5385c02cd49fdcc99c23d02426088252a8eace6b6e6a2a511f36'
)

for index in "${!keys[@]}"; do
  key="${keys[$index]}"
  count="$(awk -F= -v key="$key" '$1 == key { count++ } END { print count + 0 }' docker/versions.env)"
  test "$count" -eq 1 || fail "$key must occur exactly once"
  image="$(awk -F= -v key="$key" '$1 == key { print substr($0, index($0, "=") + 1) }' docker/versions.env)"
  test "$image" = "${expected[$index]}" || fail "$key has an unexpected image index"
  docker buildx imagetools inspect --raw "$image" | jq -e '
    [.manifests[].platform | "\(.os)/\(.architecture)"] as $platforms |
    ($platforms | index("linux/amd64")) != null and
    ($platforms | index("linux/arm64")) != null
  '
done

printf 'image index contract passed\n'
