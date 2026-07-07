# 개념

Day 7에서는 learned policy를 붙이지 않습니다. 먼저 Doosan `DSR_ROBOT2` Python
API로 virtual A0912가 알려진 command를 따라 움직이는지 확인합니다. 이 path가
안정적이어야 Day 8의 scripted cube-pick sequence와 Day 9의 demonstration collection을
믿을 수 있습니다.

## DSR_ROBOT2 설정 순서

Doosan tutorial의 핵심 pattern은 순서입니다. `DR_init`에 robot id와 model을 먼저
알려 주고, ROS2 node를 robot namespace로 만든 뒤, 그 node를 `DR_init.__dsr__node`에
넣습니다. 그다음 `DSR_ROBOT2`를 import합니다.

```text
import rclpy and DR_init
set ROBOT_ID
set ROBOT_MODEL = "a0912"
create ROS2 node with namespace=ROBOT_ID
assign DR_init.__dsr__node
import DSR_ROBOT2 after node setup
```

`ROBOT_ID`는 bringup namespace와 맞아야 합니다. 초보자 예제에서는 보통
`"dsr01"`을 사용합니다. `ROBOT_MODEL="a0912"`는 Python API 쪽에서도 오늘의 robot이
A0912라는 점을 명확히 합니다.

`DSR_ROBOT2`를 node setup 전에 import하면 API가 사용할 ROS2 node context가 아직
준비되지 않은 상태가 될 수 있습니다. 그래서 tutorial pattern처럼
`DR_init.__dsr__node`를 먼저 지정한 뒤 import하는 순서를 지킵니다.

## Robot mode와 motion primitive

`set_robot_mode(ROBOT_MODE_AUTONOMOUS)`는 motion command를 실행할 수 있는 autonomous
mode로 전환하는 단계입니다. virtual mode에서도 motion command 전에 mode를 명확히
설정하는 습관을 들입니다.

`posj`는 joint-space target을 만듭니다. `movej`는 그 joint target으로 움직입니다.
known safe pose로 robot command path를 확인할 때 좋습니다.

`posx`는 task-space pose target을 만듭니다. `movel`은 end-effector가 직선에 가까운
motion을 하도록 command합니다. cube-pick에서는 gripper를 cube 위, pre-grasp, lift
pose로 움직여야 하므로 task-space motion의 감각이 중요합니다.

처음에는 `vel`과 `acc`를 낮게 둡니다. 오늘의 목표는 빠른 motion이 아니라 command
path가 맞고 robot이 예상 가능한 작은 움직임을 하는지 확인하는 것입니다.

## ACT/Diffusion cube-pick에서 중요한 이유

scripted motion은 나중의 policy의 경쟁자가 아니라 기준선입니다. known script로
virtual A0912가 움직이지 않으면 learned policy를 붙여도 실패 원인을 알 수 없습니다.

policy action은 이 curriculum에서 `target_ee_delta + gripper_command`로 유지합니다.
joint-space command는 safe pose 확인에 좋지만, cube-pick policy는 cube와 gripper의
상대적인 움직임을 표현해야 합니다. 작은 end-effector delta와 gripper command를 쓰면
ACT나 Diffusion Policy가 처음부터 큰 absolute pose를 내는 위험을 줄이고, safety gate로
clamp하기도 쉽습니다.
