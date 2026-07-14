# Core 이후 확장 이정표

Core 과정을 마친 뒤의 작업은 robot 통합 또는 튜토리얼 브랜치가 소유합니다. 이 문서는
구체 robot이나 일정 번호를 고정하지 않고 확장 순서의 원칙만 설명합니다.

## 1. Simulation bringup

먼저 virtual mode에서 model, joint state, controller state를 관측합니다. Motion을
추가하기 전에 launch와 shutdown이 반복 가능하고 실패가 명확해야 합니다.

## 2. 작은 scripted motion

알려진 시작 상태에서 낮은 속도의 짧은 command를 실행합니다. Policy나 외부 service를
연결하기 전에 command path와 stop behavior를 독립적으로 검증합니다.

## 3. Deterministic task scene

Robot, object, sensor, reference frame의 prim 이름과 초기 pose를 코드로 고정합니다.
Reset 후 같은 checkpoint를 재현하지 못하면 dataset 수집으로 진행하지 않습니다.

## 4. Dataset과 replay

Observation/action schema, timestamps, units, episode metadata를 versioned contract로
정의합니다. 학습 전에 수집한 episode를 replay해 입력과 상태 전이가 일치하는지
검증합니다.

## 5. Policy integration

Policy output을 곧바로 controller에 연결하지 않습니다. Schema validation, range clamp,
timeout, stale input, emergency stop과 dry-run 계층을 먼저 둡니다.

## 6. Hardware promotion

Simulation acceptance만으로 hardware 실행을 허용하지 않습니다. Robot별 safety 문서,
operator 승인, workspace 제한, 속도/힘 제한과 independent stop path를 확장 브랜치에
명시합니다.

두 확장에서 공통으로 검증된 도구만 vendor-neutral 형태로 core에 제안합니다.
