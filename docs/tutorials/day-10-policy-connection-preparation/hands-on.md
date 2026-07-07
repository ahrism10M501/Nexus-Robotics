# Day 10 실습

## 오늘 만들 것

Day 10에서는 나중의 policy 연결 구조를 문서화하고, simulation에서 real
robot으로 넘어가기 전에 필요한 safety gates를 정리합니다. 구현 대상은 ACT나 Diffusion
training code가 아닙니다. 오늘 만드는 것은 "policy process가 어디서 시작하고 어디서
끝나는가"에 대한 명확한 boundary입니다.

## 공식 튜토리얼 흐름

오늘의 공식 튜토리얼은 구조 참고 자료로만 읽습니다.

- `Deploying Policies in Isaac Sim`:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/isaac_lab_tutorials/tutorial_policy_deployment.html
- `Running a Reinforcement Learning Policy through ROS2 and Isaac Sim`:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_rl_controller.html
- `Isaac Lab`:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/isaac_lab_tutorials/index.html

이 문서들은 policy deployment, simulation loop, ROS2 controller connection을 설명합니다.
하지만 Day 10에서는 그 예제를 우리 cube-pick task로 복사하지 않습니다. 우리가 가져오는
것은 process boundary와 safety-first deployment mindset입니다.

## 시작하기 전에

Day 9에서 replay 가능한 episode가 최소 하나 있어야 합니다. policy를 붙이기 전에 saved
action이 simulation에서 다시 실행되는지 확인한 상태여야 합니다.

shared contract를 열어 policy process가 받을 observation과 반환할 action concept을
확인합니다.

[Cube-pick v1 데이터셋과 policy interface](../shared/cube-pick-v1-dataset-policy-interface.md)

실제 robot 실행은 오늘 하지 않습니다. Day 10의 현재 execution mode는
Simulation replay입니다.

## 1단계: process boundary 그리기

아래 흐름을 project note 또는 whiteboard에 그대로 적습니다.

```text
simulator가 observation을 publish/수집
policy process가 observation을 받음
policy가 action을 출력
safety gate가 action을 검사
robot command가 action을 실행
```

여기서 simulator는 Isaac Sim scene과 recorder/replay loop를 포함합니다. policy process는
model code가 살게 될 별도 boundary입니다. safety gate는 policy output과 robot command
사이에 놓입니다. robot command path는 simulation command일 수도 있고, 훨씬 나중에는
real robot command path일 수도 있습니다.

## 2단계: Day 9 replay를 placeholder policy와 연결하기

처음 policy process는 learned model일 필요가 없습니다. Day 9에서 저장한 action을 하나씩
읽어 반환하는 placeholder policy라고 생각해도 됩니다. 중요한 것은 simulator가 observation을
넘기고, policy boundary가 action을 돌려주고, 그 action이 바로 command로 가지 않고 safety
gate를 지난다는 구조입니다.

이렇게 하면 나중에 placeholder policy를 Behavior Cloning, ACT, Diffusion Policy로 바꿔도
simulator side와 safety gate는 같은 구조를 유지할 수 있습니다.

## 3단계: safety gate 책임 정의하기

safety gate는 policy output을 robot command로 바꾸기 전에 검사합니다. 최소한 action
limit, workspace limit, invalid value rejection, speed limit, execution mode check를
담당한다고 적어 둡니다.

중요한 것은 "나중에 real robot 때 추가하자"가 아니라 simulation 때부터 gate를 architecture에
넣는 것입니다. simulation에서 gate를 통과한 action만 command path로 보내면 Day 10 이후의
code review 기준이 훨씬 분명해집니다.

## 4단계: 세 execution gate 이름 붙이기

나중의 real robot path 앞에는 아래 세 gate를 둡니다.

1. Simulation replay: policy action을 Isaac Sim 안에서만 replay합니다.
2. Low-speed dry-run: real robot command path가 action을 logging만 하고 일반 실행은
   하지 않거나, free space에서 아주 작은 motion만 실행합니다.
3. Manual approval: 모든 real policy run 전에 operator readiness, workspace check,
   emergency stop check, speed scaling을 확인합니다.

Day 10의 output에는 이 세 이름이 그대로 들어가야 합니다. 특히 Simulation replay는 현재
허용된 실행 mode입니다. Low-speed dry-run과 Manual approval은 real robot으로 가기 전
추가 gate입니다.

## 5단계: training은 범위 밖으로 유지하기

ACT나 Diffusion Policy training은 오늘 구현하지 않습니다. Isaac Lab tutorial을 읽다가
training pipeline을 따라가고 싶어져도 멈춥니다. Day 8-10의 목적은 scene, dataset,
policy boundary를 안정화하는 것입니다.

training은 나중에 같은 shared contract를 사용해 붙입니다. 지금은 model 성능보다 "model을
끼워 넣어도 위험한 command가 바로 실행되지 않는 구조"가 더 중요합니다.

## 확인하기

아래를 확인합니다.

- simulator, policy process, safety gate, robot command path의 boundary를 설명할 수 있습니다.
- policy process는 observation을 받고 action을 반환한다고 설명할 수 있습니다.
- policy output은 safety gate를 통과하기 전에는 robot command path로 가지 않습니다.
- 현재 mode를 Simulation replay로 표시했습니다.
- Low-speed dry-run과 Manual approval을 나중의 real robot gates로 분리했습니다.
- ACT/Diffusion training을 Day 10 scope에 넣지 않았습니다.

## 막혔을 때

policy boundary가 흐릿하면 shared contract의 Policy Process Contract를 다시 읽습니다.
정확한 key와 shape를 Day 문서에 베끼지 말고, simulator와 policy가 어떤 약속으로 만나는지만
말로 정리합니다.

action이 safety gate를 우회할 수 있으면 architecture가 아직 준비되지 않은 것입니다.
policy output을 command publisher나 robot API에 직접 연결하는 path를 제거하고, gate를
반드시 사이에 둡니다.

Simulation replay도 불안정하면 Day 9로 돌아갑니다. replay가 안정적이지 않은 상태에서
learned policy를 붙이면 실패 원인을 찾기 어렵습니다.

real robot dry-run이 실제 motion을 만들 가능성이 있으면 logging-only mode로 낮춥니다.
operator readiness, workspace check, emergency stop check, speed scaling이 명시되기 전에는
Manual approval gate를 통과한 것이 아닙니다.

## 오늘 배운 것

Day 10에서는 공식 policy deployment 튜토리얼을 구조 참고 자료로 읽고,
cube-pick project에 맞는 policy process boundary를 정리했습니다. simulator가 observation을
모으고, policy가 action을 내고, safety gate가 action을 걸러낸 뒤에만 command path가
실행됩니다. Simulation replay, Low-speed dry-run, Manual approval 세 gate를 분리해 두면
나중에 ACT나 Diffusion Policy를 붙일 때도 safety structure를 유지할 수 있습니다.
