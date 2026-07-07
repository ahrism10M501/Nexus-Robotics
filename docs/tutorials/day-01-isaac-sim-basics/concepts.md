# Day 1 개념

Day 1의 핵심은 Isaac Sim을 "멋진 3D 화면"이 아니라 robot experiment를 담는
구조로 보는 것입니다. 오늘은 아직 ROS2 command를 보내지 않습니다. 대신 stage
안에 object가 어떻게 놓이고, physics가 어떤 prim에만 적용되며, robot joint가
target을 받으면 어떻게 움직이는지 감을 잡습니다.

## Stage와 prim

`stage`는 지금 열려 있는 simulated world 전체입니다. 빈 stage를 만들면 아직
아무것도 없는 세계를 연 것이고, ground plane, cube, light, robot을 추가할수록
stage tree가 채워집니다.

`prim`은 stage tree 안의 한 node입니다. cube도 prim이고, robot도 prim이고,
robot 아래의 link나 visual mesh도 prim입니다. 초보자가 자주 놓치는 점은 화면에서
보이는 물체와 stage tree에서 선택해야 하는 prim이 항상 같지는 않다는 것입니다.
예를 들어 robot joint limit을 보려면 예쁜 mesh child가 아니라 articulation root
쪽을 선택해야 할 때가 많습니다.

이 구분은 나중에 script와 dataset에서 더 중요해집니다. script는
`/World/Cube` 같은 prim path로 object를 찾습니다. 오늘부터 stage tree에서
이름과 위치를 확인하는 습관을 들이면 Day 8의 deterministic cube-pick scene을
읽기가 훨씬 쉬워집니다.

## Rigid body와 collider

cube를 stage에 추가하면 처음에는 "보이는 cube"일 뿐입니다. gravity에 떨어지고
ground와 부딪히게 하려면 physics engine이 그 cube를 계산 대상으로 알아야 합니다.

`rigid body`는 이 prim이 physics simulation에서 움직일 수 있다는 뜻입니다.
`collider`는 contact 계산에 쓰는 shape입니다. rigid body만 있고 collider가
없으면 충돌을 계산할 표면이 없고, collider만 있고 원하는 physics 설정이 없으면
움직임이 기대와 다를 수 있습니다.

Day 1에서 cube가 ground 위로 떨어져 멈추는 장면은 작지만 중요한 첫 검증입니다.
Day 8에서 cube를 집으려면 cube가 단순한 visual object가 아니라 contact가 되는
physics object여야 하기 때문입니다.

## Articulation

`articulation`은 joint로 연결된 robot body입니다. mobile robot의 wheel joint,
manipulator arm의 shoulder/elbow/wrist joint처럼 여러 link가 연결된 구조를
하나의 physics-controlled robot으로 다룰 때 사용합니다.

robot을 stage에 추가한 뒤 Physics Inspector에서 joint를 보면 각 joint의 limit,
현재 position, drive target 같은 정보를 확인할 수 있습니다. 여기서 보는 숫자는
나중에 ROS2 controller, MoveIt2, learned policy가 모두 존중해야 하는 경계입니다.
"joint를 움직인다"는 말은 결국 articulation 안의 특정 joint drive에 target을
주는 일이라고 생각하면 됩니다.

## Action Graph

`Action Graph`는 Isaac Sim 안에서 node를 연결해 simulation event와 control flow를
만드는 visual dataflow graph입니다. Day 1에서는 Joint Position Action Graph 또는
Articulation Controller graph를 통해 joint target을 robot articulation에 보냅니다.

중요한 점은 graph가 simulation time과 함께 실행된다는 것입니다. graph가 있어도
timeline이 Play 상태가 아니면 target이 실제 motion으로 이어지지 않을 수 있습니다.
나중에 Day 2의 `/cmd_vel`, Day 4의 `/clock`과 camera publish도 같은 감각으로
debug합니다. topic이나 node 이름을 보기 전에 "graph가 ticking 중인가"를 먼저
묻게 됩니다.

## 오늘의 사고 모델

오늘의 흐름은 하나의 문장으로 정리할 수 있습니다.

Stage 안에 prim을 놓고, 필요한 prim에 rigid body와 collider를 붙이고, robot은
articulation으로 선택한 뒤, Action Graph가 simulation 중에 joint target을 보낸다.
