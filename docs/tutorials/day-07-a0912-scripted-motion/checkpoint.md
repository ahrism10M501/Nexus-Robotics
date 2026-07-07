# 체크포인트

## 통과 기준

Day 7을 통과하려면 아래 내용을 확인해야 합니다.

- virtual A0912 bringup이 실행 중이고 `/joint_states`가 publish됩니다.
- script에서 `DR_init.__dsr__id`, `DR_init.__dsr__model`, `DR_init.__dsr__node`를
  설정합니다.
- `ROBOT_MODEL="a0912"` 또는 같은 의미의 A0912 model 설정을 사용합니다.
- ROS2 node를 `namespace=ROBOT_ID`로 만들고, `DSR_ROBOT2`를 그 뒤에 import합니다.
- `set_robot_mode(ROBOT_MODE_AUTONOMOUS)`를 motion command 전에 호출합니다.
- `posj`와 `movej`로 virtual A0912가 known joint pose에 천천히 이동합니다.
- `posx`와 `movel`로 작은 task-space motion을 실행할 수 있습니다.
- 이 curriculum의 나중의 policy action이 `target_ee_delta + gripper_command`라는
  결정을 설명할 수 있습니다.

## 문제 해결

Python import가 실패하면 script를 실행하는 shell에서 ROS2와 Doosan workspace를 source했는지
확인합니다.

```bash
source /etc/profile.d/nexus_env.bash
ros2 pkg prefix dsr_bringup2
```

namespace가 맞지 않으면 `ROBOT_ID`를 확인합니다. `ROBOT_ID`는 virtual bringup namespace와
같아야 합니다.

`DR_init.__dsr__node` 관련 error가 나오면 `DSR_ROBOT2` import가 너무 이른지 확인합니다.
node를 만들고 `DR_init.__dsr__node`를 assign한 뒤 import해야 합니다.

robot이 움직이지 않으면 Day 6 기준으로 bringup과 controller를 다시 확인합니다.

```bash
ros2 control list_controllers
ros2 topic echo /joint_states --once
```

motion이 크거나 빠르면 script의 `vel`과 `acc`를 낮춥니다. 초보자에게 안전한 motion에서는
느린 command가 정상입니다.

policy action이 헷갈리면 오늘의 scripted command와 learned policy action을 구분합니다.
`movej`/`movel`은 사람이 정한 command이고, 나중의 ACT/Diffusion policy는
`target_ee_delta + gripper_command`를 내도록 맞춥니다.
