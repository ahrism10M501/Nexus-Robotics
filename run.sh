#!/usr/bin/env bash
set -euo pipefail

COMPOSE_SERVICE="${COMPOSE_SERVICE:-ros2_dev}"

usage() {
  cat <<'USAGE'
Usage: ./run.sh <command>

Commands:
  build            Build the Docker image
  up               Start the dev container and allow local root X11 GUI access
  shell            Open an interactive shell in the dev container
  dev              Start the container, then open a shell
  workspace-build  Run colcon build --symlink-install inside the container
  status           Show compose container status
  down             Stop the dev container and revoke local root X11 GUI access
USAGE
}

allow_x11_root() {
  if [ -n "${DISPLAY:-}" ] && command -v xhost >/dev/null 2>&1; then
    xhost +local:root >/dev/null
  fi
}

revoke_x11_root() {
  if [ -n "${DISPLAY:-}" ] && command -v xhost >/dev/null 2>&1; then
    xhost -local:root >/dev/null || true
  fi
}

compose_exec() {
  docker compose exec "$COMPOSE_SERVICE" "$@"
}

command="${1:-}"

case "$command" in
  build)
    docker compose build
    ;;
  up)
    allow_x11_root
    docker compose up -d
    ;;
  shell)
    compose_exec bash
    ;;
  dev)
    allow_x11_root
    docker compose up -d
    compose_exec bash
    ;;
  workspace-build)
    compose_exec bash -lc 'source /etc/profile.d/nexus_env.bash && cd /workspace && colcon build --symlink-install'
    ;;
  status)
    docker compose ps
    ;;
  down)
    docker compose down
    revoke_x11_root
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $command" >&2
    usage >&2
    exit 1
    ;;
esac
