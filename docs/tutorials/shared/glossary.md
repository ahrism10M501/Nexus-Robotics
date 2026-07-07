# 공통 용어집

이 문서는 Day 1부터 Day 10까지 반복해서 나오는 초보자용 용어를 설명합니다.
단순한 사전식 정의가 아니라, 이 Isaac Sim, ROS2 Jazzy, Doosan A0912,
cube-pick 프로젝트에서 왜 중요한가를 중심으로 읽으면 됩니다.

각 항목은 두 부분으로 나눕니다.

- 뜻: 처음 볼 때 이해해야 하는 최소 의미
- 왜 중요한가: 이 프로젝트에서 그 개념이 필요한 이유

## Isaac Sim과 USD

### stage

뜻: stage는 Isaac Sim에 열려 있는 전체 simulated world입니다.
`/World/A0912`, `/World/Table`, `/World/Cube`, camera, task marker가 모두
stage 안에 있습니다.

왜 중요한가: Day 8과 Day 9에서는 매 episode마다 같은 시작 상태로 돌아가야
합니다. stage reset이 불안정하면 dataset replay가 맞지 않고, policy가
좋은지 scene이 흔들린 것인지 구분하기 어렵습니다.

### prim

뜻: prim은 USD stage tree 안의 하나의 node 또는 object입니다. robot,
cube, camera, table, joint, marker가 prim으로 표현될 수 있습니다.

왜 중요한가: script와 Action Graph는 `/World/Cube` 같은 prim path로 대상을
찾습니다. path가 자주 바뀌면 scene을 자동화하거나 dataset을 재생할 때 같은
object를 찾지 못합니다.

### USD

뜻: USD는 Isaac Sim이 scene을 저장하고 구성하는 scene description
system입니다. hierarchy, transform, physics setting, robot asset reference
같은 정보가 USD 안에 들어갑니다.

왜 중요한가: 이 커리큘럼은 손으로 만든 scene에서 scriptable scene으로
이동합니다. USD를 이해하면 stage tree, asset reference, 저장된 scene이
어떻게 연결되는지 덜 낯설어집니다.

### rigid body

뜻: rigid body는 physics simulation에서 움직일 수 있는 물체입니다.

왜 중요한가: cube가 rigid body가 아니면 gravity, contact, gripper
interaction을 제대로 확인할 수 없습니다. cube-pick은 보기 좋은 cube가
아니라 물리적으로 잡히고 움직이는 cube가 필요합니다.

### collider

뜻: collider는 physics engine이 충돌을 계산할 때 사용하는 shape입니다.

왜 중요한가: 화면에는 cube와 table이 보여도 collider가 없으면 cube가 table을
뚫고 떨어질 수 있습니다. Day 1에서 collider를 배우는 이유는 Day 8의 grasp와
contact가 이 설정에 의존하기 때문입니다.

### articulation

뜻: articulation은 joint로 연결된 robot body입니다. manipulator arm처럼
여러 link와 joint가 연결된 robot을 다룰 때 사용합니다.

왜 중요한가: A0912는 articulation으로 다뤄야 controller가 joint target을
보내고 Isaac Sim이 연결된 joint motion을 계산할 수 있습니다.

### Action Graph

뜻: Action Graph는 Isaac Sim에서 simulation event, control node, ROS2 Bridge
node를 연결하는 visual dataflow graph입니다.

왜 중요한가: Day 1에서는 Joint Position Action Graph로 joint를 움직이고,
Day 2에서는 `/cmd_vel`을 받는 graph를 확인하며, Day 4에서는 `/clock`과
camera topic을 publish합니다. topic이 보이지 않을 때도 graph가 ticking 중인지
확인해야 합니다.

### OmniGraph

뜻: OmniGraph는 Action Graph 아래에 있는 graph system입니다. 공식 문서에서는
node, pin, tick, graph execution 같은 표현으로 자주 등장합니다.

왜 중요한가: 초반에는 Action Graph UI만 써도 됩니다. 하지만 에러를 읽거나
공식 튜토리얼을 따라갈 때 OmniGraph라는 이름을 알면 같은 시스템을 다른
수준에서 설명하고 있다는 것을 이해할 수 있습니다.

## ROS2 Bridge와 Topic

### ROS2 Bridge

뜻: ROS2 Bridge는 Isaac Sim extension인 `isaacsim.ros2.bridge`입니다.
simulation graph가 ROS2 topic을 publish하거나 subscribe할 수 있게 해 줍니다.

왜 중요한가: host에서 실행되는 Isaac Sim과 container 안의 ROS2 Jazzy tool이
만나는 통로입니다. 이 extension이 꺼져 있으면 `ros2 topic list`에서 기대한
simulator topic이 보이지 않습니다.

### ROS2 topic

뜻: ROS2 topic은 이름이 붙은 message stream입니다. 예를 들면 `/cmd_vel`,
`/clock`, `/camera_info`, `/joint_states`가 있습니다.

왜 중요한가: 이 튜토리얼에서는 topic이 가장 기본적인 관찰 도구입니다. robot이
명령을 받는지, simulator가 시간을 publish하는지, camera metadata가 나오는지
대부분 topic으로 확인합니다.

### QoS

뜻: QoS는 Quality of Service입니다. ROS2 message의 reliability, durability,
history, depth 같은 전달 조건을 뜻합니다.

왜 중요한가: topic 이름이 보여도 data가 안 들어오는 경우가 있습니다. 그때
publisher와 subscriber의 QoS가 맞지 않으면 `ros2 topic list`에는 보여도
`ros2 topic echo`에서는 아무것도 못 받을 수 있습니다.

### /clock

뜻: `/clock`은 Isaac Sim이 publish하는 simulated time입니다. simulation이
playing 중일 때 진행되고 pause하면 멈추는 시간입니다.

왜 중요한가: dataset timestamp, RViz display, replay check가 모두 같은 시간
기준을 써야 합니다. wall-clock time과 simulation time이 섞이면 camera와 robot
state를 맞추기 어려워집니다.

### use_sim_time

뜻: `use_sim_time`은 ROS2 node가 wall-clock 대신 `/clock`을 사용하게 하는
parameter입니다.

왜 중요한가: Day 4에서 RViz `use_sim_time`을 `true`로 설정해야 simulation
time에 맞춰 camera data와 transform을 해석할 수 있습니다.

### camera_info

뜻: `camera_info`는 image topic과 짝을 이루는 camera calibration 및 geometry
metadata입니다.

왜 중요한가: RGB pixel만으로는 camera가 world를 어떤 geometry로 보고 있는지
알 수 없습니다. 나중에 observation을 policy input으로 쓸 때도 image가 어떤
camera에서 온 것인지 안정적으로 관리해야 합니다.

### /joint_states

뜻: `/joint_states`는 현재 joint position, velocity, effort를 알려주는
observation topic입니다.

왜 중요한가: A0912가 지금 어떤 자세인지 ROS2, MoveIt2, dataset collection,
나중의 policy process가 모두 이 정보를 통해 확인합니다. command를 보내기 전에
현재 상태를 아는 것이 안전한 robot control의 시작입니다.

## Robot Control

### controller

뜻: controller는 command나 trajectory를 받아 robot joint를 목표 motion으로
움직이는 구성요소입니다.

왜 중요한가: Day 6에서 `ros2 control list_controllers`를 확인하는 이유는
planning 결과가 실제 virtual A0912 motion으로 이어지는 path가 살아 있는지
보기 위해서입니다.

### MoveIt2

뜻: MoveIt2는 robot model, joint limit, collision을 고려해 motion을 planning
하는 ROS2 toolchain입니다.

왜 중요한가: Day 5와 Day 6에서는 안전한 virtual arm motion을 확인하는 기준으로
사용합니다. 나중에 policy action을 다룰 때도 "planning된 trajectory"와
"policy가 바로 낸 action"을 구분하는 기준이 됩니다.

### DSR_ROBOT2

뜻: `DSR_ROBOT2`는 Doosan Python API입니다. `movej`, `movel`, `posj`, `posx`
같은 high-level command를 제공합니다.

왜 중요한가: Day 7에서 learned policy 없이 먼저 scripted motion을 검증합니다.
이 path가 안정적이어야 Day 8의 scripted pick sequence와 Day 9의 demonstration
collection을 믿을 수 있습니다.

## Data와 Policy

### episode

뜻: episode는 하나의 cube-pick 시도 전체입니다. reset, action sequence,
final `done`, final `success`까지 포함합니다.

왜 중요한가: Day 9 dataset은 episode 단위로 저장하고 replay합니다. episode
경계가 분명해야 실패한 시도와 성공한 시도를 나중에 비교할 수 있습니다.

### observation

뜻: observation은 policy process가 action을 고르기 전에 받는 현재 상태입니다.
`cube_pick_v1`에서는 `rgb`, `joint_state`, `ee_pose`, `gripper_state`,
timestamp data가 핵심입니다.

왜 중요한가: observation을 action보다 먼저 저장해야 "이 상태를 보고 이 행동을
했다"는 순서가 유지됩니다. 이 순서가 깨지면 behavior cloning이나 replay에서
data 해석이 어긋납니다.

### action

뜻: action은 control 또는 policy 쪽에서 robot에게 다음에 하라고 요청하는
명령입니다. shared contract는 `target_ee_delta`와 `gripper_command`를 기본
action으로 사용합니다.

왜 중요한가: 작은 end-effector delta와 gripper command로 시작하면 early policy가
너무 큰 motion을 바로 내는 위험을 줄일 수 있고, simulation replay도 이해하기
쉬워집니다.

### policy process

뜻: policy process는 observation을 받아 action을 반환하는 별도 program
boundary입니다.

왜 중요한가: simulator, dataset replay, model code, safety layer를 분리하기
위해 필요합니다. policy process boundary가 명확하면 model을 ACT나 Diffusion
Policy로 바꾸더라도 simulator와 action contract를 계속 안정적으로 유지할 수
있습니다.

### safety gate

뜻: safety gate는 policy output이 robot command path로 들어가기 전에 반드시
거치는 filter입니다. delta clamp, workspace limit, non-finite value rejection,
speed limit, manual enable 같은 검사를 포함합니다.

왜 중요한가: learned policy는 real robot controller에 직접 publish하면 안
됩니다. simulation에서도 safety gate를 통과하게 만들면 나중에 real robot으로
옮길 때 위험한 구조를 처음부터 피할 수 있습니다.
