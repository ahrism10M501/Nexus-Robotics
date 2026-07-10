# Team-Shared ROS2 Development Environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a clean Ubuntu 24.04 x86_64 clone provide a safe, non-root, CPU/headless ROS2 development environment with opt-in GPU, X11, host DDS, Doosan, and full profiles, backed by reproducible inputs, onboarding documentation, and CI verification.

**Architecture:** Replace the duplicated Dockerfiles with one named-target Dockerfile and focused installer scripts. Keep `compose.yml` safe by default and add narrowly scoped override files that `run.sh` assembles into named presets. Centralize local configuration, host diagnostics, X11 authorization, static contracts, and smoke tests so documentation and CI exercise the same interfaces.

**Tech Stack:** Docker BuildKit, Docker Compose v2.30+, Bash, ROS2 Jazzy, FastDDS, uv, GitHub Actions, jq, xmllint, ShellCheck.

## Global Constraints

- Official host support is Ubuntu 24.04 LTS on x86_64.
- CPU/headless `ros2_dev` must work without NVIDIA Container Toolkit, X11, host PID/IPC/network, or Docker socket.
- Runtime containers use a non-root `developer` identity mapped to `LOCAL_UID` and `LOCAL_GID`.
- GPU, GUI, host DDS, Doosan, full, and trusted emulator privileges are opt-in.
- `doosan_dev`, `full_dev`, and every VS Code Dev Container must not mount `/var/run/docker.sock`.
- Existing public `run.sh` commands remain available; `moveit-*` remain aliases of `full-*`.
- Preserve current user changes and never use destructive Git restoration commands.
- Do not overwrite `.env`, `data/`, `checkpoints/`, or locally generated ROS build outputs.
- Do not select a repository license in this cycle.
- Do not claim actual model training, digital-twin asset production, or real-robot control.
- Pin the following immutable sources:
  - `osrf/ros:jazzy-desktop@sha256:1d6f898b6ab77636c40f26298070ad3de5a9e06f0a71cf9ab066fd6b7838f151`
  - `ghcr.io/astral-sh/uv:0.8.3@sha256:88baae1f9fa298996f8313e44559163c535937406d217f1c8ac9d4b86a2020fd`
  - Doosan `816ecb5d1c2599303eaf9540216afa03552f80ad`
  - Isaac ROS workspace `dd3eeede7912755996a18f4884285d9f50843f79`
  - emulator `doosanrobot/dsr_emulator:3.0.1@sha256:878b8557dfa2ffd843674e42576fd015b803cc805fe698156eb7b743e71547e9`

---

## File Structure

### Build and dependency files

- `Dockerfile`: single source of named targets `ros-base`, `ros-dev`, `ros-ai-dev`, `doosan-dev`, and `full-dev`.
- `docker/versions.env`: repository-owned immutable image and Git references.
- `docker/requirements/ai.in`: direct AI dependency constraints.
- `docker/requirements/ai.lock`: generated hash-locked transitive dependencies.
- `docker/install_doosan.bash`: fetch, resolve, rosdep, and build the pinned Doosan workspace.
- `docker/install_isaac_ros.bash`: fetch submodules, install dependencies, and build the pinned Isaac ROS workspace.
- `docker/nexus_env.bash`: source ROS, vendor overlays, optional venv, and the local workspace in deterministic order.
- `.dockerignore`: exclude Git metadata, secrets, build products, data, checkpoints, caches, and editor state.
- `.env.example`: documented local runtime values; never consumed as a secret file.

### Compose and runtime interfaces

- `compose.yml`: safe CPU/headless services and named build targets.
- `compose/host-dds.yml`: host network only for services that need host Isaac/DDS.
- `compose/gpu.yml`: GPU reservation and narrow NVIDIA capabilities.
- `compose/gui.yml`: read-only X11 socket and generated Xauthority mount.
- `compose/trusted-emulator.yml`: explicit root-equivalent vendor runner and no general development shell.
- `run.sh`: stable public command dispatcher.
- `scripts/lib/config.bash`: safe `.env` loading, validation, and init behavior.
- `scripts/lib/compose.bash`: preset-to-files/service/profile mapping.
- `scripts/doctor.bash`: host and optional profile diagnostics.
- `scripts/x11.bash`: Xauthority lifecycle.
- `scripts/smoke_container.bash`: runtime ownership and ROS smoke assertions.

### Dev Containers and CI

- `.devcontainer/devcontainer.json`: base non-root Dev Container.
- `.devcontainer/doosan/devcontainer.json`: Doosan non-root Dev Container without Docker socket.
- `.devcontainer/doosan/compose.yml`: Doosan profile reset only.
- `.devcontainer/full/devcontainer.json`: full non-root Dev Container.
- `.devcontainer/full/compose.yml`: full profile reset only.
- `.github/workflows/dev-environment.yml`: PR/push static, build, and CPU smoke workflow.
- `.github/workflows/heavy-images.yml`: manual Doosan/full build workflow.

### Tests and documentation

- `tests/helpers/assert.bash`: shell assertion library.
- `tests/test_init.bash`: environment initialization tests.
- `tests/test_doctor.bash`: host/profile diagnostic tests.
- `tests/test_presets.bash`: Compose command and privilege contract tests.
- `tests/test_static_contract.bash`: versions, Dockerfile, links, path, and configuration contracts.
- `tests/run_all.bash`: deterministic test entry point.
- `scripts/check_dev_workflow.sh`: user-facing static verification wrapper.
- `docs/onboarding/*.md`: canonical onboarding set.
- `README.md`, `docs/tutorials/**/*.md`, `docs/troubleshooting/*.md`: migrated commands and paths.

---

### Task 1: Add immutable repository and environment contracts

**Files:**
- Create: `.dockerignore`
- Create: `.env.example`
- Create: `docker/versions.env`
- Create: `docker/requirements/ai.in`
- Create: `docker/requirements/ai.lock`
- Create: `tests/helpers/assert.bash`
- Create: `tests/test_static_contract.bash`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: immutable values in Global Constraints.
- Produces: `docker/versions.env`, the two-file AI dependency contract, `assert_file`, `assert_contains`, `assert_not_contains`, and a static test executable used by later tasks.

- [ ] **Step 1: Create the assertion helper and failing repository contract**

```bash
# tests/helpers/assert.bash
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_file() { test -f "$1" || fail "missing file: $1"; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"; }
assert_not_contains() { ! grep -Fq -- "$2" "$1" || fail "$1 contains forbidden text: $2"; }
```

```bash
# initial tests/test_static_contract.bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source tests/helpers/assert.bash

for path in .dockerignore .env.example docker/versions.env docker/requirements/ai.in docker/requirements/ai.lock; do
  assert_file "$path"
done
assert_contains docker/versions.env 'DOOSAN_REF=816ecb5d1c2599303eaf9540216afa03552f80ad'
assert_contains docker/versions.env 'ISAAC_ROS_REF=dd3eeede7912755996a18f4884285d9f50843f79'
assert_contains .dockerignore 'data/'
assert_contains .dockerignore 'checkpoints/'
assert_contains .dockerignore '.env'
printf 'static repository contract passed\n'
```

- [ ] **Step 2: Run the contract and confirm it fails on the first missing file**

Run: `bash tests/test_static_contract.bash`

Expected: non-zero with `FAIL: missing file: .dockerignore`.

- [ ] **Step 3: Add exact ignore, runtime example, version, and direct dependency files**

```text
# .dockerignore
.git
.github
.env
.superpowers
build
install
log
data
checkpoints
__pycache__
.pytest_cache
.ruff_cache
.vscode
*.pyc
```

```dotenv
# .env.example
COMPOSE_PROJECT_NAME=ros2-dev-local
LOCAL_UID=1000
LOCAL_GID=1000
ROS_DOMAIN_ID=42
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
DISPLAY=:0
ISAAC_SIM_ROOT=/home/user/isaacsim
```

```dotenv
# docker/versions.env
ROS_BASE_IMAGE=osrf/ros:jazzy-desktop@sha256:1d6f898b6ab77636c40f26298070ad3de5a9e06f0a71cf9ab066fd6b7838f151
UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:88baae1f9fa298996f8313e44559163c535937406d217f1c8ac9d4b86a2020fd
DOOSAN_REF=816ecb5d1c2599303eaf9540216afa03552f80ad
ISAAC_ROS_REF=dd3eeede7912755996a18f4884285d9f50843f79
DOOSAN_EMULATOR_IMAGE=doosanrobot/dsr_emulator:3.0.1@sha256:878b8557dfa2ffd843674e42576fd015b803cc805fe698156eb7b743e71547e9
```

```text
# docker/requirements/ai.in
torch==2.7.1
torchvision==0.22.1
diffusers==0.34.0
huggingface-hub==0.33.4
einops==0.8.1
timm==1.0.17
```

Append `.xauth-*` to `.gitignore` so temporary GUI credentials cannot be committed.

- [ ] **Step 4: Generate the hash-locked Python dependencies as the host user**

Run:

```bash
set -a
source docker/versions.env
set +a
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$PWD:/workspace" -w /workspace "$UV_IMAGE" \
  /uv pip compile --python-version 3.12 --generate-hashes \
  --output-file docker/requirements/ai.lock docker/requirements/ai.in
```

Expected: `docker/requirements/ai.lock` contains exact `==` versions and `--hash=sha256:` entries.

- [ ] **Step 5: Run the contract and lock checks**

Run:

```bash
bash tests/test_static_contract.bash
grep -q -- '--hash=sha256:' docker/requirements/ai.lock
git diff --check -- .dockerignore .env.example .gitignore docker tests
```

Expected: `static repository contract passed` and all commands exit zero.

- [ ] **Step 6: Commit the immutable contracts**

```bash
git add .dockerignore .env.example .gitignore docker/versions.env \
  docker/requirements/ai.in docker/requirements/ai.lock \
  tests/helpers/assert.bash tests/test_static_contract.bash
git commit -m "build: pin shared environment inputs"
```

---

### Task 2: Consolidate the Docker build into named non-root targets

**Files:**
- Modify: `Dockerfile`
- Create: `docker/install_doosan.bash`
- Create: `docker/install_isaac_ros.bash`
- Modify: `docker/nexus_env.bash`
- Delete with `apply_patch` after equivalent targets pass: `Dockerfile.doosan`
- Delete with `apply_patch` after equivalent targets pass: `Dockerfile.isaac-moveit`
- Modify: `tests/test_static_contract.bash`

**Interfaces:**
- Consumes: `ROS_BASE_IMAGE`, `UV_IMAGE`, `DOOSAN_REF`, `ISAAC_ROS_REF`, and `docker/requirements/ai.lock`.
- Produces: Docker targets `ros-dev`, `ros-ai-dev`, `doosan-dev`, `full-dev`; runtime user `developer`; overlays at `/opt/robot_ws`.

- [ ] **Step 1: Extend the static contract with failing Docker target assertions**

Add:

```bash
for target in 'AS ros-base' 'AS ros-dev' 'AS ros-ai-dev' 'AS doosan-dev' 'AS full-dev'; do
  assert_contains Dockerfile "$target"
done
assert_contains Dockerfile 'USER developer'
assert_not_contains Dockerfile 'curl -LsSf https://astral.sh/uv/install.sh | sh'
assert_not_contains Dockerfile 'DOOSAN_ROBOT2_REF=jazzy'
```

- [ ] **Step 2: Run the static contract and confirm target assertions fail**

Run: `bash tests/test_static_contract.bash`

Expected: non-zero at `AS ros-base`.

- [ ] **Step 3: Write the focused Doosan installer**

The script must use `set -euo pipefail`, accept the SHA as `$1`, initialize a detached Git checkout under `/opt/robot_ws/doosan_ws/src/doosan-robot2`, run `rosdep install`, build with `colcon --symlink-install`, verify `dsr_bringup2`, and remove Git metadata. Its externally visible contract is:

```bash
docker/install_doosan.bash 816ecb5d1c2599303eaf9540216afa03552f80ad
test -f /opt/robot_ws/doosan_ws/install/setup.bash
```

Use the exact fetch sequence:

```bash
git init "$repo"
git -C "$repo" remote add origin https://github.com/DoosanRobotics/doosan-robot2.git
git -C "$repo" fetch --depth 1 origin "$ref"
test "$(git -C "$repo" rev-parse FETCH_HEAD)" = "$ref"
git -C "$repo" checkout --detach FETCH_HEAD
```

- [ ] **Step 4: Write the focused Isaac ROS installer**

The script accepts the SHA as `$1`, checks out the exact commit with submodules under `/opt/robot_ws/isaacsim_ros`, installs rosdep dependencies, installs `setuptools==78.1.1` before the build, builds `jazzy_ws`, verifies `isaac_moveit`, and removes all `.git` directories and files.

```bash
docker/install_isaac_ros.bash dd3eeede7912755996a18f4884285d9f50843f79
test -f /opt/robot_ws/isaacsim_ros/jazzy_ws/install/setup.bash
```

- [ ] **Step 5: Replace the root Dockerfile with the named-target build**

The Dockerfile must start with:

```dockerfile
# syntax=docker/dockerfile:1.7
ARG ROS_BASE_IMAGE=osrf/ros:jazzy-desktop@sha256:1d6f898b6ab77636c40f26298070ad3de5a9e06f0a71cf9ab066fd6b7838f151
ARG UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:88baae1f9fa298996f8313e44559163c535937406d217f1c8ac9d4b86a2020fd
FROM ${UV_IMAGE} AS uv-bin
FROM ${ROS_BASE_IMAGE} AS ros-base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DEVELOPER_UID=1000
ARG DEVELOPER_GID=1000
ARG DEVELOPER_NAME=developer
ENV DEBIAN_FRONTEND=noninteractive
ENV ROBOT_WS_ROOT=/opt/robot_ws
ENV VENV_DIR=/opt/venv
```

Install shared runtime tools with `--no-install-recommends`, copy `uv` from `uv-bin`, create the matching user, copy `nexus_env.bash`, set `/workspace` ownership, and end every runnable target with:

```dockerfile
WORKDIR /workspace
USER developer
```

`ros-dev` installs colcon, rosdep, vcstool, compiler, Git, jq, and common ROS debugging tools. `ros-ai-dev` creates `/opt/venv` and runs:

```dockerfile
RUN uv venv "${VENV_DIR}" --system-site-packages \
    && uv pip sync --python "${VENV_DIR}" /tmp/ai.lock \
    && chown -R developer:developer "${VENV_DIR}"
```

`doosan-dev` calls `install_doosan.bash`. `full-dev` starts from `doosan-dev`, installs the same locked AI environment, then calls `install_isaac_ros.bash`.

- [ ] **Step 6: Make runtime sourcing deterministic**

Keep this order in `docker/nexus_env.bash`:

```bash
source /opt/ros/jazzy/setup.bash
test ! -f /opt/robot_ws/isaacsim_ros/jazzy_ws/install/setup.bash || \
  source /opt/robot_ws/isaacsim_ros/jazzy_ws/install/setup.bash
test ! -f /opt/robot_ws/doosan_ws/install/setup.bash || \
  source /opt/robot_ws/doosan_ws/install/setup.bash
test ! -f /opt/venv/bin/activate || source /opt/venv/bin/activate
test ! -f /workspace/install/setup.bash || source /workspace/install/setup.bash
```

Preserve the FastDDS path only when `/workspace/config/fastdds.xml` exists.

- [ ] **Step 7: Run static checks and build the two lightweight targets**

Run:

```bash
bash -n docker/install_doosan.bash docker/install_isaac_ros.bash docker/nexus_env.bash
bash tests/test_static_contract.bash
set -a; source docker/versions.env; set +a
docker build --target ros-dev \
  --build-arg ROS_BASE_IMAGE="$ROS_BASE_IMAGE" --build-arg UV_IMAGE="$UV_IMAGE" .
docker build --target ros-ai-dev \
  --build-arg ROS_BASE_IMAGE="$ROS_BASE_IMAGE" --build-arg UV_IMAGE="$UV_IMAGE" .
```

Expected: both builds exit zero and the static contract passes.

- [ ] **Step 8: Remove legacy Dockerfiles only after target builds pass**

Delete both files with `apply_patch`, which is required for repository file edits:

```diff
*** Delete File: Dockerfile.doosan
*** Delete File: Dockerfile.isaac-moveit
```

Then run `bash tests/test_static_contract.bash`.

Expected: the contract passes and all former features are represented by named targets. Both
legacy files were untracked before this plan, so no deletion path is staged for them.

- [ ] **Step 9: Commit the Docker consolidation**

```bash
git add Dockerfile docker/install_doosan.bash docker/install_isaac_ros.bash \
  docker/nexus_env.bash tests/test_static_contract.bash
git commit -m "build: consolidate non-root Docker targets"
```

---

### Task 3: Split safe Compose defaults from privileged overrides

**Files:**
- Modify: `compose.yml`
- Create: `compose/host-dds.yml`
- Create: `compose/gpu.yml`
- Create: `compose/gui.yml`
- Create: `compose/trusted-emulator.yml`
- Create: `tests/test_presets.bash`

**Interfaces:**
- Consumes: `.env`, `docker/versions.env`, and Docker named targets.
- Produces: base services `ros2_dev`, `ai_dev`, `doosan_dev`, `full_dev`; four independent override files; no fixed container names.

- [ ] **Step 1: Write a failing normalized-Compose security test**

The test copies `.env.example` to a temporary env file, invokes Compose with both env files, renders JSON, and asserts:

```bash
jq -e '.services.ros2_dev.build.target == "ros-dev"' "$json"
jq -e '.services.ros2_dev.user != "0" and .services.ros2_dev.user != "root"' "$json"
jq -e '.services.ros2_dev | has("container_name") | not' "$json"
jq -e '.services.ros2_dev | has("network_mode") | not' "$json"
jq -e '.services.ros2_dev | has("pid") | not' "$json"
jq -e '.services.ros2_dev | has("ipc") | not' "$json"
jq -e '[.services.ros2_dev.volumes[]?.target] | index("/var/run/docker.sock") | not' "$json"
```

It must also assert that `host-dds.yml` adds only `network_mode: host`, `gpu.yml` adds GPU only to `ai_dev` and `full_dev`, and `trusted-emulator.yml` is the only normalized configuration containing `/var/run/docker.sock`.

- [ ] **Step 2: Run the preset test and confirm the current Compose fails**

Run: `bash tests/test_presets.bash`

Expected: non-zero because `ros2_dev` has fixed name and host privileges.

- [ ] **Step 3: Replace `compose.yml` with safe services and shared anchors**

Use this service mapping:

```yaml
services:
  ros2_dev:
    build: {context: ., dockerfile: Dockerfile, target: ros-dev}
  ai_dev:
    profiles: [ai]
    build: {context: ., dockerfile: Dockerfile, target: ros-ai-dev}
  doosan_dev:
    profiles: [doosan]
    build: {context: ., dockerfile: Dockerfile, target: doosan-dev}
  full_dev:
    profiles: [full]
    build: {context: ., dockerfile: Dockerfile, target: full-dev}
```

Each service receives `DEVELOPER_UID`, `DEVELOPER_GID`, source refs, `ROS_DOMAIN_ID`, RMW, and FastDDS paths, uses `user: "${LOCAL_UID}:${LOCAL_GID}"`, `init: true`, and only binds `.:/workspace:rw` in the base file.

- [ ] **Step 4: Add independent host DDS, GPU, and GUI overrides**

`host-dds.yml` sets `network_mode: host` for the four services. `gpu.yml` sets `gpus: all`, `NVIDIA_VISIBLE_DEVICES`, and `NVIDIA_DRIVER_CAPABILITIES=compute,utility` for `ai_dev`; `full_dev` uses `compute,utility,graphics`. `gui.yml` adds:

```yaml
environment:
  DISPLAY: ${DISPLAY}
  XAUTHORITY: /tmp/.nexus.xauth
  QT_X11_NO_MITSHM: "1"
volumes:
  - /tmp/.X11-unix:/tmp/.X11-unix:ro
  - ${NEXUS_XAUTH_FILE}:/tmp/.nexus.xauth:ro
```

- [ ] **Step 5: Add the explicit trusted emulator runner**

The service is profile-gated, based on `doosan-dev`, uses host network and GUI credentials, mounts the socket, and runs the pinned vendor MoveIt launch:

```yaml
services:
  trusted_emulator:
    profiles: [trusted-emulator]
    build: {context: ., dockerfile: Dockerfile, target: doosan-dev}
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /tmp/.X11-unix:/tmp/.X11-unix:ro
      - ${NEXUS_XAUTH_FILE}:/tmp/.nexus.xauth:ro
      - .:/workspace:rw
    command: >-
      bash -lc 'docker pull "$DOOSAN_EMULATOR_IMAGE" &&
      docker tag "$DOOSAN_EMULATOR_IMAGE" doosanrobot/dsr_emulator:3.0.1 &&
      source /etc/profile.d/nexus_env.bash &&
      ros2 launch dsr_bringup2 dsr_bringup2_moveit.launch.py
      mode:=virtual model:=a0912 host:=127.0.0.1 port:=12345'
```

Set `DOOSAN_EMULATOR_IMAGE` in the service environment. Pull by digest and retag locally before
the vendor script uses its hard-coded versioned tag, so a moved registry tag cannot change the
emulator binary selected for the run.

- [ ] **Step 6: Validate every Compose combination**

Run:

```bash
bash tests/test_presets.bash
docker compose --env-file docker/versions.env --env-file .env.example config -q
docker compose --env-file docker/versions.env --env-file .env.example \
  -f compose.yml -f compose/host-dds.yml config -q
docker compose --env-file docker/versions.env --env-file .env.example \
  -f compose.yml -f compose/gpu.yml --profile ai --profile full config -q
docker compose --env-file docker/versions.env --env-file .env.example \
  -f compose.yml -f compose/gui.yml -f compose/trusted-emulator.yml \
  --profile trusted-emulator config -q
```

Expected: preset contract passes and all configurations parse.

- [ ] **Step 7: Commit the Compose privilege split**

```bash
git add compose.yml compose tests/test_presets.bash
git commit -m "build: isolate optional container privileges"
```

---

### Task 4: Implement idempotent local initialization

**Files:**
- Create: `scripts/lib/config.bash`
- Create: `tests/test_init.bash`
- Modify: `run.sh`

**Interfaces:**
- Produces: `nexus_load_env`, `nexus_validate_env`, `nexus_init_env`, `nexus_env_file`; `./run.sh init [--non-interactive]`.
- Consumes: `.env.example`; environment overrides `NEXUS_ENV_FILE` and `NEXUS_NONINTERACTIVE` for tests and CI.

- [ ] **Step 1: Write failing init tests against a temporary env path**

Test these cases:

```bash
NEXUS_ENV_FILE="$tmp/.env" ./run.sh init --non-interactive
grep -Fxq "LOCAL_UID=$(id -u)" "$tmp/.env"
grep -Fxq "LOCAL_GID=$(id -g)" "$tmp/.env"
grep -Eq '^COMPOSE_PROJECT_NAME=ros2-dev-[a-z0-9_.-]+$' "$tmp/.env"
grep -Eq '^ROS_DOMAIN_ID=[0-9]+$' "$tmp/.env"
before="$(sha256sum "$tmp/.env")"
NEXUS_ENV_FILE="$tmp/.env" ./run.sh init --non-interactive
test "$before" = "$(sha256sum "$tmp/.env")"
```

Also create invalid files and assert `nexus_validate_env` rejects domain `-1`, `233`, non-numeric UID/GID, and an unsafe project name.

- [ ] **Step 2: Run the tests and confirm `init` is unknown**

Run: `bash tests/test_init.bash`

Expected: non-zero because current `run.sh` does not implement `init`.

- [ ] **Step 3: Add safe dotenv parsing and validation**

`scripts/lib/config.bash` must accept only these keys:

```bash
COMPOSE_PROJECT_NAME LOCAL_UID LOCAL_GID ROS_DOMAIN_ID RMW_IMPLEMENTATION DISPLAY ISAAC_SIM_ROOT
```

Parse `KEY=VALUE` without `eval` or `source`. Reject whitespace in key names, shell metacharacters in numeric/project fields, `ROS_DOMAIN_ID` outside `0..232`, and project names outside `[a-z0-9][a-z0-9_.-]*`.

- [ ] **Step 4: Generate but never overwrite `.env`**

For non-interactive initialization use:

```text
safe_user="$(printf '%s' "${USER:-user}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9_.-' '-')"
safe_user="${safe_user#-}"
safe_user="${safe_user%-}"
test -n "$safe_user" || safe_user=user
COMPOSE_PROJECT_NAME=ros2-dev-${safe_user}
LOCAL_UID=$(id -u)
LOCAL_GID=$(id -g)
ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-42}
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
DISPLAY=${DISPLAY:-:0}
ISAAC_SIM_ROOT=${ISAAC_SIM_ROOT:-$HOME/isaacsim}
```

Write through a temporary file in the same directory, set mode `0600`, then atomically rename only when the target does not exist.

- [ ] **Step 5: Add the `run.sh init` route and missing-env guard**

`help` and `init` run without `.env`; all Docker lifecycle commands call `nexus_load_env` and fail with:

```text
Local environment file is missing: $NEXUS_ENV_FILE
Run ./run.sh init before starting a development profile.
```

- [ ] **Step 6: Run init tests and syntax checks**

Run:

```bash
bash tests/test_init.bash
bash -n run.sh scripts/lib/config.bash
```

Expected: all init tests pass.

- [ ] **Step 7: Commit local environment initialization**

```bash
git add run.sh scripts/lib/config.bash tests/test_init.bash
git commit -m "feat: add safe workspace initialization"
```

---

### Task 5: Add profile-aware host diagnostics

**Files:**
- Create: `scripts/doctor.bash`
- Create: `tests/test_doctor.bash`
- Modify: `run.sh`

**Interfaces:**
- Produces: `./run.sh doctor [base|gpu|gui|full]` with zero on success and non-zero on required failure.
- Test controls: `NEXUS_OS_RELEASE_FILE`, `NEXUS_UNAME_MACHINE`, and fake commands at the front of `PATH`.

- [ ] **Step 1: Write failing tests with fake host commands**

Create temporary fake `docker`, `nvidia-smi`, `xauth`, and `uname` commands. Assert:

- Ubuntu `24.04`, `x86_64`, Docker daemon, Compose `2.30.0`, valid env, and sufficient disk pass base doctor.
- Ubuntu `22.04`, `aarch64`, stopped daemon, Compose `2.29.9`, and invalid domain each fail with an exact remediation line.
- GPU doctor fails without `nvidia-smi` or an `nvidia` runtime.
- GUI doctor fails without `DISPLAY`, `/tmp/.X11-unix`, or `xauth`.
- Full doctor fails when `$ISAAC_SIM_ROOT/isaac-sim.sh` is not executable.

- [ ] **Step 2: Run tests and confirm `doctor` is unknown**

Run: `bash tests/test_doctor.bash`

Expected: non-zero because the route does not exist.

- [ ] **Step 3: Implement base checks and exact messages**

Base checks:

```text
os-release VERSION_ID == 24.04
machine == x86_64
docker command exists
docker info succeeds
docker compose version >= 2.30.0
available disk >= 20 GiB
local env validates
```

Print one line per check using `PASS`, `WARN`, or `FAIL`. Every `FAIL` includes the observed value and a command or onboarding document path.

- [ ] **Step 4: Add optional profile checks**

- `gpu`: `nvidia-smi` succeeds and `docker info --format '{{json .Runtimes}}'` contains `nvidia`.
- `gui`: non-empty `DISPLAY`, X11 socket directory, and `xauth` command.
- `full`: base + gpu + gui + executable Isaac launcher and at least 80 GiB available disk.

- [ ] **Step 5: Add `run.sh doctor` dispatch and run tests**

Run:

```bash
bash tests/test_doctor.bash
bash -n run.sh scripts/doctor.bash scripts/lib/config.bash
```

Expected: all synthetic host cases pass.

- [ ] **Step 6: Run doctor on the current host without changing state**

Run: `./run.sh doctor base`

Expected: all required base checks report `PASS`; optional limitations are not promoted to success.

- [ ] **Step 7: Commit host diagnostics**

```bash
git add run.sh scripts/doctor.bash tests/test_doctor.bash
git commit -m "feat: add profile-aware environment doctor"
```

---

### Task 6: Add Compose preset dispatch and scoped X11 credentials

**Files:**
- Create: `scripts/lib/compose.bash`
- Create: `scripts/x11.bash`
- Modify: `run.sh`
- Modify: `tests/test_presets.bash`

**Interfaces:**
- Produces: `nexus_compose_args <preset>`, `nexus_service <preset>`, `nexus_profile <preset>`, `nexus_x11_prepare`, and `nexus_x11_cleanup`.
- Public presets: `dev`, `isaac-dev`, `gui-dev`, `isaac-gui-dev`, `ai-dev`, `gpu-dev`, `doosan-dev`, `full-dev`.

- [ ] **Step 1: Add failing dry-run command assertions**

With `NEXUS_DRY_RUN=1`, assert exact fragments:

```text
dev -> -f compose.yml ... ros2_dev
isaac-dev -> -f compose.yml -f compose/host-dds.yml ... ros2_dev
ai-dev -> --profile ai ... ai_dev
gpu-dev -> host-dds.yml + gpu.yml + --profile ai ... ai_dev
doosan-dev -> host-dds.yml + gui.yml + --profile doosan ... doosan_dev
full-dev -> host-dds.yml + gpu.yml + gui.yml + --profile full ... full_dev
```

Assert `moveit-dev` renders the same Compose selection as `full-dev`.

- [ ] **Step 2: Run preset tests and confirm dry-run support fails**

Run: `bash tests/test_presets.bash`

Expected: non-zero because current `run.sh` does not assemble overrides.

- [ ] **Step 3: Implement deterministic preset arrays**

All Compose commands begin with:

```bash
docker compose --env-file "$ROOT/docker/versions.env" --env-file "$NEXUS_ENV_FILE" -f "$ROOT/compose.yml"
```

Append override files and profiles in this fixed order: `host-dds`, `gpu`, `gui`, `trusted-emulator`. Never construct the command with `eval`.

- [ ] **Step 4: Implement Xauthority preparation and cleanup**

Use `${XDG_RUNTIME_DIR:-/tmp}/${COMPOSE_PROJECT_NAME}-${LOCAL_UID}.xauth`, create mode `0600`,
and merge only the current `$DISPLAY` cookie:

```bash
xauth nlist "$DISPLAY" | sed -e 's/^..../ffff/' | xauth -f "$NEXUS_XAUTH_FILE" nmerge -
```

Export `NEXUS_XAUTH_FILE`. Cleanup removes only that generated file. Install a trap before `docker compose up`; cleanup on failure and on `down`.

- [ ] **Step 5: Rebuild public lifecycle routes around presets**

Keep existing routes and add the new presets. `build`, `up`, `shell`, `workspace-build`, `status`, and `down` default to `ros2_dev`; profile-prefixed routes select their service. `moveit-*` delegates to `full-*`. `down` includes all override files and profiles with `--remove-orphans` so one command stops every preset in the project.

- [ ] **Step 6: Run script and normalized Compose tests**

Run:

```bash
bash tests/test_init.bash
bash tests/test_doctor.bash
bash tests/test_presets.bash
bash -n run.sh scripts/lib/config.bash scripts/lib/compose.bash scripts/x11.bash
```

Expected: all tests pass without running a real container.

- [ ] **Step 7: Commit preset and GUI lifecycle support**

```bash
git add run.sh scripts/lib/compose.bash scripts/x11.bash tests/test_presets.bash
git commit -m "feat: add safe development presets"
```

---

### Task 7: Align Dev Containers, Isaac launcher, and trusted emulator workflow

**Files:**
- Modify: `.devcontainer/devcontainer.json`
- Modify: `.devcontainer/doosan/devcontainer.json`
- Modify: `.devcontainer/doosan/compose.yml`
- Create: `.devcontainer/full/devcontainer.json`
- Create: `.devcontainer/full/compose.yml`
- Modify: `scripts/launch_isaac_sim.sh`
- Delete with `apply_patch`: `docker/bootstrap_doosan_emulator.bash`
- Modify: `run.sh`
- Modify: `tests/test_static_contract.bash`
- Modify: `tests/test_presets.bash`

**Interfaces:**
- Produces: non-root base, Doosan, and full Dev Containers; `.env`-aware Isaac launch; explicit `./run.sh doosan-emulator` route.

- [ ] **Step 1: Add failing static assertions**

Assert all Dev Container files use `"remoteUser": "developer"`, base points to `ros2_dev`, Doosan to `doosan_dev`, full to `full_dev`, and none mention `/var/run/docker.sock`. Assert `scripts/launch_isaac_sim.sh` does not contain `/home/ahrism` and does load the workspace `.env` through `scripts/lib/config.bash`.

- [ ] **Step 2: Run static tests and confirm current root/path assertions fail**

Run: `bash tests/test_static_contract.bash`

Expected: non-zero at the base Dev Container `remoteUser` assertion.

- [ ] **Step 3: Update all Dev Containers**

Each definition uses `initializeCommand` to call `./run.sh init --non-interactive`, `remoteUser: developer`, `updateRemoteUserUID: false`, and a `postCreateCommand` rather than rebuilding on every start. Keep Python interpreter `/usr/bin/python3` for base/Doosan and `/opt/venv/bin/python` for full.

Doosan and full compose overrides reset only the selected service profile; they do not add GPU, GUI, host network, or socket implicitly. Those capabilities remain `run.sh` presets.

- [ ] **Step 4: Make the Isaac launcher read validated local configuration**

Resolve `WORKSPACE_DIR`, set `NEXUS_ENV_FILE`, source only function code from `config.bash`, call `nexus_load_env`, derive launcher from `$ISAAC_SIM_ROOT/isaac-sim.sh`, and retain explicit CLI overrides. The help output uses `$HOME/isaacsim`, never a developer-specific path.

- [ ] **Step 5: Replace in-container bootstrap with an explicit trusted route**

Remove `docker/bootstrap_doosan_emulator.bash` with `apply_patch`. Add `doosan-emulator` to
`run.sh`; it prints the root-equivalent Docker socket warning, requires the literal environment
opt-in `NEXUS_ALLOW_DOCKER_SOCKET=1`, prepares X11, and starts only `trusted_emulator` from the
trusted override.

Without the opt-in, output:

```text
Refusing trusted emulator startup: this profile controls the host Docker daemon.
Review docs/onboarding/security.md, then set NEXUS_ALLOW_DOCKER_SOCKET=1 for this command.
```

- [ ] **Step 6: Run static and preset tests**

Run:

```bash
jq empty .devcontainer/devcontainer.json .devcontainer/doosan/devcontainer.json \
  .devcontainer/full/devcontainer.json
bash tests/test_static_contract.bash
bash tests/test_presets.bash
bash -n scripts/launch_isaac_sim.sh run.sh
```

Expected: all checks pass and only `compose/trusted-emulator.yml` contains the socket path.

- [ ] **Step 7: Commit IDE and trusted-emulator alignment**

```bash
git add .devcontainer scripts/launch_isaac_sim.sh run.sh \
  tests/test_static_contract.bash tests/test_presets.bash
git commit -m "feat: align non-root developer workflows"
```

---

### Task 8: Turn verification into executable local and CI gates

**Files:**
- Create: `tests/run_all.bash`
- Create: `scripts/smoke_container.bash`
- Rewrite: `scripts/check_dev_workflow.sh`
- Create: `.github/workflows/dev-environment.yml`
- Create: `.github/workflows/heavy-images.yml`

**Interfaces:**
- Produces: `tests/run_all.bash`, `scripts/check_dev_workflow.sh`, `scripts/smoke_container.bash`, automated clean-checkout gates.

- [ ] **Step 1: Write the aggregate test runner**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
for test_file in tests/test_init.bash tests/test_doctor.bash tests/test_presets.bash tests/test_static_contract.bash; do
  bash "$test_file"
done
printf 'all shell tests passed\n'
```

- [ ] **Step 2: Make the workflow checker execute real parsers and contracts**

`scripts/check_dev_workflow.sh` must run:

```bash
bash -n run.sh docker/*.bash scripts/*.bash scripts/lib/*.bash tests/*.bash tests/helpers/*.bash
jq empty .devcontainer/devcontainer.json .devcontainer/doosan/devcontainer.json .devcontainer/full/devcontainer.json
xmllint --noout config/fastdds.xml
bash tests/run_all.bash
docker compose --env-file docker/versions.env --env-file .env.example config -q
git diff --check
```

It must no longer consider literal string presence alone proof of a valid environment.

- [ ] **Step 3: Write the CPU container smoke script**

The script builds `ros2_dev`, starts an ephemeral service, and checks:

```bash
test "$(id -u)" -ne 0
test "$HOME" = /home/developer
source /etc/profile.d/nexus_env.bash
command -v ros2
ros2 pkg prefix demo_nodes_cpp
touch /workspace/.nexus-write-test
rm /workspace/.nexus-write-test
```

Then run a `demo_nodes_cpp talker` in the background, wait with a bounded 20-second loop for `ros2 topic echo /chatter --once`, terminate the talker, and fail if no message arrives.

- [ ] **Step 4: Run local aggregate checks before adding CI**

Run:

```bash
./run.sh init --non-interactive
bash tests/run_all.bash
./scripts/check_dev_workflow.sh
```

Expected: all shell/static checks pass.

- [ ] **Step 5: Add the PR/push workflow**

Use Ubuntu 24.04, pin checkout as
`actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5` (v4), install
`jq libxml2-utils shellcheck`, run the checker, build only `ros-dev`, then run the smoke script.
Set `COMPOSE_PROJECT_NAME=ros2-dev-ci`, UID/GID from the runner, and `ROS_DOMAIN_ID=212` in the
generated `.env`.

- [ ] **Step 6: Add the manual heavy-image workflow**

Use `workflow_dispatch` with an input `target` constrained to `doosan-dev` or `full-dev`. It runs static checks and `docker build --target "$target"` with version args; it does not publish or claim GPU/GUI/Isaac runtime success.

- [ ] **Step 7: Commit executable verification**

```bash
git add tests/run_all.bash scripts/check_dev_workflow.sh scripts/smoke_container.bash .github/workflows
git commit -m "ci: verify clean shared development environment"
```

---

### Task 9: Create the canonical onboarding documentation

**Files:**
- Create: `docs/onboarding/README.md`
- Create: `docs/onboarding/supported-platforms.md`
- Create: `docs/onboarding/prerequisites.md`
- Create: `docs/onboarding/quickstart.md`
- Create: `docs/onboarding/profiles.md`
- Create: `docs/onboarding/security.md`
- Create: `docs/onboarding/updates-and-cleanup.md`
- Create: `docs/onboarding/troubleshooting.md`
- Create: `docs/onboarding/third-party-sources.md`
- Modify: `README.md`
- Modify: `tests/test_static_contract.bash`

**Interfaces:**
- Consumes: exact public commands and profile behavior from Tasks 4–8.
- Produces: one canonical start path and security/support references used by tutorials and error messages.

- [ ] **Step 1: Add failing onboarding navigation and path tests**

Assert all nine files exist, README links `docs/onboarding/README.md` before tutorials, no
canonical onboarding file contains `/home/ahrism`, and each public preset appears in
`profiles.md`.

- [ ] **Step 2: Run static tests and confirm onboarding files are missing**

Run: `bash tests/test_static_contract.bash`

Expected: non-zero at `docs/onboarding/README.md`.

- [ ] **Step 3: Write support and prerequisite documents**

Record exact support: Ubuntu 24.04 x86_64, Compose >=2.30, CPU base, optional NVIDIA/X11, explicit WSL/macOS/Wayland/ARM64 non-support. Include commands and expected signals for `uname -m`, OS release, Docker daemon, Compose, `nvidia-smi`, `xauth`, disk, and Isaac launcher.

- [ ] **Step 4: Write clean-clone quickstart and profile reference**

Quickstart uses only:

```bash
git clone https://github.com/ahrism10M501/Nexus-Robotics.git ros2-dev
cd ros2-dev
./run.sh init
./run.sh doctor base
./run.sh build
./run.sh dev
./scripts/smoke_container.bash
./run.sh down
```

Profiles document every permission and expected disk cost. The onboarding index also explains
that an internal mirror URL may replace the public origin without changing the remaining steps.

- [ ] **Step 5: Write security, cleanup, and troubleshooting documents**

Security must state Docker socket root equivalence, host DDS LAN visibility, per-user domain
allocation, X11 credential scope, and trusted emulator opt-in. Cleanup distinguishes `down`,
local build outputs, Docker build cache, images, datasets, and checkpoints; destructive commands
require explicit paths and warnings. Troubleshooting covers Docker permissions, missing NVIDIA
runtime, X11/Wayland, root-owned legacy outputs, build disk exhaustion, and profile collisions.
`third-party-sources.md` records every pinned image/source, its upstream URL, version or SHA,
license link when upstream declares one, and the update procedure without selecting a license for
this repository.

- [ ] **Step 6: Rewrite README as the onboarding hub**

Order sections as support, prerequisites, clone/init, doctor, CPU quickstart, optional profiles, verification, tutorials, security, and troubleshooting. Remove the nonexistent `isaac/` directory and internal `docs/superpowers/plans` links from beginner navigation.

- [ ] **Step 7: Validate local Markdown targets and onboarding contracts**

Run:

```bash
bash tests/test_static_contract.bash
rg -n '/home/ahrism' README.md docs/onboarding && exit 1 || true
```

Expected: no personal path output and all local links resolve.

- [ ] **Step 8: Commit canonical onboarding**

```bash
git add README.md docs/onboarding tests/test_static_contract.bash
git commit -m "docs: add clean-clone researcher onboarding"
```

---

### Task 10: Migrate tutorials and troubleshooting to the new environment

**Files:**
- Modify: `docs/tutorials/README.md`
- Modify: `docs/tutorials/shared/README.md`
- Modify: `docs/tutorials/shared/environment-setup.md`
- Modify: `docs/tutorials/shared/troubleshooting.md`
- Modify: `docs/troubleshooting/2026-07-07-isaacsim-ros2-bridge-fastdds.md`
- Modify: `docs/tutorials/day-01-isaac-sim-basics/hands-on.md`
- Modify: `docs/tutorials/day-02-jetbot-turtlebot-ros2-driving/hands-on.md`
- Modify: `docs/tutorials/day-03-python-scripting-minimum-loop/hands-on.md`
- Modify: `docs/tutorials/day-04-ros2-bridge-observation-pipeline/README.md`
- Modify: `docs/tutorials/day-04-ros2-bridge-observation-pipeline/hands-on.md`
- Modify: `docs/tutorials/day-05-manipulator-concepts-before-a0912/hands-on.md`
- Modify: `docs/tutorials/day-06-doosan-a0912-bringup/hands-on.md`
- Modify: `docs/tutorials/day-07-a0912-scripted-motion/README.md`
- Modify: `docs/tutorials/day-07-a0912-scripted-motion/hands-on.md`
- Modify: `docs/tutorials/day-08-cube-pick-scene-v0/README.md`
- Modify: `docs/tutorials/day-08-cube-pick-scene-v0/hands-on.md`
- Modify: `docs/tutorials/day-09-dataset-collection/README.md`
- Modify: `docs/tutorials/day-09-dataset-collection/hands-on.md`
- Modify: `tests/test_static_contract.bash`

**Interfaces:**
- Consumes: onboarding paths and public presets.
- Produces: tutorial commands that match runtime profiles and zero personal checkout paths.

- [ ] **Step 1: Add failing tutorial migration assertions**

Assert no Markdown under `docs/tutorials` contains `/home/ahrism/workspace/ros2-dev`, Day 4 links directly to Day 5 README, Day 7–9 READMEs contain `설계 실습`, and no tutorial tells users to run `docker ps` inside `doosan_dev`.

- [ ] **Step 2: Run static tests and observe current migration failures**

Run: `bash tests/test_static_contract.bash`

Expected: non-zero with the first remaining personal path.

- [ ] **Step 3: Replace all checkout paths and add a shared preamble**

Every host sequence begins with:

```bash
cd "$REPO_ROOT"
```

The shared setup defines `REPO_ROOT` once as the clone location selected during onboarding. Do not embed a username or assume `/workspace` on the host.

- [ ] **Step 4: Assign exact presets by tutorial stage**

- Day 1 and Day 3: host Isaac plus `doctor full` only when container interaction is required.
- Day 2: `isaac-dev`.
- Day 4: `isaac-gui-dev` for RViz.
- Day 5: `full-dev`.
- Day 6 and Day 7: `doosan-dev`; virtual MoveIt starts through `NEXUS_ALLOW_DOCKER_SOCKET=1 ./run.sh doosan-emulator`, while inspection uses `doosan-shell`.
- Day 8 and Day 9: `isaac-dev` unless RViz is explicitly required.
- Day 10 remains architecture-only and does not claim training support.

- [ ] **Step 5: Mark non-executable later days accurately**

Add a prominent `현재 상태: 설계 실습` block to Day 7–9 READMEs and hands-on documents. State which script/package is absent and which conceptual checkpoint remains useful; do not present recorder, replay, or learned policy as implemented.

- [ ] **Step 6: Fix navigation and troubleshooting**

Make Day 4 link directly to `../day-05-manipulator-concepts-before-a0912/README.md`. Link shared setup to canonical onboarding. Add first-run Docker, NVIDIA, X11, non-root ownership, disk, `.env`, domain collision, and trusted emulator diagnostics.

- [ ] **Step 7: Run documentation contracts and local link validation**

Run:

```bash
bash tests/test_static_contract.bash
rg -n '/home/ahrism/workspace/ros2-dev' README.md docs && exit 1 || true
```

Expected: no personal checkout path and all tutorial contracts pass.

- [ ] **Step 8: Commit tutorial migration**

```bash
git add docs/tutorials docs/troubleshooting tests/test_static_contract.bash
git commit -m "docs: align tutorials with shared profiles"
```

---

### Task 11: Prove cycle-1 completion from current and clean state

**Files:**
- Modify only if verification reveals a defect: files owned by the failing task.
- Record evidence in final handoff; do not add generated build outputs.

**Interfaces:**
- Consumes: all cycle-1 commands, tests, Docker targets, Compose presets, and documentation.
- Produces: requirement-by-requirement evidence and an explicit list of hardware-dependent checks not executed.

- [ ] **Step 1: Run the complete local static and shell suite**

Run:

```bash
./scripts/check_dev_workflow.sh
shellcheck run.sh docker/*.bash scripts/*.bash scripts/lib/*.bash tests/*.bash tests/helpers/*.bash
git diff --check
```

Expected: all commands exit zero.

- [ ] **Step 2: Render every supported Compose preset**

Run the exact commands in Task 3 Step 6 plus the Doosan/full Dev Container merges.

Expected: every configuration exits zero; normalized JSON proves only `trusted_emulator` has the Docker socket and no service has host PID/IPC.

- [ ] **Step 3: Build and smoke the CPU/headless environment**

Run:

```bash
./run.sh doctor base
./run.sh build
./scripts/smoke_container.bash
```

Expected: non-root identity, ROS CLI, writable workspace, and `/chatter` message all pass.

- [ ] **Step 4: Verify host ownership**

Run:

```bash
./run.sh workspace-build
find build install log -maxdepth 1 ! -user "$(id -un)" -print -quit
```

Expected: no output from `find`. If `src/` still has no packages, document that the workspace-build command correctly performs a no-package no-op and instead verify ownership through the smoke file.

- [ ] **Step 5: Audit documentation requirements**

Run:

```bash
rg -n '/home/ahrism|xhost \+local:root|container_name:|pid: host|ipc: host' \
  README.md docs compose.yml compose .devcontainer run.sh
```

Expected: no forbidden personal path or unsafe default. Security documentation may mention forbidden patterns only inside explanatory warnings, so review any output rather than treating all matches as automatic failure.

- [ ] **Step 6: Verify from a clean clone-equivalent archive**

Create a temporary archive from `git HEAD`, extract it outside the working tree, generate `.env`, and run static/Compose checks there:

```bash
tmp="$(mktemp -d)"
git archive HEAD | tar -x -C "$tmp"
cd "$tmp"
./run.sh init --non-interactive
./scripts/check_dev_workflow.sh
docker compose --env-file docker/versions.env --env-file .env config -q
```

Expected: a Git-only copy contains every required file and passes without relying on untracked workspace files.

- [ ] **Step 7: Record hardware-dependent limitations honestly**

Run `./run.sh doctor gpu`, `./run.sh doctor gui`, and `./run.sh doctor full`. Execute GPU/GUI/full runtime smoke only when the doctor passes and the required assets are available. Report unexecuted image builds, Isaac Bridge, RViz/X11, emulator, and hardware motion as unverified rather than inferred.

- [ ] **Step 8: Review all changes and commits**

Run:

```bash
git status --short
git log --oneline --decorate -12
git diff 3b60acf..HEAD --stat
```

Expected: no generated `.env`, Xauthority, build, data, checkpoint, or cache files are staged; every cycle-1 deliverable is tracked.

- [ ] **Step 9: Request final code review and address only evidence-backed findings**

Use `superpowers:requesting-code-review`, provide the design and this plan, then rerun Steps 1–8 after any accepted fix.
