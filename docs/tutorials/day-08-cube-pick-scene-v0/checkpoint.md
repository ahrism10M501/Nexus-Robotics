# Day 8 체크포인트

Day 8의 checkpoint는 "cube를 멋지게 잡았는가"가 아니라 "같은 scene을 같은 방식으로
다시 실행할 수 있는가"를 확인합니다. 이 기준을 통과해야 Day 9 dataset replay가 의미를
가집니다.

## 통과 기준

- stage tree에 `/World/A0912`, `/World/Table`, `/World/Cube`, `/World/Camera_Front`,
  `/World/TaskMarkers`가 있습니다.
- reset을 여러 번 실행해도 robot ready pose, cube pose, camera pose, marker pose,
  gripper state가 같은 시작점으로 돌아옵니다.
- scripted sequence가 reset부터 release 또는 failure label까지 중단 없이 실행됩니다.
- `Surface Gripper` 또는 다른 virtual gripper의 open/close intent를 설명할 수 있습니다.
- camera, robot state, gripper state, action intent, done/success 판단을 같은 control tick
  기준으로 모을 수 있습니다.
- grasp가 가끔 실패해도 scene과 replay loop가 안정적이면 통과로 봅니다.

## 문제 해결

cube가 table 위에서 미끄러지거나 매번 다른 곳에 있으면 reset에서 pose만 바꾸고 physics
state를 놓쳤을 가능성이 큽니다. cube velocity와 gripper attachment state를 함께
초기화하세요.

robot이 cube 위로 가지 못하면 `TaskMarkers`를 먼저 눈으로 확인합니다. marker가
설명하는 approach, pre-grasp, lift, drop 위치가 robot workspace 안에 있어야 합니다.

lift가 불안하면 two-finger gripper 세부 tuning을 미루고 `Surface Gripper`로 sequence를
검증합니다. Day 8 v0에서는 virtual gripper 선택보다 repeatable loop가 더 중요합니다.

camera에 cube가 잘리지 않으면 `/World/Camera_Front`를 고정하고 reset 대상에 포함합니다.
dataset 단계에서 camera pose가 바뀌면 observation 해석이 어려워집니다.

sequence가 한 번만 성공하고 다음 run에서 실패하면 reset이 충분하지 않은 것입니다.
세 번 연속 reset과 scripted sequence를 돌려서 같은 실패 또는 같은 성공이 반복되는지
확인하세요.
