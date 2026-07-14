# Day 2 체크포인트

## 통과 기준

Day 2를 통과하려면 container에서 command를 보내 robot이 움직이는 것뿐 아니라, 그 command가
Isaac Sim graph 안에서 어떤 node를 거치는지도 설명할 수 있어야 합니다.

- `ros2 topic list`에서 `/cmd_vel`을 확인할 수 있습니다.
- `ros2 topic info /cmd_vel`에서 `geometry_msgs/msg/Twist` type을 확인할 수 있습니다.
- repeated publish command로 robot을 천천히 움직일 수 있습니다.
- zero stop command로 motion intent를 멈출 수 있습니다.
- `ROS2 Subscribe Twist` receives `/cmd_vel`, `Differential Controller` converts
  vehicle velocity to wheel velocity, `Articulation Controller` sends commands to
  joint drives라고 설명할 수 있습니다.

## 문제 해결 가이드

`/cmd_vel`이 topic list에 없다면 bridge와 graph를 먼저 봅니다. `isaacsim.ros2.bridge`가
enable되어 있어야 하고, Action Graph 안에 `/cmd_vel`을 subscribe하는 `ROS2 Subscribe
Twist` node가 있어야 합니다. graph가 있어도 simulation이 Play 상태가 아니면 기대한 data
flow가 보이지 않을 수 있습니다.

topic은 있는데 robot이 움직이지 않으면 graph의 뒷부분을 봅니다. `Differential Controller`
output이 wheel command로 이어지는지, `Articulation Controller`가 올바른 robot articulation과
wheel joint를 가리키는지 확인합니다.

message가 안 들어오는 것 같으면 QoS를 확인합니다.

```bash
ros2 topic info /cmd_vel -v
```

publisher와 subscriber의 QoS가 compatible해야 합니다. reliable publisher와 best effort
subscriber처럼 일부 조합은 상황에 따라 기대와 다르게 보일 수 있으므로 공식 tutorial의
QoS 설정과 graph node 설정을 비교합니다.

robot이 멈추지 않으면 publish terminal이 아직 반복 command를 보내고 있는지 확인하고,
zero stop command를 다시 보냅니다.

## Day 3로 넘어가기 전에

Day 2에서는 ready-made scene과 graph를 사용했습니다. Day 3에서는 같은 Isaac Sim world를
손으로만 만들지 않고 Python으로 다시 만들 수 있는 minimum loop를 읽습니다. 그 준비가 되어야
후속 실습에서 task scene을 매번 같은 상태로 reset할 수 있습니다.
