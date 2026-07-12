#!/usr/bin/env bash

export ROS_DISTRO="${ROS_DISTRO:-jazzy}"
export VENV_DIR="${VENV_DIR:-/opt/venv}"
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-42}"
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_fastrtps_cpp}"

if [ -f "/workspace/config/fastdds.xml" ]; then
  export FASTDDS_DEFAULT_PROFILES_FILE="${FASTDDS_DEFAULT_PROFILES_FILE:-/workspace/config/fastdds.xml}"
  export FASTRTPS_DEFAULT_PROFILES_FILE="${FASTRTPS_DEFAULT_PROFILES_FILE:-/workspace/config/fastdds.xml}"
fi

if [ -f "/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash" ]; then
  source "/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash"
fi

if [ -f "/opt/robot_ws/isaacsim_ros/${ROS_DISTRO:-jazzy}_ws/install/setup.bash" ]; then
  source "/opt/robot_ws/isaacsim_ros/${ROS_DISTRO:-jazzy}_ws/install/setup.bash"
fi

if [ -f "/opt/robot_ws/doosan_ws/install/setup.bash" ]; then
  source "/opt/robot_ws/doosan_ws/install/setup.bash"
fi

if [ -f "${VENV_DIR}/bin/activate" ]; then
  source "${VENV_DIR}/bin/activate"
fi

if [ -f "/workspace/install/setup.bash" ]; then
  source "/workspace/install/setup.bash"
fi
