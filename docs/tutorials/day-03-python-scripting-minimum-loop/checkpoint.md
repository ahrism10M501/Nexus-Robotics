# Day 3 체크포인트

## 통과 기준

Day 3을 통과하려면 공식 튜토리얼 code를 완성품처럼 복사하는 것이 아니라, lifecycle의 각 자리를
가리킬 수 있어야 합니다.

- `setup_scene`에서 world object를 만드는 위치를 찾을 수 있습니다.
- `setup_post_load`에서 load 이후 object handle이나 controller를 준비하는 위치를 찾을 수 있습니다.
- update loop가 simulation step과 함께 반복 실행되는 자리임을 설명할 수 있습니다.
- reset logic이 robot, cube, prop 같은 object를 known starting state로 되돌리는 이유를 설명할 수
  있습니다.
- 후속 실습의 deterministic task를 위해 scripted scene creation이 필요한 이유를 설명할 수 있습니다.

## 문제 해결 가이드

`Hello World`가 실행되지 않으면 먼저 공식 튜토리얼에서 extension flow를 선택했는지 standalone
flow를 선택했는지 확인합니다. 두 방식은 entry point와 실행 위치가 다릅니다. 하나를 골랐다면 그
방식의 file location, menu action, run command만 따라갑니다.

object가 보이지 않으면 `setup_scene`이 실제로 호출되는지 확인합니다. code를 수정했는데 stage가
이전 상태라면 reset 또는 reload가 필요할 수 있습니다. stage tree에서 prim path가 생겼는지도 같이
확인합니다.

robot이나 prop을 code에서 찾지 못하면 prim path와 object name을 봅니다. UI에서 자동 생성된 이름과
script에서 기대하는 이름이 다르면 handle lookup이 실패할 수 있습니다.

update loop가 조용하면 timeline Play 상태를 확인합니다. simulation이 멈춰 있으면 update callback도
움직이는 scene을 보여 주지 못합니다.

reset이 믿기지 않으면 reset 전후로 cube pose나 robot joint position을 관찰합니다. 같은 시작 상태로
돌아오지 않는 object가 있다면 나중에 dataset collection에서 문제를 만들 수 있습니다.

## Day 4로 넘어가기 전에

Day 3에서는 scene을 code로 다시 만들 수 있는 구조를 읽었습니다. Day 4에서는 그 scene에서 나오는
time과 camera observation을 ROS2 topic으로 내보냅니다. scriptable scene과 observation pipeline이
합쳐져야 나중에 episode data를 안정적으로 저장할 수 있습니다.
