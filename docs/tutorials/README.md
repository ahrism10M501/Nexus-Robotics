# ROS2 Jazzy + Host Isaac Sim 튜토리얼

이 인덱스는 vendor-neutral core 과정과 로봇별 확장 과정의 소유권을 나눕니다.
`main`에는 모든 확장이 공통으로 재사용하는 기초 과정만 둡니다.

## Core 과정

| 순서 | 과정 | 결과 |
| --- | --- | --- |
| 1 | [Isaac Sim 기본기](day-01-isaac-sim-basics/README.md) | stage, prim, physics, articulation을 설명합니다. |
| 2 | [Jetbot/TurtleBot ROS2 주행](day-02-jetbot-turtlebot-ros2-driving/README.md) | ROS2 velocity command가 simulation motion으로 이어집니다. |
| 3 | [Python Scripting 최소 루프](day-03-python-scripting-minimum-loop/README.md) | scene 생성, update, reset 흐름을 코드로 읽습니다. |
| 4 | [ROS2 Bridge 관측 파이프라인](day-04-ros2-bridge-observation-pipeline/README.md) | `/clock`, RGB, camera metadata를 ROS2에서 관측합니다. |

시작하기 전에 [공통 환경 설정](shared/environment-setup.md)을 확인하고, 각 과정의
개념 → 실습 → 체크포인트 순서로 진행합니다.

## 확장 과정 소유권

Days 5-10은 `main`에 두지 않습니다.

- `doosan-tutorial`: `doosan-robotics` 통합을 기반으로 한 Days 5-10
- `openarm-tutorial`: `open-arm` 통합을 기반으로 한 Days 5-10

필요한 로봇을 선택해 해당 브랜치로 전환한 뒤 그 브랜치의 이 인덱스를 따릅니다.
Core 문서가 특정 vendor의 SDK, service 이름 또는 runtime 경로를 전제해서는 안 됩니다.

## 공통 참고

- [공통 문서 안내](shared/README.md)
- [공식 튜토리얼 연결](shared/official-tutorial-map.md)
- [용어집](shared/glossary.md)
- [문제 해결](shared/troubleshooting.md)
