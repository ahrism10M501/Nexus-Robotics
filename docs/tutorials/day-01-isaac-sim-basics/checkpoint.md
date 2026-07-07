# Day 1 체크포인트

## 통과 기준

Day 1을 통과하려면 결과 화면만 있으면 안 됩니다. 아래 내용을 자기 말로 설명하고 다시
재현할 수 있어야 합니다.

- 새 stage를 만들고 ground plane, light, cube를 추가할 수 있습니다.
- cube prim에 rigid body, collider, mass를 붙여 gravity로 떨어지게 만들 수 있습니다.
- robot articulation을 선택해 Physics Inspector에서 joint와 joint limit을 찾을 수
  있습니다.
- Action Graph 또는 Articulation Controller graph에서 joint target을 작게 바꿔 실제
  joint motion을 만들 수 있습니다.

## 문제 해결 가이드

cube가 떨어지지 않으면 먼저 Play 상태를 확인합니다. Isaac Sim에서는 object를 만들었다고
physics가 자동으로 진행되지 않습니다. Play 중인데도 cube가 움직이지 않으면 cube prim에
rigid body가 붙었는지, contact를 위한 collider가 있는지, mass가 설정되어 있는지 봅니다.

cube가 ground를 통과하면 collider 쪽을 의심합니다. 화면에 보이는 mesh와 physics collider는
다른 개념입니다. ground plane도 physics contact를 받을 수 있는 상태인지 확인합니다.

Physics Inspector에 joint가 보이지 않으면 선택한 prim이 너무 아래쪽 visual mesh일 가능성이
큽니다. stage tree에서 robot root 또는 articulation root에 가까운 prim을 선택하고 다시
확인합니다.

joint target을 바꿔도 움직임이 없다면 graph가 robot articulation을 올바르게 가리키는지,
timeline이 Play 상태인지, target 값이 joint limit 안에 있는지 확인합니다. 처음 debug할 때는
큰 target 대신 작은 target을 쓰는 것이 좋습니다.

## Day 2로 넘어가기 전에

Day 2로 넘어가기 전에 한 가지만 분명히 기억하세요. Isaac Sim에서 robot이 움직이려면
무언가가 articulation joint drive에 target을 보내야 합니다. Day 1에서는 그 출처가 Action
Graph의 직접 입력이었고, Day 2에서는 ROS2 `/cmd_vel` message가 mobile robot control graph의
입력이 됩니다.
