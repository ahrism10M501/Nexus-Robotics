# Isaac Sim ROS2 Bridge가 Docker ROS2 Twist를 받지 못한 문제

Date: 2026-07-07

## Context

Isaac Sim은 host에서 실행하고, ROS2 Jazzy와 Python/AI 의존성은 Docker 컨테이너에서 실행한다.
컨테이너는 workspace를 volume mount하고, ROS2 통신을 위해 host network를 사용한다.

관련 구성:

- Isaac Sim: host process
- ROS2 publisher: Docker container
- ROS domain: `42`
- RMW: `rmw_fastrtps_cpp`
- Topic: `/cmd_vel`
- Message type: `geometry_msgs/msg/Twist`
- Isaac Action Graph node: `isaacsim.ros2.bridge.ROS2SubscribeTwist`

## Symptoms

컨테이너에서 `/cmd_vel`을 publish했다.

```bash
ros2 topic pub /cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: 0.2, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.5}}" \
  -r 10
```

다른 ROS2 터미널에서는 `ros2 topic echo /cmd_vel`이 정상적으로 메시지를 받았다.
하지만 Isaac Sim 내부 Action Graph의 `ROS2 Subscribe Twist` 출력은 계속 0이었다.

Script Editor에서 runtime output을 직접 읽어도 값이 바뀌지 않았다.

```python
import asyncio
import numpy as np
import omni.kit.app
import omni.graph.core as og
import omni.timeline

GRAPH = "/World/ActionGraph_01"
LIN = f"{GRAPH}/ros2_subscribe_twist.outputs:linearVelocity"
ANG = f"{GRAPH}/ros2_subscribe_twist.outputs:angularVelocity"

omni.timeline.get_timeline_interface().play()

async def monitor():
    prev = None
    for _ in range(300):
        lin = og.Controller.get(og.Controller.attribute(LIN))
        ang = og.Controller.get(og.Controller.attribute(ANG))

        lin_s = lin.tolist() if isinstance(lin, np.ndarray) else lin
        ang_s = ang.tolist() if isinstance(ang, np.ndarray) else ang

        now = (str(lin_s), str(ang_s))
        if now != prev:
            print("Twist runtime:", "linear=", lin_s, "angular=", ang_s)
            prev = now

        await omni.kit.app.get_app().next_update_async()

asyncio.ensure_future(monitor())
```

## Evidence

`ros2 topic info -v /cmd_vel`에서 Isaac Sim subscriber는 discovery되었다.

```text
Publisher count: 0
Subscription count: 1
Reliability: RELIABLE
Durability: VOLATILE
```

Action Graph JSON dump에서도 핵심 wiring은 맞았다.

```text
ROS2Context.outputs:context
  -> ROS2SubscribeTwist.inputs:context

OnPlaybackTick.outputs:tick
  -> ROS2SubscribeTwist.inputs:execIn

ROS2SubscribeTwist.outputs:linearVelocity
  -> BreakVector3.inputs:tuple

ROS2SubscribeTwist.outputs:angularVelocity
  -> BreakVector3.inputs:tuple
```

따라서 문제는 topic name, ROS domain, graph wiring, QoS mismatch보다는 DDS transport 쪽일 가능성이 높았다.

## Root Cause

FastDDS 기본 transport가 host Isaac Sim process와 Docker container 사이에서 shared-memory transport를 선택하면서,
DDS discovery는 되지만 실제 data sample이 Isaac Sim 쪽 `ROS2SubscribeTwist` node까지 전달되지 않았다.

핵심 포인트:

- Discovery가 된다고 data delivery까지 보장되는 것은 아니다.
- `ros2 topic echo`가 컨테이너 또는 다른 ROS2 process에서 된다고 Isaac Sim Action Graph subscriber가 받는 것도 아니다.
- Docker와 host process가 섞인 구성에서는 FastDDS shared-memory transport가 discovery/data path를 다르게 망가뜨릴 수 있다.
- `network_mode: host`와 `ipc: host`만으로 항상 해결되지는 않는다.

## Fix

FastDDS profile을 UDP-only로 고정했다.

[config/fastdds.xml](../../config/fastdds.xml):

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<profiles xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
  <transport_descriptors>
    <transport_descriptor>
      <transport_id>udp_transport</transport_id>
      <type>UDPv4</type>
    </transport_descriptor>
  </transport_descriptors>

  <participant profile_name="default_participant" is_default_profile="true">
    <rtps>
      <useBuiltinTransports>false</useBuiltinTransports>
      <userTransports>
        <transport_id>udp_transport</transport_id>
      </userTransports>
    </rtps>
  </participant>
</profiles>
```

컨테이너와 Isaac Sim 양쪽에서 같은 profile을 읽도록 환경변수를 설정했다.
구버전/신버전 호환을 위해 두 이름을 모두 사용한다.

```bash
FASTDDS_DEFAULT_PROFILES_FILE=/workspace/config/fastdds.xml
FASTRTPS_DEFAULT_PROFILES_FILE=/workspace/config/fastdds.xml
```

Host Isaac Sim launcher에서는 workspace path를 사용한다.

```bash
FASTDDS_DEFAULT_PROFILES_FILE=$REPO_ROOT/config/fastdds.xml
FASTRTPS_DEFAULT_PROFILES_FILE=$REPO_ROOT/config/fastdds.xml
```

변경된 파일:

- [config/fastdds.xml](../../config/fastdds.xml)
- [compose.yml](../../compose.yml)
- [docker/nexus_env.bash](../../docker/nexus_env.bash)
- [scripts/launch_isaac_sim.sh](../../scripts/launch_isaac_sim.sh)

## Required Restart

FastDDS profile은 process 시작 시점에 읽힌다.
파일만 바꾼 뒤에는 반드시 Docker container와 Isaac Sim을 둘 다 재시작해야 한다.

```bash
./run.sh isaac-host-down
./run.sh isaac-host-up
```

Isaac Sim은 완전히 종료한 뒤 host에서 다시 실행한다.

```bash
./scripts/launch_isaac_sim.sh
```

## Verification

먼저 실행 중인 host Isaac Sim과 core 컨테이너 사이의 bridge를 변경 없이 점검한다.

```bash
cd "$REPO_ROOT"
bash scripts/check_isaac_host.bash
```

- `PASS`와 `/clock observed`가 나오면 bridge가 정상이다.
- Isaac Sim 또는 NVIDIA host 조건이 없으면 `SKIP E_PREREQUISITE`와 종료 코드 `77`이 나온다.
- 조건이 갖춰진 host에서 `FAIL E_PREREQUISITE`가 나오면 blocking failure로 처리하고 안내된
  조치를 수행한다.

이 검사는 container나 simulator를 시작·종료하지 않고 현재 상태만 읽는다.

컨테이너 내부에서 환경변수를 확인한다.

```bash
env | grep -E 'ROS_DOMAIN_ID|RMW_IMPLEMENTATION|FASTDDS|FASTRTPS'
```

기대값:

```text
ROS_DOMAIN_ID=42
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
FASTDDS_DEFAULT_PROFILES_FILE=/workspace/config/fastdds.xml
FASTRTPS_DEFAULT_PROFILES_FILE=/workspace/config/fastdds.xml
```

Twist를 publish한다.

```bash
ros2 topic pub /cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: 0.2, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.5}}" \
  --qos-reliability reliable \
  --qos-durability volatile \
  --qos-depth 10 \
  -r 10
```

Isaac Sim Script Editor monitor에서 다음처럼 0이 아닌 값이 찍히면 성공이다.

```text
Twist runtime: linear= [0.2, 0.0, 0.0] angular= [0.0, 0.0, 0.5]
```

## Notes

이번 문제에서 `qosProfile`이 비어 있는 것은 직접 원인이 아니었다.
`ROS2SubscribeTwist` node는 `qosProfile`이 비어 있으면 `queueSize` 기반 기본 QoS를 사용한다.

Action Graph에서 값이 안 보일 때는 UI의 정적 property만 보지 말고,
`og.Controller.get()`으로 runtime output을 직접 읽는 것이 좋다.

로봇이 움직이지 않는 문제와 Twist를 못 받는 문제는 분리해서 봐야 한다.
Twist가 들어오더라도 `DifferentialController.inputs:maxLinearSpeed`, wheel joint 이름,
`IsaacArticulationController.inputs:targetPrim` 설정이 틀리면 로봇은 움직이지 않을 수 있다.
