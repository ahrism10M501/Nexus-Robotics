#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/doctor.bash"

nexus_check_isaac_host_main() {
  local ambient_root parsed_root env_valid=1 ids_output actual_network
  local graph_output line container_id
  local -a running_ids=()

  (($# == 0)) || {
    nexus_usage_error 'usage: scripts/check_isaac_host.bash'
    return
  }
  cd "$ROOT"
  ambient_root="${ISAAC_SIM_ROOT-}"

  if ! nexus_validate_core_env; then
    env_valid=0
  fi
  parsed_root="${ISAAC_SIM_ROOT-}"

  [[ "$(uname -m 2>/dev/null)" == x86_64 ]] || {
    nexus_acceptance_skip 'Isaac host requires x86_64' 'use an x86_64 Isaac Sim host'
    return
  }

  command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1 || {
    nexus_acceptance_skip 'NVIDIA read-only prerequisite probe failed' 'nvidia-smi -L'
    return
  }

  if ! nexus_resolve_isaac_root "$ambient_root" "$parsed_root"; then
    nexus_acceptance_skip 'HOME is required for the Isaac Sim fallback root' 'export HOME=/home/your-user'
    return
  fi
  [[ -d "$ISAAC_SIM_ROOT" ]] || {
    nexus_acceptance_skip 'Isaac Sim root is absent' 'export ISAAC_SIM_ROOT=/path/to/isaacsim'
    return
  }
  [[ -e "$ISAAC_SIM_ROOT/isaac-sim.sh" || -L "$ISAAC_SIM_ROOT/isaac-sim.sh" ]] || {
    nexus_acceptance_skip 'Isaac Sim launcher is absent' 'export ISAAC_SIM_ROOT=/path/to/isaacsim'
    return
  }
  [[ -f "$ISAAC_SIM_ROOT/isaac-sim.sh" && -x "$ISAAC_SIM_ROOT/isaac-sim.sh" ]] || {
    nexus_acceptance_fail 'Isaac Sim launcher is not executable' 'chmod +x "$ISAAC_SIM_ROOT/isaac-sim.sh"'
    return
  }

  nexus_read_compatible_version "$ISAAC_SIM_ROOT/VERSION" "$NEXUS_ISAAC_COMPAT_VERSION" || {
    nexus_acceptance_fail 'Isaac Sim version is missing, unreadable, or incompatible' 'install the compatible Isaac Sim release'
    return
  }

  ((env_valid == 1)) || {
    nexus_acceptance_fail 'repository environment is missing or invalid' 'cp .env.example .env'
    return
  }

  command -v docker >/dev/null 2>&1 || {
    nexus_acceptance_fail 'Docker Engine is unavailable' 'install Docker Engine and start its daemon'
    return
  }

  if ! nexus_prepare_isaac_compose; then
    nexus_acceptance_fail 'Docker Compose configuration is unavailable' 'docker compose config'
    return
  fi
  nexus_validate_isaac_compose_contract || {
    nexus_acceptance_fail 'normalized Compose contract is invalid' 'docker compose config'
    return
  }

  if ! ids_output="$("${compose_argv[@]}" ps -q "$service" 2>/dev/null)"; then
    nexus_acceptance_fail 'running container state is unavailable' 'docker compose ps'
    return
  fi
  while IFS= read -r line; do
    [[ -z "$line" ]] || running_ids+=("$line")
  done <<< "$ids_output"
  ((${#running_ids[@]} == 1)) && [[ "${running_ids[0]}" =~ ^[0-9a-f]{12,64}$ ]] || {
    nexus_acceptance_fail 'exactly one running container is required' 'docker compose ps'
    return
  }
  container_id="${running_ids[0]}"

  if ! actual_network="$(docker inspect --format '{{.HostConfig.NetworkMode}}' "$container_id" 2>/dev/null)" ||
     [[ "$actual_network" != host ]]; then
    nexus_acceptance_fail 'container actual network is not host' 'docker inspect --format {{.HostConfig.NetworkMode}} CONTAINER'
    return
  fi

  command -v timeout >/dev/null 2>&1 || {
    nexus_acceptance_fail 'host timeout command is unavailable' 'install GNU coreutils timeout'
    return
  }
  if ! graph_output="$(timeout --kill-after=2s 10s "${compose_argv[@]}" exec -T "$service" \
      bash --noprofile --norc -c \
      'source /etc/profile.d/nexus_env.bash; exec ros2 topic list' 2>/dev/null)"; then
    nexus_acceptance_fail 'ROS graph observation failed or timed out' 'docker compose ps'
    return
  fi

  local clock_found=0
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ "$line" != /clock ]] || clock_found=1
  done <<< "$graph_output"
  ((clock_found == 1)) || {
    nexus_acceptance_fail '/clock topic is absent' 'verify the Isaac ROS bridge graph'
    return
  }

  if ! timeout --kill-after=2s 10s "${compose_argv[@]}" exec -T "$service" \
      bash --noprofile --norc -c \
      'source /etc/profile.d/nexus_env.bash; exec ros2 topic echo /clock --once' \
      >/dev/null 2>&1; then
    nexus_acceptance_fail '/clock observation failed or timed out' 'verify the Isaac ROS bridge clock publisher'
    return
  fi

  printf 'PASS\n/clock observed\nno action required\n'
}

nexus_check_isaac_host_main "$@"
