# Core 튜토리얼 문제 해결

문제가 생기면 scene, process, discovery, data, control 순서로 범위를 좁힙니다.

## 환경 진단

```bash
cd "$REPO_ROOT"
./run.sh doctor
./run.sh status
```

`.env`가 없거나 잘못되었으면 `./run.sh init`으로 다시 생성하고 local 값만 수정합니다.
Docker daemon, Compose, BuildKit 오류는 simulator 문제와 분리해 먼저 해결합니다.

## Host Isaac Sim이 실행되지 않음

```bash
./run.sh isaac-host-doctor
```

`$ISAAC_SIM_ROOT/isaac-sim.sh`의 존재와 실행 권한, `$ISAAC_SIM_ROOT/VERSION`, NVIDIA
probe 결과를 확인합니다. Launcher는 설치나 download를 대신하지 않습니다.

## ROS2 topic이 보이지 않음

1. Isaac Sim ROS2 Bridge extension이 enable인지 확인합니다.
2. Host와 container의 `ROS_DOMAIN_ID`가 같은지 확인합니다.
3. 두 process가 `rmw_fastrtps_cpp`와 같은 FastDDS profile을 읽는지 확인합니다.
4. Action Graph가 Play tick과 ROS2 context에 연결됐는지 확인합니다.

```bash
ros2 topic list
ros2 topic info -v /clock
```

## Topic은 보이지만 sample이 없음

Discovery와 data delivery는 다릅니다. QoS를 확인하고 host/container 모두
`$REPO_ROOT/config/fastdds.xml`에 대응하는 profile을 읽는지 확인합니다. FastDDS profile은
process 시작 때 읽히므로 변경 뒤에는 두 process를 명시적으로 재시작합니다.

자세한 사례는 [FastDDS 문제 해결 기록](../../troubleshooting/2026-07-07-isaacsim-ros2-bridge-fastdds.md)을
참고합니다.

## Bridge acceptance

실행 중인 환경을 변경하지 않고 `/clock`을 확인합니다.

```bash
bash scripts/check_isaac_host.bash
```

- `PASS`: topic과 sample 관측 성공
- 종료 코드 `77`의 `SKIP E_PREREQUISITE`: host 조건 없음
- `FAIL E_PREREQUISITE`: 조건이 갖춰진 환경의 blocking failure

검사 자체는 container나 simulator lifecycle을 변경하지 않습니다.

## Robot이 움직이지 않음

ROS2 command → bridge subscriber → controller output → articulation target 순서로 runtime
값을 확인합니다. 큰 command로 반응을 강제하지 말고 joint/velocity limit 안의 작은 값과
명시적인 stop command를 사용합니다.

## Image가 RViz에서 보이지 않음

Image topic과 camera metadata topic의 type, QoS, timestamp를 각각 확인합니다. RViz의
Fixed Frame과 `use_sim_time`도 같은 simulation graph에 맞춰야 합니다.
