# doosan-tutorial Branch

## Parent and synchronization

Parent: `doosan-robotics`. Merge updates from that parent into this branch; do not
merge this tutorial branch back into its parent or into `main`.

## Owns

Doosan-specific learning days, reproducible launch examples, optional scene assets, and
checkpoint instructions that use the parent branch's supported runtime.

## Does not own

Doosan drivers, emulator behavior, Docker/Compose profiles, core infrastructure, or any
OpenArm content. Fix runtime defects in `doosan-robotics` first and merge them here.

## Safe start

```bash
./run.sh init
./run.sh doctor
```

Follow only tutorial steps documented after a matching `doosan-robotics` runtime PR
has supplied its profile and launch commands.

## Verification

```bash
bash tests/run_all.bash --checks
```

Each future lesson must include a no-hardware checkpoint before its manual emulator or
robot step.

## Hardware safety

Tutorial text must not provide automatic enable, home, or motion commands. Physical robot
steps require a separate operator-approved HIL checklist.
