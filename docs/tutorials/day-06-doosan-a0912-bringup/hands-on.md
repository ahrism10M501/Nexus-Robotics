# Day 6 실습

## 오늘 만들 것

Doosan Jazzy stack으로 virtual A0912를 실행하고, RViz에서 robot model을 확인한 뒤,
controller 상태와 `/joint_states`를 검사합니다. 먼저 MoveIt bringup에서 작은 planning
and execution 흐름을 확인하고, 그다음 Gazebo bringup을 별도로 실행해 virtual A0912가
simulation path에서도 뜨는지 봅니다.

## 공식 튜토리얼 흐름

오늘의 중심 공식 문서는 `Doosan ROS2 Jazzy Manual`입니다.

- Doosan ROS2 Jazzy Manual:
  https://doosanrobotics.github.io/doosan-robotics-ros-manual/jazzy/
- Doosan GitHub:
  https://github.com/DoosanRobotics/doosan-robot2

manual의 설치, build, source 흐름을 따른 뒤 이 repo의 ROS2 환경과 함께 사용합니다.
처음에는 real robot이 아니라 `mode:=virtual`만 사용합니다.

## 시작하기 전에

container shell로 들어갑니다.

```bash
cd /home/ahrism/workspace/ros2-dev
./run.sh shell
```

container 안에서 기본 ROS2 환경을 source합니다.

```bash
source /etc/profile.d/nexus_env.bash
cd /workspace
```

Doosan manual에 따라 준비한 Doosan Jazzy workspace도 같은 shell에서 source합니다.
workspace 위치는 설치 방식마다 다를 수 있으므로, manual에서 사용한 setup file을
사용하세요. launch command를 실행하기 전에 package가 보이는지 확인합니다.

```bash
ros2 pkg prefix dsr_bringup2
```

이 command가 package prefix를 출력하면 현재 shell이 Doosan package를 찾고 있는
상태입니다.

## 1단계: virtual bringup argument 읽기

오늘 launch command에서 가장 중요한 argument는 네 가지입니다.

`mode:=virtual`은 real controller가 아니라 virtual mode로 시작한다는 뜻입니다.
초보자 실습과 cube-pick 준비는 여기서 출발합니다.

`model:=a0912`는 Doosan model 중 A0912를 선택합니다. 이 값이 틀리면 RViz, Gazebo,
MoveIt2 planning group, joint names가 모두 엇갈릴 수 있습니다.

`host:=127.0.0.1`과 `port:=12345`는 controller endpoint를 가리킵니다. virtual mode에서
local endpoint를 사용하더라도, 같은 port를 다른 process가 쓰고 있거나 이전 launch가
살아 있으면 연결이 꼬일 수 있습니다.

## 2단계: virtual MoveIt bringup 실행하기

먼저 MoveIt bringup을 실행합니다. 이 terminal은 계속 켜 둡니다.

```bash
ros2 launch dsr_bringup2 dsr_bringup2_moveit.launch.py \
  mode:=virtual \
  model:=a0912 \
  host:=127.0.0.1 \
  port:=12345
```

RViz가 열리면 A0912 model이 보이는지 확인합니다. 아직 motion을 실행하지 말고,
먼저 robot model, planning group, initial state가 정상적으로 보이는지 살펴봅니다.

## 3단계: controller와 `/joint_states` 확인하기

다른 container shell을 열고 같은 환경을 source한 뒤 controller와 joint state를
확인합니다.

```bash
source /etc/profile.d/nexus_env.bash
cd /workspace
ros2 control list_controllers
ros2 topic list
ros2 topic echo /joint_states --once
ros2 topic info /joint_states -v
```

`ros2 control list_controllers`에서 controller가 `active`인지 확인합니다. 이름은
Doosan stack version이나 launch 구성에 따라 달라질 수 있으므로, 초보자 단계에서는
"필요한 controller가 로드되어 있고 active인가"를 먼저 봅니다.

`/joint_states` message가 한 번 출력되면 A0912의 현재 joint state observation이 ROS2로
나오고 있는 것입니다. 이 topic은 Day 9 dataset과 policy observation으로 이어집니다.

## 4단계: RViz에서 작은 motion plan/execute하기

RViz MotionPlanning panel에서 작은 target을 잡고 plan을 만듭니다. 오늘은 큰 동작이나
빠른 motion을 테스트하는 날이 아닙니다. A0912가 virtual mode에서 planning 가능한
상태인지 확인하는 것이 목표입니다.

plan이 성공하면 execution을 실행합니다. robot이 움직이는 동안 `/joint_states`가 계속
publish되는지 확인합니다.

```bash
ros2 topic hz /joint_states
```

여기서 다시 Day 5의 구분을 떠올립니다. RViz에서 plan이 보이는 것은 planning 성공이고,
robot이 움직이고 `/joint_states`가 변하는 것은 execution path가 살아 있다는 뜻입니다.

## 5단계: Gazebo를 시도하기 전에 MoveIt 종료하기

MoveIt bringup 확인이 끝나면 launch terminal에서 `Ctrl+C`로 종료합니다. 처음 배우는
동안에는 MoveIt bringup과 Gazebo bringup을 동시에 켜지 않습니다. 같은 model,
controller, `host`, `port`를 동시에 잡으려 하면 실패 원인을 분리하기 어렵습니다.

## 6단계: virtual Gazebo bringup 실행하기

이제 Gazebo bringup을 별도로 실행합니다.

```bash
ros2 launch dsr_bringup2 dsr_bringup2_gazebo.launch.py \
  mode:=virtual \
  model:=a0912 \
  host:=127.0.0.1 \
  port:=12345 \
  x:=0 \
  y:=0
```

Gazebo에 A0912가 나타나는지 확인합니다. 별도 shell에서 다시 controller와 joint state를
봅니다.

```bash
ros2 control list_controllers
ros2 topic list
ros2 topic echo /joint_states --once
```

Gazebo bringup은 physics simulation path를 확인하는 데 사용합니다. 오늘은 MoveIt과
Gazebo를 동시에 연결해 복잡한 motion을 만드는 단계가 아닙니다.

## 확인하기

아래 내용을 확인합니다.

- `ros2 pkg prefix dsr_bringup2`가 package prefix를 출력합니다.
- MoveIt bringup command에 `mode:=virtual`, `model:=a0912`, `host:=127.0.0.1`,
  `port:=12345`가 들어 있습니다.
- RViz에서 A0912 model이 보입니다.
- `ros2 control list_controllers`에서 controller가 로드되고 active 상태입니다.
- `ros2 topic echo /joint_states --once`가 A0912 joint state message를 출력합니다.
- RViz MotionPlanning panel에서 작은 motion을 plan하고 virtual mode에서 execute할 수
  있습니다.
- MoveIt bringup을 종료한 뒤 Gazebo bringup에서 A0912가 나타납니다.

## 막혔을 때

launch file을 찾지 못하면 Doosan workspace가 build되고 현재 shell에서 source되어
있는지 확인합니다.

```bash
ros2 pkg prefix dsr_bringup2
```

RViz에 다른 robot이 보이거나 joint name이 이상하면 launch command의 `model:=a0912`를
확인합니다.

controller가 inactive이면 execution을 시도하지 말고 launch output을 먼저 봅니다.
controller manager error, hardware interface error, namespace mismatch가 있는지
확인합니다.

`/joint_states`가 missing이면 bringup terminal이 아직 살아 있는지, inspection shell도
같은 ROS2 환경을 source했는지 확인합니다.

MoveIt2에서 plan은 되지만 execute가 실패하면 controller 상태를 다시 봅니다.

```bash
ros2 control list_controllers
```

Gazebo bringup이 시작되지 않으면 이전 MoveIt bringup이 아직 종료되지 않았는지,
같은 `host`와 `port`를 쓰는 process가 남아 있지 않은지 확인합니다.

## 오늘 배운 것

Doosan A0912 bringup은 launch command 하나를 외우는 일이 아닙니다. `mode:=virtual`
로 안전하게 시작하고, `model:=a0912`로 정확한 robot을 고르며, `host`와 `port`가
controller endpoint를 가리킨다는 점을 읽어야 합니다. MoveIt bringup에서는 RViz
planning과 execution path를 확인하고, `ros2 control list_controllers`와 `/joint_states`
로 controller와 observation이 살아 있는지 검증합니다. 이 기준선이 있어야 나중에
ACT/Diffusion cube-pick 실패를 policy 문제와 bringup 문제로 나눠 볼 수 있습니다.
