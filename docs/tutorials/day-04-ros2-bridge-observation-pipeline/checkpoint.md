# Day 4 체크포인트

## 통과 기준

Day 4를 통과하려면 Isaac Sim이 observation을 publish하고 ROS2 tool이 같은 simulation time 기준으로
받는 것을 확인해야 합니다.

- `/clock` topic이 보이고 Play 중에 simulated time message를 받을 수 있습니다.
- `/rgb` topic의 publisher와 rate를 확인할 수 있습니다.
- `/camera_info` topic에서 camera metadata를 한 번 받을 수 있습니다.
- RViz의 `use_sim_time`을 `true`로 설정하고 확인할 수 있습니다.
- topic이 보여도 QoS mismatch 때문에 data가 안 도착할 수 있음을 설명할 수 있습니다.
- `ROS2 Camera Helper`가 camera output을 ROS2 image와 `camera_info` topic으로 publish하는 역할을
  한다고 설명할 수 있습니다.

## 문제 해결 가이드

`/clock`이 echo되지 않으면 clock graph와 timeline을 먼저 봅니다. simulation이 Pause 상태이면
simulated time은 진행되지 않습니다. `isaacsim.ros2.bridge`가 enable되어 있는지도 확인합니다.

camera topic이 없으면 camera prim만 만든 상태일 수 있습니다. render output과 `ROS2 Camera Helper`
node가 연결되어야 ROS2 topic이 publish됩니다. graph의 topic name이 `/rgb`와 `/camera_info`로 되어
있는지도 확인합니다.

RViz가 camera image를 표시하지 못하면 `/rviz` parameter를 확인합니다.

```bash
ros2 param get /rviz use_sim_time
```

`false`라면 아래처럼 바꿉니다.

```bash
ros2 param set /rviz use_sim_time true
```

topic은 있는데 message가 안 들어오면 QoS를 봅니다.

```bash
ros2 topic info /rgb -v
ros2 topic info /camera_info -v
```

publisher와 subscriber의 reliability, durability, history, depth가 compatible하지 않으면 RViz나
custom subscriber가 data를 받지 못할 수 있습니다.

## Day 5로 넘어가기 전에

Day 4까지 끝나면 Isaac Sim에서 world를 만들고, ROS2 command로 mobile robot을 움직이고, camera와
time observation을 ROS2로 내보내는 기본 흐름을 경험했습니다. Day 5에서는 manipulator command와
joint state observation 쪽으로 시야를 옮깁니다.
