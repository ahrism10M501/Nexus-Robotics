# 튜토리얼 문제 해결

이 문서는 tutorial을 따라가다가 막혔을 때 처음 확인할 순서를 정리합니다. 문제를
바로 "코드가 틀렸다"로 보지 말고, 증상, 가능한 원인, 첫 확인 순서로 나누어 보면
ROS2와 Isaac Sim 사이의 연결 상태를 훨씬 빨리 좁힐 수 있습니다.

## ROS2 Topic이 보이지 않을 때

증상: container에서 `ros2 topic list`를 실행했는데 `/clock`, `/cmd_vel`,
`/joint_states`, camera topic 같은 expected topic이 보이지 않습니다.

가능한 원인: Isaac Sim이 ROS2 환경을 모르는 terminal에서 실행되었거나,
`isaacsim.ros2.bridge`가 꺼져 있거나, Isaac Sim과 container의 `ROS_DOMAIN_ID` 또는
FastDDS profile이 서로 다를 수 있습니다. DDS 환경 변수는 process 시작 시점에 읽히므로,
중간에 바꾼 뒤 Isaac Sim을 재시작하지 않은 경우도 흔합니다.

먼저 확인:

- Isaac Sim을 ROS 환경이 맞춰진 terminal에서 실행했는지 확인합니다.
- `isaacsim.ros2.bridge`가 enable되어 있는지 확인합니다.
- Isaac Sim과 container 양쪽에서 `ROS_DOMAIN_ID=42`인지 확인합니다.
- 두 process 모두 FastDDS profile path가 설정되어 있는지 확인합니다.
- DDS 환경 변수를 바꿨다면 Isaac Sim을 재시작합니다.
- container에서 `ros2 topic list`를 다시 실행합니다.

초보자에게 가장 흔한 함정은 host Isaac Sim과 container ROS2가 서로 다른 세계에 있는
것처럼 실행되는 상황입니다. topic discovery가 안 되면 graph나 controller를 고치기 전에
실행 위치와 환경 변수를 먼저 맞춥니다.

## Topic은 보이지만 Data가 흐르지 않을 때

증상: `ros2 topic list`에는 topic 이름이 보이지만 `ros2 topic echo <topic>`에서 message가
오지 않거나, RViz에서 image 또는 state가 갱신되지 않습니다.

가능한 원인: publisher와 subscriber의 QoS가 맞지 않거나, Isaac Sim timeline이 Play
상태가 아니거나, Action Graph가 `On Playback Tick`에서 tick을 받지 못할 수 있습니다.
topic 이름이나 namespace가 tutorial 문서와 다르게 설정된 경우에도 data가 빈 것처럼
보입니다.

먼저 확인:

- `ros2 topic info <topic> -v`로 QoS를 확인합니다.
- simulation이 playing 상태인지 확인합니다.
- Action Graph가 `On Playback Tick`에서 ticking 중인지 확인합니다.
- topic 이름과 namespace를 확인합니다.
- `ros2 topic info <topic> -v`에서 publisher count와 subscriber count가 기대와 맞는지 확인합니다.
- `ros2 topic list`에 나온 정확한 topic 이름으로 `ros2 topic echo <topic>`를 실행합니다.

topic 이름이 보인다는 것은 discovery가 되었다는 뜻이지, message가 계속 흐른다는 뜻은
아닙니다. data flow 문제에서는 QoS, Play state, graph tick, namespace를 같은 우선순위로
봅니다.

## Robot이 움직이지 않을 때

증상: command를 보냈는데 robot joint나 mobile base가 움직이지 않습니다. topic은 보일 수
있고, command echo도 보일 수 있지만 Isaac Sim 화면의 robot pose가 변하지 않습니다.

가능한 원인: controller가 active 상태가 아니거나, command topic type이 controller가
기대하는 type과 다를 수 있습니다. target value가 joint limit 밖에 있거나 speed와
acceleration이 너무 높아 safety 설정 또는 controller 설정에서 막히는 경우도 있습니다.
Action Graph가 잘못된 articulation을 가리키는 경우에는 command가 도착해도 실제 robot에
전달되지 않습니다.

먼저 확인:

- controller가 active 상태인지 확인합니다.
- command topic type이 맞는지 확인합니다.
- joint limit과 target value가 유효한지 확인합니다.
- 다른 debug 전에 speed와 acceleration을 먼저 낮춥니다.
- Action Graph target articulation 또는 controller target path를 확인합니다.
- `ros2 topic echo <command_topic>`로 command 값이 실제로 보내지는지 확인합니다.

처음 debug할 때는 항상 작은 motion으로 시작합니다. 큰 target이나 빠른 speed는 문제를 더
잘 보여 주는 것이 아니라, safety issue와 controller issue를 동시에 만들 수 있습니다.

## Camera Image가 없거나 멈춰 있을 때

증상: camera topic이 보이지 않거나, topic은 있지만 image가 갱신되지 않습니다.

가능한 원인: camera prim만 있고 render product가 없거나, `ROS2 Camera Helper`가 render
output과 topic name에 제대로 연결되지 않았을 수 있습니다. timeline이 멈춰 있으면 image도
새 frame으로 갱신되지 않습니다.

먼저 확인:

- camera prim이 scene에 있는지 확인합니다.
- render product가 `ROS2 Camera Helper`에 연결되어 있는지 확인합니다.
- image topic 이름과 `camera_info` topic 이름을 확인합니다.
- simulation이 playing 상태인지 확인합니다.
- `ros2 topic list`를 실행한 뒤 `ros2 topic info <image_topic> -v`를 확인합니다.

camera 문제는 "camera가 scene에 있다"와 "ROS2 image가 publish된다"를 나누어 봐야 합니다.
prim, render product, helper node, topic name이 모두 이어져야 image observation이 됩니다.

## Dataset Replay가 맞지 않을 때

증상: saved episode를 replay했을 때 step count가 `num_steps`와 다르거나, final scene이
recording 때와 다르게 보입니다.

가능한 원인: observation을 action 적용 후에 저장했거나, reset pose가 episode마다 다르게
기록되었거나, `done`과 `success` flag가 마지막 timestep과 맞지 않을 수 있습니다. action
array와 timestamp array 길이가 다를 때도 replay가 어긋납니다.

먼저 확인:

- `observations.npz`와 `actions.npy`의 timestep count가 같은지 확인합니다.
- replay step count가 `num_steps`와 같은지 확인합니다.
- 마지막 timestep에만 `done=true`인지 확인합니다.
- `success=true`가 화면에서 보이는 final state와 맞는지 확인합니다.
- image timestamp와 action timestamp가 단조 증가하는지 확인합니다.

replay가 맞지 않으면 training을 멈추고 dataset collection을 먼저 고칩니다. model은 dataset의
시간 순서를 고쳐 주지 못합니다.
