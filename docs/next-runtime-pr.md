# Next Runtime PR: Doosan Runtime

## Intended outcome

Add a pinned Doosan ROS 2 Jazzy integration, emulator support, and a branch-local,
opt-in Doosan profile without altering the vendor-neutral core runtime.

## Source and reproducibility

- Upstream: `https://github.com/DoosanRobotics/doosan-robot2.git`
- Initial inspected Jazzy commit: `816ecb5d1c2599303eaf9540216afa03552f80ad`
- Record the exact commit, license review result, and every patch as a tracked file.
- Build from the core Docker targets; do not copy the legacy coupled
  `Dockerfile.isaac-moveit` or install Isaac ROS as a Doosan side effect.

## Acceptance

```bash
./run.sh init
./run.sh doctor
bash tests/run_all.bash --checks
```

The implementation PR must add source-patch tests, a non-root image build, and a
documented emulator-only acceptance path. Hardware and emulator verification are manual
and must be clearly separated.

## Safety

No default command may enable, home, or move a physical Doosan robot. Any HIL procedure
requires an operator-approved checklist and an explicit target selection.
