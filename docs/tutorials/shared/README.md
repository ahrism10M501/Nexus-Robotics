# 공통 튜토리얼 문서

여기 있는 문서는 여러 Day에서 반복해서 참고하는 공통 자료입니다. Day별
문서를 읽다가 공식 문서 연결, 용어, 실행 환경, dataset contract, 나중에 할
일, troubleshooting이 필요하면 이 폴더로 돌아오면 됩니다.

- [공식 튜토리얼 맵](official-tutorial-map.md):
  Day 1-10을 NVIDIA Isaac Sim 6.0.1 및 Doosan Jazzy 공식 문서와 연결합니다.
  각 공식 튜토리얼에서 무엇을 사용하고 무엇을 의도적으로 건너뛰는지 설명합니다.
- [공통 용어집](glossary.md):
  stage, prim, Action Graph, ROS2 Bridge, QoS, MoveIt2, policy process 같은
  초보자 용어를 이 프로젝트 맥락에서 설명합니다.
- [환경 설정 튜토리얼](environment-setup.md):
  host와 container 역할, `./run.sh`, `source /etc/profile.d/nexus_env.bash`,
  `colcon build`, `./scripts/launch_isaac_sim.sh`, `ROS_DOMAIN_ID=42`,
  FastDDS 사용법을 설명합니다.
- [Cube-pick v1 데이터셋과 policy interface](cube-pick-v1-dataset-policy-interface.md):
  cube-pick task의 dataset, action, replay, policy-process contract 기준입니다.
- [나중에 볼 마일스톤](later-milestones.md):
  첫 cube-pick simulation loop 이후로 미뤄 둔 주제들입니다.
- [문제 해결](troubleshooting.md):
  ROS2 topic discovery, data flow, robot motion 문제가 생겼을 때 빠르게 확인할
  항목입니다.
