# Day 9 실습

## 오늘 만들 것

Day 9에서는 Day 8의 deterministic cube-pick scene에서 작은 dataset collection loop를
만듭니다. 하나의 episode는 reset, recording start, observation capture, action apply,
done/success label, metadata save, replay check까지 포함합니다.

오늘은 ACT나 Diffusion Policy를 학습하지 않습니다. 목표는 나중의 policy가 믿고 사용할
수 있는 demonstration episode를 만드는 것입니다.

## 공식 튜토리얼 흐름

Day 9에는 새 NVIDIA 또는 Doosan 공식 튜토리얼을 추가하지 않습니다. 오늘의 기준은
공통 shared contract입니다.

- `Cube-pick v1 데이터셋과 policy interface`:
  [../shared/cube-pick-v1-dataset-policy-interface.md](../shared/cube-pick-v1-dataset-policy-interface.md)

정확한 schema, file layout, metadata key는 이 shared contract만 봅니다. Day 문서에
복사해 두면 나중에 contract가 바뀔 때 두 곳이 어긋납니다.

## 시작하기 전에

Day 8 scene이 deterministic reset을 통과해야 합니다. reset할 때마다 `/World/Cube`가
같은 곳에서 시작하고, `/World/Camera_Front`가 cube와 gripper를 볼 수 있어야 합니다.

host에서 Isaac Sim을 실행하고 scene을 엽니다.

```bash
cd /home/ahrism/workspace/ros2-dev
./scripts/launch_isaac_sim.sh
```

다른 terminal에서는 기본 ROS2 container를 시작하고 ROS2 환경을 준비합니다.

```bash
cd /home/ahrism/workspace/ros2-dev
./run.sh dev
```

container 안에서:

```bash
source /etc/profile.d/nexus_env.bash
cd /workspace
ros2 topic list
```

dataset 저장 위치는 shared contract의 file layout을 따릅니다. 이 Day 문서에서는 정확한
파일 이름을 반복하지 않습니다.

## 1단계: shared contract를 recording spec으로 읽기

shared contract에서 task version, episode concept, observation/action concept,
metadata concept, replay check를 읽습니다. 특히 "control tick에서 무엇을 먼저 저장하고
무엇을 나중에 적용하는가"를 확인합니다.

초보자에게는 이 문서가 약간 딱딱하게 보일 수 있습니다. 하지만 이것이 나중의 ACT와
Diffusion Policy code가 simulator와 약속하는 언어입니다. Day 9 recorder는 그 약속을
처음으로 실제 data로 만드는 작은 bridge입니다.

## 2단계: scene을 reset하고 recording 시작하기

하나의 episode를 시작할 때 먼저 Day 8 reset path를 실행합니다. robot ready pose,
cube pose, gripper state, camera pose가 시작 상태로 돌아온 뒤 recording을 시작합니다.

recording 시작 시점에는 episode id, task version, simulator version, control rate,
operator note 같은 metadata를 memory에 준비합니다. metadata는 episode가 끝난 뒤 실제
결과와 step count를 반영해 저장합니다.

## 3단계: action 적용 전에 observation 저장하기

각 control tick에서 가장 먼저 observation before action을 지킵니다. 즉, 현재 camera
view, robot state, end-effector state, gripper state, timestamp를 먼저 읽고, 그 state를
기준으로 이번 tick의 action intent를 정합니다.

그다음 action을 적용합니다. scripted sequence라면 "pre-grasp 쪽으로 조금 이동",
"gripper 활성화", "lift", "drop zone으로 이동" 같은 action intent가 순서대로 나옵니다.
human-guided collection을 하더라도 순서는 같습니다. 먼저 현재 observation을 저장하고,
그 state에서 선택한 action을 저장한 뒤, action을 simulator에 적용합니다.

## 4단계: done과 success를 신중히 표시하기

episode의 마지막 tick에서 done을 표시합니다. success는 cube가 drop zone 근처에 있고,
시각적으로도 pick-place attempt가 성공했다고 판단될 때만 true로 둡니다.

grasp가 실패했지만 sequence가 끝까지 갔다면 done은 episode 종료를 뜻하고, success는
실패 결과를 뜻합니다. 이 둘을 섞지 않는 것이 중요합니다. 나중에 model을 평가할 때
"episode가 끝났다"와 "task를 성공했다"는 다른 질문입니다.

## 5단계: episode 후 metadata 저장하기

episode가 끝난 뒤 metadata를 저장합니다. step count, success label, note, control rate
같은 값은 recording 중간보다 끝난 뒤가 더 정확합니다.

정확히 어떤 배열과 파일을 저장하는지는 shared contract를 따릅니다. Day 9 문서 안에서
shape나 file layout을 다시 정의하지 않습니다:
[Cube-pick v1 데이터셋과 policy interface](../shared/cube-pick-v1-dataset-policy-interface.md).

처음에는 다섯 episode 정도만 저장합니다. 성공 episode와 실패 episode가 섞여도 괜찮습니다.
중요한 것은 각 episode가 같은 loop로 저장되고 replay 가능한가입니다.

## 6단계: policy 없이 episode 하나 replay하기

저장한 episode 하나를 고르고 policy process는 끕니다. scene을 초기 상태로 reset한 뒤,
저장된 action sequence를 순서대로 적용합니다.

replay 중에는 세 가지를 봅니다. 첫째, replay step count가 metadata와 맞는가. 둘째,
timestamp가 앞으로만 흐르는가. 셋째, final success label이 화면에서 본 결과와 맞는가.

replay가 다르게 보이면 training으로 넘어가지 않습니다. recorder가 observation/action
순서를 잘못 저장했거나, reset이 완전히 deterministic하지 않거나, action timing이
episode마다 달라졌을 가능성이 큽니다.

## 확인하기

아래를 확인합니다.

- Day 8 scene reset 후 recording을 시작합니다.
- 각 control tick에서 observation before action 순서를 지킵니다.
- action 적용 뒤 다음 tick으로 넘어갑니다.
- final tick에서 done과 success를 구분해 표시합니다.
- metadata는 episode가 끝난 뒤 저장합니다.
- shared contract에 맞춰 episode data를 저장하지만, Day 문서에는 exact schema를 복사하지
  않았습니다.
- 최소 한 episode를 policy 없이 replay하고 step count, timestamp order, success label을
  확인했습니다.

## 막혔을 때

replay step count가 recording과 다르면 done을 표시하는 tick과 recording을 멈추는 tick이
어긋났을 수 있습니다. final action을 저장했는지, final observation을 저장했는지 순서를
다시 보세요.

action이 한 tick 늦거나 빠르게 보이면 observation before action 규칙을 어겼을 가능성이
있습니다. 저장 loop를 "read current state, choose/save action, apply action" 순서로
다시 정리합니다.

timestamp가 뒤로 가거나 반복되면 한 episode 안에서 clock source가 섞였을 수 있습니다.
simulation time을 기준으로 하나의 control loop에서 timestamp를 읽습니다.

success label이 헷갈리면 기준을 단순하게 둡니다. cube가 drop zone에 도착했다고 판단될
때만 success로 표시하고, 그렇지 않으면 실패 episode로 남깁니다.

## 오늘 배운 것

Day 9에서는 cube-pick scene을 data로 바꾸는 기본 loop를 만들었습니다. 핵심은
observation before action 순서, done과 success의 분리, episode 종료 후 metadata 저장,
그리고 policy 없이 replay하는 품질 확인입니다. 이 loop가 안정적이면 나중에 ACT나
Diffusion Policy를 붙일 때 model code가 아니라 dataset 자체를 믿고 시작할 수 있습니다.
