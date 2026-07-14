# Host-first Core Design

**Status:** approved for the first milestone  
**Supersedes:** ARM64 runtime/build acceptance in the 2026-07-14 branch architecture design

## Goal

Make the current x86_64 Ubuntu host the first supported execution target for the
vendor-neutral core: ROS 2 Jazzy, Python, Astral `uv`, and a host-installed Isaac
Sim connected over DDS.

## First-milestone contract

- Tier 1 is the current x86_64 Linux host and an amd64 ROS 2 container.
- Isaac Sim stays on the host; it is not installed in the core image.
- CI builds and smoke-tests only the amd64 core image.
- QEMU, `binfmt`, ARM64 cross-builds, and ARM64 runtime claims are not completion
  requirements.
- Architecture-index and lock-file checks may remain as cheap, data-only
  portability guards. They do not constitute ARM64 runtime support.
- The core remains vendor-neutral: no Doosan or OpenArm SDK/runtime is added.

## Acceptance

1. Core and host-Isaac diagnostics pass on this machine.
2. The amd64 ROS 2 container runs with the host DDS network profile.
3. Host Isaac Sim launches through the repository launcher.
4. The container discovers exact topic `/clock` and receives one message.
5. Static checks and amd64 image smoke tests pass.

No robot hardware, motion command, branch merge, or remote push is part of this
milestone.

## Deferred branch work

OpenArm integration belongs only in `open-arm`, based on the official
[`openarm_ros2`](https://github.com/enactic/openarm_ros2/tree/main) repository and
the [OpenArm ROS 2 control guide](https://docs.openarm.dev/1.0/software/ros2/control/).
The supplied 1.0 guide is version-specific; implementation must compare it with
the current documentation before pinning dependencies. Real-hardware CAN setup
and motion require explicit user authorization.
