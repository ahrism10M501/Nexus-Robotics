# 공통 환경 설정

Core 과정은 ROS2 Jazzy/Python을 Docker에서 실행하고 Isaac Sim은 host에서 실행합니다.
두 process는 같은 ROS domain과 FastDDS UDP profile을 사용합니다.

## 1. 저장소 경로

Clone한 저장소의 절대 경로를 현재 shell에 기록합니다.

```bash
cd /path/to/ros2-dev
export REPO_ROOT="$(pwd -P)"
```

문서의 `$REPO_ROOT`는 이 값을 뜻합니다. 개인 home directory를 문서나 설정에
고정하지 않습니다.

## 2. 환경 초기화

```bash
cd "$REPO_ROOT"
./run.sh init
```

`.env`는 version control에 포함되지 않는 local 설정입니다. 다음 값을 확인합니다.

```dotenv
LOCAL_UID=1000
LOCAL_GID=1000
ROS_DOMAIN_ID=42
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
ISAAC_SIM_ROOT=/path/to/isaacsim
ISAAC_SIM_COMPAT_VERSION=6.0.1
```

`$ISAAC_SIM_ROOT`에는 실행 가능한 `isaac-sim.sh`와 호환되는 `VERSION` 파일이 있어야
합니다. Isaac Sim이 필요 없는 host에서는 경로를 비워 둘 수 있습니다.

## 3. Core 진단과 실행

```bash
./run.sh doctor
./run.sh build
./run.sh dev
```

접두어 없는 명령은 `core` 프로필을 사용합니다. Container 안의 repository는
`/workspace`이며 `/opt/ros/jazzy/setup.bash`와 repository overlay가 자동으로
source됩니다. Container shell에서 별도로 같은 setup을 반복 source하지 않습니다.

자주 쓰는 lifecycle 명령:

```bash
./run.sh status
./run.sh shell
./run.sh down
```

## 4. Host Isaac Sim

Host 진단부터 실행합니다.

```bash
./run.sh isaac-host-doctor
```

진단이 통과하면 별도 host terminal에서 launcher를 실행합니다.

```bash
cd "$REPO_ROOT"
./scripts/launch_isaac_sim.sh
```

필요하면 core container를 host DDS overlay로 실행합니다.

```bash
./run.sh isaac-host-dev
```

Host와 container가 공유하는 핵심 값은 다음과 같습니다.

```text
ROS_DOMAIN_ID=42
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
Host:      $REPO_ROOT/config/fastdds.xml
Container: /workspace/config/fastdds.xml
```

## 5. 비파괴 bridge acceptance

Isaac Sim과 container가 이미 실행 중일 때만 현재 ROS graph를 읽습니다.

```bash
bash scripts/check_isaac_host.bash
```

- `PASS`: `/clock` topic과 sample을 관측했습니다.
- 종료 코드 `77`의 `SKIP E_PREREQUISITE`: 이 host에 Isaac Sim 조건이 없습니다.
- `FAIL E_PREREQUISITE`: 조건이 있는 host의 설정 또는 graph가 잘못되었습니다.

검사는 launcher, container, simulator lifecycle을 변경하지 않습니다.

## 6. 과정별 준비

- 첫 과정: stage, physics, articulation을 UI에서 확인합니다.
- 두 번째 과정: core container와 host bridge를 함께 사용합니다.
- 세 번째 과정: host Isaac Sim의 Python scripting 예제를 실행합니다.
- 네 번째 과정: `/clock`, image, camera metadata가 ROS2 graph에 보이는지 확인합니다.

로봇별 SDK나 controller가 필요해지는 실습은 선택한 확장 브랜치의 환경 문서를
따릅니다.
