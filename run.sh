#!/usr/bin/env bash
set -euo pipefail

COMPOSE_SERVICE="${COMPOSE_SERVICE:-ros2_dev}"

usage() {
  cat <<'USAGE'
Usage: ./run.sh <command>

Commands:
  build            Build the default lightweight ROS2 Docker image
  up               Start the dev container and allow local root X11 GUI access
  shell            Open an interactive shell in the dev container
  dev              Start the container, then open a shell
  workspace-build  Run colcon build --symlink-install inside the container
  doosan-build     Build the Doosan/MoveIt Docker image
  doosan-up        Start the Doosan container profile
  doosan-shell     Open an interactive shell in the Doosan container
  doosan-dev       Start the Doosan container, then open a shell
  doosan-check     Check Doosan packages, MoveIt package, Docker socket, and ROS env
  full-build       Build the full Isaac ROS workspace + Doosan Docker image
  full-up          Start the full container profile
  full-shell       Open an interactive shell in the full container
  full-dev         Start the full container, then open a shell
  full-check       Check Full packages, Docker socket, and ROS env
  status           Show compose container status
  down             Stop the dev container and revoke local root X11 GUI access

Legacy aliases:
  moveit-build, moveit-up, moveit-shell, moveit-dev, moveit-check map to full-* commands
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
  case "$COMPOSE_SERVICE" in
    doosan_dev)
      docker compose --profile doosan exec "$COMPOSE_SERVICE" "$@"
      ;;
    full_dev|moveit_dev)
      docker compose --profile full exec full_dev "$@"
      ;;
    *)
      docker compose exec "$COMPOSE_SERVICE" "$@"
      ;;
  esac
}

doosan_exec() {
  docker compose --profile doosan exec doosan_dev "$@"
}

full_exec() {
  docker compose --profile full exec full_dev "$@"
}

doosan_check() {
  doosan_exec bash -lc '
    set -eo pipefail
    source /etc/profile.d/nexus_env.bash
    echo "ROS_DISTRO=${ROS_DISTRO:-}"
    echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-}"
    echo "RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-}"
    echo "FASTDDS_DEFAULT_PROFILES_FILE=${FASTDDS_DEFAULT_PROFILES_FILE:-}"
    ros2 pkg prefix dsr_bringup2
    ros2 pkg prefix moveit_ros_move_group
    docker ps >/dev/null
    test -x /opt/robot_ws/doosan_ws/src/doosan-robot2/install_emulator.sh
    echo "doosan environment looks consistent"
  '
}

full_check() {
  full_exec bash -lc '
    set -eo pipefail
    source /etc/profile.d/nexus_env.bash
    echo "ROS_DISTRO=${ROS_DISTRO:-}"
    echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-}"
    echo "RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-}"
    echo "FASTDDS_DEFAULT_PROFILES_FILE=${FASTDDS_DEFAULT_PROFILES_FILE:-}"
    ros2 pkg prefix dsr_bringup2
    ros2 pkg prefix isaac_moveit
    ros2 pkg prefix moveit_ros_move_group
    docker ps >/dev/null
    test -x /opt/robot_ws/doosan_ws/src/doosan-robot2/install_emulator.sh
    echo "full environment looks consistent"
  '
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
  doosan-build)
    docker compose --profile doosan build doosan_dev
    ;;
  doosan-up)
    allow_x11_root
    docker compose --profile doosan up -d doosan_dev
    ;;
  doosan-shell)
    doosan_exec bash
    ;;
  doosan-dev)
    allow_x11_root
    docker compose --profile doosan up -d doosan_dev
    doosan_exec bash
    ;;
  doosan-check)
    doosan_check
    ;;
  full-build|moveit-build)
    docker compose --profile full build full_dev
    ;;
  full-up|moveit-up)
    allow_x11_root
    docker compose --profile full up -d full_dev
    ;;
  full-shell|moveit-shell)
    full_exec bash
    ;;
  full-dev|moveit-dev)
    allow_x11_root
    docker compose --profile full up -d full_dev
    full_exec bash
    ;;
  full-check|moveit-check)
    full_check
    ;;
  status)
    docker compose --profile doosan --profile full ps
    ;;
  down)
    docker compose --profile doosan --profile full down
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
