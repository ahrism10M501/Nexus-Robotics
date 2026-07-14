#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

base="${1:-main}"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

require_local_branch() {
  git show-ref --verify --quiet "refs/heads/$1" || fail "missing local branch: $1"
}

assert_descends_from() {
  local parent="$1" child="$2"
  require_local_branch "$parent"
  require_local_branch "$child"
  git merge-base --is-ancestor "$parent" "$child" ||
    fail "$child does not descend from $parent"
  printf 'PASS: %s -> %s\n' "$parent" "$child"
}

require_local_branch "$base"
assert_descends_from "$base" isaac-moveit
assert_descends_from "$base" doosan-robotics
assert_descends_from doosan-robotics doosan-tutorial
assert_descends_from "$base" open-arm
assert_descends_from open-arm openarm-tutorial
