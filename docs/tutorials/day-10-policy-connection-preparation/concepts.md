# Day 10 개념

Day 10은 policy training 날이 아닙니다. ACT나 Diffusion Policy를 구현하지도 않습니다.
오늘의 목적은 나중에 model을 붙일 때 simulator, policy process, safety gate, robot
command path가 어디서 나뉘는지 명확하게 그리는 것입니다.

기본 architecture는 아래 흐름입니다.

```text
simulator가 observation을 publish/수집
policy process가 observation을 받음
policy가 action을 출력
safety gate가 action을 검사
robot command가 action을 실행
```

`Deploying Policies in Isaac Sim`과 `Running a Reinforcement Learning Policy through ROS2 and Isaac Sim`
은 오늘 구조 참고 자료로만 사용합니다. 공식 tutorial은 policy deployment와
ROS2 controller flow를 보여 주지만, 우리는 그 task를 그대로 가져오지 않습니다. 대신
"simulation side", "policy side", "command side"를 분리하는 생각만 가져옵니다.

policy process boundary가 중요한 이유는 model을 바꾸기 쉽게 만들기 위해서입니다.
처음에는 scripted or dummy policy일 수 있고, 나중에는 Behavior Cloning, ACT, Diffusion
Policy가 될 수 있습니다. simulator가 내보내는 observation과 policy가 돌려주는 action의
약속이 안정적이면 model을 바꿔도 Day 8 scene과 Day 9 dataset loop를 매번 다시 만들지
않아도 됩니다.

정확한 observation/action key와 data contract는 shared contract만 따릅니다:
[Cube-pick v1 데이터셋과 policy interface](../shared/cube-pick-v1-dataset-policy-interface.md).

safety gate는 선택 사항이 아닙니다. learned policy output은 simulation에서도 먼저
filter를 통과해야 합니다. gate는 action limit, workspace limit, invalid value rejection,
speed limit, execution mode 확인을 담당합니다. 이 구조를 simulation 때부터 넣어야
real robot으로 옮길 때 "policy가 controller에 바로 연결되는" 위험한 길을 피할 수 있습니다.

real robot 앞에는 세 개의 gate를 둡니다.

1. Simulation replay: policy action을 Isaac Sim 안에서만 replay합니다.
2. Low-speed dry-run: real robot command path가 action을 logging만 하고 일반 실행은
   하지 않거나, free space에서 아주 작은 motion만 실행합니다.
3. Manual approval: 모든 real policy run 전에 operator readiness, workspace check,
   emergency stop check, speed scaling을 확인합니다.

이 세 gate를 통과하기 전에는 learned policy가 real robot motion을 만들지 않습니다.
