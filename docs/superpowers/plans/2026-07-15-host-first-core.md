# Host-first Core Execution Plan

**Goal:** prove the vendor-neutral amd64 ROS 2 core communicates with host Isaac
Sim on the current machine, without QEMU or an ARM64 runtime gate.

## 1. Correct the supported-platform contract

- Change the static contract test first so CI is required to contain only
  `static` and `build-amd64` jobs and rejects QEMU/ARM64 workflow behavior.
- Run the focused test and observe it fail against the old workflow.
- Remove the ARM64/QEMU job and update README support wording.
- Re-run the focused test and the complete static suite.

## 2. Prove the local core path

- Run `./run.sh doctor` and `./run.sh isaac-host-doctor`.
- Build/reuse the amd64 `ros-python-dev` image and start `isaac-host` detached.
- Inspect the actual container architecture, network mode, ROS distro, RMW, and
  required demo package.

## 3. Prove the host bridge

- Launch the existing host Isaac Sim installation with
  `scripts/launch_isaac_sim.sh`.
- Wait on process/readiness evidence, then run
  `scripts/check_isaac_host.bash`.
- If `/clock` is absent, diagnose extension, stage, timeline, DDS, and domain
  evidence in that order. Do not add robot-specific code or issue motion.

## 4. Verify and hand off

- Run static checks, amd64 image smoke, and `git diff --check` from a clean base.
- Record exact PASS/SKIP/failure evidence.
- Keep `main` and remotes untouched until the host acceptance is actually green
  and the user chooses integration.
