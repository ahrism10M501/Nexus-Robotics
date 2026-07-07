# 체크포인트

## 통과 기준

Day 5를 통과하려면 아래 내용을 스스로 설명할 수 있어야 합니다.

- Franka는 최종 robot이 아니라 A0912를 준비하기 위한 learning proxy입니다.
- `ros2 topic echo /joint_states --once`로 joint state message를 볼 수 있습니다.
- `/joint_states`는 observation이고 `/joint_command`는 NVIDIA Isaac example의
  command intent입니다.
- `MoveIt2 planning`은 trajectory를 계산하는 단계이고 execution은 controller나
  simulator를 통해 실제 motion을 만드는 단계입니다.
- `Articulation Controller`가 Isaac Sim articulation joint target으로 command를
  전달하는 낮은 수준의 역할을 한다고 말할 수 있습니다.

## 문제 해결

`/joint_states`가 missing이면 Isaac Sim timeline이 Play 상태인지, Franka tutorial
graph가 열려 있는지, `isaacsim.ros2.bridge`가 enable되어 있는지 확인합니다. host와
container의 `ROS_DOMAIN_ID`가 다르면 topic discovery가 흔들릴 수 있습니다.

`/joint_command`가 missing이면 `MoveIt 2` tutorial만 열어 둔 상태일 수 있습니다.
`ROS2 Joint Control` tutorial에서 command topic을 다시 확인합니다.

MoveIt2에서 plan은 되는데 robot이 움직이지 않으면 execution을 누른 것인지,
controller나 simulator process가 살아 있는지 확인합니다. 이 실패는 planning 문제가
아닐 수 있습니다.

`ros2 topic echo /joint_states --once`가 멈춰 있으면 publisher가 있는지 확인합니다.

```bash
ros2 topic info /joint_states -v
```

publisher count가 0이면 Isaac Sim 쪽 graph가 publish하지 않는 상태입니다.
