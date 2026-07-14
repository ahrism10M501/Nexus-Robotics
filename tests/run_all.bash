#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  printf 'usage: bash tests/run_all.bash [--checks|--core|--full]\n' >&2
}

if (($# > 1)); then
  usage
  exit 2
fi

mode="${1:---core}"
case "$mode" in
  --checks|--core|--full) ;;
  *)
    usage
    exit 2
    ;;
esac

run_checks() {
  bash tests/test_static_contract.bash
  bash tests/test_init.bash
  bash tests/test_profiles.bash
  bash tests/test_doctor.bash
  bash tests/test_isaac_host.bash
  bash tests/test_compose.bash
  bash tests/test_image_indexes.bash
  bash tests/test_ai_lock.bash
}

case "$mode" in
  --checks)
    run_checks
    printf 'core checks passed\n'
    ;;
  --core)
    run_checks
    bash tests/test_docker_runtime.bash
    printf 'all core tests passed\n'
    ;;
  --full)
    run_checks
    bash tests/test_docker_runtime.bash
    bash tests/test_ai_runtime.bash
    printf 'full core and AI tests passed\n'
    ;;
esac
