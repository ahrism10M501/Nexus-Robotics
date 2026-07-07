# 튜토리얼

ROS2 Jazzy, Isaac Sim, Doosan A0912 학습 경로의 중심 문서입니다.
Day 폴더를 순서대로 따라가세요. 각 Day에는 짧은 `README.md`와
`concepts.md`, `hands-on.md`, `checkpoint.md`가 있습니다.

## 일차별 학습 경로

| Day | 튜토리얼 | 초점 |
| --- | --- | --- |
| 1 | [Isaac Sim 기본기](day-01-isaac-sim-basics/README.md) | 작은 physics scene을 만들고, robot을 살펴본 뒤 joint 하나를 움직입니다. |
| 2 | [Jetbot/TurtleBot ROS2 주행](day-02-jetbot-turtlebot-ros2-driving/README.md) | Isaac Sim을 ROS2와 연결하고 `/cmd_vel`로 mobile robot을 움직입니다. |
| 3 | [Python Scripting 최소 루프](day-03-python-scripting-minimum-loop/README.md) | Isaac Sim scripting loop를 실행하고 scene lifecycle code를 찾습니다. |
| 4 | [ROS2 Bridge 관측 파이프라인](day-04-ros2-bridge-observation-pipeline/README.md) | `/clock`, camera data를 publish하고 ROS2에서 QoS를 확인합니다. |
| 5 | [A0912 전에 배우는 로봇팔 개념](day-05-manipulator-concepts-before-a0912/README.md) | joint state, command topic, MoveIt2, simulator actuation을 배웁니다. |
| 6 | [Doosan A0912 Bringup 실행](day-06-doosan-a0912-bringup/README.md) | A0912를 virtual mode로 bringup하고 controller를 확인합니다. |
| 7 | [A0912 Scripted Motion 실행](day-07-a0912-scripted-motion/README.md) | 저속 scripted arm motion을 실행하고 policy action format을 정합니다. |
| 8 | [Cube-Pick Scene v0 만들기](day-08-cube-pick-scene-v0/README.md) | deterministic cube-pick scene을 만들고 정렬된 task state를 샘플링합니다. |
| 9 | [데이터셋 수집](day-09-dataset-collection/README.md) | 첫 cube-pick demonstration episode를 저장하고 replay합니다. |
| 10 | [Policy 연결 준비](day-10-policy-connection-preparation/README.md) | policy process 경계와 real robot safety gate를 정의합니다. |

## 공통 문서

- [공통 튜토리얼 문서](shared/README.md)
- [Cube-pick v1 데이터셋과 policy interface](shared/cube-pick-v1-dataset-policy-interface.md)
- [나중에 볼 마일스톤](shared/later-milestones.md)
- [문제 해결](shared/troubleshooting.md)

## 호환 링크

기존 bookmark가 깨지지 않도록 오래된 진입점은 index로 남겨 둡니다:

- [2주 Isaac Sim + ROS2 + A0912 온보딩](2-week-isaac-ros2-a0912-onboarding.md)
- [Cube-pick 데이터셋과 policy interface](cube-pick-dataset-interface.md)
