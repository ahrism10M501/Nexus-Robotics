# Day 10 체크포인트

Day 10의 checkpoint는 model 성능이 아니라 구조 안전성을 확인합니다. 나중의
ACT/Diffusion policy가 들어와도 simulator, policy process, safety gate, command path가
분리되어 있어야 합니다.

## 통과 기준

- simulator가 observation을 publish 또는 collect하고 policy process가 그것을 받는다고
  설명할 수 있습니다.
- policy process가 action을 emit하고 safety gate가 그 action을 filter한다고 설명할 수
  있습니다.
- safety gate를 통과한 action만 robot command path로 갑니다.
- 현재 허용된 execution mode는 Simulation replay입니다.
- Low-speed dry-run과 Manual approval은 나중의 실제 robot 실행 전에 필요한 별도
  gate로 적혀 있습니다.
- ACT 또는 Diffusion Policy training을 구현하지 않았습니다.
- exact observation/action schema는 shared contract로만 확인합니다.

## 문제 해결

policy process가 simulator 안에 섞여 보이면 boundary를 다시 그립니다. model code는
observation을 받고 action을 반환하는 별도 process로 생각해야 교체가 쉽습니다.

safety gate가 단순한 comment로만 남아 있으면 부족합니다. action limit, workspace limit,
invalid value rejection, speed limit, execution mode check가 command path 앞에서 실행된다는
구조가 보여야 합니다.

Simulation replay가 아직 실패하면 real robot gate를 논의하기 전에 Day 9 replay를 먼저
고칩니다. replay가 흔들리는 상태에서는 policy output도 검증할 수 없습니다.

Low-speed dry-run이 실제 robot motion을 만들 수 있다면 logging-only로 시작합니다. tiny
motion도 workspace check, emergency stop check, speed scaling, operator readiness가 있어야
합니다.

Manual approval이 "나중에 사람이 보면 됨" 정도로 적혀 있으면 기준이 약합니다. operator,
workspace, emergency stop, speed scaling이 모두 명시되어야 합니다.
