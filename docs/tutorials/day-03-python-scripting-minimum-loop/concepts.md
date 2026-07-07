# Day 3 개념

Day 1과 Day 2에서는 이미 준비된 scene과 UI graph를 많이 사용했습니다. Day 3에서는 같은
생각을 Python으로 옮깁니다. 목표는 Python expert가 되는 것이 아니라, Isaac Sim scene을
반복 가능한 experiment로 만드는 최소 구조를 읽는 것입니다.

## Scripted scene creation이 중요한 이유

손으로 만든 scene은 배우기 좋습니다. 하지만 dataset을 모으거나 policy를 비교할 때는
"방금 손으로 조금 다르게 놓은 cube"가 문제가 됩니다. Day 8의 deterministic cube-pick에서는
cube, table, robot, camera가 reset할 때마다 같은 위치와 이름으로 다시 준비되어야 합니다.

scripted scene creation은 이 반복성을 줍니다. code가 ground plane을 만들고, robot을 추가하고,
cube를 같은 prim path와 pose로 놓으면 episode마다 시작 조건을 확인할 수 있습니다. 나중에
policy가 실패했을 때도 scene이 달랐는지 action이 나빴는지 구분하기 쉬워집니다.

## setup_scene

`setup_scene`은 world를 구성하는 곳입니다. ground plane, robot, cube, prop처럼 stage에
존재해야 하는 object를 여기에서 추가합니다.

초보자에게 중요한 기준은 "이 object가 reset 후에도 scene의 기본 구성으로 있어야 하는가"입니다.
그렇다면 대개 `setup_scene`의 책임입니다. 예를 들어 Day 8의 `/World/Cube`는 episode마다
필요한 task object이므로 code에서 명시적으로 만들거나 reference해야 합니다.

## setup_post_load

`setup_post_load`는 stage가 load되고 object들이 실제로 준비된 뒤, code가 그 object를 잡아
오는 곳입니다. scene을 만든 직후에는 아직 runtime handle이 필요한 경우가 있습니다. robot
object를 변수에 연결하거나, controller를 준비하거나, callback을 등록하는 일이 여기에 들어갑니다.

`setup_scene`이 "무엇을 world에 둘 것인가"라면, `setup_post_load`는 "이제 준비된 object를
code가 어떻게 사용할 것인가"에 가깝습니다.

## Update loop

update loop는 simulation이 진행되는 동안 반복해서 실행되는 code입니다. robot pose를 읽거나,
간단한 command를 보내거나, time step마다 상태를 관찰하는 일이 여기에 들어갑니다.

Day 3에서는 복잡한 policy logic을 넣지 않습니다. 대신 update loop가 "simulation이 한 step씩
진행될 때 내 code도 같이 호출되는 자리"라는 점을 확인합니다. 이 감각은 Day 9에서 observation과
action을 episode 단위로 저장할 때 다시 쓰입니다.

## Reset

reset은 scene을 알려진 시작 상태로 되돌리는 일입니다. 초보자에게 reset은 "다시 실행"처럼
보일 수 있지만, robotics experiment에서는 더 엄격한 의미를 갖습니다. robot joint, cube pose,
controller state, simulation time이 예상 가능한 상태로 돌아와야 합니다.

Day 8 deterministic cube-pick에서는 reset이 특히 중요합니다. cube 위치가 매번 다르면 pick
sequence가 실패해도 script가 나쁜지 scene이 바뀐 것인지 알 수 없습니다. Day 3의 reset 개념은
나중에 dataset 품질을 지키는 첫 장치입니다.

## 오늘의 사고 모델

`setup_scene`에서 world를 만들고, `setup_post_load`에서 runtime handle을 연결하고, update
loop에서 simulation step마다 관찰하거나 움직이고, reset으로 known starting state에 돌아갑니다.
