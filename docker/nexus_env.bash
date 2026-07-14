#!/usr/bin/env bash
test ! -f /opt/ros/jazzy/setup.bash || source /opt/ros/jazzy/setup.bash
test ! -f /opt/venv/bin/activate || source /opt/venv/bin/activate
test ! -f /workspace/install/setup.bash || source /workspace/install/setup.bash

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-42}"
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_fastrtps_cpp}"
if [[ -f /workspace/config/fastdds.xml ]]; then
  export FASTDDS_DEFAULT_PROFILES_FILE=/workspace/config/fastdds.xml
  export FASTRTPS_DEFAULT_PROFILES_FILE=/workspace/config/fastdds.xml
fi
