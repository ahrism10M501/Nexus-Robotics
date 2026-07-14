#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source tests/helpers/assert.bash

assert_file tests/fixtures/core-deleted-paths.txt
test "$(wc -l < tests/fixtures/core-deleted-paths.txt)" -eq 31 || \
  fail 'core deletion fixture must contain exactly 31 paths'
while IFS= read -r path; do
  test ! -e "$path" || fail "deleted core path still exists: $path"
  if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    fail "deleted core path remains in index: $path"
  fi
done < tests/fixtures/core-deleted-paths.txt

while IFS= read -r tracked_path; do
  case "$tracked_path" in
    Dockerfile.doosan|Dockerfile.isaac-moveit|docker/*doosan*|.devcontainer/doosan/*|\
      docs/tutorials/day-0[5-9]-*/*|docs/tutorials/day-10-*/*)
      fail "vendor-owned path remains in core: $tracked_path"
      ;;
  esac
done < <(git ls-files)

mapfile -t active_docs < <(
  git ls-files -- README.md docs |
    while IFS= read -r path; do
      case "$path" in
        README.md|docs/*.md)
          case "$path" in
            docs/superpowers/*) ;;
            *) printf '%s\n' "$path" ;;
          esac
          ;;
      esac
    done
)
live_vendor_pattern='/home/ahrism|a0912|doosan[-_](dev|build|up|shell|check)|full[-_](dev|build|up|shell|check)|bootstrap_doosan|doosanrobot|DSR_ROBOT2|isaac_moveit|IsaacSim-ros_workspaces|Dockerfile\.(doosan|isaac-moveit)|\.devcontainer/doosan'
if vendor_hits="$(grep -EinH -- "$live_vendor_pattern" "${active_docs[@]}" || true)" && \
  test -n "$vendor_hits"; then
  printf '%s\n' "$vendor_hits" >&2
  fail 'active core documentation contains vendor/runtime-specific content'
fi

mapfile -d '' -t retained_tutorial_docs < <(
  find docs/tutorials/day-0{1,2,3,4}-* docs/tutorials/shared \
    -type f -name '*.md' -print0
)
follow_on_pattern='Days? ([5-9]|10)([^0-9]|$)|day-(0[5-9]|10)([^0-9]|$)'
if follow_on_hits="$(grep -EinH -- "$follow_on_pattern" "${retained_tutorial_docs[@]}" || true)" && \
  test -n "$follow_on_hits"; then
  printf '%s\n' "$follow_on_hits" >&2
  fail 'retained core tutorial documentation references a removed follow-on lesson'
fi

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
assert_contains .devcontainer/devcontainer.json '"remoteUser": "developer"'
assert_not_contains .devcontainer/devcontainer.json '"remoteUser": "root"'
for target in 'AS ros-base' 'AS ros-dev' 'AS ros-python-dev' 'AS ros-ai-dev'; do
  assert_contains Dockerfile "$target"
done
assert_contains Dockerfile 'USER developer'
assert_contains Dockerfile 'COPY --from=uv-bin /uv /uvx /usr/local/bin/'
assert_contains Dockerfile 'ros-jazzy-desktop'
assert_contains Dockerfile 'uv pip sync --require-hashes'
assert_contains Dockerfile 'uv pip check'
assert_not_contains Dockerfile 'ARG DEVELOPER_NAME'
assert_not_contains Dockerfile 'curl -LsSf https://astral.sh/uv/install.sh'
for vendor in DOOSAN OPENARM ISAAC_ROS; do
  assert_not_contains Dockerfile "$vendor"
done
printf 'static core contract passed\n'
