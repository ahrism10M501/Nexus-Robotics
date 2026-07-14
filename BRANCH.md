# openarm-tutorial Branch

## Parent and synchronization

Parent: `open-arm`. Merge updates from that parent into this branch; do not merge this
tutorial branch back into its parent or into `main`.

## Owns

OpenArm-specific learning days, reproducible launch examples, optional scene assets, and
checkpoint instructions that use the parent branch's supported runtime.

## Does not own

OpenArm drivers, CAN behavior, Docker/Compose profiles, core infrastructure, or any
Doosan content. Fix runtime defects in `open-arm` first and merge them here.

## Safe start

```bash
./run.sh init
./run.sh doctor
```

Follow only tutorial steps documented after a matching `open-arm` runtime PR has
supplied its profile and launch commands.

## Verification

```bash
bash tests/run_all.bash --checks
```

Each future lesson must include a non-transmitting checkpoint before its manual CAN or
robot step.

## Hardware safety

Tutorial text must not provide automatic enable, calibration, home, or motion commands.
Physical robot steps require a separate operator-approved HIL checklist.
