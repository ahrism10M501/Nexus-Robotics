# isaac-moveit Branch

## Parent and synchronization

Parent: `main`. During core PR #1 review, this branch temporarily starts from
`refactor/core-branch-layout`; after that PR is merged the common commit is in
`main`. Merge parent updates into this branch; do not rebase this public branch.

## Owns

Vendor-neutral Isaac Sim and MoveIt integration, opt-in simulation profiles, generic
planning examples, and their no-hardware checks.

## Does not own

Doosan/OpenArm SDKs, robot-specific URDF/USD assets, controller configuration, CAN
setup, or hardware enable/control flows.

## Safe start

```bash
./run.sh init
./run.sh isaac-host-doctor
./run.sh isaac-host-dev
```

## Verification

```bash
bash tests/run_all.bash --checks
bash scripts/check_isaac_host.bash
```

The second command is an observational host acceptance check and may return `77`
when Isaac Sim prerequisites are absent.

## Hardware safety

This branch does not command a physical robot. Future simulation work must not add a
vendor driver or a hardware transport as a convenience dependency.
