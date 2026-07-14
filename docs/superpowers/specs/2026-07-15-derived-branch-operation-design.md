# 파생 로봇 브랜치 운영 설계

작성일: 2026-07-15
상태: 구현 승인

## 목적

vendor-neutral core를 공통 기반으로 유지하면서 Isaac Sim + MoveIt, Doosan,
OpenArm 및 각 로봇의 튜토리얼을 독립적으로 발전시킨다. 로봇별 변경이
`main`에 역유입되어 core를 오염시키거나 서로 다른 vendor 브랜치가 직접 충돌하지
않도록 한다.

## 브랜치 계층

```text
main
├── isaac-moveit
├── doosan-robotics
│   └── doosan-tutorial
└── open-arm
    └── openarm-tutorial
```

`isaac-moveit`, `doosan-robotics`, `open-arm`은 모두 `main`의 형제다. 따라서
하드웨어 전용 사용자는 Isaac Sim 또는 MoveIt 의존성을 강제 설치하지 않는다.
각 tutorial 브랜치는 대응하는 robot 브랜치만 부모로 둔다.

## 소유 경계

| 브랜치 | 포함 | 제외 |
| --- | --- | --- |
| `main` | ROS 2 Jazzy, Python, uv, Docker, FastDDS, host Isaac DDS, Days 1-4 | robot SDK, robot model, MoveIt 설정, CAN 권한, Days 5-10 |
| `isaac-moveit` | vendor-neutral MoveIt/Isaac integration, simulation launch, generic planning examples | Doosan/OpenArm driver, robot-specific URDF/USD, hardware control |
| `doosan-robotics` | Doosan driver, model, emulator, robot-specific MoveIt/RViz/Gazebo profile | OpenArm code, tutorial course material |
| `open-arm` | OpenArm ROS/CAN integration, SocketCAN safety, robot-specific MoveIt/RViz profile | Doosan code, tutorial course material |
| `doosan-tutorial` | Doosan Days 5-10 and reproducible examples | shared runtime changes |
| `openarm-tutorial` | OpenArm Days 5-10 and reproducible examples | shared runtime changes |

## 동기화와 변경 경로

동기화는 부모에서 자식으로만 수행한다.

```text
main -> isaac-moveit
main -> doosan-robotics -> doosan-tutorial
main -> open-arm -> openarm-tutorial
```

- 공통 Docker, DDS, Python, 문서 인프라 수정은 `main` PR로 보낸다.
- generic Isaac/MoveIt 수정은 `isaac-moveit`에서 시작하고, 공통화가 필요할 때만
  `main`에 vendor-neutral interface를 별도 PR로 제안한다.
- 로봇 runtime 수정은 해당 robot 브랜치에서 시작한다.
- tutorial에서 발견한 runtime 결함은 tutorial에 임시 복제하지 않고 부모 robot
  브랜치에서 먼저 수정한다.
- 공개 브랜치는 rebase하거나 robot 브랜치끼리 merge하지 않는다. 부모 동기화는
  merge commit으로 수행한다.

## 부트스트랩

현재 core 변경은 `refactor/core-branch-layout` PR에 있으므로, 파생 브랜치는 그
최신 커밋에서 생성한다. 이 PR이 `main`에 병합되면 해당 commit이 `main`의 조상이
되어 브랜치 계층은 위 모델을 만족한다. PR 병합 전에는 `main`에서 직접 파생된
것처럼 표시하거나 core PR을 생략하지 않는다.

## 사용 계약

각 장기 브랜치에는 다음 문서가 있어야 한다.

1. `BRANCH.md`: 부모, 소유 범위, 금지 범위, 동기화 명령, 지원 등급.
2. `README.md`의 간단한 시작 경로: `init`, `doctor`, profile별 build/dev,
   no-hardware 검증.
3. hardware 동작이 있는 브랜치의 명시적 수동 HIL 절차와 안전 경고.

브랜치를 전환할 때는 사용자 변경이 없는 worktree에서 `git switch <branch>`를
사용한다. 병렬 사용은 `git worktree add`로 branch별 별도 worktree를 만든다.

## 완료 기준

- 여섯 브랜치 ref가 존재하며 올바른 직접 기반 commit을 가진다.
- 공통 기반의 정적 검사와 core runtime smoke가 통과한다.
- 각 브랜치에 `BRANCH.md`가 있고 그 역할·부모·안전한 다음 단계가 명시된다.
- tutorial leaf에는 대응 robot parent가 없으면 진행하지 않는 검증이 있다.
- 실제 Doosan/OpenArm 하드웨어 또는 CAN 송신은 자동 검증하지 않는다.
