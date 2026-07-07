# 체크포인트

## 통과 기준

Day 6를 통과하려면 아래 내용을 확인해야 합니다.

- Doosan Jazzy workspace가 현재 shell에서 source되어 있고 `dsr_bringup2` package를
  찾을 수 있습니다.
- MoveIt bringup을 `mode:=virtual`, `model:=a0912`, `host:=127.0.0.1`,
  `port:=12345`로 실행했습니다.
- RViz에서 A0912가 보이고, MotionPlanning panel에서 작은 motion을 plan할 수 있습니다.
- `ros2 control list_controllers`에서 필요한 controller가 active 상태입니다.
- `ros2 topic echo /joint_states --once`가 A0912 joint state를 출력합니다.
- MoveIt2에서 작은 motion을 execute했을 때 virtual A0912가 움직입니다.
- MoveIt bringup을 종료한 뒤 Gazebo bringup에서 A0912가 나타나는 것을 확인했습니다.

## 문제 해결

launch file이 not found이면 Doosan workspace build와 source를 다시 확인합니다.

```bash
ros2 pkg prefix dsr_bringup2
```

wrong robot이 보이면 launch command의 `model:=a0912`가 빠졌거나 다른 model 값으로
실행했을 가능성이 큽니다.

controller가 active가 아니면 RViz execution을 누르기 전에 launch output과 controller
state를 봅니다.

```bash
ros2 control list_controllers
```

`/joint_states`가 나오지 않으면 virtual bringup이 아직 실행 중인지, 확인용 shell도
같은 ROS2와 Doosan workspace를 source했는지 확인합니다.

RViz plan은 되는데 execute가 실패하면 planning scene 문제가 아니라 controller나
execution path 문제일 수 있습니다. Day 5의 `MoveIt2 planning`과 execution 구분을 다시
적용합니다.

Gazebo bringup이 불안정하면 이전 MoveIt bringup이 남아 있지 않은지 확인합니다. 초반에는
MoveIt bringup과 Gazebo bringup을 동시에 켜지 않는 편이 원인 분리에 좋습니다.
