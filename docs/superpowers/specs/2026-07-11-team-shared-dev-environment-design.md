# 팀 공유 ROS2 개발환경 설계

작성일: 2026-07-11

## 1. 목적

이 설계의 첫 번째 구현 사이클은 현재 개인 워크스테이션 중심의 ROS2 개발환경을
여러 연구원이 안전하고 반복 가능하게 사용할 수 있는 팀 공유 개발환경으로 바꾸는
것을 목표로 한다.

새 연구원은 Ubuntu 24.04 x86_64의 깨끗한 clone에서 문서만 보고 다음 흐름을 완료할
수 있어야 한다.

```text
clone
  -> ./run.sh init
  -> ./run.sh doctor
  -> CPU/headless 이미지 build
  -> 개발 container 시작
  -> ROS2 smoke test
  -> container 종료
```

컨테이너가 만든 workspace 파일은 호스트 사용자 소유로 남아야 하며, 기본 환경은
GPU, GUI, host PID/IPC/network, Docker socket 없이 실행되어야 한다.

## 2. 구현 사이클 경계

전체 작업은 서로 독립적인 세 사이클로 나눈다.

### 사이클 1: 팀 공유 개발환경

이번 명세와 다음 구현 계획의 범위다.

- Ubuntu 24.04 x86_64 공식 지원
- CPU/headless 기본 Docker 환경
- 선택형 NVIDIA GPU, X11, host DDS, Doosan, full profile
- 비루트 개발 사용자와 호스트 UID/GID 정합성
- Docker socket 격리
- 의존성 버전 고정과 lockfile
- `.dockerignore`, `.env.example`, host doctor
- clean-clone CI와 CPU/headless smoke test
- README, onboarding, tutorials, troubleshooting 문서 정합성

### 사이클 2: ROS 플랫폼 최소 골격

사이클 1 완료 후 별도 설계, 계획, 구현으로 진행한다.

- 공통 ROS interface
- robot core와 vendor adapter
- sim, dry-run, real bringup 모드
- 실행 가능한 safety gate
- 최소 policy runtime 경계

### 사이클 3: 학습 환경

사이클 2 완료 후 별도 설계, 계획, 구현으로 진행한다.

- ACT 학습 컨테이너
- VLA 학습 컨테이너
- world model 학습 컨테이너
- CUDA 및 핵심 Python import smoke test
- 공통 cache와 dataset mount 규칙

사이클 3은 학습 환경까지만 제공한다. 실제 모델 구현, 실제 학습 실행, 데이터셋 및
모델 registry, 디지털 트윈 asset pipeline, 실제 로봇 제어는 포함하지 않는다.

## 3. 지원 범위

### 공식 지원

- Ubuntu 24.04 LTS
- x86_64
- Docker Engine과 Docker Compose v2
- CPU/headless ROS2 개발
- 선택형 NVIDIA GPU와 NVIDIA Container Toolkit
- 선택형 X11 GUI
- host에 설치된 Isaac Sim과 ROS2 Bridge

### 이번 사이클의 명시적 비지원

- macOS와 Windows Docker Desktop
- WSL2
- Wayland native GUI 연결
- SSH 원격 GUI 자동 설정
- ARM64
- 실제 로봇 learned-policy 실행

비지원 환경은 동작을 의도적으로 막는다는 뜻이 아니라, CI와 온보딩 완료 기준에
포함하지 않는다는 뜻이다.

## 4. 선택한 접근법

현재 Dockerfile과 Compose 설정을 단순 보완하는 방식 대신 계층형 Docker build와
선택형 Compose override를 사용한다.

이 방식을 선택한 이유는 다음과 같다.

- CPU/headless 기본 경로와 GPU/GUI 경로를 분리할 수 있다.
- Docker socket과 host namespace를 필요한 서비스에만 제한할 수 있다.
- Doosan, Isaac ROS, 향후 학습 이미지를 공통 기반 위에 추가할 수 있다.
- 동일한 설치 로직의 Dockerfile 복제를 줄일 수 있다.
- CI는 작은 기반 target만 검증하고, 무거운 target은 수동으로 분리할 수 있다.

## 5. 컨테이너 아키텍처

### 5.1 Build target

공통 Docker build 정의는 repository root의 단일 `Dockerfile`에 재사용 가능한 named
target으로 구성한다.

```text
ros-base
  -> ros-dev
      +-> ros-ai-dev
      +-> doosan-dev
            -> full-dev
```

- `ros-base`: 고정된 ROS2 Jazzy 기반과 공통 runtime 설정
- `ros-dev`: colcon, rosdep, vcstool, compiler, 개발 도구
- `ros-ai-dev`: 현재 개발환경이 제공하던 기본 AI Python 의존성
- `doosan-dev`: 고정된 Doosan source와 MoveIt/Gazebo/RViz 의존성
- `full-dev`: `doosan-dev`에 공통 AI 설치 script와 Isaac ROS workspace를 더한 조합

공통 apt, AI Python, Doosan 및 Isaac 설치 절차는 `docker/` 아래의 목적별 script로
분리하고 named target에서 호출한다. 현재 `Dockerfile.doosan`과
`Dockerfile.isaac-moveit`의 기능을 단일 `Dockerfile` target으로 옮긴 뒤 동등한 build
구성이 검증되면 두 legacy Dockerfile은 제거한다.

Compose service와 build target은 다음처럼 고정한다.

- `ros2_dev` -> `ros-dev`
- `ai_dev` -> `ros-ai-dev`
- `doosan_dev` -> `doosan-dev`
- `full_dev` -> `full-dev`

따라서 기본 `ros2_dev`는 PyTorch 같은 AI package를 포함하지 않는 작은 ROS 개발환경이다.
현재 기본 이미지가 제공하던 AI package가 필요한 사용자는 `ai_dev` preset을 사용하며,
사이클 3에서는 이를 ACT, VLA, world-model 전용 학습 target으로 더 세분화한다.

### 5.2 Compose 기본 원칙

기본 `compose.yml`은 CPU/headless 개발에 필요한 최소 권한만 갖는다.

- GPU 요청 없음
- X11 socket mount 없음
- host network 없음
- host PID와 IPC 없음
- Docker socket 없음
- 고정 `container_name` 없음
- 비루트 사용자
- repository의 `/workspace` bind mount

선택 기능은 독립된 override로 조합한다.

- GPU override: NVIDIA GPU와 최소 driver capability
- GUI override: X11 display와 제한된 인증 정보
- host DDS override: host Isaac Sim과 multicast DDS 통신
- Doosan profile: Doosan 개발 target
- full profile: GPU, GUI, host DDS, Isaac ROS workspace, Doosan target
- emulator profile: vendor emulator lifecycle

### 5.3 Emulator 격리

Doosan 개발 컨테이너와 VS Code Dev Container에는 Docker socket을 연결하지 않는다.

우선순위는 다음과 같다.

1. 고정된 emulator image를 별도 Compose service로 실행한다.
2. 벤더 bootstrap이 host Docker API를 반드시 요구하면 socket은 명시적인
   `trusted-emulator-bootstrap` 일회성 서비스에만 연결한다.
3. 해당 서비스는 기본 `up`, Dev Container 시작, CI에서 자동 실행되지 않는다.
4. 실행 전 trusted-code 전용이라는 보안 경고와 명시적 확인 명령을 문서화한다.

Docker socket을 read-only로 mount하는 것은 Docker API 권한을 제한하지 못하므로 보안
대책으로 간주하지 않는다.

## 6. 사용자와 파일 권한

모든 개발 target은 이미지 build 중에만 root를 사용하고 runtime은 `developer` 사용자로
실행한다.

- `.env`에 호스트 UID와 GID를 기록한다.
- build argument 또는 runtime mapping으로 `developer`의 UID/GID를 맞춘다.
- home directory는 `/home/developer`를 사용한다.
- workspace build output과 편집 파일은 호스트 사용자 소유로 남는다.
- Python, Hugging Face, compiler cache는 사용자 쓰기 가능한 위치를 사용한다.
- Dev Container의 `remoteUser`도 동일한 비루트 사용자를 사용한다.

## 7. 네트워크와 ROS 격리

일반 `dev` 환경은 Compose 기본 network를 사용한다. Host Isaac Sim과 DDS discovery가
필요한 preset에만 host DDS override를 적용한다.

`ROS_DOMAIN_ID`와 Compose project name은 연구원 로컬 설정으로 관리한다.

- `.env.example`은 값의 의미와 유효 범위를 설명한다.
- `./run.sh init`은 로컬 값을 생성하되 기존 `.env`를 덮어쓰지 않는다.
- `./run.sh doctor`는 누락, 유효하지 않은 domain, 공유 기본값 사용을 구분한다.
- tutorials는 일반 container와 Isaac Bridge container 명령을 구분한다.
- 같은 LAN에서 domain을 공유하면 다른 실험이나 로봇 graph가 보일 수 있음을 경고한다.

## 8. GPU와 GUI

### GPU

CPU/headless 환경은 NVIDIA runtime이 없어도 시작되어야 한다. GPU preset을 선택한 경우에만
다음을 검사한다.

- NVIDIA GPU 존재
- host driver 응답
- NVIDIA Container Toolkit 동작
- container GPU 접근
- 필요한 Python runtime의 CUDA 접근

### X11

`xhost +local:root`는 사용하지 않는다. GUI preset은 비루트 사용자에게만 제한된 X11
인증을 준비한다.

- Xauthority 또는 동일 UID 기반의 제한된 권한을 사용한다.
- X11 socket은 read-only로 mount한다.
- 준비와 회수는 helper가 반복 실행 가능하게 처리한다.
- 실패 시 남은 권한이나 임시 인증 파일을 정리한다.
- Wayland, SSH, headless 환경에서는 명시적인 오류와 대체 경로를 안내한다.

## 9. 버전과 재현성

이번 사이클은 소스에서 실용적으로 재현 가능한 수준을 목표로 한다.

- ROS base image를 immutable digest로 고정
- `uv` 설치 버전과 다운로드 검증 고정
- Python 의존성을 lockfile과 hash로 고정
- Doosan repository를 full commit SHA로 고정
- Isaac ROS workspace를 full commit SHA로 고정
- build metadata에 repository commit, upstream SHA, dependency version 기록
- `.dockerignore`로 local data와 secret을 build context에서 제외

Ubuntu와 ROS apt repository 자체의 장기 snapshot 문제는 immutable prebuilt image 배포가
추가되어야 완전히 해결된다. 사이클 1에서는 lock과 image metadata를 제공하고, registry
publish와 image signing은 후속 배포 작업으로 남긴다.

## 10. 명령 인터페이스

### 초기화와 진단

- `./run.sh init`: `.env` 생성과 로컬 UID/GID/project/domain 설정
- `./run.sh doctor`: CPU/headless 필수 조건 검사
- `./run.sh doctor gpu`: NVIDIA 조건 추가 검사
- `./run.sh doctor gui`: X11 조건 추가 검사
- `./run.sh doctor full`: GPU, GUI, Isaac, Doosan 조건 검사

### 개발 preset

- `./run.sh dev`: CPU/headless 기본 환경
- `./run.sh isaac-dev`: CPU/headless + host DDS
- `./run.sh gui-dev`: GUI + host DDS
- `./run.sh ai-dev`: 기본 AI package를 포함한 CPU/headless 환경
- `./run.sh gpu-dev`: AI package + GPU + host DDS
- `./run.sh isaac-gui-dev`: GUI + host DDS의 명시적 Isaac tutorial preset
- `./run.sh doosan-dev`: Doosan 개발 preset
- `./run.sh full-dev`: GPU + GUI + host DDS + Isaac ROS + Doosan preset

현재 공개된 `build`, `up`, `shell`, `dev`, `workspace-build`, `doosan-*`, `full-*`,
`status`, `down` command는 유지한다. `moveit-*` legacy command도 기존처럼 대응하는
`full-*` command의 alias로 유지한다. 이번 사이클에서 기존 공개 command를 제거하지
않으며, tutorials는 위에 정의한 새 canonical preset 이름을 사용한다.

### Lifecycle

- `build`, `up`, `shell`, `status`, `down`은 선택된 preset에 일관되게 동작한다.
- `.env`가 없으면 `help`, `init`, 정적 검사를 제외한 명령은 `init` 안내와 함께 실패한다.
- `init`과 `down`은 반복 실행 가능하다.
- 사용자 data와 기존 `.env`를 자동 삭제하거나 덮어쓰지 않는다.

## 11. 오류 처리

`doctor`와 `run.sh`는 실패를 다음처럼 분류한다.

- 필수 조건 실패: 선택한 preset을 실행할 수 없으며 non-zero로 종료
- 선택 기능 경고: 기본 환경은 실행 가능하지만 특정 기능이 비활성
- 보안 경고: host network, emulator bootstrap처럼 격리를 약화하는 기능
- 상태 안내: 이미 생성된 `.env`, 실행 중인 service, 기존 build output

각 오류에는 다음 정보를 포함한다.

- 실패한 검사 이름
- 실제로 관찰된 값
- 기대 조건
- 사용자가 실행할 수 있는 해결 명령 또는 관련 문서 링크

secret 값과 인증 정보는 로그에 출력하지 않는다.

## 12. 문서 설계

README는 온보딩 허브로 유지하되 첫 사용자 경로를 다음 순서로 바꾼다.

```text
지원 범위
  -> 사전 요구사항
  -> clone
  -> init
  -> doctor
  -> quickstart
  -> smoke test
  -> tutorials
```

`docs/onboarding/`에 다음 문서를 둔다.

- `README.md`: canonical onboarding index
- `supported-platforms.md`: 공식 지원과 비지원 환경
- `prerequisites.md`: Docker, Compose, GPU, X11, Isaac, disk 요구사항
- `quickstart.md`: clean-clone 첫 성공 경로
- `profiles.md`: preset과 권한 차이
- `security.md`: Docker socket, host network, X11, ROS DDS 위험
- `updates-and-cleanup.md`: rebuild, cache, image, local artifact 관리
- `troubleshooting.md`: 첫 실행, 권한, GPU, GUI, build 문제

기존 tutorials는 다음 원칙으로 수정한다.

- `/home/ahrism/...` 절대경로 제거
- `$REPO_ROOT` 또는 repository root 기준 사용
- host와 container 명령을 명시적으로 구분
- 필요한 preset을 Day 시작 부분에 표시
- 새 `init`, `doctor`, profile command와 일치
- Day 4의 잘못된 다음 링크 수정
- 존재하지 않는 `isaac/` 구조 안내 제거 또는 실제 구조와 일치
- 내부 구현계획 문서를 beginner navigation에서 제거
- 실행 구현이 없는 Day 7-9는 설계 실습임을 표시
- 실제 학습과 실제 로봇 실행은 현재 범위가 아님을 유지

저장소 LICENSE 선택은 법적·조직적 결정이므로 이번 자동 수정에서 선택하지 않는다.
대신 외부 image, source, package, USD asset의 출처와 버전을 기록할 위치와 규칙을
문서화한다.

## 13. 검증 전략

### 13.1 Test-first 원칙

구현은 현재 문제를 재현하는 검사부터 추가하고, 실패를 확인한 뒤 설정과 스크립트를
수정한다.

### 13.2 정적 검사

- 모든 shell script의 `bash -n`
- ShellCheck
- 모든 Compose 조합의 `docker compose config`
- Dev Container JSON과 FastDDS XML parsing
- local Markdown link 검사
- 개인 절대경로 금지
- 일반 service의 root, 고정 container name, Docker socket, host PID/IPC 금지
- version manifest와 lockfile 존재 및 정합성

### 13.3 Script test

실제 host 상태를 변경하지 않도록 fake `docker`, `xauth`, GPU command를 PATH 앞에 배치해
다음을 검증한다.

- `init` 첫 실행과 재실행
- 기존 `.env` 비덮어쓰기
- 잘못된 ROS domain 거부
- profile별 doctor 성공과 실패
- Docker daemon 미실행 오류
- GPU, X11, Isaac 선택 조건 오류
- `up`, `down` command 조합
- 실패 시 GUI 인증 정리

### 13.4 Container smoke test

- CPU/headless image build
- runtime UID가 0이 아님
- ROS environment source
- `ros2` CLI 실행
- workspace 읽기/쓰기와 host file ownership
- 최소 ROS topic pub/sub 통신

### 13.5 CI

GitHub Actions는 PR과 push마다 다음을 실행한다.

- clean checkout에서 정적 검사
- CPU/headless target build
- CPU/headless container smoke test
- tutorial 및 onboarding link/command consistency 검사

Doosan과 full image는 기본 CI의 시간과 저장공간 부담이 크므로 Compose/Dockerfile 정적
검사만 수행하고 수동 workflow에서 전체 build할 수 있게 한다. GPU, X11, Isaac Bridge는
GPU 워크스테이션에서 profile doctor와 수동 smoke test로 검증한다.

## 14. 완료 기준

사이클 1은 다음 조건을 모두 만족해야 완료다.

1. Ubuntu 24.04 x86_64의 깨끗한 clone에서 문서 순서대로 시작할 수 있다.
2. NVIDIA runtime 없이 CPU/headless 개발환경을 build하고 실행할 수 있다.
3. 기본 container는 비루트이며 host 파일 소유권을 훼손하지 않는다.
4. 기본 container에는 Docker socket, host PID/IPC/network, GPU, X11이 없다.
5. 선택 preset만 필요한 권한과 장치를 추가한다.
6. 일반 Doosan/full 개발 container에는 Docker socket이 없다.
7. version과 source ref가 고정되고 정적 검사가 이를 확인한다.
8. CI가 clean checkout의 구성, CPU image build, ROS smoke test를 검증한다.
9. README와 tutorials가 실제 command 및 profile과 일치한다.
10. 개인 절대경로가 canonical onboarding과 tutorials에 남아 있지 않다.
11. 이미지 build, GPU, GUI, Isaac, emulator의 미검증 범위를 문서가 구분한다.
12. 실제 학습, 디지털 트윈 asset, 실제 로봇 제어를 완료했다고 주장하지 않는다.

## 15. 변경 안전성

현재 작업트리에는 사용자가 만든 미커밋 Docker, Compose, tutorial 변경이 존재한다.
구현은 이를 기준으로 진행하며 unrelated 변경을 되돌리지 않는다.

- 구현 전 현재 diff를 보존한다.
- 파일 삭제나 통합이 필요한 경우 같은 기능이 새 구조에 보존되는지 검증한다.
- 사용자 data, checkpoint, `.env`는 수정하지 않는다.
- 구현 커밋은 논리적 단위로 제한하고 사용자 변경과 무관한 파일을 포함하지 않는다.
