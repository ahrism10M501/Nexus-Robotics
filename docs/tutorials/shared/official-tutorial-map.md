# 공식 튜토리얼 맵

이 문서는 Day 1부터 Day 10까지의 학습 내용을 공식 튜토리얼과 연결해
보는 지도입니다. 이 커리큘럼은 NVIDIA Isaac Sim 6.0.1 문서와 Doosan
Jazzy 문서를 그대로 따라가는 과정이 아니라, A0912 cube-pick 프로젝트에
필요한 부분만 골라서 배우는 과정입니다.

공식 튜토리얼 제목, URL, command, path, ROS2 topic, API name은 English로
유지합니다. 실제 검색, 디버깅, 에러 메시지 확인은 이 이름들로 해야 하기
때문입니다.

각 Day마다 아래 두 가지를 구분해서 보세요.

- 사용함: 이 프로젝트에서 실제로 가져오는 개념과 실습 범위
- 지금은 건너뜀: 나중에 필요하지만 첫 10일 흐름에서는 의도적으로 미루는 범위

## Day 1 - Isaac Sim 기본기

공식 튜토리얼:

- NVIDIA Isaac Sim Basic Usage Tutorial:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/introduction/quickstart_isaacsim.html
- NVIDIA Basic Robot Tutorial:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/introduction/quickstart_isaacsim_robot.html

사용함:

- Isaac Sim을 열고 새 stage를 만드는 흐름
- ground plane, light, cube를 추가하는 기본 UI 조작
- cube에 rigid body, collider, mass를 붙이는 물리 설정
- built-in robot을 추가하고 Physics Inspector로 joint를 보는 방법
- Joint Position Action Graph를 만들고 simulation이 playing 중일 때 joint
  target을 바꾸는 흐름

지금은 건너뜀:

- Isaac Sim UI를 깊게 커스터마이즈하는 내용
- 여러 sample scene을 탐색하는 긴 과정
- robot asset authoring 전체 흐름

Day 1의 목표는 작습니다. stage 안에 prim이 있고, 일부 prim은 physics로
움직이며, robot articulation은 target을 받으면 joint가 움직인다는 감각만
잡으면 됩니다.

## Day 2 - Jetbot/TurtleBot ROS2 주행

공식 튜토리얼:

- Hello Robot:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/core_api_tutorials/tutorial_core_hello_robot.html
- Driving TurtleBot using ROS2 Messages:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_drive_turtlebot.html

사용함:

- Hello Robot 또는 TurtleBot 예제로 바로 움직일 수 있는 mobile robot을 준비
- `isaacsim.ros2.bridge` extension 활성화
- Action Graph가 `/cmd_vel`을 subscribe하도록 확인
- container에서 `geometry_msgs/msg/Twist`를 publish
- `ros2 topic list`, `ros2 topic info /cmd_vel`로 topic discovery 확인

지금은 건너뜀:

- custom mobile robot import
- navigation stack, SLAM, map 구성
- 이동 로봇 제어를 완벽하게 튜닝하는 일

Day 2에서는 ROS2에서 보낸 한 개의 velocity command가 Isaac Sim 안의
robot을 움직이는지 확인하는 것이 전부입니다.

## Day 3 - Python Scripting 최소 루프

공식 튜토리얼:

- Hello World:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/core_api_tutorials/tutorial_core_hello_world.html
- Hello Robot:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/core_api_tutorials/tutorial_core_hello_robot.html
- Adding Props:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/core_api_tutorials/tutorial_core_adding_props.html

사용함:

- Python으로 scene을 다시 만들 수 있는 최소 구조
- `setup_scene`, `setup_post_load`, update loop, reset logic의 역할
- ground plane, robot, cube, prop를 코드로 추가하는 흐름

지금은 건너뜀:

- 완성도 높은 Isaac Sim extension packaging
- 대형 scene 생성, asset library 관리
- policy, dataset, robot command logic

Day 3에서 중요한 것은 "손으로 만든 scene"을 "코드로 다시 만들 수 있는
scene"으로 바꾸는 생각입니다. Day 8과 Day 9의 deterministic reset은 이
기초 위에서 가능합니다.

## Day 4 - ROS2 Bridge 관측 파이프라인

공식 튜토리얼:

- ROS2 Clock:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_clock.html
- ROS2 Cameras:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_camera.html
- ROS2 QoS:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_qos.html

사용함:

- Isaac Sim에서 `/clock` publish
- RGB camera image와 `camera_info` publish
- container에서 아래 command로 observation topic 확인

```bash
ros2 topic echo /clock --once
ros2 topic info /rgb -v
ros2 topic info /camera_info -v
```

- RViz에서 `use_sim_time`을 `true`로 설정
- data가 안 들어올 때 publisher/subscriber QoS 비교

지금은 건너뜀:

- depth camera, semantic camera, multi-camera pipeline
- image processing과 model inference
- QoS 전체 이론을 깊게 파는 일

Day 4의 핵심은 policy가 아니라 observation입니다. simulator가 시간과
camera data를 내보내고 ROS2 tool이 그것을 받을 수 있어야 다음 단계로
갈 수 있습니다.

## Day 5 - A0912 전에 배우는 로봇팔 개념

공식 튜토리얼:

- ROS2 Joint Control:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_manipulation.html
- MoveIt 2:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_moveit.html

사용함:

- Franka 예제를 빠른 manipulator data flow 예제로 사용
- `/joint_states`가 현재 joint 상태 observation이라는 점
- `/joint_command`가 Isaac example에서 command intent라는 점
- MoveIt2가 planning과 collision checking을 담당한다는 점
- Articulation Ctrl이 simulator 안의 낮은 수준 actuator target이라는 점

지금은 건너뜀:

- Franka package name을 외우는 일
- Franka 설정을 프로젝트에 그대로 가져오는 일
- `/joint_command`를 learned-policy interface로 확정하는 일

Day 5는 A0912를 바로 만지기 전에 manipulator 언어를 익히는 날입니다.
robot model이 달라도 observation, command, planning, execution의 구분은
계속 사용됩니다.

## Day 6 - Doosan A0912 Bringup

공식 튜토리얼:

- Doosan ROS2 Jazzy Manual:
  https://doosanrobotics.github.io/doosan-robotics-ros-manual/jazzy/
- Doosan GitHub:
  https://github.com/DoosanRobotics/doosan-robot2

사용함:

- Doosan workspace의 `jazzy` branch
- Doosan manual에 따른 workspace 설치 또는 source
- `mode:=virtual`로 real controller 없이 먼저 bringup
- `model:=a0912`로 A0912 model 선택
- `dsr_bringup2_moveit.launch.py`로 RViz, controller, MoveIt2,
  `/joint_states` 확인
- MoveIt virtual path가 이해된 뒤 `dsr_bringup2_gazebo.launch.py` 확인

지금은 건너뜀:

- real robot controller 연결
- MoveIt bringup과 Gazebo bringup을 동시에 켜고 디버깅하는 일
- 고속 motion 또는 큰 범위의 motion

Day 6의 목표는 virtual A0912가 ROS2, controller, MoveIt2에서 일관되게
보이는지 확인하는 것입니다.

## Day 7 - A0912 Scripted Motion

공식 튜토리얼:

- Doosan DSR_ROBOT2 Python Library Tutorial:
  https://doosanrobotics.github.io/doosan-robotics-ros-manual/jazzy/tutorials/advanced_tutorials/dsr_robot_tutorial.html

사용함:

- `rclpy`, `DR_init`, `ROBOT_ID`, `ROBOT_MODEL`을 사용하는 DSR_ROBOT2
  Python setup pattern
- `movej`, `movel`, `posj`, `posx`로 작은 scripted motion 실행
- virtual mode에서 `set_robot_mode(ROBOT_MODE_AUTONOMOUS)`를 사용하는 흐름
- 처음에는 낮은 `vel`, `acc` 값으로 실행

지금은 건너뜀:

- force control, IO, tool changing
- real hardware execution
- learned-policy execution

Day 7에서는 policy를 붙이지 않습니다. 먼저 "알려진 script command path"로
virtual A0912가 안전하게 움직이는지 확인합니다.

## Day 8 - Cube-Pick Scene v0

공식 튜토리얼:

- Adding a Manipulator Robot:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/core_api_tutorials/tutorial_core_adding_manipulator.html
- Robot Setup Tutorial 6:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/robot_setup_tutorials/tutorial_import_assemble_manipulator.html
- Robot Setup Tutorial 7:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/robot_setup_tutorials/tutorial_configure_manipulator.html
- Robot Setup Tutorial 9:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/robot_setup_tutorials/tutorial_pickplace_example.html
- Surface Gripper:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/robot_simulation/ext_isaacsim_robot_surface_gripper.html

사용함:

- manipulator와 robot setup 문서를 참고해 단순한 A0912 scene 구성
- pick-place example의 task 흐름: cube 위로 이동, pre-grasp, grasp, lift,
  drop zone으로 이동, release
- two-finger gripper가 v0를 늦추면 Surface Gripper를 먼저 사용
- deterministic scene tree를 유지

```text
/World
  /A0912
  /Table
  /Cube
  /Camera_Front
  /TaskMarkers
```

지금은 건너뜀:

- 고정밀 gripper modeling
- digital twin 수준의 asset 정리
- 큰 randomized environment

Day 8에서는 현실감보다 반복 가능성이 더 중요합니다. 같은 reset에서 같은
sequence를 돌릴 수 있어야 Day 9 dataset replay가 의미 있습니다.

## Day 9 - 데이터셋 수집

공식 튜토리얼:

- Day 9 파일은 새로운 NVIDIA 또는 Doosan 공식 튜토리얼을 추가로 참조하지 않습니다.
- 이 날의 기준 문서는 공통 shared contract입니다:
  [Cube-pick v1 데이터셋과 policy interface](cube-pick-v1-dataset-policy-interface.md)

사용함:

- Day 8 scene과 `cube_pick_v1` schema
- `data/cube_pick_v1/` 아래 최소 다섯 개 scripted episode 저장
- 매 control tick에서 action 적용 전에 observation 저장
- replay를 dataset quality check로 사용

지금은 건너뜀:

- ACT, Diffusion Policy, Behavior Cloning training
- 큰 dataset 수집
- cloud storage 또는 dataset format migration
- shared contract 밖의 임의 schema key 추가

Day 9의 목적은 "학습"이 아니라 "기록과 재생"입니다. replay가 맞지 않으면
model을 학습해도 원인을 찾기 어렵습니다.

## Day 10 - Policy 연결 준비

공식 튜토리얼:

- Deploying Policies in Isaac Sim:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/isaac_lab_tutorials/tutorial_policy_deployment.html
- Running a Reinforcement Learning Policy through ROS2 and Isaac Sim:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_rl_controller.html
- Isaac Lab:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/isaac_lab_tutorials/index.html

사용함:

- simulator가 observation을 publish하고, policy process가 observation을 받고,
  policy가 action을 내고, safety gate가 action을 거른 뒤 robot command
  path가 실행한다는 구조
- ROS2 policy-controller tutorial은 task를 복사하기보다 architecture 참고용으로 사용
- Isaac Lab은 나중의 training/deployment 구조를 이해하는 배경으로만 사용
- 정확한 observation/action key는 local Policy Process Contract를 따름

지금은 건너뜀:

- policy training
- custom Isaac Lab environment 작성
- large-scale parallel training
- benchmark report
- real robot learned-policy execution

Day 10에서는 실제 robot에 policy를 연결하지 않습니다. simulation replay,
low-speed dry run, manual approval gate를 먼저 정의해 두는 것이 핵심입니다.
