# Day 4 실습

## 오늘 만들 것

Isaac Sim scene에서 simulation clock과 하나의 RGB camera observation을 ROS2로 publish합니다.
container에서 `/clock`, `/rgb`, `/camera_info`를 inspect하고, RViz가 `/clock`을 쓰도록
`use_sim_time`을 설정합니다.

## 공식 튜토리얼 흐름

오늘은 아래 공식 ROS2 Bridge tutorial을 연결합니다.

- ROS2 Clock:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_clock.html
- ROS2 Cameras:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_camera.html
- ROS2 QoS:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_qos.html

`ROS2 Clock`으로 simulated time을 만들고, `ROS2 Cameras`로 image와 `camera_info`를 publish하며,
`ROS2 QoS`로 topic은 보이는데 data가 안 들어오는 상황을 debug합니다.

## 시작하기 전에

host에서 Isaac Sim을 실행합니다.

```bash
cd /home/ahrism/workspace/ros2-dev
./scripts/launch_isaac_sim.sh
```

다른 terminal에서는 container shell을 열고 ROS2 환경을 준비합니다.

```bash
cd /home/ahrism/workspace/ros2-dev
./run.sh shell
```

container 안에서:

```bash
source /etc/profile.d/nexus_env.bash
cd /workspace
```

Isaac Sim에서 `isaacsim.ros2.bridge` extension이 enable되어 있어야 합니다. topic을 inspect할 때는
simulation timeline이 Play 상태인지도 계속 확인합니다.

## 1단계: Isaac Sim에서 /clock publish하기

공식 `ROS2 Clock` tutorial 흐름을 따라 `/clock` publisher graph를 만듭니다. graph는 simulation
tick에 맞춰 simulated time을 publish해야 합니다.

timeline에서 Play를 누른 뒤 container에서 `/clock`을 확인합니다.

```bash
ros2 topic list
ros2 topic info /clock -v
ros2 topic echo /clock --once
```

`/clock` 값은 simulation이 Play 중일 때 진행됩니다. Pause하면 wall-clock은 계속 흐르지만 simulated
time은 멈추는 것이 정상입니다.

## 2단계: RGB camera 하나 추가하기

scene에 camera prim을 하나 둡니다. 처음에는 camera pose를 완벽하게 잡으려 하지 말고, ground나
robot이 보이는 정도로만 놓습니다. 중요한 것은 camera prim이 scene에 있고 render output을 만들 수
있다는 점입니다.

camera topic 이름은 tutorial과 graph 설정에 따라 달라질 수 있지만, 이 curriculum에서는 초보자
inspection을 위해 `/rgb`와 `/camera_info`를 기준 이름으로 사용합니다. graph에서 topic name을 이
이름으로 맞추면 이후 command가 단순해집니다.

## 3단계: ROS2 Camera Helper 연결하기

공식 `ROS2 Cameras` 흐름을 따라 `ROS2 Camera Helper`를 추가합니다. 이 node가 camera render output을
ROS2 message로 publish합니다.

RGB image output은 `/rgb`로, metadata는 `/camera_info`로 publish되도록 설정합니다. `camera_info`는
단순 보조 topic이 아닙니다. image를 어떤 camera geometry로 해석해야 하는지 알려 주는 짝 topic입니다.

timeline이 Play 상태인지 확인하고 graph가 ticking 중인지 봅니다.

## 4단계: container에서 camera topic 확인하기

container에서 image와 camera metadata topic을 확인합니다.

```bash
ros2 topic list
ros2 topic info /rgb -v
ros2 topic hz /rgb
ros2 topic info /camera_info -v
ros2 topic echo /camera_info --once
```

`/rgb`는 image data라서 `echo`로 보면 출력이 크고 읽기 어렵습니다. 먼저 `ros2 topic info /rgb -v`와
`ros2 topic hz /rgb`로 publisher와 publish rate를 확인하는 편이 좋습니다. `/camera_info`는
`--once`로 metadata를 한 번 확인하기 좋습니다.

## 5단계: use_sim_time으로 RViz 열기

container 안에서 RViz를 실행합니다.

```bash
ros2 run rviz2 rviz2
```

다른 container terminal에서 RViz parameter를 simulated time으로 바꿉니다.

```bash
ros2 param set /rviz use_sim_time true
ros2 param get /rviz use_sim_time
```

RViz UI에서도 `use_sim_time`이 true인지 확인합니다. camera display를 추가할 때 image topic은
`/rgb`, camera info는 `/camera_info`와 맞아야 합니다. RViz가 data를 받지 못하면 time과 QoS를
함께 의심합니다.

## 6단계: data가 오지 않을 때 QoS 비교하기

topic 이름이 보이는데 RViz나 subscriber가 data를 받지 못하면 QoS를 확인합니다.

```bash
ros2 topic info /rgb -v
ros2 topic info /camera_info -v
```

publisher와 subscriber의 reliability, durability, history, depth가 compatible한지 봅니다. image
topic은 QoS 차이에 민감하게 보일 수 있습니다. 공식 `ROS2 QoS` 튜토리얼의 설명과 graph node
settings를 비교해 어떤 쪽이 맞지 않는지 좁혀 갑니다.

## 확인하기

아래 내용을 확인합니다.

- `/clock`이 보이고 Play 중에 `ros2 topic echo /clock --once`가 값을 받습니다.
- `/rgb`가 보이고 `ros2 topic hz /rgb`로 publish rate를 볼 수 있습니다.
- `/camera_info`가 보이고 `ros2 topic echo /camera_info --once`로 metadata를 받을 수 있습니다.
- RViz의 `use_sim_time`이 `true`입니다.
- topic은 보이지만 data가 안 올 때 QoS mismatch를 의심해야 한다고 설명할 수 있습니다.

## 막혔을 때

`/clock`이 보이지 않으면 `isaacsim.ros2.bridge` extension, `/clock` publisher graph, timeline Play
상태를 확인합니다. graph가 simulation tick에 연결되어 있어야 합니다.

`/rgb` 또는 `/camera_info`가 보이지 않으면 camera prim, render product, `ROS2 Camera Helper` 설정을
확인합니다. graph의 topic name이 실제로 `/rgb`와 `/camera_info`인지도 봅니다.

RViz에서 image가 비어 있으면 먼저 `/rviz`의 `use_sim_time`을 확인합니다. 그 다음
`ros2 topic info /rgb -v`와 `ros2 topic info /camera_info -v`로 QoS compatibility를 비교합니다.

topic rate가 0처럼 보이면 simulation이 Play 상태인지, viewport/render가 멈춰 있지 않은지,
Action Graph가 ticking 중인지 확인합니다.

## 오늘 배운 것

Observation pipeline은 `/clock`에서 시작합니다. Isaac Sim의 simulated time을 ROS2 tool이 같이 쓰고,
`ROS2 Camera Helper`가 RGB image와 `camera_info`를 publish해야 camera observation을 해석할 수
있습니다. topic 이름만 보는 것으로는 충분하지 않고, `use_sim_time`과 QoS까지 확인해야 합니다.
