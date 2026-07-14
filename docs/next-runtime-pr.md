# Next Runtime PR: OpenArm Runtime

## Intended outcome

Add a pinned OpenArm ROS 2 integration and a safe SocketCAN boundary on this branch,
using the OpenArm documentation as the operational reference while retaining the
vendor-neutral core unchanged.

## Source and reproducibility

- Upstream: `https://github.com/enactic/openarm_ros2.git`
- Initial inspected main commit: `4e837e1d0dae692ff67b560b69d8d281d7a8d4ed`
- Control reference: `https://docs.openarm.dev/1.0/software/ros2/control/`
- Record the exact source commit, license terms, package list, and every local patch.
- Keep virtual CAN and real CAN configuration separate.

## Acceptance

```bash
./run.sh init
./run.sh doctor
bash tests/run_all.bash --checks
```

The implementation PR must add non-transmitting vcan checks and build/import checks
before documenting any manual device procedure. It must not assume CAN IDs, joint
limits, calibration data, or safety state from incomplete documentation.

## Safety

No default command may enable, calibrate, home, or move an OpenArm. Real CAN and robot
control remain manual, operator-approved HIL actions.
