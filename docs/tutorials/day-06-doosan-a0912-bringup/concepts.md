# 개념

Day 6부터는 learning proxy였던 Franka를 내려놓고 Doosan A0912 stack을 직접
띄웁니다. 그래도 오늘의 태도는 여전히 안전한 초보자 loop입니다. real robot
controller에 연결하지 않고 `mode:=virtual`로 시작해 launch file, controller,
MoveIt2, `/joint_states`가 서로 맞는지 확인합니다.

## Doosan Jazzy workspace

이 project는 Doosan ROS2 Jazzy manual을 기준으로 합니다. Doosan workspace는
manual에 따라 준비하고, 이 curriculum에서는 `jazzy` branch를 사용합니다. launch
file을 찾지 못하거나 Python package import가 실패하면 대개 현재 shell에서 ROS2
workspace나 Doosan workspace를 source하지 않은 상태입니다.

## 반드시 읽어야 하는 launch argument

`mode:=virtual`은 real robot controller 없이 virtual controller path를 사용한다는
뜻입니다. 초보자는 반드시 이 mode에서 먼저 RViz planning, controller state,
small motion을 확인합니다.

`model:=a0912`는 robot model을 A0912로 선택합니다. model이 틀리면 RViz에 다른
robot이 보이거나 joint name, controller name, planning group이 헷갈릴 수 있습니다.
Day 8 이후 cube-pick scene도 A0912 geometry와 joint structure를 기준으로 생각합니다.

`host`와 `port`는 Doosan controller endpoint를 가리키는 launch argument입니다.
virtual mode에서는 local virtual controller 쪽으로 맞추는 흐름을 사용합니다. 같은
bringup을 두 번 띄우거나 다른 process가 같은 `port`를 사용하면 연결 문제가 생길 수
있습니다.

## MoveIt bringup과 Gazebo bringup

MoveIt bringup은 RViz MotionPlanning panel, robot model, controller, MoveIt2
planning/execution path를 확인하기 위한 시작점입니다. Day 5에서 배운 것처럼
planning은 trajectory를 계산하는 단계이고, execution은 controller path를 통해 robot
motion으로 이어지는 단계입니다.

Gazebo bringup은 virtual robot을 physics simulation 안에서 확인하는 path입니다. 처음
배울 때는 MoveIt bringup과 Gazebo bringup을 동시에 켜서 디버깅하지 않습니다. 하나를
실행하고 확인한 뒤 종료하고, 다음 bringup을 실행합니다.

## Controller와 `/joint_states`

`ros2 control list_controllers`는 controller가 로드되고 active인지 보는 기본 도구입니다.
MoveIt2가 plan을 만들어도 controller가 active가 아니면 execution이 motion으로 이어지지
않을 수 있습니다.

`/joint_states`는 A0912의 현재 joint state observation입니다. Day 9 dataset collection과
ACT/Diffusion cube-pick policy에서는 robot이 어느 자세에서 어떤 action을 받았는지
저장해야 합니다. Day 6에서 `/joint_states`를 안정적으로 볼 수 있어야 나중에
observation과 action을 신뢰할 수 있습니다.

## Cube-pick에서 중요한 이유

ACT나 Diffusion Policy는 나중에 image, joint state, end-effector state 같은
observation을 보고 action을 냅니다. 그런데 A0912 bringup이 불안정하면 policy가
실패한 것인지 controller, namespace, model, `/joint_states`가 틀린 것인지 알 수
없습니다. Day 6의 목표는 learned policy 이전에 robot bringup path를 믿을 수 있는
기준선으로 만드는 것입니다.
