# ROS2 개발 워크스페이스

ROS2 Jazzy, Docker Compose, Isaac Sim, FastDDS를 함께 쓰는 로봇 시뮬레이션 개발 워크스페이스입니다. 이 README는 리포를 처음 보는 ROS2 경험자가 구조와 실행 흐름을 빠르게 파악하기 위한 온보딩 허브입니다.

## 프로젝트 개요

- ROS2/AI 개발 환경은 Docker 컨테이너 `ros2_dev`에서 실행합니다.
- Doosan A0912, MoveIt2, RViz, Gazebo 실습은 선택형 Docker 컨테이너
  `doosan_dev`에서 실행합니다.
- NVIDIA `IsaacSim-ros_workspaces`까지 필요한 실습은 더 무거운 선택형 컨테이너
  `full_dev`에서 실행합니다.
- Isaac Sim은 host에서 실행하고, ROS2 Bridge로 컨테이너의 ROS2 노드와 통신합니다.
- 기본 ROS domain은 `ROS_DOMAIN_ID=42`입니다.
- RMW는 `rmw_fastrtps_cpp`를 사용합니다.
- FastDDS는 host Isaac Sim과 Docker ROS2 사이의 shared-memory transport 문제를 피하기 위해 UDP-only profile을 사용합니다.

주요 환경 기본값:

```bash
ROS_DISTRO=jazzy
ROS_DOMAIN_ID=42
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
FASTDDS_DEFAULT_PROFILES_FILE=/workspace/config/fastdds.xml
FASTRTPS_DEFAULT_PROFILES_FILE=/workspace/config/fastdds.xml
```

## 리포지토리 구조

- `src/`: ROS2 package workspace. `bringup`, `control`, `interface`, `perception`, `policy` 영역이 예약되어 있습니다.
- `config/`: robot config와 DDS 설정. 현재 핵심 파일은 `config/fastdds.xml`입니다.
- `isaac/`: Isaac Sim 전용 script와 USD asset 위치입니다.
- `scripts/`: host/container 개발 보조 스크립트입니다.
- `docker/`: 컨테이너 shell 환경 설정입니다.
- `docs/`: 설계, 계획, troubleshooting 문서입니다.
- `data/`: rosbag, dataset 등 로컬 데이터 위치입니다. `.gitkeep` 외 내용은 git에서 제외됩니다.
- `checkpoints/`: model checkpoint 등 로컬 artifact 위치입니다. `.gitkeep` 외 내용은 git에서 제외됩니다.

## 빠른 시작

Host에서 개발 컨테이너를 빌드하고 실행합니다.

```bash
./run.sh build
./run.sh up
./run.sh shell
```

Doosan A0912 virtual bringup은 별도 profile로 시작합니다. 이 이미지는 Doosan
Jazzy stack과 MoveIt2/RViz/Gazebo 의존성을 포함하고, Isaac Sim 자체는 host 설치를
사용합니다.

```bash
./run.sh doosan-build
./run.sh doosan-dev
```

특정 Doosan branch, tag, commit으로 재현성 있게 빌드하려면 build arg를 넘깁니다.

```bash
docker compose --profile doosan build \
  --build-arg DOOSAN_ROBOT2_REF=816ecb5 \
  doosan_dev
```

컨테이너 안에서는 ROS2 환경이 자동으로 잡히지만, 새 shell에서 명시적으로 다시 source할 수 있습니다.

```bash
source /etc/profile.d/nexus_env.bash
cd /workspace
colcon build --symlink-install
ros2 topic list
```

Host에서 workspace build만 실행하려면 컨테이너를 먼저 띄운 뒤 다음 명령을 사용합니다.

```bash
./run.sh workspace-build
```

`run.sh` public commands:

```text
./run.sh build
./run.sh up
./run.sh shell
./run.sh dev
./run.sh workspace-build
./run.sh doosan-build
./run.sh doosan-up
./run.sh doosan-shell
./run.sh doosan-dev
./run.sh doosan-check
./run.sh full-build
./run.sh full-up
./run.sh full-shell
./run.sh full-dev
./run.sh full-check
./run.sh status
./run.sh down
```

`ros2_dev`는 가벼운 ROS2/AI 개발용이며 Doosan package를 포함하지 않습니다.
`doosan_dev`는 Doosan `doosan-robot2` Jazzy stack, MoveIt2, RViz, Gazebo 의존성을
이미지 안에 포함합니다. `full_dev`는 여기에 NVIDIA `IsaacSim-ros_workspaces`의 Jazzy
workspace까지 더한 무거운 옵션입니다. Doosan virtual emulator를 사용할 수 있도록
host Docker socket은 `doosan_dev`와 `full_dev`에만 연결됩니다.

Doosan 컨테이너 안에서 패키지가 보이는지 확인합니다.

```bash
source /etc/profile.d/nexus_env.bash
ros2 pkg prefix dsr_bringup2
ros2 pkg prefix moveit_ros_move_group
```

한 번에 확인하려면 host에서 아래 command를 실행합니다.

```bash
./run.sh doosan-check
```

Doosan emulator image는 host Docker daemon에 `doosanrobot/dsr_emulator:3.0.1`로
남습니다. 처음 한 번, Docker image를 지웠을 때, 또는 emulator version을 바꿨을 때만
`doosan_dev` 안에서 bootstrap helper를 실행합니다.

```bash
docker ps
bootstrap_doosan_emulator
```

NVIDIA `IsaacSim-ros_workspaces`의 `isaac_moveit` package가 필요한 경우에는 full
profile을 사용합니다. 예전 `moveit-*` command는 `full-*` command의 legacy alias로
남아 있습니다.

```bash
./run.sh full-build
./run.sh full-dev
source /etc/profile.d/nexus_env.bash
ros2 pkg prefix isaac_moveit
```

VS Code Dev Containers를 쓴다면 기본 환경은 `.devcontainer/devcontainer.json`,
Doosan 환경은 `.devcontainer/doosan/devcontainer.json`을 선택합니다.

## Isaac Sim + ROS2 Bridge

Isaac Sim은 host에서 실행합니다. 이 스크립트는 ROS domain, RMW, FastDDS profile 환경변수를 맞춘 뒤 Isaac Sim launcher를 실행합니다.

```bash
./scripts/launch_isaac_sim.sh
```

Isaac Sim 설치 위치가 기본값(`/home/ahrism/isaacsim`)과 다르면 override합니다.

```bash
ISAAC_SIM_ROOT=/path/to/isaacsim ./scripts/launch_isaac_sim.sh
```

컨테이너와 Isaac Sim은 같은 `ROS_DOMAIN_ID`와 같은 FastDDS profile을 사용해야 합니다. FastDDS profile은 process 시작 시 읽히므로 `config/fastdds.xml`을 바꾼 뒤에는 컨테이너와 Isaac Sim을 모두 재시작하세요.

## 검증

개발환경 파일의 기본 정합성을 확인합니다.

```bash
./scripts/check_dev_workflow.sh
```

기대 출력:

```text
dev workflow config looks consistent
```

Isaac Sim ROS2 Bridge가 켜져 있고 simulation이 play 중이면 컨테이너에서 topic을 확인합니다.

```bash
ros2 topic list
```

휠 로봇 예제에서 `/cmd_vel`을 구독하도록 구성되어 있다면 Twist 명령을 publish해 동작을 확인합니다.

```bash
ros2 topic pub /cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: 0.2, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.5}}" \
  --qos-reliability reliable \
  --qos-durability volatile \
  --qos-depth 10 \
  -r 10
```

멈출 때는 publisher를 종료한 뒤 zero command를 한 번 보냅니다.

```bash
ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: 0.0, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.0}}"
```

## 문제 해결 링크

- [튜토리얼 허브](docs/tutorials/README.md)
- [Cube-pick v1 데이터셋과 policy interface](docs/tutorials/shared/cube-pick-v1-dataset-policy-interface.md)
- [Isaac Sim ROS2 Bridge FastDDS 문제 해결](docs/troubleshooting/2026-07-07-isaacsim-ros2-bridge-fastdds.md)
- [초보자용 wheel robot 튜토리얼 계획](docs/superpowers/plans/2026-07-06-wheel-robot-tutorial.md)
- [초보자용 wheel robot 튜토리얼 설계](docs/superpowers/specs/2026-07-06-wheel-robot-tutorial-design.md)
