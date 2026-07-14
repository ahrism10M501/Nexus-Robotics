# Day 4 개념

Day 4는 command가 아니라 observation의 날입니다. robot을 움직이는 것보다 먼저 simulator가
시간과 camera data를 ROS2로 내보내고, ROS2 tool이 그 data를 같은 시간 기준으로 읽을 수 있어야
합니다.

## /clock

`/clock`은 Isaac Sim이 publish하는 simulated time입니다. wall-clock time과 다르게 simulation이
Play일 때 진행되고 pause하면 멈춥니다.

이 차이는 dataset과 visualization에서 중요합니다. camera frame, joint state, 나중의 policy
observation이 서로 다른 시간 기준을 쓰면 "같은 순간"의 data를 맞추기 어렵습니다. Day 4에서
`/clock`을 먼저 확인하는 이유는 모든 observation의 기준 시간을 맞추기 위해서입니다.

## use_sim_time

ROS2 node는 기본적으로 wall-clock time을 씁니다. `use_sim_time` parameter를 `true`로 설정하면
node가 `/clock`을 시간 기준으로 사용합니다.

RViz는 특히 이 설정이 중요합니다. Isaac Sim camera data를 보고 있는데 RViz가 wall-clock 기준으로
message timestamp를 해석하면 display가 늦거나 비어 보일 수 있습니다. Day 4에서는 RViz의
`use_sim_time`을 직접 `true`로 설정해 봅니다.

## ROS2 Camera Helper

`ROS2 Camera Helper`는 Isaac Sim camera output을 ROS2 topic으로 publish하도록 돕는 graph node입니다.
RGB image, depth image, semantic data, camera info처럼 camera 관련 output을 ROS2 message로 내보내는
데 사용됩니다.

오늘은 복잡한 multi-camera pipeline이 아니라 하나의 RGB camera를 목표로 합니다. 중요한 것은 camera
prim이 있고, render product가 있으며, `ROS2 Camera Helper`가 image topic과 metadata topic을 publish
하도록 연결되어 있다는 점입니다.

## RGB image와 camera_info

`/rgb`는 image data stream입니다. pixel 값이 들어 있지만, 그 pixel이 어떤 camera model에서 나온
것인지는 혼자 설명하지 못합니다.

`camera_info`는 camera calibration과 geometry metadata입니다. focal length, projection 관련 정보,
image size 같은 data가 포함됩니다. ROS2 visualization과 perception pipeline은 image topic과
`camera_info`를 같이 볼 때 camera observation을 제대로 해석할 수 있습니다.

후속 dataset 실습을 생각하면 이 둘의 짝이 더 중요해집니다. RGB만 저장하면 나중에
observation이 어떤 camera geometry에서 나온 것인지 잃기 쉽습니다.

## QoS mismatch

ROS2에서 topic 이름이 보이는 것과 message가 도착하는 것은 다릅니다. QoS mismatch가 있으면
`ros2 topic list`에는 `/rgb`나 `/camera_info`가 보이는데 echo, RViz, subscriber는 data를 받지 못할
수 있습니다.

`ros2 topic info <topic> -v`는 publisher와 subscriber의 reliability, durability, history, depth를
보여 줍니다. Day 4에서는 data가 안 보일 때 "topic이 없다"와 "topic은 있는데 QoS나 time 때문에
받지 못한다"를 구분하는 연습을 합니다.

## 오늘의 사고 모델

Isaac Sim graph가 `/clock`을 publish하고, camera prim의 render output을 `ROS2 Camera Helper`가
`/rgb`와 `/camera_info`로 publish합니다. ROS2 tool과 RViz는 `use_sim_time=true`로 같은 simulated time을
사용하며, data가 안 보이면 QoS compatibility를 확인합니다.
