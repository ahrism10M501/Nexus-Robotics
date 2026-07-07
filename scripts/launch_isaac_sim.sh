#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ISAAC_SIM_ROOT="${ISAAC_SIM_ROOT:-/home/ahrism/isaacsim}"
ISAAC_SIM_LAUNCHER="${ISAAC_SIM_LAUNCHER:-$ISAAC_SIM_ROOT/isaac-sim.sh}"

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-42}"
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_fastrtps_cpp}"
export FASTDDS_DEFAULT_PROFILES_FILE="${FASTDDS_DEFAULT_PROFILES_FILE:-$WORKSPACE_DIR/config/fastdds.xml}"
export FASTRTPS_DEFAULT_PROFILES_FILE="${FASTRTPS_DEFAULT_PROFILES_FILE:-$WORKSPACE_DIR/config/fastdds.xml}"

usage() {
  cat <<USAGE
Usage: scripts/launch_isaac_sim.sh [isaac-sim args...]

Environment overrides:
  ISAAC_SIM_ROOT                 Default: /home/ahrism/isaacsim
  ISAAC_SIM_LAUNCHER             Default: \$ISAAC_SIM_ROOT/isaac-sim.sh
  ROS_DOMAIN_ID                  Default: 42
  RMW_IMPLEMENTATION             Default: rmw_fastrtps_cpp
  FASTDDS_DEFAULT_PROFILES_FILE  Default: $WORKSPACE_DIR/config/fastdds.xml
  FASTRTPS_DEFAULT_PROFILES_FILE Default: $WORKSPACE_DIR/config/fastdds.xml

Examples:
  scripts/launch_isaac_sim.sh
  scripts/launch_isaac_sim.sh --reset-user
  ROS_DOMAIN_ID=7 scripts/launch_isaac_sim.sh
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ ! -x "$ISAAC_SIM_LAUNCHER" ]; then
  echo "Isaac Sim launcher is not executable: $ISAAC_SIM_LAUNCHER" >&2
  echo "Set ISAAC_SIM_ROOT or ISAAC_SIM_LAUNCHER if Isaac Sim is installed elsewhere." >&2
  exit 1
fi

if [ ! -f "$FASTDDS_DEFAULT_PROFILES_FILE" ]; then
  echo "FastDDS profile not found: $FASTDDS_DEFAULT_PROFILES_FILE" >&2
  exit 1
fi

echo "Starting Isaac Sim"
echo "  ISAAC_SIM_LAUNCHER=$ISAAC_SIM_LAUNCHER"
echo "  ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
echo "  RMW_IMPLEMENTATION=$RMW_IMPLEMENTATION"
echo "  FASTDDS_DEFAULT_PROFILES_FILE=$FASTDDS_DEFAULT_PROFILES_FILE"
echo "  FASTRTPS_DEFAULT_PROFILES_FILE=$FASTRTPS_DEFAULT_PROFILES_FILE"

cd "$ISAAC_SIM_ROOT"
exec "$ISAAC_SIM_LAUNCHER" "$@"
