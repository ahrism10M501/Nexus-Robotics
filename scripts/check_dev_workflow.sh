#!/usr/bin/env bash
set -euo pipefail

require_file() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "missing file: $path" >&2
    exit 1
  fi
}

require_text() {
  local path="$1"
  local pattern="$2"
  if ! grep -Fq "$pattern" "$path"; then
    echo "missing pattern in $path: $pattern" >&2
    exit 1
  fi
}

reject_text() {
  local path="$1"
  local pattern="$2"
  if grep -Fq "$pattern" "$path"; then
    echo "unexpected pattern in $path: $pattern" >&2
    exit 1
  fi
}

require_file Dockerfile
require_file compose.yml
require_file run.sh
require_file scripts/launch_isaac_sim.sh
require_file docker/nexus_env.bash
require_file config/fastdds.xml
require_file .devcontainer/devcontainer.json

require_text Dockerfile "COPY docker/nexus_env.bash /etc/profile.d/nexus_env.bash"
require_text Dockerfile "python3-colcon-common-extensions"
reject_text compose.yml "version:"
require_text compose.yml "gpus: all"
require_text compose.yml ".:/workspace"
require_text compose.yml "FASTDDS_DEFAULT_PROFILES_FILE"
require_text compose.yml "FASTRTPS_DEFAULT_PROFILES_FILE"
require_text docker/nexus_env.bash '/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash'
require_text docker/nexus_env.bash "/workspace/install/setup.bash"
require_text docker/nexus_env.bash "FASTDDS_DEFAULT_PROFILES_FILE"
require_text run.sh "workspace-build"
require_text run.sh "xhost +local:root"
require_text scripts/launch_isaac_sim.sh "ISAAC_SIM_ROOT"
require_text scripts/launch_isaac_sim.sh "ROS_DOMAIN_ID"
require_text scripts/launch_isaac_sim.sh "FASTDDS_DEFAULT_PROFILES_FILE"
require_text scripts/launch_isaac_sim.sh "FASTRTPS_DEFAULT_PROFILES_FILE"
require_text scripts/launch_isaac_sim.sh "exec"
require_text config/fastdds.xml "<profiles"
require_text config/fastdds.xml "UDPv4"
require_text config/fastdds.xml "useBuiltinTransports"
require_text .devcontainer/devcontainer.json "\"service\": \"ros2_dev\""
require_text .gitignore "build/"
require_text .gitignore "install/"
require_text .gitignore "log/"

if [ ! -x run.sh ]; then
  echo "run.sh must be executable" >&2
  exit 1
fi

if [ ! -x scripts/launch_isaac_sim.sh ]; then
  echo "scripts/launch_isaac_sim.sh must be executable" >&2
  exit 1
fi

echo "dev workflow config looks consistent"
