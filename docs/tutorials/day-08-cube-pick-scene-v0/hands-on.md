# Day 8 실습

## 오늘 만들 것

Day 8에서는 Isaac Sim 안에 아주 작은 cube-pick scene v0를 만듭니다. 목표 scene은
아래 구조를 가집니다.

```text
/World
  /A0912
  /Table
  /Cube
  /Camera_Front
  /TaskMarkers
```

여기서 `TaskMarkers`는 cube 위 접근 위치, pre-grasp 위치, lift 위치, drop zone 같은
참조점을 눈으로 확인하기 위한 prim group입니다. 오늘은 perfect grasp보다 안정적인
reset과 scripted replay가 더 중요합니다.

## 공식 튜토리얼 흐름

오늘은 아래 공식 문서를 그대로 끝까지 따라 하기보다, 필요한 개념만 가져옵니다.

- `Adding a Manipulator Robot`:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/core_api_tutorials/tutorial_core_adding_manipulator.html
- `Robot Setup Tutorial 6: Setup a Manipulator`:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/robot_setup_tutorials/tutorial_import_assemble_manipulator.html
- `Robot Setup Tutorial 7: Configure a Manipulator`:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/robot_setup_tutorials/tutorial_configure_manipulator.html
- `Robot Setup Tutorial 9: Pick and Place Example`:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/robot_setup_tutorials/tutorial_pickplace_example.html
- `Surface Gripper`:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/robot_simulation/ext_isaacsim_robot_surface_gripper.html

읽을 때는 "이 tutorial의 robot을 그대로 복사한다"가 아니라 "manipulator를 stage에
올리고, end-effector와 gripper를 task flow에 연결하고, pick-place sequence를 작게
쪼개는 방식"을 가져온다고 생각하세요.

## 시작하기 전에

host에서 Isaac Sim을 시작합니다.

```bash
cd /home/ahrism/workspace/ros2-dev
./scripts/launch_isaac_sim.sh
```

다른 terminal에서는 기본 ROS2 container를 시작하고 topic discovery를 확인합니다.

```bash
cd /home/ahrism/workspace/ros2-dev
./run.sh dev
```

container 안에서:

```bash
source /etc/profile.d/nexus_env.bash
cd /workspace
ros2 topic list
```

Day 6-7에서 사용한 A0912 virtual workflow가 아직 헷갈린다면 먼저
[환경 설정 튜토리얼](../shared/environment-setup.md)을 다시 확인합니다. Day 8의
scene은 real robot에 연결하지 않습니다.

## 1단계: 공식 튜토리얼을 이 scene으로 해석하기

`Adding a Manipulator Robot`에서 가져올 것은 "robot asset을 stage에 올리고 Python이나
UI에서 named prim으로 다룬다"는 감각입니다. A0912는 `/World/A0912` 아래에 두고,
나머지 object는 robot보다 단순한 prim으로 시작합니다.

`Robot Setup Tutorial 6`과 `Robot Setup Tutorial 7`에서는 manipulator setup과
configuration의 의미를 봅니다. 오늘은 모든 robot authoring을 완성하려는 날이
아닙니다. A0912가 articulation으로 보이고, end-effector 기준을 정할 수 있고,
작은 scripted motion을 안전하게 보낼 수 있으면 충분합니다.

`Robot Setup Tutorial 9`에서는 pick-place를 하나의 큰 행동으로 보지 말고 여러 작은
상태로 나누는 방식을 가져옵니다. 우리는 그 구조를 아래처럼 단순화합니다.

```text
reset
cube 위로 이동
pre-grasp 위치로 이동
gripper 활성화
lift
drop zone으로 이동
release
success label 기록
```

## 2단계: 최소 stage tree 만들기

새 stage 또는 tutorial stage에서 `/World` 아래에 다섯 개의 안정적인 anchor를 만듭니다.

`/World/A0912`는 robot입니다. `/World/Table`은 cube가 놓일 기준 surface입니다.
`/World/Cube`는 rigid body와 collider가 있는 작은 object입니다. `/World/Camera_Front`는
fixed RGB camera입니다. `/World/TaskMarkers`는 motion target을 설명하는 marker group입니다.

처음에는 scene을 예쁘게 꾸미지 않습니다. cube가 table 위에 있고, camera가 cube와
gripper를 볼 수 있고, marker가 pick path를 설명하면 충분합니다. 나중에 dataset을
볼 때 "camera가 뭘 보고 있는지"가 바로 이해되어야 합니다.

## 3단계: virtual gripper 선택하기

two-finger gripper를 이미 안정적으로 붙일 수 있다면 사용해도 됩니다. 하지만 v0에서는
`Surface Gripper`가 더 좋은 시작점일 수 있습니다. 이유는 간단합니다. 오늘 검증하려는
것은 contact mechanics의 완성도가 아니라 reset, sequence, observation timing,
success label입니다.

`Surface Gripper`를 쓰면 activate/deactivate라는 단순한 gripper state로 scripted pick
sequence를 먼저 만들 수 있습니다. 나중에 gripper model을 바꾸더라도 Day 9 dataset과
Day 10 policy boundary는 shared contract를 기준으로 유지합니다.

## 4단계: deterministic reset 추가하기

reset path는 매 attempt 전에 같은 시작 상태를 만듭니다. robot ready pose, cube pose,
cube velocity, gripper state, camera pose, task marker pose를 모두 reset 대상에 넣습니다.

초보자가 자주 놓치는 부분은 cube physics state입니다. pose만 되돌리고 velocity나
gripper attachment state를 놓치면 첫 번째 run은 괜찮아도 두 번째 run부터 cube가 이상하게
움직일 수 있습니다. reset 후에는 simulation을 잠깐 step해서 cube가 table 위에 안정적으로
놓이는지 봅니다.

## 5단계: scripted pick sequence를 천천히 실행하기

Day 7에서 배운 scripted motion 감각을 그대로 사용합니다. 처음에는 낮은 speed로
approach, pre-grasp, lift, drop motion을 하나씩 실행합니다.

pick이 실패해도 바로 gripper tuning에 빠지지 마세요. 아래 질문에 먼저 답합니다.

- reset 후 scene tree가 같은가?
- cube와 marker가 같은 pose에서 시작하는가?
- camera가 cube와 gripper를 계속 보는가?
- gripper command timing이 sequence 안에서 같은 tick에 일어나는가?
- 실패 attempt도 끝까지 replay 가능한가?

이 질문에 "yes"라고 답할 수 있으면 Day 8의 큰 목적은 이미 잡힌 것입니다.

## 6단계: scene을 shared contract와 연결하기

Day 9에서는 이 scene에서 episode를 저장합니다. 그래서 지금부터 camera, robot state,
gripper state, action intent, done/success label이 같은 control tick에서 함께 읽힐 수
있는지 확인합니다.

정확한 observation/action 이름, shape, file layout은 이 문서에 복사하지 않습니다.
필요할 때마다 shared contract를 봅니다:
[Cube-pick v1 데이터셋과 policy interface](../shared/cube-pick-v1-dataset-policy-interface.md).

## 확인하기

아래가 확인되면 Day 8은 통과입니다.

- `/World/A0912`, `/World/Table`, `/World/Cube`, `/World/Camera_Front`,
  `/World/TaskMarkers`가 stage에서 안정적으로 보입니다.
- reset을 여러 번 실행해도 robot, cube, camera, marker, gripper state가 같은 시작점으로
  돌아옵니다.
- scripted pick sequence가 low speed로 끝까지 실행됩니다.
- cube grasp가 실패해도 episode attempt가 중간에 깨지지 않습니다.
- camera, robot state, gripper state, action intent, success label을 같은 control tick에서
  읽을 수 있습니다.
- `Surface Gripper`를 쓰는 경우 activate/deactivate timing을 설명할 수 있습니다.

## 막혔을 때

cube가 매번 다른 곳에서 시작하면 cube pose reset과 robot reset이 같은 reset path 안에
있는지 확인합니다. physics velocity와 gripper attachment state도 함께 초기화합니다.

robot이 cube에 닿지만 lift하지 못하면 two-finger gripper tuning을 잠시 멈추고
`Surface Gripper`로 scene/replay loop를 먼저 안정화합니다.

camera image와 robot state가 어긋나 보이면 action을 적용하기 전 control tick에서 필요한
값을 함께 읽고 있는지 확인합니다. Day 9에서는 이 timing이 dataset 품질이 됩니다.

sequence가 첫 run 뒤에만 망가지면 reset이 gripper state나 cube physics state를 완전히
되돌리지 못한 것입니다. scene을 저장하기 전에 reset을 세 번 연속 실행해 보세요.

## 오늘 배운 것

Day 8에서는 공식 manipulator와 pick-place tutorial을 우리 project의 아주 작은
scene으로 번역했습니다. `/World/A0912`, `/World/Table`, `/World/Cube`,
`/World/Camera_Front`, `/World/TaskMarkers`라는 안정적인 구조를 만들고,
`Surface Gripper` 같은 virtual gripper로 pick sequence를 먼저 검증했습니다. 가장 중요한
배움은 deterministic reset입니다. ACT나 Diffusion Policy는 나중 일이고, 오늘은 실패한
pick도 같은 방식으로 다시 볼 수 있는 scene/replay loop를 만드는 것이 핵심입니다.
