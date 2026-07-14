# Core 튜토리얼 공통 문서

이 디렉터리는 모든 로봇별 확장이 공유하는 vendor-neutral 기초만 설명합니다.

- [환경 설정](environment-setup.md): core container와 host Isaac Sim 연결
- [공식 튜토리얼 연결](official-tutorial-map.md): core 과정별 공식 학습 자료
- [용어집](glossary.md): stage, ROS2, observation의 공통 언어
- [문제 해결](troubleshooting.md): 환경, DDS, graph 점검 순서
- [Dataset/policy handoff](cube-pick-v1-dataset-policy-interface.md): 확장 브랜치가 정의할 경계
- [후속 이정표](later-milestones.md): core 이후 확장의 설계 원칙

로봇 모델, SDK, controller, dataset schema의 구체 구현은 해당 확장 브랜치가
소유합니다. Core 문서는 그 구현을 미리 가정하지 않습니다.
