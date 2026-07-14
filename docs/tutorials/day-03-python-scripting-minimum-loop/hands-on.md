# Day 3 실습

## 오늘 만들 것

공식 Isaac Sim Python tutorial을 따라 작은 scene을 code로 만듭니다. ground plane을 만들고,
robot을 추가하고, cube 또는 prop을 놓은 뒤, script 안에서 `setup_scene`, `setup_post_load`,
update loop, reset logic이 각각 어디에 있는지 표시합니다.

## 공식 튜토리얼 흐름

오늘은 아래 세 공식 튜토리얼을 순서대로 얕게 연결합니다.

- Hello World:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/core_api_tutorials/tutorial_core_hello_world.html
- Hello Robot:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/core_api_tutorials/tutorial_core_hello_robot.html
- Adding Props:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/core_api_tutorials/tutorial_core_adding_props.html

`Hello World`에서 lifecycle을 보고, `Hello Robot`에서 robot object를 code로 다루는 흐름을 보고,
`Adding Props`에서 cube나 prop을 scene에 추가하는 방식을 봅니다.

## 시작하기 전에

Isaac Sim은 host에서 실행합니다.

```bash
cd "$REPO_ROOT"
./scripts/launch_isaac_sim.sh
```

오늘은 container에서 ROS2 topic을 publish하지 않습니다. Isaac Sim의 Python tutorial을 따라
extension workflow 또는 standalone workflow 중 하나를 선택합니다. 둘을 동시에 섞으면 초보자
debug가 어려워지므로, 공식 `Hello World` page에서 선택한 방식 하나로 끝까지 진행합니다.

## 1단계: Hello World 흐름 실행하기

공식 `Hello World` tutorial을 열고 예제가 정상 실행되는지 확인합니다. 목표는 코드를 전부 외우는
것이 아니라, Isaac Sim Python tutorial이 어떤 lifecycle로 scene을 준비하는지 보는 것입니다.

예제가 실행되면 stage에 기본 object가 나타나는지 확인합니다. 이때 "UI로 object를 놓은 것"과
"code가 object를 만든 것"을 구분해 봅니다. Day 3에서는 code가 다시 실행되면 같은 object를 다시
만들 수 있다는 점이 중요합니다.

## 2단계: setup_scene 찾기

script에서 `setup_scene`을 찾습니다. 이 함수 또는 method 안에서 world에 object를 추가하는 부분을
읽습니다. ground plane을 추가하는 code가 있다면 그 줄을 먼저 찾습니다.

이제 Day 1의 stage/prim 개념을 다시 연결합니다. `setup_scene`에서 object를 추가한다는 것은 stage
tree에 prim을 만들거나 asset reference를 추가한다는 뜻입니다. 후속 실습에서는 table, cube,
camera, robot이 모두 이런 방식으로 준비되어야 deterministic reset이 쉬워집니다.

## 3단계: Python에서 robot 추가하기

공식 `Hello Robot` 흐름을 따라 Jetbot 같은 sample robot을 Python에서 추가하는 부분을 확인합니다.
robot이 stage에 나타나면 stage tree에서 robot prim path를 봅니다.

여기서 중요한 질문은 하나입니다. "이 robot을 나중에 code가 다시 찾을 수 있는가?" robot prim path가
예측 가능해야 controller나 reset code가 같은 대상을 안정적으로 잡을 수 있습니다.

## 4단계: cube 또는 prop 추가하기

공식 `Adding Props` 흐름을 따라 cube 또는 prop을 scene에 추가합니다. 가능하면 이름과 pose가 code에
명시된 object를 사용합니다.

cube나 prop은 후속 task object를 위한 작은 예고편입니다. cube-pick에서는 cube가 매번 같은
초기 pose로 만들어져야 scripted pick sequence가 같은 조건에서 실행됩니다. 오늘은 prop 하나라도
code로 만들고 stage tree에서 prim path를 확인하는 것이 목표입니다.

## 5단계: setup_post_load 찾기

script에서 `setup_post_load`를 찾습니다. scene이 load된 뒤 object handle을 가져오거나 controller,
callback, state variable을 준비하는 code가 있는지 봅니다.

`setup_scene`과 헷갈리지 않도록 역할을 나눠 생각합니다. `setup_scene`은 object를 world에 놓는
곳이고, `setup_post_load`는 이미 load된 object를 code가 사용할 준비를 하는 곳입니다.

## 6단계: update loop와 reset logic 찾기

simulation이 진행되는 동안 반복 호출되는 update loop를 찾습니다. tutorial에 따라 callback 이름이
다르게 보일 수 있지만, 핵심은 simulation step마다 code가 실행되는 자리입니다.

그 다음 reset logic을 찾습니다. reset은 scene을 known starting state로 되돌리는 code입니다. 오늘은
복잡한 reset을 직접 구현하지 않아도 됩니다. 대신 "어디에서 reset이 호출되고, 어떤 object state가
초기화되는가"를 읽습니다.

## 확인하기

아래 내용을 확인합니다.

- `setup_scene`에서 ground plane, robot, cube 또는 prop을 추가하는 위치를 찾았습니다.
- `setup_post_load`에서 load된 object를 code가 다시 잡는 위치를 찾았습니다.
- simulation 중 반복 실행되는 update loop 위치를 찾았습니다.
- reset logic이 scene을 known starting state로 되돌리는 이유를 설명할 수 있습니다.
- scripted scene creation이 후속 deterministic task에 필요한 이유를 설명할 수 있습니다.

## 막혔을 때

example이 실행되지 않으면 extension workflow와 standalone workflow를 섞지 않았는지 확인합니다.
공식 `Hello World` page에서 선택한 방식 하나만 따라갑니다.

object가 stage에 나타나지 않으면 object creation code가 `setup_scene` 안에 있는지, stage가 reload
또는 reset되었는지 확인합니다. code를 수정한 뒤에도 이전 stage 상태만 보고 있을 수 있습니다.

update loop가 실행되지 않는 것 같으면 timeline이 Play 상태인지 확인합니다. simulation step이
진행되지 않으면 update callback도 기대한 방식으로 호출되지 않습니다.

reset 후 object 위치가 예상과 다르면 reset이 어떤 object state를 초기화하는지 읽습니다. pose,
velocity, controller state가 모두 같은 곳에서 초기화된다고 가정하지 말고 code를 따라갑니다.

## 오늘 배운 것

Isaac Sim scene은 UI로만 만들 필요가 없습니다. `setup_scene`은 world를 만들고,
`setup_post_load`는 load된 object를 code와 연결하며, update loop는 simulation step마다 실행되고,
reset은 experiment를 known starting state로 되돌립니다. 이 구조가 후속 deterministic task의
기초입니다.
