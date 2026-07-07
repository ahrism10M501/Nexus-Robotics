# 나중에 볼 마일스톤

이 문서는 첫 cube-pick curriculum에서 일부 주제를 왜 뒤로 미루는지 설명합니다.
미루는 이유는 중요하지 않아서가 아니라, 초보자가 Day 1-10에서 먼저 익혀야 할
핵심 경로가 있기 때문입니다. 지금의 중심은 작은 cube-pick simulation loop,
dataset 저장, replay, policy process contract입니다.

## Custom Isaac Lab Environment 만들기

왜 지금은 미루는가: 처음부터 Isaac Lab environment를 직접 만들면 scene 구성,
reset logic, reward 또는 success condition, parallel rollout 구조를 한꺼번에 배워야
합니다. 아직 ROS2 Bridge, A0912 control path, dataset episode shape가 안정되지 않은
상태에서는 어디서 문제가 생겼는지 분리하기 어렵습니다.

언제 다시 보는가: `dataset_v0`가 저장과 replay를 통과하고, `sim_eval_v0`에서 같은
policy를 여러 초기 cube pose로 반복 평가하고 싶어질 때 다시 봅니다. 그때는 custom
environment가 반복 실험을 정리하는 도구가 됩니다.

## 대규모 Parallel Training

왜 지금은 미루는가: large-scale parallel training은 작은 dataset 문제가 해결된 뒤에야
의미가 있습니다. observation/action timestamp가 어긋나거나 `success` label이 틀린
상태에서 worker 수만 늘리면, 더 빠르게 잘못된 결과를 만들 뿐입니다.

언제 다시 보는가: 단일 simulation에서 replay와 evaluation이 안정되고, Behavior Cloning,
ACT, Diffusion Policy 중 최소 하나가 같은 episode format으로 반복 학습될 때 다시 봅니다.
그 시점에는 속도와 sample 수가 실제 병목인지 판단할 수 있습니다.

## Instanceable Asset 최적화

왜 지금은 미루는가: instanceable asset은 많은 object를 효율적으로 배치할 때 유용하지만,
첫 cube-pick scene에는 cube, table, robot, camera 정도만 필요합니다. 초반에는 asset
최적화보다 prim path, rigid body, collider, articulation 관계를 눈으로 확인하는 것이 더
중요합니다.

언제 다시 보는가: cube 종류가 늘어나거나 cluttered scene을 만들고, 같은 asset을 수십
개 이상 반복 배치해야 할 때 다시 봅니다. performance가 scene 복잡도 때문에 떨어진다는
증거가 있을 때가 적절한 시점입니다.

## Digital Twin 작업장 Workflow

왜 지금은 미루는가: Digital Twin warehouse workflow는 layout, sensor placement,
asset pipeline, operations scenario까지 포함하는 큰 주제입니다. 지금은 A0912가 작은
cube 하나를 안전하게 집고 내려놓는 path를 이해하는 단계이므로 warehouse scale의
맥락을 넣으면 학습 초점이 흐려집니다.

언제 다시 보는가: cube-pick이 안정되고, robot 주변 workspace를 실제 작업장 구조와
맞춰야 할 필요가 생길 때 다시 봅니다. 예를 들어 real cell layout, camera calibration,
fixture 위치를 simulation에 반영해야 한다면 Digital Twin 흐름이 필요합니다.

## Custom OmniGraph Node 만들기

왜 지금은 미루는가: 기본 Action Graph node와 Python scripting만으로도 ROS2 topic,
camera publish, controller command path를 확인할 수 있습니다. custom OmniGraph node를
일찍 만들면 node build, packaging, graph API 문제와 tutorial의 핵심 문제가 섞입니다.

언제 다시 보는가: 기존 node 조합이나 Python script로는 매 tick에 필요한 data transform을
깔끔하게 표현하기 어렵고, 같은 logic을 여러 graph에서 반복하게 될 때 다시 봅니다. 그때는
custom node가 유지보수 비용을 줄이는 선택이 됩니다.

## Real Robot Learned-Policy 실행

왜 지금은 미루는가: learned policy output은 예측값이지 안전한 robot command가 아닙니다.
simulation replay, low-speed dry run, manual approval, workspace check, emergency stop
check가 준비되지 않으면 real robot에 연결하면 안 됩니다.

언제 다시 보는가: `real_dry_run_v0`에서 policy action이 real command path를 통해 logging만
되고, safety layer가 non-finite value, workspace 밖 command, excessive speed를 확실히
reject한다는 증거가 있을 때 다시 봅니다. 그 전까지는 real robot learned-policy execution을
목표가 아니라 later milestone로 남겨 둡니다.
