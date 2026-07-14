# Core 과정과 공식 튜토리얼 연결

이 문서는 core 네 과정에서 필요한 개념을 공식 문서의 어디에서 확인할지 안내합니다.
공식 문서를 그대로 복제하지 않고, 이 저장소의 실습 목표와 연결합니다.

## 첫 과정: Isaac Sim 기본기

참고 주제:

- Isaac Sim Core API와 stage 구성
- rigid body, collider, mass와 physics scene
- articulation, joint drive, Physics Inspector
- Action Graph 기본 구조

공식 문서에서 예제를 실행한 뒤 저장소의 [첫 과정 실습](../day-01-isaac-sim-basics/hands-on.md)으로
stage tree, prim path, joint limit을 직접 확인합니다. 목표는 특정 robot asset을 외우는
것이 아니라 USD scene과 physics 상태를 읽는 것입니다.

## 두 번째 과정: ROS2 주행 command

참고 주제:

- Isaac Sim ROS2 Bridge 활성화
- Driving TurtleBot using ROS2 Messages
- `geometry_msgs/msg/Twist`와 `/cmd_vel`
- ROS2 topic QoS와 publisher/subscriber introspection

[두 번째 과정 실습](../day-02-jetbot-turtlebot-ros2-driving/hands-on.md)에서는 ROS2 Subscribe
Twist → Differential Controller → Articulation Controller 흐름을 단계별로 확인합니다.
Topic discovery와 실제 data delivery를 구분하는 것이 핵심입니다.

## 세 번째 과정: Python scripting 최소 루프

참고 주제:

- standalone/workflow Python examples
- scene setup과 post-load callback
- simulation update loop
- deterministic reset

[세 번째 과정 실습](../day-03-python-scripting-minimum-loop/hands-on.md)에서는 object 생성,
reference, update, reset의 책임을 분리합니다. 확장 브랜치가 어떤 task를 추가하더라도
같은 시작 상태를 재현할 수 있어야 합니다.

## 네 번째 과정: ROS2 observation

참고 주제:

- ROS2 Clock publisher와 simulation time
- ROS2 Camera publisher
- RViz image/camera display
- `sensor_msgs/msg/Image`와 `CameraInfo`

[네 번째 과정 실습](../day-04-ros2-bridge-observation-pipeline/hands-on.md)에서는 `/clock`, RGB,
camera metadata가 같은 simulation timeline에서 관측되는지 확인합니다. Topic 이름만
보는 데서 멈추지 않고 sample과 timestamp까지 점검합니다.

## 공식 자료를 사용할 때의 규칙

1. 저장소의 호환 버전과 ROS2 distribution을 먼저 확인합니다.
2. 공식 예제의 절대 경로는 `$ISAAC_SIM_ROOT` 또는 `$REPO_ROOT`로 바꿉니다.
3. 특정 robot asset은 예제로만 보고 core 계약으로 고정하지 않습니다.
4. 실행 결과는 각 과정의 checkpoint 기준으로 판단합니다.
5. 링크가 바뀌어도 개념과 acceptance 기준은 repository 안에 남깁니다.
