# open-arm Branch

## Parent and synchronization

Parent: `main`. This branch temporarily starts from `refactor/core-branch-layout`
until core PR #1 merges. Merge parent updates into this branch; do not rebase it or
merge from another robot branch.

## Owns

Pinned OpenArm ROS2/CAN source, OpenArm robot description and control integration,
SocketCAN/vcan separation, and OpenArm-specific MoveIt/RViz profiles.

## Does not own

Core Docker/DDS behavior, Doosan code, shared tutorial infrastructure, or inferred
hardware constants. Shared runtime needs are proposed to `main` as generic interfaces.

## Safe start

```bash
./run.sh init
./run.sh doctor
```

OpenArm profile commands will be introduced only with a pinned and tested branch-local
runtime PR.

## Verification

```bash
bash tests/run_all.bash --checks
```

Future CAN checks must use a non-transmitting virtual interface before any manual HIL.

## Hardware safety

No command in the current branch may enable, home, calibrate, or move an OpenArm. CAN
identifiers, joint limits, and safety state must come from verified upstream sources and
an operator-approved manual procedure.
