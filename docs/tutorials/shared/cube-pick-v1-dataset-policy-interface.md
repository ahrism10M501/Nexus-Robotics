# Cube-Pick v1 데이터셋과 Policy Interface

이 문서는 A0912 cube-pick 프로젝트에서 Day 8-10 동안 함께 쓰는 첫 dataset과
policy action interface를 정합니다. 초보자에게 중요한 점은 "model을 바꿔도
simulator와 dataset 모양은 흔들리지 않게 한다"는 것입니다. Behavior Cloning,
ACT, Diffusion Policy를 차례로 시도하더라도 아래 contract가 그대로 남아 있어야
debugging과 replay가 쉬워집니다.

처음에는 작고 단순한 interface가 좋습니다. camera 한 대, cube 한 개, gripper 한
개만으로도 observation, action, safety layer의 기본 연결을 충분히 연습할 수
있습니다.

## 작업

작업은 table 위의 cube 하나를 집어서 가까운 drop zone에 내려놓는 것입니다. 여기서
`cube_pick_v1`은 "처음 학습 가능한 최소 버전"을 뜻합니다.

`cube_pick_v1` 버전은 아래 구성만 사용합니다.

- simulation 안의 Doosan A0912 arm 한 대
- virtual gripper 한 개
- 고정 RGB camera 한 대
- cube 한 개
- table 한 개
- scripted 또는 teleoperated demonstration

각 항목을 일부러 하나씩만 둡니다. object가 많아지면 실패 원인을 찾기 어렵고,
초기 dataset이 잘못 저장되어도 model 문제처럼 보이기 쉽습니다.

## Observation: policy가 보는 입력

observation은 policy가 한 timestep에서 보는 입력입니다. 먼저 "robot과 scene이
지금 어떤 상태인가"를 저장하고, 그 다음 action을 적용해야 나중에 "이 상태를 보고
이 행동을 했다"는 관계가 깨지지 않습니다.

각 timestep에는 아래 값을 기록합니다.

```text
rgb             uint8[H, W, 3]
joint_state     float32[6]
ee_pose         float32[7]   # x, y, z, qx, qy, qz, qw
gripper_state   float32[1]   # 0.0 open, 1.0 closed
timestamp       float64
```

`rgb`는 fixed camera image이고, `joint_state`는 A0912의 6개 joint 상태입니다.
`ee_pose`는 end-effector의 위치와 quaternion 자세이며, `gripper_state`는 gripper가
열렸는지 닫혔는지 알려 줍니다. `timestamp`는 replay와 action alignment를 확인할
때 기준이 됩니다.

처음에는 `H`와 `W`를 작게 둡니다. 예를 들어 `240 x 320`이면 training과 debugging이
빠르고, image 저장 문제도 빨리 발견할 수 있습니다.

## Action: policy가 내보내는 명령

action은 policy가 다음 control tick에 하고 싶은 움직임입니다. 처음부터 absolute
pose를 직접 내보내면 큰 점프가 생기기 쉬우므로, `cube_pick_v1`에서는 작은
end-effector delta와 gripper command를 기본으로 둡니다.

기본 action은 end-effector delta와 gripper command의 조합입니다.

```text
target_ee_delta   float32[6]  # dx, dy, dz, droll, dpitch, dyaw
gripper_command   float32[1]  # 0.0 open, 1.0 close
```

delta는 작게 제한합니다.

```text
abs(dx, dy, dz) <= 0.02 m per step
abs(droll, dpitch, dyaw) <= 0.10 rad per step
```

`target_ee_delta`는 지금 end-effector pose에서 조금 움직이라는 뜻입니다.
`gripper_command`는 gripper를 열지 닫을지 나타냅니다. learned policy output은 항상
safety layer를 통과해야 하며, real robot controller로 직접 publish하면 안 됩니다.

## Episode Directory: 저장 구조

episode는 한 번의 cube-pick 시도입니다. 성공하든 실패하든 하나의 episode로 저장하면
나중에 replay, filtering, training split을 같은 방식으로 처리할 수 있습니다.

생성된 data는 `data/` 아래에 저장합니다. 이 폴더는 `.gitkeep`을 제외하고
의도적으로 git에서 제외됩니다.

```text
data/cube_pick_v1/
  episodes/
    000001/
      meta.json
      observations.npz
      actions.npy
      rgb_front.npy
    000002/
      meta.json
      observations.npz
      actions.npy
      rgb_front.npy
  index.json
```

`data/cube_pick_v1/` 아래에서 episode 번호를 고정 길이 문자열로 두면 정렬과
검색이 쉽습니다. `meta.json`은 사람이 읽는 설명과 episode summary이고,
`observations.npz`와 `actions.npy`는 training code가 바로 읽는 배열입니다.
`rgb_front.npy`는 첫 camera image stream입니다. `index.json`은 전체 episode 목록과
split을 관리할 때 사용합니다.

최소 `meta.json`은 아래 형태를 사용합니다.

```json
{
  "task": "cube_pick_v1",
  "episode_id": "000001",
  "robot": "doosan_a0912",
  "simulator": "isaac_sim_6.0.1",
  "control_hz": 10,
  "success": true,
  "num_steps": 120,
  "action_type": "target_ee_delta_gripper",
  "observation_keys": ["rgb", "joint_state", "ee_pose", "gripper_state"],
  "notes": "scripted demonstration"
}
```

`observations.npz` key는 아래처럼 고정합니다.

```text
timestamps
joint_state
ee_pose
gripper_state
done
success
```

첫 버전에서는 `rgb_front.npy`를 사용합니다. 파일 크기가 불편해질 만큼 커지면
나중에 video나 chunked array 저장 방식으로 바꿉니다.

처음에는 파일 수를 줄이는 것보다 contract를 분명히 지키는 것이 더 중요합니다.
`success` label과 `done` flag가 틀리면 model 성능보다 dataset 품질을 먼저 의심해야
합니다.

## Collection Loop: 수집 순서

collection loop는 "초기화, 기록, action 적용, 종료 표시"의 반복입니다. 이 순서가
흔들리면 replay가 맞지 않고, model은 잘못된 짝의 observation/action을 배우게 됩니다.

한 episode는 아래 순서로 진행합니다.

1. simulation과 cube pose를 reset합니다.
2. recording을 시작합니다.
3. scripted 또는 human-guided pick sequence를 실행합니다.
4. 모든 control tick에서 action을 적용하기 전에 observation을 저장합니다.
5. action을 적용합니다.
6. 마지막 timestep에만 `done=true`를 표시합니다.
7. cube가 drop zone에 도달했을 때만 `success=true`를 표시합니다.
8. episode가 끝난 뒤 metadata를 저장합니다.

초보자에게 가장 중요한 줄은 4번입니다. action을 먼저 적용하고 observation을 저장하면
"과거 상태에 대한 행동"이 아니라 "행동 후 상태"가 저장되어 training target이
어긋납니다.

## Replay Check: 재생 검증

dataset을 training에 쓰기 전에는 반드시 한 episode를 replay합니다. replay는 dataset
format 검증이면서 simulator command path 검증입니다.

dataset을 training에 사용하기 전에 episode 하나를 replay합니다.

1. 초기 scene을 load합니다.
2. 저장된 action을 순서대로 적용합니다.
3. replay step 수가 `num_steps`와 같은지 확인합니다.
4. 마지막 `success` label이 화면에서 보이는 결과와 맞는지 확인합니다.
5. image timestamp와 action timestamp가 단조 증가하는지 확인합니다.

replay가 episode shape를 재현하지 못하면 model training으로 넘어가지 않습니다. 이때는
policy나 network보다 data collection code, timestep count, timestamp, reset 상태를 먼저
고칩니다.

## Policy Process Contract: simulator와 model의 경계

policy process는 simulator와 model 사이의 작은 경계입니다. simulator는 observation dict를
만들고, policy process는 action dict를 돌려줍니다. 이 경계가 작고 일정해야 나중에
Behavior Cloning, ACT, Diffusion Policy를 교체해도 주변 code가 그대로 유지됩니다.

policy process는 아래 observation을 받습니다.

```python
observation = {
    "rgb": rgb,
    "joint_state": joint_state,
    "ee_pose": ee_pose,
    "gripper_state": gripper_state,
}
```

policy process는 아래 action을 반환합니다.

```python
action = {
    "target_ee_delta": [dx, dy, dz, droll, dpitch, dyaw],
    "gripper_command": close_value,
}
```

이 Python dict examples는 code에서 그대로 찾을 수 있어야 합니다. key 이름을 바꾸면
dataset loader, policy wrapper, safety layer가 모두 함께 바뀌므로 초반에는 절대
변경하지 않습니다.

Safety layer는 반드시 아래 일을 해야 합니다.

- delta를 clamp합니다.
- workspace 밖 command를 거부합니다.
- non-finite value를 거부합니다.
- maximum speed를 강제합니다.
- 실제 robot 실행 전에는 manual enable을 요구합니다.

## Safety Gates: 실제 로봇 전 안전 단계

learned policy는 그럴듯한 숫자를 내도 안전한 command라는 보장은 없습니다. 그래서
실제 robot 실행 전에 simulation과 dry run을 따로 통과해야 합니다.

real robot에서 실행하기 전에는 반드시 아래 gate를 통과합니다.

1. Simulation replay: policy action을 Isaac Sim 안에서만 replay합니다.
2. Low-speed dry run: real robot command path가 action을 logging만 하고 실행하지
   않거나, free space에서 아주 작은 motion만 실행합니다.
3. Manual approval: 모든 real policy run 전에 operator readiness, workspace check,
   emergency stop check, speed scaling을 확인합니다.

이 단계는 빠르게 넘어가는 checklist가 아니라 사고를 줄이는 설계 경계입니다. 특히 policy
output은 real robot controller에 직접 연결하지 않고, 항상 clamp와 reject 규칙을 먼저
지납니다.

## Milestone: 다음 단계로 넘어가는 기준

milestone은 "어디까지 되면 다음 단계로 넘어가도 되는가"를 정하는 작은 문입니다. 큰
model부터 시작하지 말고, dataset 저장과 replay가 먼저 통과해야 합니다.

아래 gate를 순서대로 사용합니다.

1. `dataset_v0`: scripted episode 5개를 저장하고 replay할 수 있습니다.
2. `bc_v0`: 작은 behavior cloning policy가 episode 5개에 overfit할 수 있습니다.
3. `act_v0`: ACT가 같은 episode format으로 학습될 수 있습니다.
4. `diffusion_v0`: Diffusion Policy가 같은 episode format으로 학습될 수 있습니다.
5. `sim_eval_v0`: policy success rate를 simulation에서 측정합니다.
6. `real_dry_run_v0`: uncontrolled motion 없이 policy action이 real command path를
   통해 logging됩니다.

처음 목표는 높은 성공률이 아니라 전체 path가 설명 가능하게 이어지는 것입니다.
`dataset_v0`가 약하면 뒤의 모든 milestone이 흔들립니다.
