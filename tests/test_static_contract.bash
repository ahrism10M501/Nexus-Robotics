#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source tests/helpers/assert.bash

for path in .dockerignore .env.example docker/versions.env \
  docker/requirements/ai.in docker/requirements/ai.lock; do
  assert_file "$path"
done
assert_file scripts/generate_ai_lock.bash
assert_file tests/test_ai_lock.bash
test -x scripts/generate_ai_lock.bash || fail 'lock generator is not executable'
assert_contains docker/versions.env \
  'ROS_BASE_IMAGE=ros:jazzy-ros-base-noble@sha256:31daab66eef9139933379fb67159449944f4e2dcf2e22c2d12cc715f29873e0f'
assert_contains docker/versions.env \
  'UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:ef11ed817e6a5385c02cd49fdcc99c23d02426088252a8eace6b6e6a2a511f36'
assert_not_contains docker/versions.env 'DOOSAN'
assert_not_contains docker/versions.env 'OPENARM'
assert_not_contains docker/versions.env 'ISAAC_ROS'
assert_contains .env.example 'ISAAC_SIM_ROOT='
assert_contains .env.example 'ISAAC_SIM_COMPAT_VERSION=6.0.1'
assert_not_contains .env.example 'ISAAC_SIM_ROOT=/home/'
assert_contains .dockerignore '.env'
assert_contains .dockerignore '.worktrees'
assert_contains .dockerignore 'data'
assert_contains .dockerignore 'checkpoints'
assert_contains .gitignore '.env'
assert_contains .gitignore '.xauth-*'
printf 'static core contract passed\n'
