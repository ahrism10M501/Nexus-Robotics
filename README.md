# Nexus Robotics ROS2 Core

ROS2 Jazzy, Python, Astral `uv`, 그리고 host에서 실행하는 Isaac Sim을 연결하는
vendor-neutral 개발 환경입니다. Core는 로봇별 SDK나 runtime을 포함하지 않습니다.
로봇 통합과 확장 튜토리얼은 이 브랜치를 기반으로 별도 브랜치에서 관리합니다.

## 지원 범위

- Ubuntu 24.04 기반 ROS2 Jazzy 개발 이미지
- Python 의존성을 hash-pinned lock으로 설치하는 Astral `uv` 환경
- non-root `developer` 사용자와 `/workspace` bind mount
- host Isaac Sim과 Docker ROS2 사이의 FastDDS UDP 통신
- x86_64와 arm64에서 사용할 수 있는 core 이미지

Isaac Sim 자체는 이미지에 설치하지 않습니다. 호환 버전은 host의
`$ISAAC_SIM_ROOT`에 준비되어 있어야 하며 launcher가 그 설치를 그대로 실행합니다.

## 빠른 시작

### 1. Clone

```bash
git clone https://github.com/ahrism10M501/Nexus-Robotics.git ros2-dev
cd ros2-dev
export REPO_ROOT="$(pwd -P)"
```

### 2. 로컬 환경 초기화

```bash
./run.sh init
```

생성된 `.env`에서 `LOCAL_UID`, `LOCAL_GID`, `ROS_DOMAIN_ID`를 확인합니다. Host Isaac
Sim을 연결하려면 설치 경로와 호환 버전도 설정합니다.

```dotenv
ISAAC_SIM_ROOT=/path/to/isaacsim
ISAAC_SIM_COMPAT_VERSION=6.0.1
```

### 3. 사전 진단

```bash
./run.sh doctor
./run.sh isaac-host-doctor
```

첫 명령은 Docker, Compose, BuildKit과 core 설정을 확인합니다. 두 번째 명령은 x86_64,
NVIDIA, host Isaac Sim 설치와 host-network DDS 계약까지 읽기 전용으로 확인합니다.

### 4. Core 이미지와 개발 shell

```bash
./run.sh build
./run.sh dev
```

`dev`는 core 컨테이너를 시작하고 `developer` shell로 들어갑니다. 이미 실행 중인
컨테이너에는 `./run.sh shell`로 접속할 수 있고, `./run.sh down`으로 종료합니다.

### 5. Host Isaac Sim 실행

별도 host terminal에서 다음을 실행합니다.

```bash
cd "$REPO_ROOT"
./scripts/launch_isaac_sim.sh
```

launcher는 `.env`를 검증하고 `$REPO_ROOT/config/fastdds.xml`을 host process에
주입합니다. 설치나 다운로드를 수행하지 않습니다.

실행 중인 bridge의 비파괴 acceptance check는 다음과 같습니다.

```bash
bash scripts/check_isaac_host.bash
```

- `PASS`와 `/clock observed`: host bridge 정상
- `SKIP E_PREREQUISITE`, 종료 코드 `77`: Isaac Sim 또는 NVIDIA host 조건 없음
- `FAIL E_PREREQUISITE`: 조건이 있는 host의 blocking failure; 출력된 조치 필요

이 검사는 simulator나 container를 시작·종료하지 않습니다.

## 프로필

| 프로필 | 목적 | 대표 명령 |
| --- | --- | --- |
| `core` | ROS2 Jazzy, Python, `uv` 기본 개발 | `./run.sh doctor`, `./run.sh dev` |
| `isaac-host` | core에 host-network DDS overlay 적용 | `./run.sh isaac-host-doctor`, `./run.sh isaac-host-dev` |

접두어 없는 명령은 `core`를 사용합니다. 지원 명령 전체는 `./run.sh --help`에서
확인합니다.

## Core 튜토리얼

1. [Isaac Sim 기본기](docs/tutorials/day-01-isaac-sim-basics/README.md)
2. [Jetbot/TurtleBot ROS2 주행](docs/tutorials/day-02-jetbot-turtlebot-ros2-driving/README.md)
3. [Python Scripting 최소 루프](docs/tutorials/day-03-python-scripting-minimum-loop/README.md)
4. [ROS2 Bridge 관측 파이프라인](docs/tutorials/day-04-ros2-bridge-observation-pipeline/README.md)

공통 환경과 학습 순서는 [튜토리얼 인덱스](docs/tutorials/README.md)를 참고합니다.

## 유지보수 확인

```bash
./run.sh check
```

현재 단계에서는 core ownership, 이식성, pinned dependency 계약을 검사합니다. CI와
로컬 검증 진입점은 후속 core 변경에서도 같은 명령 계층을 유지합니다.

## 문제 해결

- [공통 튜토리얼 문제 해결](docs/tutorials/shared/troubleshooting.md)
- [Host Isaac Sim FastDDS 사례](docs/troubleshooting/2026-07-07-isaacsim-ros2-bridge-fastdds.md)
