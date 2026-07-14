# Core 튜토리얼 용어집

## Isaac Sim과 USD

### Stage

USD scene 전체입니다. Robot, ground, light, sensor와 graph가 하나의 stage 안에 있습니다.

### Prim

Stage tree의 주소를 가진 구성 요소입니다. Script와 graph는 화면 모양보다 prim path를
통해 object를 찾으므로 이름과 위치가 안정적이어야 합니다.

### Rigid body / Collider / Mass

Rigid body는 physics로 움직이는 물체, collider는 contact shape, mass는 관성 계산에
쓰이는 질량입니다. 화면에 mesh가 보이는 것만으로 physics interaction이 생기지는 않습니다.

### Articulation / Joint drive

Articulation은 joint로 연결된 link 집합입니다. Joint drive는 target position 또는
velocity를 실제 physics motion으로 바꾸는 제어 요소입니다.

### Action Graph

Tick, ROS2 message, controller 같은 node를 연결하는 실행 graph입니다. 연결선뿐 아니라
timeline과 runtime output도 함께 확인해야 합니다.

### Simulation time / Reset

Simulation time은 world step에 맞춰 진행되는 시간입니다. Reset은 scene과 controller를
알려진 시작 상태로 되돌려 실험을 반복 가능하게 만듭니다.

## ROS2

### Node / Topic / Message

Node는 ROS2 실행 단위, topic은 publish/subscribe channel, message는 그 channel의 data
type입니다. Topic 이름이 보여도 QoS나 transport 문제로 sample이 전달되지 않을 수 있습니다.

### QoS

Reliability, durability, history와 queue depth 같은 통신 정책입니다. Publisher와 subscriber의
정책이 호환되어야 합니다.

### ROS domain

같은 domain id를 쓰는 ROS2 participant가 discovery되는 논리적 경계입니다. Core 기본값은
`.env`의 `ROS_DOMAIN_ID`가 결정합니다.

### RMW / DDS

RMW는 ROS2 middleware 추상화이고 DDS는 이 환경의 discovery와 data transport를 담당합니다.
Core는 FastDDS와 repository의 UDP profile을 사용합니다.

### `/cmd_vel`

Mobile robot에 linear/angular velocity를 요청할 때 흔히 쓰는 topic입니다. Pose goal이
아니며 반복 publish와 명시적인 zero stop을 함께 고려합니다.

### `/clock`과 `use_sim_time`

`/clock`은 simulator가 publish하는 simulation time입니다. ROS2 node가
`use_sim_time=true`이면 wall clock 대신 이 값을 사용합니다.

### Observation

Sensor image, camera metadata, joint state, simulation time처럼 현재 상태를 설명하는 data입니다.
확장 브랜치는 observation의 shape, unit, ordering을 별도 계약으로 정의해야 합니다.

## Repository 환경

### `$REPO_ROOT`

Clone한 repository의 절대 경로를 담는 shell 변수입니다. 문서는 개인 home 경로 대신
이 변수를 사용합니다.

### `$ISAAC_SIM_ROOT`

Host Isaac Sim 설치 디렉터리입니다. Core launcher는 이 경로의 `isaac-sim.sh`와
`VERSION`을 검증하며 설치 자체를 변경하지 않습니다.

### Core profile

ROS2 Jazzy, Python, `uv` 개발 환경을 제공하는 기본 profile입니다. Robot별 runtime을
포함하지 않습니다.

### Isaac-host profile

Core service에 host-network DDS overlay를 적용하는 profile입니다. Host Isaac Sim은
container 밖에서 실행됩니다.
