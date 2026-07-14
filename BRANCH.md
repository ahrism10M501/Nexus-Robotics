# doosan-robotics Branch

## Parent and synchronization

Parent: `main`. This branch temporarily starts from `refactor/core-branch-layout`
until core PR #1 merges. Merge parent updates into this branch; do not rebase it or
merge from another robot branch.

## Owns

Doosan upstream source pins and patches, driver and emulator integration, A-series
robot models, and Doosan-specific MoveIt/RViz/Gazebo profiles.

## Does not own

Core Docker/DDS behavior, OpenArm code, shared tutorial infrastructure, or OpenArm
assets. Propose a vendor-neutral interface to `main` before sharing runtime code.

## Safe start

```bash
./run.sh init
./run.sh doctor
```

Doosan runtime profile commands will be introduced only with a pinned and tested
branch-local runtime PR.

## Verification

```bash
bash tests/run_all.bash --checks
```

Run branch-local source, build, and emulator checks after the runtime PR adds them.

## Hardware safety

No command in the current branch may enable, home, or move a physical robot. Any future
hardware test requires an operator-approved manual HIL procedure.
