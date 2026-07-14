# Day 1 실습

## 오늘 만들 것

작은 Isaac Sim scene을 만듭니다. 새 stage에 ground plane, light, cube를 놓고,
cube가 gravity로 떨어져 ground 위에 멈추도록 physics를 붙입니다. 그 다음 built-in
robot을 추가해 joint를 inspect하고, Action Graph에서 joint target을 바꿔 robot의
한 joint가 움직이는지 확인합니다.

## 공식 튜토리얼 흐름

오늘은 아래 두 공식 흐름을 짧게 이어 붙입니다.

- NVIDIA Isaac Sim Basic Usage Tutorial:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/introduction/quickstart_isaacsim.html
- NVIDIA Basic Robot Tutorial:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/introduction/quickstart_isaacsim_robot.html

`Basic Usage`에서는 Isaac Sim을 열고 stage에 기본 object를 놓는 감각을 가져옵니다.
`Basic Robot`에서는 robot을 추가하고 joint target을 바꾸는 흐름만 가져옵니다.

## 시작하기 전에

Isaac Sim은 host에서 실행합니다. repo root에서 아래 command를 실행해 시작합니다.

```bash
cd "$REPO_ROOT"
./scripts/launch_isaac_sim.sh
```

오늘은 ROS2 container command가 필요하지 않습니다. Isaac Sim UI 안에서 stage tree,
viewport, Physics Inspector, Action Graph를 오가며 작업합니다.

## 1단계: 새 stage 열기

Isaac Sim이 열리면 새 stage를 만듭니다. 이 stage가 오늘의 simulated world입니다.
처음에는 거의 비어 있지만, 이후에 추가하는 ground plane, light, cube, robot이 모두
stage tree 아래에 prim으로 나타납니다.

stage tree를 계속 열어 둡니다. 초보자에게 가장 좋은 습관은 viewport에서 object를
보는 것과 stage tree에서 해당 prim을 찾는 일을 같이 하는 것입니다. 나중에 script가
`/World/Cube` 같은 prim path를 사용하기 때문에, 오늘부터 이름과 hierarchy를 보는
연습을 합니다.

## 2단계: ground plane, light, cube 추가하기

`Basic Usage` 흐름을 따라 ground plane과 light를 추가합니다. ground plane은 cube가
떨어져 멈출 기준면이고, light는 viewport에서 object를 보기 위한 기본 조명입니다.

그 다음 cube를 하나 추가합니다. cube를 선택한 뒤 stage tree에서 cube prim의 이름을
확인합니다. 이름이 자동으로 `Cube` 또는 비슷한 값으로 만들어질 수 있습니다. 오늘은
이름 자체보다 "보이는 cube는 stage tree의 prim 하나로 관리된다"는 감각이 중요합니다.

## 3단계: cube를 physics object로 만들기

cube가 그냥 떠 있는 visual object로 끝나지 않게 physics 설정을 붙입니다. cube prim을
선택하고 rigid body, collider, mass를 추가합니다.

이 단계에서 의미를 같이 확인합니다.

- `rigid body`: cube가 gravity와 velocity의 영향을 받는 body가 됩니다.
- `collider`: physics engine이 contact를 계산할 shape를 갖습니다.
- `mass`: contact와 motion 계산에 사용할 물리량을 갖습니다.

timeline에서 Play를 누릅니다. cube가 아래로 떨어져 ground plane 위에 멈추면 성공입니다.
떨어지는 중에 cube가 ground를 통과한다면 collider 또는 ground physics 설정을 다시
확인합니다.

## 4단계: built-in robot 추가하기

`Basic Robot` 흐름을 따라 built-in robot을 stage에 추가합니다. 어떤 sample robot을
쓰더라도 오늘의 목표는 같습니다. robot이 stage tree에 하나의 큰 prim으로 들어오고,
그 아래에 link, mesh, joint 관련 prim이 이어지는 구조를 봅니다.

robot을 선택할 때는 viewport의 겉모습만 보지 말고 stage tree의 root 쪽 prim을
확인합니다. articulation을 inspect하려면 visual mesh child가 아니라 robot
articulation을 대표하는 prim을 선택해야 하는 경우가 많습니다.

## 5단계: articulation joint 확인하기

Physics Inspector를 열고 robot articulation의 joints를 봅니다. 각 joint의 현재
position, limit, drive target 같은 값을 확인합니다.

여기서 joint limit은 단순한 참고 숫자가 아닙니다. controller나 script가 target을
보낼 때 안전하게 움직일 수 있는 범위를 알려 주는 계약에 가깝습니다. 후속 로봇
튜토리얼 브랜치에서 manipulator를 다룰 때도 joint limit을 무시한 command는 대부분
좋은 debug 출발점이 아닙니다.

## 6단계: Action Graph로 joint target 하나 바꾸기

Joint Position Action Graph 또는 Articulation Controller graph를 만듭니다. graph의
대상 articulation이 방금 추가한 robot을 가리키는지 확인합니다.

timeline이 Play 상태일 때 joint target 값을 작게 바꿉니다. 처음에는 큰 값을 넣지
말고, joint limit 안쪽에서 눈으로 확인 가능한 작은 motion만 시도합니다. robot의 한
joint가 target을 따라 움직이면 오늘 필요한 Action Graph 감각을 얻은 것입니다.

이 단계의 핵심은 "graph node가 target 값을 만들고, Articulation Controller가 그 값을
robot joint drive에 보낸다"는 흐름입니다. Day 2에서는 이 target의 출처가 ROS2
`/cmd_vel` message로 바뀌고, Day 4에서는 graph가 `/clock`과 camera data를 publish하는
쪽으로 바뀝니다.

## 확인하기

아래 세 가지를 직접 확인합니다.

- cube가 Play 중에 gravity로 떨어지고 ground 위에 멈춥니다.
- Physics Inspector에서 robot articulation의 joint와 limit을 볼 수 있습니다.
- Action Graph에서 joint target을 바꾸면 robot의 joint 하나가 움직입니다.

## 막혔을 때

cube가 움직이지 않으면 timeline이 Play 상태인지 먼저 확인합니다. 그 다음 cube prim에
rigid body, collider, mass가 모두 붙어 있는지 봅니다. 화면의 cube mesh child를 선택한
상태로 설정을 붙였는지도 stage tree에서 다시 확인합니다.

joint가 보이지 않으면 robot의 visual mesh child가 아니라 articulation root에 가까운
prim을 선택했는지 확인합니다. Physics Inspector가 어떤 prim을 보고 있는지가 중요합니다.

joint target을 바꿔도 robot이 움직이지 않으면 graph의 articulation target path,
timeline Play 상태, joint target 값이 limit 안에 있는지 확인합니다. target을 너무 크게
넣어 debug하지 말고 작은 값으로 다시 시도합니다.

## 오늘 배운 것

Isaac Sim scene은 stage이고, stage 안의 object는 prim입니다. cube처럼 physics가 필요한
prim에는 rigid body와 collider가 필요합니다. robot은 articulation으로 다루며, Action
Graph가 simulation 중에 joint target을 보내면 joint motion이 만들어집니다.
