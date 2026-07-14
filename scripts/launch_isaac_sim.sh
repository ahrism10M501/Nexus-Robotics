#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
export ROOT NEXUS_ENV_FILE="$ROOT/.env"
source "$ROOT/scripts/lib/config.bash"

usage() {
  cat <<USAGE
Usage: scripts/launch_isaac_sim.sh [isaac-sim args...]

Uses the validated repository .env and an explicit ISAAC_SIM_ROOT when set.
Otherwise ISAAC_SIM_ROOT falls back to the parsed .env value, then
\$HOME/isaacsim. The launcher never installs or downloads Isaac Sim.
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

ambient_root="${ISAAC_SIM_ROOT-}"
if ! nexus_validate_env >/dev/null 2>&1; then
  printf 'FAIL E_PREREQUISITE\nrepository environment is missing or invalid\ncp .env.example .env\n' >&2
  exit 1
fi
parsed_root="${ISAAC_SIM_ROOT-}"

[[ "$RMW_IMPLEMENTATION" == rmw_fastrtps_cpp &&
   "${ISAAC_SIM_COMPAT_VERSION:-}" == 6.0.1 ]] || {
  printf 'FAIL E_PREREQUISITE\nrepository environment pins are incompatible\ncp .env.example .env\n' >&2
  exit 1
}

if [[ -n "$ambient_root" ]]; then
  ISAAC_SIM_ROOT="$ambient_root"
elif [[ -n "$parsed_root" ]]; then
  ISAAC_SIM_ROOT="$parsed_root"
else
  [[ -n "${HOME:-}" ]] || {
    printf 'FAIL E_PREREQUISITE\nHOME is required for the Isaac Sim fallback root\nexport HOME=/home/your-user\n' >&2
    exit 1
  }
  ISAAC_SIM_ROOT="${ISAAC_SIM_ROOT:-$HOME/isaacsim}"
fi

launcher="$ISAAC_SIM_ROOT/isaac-sim.sh"
[[ -f "$launcher" && -x "$launcher" ]] || {
  printf 'FAIL E_PREREQUISITE\nIsaac Sim launcher is missing or not executable\nexport ISAAC_SIM_ROOT=/path/to/isaacsim\n' >&2
  exit 1
}

version=''
[[ -f "$ISAAC_SIM_ROOT/VERSION" && -r "$ISAAC_SIM_ROOT/VERSION" ]] &&
  { IFS= read -r version < "$ISAAC_SIM_ROOT/VERSION" || [[ -n "$version" ]]; } || {
    printf 'FAIL E_PREREQUISITE\nIsaac Sim version is missing, unreadable, or incompatible\ninstall the compatible Isaac Sim release\n' >&2
    exit 1
  }
version="${version%$'\r'}"
[[ "$version" == 6.0.1 || "$version" == 6.0.1-* || "$version" == 6.0.1+* ]] || {
  printf 'FAIL E_PREREQUISITE\nIsaac Sim version is missing, unreadable, or incompatible\ninstall the compatible Isaac Sim release\n' >&2
  exit 1
}

fastdds="$ROOT/config/fastdds.xml"
[[ -f "$fastdds" && -r "$fastdds" ]] || {
  printf 'FAIL E_PREREQUISITE\nFastDDS profile is missing or unreadable\ngit restore --source=HEAD -- config/fastdds.xml\n' >&2
  exit 1
}

export ISAAC_SIM_ROOT ROS_DOMAIN_ID RMW_IMPLEMENTATION
export FASTDDS_DEFAULT_PROFILES_FILE="$fastdds"
export FASTRTPS_DEFAULT_PROFILES_FILE="$fastdds"
exec "$ISAAC_SIM_ROOT/isaac-sim.sh" "$@"
