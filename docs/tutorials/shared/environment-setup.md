# 환경 설정 튜토리얼

이 repo는 host와 container를 함께 씁니다. 초보자가 가장 자주 헷갈리는 부분은
"어디에서 실행해야 하는가"입니다. Isaac Sim은 host에서 실행하고, ROS2 Jazzy
개발 도구는 container 안에서 실행한다고 먼저 생각하면 됩니다.

- Host: Isaac Sim 실행, GPU desktop session, Docker 제어,
  `./scripts/launch_isaac_sim.sh`
- `ros2_dev` container: 일반 ROS2 Jazzy command, `colcon build`,
  `ros2 topic list`
- `doosan_dev` container: Doosan A0912, MoveIt2, RViz, Gazebo,
  virtual emulator command
- `full_dev` container: `doosan_dev`에 NVIDIA `IsaacSim-ros_workspaces`
  Jazzy workspace까지 더한 무거운 옵션

command가 Docker나 Isaac Sim launch를 다루면 host에서 실행합니다. command가
`ros2`, `colcon`, ROS2 package, controller 확인을 다루면 보통 container 안에서
실행합니다.

## Host에서 container 시작하기

host terminal에서 repo root로 이동합니다.

```bash
cd /home/ahrism/workspace/ros2-dev
```

Docker image를 build합니다. Dockerfile이나 dependency가 바뀐 뒤에는 다시
build하는 습관을 들이면 좋습니다.

```bash
./run.sh build
```

개발 container를 시작합니다.

```bash
./run.sh up
```

container shell로 들어갑니다.

```bash
./run.sh shell
```

`./run.sh dev`는 `./run.sh up`을 실행한 뒤 바로 `./run.sh shell`로 들어가는
shortcut입니다. 현재 container 상태는 host에서 아래처럼 봅니다.

```bash
./run.sh status
```

작업을 끝낼 때는 host에서 내립니다.

```bash
./run.sh down
```

Doosan A0912 virtual bringup을 할 때는 별도 Doosan container profile을 사용합니다.
처음이거나 Dockerfile이 바뀐 뒤에는 build를 먼저 실행하고, 평소에는 `doosan-dev`로
container 시작과 shell 진입을 한 번에 처리합니다.

```bash
./run.sh doosan-build
./run.sh doosan-dev
```

`./run.sh doosan-up`은 container만 띄우고 싶을 때, `./run.sh doosan-shell`은 이미
떠 있는 Doosan container에 추가 shell을 열 때 사용합니다.
`doosan_dev`에는 Doosan `doosan-robot2` Jazzy workspace와 MoveIt2/RViz/Gazebo
의존성이 image 안에 build되어 있습니다. Isaac Sim은 host 설치를 사용합니다.

Doosan virtual mode는 emulator helper가 host Docker daemon을 사용할 수 있어야 합니다.
`doosan_dev` 안에서 아래 command가 성공하면 Docker socket 연결이 살아 있는 것입니다.

```bash
docker ps
```

emulator image는 host Docker에 `doosanrobot/dsr_emulator:3.0.1`로 남습니다. 처음 한 번,
Docker image를 지웠을 때, 또는 emulator version을 바꿨을 때만 아래 command를 실행합니다.

```bash
bootstrap_doosan_emulator
```

Doosan 환경 전체를 host에서 한 번에 점검하려면 아래 command를 사용합니다.

```bash
./run.sh doosan-check
```

NVIDIA `IsaacSim-ros_workspaces`의 `isaac_moveit` package가 필요한 실습은 full
profile을 사용합니다. 이 이미지는 더 큽니다.

```bash
./run.sh full-build
./run.sh full-dev
```

`./run.sh full-up`은 container만 띄우고 싶을 때, `./run.sh full-shell`은 이미 떠
있는 full container에 추가 shell을 열 때 사용합니다. Full 환경을 한 번에 점검하려면
host에서 아래 command를 실행합니다.

```bash
./run.sh full-check
```

VS Code Dev Containers를 사용할 때는 기본 환경은 `.devcontainer/devcontainer.json`,
Doosan 환경은 `.devcontainer/doosan/devcontainer.json`을 선택합니다.

## Container 안에서 ROS2 환경 준비하기

`./run.sh shell`로 들어간 뒤에는 container 안에서 아래 command를 실행합니다.

```bash
source /etc/profile.d/nexus_env.bash
cd /workspace
```

container shell은 이 파일을 자동으로 source하도록 설정되어 있지만, 새 shell을
열었거나 build 후 환경이 헷갈리면 직접 한 번 더 실행해도 됩니다.

`/etc/profile.d/nexus_env.bash`가 잡아 주는 중요한 기본값은 다음과 같습니다.

```text
ROS_DISTRO=jazzy
ROS_DOMAIN_ID=42
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
FASTDDS_DEFAULT_PROFILES_FILE=/workspace/config/fastdds.xml
FASTRTPS_DEFAULT_PROFILES_FILE=/workspace/config/fastdds.xml
```

`doosan_dev`에서는 같은 파일이 추가로 아래 setup file을 source합니다.

```text
/opt/robot_ws/doosan_ws/install/setup.bash
```

`full_dev`에서는 Doosan setup file에 더해 아래 setup file도 source합니다.

```text
/opt/robot_ws/isaacsim_ros/jazzy_ws/install/setup.bash
```

ROS2 workspace를 build합니다. 이 command는 container 안에서 실행합니다.

```bash
colcon build --symlink-install
source /etc/profile.d/nexus_env.bash
```

host에서 한 번에 build만 실행하고 싶으면 helper command를 사용할 수 있습니다.
아래 command는 host에서 실행하지만, 실제 `colcon build --symlink-install`은
container 안에서 수행됩니다.

```bash
./run.sh workspace-build
```

ROS2 topic discovery의 첫 확인은 container 안에서 합니다.

```bash
ros2 topic list
```

Isaac Sim이 아직 실행되지 않았거나 simulation이 playing 상태가 아니면 topic이
비어 있거나 일부만 보일 수 있습니다. Isaac Sim에서 ROS2 Bridge graph가 publish
중이면 Day에 따라 `/clock`, `/cmd_vel`, camera topic, `/joint_states` 등이
보여야 합니다.

## Host에서 Isaac Sim 실행하기

Isaac Sim은 container가 아니라 host terminal에서 실행합니다.

```bash
cd /home/ahrism/workspace/ros2-dev
./scripts/launch_isaac_sim.sh
```

이 script는 Isaac Sim을 시작하기 전에 ROS2 domain, RMW, FastDDS profile 경로를
container와 맞춥니다. Isaac Sim 설치 위치가 기본값 `/home/ahrism/isaacsim`이
아니라면 host에서 override합니다.

```bash
ISAAC_SIM_ROOT=/path/to/isaacsim ./scripts/launch_isaac_sim.sh
```

Isaac Sim이 열린 뒤에는 `isaacsim.ros2.bridge`를 enable하거나 이미 enable되어
있는지 확인합니다. tutorial scene 또는 graph를 열고 Play를 눌러야 많은 ROS2
topic이 실제로 publish됩니다. topic 이름은 있는데 data가 흐르지 않으면
Action Graph가 ticking 중인지도 확인합니다.

## ROS_DOMAIN_ID=42 와 FastDDS

이 project의 기본 ROS domain은 `ROS_DOMAIN_ID=42`입니다. host Isaac Sim과
container가 같은 domain을 사용해야 서로 발견할 수 있습니다. 이 값은
`compose.yml`, `/etc/profile.d/nexus_env.bash`,
`./scripts/launch_isaac_sim.sh`에 맞춰져 있습니다.

RMW는 `rmw_fastrtps_cpp`를 사용합니다. `config/fastdds.xml`은 UDPv4 transport만
사용하도록 설정되어 있습니다. 이렇게 하는 이유는 host Isaac Sim과 Docker
container 사이에서 shared-memory transport가 섞이며 생기는 discovery 문제를
줄이기 위해서입니다.

같은 파일이지만 process마다 path가 다릅니다.

```text
Container: /workspace/config/fastdds.xml
Host:      /home/ahrism/workspace/ros2-dev/config/fastdds.xml
```

FastDDS profile은 process가 시작될 때 읽힙니다. `config/fastdds.xml`을 바꿨다면
container 쪽 process와 Isaac Sim을 모두 다시 시작한 뒤 topic discovery를
확인하세요.

container 안에서 환경을 확인할 때는 아래 command를 씁니다.

```bash
env | grep -E 'ROS_DOMAIN_ID|RMW_IMPLEMENTATION|FASTDDS|FASTRTPS'
ros2 topic list
```

host Isaac Sim 쪽은 `launch_isaac_sim.sh` 시작 로그를 봅니다. script가
`ROS_DOMAIN_ID`, `RMW_IMPLEMENTATION`, `FASTDDS_DEFAULT_PROFILES_FILE`,
`FASTRTPS_DEFAULT_PROFILES_FILE` 값을 출력합니다.

## 어디에서 실행하는가

host에서 실행:

```bash
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
./scripts/launch_isaac_sim.sh
```

`./run.sh shell`로 들어간 container 안에서 실행:

```bash
source /etc/profile.d/nexus_env.bash
cd /workspace
colcon build --symlink-install
ros2 topic list
ros2 topic info /clock -v
ros2 topic echo /joint_states --once
ros2 control list_controllers
```

Doosan 환경은 host에서 `./run.sh doosan-dev`로 들어가 확인합니다. 이미 Doosan
container가 떠 있고 추가 shell만 필요하면 `./run.sh doosan-shell`을 사용합니다.

```bash
source /etc/profile.d/nexus_env.bash
ros2 pkg prefix dsr_bringup2
ros2 pkg prefix moveit_ros_move_group
docker ps
```

`isaac_moveit` package가 필요한 경우에는 host에서 `./run.sh full-dev`로 들어가
확인합니다. 이미 full container가 떠 있고 추가 shell만 필요하면 `./run.sh full-shell`을
사용합니다.

```bash
ros2 pkg prefix isaac_moveit
```

Isaac Sim UI 안에서 할 일:

```text
`isaacsim.ros2.bridge`를 enable합니다.
tutorial scene을 열거나 만듭니다.
Play를 누릅니다.
Action Graph가 ticking 중인지 확인합니다.
```

처음에는 이 실행 위치만 정확히 지켜도 많은 문제가 줄어듭니다. host와 container
둘 다 `ROS_DOMAIN_ID=42`이고 같은 FastDDS profile을 사용해야 ROS2 Bridge topic이
안정적으로 보입니다.
