# Day 5 실습

## 오늘 만들 것

Isaac Sim의 Franka manipulator tutorial을 학습용 proxy로 사용해 manipulator
control path를 읽습니다. 최종 robot은 Franka가 아니라 A0912입니다. 오늘 만드는
것은 완성된 robot application이 아니라, `/joint_states`를 관찰하고,
`/joint_command`가 어떤 command intent인지 확인하며, MoveIt2 planning과 execution을
분리해서 설명할 수 있는 기본 감각입니다.

## 공식 튜토리얼 흐름

오늘의 중심 공식 튜토리얼은 `ROS2 Joint Control`과 `MoveIt 2`입니다.

- ROS2 Joint Control:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_manipulation.html
- MoveIt 2:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_moveit.html

`ROS2 Joint Control`에서는 `/joint_states`, `/joint_command`,
`Articulation Controller`를 봅니다. `MoveIt 2`에서는 planning이 먼저 일어나고,
execution을 켰을 때 robot motion으로 이어진다는 점을 봅니다.

## 시작하기 전에

host에서 Isaac Sim을 실행합니다.

```bash
cd /home/ahrism/workspace/ros2-dev
./scripts/launch_isaac_sim.sh
```

다른 terminal에서 full container를 시작하고 shell로 들어갑니다. 이 이미지는
`isaac_moveit` package가 필요한 날에만 사용합니다. 처음이거나 Dockerfile이 바뀐 뒤에만
build를 먼저 실행합니다.

```bash
cd /home/ahrism/workspace/ros2-dev
# 처음이거나 Dockerfile이 바뀐 뒤에만 실행
./run.sh full-build
./run.sh full-dev
```

Full container 안에서 ROS2 환경과 Isaac MoveIt package를 확인합니다.

```bash
source /etc/profile.d/nexus_env.bash
cd /workspace
env | grep -E 'ROS_DOMAIN_ID|RMW_IMPLEMENTATION|FASTDDS|FASTRTPS'
ros2 pkg prefix isaac_moveit
```

host Isaac Sim과 container가 같은 `ROS_DOMAIN_ID=42`를 사용해야 ROS2 topic이
서로 보입니다.

## 1단계: Franka joint control 예제 열기

Isaac Sim에서 `ROS2 Joint Control` tutorial의 Franka scene 또는 tutorial graph를
엽니다. 오늘 Franka를 쓰는 이유는 A0912 대신 배울 수 있는 manipulator proxy이기
때문입니다. robot model은 다르지만 joint state, command, controller라는 언어는
그대로 이어집니다.

`isaacsim.ros2.bridge` extension이 enable되어 있는지 확인하고, timeline에서 Play를
누릅니다. Action Graph가 ticking 중이어야 ROS2 publish와 subscribe가 실제로
동작합니다.

## 2단계: `/joint_states` 확인하기

container 안에서 topic을 확인합니다.

```bash
ros2 topic list
ros2 topic info /joint_states -v
ros2 topic echo /joint_states --once
ros2 topic hz /joint_states
```

`/joint_states`는 현재 joint 상태 observation입니다. `name` 배열의 순서와
`position` 배열의 값이 함께 의미를 가집니다. 숫자를 모두 이해하지 못해도 괜찮습니다.
오늘은 이 topic이 "robot이 지금 어디에 있는가"를 알려 준다는 점을 잡으면 됩니다.

message 구조가 궁금하면 interface를 봅니다.

```bash
ros2 interface show sensor_msgs/msg/JointState
```

## 3단계: `/joint_command`가 Articulation Controller로 가는 흐름 따라가기

같은 joint control example에서 command topic을 확인합니다.

```bash
ros2 topic info /joint_command -v
ros2 topic type /joint_command
ros2 interface show $(ros2 topic type /joint_command)
```

`/joint_command`는 이 Isaac example에서 원하는 joint target을 표현하는 command
intent입니다. 이것은 MoveIt2 plan이 아니고, 나중의 learned-policy interface도
아닙니다. Action Graph 안에서는 이 command가 `Articulation Controller`로 이어져
simulator articulation joint target이 됩니다.

Isaac Sim UI에서 Action Graph를 왼쪽에서 오른쪽으로 읽어 보세요. ROS2 node가
topic을 받고, 그 값이 controller node로 들어가며, 마지막에 articulation target으로
전달되는 흐름을 확인합니다.

## 4단계: MoveIt 2 튜토리얼 열기

이제 `MoveIt 2` tutorial을 엽니다. 여기서도 Franka는 learning proxy입니다. 중요한
것은 robot 이름이 아니라 RViz에서 target pose를 고르고, MoveIt2가 collision과
joint limit을 고려해 trajectory를 만든 뒤, execution을 통해 simulator motion으로
보내는 흐름입니다.

launch command를 실행하기 전에 `isaac_moveit` package가 현재 shell에서 보이는지
다시 확인합니다.

```bash
ros2 pkg prefix isaac_moveit
```

패키지 prefix가 출력되면 MoveIt launch를 실행합니다.

```bash
ros2 launch isaac_moveit isaac_moveit.launch.py
```

RViz의 MotionPlanning panel에서 작은 target으로 plan을 만듭니다. 처음에는 큰 자세
변화를 고르지 않습니다. plan이 성공하면 아직 robot이 실제로 움직인 것이 아니라
"움직일 수 있는 경로를 찾았다"는 뜻입니다.

## 5단계: 작은 planned motion 하나 실행하기

MoveIt2 tutorial에서 execution을 활성화한 뒤 작은 motion 하나를 실행합니다. 이때
눈으로는 robot motion을 보고, terminal에서는 `/joint_states`가 바뀌는지 확인합니다.

```bash
ros2 topic echo /joint_states --once
ros2 topic hz /joint_states
```

움직이기 전과 후의 `position` 값이 달라지면 planning 결과가 execution path를 통해
simulator state로 이어진 것입니다.

## 확인하기

아래 내용을 확인합니다.

- `ros2 topic echo /joint_states --once`가 한 번 이상 message를 출력합니다.
- `ros2 pkg prefix isaac_moveit`가 package prefix를 출력합니다.
- `/joint_states`가 observation이고 `/joint_command`가 Isaac example의 command
  intent라는 차이를 설명할 수 있습니다.
- MoveIt2 planning은 trajectory를 계산하는 단계이고 execution은 controller나
  simulator로 보내 실제 motion을 만드는 단계라고 설명할 수 있습니다.
- Franka가 최종 robot이 아니라 A0912를 준비하기 위한 learning proxy라는 점을
  이해했습니다.
- `Articulation Controller`가 simulator articulation joint target으로 이어지는
  낮은 수준의 문이라는 점을 설명할 수 있습니다.

## 막혔을 때

`/joint_states`가 보이지 않으면 Isaac Sim의 `isaacsim.ros2.bridge`가 enable되어
있는지, timeline이 Play 상태인지, Franka tutorial graph가 열려 있는지 확인합니다.
host Isaac Sim과 container의 `ROS_DOMAIN_ID`도 같아야 합니다.

`/joint_command`가 보이지 않으면 MoveIt2 tutorial만 보고 있는 것은 아닌지 확인합니다.
`/joint_command`는 `ROS2 Joint Control` tutorial에서 확인하는 command topic입니다.

topic은 보이지만 data가 오지 않으면 `ros2 topic info /joint_states -v`로 QoS와
publisher 수를 봅니다. publisher가 0이면 simulator graph가 publish하지 않는 상태입니다.

MoveIt2에서 plan은 성공하지만 robot이 움직이지 않으면 execution이 켜져 있는지,
controller나 simulator side가 아직 실행 중인지 확인합니다. 이것이 바로 planning과
execution을 분리해서 생각해야 하는 이유입니다.

`isaac_moveit` package를 찾지 못하면 일반 `ros2_dev` 또는 `doosan_dev` shell에 들어온 것입니다.
host에서 `./run.sh full-dev`로 full container에 들어가세요. 이미 full container가
떠 있고 추가 shell만 필요하면 `./run.sh full-shell`을 사용합니다.

## 오늘 배운 것

Manipulator control은 한 덩어리가 아닙니다. `/joint_states`는 현재 상태를
관찰하고, `/joint_command`는 Isaac example에서 joint target intent를 보내며,
MoveIt2는 motion을 계획하고, execution path와 `Articulation Controller`는 그 계획이나
command가 실제 simulated motion으로 이어지게 합니다. 이 구분이 Day 6의 A0912 bringup과
Day 9 이후 ACT/Diffusion cube-pick policy를 안전하게 해석하는 바탕입니다.
