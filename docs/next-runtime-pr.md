# Next Runtime PR: Generic Isaac Sim + MoveIt

## Intended outcome

Add an opt-in, vendor-neutral planning and simulation path on top of the host Isaac DDS
contract already supplied by the core. It must be usable with a documented generic test
model and must not depend on Doosan or OpenArm packages.

## Required implementation boundary

- Add MoveIt packages only to a dedicated image target or an explicit Compose profile.
- Keep Isaac Sim on the host; do not clone or install Isaac Sim workspaces in Docker.
- Accept a robot description and planning configuration through documented, generic inputs.
- Keep GPU, GUI, and host-network privileges opt-in.

## Acceptance

```bash
./run.sh init
./run.sh isaac-host-doctor
bash tests/run_all.bash --checks
```

The runtime PR must add an automated `move_group` startup check against the chosen
generic model. A host Isaac observation check remains non-destructive:
`bash scripts/check_isaac_host.bash`.

## Exclusions and safety

Do not add a vendor driver, robot-specific URDF/USD, hardware transport, or physical
motion command. A real robot integration belongs in its matching robot branch.
