# Day 10: Policy 연결 준비

오늘의 목표는 나중의 ACT/Diffusion policy를 어디에 붙일지 구조 경계를
정하는 것입니다. training은 하지 않습니다. simulator가 observation을 모으고, policy
process가 action을 내고, safety gate가 action을 거른 뒤 robot command path로 보내는
흐름을 말로 설명할 수 있으면 됩니다.

공통 실행 환경:
[환경 설정 튜토리얼](../shared/environment-setup.md)

policy boundary의 기준:
[Cube-pick v1 데이터셋과 policy interface](../shared/cube-pick-v1-dataset-policy-interface.md)

읽는 순서:

1. [개념](concepts.md)
2. [실습](hands-on.md)
3. [체크포인트](checkpoint.md)

이전: [Day 9: 데이터셋 수집](../day-09-dataset-collection/README.md)

다음: [공통 튜토리얼 문서](../shared/README.md)
