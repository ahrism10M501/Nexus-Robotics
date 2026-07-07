# 개념

Day 5의 Franka 예제는 최종 목표가 아닙니다. 우리는 Doosan A0912를 사용할
것이지만, NVIDIA의 Franka tutorial은 manipulator data flow를 짧은 시간 안에
보여 주는 좋은 proxy입니다. package name이나 robot shape를 외우려 하지 말고,
아래 네 가지가 어디에서 보이는지에 집중하세요.

```text
/joint_states       현재 측정되었거나 simulation된 joint state
/joint_command      Isaac 예제에서 원하는 joint state command
MoveIt2             planning과 collision checking
Articulation Ctrl   낮은 수준의 simulator actuator target
```

## `/joint_states`는 observation이다

`/joint_states`는 robot이 지금 어떤 자세인지 알려 주는 observation topic입니다.
message에는 보통 joint `name`, `position`, `velocity`, `effort`가 들어갑니다.
simulation에서는 simulated joint state이고, real robot에서는 driver가 보고하는
measured joint state가 됩니다.

나중에 ACT나 Diffusion Policy로 cube-pick을 할 때도 policy는 현재 상태를 먼저
봐야 합니다. camera image만으로는 arm이 어느 자세인지 충분히 알기 어렵습니다.
그래서 `/joint_states`는 Day 9 dataset의 `joint_state` observation과 직접
이어집니다.

## 이 Isaac 예제에서 `/joint_command`는 command intent이다

`/joint_command`는 NVIDIA Isaac Sim joint control tutorial에서 joint target을
보내는 command topic입니다. 이 이름이 모든 robot의 표준 policy interface라는 뜻은
아닙니다. 오늘은 "command intent가 ROS2 topic으로 들어와 simulator controller까지
흘러간다"는 구조를 보는 데 사용합니다.

이 구분은 중요합니다. learned policy가 나중에 action을 낸다고 해서 곧바로
`/joint_command`에 publish한다는 뜻은 아닙니다. 이 curriculum의 policy action은
Day 7에서 `target_ee_delta + gripper_command`로 정합니다. Day 5에서는 그보다
낮은 수준의 joint command 예제를 보고 control path의 감각을 잡습니다.

## MoveIt2 planning과 execution은 다르다

MoveIt2 planning은 robot model, joint limit, collision object를 보고 "어떤 경로로
움직이면 되는가"를 계산하는 단계입니다. planning 결과는 trajectory입니다.

Execution은 그 trajectory를 controller나 simulator로 보내 실제 motion이 일어나게
하는 단계입니다. RViz에서 plan은 보이는데 robot이 움직이지 않는 상황이 생길 수
있습니다. 그때는 planning 문제가 아니라 execution path, controller, simulator
상태를 확인해야 합니다.

ACT나 Diffusion Policy를 붙일 때도 이 차이가 계속 중요합니다. model output은
planning된 trajectory가 아닐 수 있습니다. policy action을 safety gate와 controller
path에 넣기 전에, 지금 내가 보고 있는 것이 "계획"인지 "실행 명령"인지 구분해야
합니다.

## Articulation Controller는 simulator actuator로 가는 문이다

Isaac Sim에서 manipulator는 articulation으로 표현됩니다. `Articulation Controller`
는 ROS2나 graph에서 온 target을 articulation joint drive에 전달하는 낮은 수준의
문입니다. ROS2 topic이 보여도 `Articulation Controller`가 잘못된 articulation이나
joint name을 가리키면 robot은 움직이지 않습니다.

Day 6의 A0912에서는 Doosan stack과 ROS2 control controller가 이 역할을 더
체계적으로 담당합니다. 그래도 핵심 질문은 같습니다. "현재 joint state를 누가
publish하는가?", "command는 어떤 controller로 들어가는가?", "execution이 실제
motion으로 이어지는가?"를 확인할 수 있어야 cube-pick 실험을 믿을 수 있습니다.
