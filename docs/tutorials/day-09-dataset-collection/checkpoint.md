# Day 9 체크포인트

Day 9의 checkpoint는 "많은 data를 모았다"가 아니라 "작은 dataset을 믿을 수 있게
저장하고 다시 재생했다"를 확인합니다.

## 통과 기준

- Day 8 scene에서 최소 다섯 개의 scripted episode를 기록했습니다.
- 각 episode는 reset으로 시작하고 final done/success 판단으로 끝납니다.
- 모든 control tick에서 observation before action 순서를 지켰습니다.
- metadata는 episode 종료 후 실제 step count와 success result를 반영해 저장했습니다.
- 정확한 schema와 file layout은 shared contract와 맞춰 확인했습니다.
- policy process 없이 episode 하나를 replay했고, replay step count와 final label이
  recording과 맞습니다.

## 문제 해결

episode마다 시작 화면이 다르면 Day 9 recorder 문제가 아니라 Day 8 reset 문제일 수
있습니다. data를 더 모으기 전에 cube, robot, gripper, camera reset을 먼저 고칩니다.

replay가 저장된 sequence보다 짧거나 길면 final tick 처리와 done 표시 위치를 봅니다.
episode 종료 조건이 action 저장보다 먼저 실행되는지, 나중에 실행되는지 명확해야 합니다.

action과 observation이 한 step씩 밀려 보이면 저장 순서를 다시 확인합니다. 현재 state를
먼저 저장하고, 그 state에서 선택한 action을 저장한 뒤, action을 적용해야 합니다.

metadata가 episode 결과와 다르면 metadata를 recording 시작 시점에 확정해 버렸을 가능성이
있습니다. success, step count, note처럼 결과에 의존하는 값은 episode가 끝난 뒤 씁니다.

파일 이름이나 schema가 헷갈리면 Day 문서에서 추측하지 말고 shared contract를 다시
엽니다:
[Cube-pick v1 데이터셋과 policy interface](../shared/cube-pick-v1-dataset-policy-interface.md).
