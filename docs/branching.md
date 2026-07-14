# 브랜치 사용과 소유 경계

이 저장소의 장기 브랜치는 공통 기반을 재사용하되, 로봇별 runtime과 교육 자료를
서로 분리합니다.

```text
main
├── isaac-moveit
├── doosan-robotics
│   └── doosan-tutorial
└── open-arm
    └── openarm-tutorial
```

## 역할

| 브랜치 | 소유 범위 |
| --- | --- |
| `main` | ROS 2 Jazzy, Python, uv, core Docker/Compose, FastDDS, host Isaac DDS, 공통 튜토리얼 |
| `isaac-moveit` | vendor-neutral Isaac Sim과 MoveIt 통합 |
| `doosan-robotics` | Doosan 드라이버, 모델, emulator, 로봇별 MoveIt 설정 |
| `open-arm` | OpenArm 드라이버, CAN 안전 경계, 모델, 로봇별 MoveIt 설정 |
| `doosan-tutorial` | Doosan 전용 실습·예제 |
| `openarm-tutorial` | OpenArm 전용 실습·예제 |

`main`에는 robot SDK, robot model, CAN setup, vendor-specific MoveIt 설정을 넣지
않습니다. `isaac-moveit`에도 Doosan/OpenArm 드라이버나 로봇 asset을 넣지
않습니다. Tutorial 브랜치는 runtime을 수정하지 않습니다.

## 동기화

동기화는 부모에서 자식 방향으로만 수행합니다.

```text
main -> isaac-moveit
main -> doosan-robotics -> doosan-tutorial
main -> open-arm -> openarm-tutorial
```

공통 문제는 `main`에서, runtime 문제는 대응 robot 브랜치에서 먼저 고칩니다.
공개 브랜치는 rebase하지 않으며, 부모를 반영할 때 merge commit을 사용합니다.
로봇 브랜치끼리 직접 merge하거나 cherry-pick하지 않습니다.

## 안전한 사용

현재 작업을 보존하려면 브랜치마다 별도 worktree를 사용합니다.

```bash
git fetch origin
git worktree add ../nexus-isaac isaac-moveit
git worktree add ../nexus-doosan doosan-robotics
git worktree add ../nexus-openarm open-arm
```

하나의 깨끗한 worktree에서만 전환할 때는 다음을 사용합니다.

```bash
git switch <branch>
./run.sh init
./run.sh doctor
bash tests/run_all.bash --checks
```

현재 core PR이 병합되기 전에는 파생 브랜치가
`refactor/core-branch-layout`을 임시 공통 기반으로 사용합니다. 병합 뒤 그
commit이 `main`의 조상이 되므로 위 계층은 그대로 유지됩니다.

## 토폴로지 확인

```bash
# PR 병합 전
bash scripts/verify_branch_topology.bash refactor/core-branch-layout

# PR 병합 후
bash scripts/verify_branch_topology.bash
```
