# Day 2 개념

Day 2의 목표는 ROS2 command가 Isaac Sim 안의 robot motion으로 바뀌는 길을 보는
것입니다. 오늘의 command는 `/cmd_vel` 하나입니다. 이 topic을 publish하면 robot이
어디로 가야 하는지 지정하는 것이 아니라, 지금 어떤 속도로 움직일지를 요청합니다.

## ROS2 Bridge

`isaacsim.ros2.bridge`는 host에서 실행되는 Isaac Sim과 container 안의 ROS2 Jazzy
tool을 연결하는 extension입니다. 이 extension이 enable되어 있지 않으면
`ros2 topic list`에서 Isaac Sim graph가 만든 topic을 기대하기 어렵습니다.

Day 2에서는 bridge가 subscribe 방향으로 쓰입니다. container에서 `/cmd_vel`을
publish하고, Isaac Sim Action Graph의 ROS2 node가 그 message를 받습니다.

## /cmd_vel와 Twist

`/cmd_vel`은 velocity command topic입니다. 보통 message type은
`geometry_msgs/msg/Twist`입니다.

`Twist`에는 linear velocity와 angular velocity가 들어 있습니다. 예를 들어
`linear.x`를 양수로 주면 앞으로 가려는 command가 되고, `angular.z`를 양수 또는
음수로 주면 회전하려는 command가 됩니다. 이것은 waypoint나 pose goal이 아닙니다.
publish가 멈추거나 zero command를 보내면 robot은 더 이상 같은 속도를 유지하라는
요청을 받지 않습니다.

## Isaac Sim 흐름의 세 control node

공식 `Driving TurtleBot using ROS2 Messages` 흐름에서 초보자가 꼭 이해해야 하는
node chain은 다음과 같습니다.

`ROS2 Subscribe Twist` receives `/cmd_vel`.

`Differential Controller` converts vehicle velocity to wheel velocity.

`Articulation Controller` sends commands to joint drives.

즉 ROS2에서 보낸 `Twist`가 바로 wheel joint target이 되는 것이 아닙니다. 먼저
vehicle-level velocity command로 들어오고, differential drive kinematics를 거쳐
left/right wheel velocity로 바뀐 뒤, articulation joint drive에 전달됩니다.

이 구조를 알면 debug 순서가 분명해집니다. `/cmd_vel` topic이 있는지, `ROS2 Subscribe
Twist`가 message를 받는지, `Differential Controller` output이 wheel command로
나오는지, `Articulation Controller`가 robot articulation을 올바르게 가리키는지 차례로
볼 수 있습니다.

## QoS와 continuous publish

ROS2 topic은 이름이 보인다고 data가 반드시 흐르는 것은 아닙니다. publisher와
subscriber의 QoS가 맞지 않으면 `ros2 topic list`에는 topic이 보여도 message가 도착하지
않을 수 있습니다. 오늘은 `ros2 topic info /cmd_vel -v`로 publisher/subscriber와 QoS를
보는 습관을 만듭니다.

또 하나 중요한 점은 velocity command는 보통 반복 publish가 어울린다는 것입니다.
`--once`로 한 번만 보내면 robot이 잠깐 반응하거나 sample graph에 따라 충분히 움직이지
않을 수 있습니다. 움직임을 볼 때는 `-r 10`처럼 rate를 주고, 끝낼 때는 zero stop
command를 보냅니다.
