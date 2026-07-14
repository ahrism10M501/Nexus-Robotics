# 확장형 ROS2 로봇 브랜치 아키텍처 설계

작성일: 2026-07-14
상태: 사용자 승인 완료

## 1. 목적

이 설계는 현재 한 브랜치에 섞여 있는 ROS2 공통 개발환경, Doosan Robotics,
OpenArm, Isaac Sim 연동, 교육 자료를 충돌이 적은 장기 브랜치 계층으로 분리한다.

완료 후 각 브랜치는 다음 역할만 가진다.

```text
main
├── doosan-robotics
│   └── doosan-tutorial
└── open-arm
    └── openarm-tutorial
```

동시에 다음 목표를 만족해야 한다.

- `main`은 ROS2 Jazzy, Python, Astral uv, 호스트 Isaac Sim의 ROS2 Bridge 연결만 제공한다.
- 로봇별 설치, 권한, emulator, MoveIt, asset과 bringup은 로봇 브랜치로 격리한다.
- 공통 튜토리얼은 한 번만 관리하고 로봇별 과정만 leaf 브랜치에서 확장한다.
- Ubuntu x86_64에 갇힌 설정을 줄이고 가능한 core 경로는 amd64와 arm64에서 검증한다.
- AI Agent가 브랜치 경계를 유지할 수 있게 짧은 지침, 선언형 contract, 자동 검사를 제공한다.
- Agent의 구현 자율성을 유지하고 항상 로드되는 context를 최소화한다.

## 2. 현재 상태와 문제

### 2.1 Git 상태

조사 시점의 ref는 다음과 같다.

```text
b086bc7
├── 6bb7f14  main, user/damin, origin/main
└── 347a615 ... bbce9bd  feat/team-shared-dev-env
```

- 원격에는 `main`만 존재한다.
- `doosan-robotics`, `open-arm`, `doosan-tutorial`, `openarm-tutorial`은 아직 없다.
- `main`과 `feat/team-shared-dev-env`는 서로의 조상이 아니며 공통 조상 이후 갈라졌다.
- 예상 textual conflict는 `compose.yml`, `docker/nexus_env.bash`, `run.sh`에 있다.

### 2.2 보존해야 할 작업

현재 `user/damin` worktree에는 다음 사용자 변경이 있다.

- `Dockerfile.doosan`: Doosan upstream 보정 3개와 uv venv 추가
- `scripts/check_dev_workflow.sh`: 위 변경의 정적 검사 추가
- 미추적 OpenArm 한글 매뉴얼 PDF
- 미추적 `user-ws/`

`feat/team-shared-dev-env` worktree에도 수정 및 미추적 파일이 있다. 대부분 현재
`main`의 blob과 동일하지만, 이관이 끝날 때까지 두 worktree를 reset, clean, stash,
삭제하지 않는다.

### 2.3 미병합 환경의 가치와 결함

`feat/team-shared-dev-env`에서 가져올 가치가 있는 공통 기능은 다음과 같다.

- immutable base image와 uv image pin
- hash-locked Python dependency
- 비루트 runtime 사용자와 UID/GID 매핑
- 최소 권한 Compose 기본값
- GPU, GUI, host DDS의 독립 override
- `.env` 초기화와 host doctor
- static, init, doctor, Compose contract test

그러나 해당 브랜치를 직접 merge하지 않는다. 다음 결함을 먼저 분리해야 한다.

- core와 Doosan/Isaac ROS installer가 한 Dockerfile에 결합되어 있다.
- `docker/versions.env`가 실제 Compose 실행 경로에 연결되지 않는다.
- 일부 profile override가 `run.sh`에서 선택되지 않는다.
- Docker socket을 제거한 서비스에서 `docker ps`를 요구한다.
- Dev Container의 root 사용자와 Python interpreter 설정이 새 설계와 다르다.
- 현재 `main`의 정적 검사는 legacy 다중 Dockerfile 구조를 전제로 한다.

따라서 feature branch는 merge 대상이 아니라 검증된 코드의 donor로 사용한다.

## 3. 범위

### 3.1 포함

- 공통 Docker/Compose/Profile 아키텍처
- 장기 브랜치 계층과 동기화 정책
- Doosan 및 OpenArm overlay 경계
- 공통/로봇별 튜토리얼 분리
- 기존 작업의 forward-only 이관
- AI Agent 유지보수 contract와 CI
- 정적, build, runtime, no-hardware 및 수동 HIL 검증 계층

### 3.2 제외

- Isaac Sim 자체를 컨테이너 이미지에 설치하거나 배포하는 작업
- learned policy, ACT, VLA, world model 구현 또는 실제 학습
- OpenArm에 존재하지 않는 ROS interface나 launch API를 임의로 발명하는 작업
- 라이선스가 확인되지 않은 robot/USD asset의 저장소 반입
- 자동 실제 로봇 제어, 자동 CAN 송신, 자동 영점 보정
- 기존 public Git history rewrite
- 검증 완료 전 `feat/team-shared-dev-env` 삭제

## 4. 지원 등급

지원 범위는 core와 실제 시뮬레이터/하드웨어 경로를 구분한다.

| 등급 | 환경 | 범위 |
|---|---|---|
| Core Tier 1 | Ubuntu 24.04, linux/amd64 | ROS2 Jazzy, Python 3.12, uv, headless Docker, CI |
| Core Tier 1 | Ubuntu 24.04, linux/arm64 | `ros-python-dev`까지의 공통 build와 smoke test |
| Isaac Host Tier 1 | Ubuntu 24.04, x86_64, NVIDIA GPU | 호스트 Isaac Sim 6.0.1과 container ROS2 Bridge/FastDDS 통신 |
| Hardware Tier 1 | Ubuntu 24.04, x86_64 | Doosan 또는 OpenArm의 수동 승인 HIL |
| Best effort | Docker Desktop, WSL2, 다른 Linux | core/headless만 허용하며 CI 완료 조건에 포함하지 않음 |

`ros-ai-dev`의 arm64 지원은 lock된 wheel과 import smoke test가 통과한 경우에만
승격한다. GPU, GUI, host network, Docker socket은 어떤 플랫폼에서도 기본값이 아니다.

### 4.1 초기 재현성 pin

첫 이관은 donor branch에서 이미 검토된 다음 값을 사용한다. 구현 중 호환되지 않으면
임의로 최신 버전으로 올리지 않고 해당 계획을 중단하여 설계를 다시 검토한다.

```text
ROS_BASE_IMAGE=osrf/ros:jazzy-desktop@sha256:1d6f898b6ab77636c40f26298070ad3de5a9e06f0a71cf9ab066fd6b7838f151
UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:88baae1f9fa298996f8313e44559163c535937406d217f1c8ac9d4b86a2020fd
DOOSAN_REF=816ecb5d1c2599303eaf9540216afa03552f80ad
OPENARM_CAN_RELEASE=1.2.8
OPENARM_ROS2_RELEASE=0.9.2
ISAAC_SIM_COMPAT_VERSION=6.0.1
```

release 이름으로 지정된 OpenArm 두 항목은 installer 작성 시 tag가 가리키는 full commit
SHA와 archive checksum을 함께 기록한다. AI Python direct dependency는 기존 donor의
`torch==2.7.1`, `torchvision==0.22.1`, `diffusers==0.34.0`,
`huggingface-hub==0.33.4`, `einops==0.8.1`, `timm==1.0.17`을 유지하고 transitive
dependency는 hash lock으로 고정한다.

## 5. 브랜치 모델

### 5.1 소유권

| 브랜치 | 부모 | 소유 범위 |
|---|---|---|
| `main` | 없음 | ROS2/Python/uv core, 공통 Compose, FastDDS, host Isaac launcher, Days 1-4 |
| `doosan-robotics` | `main` | Doosan source, patches, MoveIt/Gazebo/RViz, emulator, 전용 profile |
| `open-arm` | `main` | OpenArm CAN/ROS source, SocketCAN, `vcan`, safety 및 전용 profile |
| `doosan-tutorial` | `doosan-robotics` | Doosan용 Days 5-10, 예제, USD와 checkpoint |
| `openarm-tutorial` | `open-arm` | OpenArm용 Days 5-10, 예제, asset과 checkpoint |

### 5.2 동기화

동기화 방향은 한쪽뿐이다.

```text
main → robot branch → matching tutorial branch
```

- 공통 수정은 `main`에서 시작한다.
- 로봇 runtime 수정은 해당 robot branch에서 시작한다.
- tutorial에서 발견한 runtime 결함은 부모 robot branch에서 먼저 수정한다.
- 서로 다른 robot branch 사이에는 merge나 공유 commit cherry-pick을 하지 않는다.
- 공개된 장기 브랜치는 rebase하지 않고 merge commit으로 부모를 동기화한다.
- tutorial 또는 robot branch를 `main`으로 역병합하지 않는다.

새 공통 기능이 필요하면 먼저 `main`의 확장 interface를 일반화한 후 자식 브랜치가
이를 사용한다. 이 규칙은 `main`이 특정 vendor를 알게 되는 것을 막는다.

## 6. `main` 아키텍처

### 6.1 파일 경계

```text
Dockerfile
compose.yml
compose/
  host-dds.yml
  gpu.yml
  gui.yml
config/fastdds.xml
docker/
  nexus_env.bash
  versions.env
  requirements/
profiles/
  core.conf
  isaac-host.conf
scripts/
  doctor.bash
  launch_isaac_sim.sh
  lib/
tests/
docs/tutorials/
  day-01-*/
  day-02-*/
  day-03-*/
  day-04-*/
  shared/
```

`main`에는 `doosan`, `openarm`, A0912, AA-K1 이름을 가진 runtime target이나
Compose service를 두지 않는다. 브랜치 계층을 기술하는 governance metadata는 예외다.

### 6.2 Docker target

```text
ros-base
└── ros-dev
    └── ros-python-dev
        └── ros-ai-dev
```

- `ros-base`: digest로 고정된 ROS2 Jazzy base, locale, 인증서, 비루트 사용자
- `ros-dev`: colcon, rosdep, vcstool, compiler, Git과 ROS 진단 도구
- `ros-python-dev`: 고정된 uv binary, Python 3.12, system-site-packages venv
- `ros-ai-dev`: 별도 hash lock을 사용하는 선택형 ML dependency

ROS의 apt Python package와 uv 환경을 함께 사용하기 위해 system Python을 교체하지 않고
`/opt/venv`가 ROS site package를 읽게 한다. 기본 `ros2_dev` service는
`ros-python-dev`를 사용한다.

### 6.3 Compose 권한

기본 `compose.yml`은 다음 권한을 갖지 않는다.

- GPU
- X11/Wayland socket
- host network, PID 또는 IPC
- Docker socket
- root runtime user
- 고정 `container_name`

필요한 기능은 독립 override로만 더한다.

- `host-dds.yml`: host network만 추가
- `gpu.yml`: GPU reservation과 최소 driver capability만 추가
- `gui.yml`: read-only X11 socket과 제한된 Xauthority만 추가

호스트 Isaac Sim 연동은 `host-dds.yml`을 사용한다. Isaac Sim 자체와
`IsaacSim-ros_workspaces`는 core image에 설치하지 않는다. 기존 `full-dev`가 필요했던
Doosan 기능은 `doosan-robotics`의 선택형 target으로 재평가한다.

### 6.4 Profile interface

`run.sh`는 vendor 이름을 case 문에 하드코딩하지 않고 `profiles/*.conf`를 읽는다.
profile은 다음 key만 선언할 수 있다.

```text
PROFILE_VERSION
SERVICE
COMPOSE_FILES
COMPOSE_PROFILES
DOCTOR_COMMAND
CHECK_COMMAND
```

값은 임의 shell code로 `source`하지 않고 allow-list parser로 검증한다. 표준 명령은
다음 형태를 유지한다.

```bash
./run.sh init
./run.sh doctor
./run.sh dev
./run.sh isaac-host-dev
./run.sh doosan-dev
./run.sh openarm-dev
./run.sh doosan-check
./run.sh openarm-check
```

`<profile>-<action>` 해석은 generic하므로 새 robot profile이 추가되어도 `run.sh`를
수정하지 않는다. `doosan-*`와 `openarm-*` 명령은 해당 profile 파일이 존재하는 자식
브랜치에서만 유효하며, `main`에서는 `E_PROFILE`로 명확하게 실패한다.

## 7. Robot overlay

### 7.1 공통 규칙

각 robot branch는 공통 파일을 편집하지 않고 전용 파일을 추가한다.

```text
docker/<robot>/Dockerfile
docker/<robot>/install.bash
docker/<robot>/versions.env
compose/<robot>.yml
profiles/<robot>.conf
.devcontainer/<robot>/
docs/platform/<robot>/
tests/<robot>/
```

전용 Dockerfile은 Compose BuildKit `additional_contexts`로 `main`의
`ros-python-dev` 결과를 상속한다. 지원 최소값은 Docker Compose 2.30과 BuildKit이다.
동일한 ROS/Python/uv 설치를 vendor Dockerfile에 복사하지 않는다.

### 7.2 Doosan

`doosan-robotics`는 다음을 소유한다.

- full commit SHA로 고정된 `DoosanRobotics/doosan-robot2`
- MoveIt2, Gazebo, RViz와 ros2_control dependency
- 현재 `Dockerfile.doosan`의 세 upstream 보정
- emulator lifecycle과 trusted one-shot runner
- `doosan`, 선택형 `doosan-isaac` profile
- Doosan package, controller, namespace와 emulator smoke test

현재 `sed` 치환은 `docker/doosan/patches/*.patch`로 변환한다. 각 patch는 적용 대상
upstream SHA를 metadata로 가지며 `git apply --check`가 실패하면 build를 중단한다.

일반 Doosan 개발 컨테이너에는 Docker socket을 연결하지 않는다. vendor emulator가
host Docker API를 반드시 요구할 때만 별도의 명시적 trusted service가 socket을 가진다.
해당 service는 기본 `dev`, Dev Container, CI에서 실행되지 않는다.

### 7.3 OpenArm

OpenArm 매뉴얼 v1.2가 정의하는 최소 요구사항은 다음과 같다.

- Ubuntu 22.04 또는 24.04와 Linux SocketCAN
- CMake 3.22 이상과 C++17
- `can-utils`, `iproute2`, OpenArm CAN library와 utility
- CAN FD nominal bitrate 1 Mbps, data bitrate 5 Mbps
- 연결 구성에 따라 운영자가 명시하는 2개 또는 4개 CAN interface
- right/left arm interface mapping 확인

프로젝트는 `main`과의 일관성을 위해 Ubuntu 24.04/Jazzy로 표준화한다. 매뉴얼은
ROS package, URDF, controller, topic/action 또는 launch contract를 정의하지 않으므로
공식 `enactic/openarm_can`과 `enactic/openarm_ros2`의 고정 release/commit을 별도로
검증한다. 검증되지 않은 ROS API를 구현하지 않는다.

CAN interface 설정은 기본적으로 host helper가 `sudo`로 수행한다. runtime container는
host network로 이미 구성된 interface를 사용하며 `NET_ADMIN`을 갖지 않는다. 내부에서
설정해야 하는 예외 profile은 권한과 위험을 명시하고 기본 경로에서 제외한다.

실제 hardware가 없는 CI는 `vcan` 또는 protocol-level fake를 사용한다. 실제 CAN 송신,
actuator enable, 영점 보정은 수동 HIL gate 뒤에서만 가능하다.

OpenArm 한글 매뉴얼은 confidential 및 무단 복제/배포 금지 표시가 있으므로 배포 권한이
확인되기 전 Git에 추가하지 않는다. 공개 가능한 운영 요구사항만 저작권을 침해하지 않는
범위에서 별도 문서로 정리한다.

## 8. Tutorial 모델

Days 1-4와 `docs/tutorials/shared/`는 `main`이 한 번만 소유한다.

- Day 1: Isaac Sim 기본 조작
- Day 2: ROS2 mobile robot 통신
- Day 3: Python scripting 최소 루프
- Day 4: ROS2 Bridge 관측 pipeline

Days 5-10은 tutorial branch가 동일한 학습 목표를 각 robot에 맞게 제공한다.

- Day 5: manipulator/control 개념
- Day 6: robot bringup
- Day 7: scripted motion
- Day 8: deterministic cube-pick scene
- Day 9: dataset record/replay
- Day 10: policy connection contract

현재 Doosan curriculum의 Days 7-9는 문서만 있고 실행 가능한 deliverable이 부족하다.
`doosan-tutorial` 완료 조건에는 tracked script, deterministic reset, record/replay test를
포함한다. 현재 미참조 Python/USD asset은 문서에서 실제로 사용하거나 제거 대상으로
명시하여 orphan asset을 남기지 않는다.

`openarm-tutorial`은 Doosan 파일을 복사해 이름만 바꾸지 않는다. OpenArm의 검증된
ROS interface와 라이선스가 확인된 asset을 사용해 같은 학습 결과를 새로 구현한다.
적절한 simulation asset이 없으면 branch publish를 보류하고 CAN/ROS interface 검증까지만
완료 상태로 보고한다.

절대 host 경로인 `/home/ahrism/...`은 문서에서 제거하고 `$REPO_ROOT`, `$HOME`,
`ISAAC_SIM_ROOT` 같은 설정값을 사용한다.

## 9. AI Agent 유지보수 체계

### 9.1 형태 선택

이 규칙은 이 저장소에 특화되어 있으므로 전역 personal skill 대신 repository-native
agent contract를 사용한다. 전역 skill은 같은 패턴이 두 개 이상의 저장소에서 검증된
후 별도 작업으로 추출한다.

```text
AGENTS.md
config/branch-contract.json
docs/maintenance/
  branch-governance.md
  ai-agent-runbook.md
scripts/maintenance/
  audit-branches.bash
  sync-plan.bash
tests/test_branch_contract.bash
.github/workflows/branch-contract.yml
```

### 9.2 Progressive disclosure

항상 로드되는 root `AGENTS.md`는 200단어 이내로 유지하고 다음만 포함한다.

- 변경을 올바른 소유 브랜치에서 시작한다.
- 동기화는 부모에서 자식 방향으로만 한다.
- dirty worktree와 사용자 변경을 보존한다.
- 실제 hardware와 원격 publish는 명시적 권한 경계다.
- 작업 종류에 따라 어떤 세부 문서를 읽을지 안내한다.

세부 지침은 관련 작업에서만 읽는다.

- branch 구조 변경 또는 sync: `docs/maintenance/branch-governance.md`
- audit, migration, recovery: `docs/maintenance/ai-agent-runbook.md`
- Doosan 변경: `docker/doosan/AGENTS.md`
- OpenArm 변경: `docker/openarm/AGENTS.md`
- tutorial 변경: `docs/tutorials/AGENTS.md`

동일한 규칙을 여러 파일에 복제하지 않는다. 경로와 branch 관계는 JSON contract,
절차는 runbook, 로봇 안전 규칙은 해당 하위 지침에 한 번만 기록한다.

### 9.3 자율성 경계

지침은 구현 recipe가 아니라 결과 invariant를 정의한다. Agent는 다음을 자율적으로
결정한다.

- 조사 도구, 구현 방식과 작업 분해
- 요청 범위 내 로컬 수정과 테스트 순서
- read-only 검사와 실패 원인에 따른 안전한 대안
- contract를 만족하는 focused file 구조

다음 조건에서만 중단하고 사용자 권한이나 선택을 요청한다.

- push, branch 삭제, 공개 merge처럼 원격 상태를 바꾸는 작업
- 실제 로봇 제어, CAN 송신, 영점 보정
- dirty 변경을 덮어써야만 진행 가능한 상황
- 승인된 branch 책임 모델 자체를 변경해야 하는 상황

안전한 정상 구현에서는 불필요한 확인 질문을 만들지 않는다.

### 9.4 선언형 contract

`config/branch-contract.json`은 schema version, branch kind, parent, owned path,
forbidden path, verification command와 safety gate를 선언한다. 새 robot은 contract entry,
profile, 전용 directory와 test만 추가하며 중앙 dispatcher를 수정하지 않는다.

contract는 최소한 다음 관계를 표현한다.

```json
{
  "schema_version": 1,
  "branches": {
    "main": {"kind": "core", "parent": null},
    "doosan-robotics": {"kind": "robot", "parent": "main"},
    "open-arm": {"kind": "robot", "parent": "main"},
    "doosan-tutorial": {"kind": "tutorial", "parent": "doosan-robotics"},
    "openarm-tutorial": {"kind": "tutorial", "parent": "open-arm"}
  }
}
```

실제 구현에서는 각 branch entry에 exact path와 command 배열을 추가하고 JSON Schema로
검증한다.

### 9.5 Agent workflow와 출력

```text
요청 해석
→ branch/worktree/dirty 상태 read-only 확인
→ contract audit
→ 소유 branch 결정
→ 격리 worktree에서 변경
→ 최소 비용부터 branch 검증
→ diff, command와 결과 보고
```

`audit-branches.bash`는 기본적으로 짧은 결과만 출력한다.

```text
PASS 또는 FAIL
위반 invariant
근거 ref/file
권장 다음 동작
```

상세 log는 `--verbose`, 도구 연동은 `--format json`에서만 제공한다.
`sync-plan.bash`는 실제 merge를 수행하지 않고 필요한 부모, 대상, 사전 조건과 검증
명령을 출력한다. Agent가 상황에 맞게 merge를 수행하고 충돌을 판단한다.

### 9.6 Agent 지침 검증

AI 지침은 작성 전에 지침이 없는 fresh agent의 baseline 실패를 기록하고, 작성 후 같은
시나리오를 다시 실행한다. 검증 시나리오는 다음을 포함한다.

- vendor 변경을 `main`에 넣으려는 요청
- tutorial branch를 부모로 역병합하라는 압력
- dirty worktree에서 빠르게 checkout하라는 압력
- 실제 OpenArm calibration을 자동화하라는 요청
- 안전한 local audit인데도 불필요한 승인을 묻는 과잉 제약
- 새 robot branch를 중앙 `run.sh` 하드코딩 없이 추가하는 확장 작업

성공 기준은 안전 invariant를 지키면서도 허용된 로컬 작업을 자율적으로 진행하는 것이다.

## 10. 마이그레이션

기존 이력은 rewrite하지 않고 forward-only로 이관한다.

### 단계 0: 보존

1. `6bb7f14`를 가리키는 migration 기준 tag를 만든다.
2. root worktree의 tracked diff를 binary patch와 checksum으로 repository 밖에 백업한다.
3. 미추적 PDF와 `user-ws/`는 그대로 둔다.
4. `feat/team-shared-dev-env` worktree도 그대로 보존한다.
5. 이후 구현은 `superpowers:using-git-worktrees`로 만든 격리 worktree에서 수행한다.

### 단계 1: core `main`

1. `feat/team-shared-dev-env`의 순수 core 기능만 선별 이식한다.
2. 혼합 commit은 cherry-pick하지 않고 test-first로 재구성한다.
3. Doosan service, installer, emulator와 Days 5-10을 `main`에서 제거한다.
4. 공통 profile, host Isaac, multi-arch core와 Agent contract를 검증한다.
5. 검증된 core 변경을 `main`에 forward commit으로 반영한다.

### 단계 2: robot branch

1. 동일한 clean `main` commit에서 두 robot branch를 생성한다.
2. `doosan-robotics`에 archive의 vendor 파일과 root worktree patch를 새 구조로 복원한다.
3. `open-arm`에 CAN/ROS overlay를 신규 구현한다.
4. 각 branch는 core test와 자신의 no-hardware test를 모두 통과한다.

### 단계 3: tutorial branch

1. 각 robot branch에서 matching tutorial branch를 생성한다.
2. Doosan Days 5-10을 archive에서 복원하고 실행 가능하게 완성한다.
3. OpenArm Days 5-10을 검증된 interface와 asset으로 구현한다.
4. 공통 Days 1-4를 복제하지 않고 부모에서 상속한다.

### 단계 4: publish와 archive

1. `main`, robot, tutorial 순서로 원격 branch를 게시한다.
2. branch protection과 CI를 적용한다.
3. fresh clone에서 각 branch acceptance test를 실행한다.
4. 모든 이관이 확인된 뒤에만 donor branch의 보관 또는 삭제를 별도로 결정한다.

## 11. 오류 처리

도구와 Agent 보고는 오류를 다음 범주로 구분한다.

| 코드 | 의미 | 기본 동작 |
|---|---|---|
| `E_BRANCH_CONTRACT` | 현재 branch가 경로를 소유하지 않음 | 올바른 branch/worktree를 제안하고 수정 중단 |
| `E_DIRTY_WORKTREE` | 안전한 전환 또는 merge가 불가능 | 사용자 변경을 보존하고 격리 worktree 사용 |
| `E_PROFILE` | manifest key, service 또는 Compose 조합 오류 | 실행 전 fail-fast |
| `E_PREREQUISITE` | Docker, Compose, GPU, X11, Isaac root 또는 CAN 누락 | 누락 항목과 확인 명령 보고 |
| `E_UPSTREAM_PIN` | SHA, digest 또는 patch 대상 불일치 | build 중단, 자동 최신화 금지 |
| `E_HARDWARE_GATE` | 실제 장비 작업 승인 또는 preflight 누락 | 명령 전송 없이 중단 |
| `E_LICENSE_GATE` | PDF 또는 asset 배포 권한 미확인 | 추적/publish 중단 |

실패 시 다른 profile로 조용히 fallback하지 않는다. Agent는 근거와 안전한 다음 선택을
제시하되 승인된 범위 안에서 가능한 진단은 계속 수행한다.

## 12. 검증 전략

검사는 비용과 위험이 낮은 순서로 실행한다.

### 12.1 공통

1. JSON Schema, profile allow-list와 shell syntax
2. branch/path contract와 Markdown link
3. 모든 Compose 조합의 normalized configuration
4. linux/amd64 및 linux/arm64 `ros-python-dev` build
5. non-root UID/GID, Python, uv, ROS2 talker/listener smoke test
6. host Isaac profile의 FastDDS와 domain contract

### 12.2 Doosan

1. pinned SHA와 patch applicability
2. vendor image build 및 ROS package discovery
3. emulator service의 socket 격리
4. virtual bringup, controller와 `/joint_states`
5. 실제 hardware는 별도 수동 승인 HIL

### 12.3 OpenArm

1. CMake 3.22+, C++17, CAN/OpenArm utility 존재
2. `vcan` send/receive 또는 protocol fake
3. operator가 선언한 interface 수와 right/left mapping preflight
4. CAN FD 1M/5M/FD 상태 확인
5. passive `candump` HIL
6. enable/disable 및 calibration은 분리된 수동 절차

### 12.4 Tutorial

1. link, command와 asset reference 검사
2. 절대 host path 금지
3. Day별 tracked deliverable와 checkpoint 검사
4. deterministic reset과 record/replay test
5. 부모 robot branch의 전체 test 재실행

## 13. 보안과 안전

- Docker socket은 root-equivalent 권한으로 취급한다.
- `xhost +local:root`를 사용하지 않는다.
- 기본 service에는 host network, GPU, GUI, PID, IPC가 없다.
- OpenArm CAN 설정은 host에서 수행하고 runtime `NET_ADMIN`을 기본 금지한다.
- 실제 motion 전에 base 고정, 작업 반경 비우기, cable 확인, E-stop 접근성을 확인한다.
- zero calibration은 자동 움직임과 persistent zero 기록을 동반하므로 CI에서 금지한다.
- confidential PDF와 라이선스 미확인 asset은 Git과 원격 publish에서 제외한다.

## 14. 구현 계획 분할

이 umbrella 설계는 독립적으로 검토 가능한 다섯 구현 계획으로 분리한다.

1. **Core 및 migration plan**: 작업 보존, `main` 정리, 공통 Docker/Profile/CI
2. **AI Agent governance plan**: `AGENTS.md`, contract, audit/sync 도구와 behavior test
3. **Doosan overlay plan**: vendor image, patches, emulator, devcontainer와 smoke test
4. **OpenArm overlay plan**: CAN/ROS, `vcan`, safety와 HIL gate
5. **Tutorial variants plan**: Days 1-4 공통화, Doosan/OpenArm Days 5-10

의존 순서는 1 → 2 → (3과 4 병렬) → 5다. 각 계획은 별도 commit과 acceptance test를
가지며 다음 계획이 없어도 자체적으로 유효한 결과를 만든다.

## 15. 완료 조건

- `main`에서 vendor runtime 파일과 Days 5-10이 제거되어 있다.
- `main`의 host Isaac profile이 Isaac Sim 설치 없이 ROS2 Bridge 연결 설정만 제공한다.
- core image가 amd64/arm64에서 build되고 Python, uv, ROS smoke test를 통과한다.
- 각 robot branch는 `main`의 후손이며 공통 파일을 복제하지 않는다.
- 각 tutorial branch는 올바른 robot branch의 후손이다.
- Doosan의 현재 local patches가 추적 가능한 patch 파일과 test로 보존된다.
- OpenArm real-hardware 명령은 자동 실행되지 않고 명시적 safety gate 뒤에 있다.
- Days 1-4는 한 번만 존재하고 Days 5-10은 robot별 실행 가능한 결과를 가진다.
- root `AGENTS.md`가 200단어 이내이고 관련 문서만 조건부로 읽게 한다.
- Agent behavior test가 안전 위반과 과도한 승인 요청을 모두 탐지한다.
- branch contract와 CI가 역방향 merge 및 경로 침범을 차단한다.
- 모든 기존 사용자 변경의 원본 또는 checksum 검증 가능한 backup이 남는다.

## 16. 참고 자료

- ROS2 Jazzy supported platforms: <https://docs.ros.org/en/ros2_documentation/rolling/Releases/Release-Jazzy-Jalisco.html>
- ROS2 Jazzy Ubuntu binary requirements: <https://docs.ros.org/en/jazzy/Installation/Alternatives/Ubuntu-Install-Binary.html>
- Isaac Sim requirements: <https://docs.isaacsim.omniverse.nvidia.com/latest/installation/requirements.html>
- Doosan ROS2 repository: <https://github.com/DoosanRobotics/doosan-robot2>
- OpenArm project: <https://github.com/enactic/openarm>
- OpenArm ROS2 repository: <https://github.com/enactic/openarm_ros2>
- 로컬 참고 문서: `docs/[리버트론]OpenArm(AA-K1)_User Manual_한글판.pdf` (미추적, 배포 권한 확인 필요)
