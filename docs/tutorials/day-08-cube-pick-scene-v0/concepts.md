# Day 8 개념

Day 8은 "A0912가 움직인다"에서 "A0912가 물체를 집으려고 시도한다"로 넘어가는
날입니다. 하지만 오늘의 성공 기준은 realistic grasp가 아닙니다. 오늘 중요한 것은
작고 반복 가능한 scene입니다. 나중에 ACT나 Diffusion Policy가 실패했을 때, model이
못한 것인지 scene reset이 흔들린 것인지 구분하려면 먼저 scene 자체가 조용하고
예측 가능해야 합니다.

scene tree는 단순하게 고정합니다.

```text
/World
  /A0912
  /Table
  /Cube
  /Camera_Front
  /TaskMarkers
```

이 이름들이 중요한 이유는 초보자가 눈으로 찾기 쉬워서만이 아닙니다. Day 9에서는
episode를 다시 재생하고, Day 10에서는 policy process가 observation을 받아 action을
내는 구조를 생각합니다. prim path가 매번 달라지면 replay script와 policy wrapper가
같은 대상을 찾기 어렵습니다.

공식 `Adding a Manipulator Robot`와 `Robot Setup Tutorial 6/7/9`는 완성된 A0912
project file을 대신 만들어 주는 문서가 아니라, 우리가 어떤 개념을 가져올지 알려 주는
지도입니다. manipulator를 stage에 올리고, articulation과 end-effector를 확인하고,
pick-place task를 "approach, grasp, lift, move, release" 흐름으로 나누는 방법을
배웁니다. 우리는 그 흐름을 `/World/A0912`, `/World/Table`, `/World/Cube`,
`/World/Camera_Front`, `/World/TaskMarkers`로 줄여서 사용합니다.

gripper는 v0에서 너무 욕심내지 않습니다. two-finger gripper가 잘 맞으면 좋지만,
setup이 길어져서 scene reset과 replay loop를 늦춘다면 `Surface Gripper`를 먼저
사용합니다. 이 선택은 현실감을 포기한다는 뜻이 아니라, dataset과 policy interface를
먼저 검증하겠다는 뜻입니다.

deterministic reset은 Day 8의 중심 개념입니다. reset은 robot ready pose, cube pose,
table pose, camera pose, marker pose, gripper state, cube physics state를 같은 시작점으로
되돌립니다. 같은 시작 상태에서 같은 scripted pick sequence를 여러 번 돌릴 수 있으면,
Day 9에서 저장한 episode를 replay할 때 data 문제가 훨씬 잘 보입니다.

오늘 pick sequence가 cube를 자주 놓쳐도 괜찮습니다. 실패한 attempt도 reset, action
timing, success label이 안정적이면 좋은 debugging data가 됩니다. ACT나 Diffusion
Policy로 가기 전에 필요한 것은 "항상 성공하는 손"이 아니라 "실패도 같은 방식으로
기록되는 task"입니다.

observation/action의 정확한 이름과 shape는 Day 문서에 복사하지 않습니다. source of
truth는 shared contract입니다:
[Cube-pick v1 데이터셋과 policy interface](../shared/cube-pick-v1-dataset-policy-interface.md).
