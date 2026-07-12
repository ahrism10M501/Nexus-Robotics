# Day 2 실습

## 오늘 만들 것

Isaac Sim에서 Jetbot 또는 TurtleBot driving scene을 열고, container 안의 ROS2 command로
robot을 천천히 움직입니다. Action Graph에서는 `ROS2 Subscribe Twist`,
`Differential Controller`, `Articulation Controller`가 이어지는 control path를 확인합니다.

## 공식 튜토리얼 흐름

오늘의 중심 공식 튜토리얼은 `Driving TurtleBot using ROS2 Messages`입니다.

- Driving TurtleBot using ROS2 Messages:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/ros2_tutorials/tutorial_ros2_drive_turtlebot.html
- Hello Robot:
  https://docs.isaacsim.omniverse.nvidia.com/6.0.1/core_api_tutorials/tutorial_core_hello_robot.html

`Hello Robot`은 ready-made robot을 scene에서 다루는 감각을 보충하기 위한 배경입니다.
실습의 실제 command path는 TurtleBot ROS2 driving 흐름을 따릅니다.

## 시작하기 전에

host에서 Isaac Sim을 실행합니다.

```bash
cd /home/ahrism/workspace/ros2-dev
./scripts/launch_isaac_sim.sh
```

다른 terminal에서는 기본 ROS2 container를 시작하고 shell로 들어갑니다.

```bash
cd /home/ahrism/workspace/ros2-dev
./run.sh dev
```

container 안에서 ROS2 환경을 확인합니다.

```bash
source /etc/profile.d/nexus_env.bash
cd /workspace
env | grep -E 'ROS_DOMAIN_ID|RMW_IMPLEMENTATION|FASTDDS|FASTRTPS'
```

host Isaac Sim과 container가 같은 `ROS_DOMAIN_ID=42`와 FastDDS profile을 사용해야
topic discovery가 안정적입니다.

## 1단계: TurtleBot driving scene 열기

Isaac Sim에서 공식 `Driving TurtleBot using ROS2 Messages` 흐름의 TurtleBot driving
scene을 엽니다. Jetbot 예제를 사용하는 경우에도 오늘 볼 구조는 같습니다. mobile robot
articulation이 있고, wheel joint를 drive할 graph가 있어야 합니다.

`isaacsim.ros2.bridge` extension이 enable되어 있는지 확인합니다. extension을 켠 뒤에는
scene의 Action Graph가 ROS2 node를 사용하고 있는지 봅니다.

## 2단계: Action Graph를 왼쪽에서 오른쪽으로 읽기

Action Graph에서 command가 지나가는 길을 확인합니다.

`ROS2 Subscribe Twist` receives `/cmd_vel`. 이 node는 ROS2 topic에서
`geometry_msgs/msg/Twist` message를 받습니다. topic name이 `/cmd_vel`인지 확인합니다.

`Differential Controller` converts vehicle velocity to wheel velocity. `Twist`의
linear/angular velocity는 robot 전체의 이동 의도입니다. differential controller는 이
의도를 left/right wheel velocity로 바꿉니다.

`Articulation Controller` sends commands to joint drives. 이 node는 계산된 wheel
command를 실제 robot articulation의 wheel joint drive로 보냅니다. target articulation과
joint 이름이 scene의 robot과 맞는지 확인합니다.

## 3단계: simulation을 시작하고 topic 확인하기

Isaac Sim timeline에서 Play를 누릅니다. graph가 ticking 중이어야 ROS2 subscribe와
controller update가 실제로 진행됩니다.

container 안에서 topic을 봅니다.

```bash
ros2 topic list
ros2 topic info /cmd_vel
ros2 topic info /cmd_vel -v
```

`/cmd_vel`이 보이지 않으면 graph가 아직 만들어지지 않았거나 bridge가 enable되지 않았을
수 있습니다. `ros2 topic info /cmd_vel -v`는 type과 QoS를 확인하는 데 유용합니다.

## 4단계: 느린 Twist command publish하기

container 안에서 천천히 앞으로 가며 회전하는 command를 publish합니다.

```bash
ros2 topic pub /cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: 0.2, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.4}}" \
  --qos-reliability reliable \
  --qos-durability volatile \
  --qos-depth 10 \
  -r 10
```

robot이 움직이는 동안 graph를 다시 봅니다. `/cmd_vel` message가 `ROS2 Subscribe
Twist`로 들어오고, 그 값이 `Differential Controller`를 지나 wheel velocity가 되며,
`Articulation Controller`가 wheel joint drive에 command를 보내는 흐름을 머릿속으로
따라갑니다.

## 5단계: zero stop command 보내기

속도 command 실습은 항상 stop command까지 포함합니다. publish terminal을 `Ctrl+C`로
멈춘 뒤 container 안에서 zero command를 한 번 보냅니다.

```bash
ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: 0.0, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.0}}"
```

robot이 더 움직이지 않는지 확인합니다. simulation이 계속 playing 상태라면 zero command
후에도 미끄러짐이나 controller 상태 때문에 아주 작은 움직임이 보일 수 있지만, command
intent는 stop입니다.

## 확인하기

아래 내용을 확인합니다.

- `ros2 topic list`에서 Isaac Sim 관련 topic과 `/cmd_vel`을 볼 수 있습니다.
- `ros2 topic info /cmd_vel`에서 type이 `geometry_msgs/msg/Twist`로 보입니다.
- repeated Twist publish 중 robot이 움직입니다.
- zero stop command 후 robot이 멈춥니다.
- `ROS2 Subscribe Twist`, `Differential Controller`, `Articulation Controller`의 역할을
  순서대로 설명할 수 있습니다.

## 막혔을 때

`/cmd_vel`이 보이지 않으면 Isaac Sim에서 `isaacsim.ros2.bridge`가 enable되어 있는지,
timeline이 Play 상태인지, Action Graph에 `ROS2 Subscribe Twist` node가 있는지 확인합니다.
host Isaac Sim과 container의 `ROS_DOMAIN_ID`도 같아야 합니다.

topic은 보이지만 robot이 움직이지 않으면 command를 `--once`로만 보낸 것은 아닌지
확인합니다. velocity command는 `-r 10`처럼 반복 publish할 때 확인하기 쉽습니다.

message가 도착하지 않는 것 같으면 `ros2 topic info /cmd_vel -v`로 QoS를 봅니다.
publisher와 subscriber의 reliability, durability, depth가 compatible해야 합니다.

robot이 계속 움직이면 zero stop command를 다시 보내고, publish 중이던 terminal이 아직
살아 있는지 확인합니다.

## 오늘 배운 것

ROS2 `/cmd_vel`은 mobile robot의 velocity command입니다. Isaac Sim에서는
`ROS2 Subscribe Twist`가 이 message를 받고, `Differential Controller`가 vehicle velocity를
wheel velocity로 바꾸며, `Articulation Controller`가 wheel joint drive에 command를 보냅니다.
