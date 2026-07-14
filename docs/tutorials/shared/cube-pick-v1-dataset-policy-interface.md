# Dataset/Policy 확장 handoff

Core는 특정 robot의 cube-pick dataset schema나 policy action format을 소유하지
않습니다. 이 문서는 확장 브랜치가 그런 계약을 추가할 때 지켜야 할 경계만 정의합니다.

## Core가 제공하는 입력

- simulation time과 `/clock`
- RGB image와 camera metadata를 관측하는 방법
- deterministic scene setup/reset 개념
- ROS2 topic과 QoS를 점검하는 방법
- Python 및 `uv` 기반 실행 환경

## 확장 브랜치가 정의할 항목

- robot identity, joint ordering, units와 limits
- observation tensor와 action schema
- scene prim naming과 reset state
- episode 시작/종료 조건
- artifact version, provenance, replay 검증
- 실제 또는 simulated controller에 대한 safety gate

이 항목은 robot마다 달라질 수 있으므로 core의 공통 파일에 구체 값을 넣지 않습니다.

## 최소 호환성 원칙

확장 계약은 다음 질문에 명시적으로 답해야 합니다.

1. Observation과 action의 shape, dtype, unit은 무엇인가?
2. Joint 순서와 frame은 어디에서 고정되는가?
3. Missing sample, timeout, stale timestamp를 어떻게 처리하는가?
4. 같은 episode를 replay해 같은 초기 상태를 만들 수 있는가?
5. Schema version이 다른 artifact를 어떻게 거부하는가?
6. Hardware action을 허용하기 전에 어떤 독립 검증을 통과해야 하는가?

## Core로 올릴 수 있는 변경

둘 이상의 robot 확장에서 동일하게 필요하고 vendor 이름이나 SDK에 의존하지 않는
기능만 core 후보입니다. 승격할 때는 기존 core profile과 문서가 특정 extension을
필수로 요구하지 않는지 static contract로 검증합니다.

구체 schema의 원본은 해당 튜토리얼 브랜치가 보존하고 유지합니다.
