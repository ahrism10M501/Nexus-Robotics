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
  if ! grep -Fq -- "$pattern" "$path"; then
    echo "missing pattern in $path: $pattern" >&2
    exit 1
  fi
}

reject_text() {
  local path="$1"
  local pattern="$2"
  if grep -Fq -- "$pattern" "$path"; then
    echo "unexpected pattern in $path: $pattern" >&2
    exit 1
  fi
}

reject_rg() {
  local path="$1"
  local pattern="$2"
  if rg -q "$pattern" "$path"; then
    echo "unexpected pattern under $path: $pattern" >&2
    rg -n "$pattern" "$path" >&2
    exit 1
  fi
}

reject_rg_multiline() {
  local path="$1"
  local pattern="$2"
  if rg -Uq "$pattern" "$path"; then
    echo "unexpected multi-line pattern under $path: $pattern" >&2
    rg -Un "$pattern" "$path" >&2
    exit 1
  fi
}

require_file Dockerfile
require_file Dockerfile.doosan
require_file Dockerfile.isaac-moveit
require_file compose.yml
require_file run.sh
require_file scripts/launch_isaac_sim.sh
require_file docker/nexus_env.bash
require_file docker/bootstrap_doosan_emulator.bash
require_file config/fastdds.xml
require_file .devcontainer/devcontainer.json
require_file .devcontainer/doosan/devcontainer.json
require_file .devcontainer/doosan/compose.yml

require_text Dockerfile "COPY docker/nexus_env.bash /etc/profile.d/nexus_env.bash"
require_text Dockerfile "python3-colcon-common-extensions"
require_text Dockerfile.doosan "https://github.com/DoosanRobotics/doosan-robot2.git"
require_text Dockerfile.doosan "DOOSAN_ROBOT2_REF=jazzy"
require_text Dockerfile.doosan 'git checkout "${DOOSAN_ROBOT2_REF}"'
require_text Dockerfile.doosan 'rm -rf "${DOOSAN_WS}/src/doosan-robot2/.git"'
require_text Dockerfile.doosan "COPY docker/bootstrap_doosan_emulator.bash"
reject_text Dockerfile.doosan "torch"
reject_text Dockerfile.doosan "diffusers"
require_text Dockerfile.isaac-moveit "https://github.com/isaac-sim/IsaacSim-ros_workspaces.git"
require_text Dockerfile.isaac-moveit "https://github.com/DoosanRobotics/doosan-robot2.git"
require_text Dockerfile.isaac-moveit 'git checkout "${DOOSAN_ROBOT2_REF}"'
require_text Dockerfile.isaac-moveit 'rm -rf "${DOOSAN_WS}/src/doosan-robot2/.git"'
require_text Dockerfile.isaac-moveit 'find "${ROBOT_WS_ROOT}/isaacsim_ros" -type d -name .git -prune -exec rm -rf {} +'
reject_text compose.yml "version:"
require_text compose.yml "doosan_dev:"
require_text compose.yml "full_dev:"
require_text compose.yml "dockerfile: Dockerfile.doosan"
require_text compose.yml "dockerfile: Dockerfile.isaac-moveit"
require_text compose.yml "gpus: all"
require_text compose.yml ".:/workspace"
require_text compose.yml "FASTDDS_DEFAULT_PROFILES_FILE"
require_text compose.yml "FASTRTPS_DEFAULT_PROFILES_FILE"
require_text docker/nexus_env.bash '/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash'
require_text docker/nexus_env.bash "/workspace/install/setup.bash"
require_text docker/nexus_env.bash "FASTDDS_DEFAULT_PROFILES_FILE"
require_text docker/bootstrap_doosan_emulator.bash "install_emulator.sh"
require_text docker/bootstrap_doosan_emulator.bash "docker image inspect"
require_text docker/bootstrap_doosan_emulator.bash "--force"
require_text run.sh "workspace-build"
require_text run.sh "doosan-build"
require_text run.sh "doosan-check"
require_text run.sh "full-build"
require_text run.sh "full-check"
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
require_text .devcontainer/doosan/devcontainer.json "\"service\": \"doosan_dev\""
require_text .devcontainer/doosan/devcontainer.json "\"dockerComposeFile\": ["
require_text .devcontainer/doosan/compose.yml "doosan_dev:"
require_text .devcontainer/doosan/compose.yml "profiles: !reset []"
require_text docs/tutorials/day-02-jetbot-turtlebot-ros2-driving/hands-on.md "./run.sh dev"
require_text docs/tutorials/day-04-ros2-bridge-observation-pipeline/hands-on.md "./run.sh dev"
require_text docs/tutorials/day-05-manipulator-concepts-before-a0912/hands-on.md "./run.sh full-dev"
require_text docs/tutorials/day-06-doosan-a0912-bringup/hands-on.md "./run.sh doosan-dev"
require_text docs/tutorials/day-07-a0912-scripted-motion/hands-on.md "./run.sh doosan-dev"
require_text docs/tutorials/day-08-cube-pick-scene-v0/hands-on.md "./run.sh dev"
require_text docs/tutorials/day-09-dataset-collection/hands-on.md "./run.sh dev"
require_text docs/tutorials/shared/environment-setup.md "./run.sh doosan-dev"
require_text docs/tutorials/shared/environment-setup.md "./run.sh full-dev"
reject_rg docs/tutorials 'moveit-(build|up|shell|dev)'
reject_rg docs/tutorials 'moveit_dev|ros2_moveit_workspace'
reject_rg_multiline docs/tutorials '\./run\.sh (dev|doosan-dev|doosan-shell|full-dev|full-shell)\nsource /etc/profile.d/nexus_env\.bash'
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
