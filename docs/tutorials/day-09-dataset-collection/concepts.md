# Day 9 개념

Day 9는 Day 8의 scripted cube-pick attempt를 dataset으로 바꾸는 날입니다. 여기서
dataset은 단순한 log dump가 아닙니다. 나중에 ACT나 Diffusion Policy가 배울 수 있도록
"observation을 보고 action을 선택했다"는 causality를 보존한 기록입니다.

episode는 하나의 시도 전체입니다. reset으로 시작하고, scripted 또는 human-guided
pick sequence를 진행하고, 마지막에 done과 success 판단을 남깁니다. 성공한 episode만
좋은 data가 아닙니다. 실패한 episode도 reset, action timing, label이 일관되면 model과
replay debugging에 도움이 됩니다.

가장 중요한 규칙은 observation before action입니다. control tick마다 먼저 현재 상태를
저장하고, 그다음 action을 적용합니다. 순서가 반대로 되면 data를 읽는 사람은 "이 action이
어떤 state를 보고 나온 것인지"를 헷갈리게 됩니다. Behavior Cloning, ACT, Diffusion
Policy 모두 이 pairing이 흔들리면 초반부터 어려워집니다.

Day 9 문서에는 정확한 observation/action schema나 file layout을 복사하지 않습니다.
그 정보는 아래 shared contract가 source of truth입니다:
[Cube-pick v1 데이터셋과 policy interface](../shared/cube-pick-v1-dataset-policy-interface.md).

replay는 policy test가 아니라 data-quality test입니다. 저장된 action을 순서대로 다시
적용했을 때 step count, timestamp order, final success label이 눈으로 본 결과와 맞는지
확인합니다. replay가 흔들리면 model training으로 넘어가지 않습니다. dataset이 먼저
믿을 수 있어야 policy 실패를 해석할 수 있습니다.

처음 dataset은 작게 시작합니다. 다섯 개 정도의 scripted episode면 충분합니다. 많은
data를 모으기 전에 reset, recording, metadata, replay가 같은 기준으로 움직이는지 보는
것이 더 빠르고 안전합니다.
