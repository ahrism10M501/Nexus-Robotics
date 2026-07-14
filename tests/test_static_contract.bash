#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source tests/helpers/assert.bash

for path in .dockerignore .env.example docker/versions.env \
  docker/requirements/ai.in docker/requirements/ai.lock; do
  assert_file "$path"
done
assert_contains docker/versions.env \
  'ROS_BASE_IMAGE=osrf/ros:jazzy-desktop@sha256:1d6f898b6ab77636c40f26298070ad3de5a9e06f0a71cf9ab066fd6b7838f151'
assert_contains docker/versions.env \
  'UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:88baae1f9fa298996f8313e44559163c535937406d217f1c8ac9d4b86a2020fd'
assert_not_contains docker/versions.env 'DOOSAN'
assert_not_contains docker/versions.env 'OPENARM'
assert_not_contains docker/versions.env 'ISAAC_ROS'
assert_contains .dockerignore '.env'
assert_contains .dockerignore '.worktrees'
assert_contains .dockerignore 'data'
assert_contains .dockerignore 'checkpoints'
assert_contains .gitignore '.env'
assert_contains .gitignore '.xauth-*'
printf 'static core contract passed\n'
