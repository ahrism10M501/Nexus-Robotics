# Core Branch Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve all current local work, then produce a clean `main` foundation containing ROS2 Jazzy, Python/uv, safe Compose profiles, and host Isaac Sim ROS2 Bridge integration without vendor runtime code.

**Architecture:** Rebuild the useful parts of `feat/team-shared-dev-env` behind tests instead of merging the divergent branch. A single non-root multi-stage Dockerfile supplies core targets, generic profile manifests assemble narrowly scoped Compose overrides, and vendor/tutorial content is removed from `main` only after a preservation tag exists.

**Tech Stack:** Git worktrees, Bash, Docker BuildKit, Docker Compose 2.30+, ROS2 Jazzy, Python 3.12, Astral uv, FastDDS, jq, GitHub Actions.

## Global Constraints

- Preserve the dirty `user/damin` and `feat/team-shared-dev-env` worktrees; never reset, clean, checkout over, or stash them.
- Do not push, delete a branch, or run real robot commands in this plan.
- Use forward-only commits; do not rewrite public history.
- `main` owns no Doosan/OpenArm runtime target, installer, service, or Days 5-10 tutorial content.
- Isaac Sim runs on the host; `main` installs neither Isaac Sim nor `IsaacSim-ros_workspaces`.
- Base runtime is non-root and CPU/headless; GPU, GUI, host network, PID, IPC, and Docker socket are opt-in or absent.
- Core Tier 1 targets are Ubuntu 24.04 on linux/amd64 and linux/arm64.
- Docker Compose minimum is 2.30 with BuildKit.
- Use `ROS_BASE_IMAGE=osrf/ros:jazzy-desktop@sha256:1d6f898b6ab77636c40f26298070ad3de5a9e06f0a71cf9ab066fd6b7838f151`.
- Use `UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:88baae1f9fa298996f8313e44559163c535937406d217f1c8ac9d4b86a2020fd`.
- Preserve AI direct pins: `torch==2.7.1`, `torchvision==0.22.1`, `diffusers==0.34.0`, `huggingface-hub==0.33.4`, `einops==0.8.1`, `timm==1.0.17`.
- Public profile files are parsed as data with an allow-list; never `source` them as shell.
- Use exact file staging for every commit so unrelated user changes remain unstaged.

---

## File Structure

### Repository and dependency contracts

- `.dockerignore`: exclude Git state, secrets, worktrees, local artifacts, datasets, and caches from build context.
- `.env.example`: user-local runtime values without vendor fields.
- `docker/versions.env`: immutable common image inputs only.
- `docker/requirements/ai.in`: direct optional AI dependency pins.
- `docker/requirements/ai.lock`: generated hash-locked dependency graph.
- `tests/helpers/assert.bash`: shared shell assertions.
- `tests/test_static_contract.bash`: core ownership, pin, and file contract.

### Build and runtime

- `Dockerfile`: targets `ros-base`, `ros-dev`, `ros-python-dev`, `ros-ai-dev`.
- `docker/nexus_env.bash`: deterministic ROS, venv, and workspace sourcing.
- `compose.yml`: safe CPU/headless `ros2_dev` and optional `ai_dev` services.
- `compose/host-dds.yml`: host network only.
- `compose/gpu.yml`: GPU only for `ai_dev`.
- `compose/gui.yml`: read-only X11/Xauthority only.
- `profiles/core.conf`: default core service and Compose selection.
- `profiles/isaac-host.conf`: core service plus host DDS override.

### Command interface and diagnostics

- `scripts/lib/config.bash`: `.env` initialization and validation without sourcing.
- `scripts/lib/profile.bash`: allow-listed profile parsing and Compose argument construction.
- `run.sh`: generic `<profile>-<action>` dispatcher.
- `scripts/doctor.bash`: compact host/profile prerequisite diagnostics.
- `scripts/launch_isaac_sim.sh`: host Isaac Sim launcher with validated shared ROS settings.

### Tests and CI

- `tests/test_init.bash`: local config creation and rejection cases.
- `tests/test_profiles.bash`: profile parser and generic dispatch contract.
- `tests/test_compose.bash`: normalized least-privilege Compose contract.
- `tests/test_doctor.bash`: compact diagnostics and prerequisite failures.
- `tests/run_all.bash`: deterministic static test entrypoint.
- `.github/workflows/core-environment.yml`: static, amd64 build/smoke, and arm64 build jobs.
- `scripts/check_dev_workflow.sh`: user-facing wrapper around the same static tests.

### Documentation split

- `README.md`: core-only onboarding and profile commands.
- `docs/tutorials/README.md`: Days 1-4 core curriculum only.
- `docs/tutorials/day-01-*` through `day-04-*`: retained common tutorials.
- `docs/tutorials/shared/`: retained common references with portable paths.
- `docs/tutorials/day-05-*` through `day-10-*`: removed from `main`, recoverable from the preservation tag.

---

### Task 1: Preserve current refs and create the isolated implementation worktree

**Files:**
- Create outside repository: `/home/ahrism/workspace/ros2-dev-migration-backup-2026-07-14/user-damin.patch`
- Create outside repository: `/home/ahrism/workspace/ros2-dev-migration-backup-2026-07-14/manifest.txt`
- Create worktree: `/home/ahrism/workspace/ros2-dev/.worktrees/core-branch-migration`

**Interfaces:**
- Consumes: `main=6bb7f14`, approved commits on `user/damin`, dirty root worktree, dirty feature worktree.
- Produces: tag `migration/pre-split-2026-07-14`, backup hashes, branch `refactor/core-branch-layout`, clean isolated worktree.

- [ ] **Step 1: Record current state without mutation**

Run:

```bash
git status --short --branch
git worktree list --porcelain
git rev-parse main user/damin feat/team-shared-dev-env
git diff --binary -- Dockerfile.doosan scripts/check_dev_workflow.sh
sha256sum Dockerfile.doosan scripts/check_dev_workflow.sh \
  'docs/[리버트론]OpenArm(AA-K1)_User Manual_한글판.pdf'
```

Expected: `main` is `6bb7f14`, `user/damin` is `bb0d497`, and the command reports but does not modify the known dirty files.

- [ ] **Step 2: Create a local preservation tag**

Run:

```bash
test "$(git rev-parse main)" = "6bb7f14f748416f64712ce63103bea1b02997fea"
git tag -a migration/pre-split-2026-07-14 6bb7f14 \
  -m "Preserve repository state before robot branch split"
git rev-parse migration/pre-split-2026-07-14^{}
```

Expected: tag resolves to `6bb7f14f748416f64712ce63103bea1b02997fea`.

- [ ] **Step 3: Save the tracked patch and checksums with `apply_patch`**

Capture the exact output of the Step 1 `git diff --binary` and create
`user-damin.patch` with `apply_patch`. Create `manifest.txt` with these exact fields and the
fresh Step 1 values:

```text
source_branch=user/damin
dirty_files_base_commit=bb0d49742fe96eba0a9492d770c92809a8b6a6ff
main_commit=6bb7f14f748416f64712ce63103bea1b02997fea
dockerfile_doosan_sha256=d236f98f1185458b52aab3d6ed49b8eb208a87afcc8662739e4841951422a4a9
check_dev_workflow_sha256=06b0a687b041b3b9a4f66be1b5ca84e606ae1e7a155c3e136a315a62aa64235f
openarm_manual_sha256=6b35dd70c72ac76eed385adfedb9936d13d514fec74e4a8811aa321c888560e6
```

Run:

```bash
sha256sum /home/ahrism/workspace/ros2-dev-migration-backup-2026-07-14/user-damin.patch
```

Expected: the patch has a recorded checksum. Applicability is checked against the clean worktree
in Step 4 rather than against the already-modified root worktree.

- [ ] **Step 4: Create an isolated worktree from the approved design commit**

**REQUIRED SUB-SKILL:** Use `superpowers:using-git-worktrees`.

Run:

```bash
git worktree add .worktrees/core-branch-migration \
  -b refactor/core-branch-layout user/damin
git -C .worktrees/core-branch-migration status --short --branch
test -f .worktrees/core-branch-migration/docs/superpowers/plans/2026-07-14-core-branch-migration.md
git -C .worktrees/core-branch-migration apply --check \
  /home/ahrism/workspace/ros2-dev-migration-backup-2026-07-14/user-damin.patch
```

Expected: clean `refactor/core-branch-layout` worktree at the approved `user/damin` tip; the plan
is present and the preserved patch applies.

---

### Task 2: Add immutable core repository contracts

**Files:**
- Create: `.dockerignore`
- Create: `.env.example`
- Modify: `.gitignore`
- Create: `docker/versions.env`
- Create: `docker/requirements/ai.in`
- Create: `docker/requirements/ai.lock`
- Create: `tests/helpers/assert.bash`
- Create: `tests/test_static_contract.bash`

**Interfaces:**
- Consumes: immutable image and AI values from Global Constraints.
- Produces: `assert_file`, `assert_contains`, `assert_not_contains`, common version inputs, and the repository ownership test.

- [ ] **Step 1: Write the failing static contract**

Create `tests/helpers/assert.bash`:

```bash
#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_file() { test -f "$1" || fail "missing file: $1"; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"; }
assert_not_contains() { ! grep -Fq -- "$2" "$1" || fail "$1 contains forbidden text: $2"; }
```

Create `tests/test_static_contract.bash`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source tests/helpers/assert.bash

for path in .dockerignore .env.example docker/versions.env \
  docker/requirements/ai.in docker/requirements/ai.lock; do
  assert_file "$path"
done
assert_contains docker/versions.env \
  'ROS_BASE_IMAGE=osrf/ros:jazzy-desktop@sha256:1d6f898b6ab77636c40f26298070ad3de5a9e06f0a71cf9ab066fd6b7838f151'
assert_contains docker/versions.env \
  'UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:88baae1f9fa298996f8313e44559163c535937406d217f1c8ac9d4b86a2020fd'
assert_not_contains docker/versions.env 'DOOSAN'
assert_not_contains docker/versions.env 'OPENARM'
assert_not_contains docker/versions.env 'ISAAC_ROS'
assert_contains .dockerignore '.env'
assert_contains .dockerignore '.worktrees'
assert_contains .dockerignore 'data'
assert_contains .dockerignore 'checkpoints'
printf 'static core contract passed\n'
```

- [ ] **Step 2: Run the contract and verify RED**

Run: `bash tests/test_static_contract.bash`

Expected: FAIL with `missing file: .dockerignore`.

- [ ] **Step 3: Add exact core inputs**

Create `.dockerignore`:

```text
.git
.github
.env
.worktrees
.superpowers
build
install
log
data
checkpoints
user-ws
__pycache__
.pytest_cache
.ruff_cache
.vscode
*.pyc
```

Create `.env.example`:

```dotenv
COMPOSE_PROJECT_NAME=ros2-dev-local
LOCAL_UID=1000
LOCAL_GID=1000
ROS_DOMAIN_ID=42
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
DISPLAY=:0
ISAAC_SIM_ROOT=/home/user/isaacsim
NEXUS_XAUTH_FILE=/tmp/nexus.xauth
```

Create `docker/versions.env`:

```dotenv
ROS_BASE_IMAGE=osrf/ros:jazzy-desktop@sha256:1d6f898b6ab77636c40f26298070ad3de5a9e06f0a71cf9ab066fd6b7838f151
UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:88baae1f9fa298996f8313e44559163c535937406d217f1c8ac9d4b86a2020fd
```

Create `docker/requirements/ai.in`:

```text
torch==2.7.1
torchvision==0.22.1
diffusers==0.34.0
huggingface-hub==0.33.4
einops==0.8.1
timm==1.0.17
```

Append these exact lines to `.gitignore`:

```text
.env
.xauth-*
```

- [ ] **Step 4: Generate the lock as the host user**

Run:

```bash
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$PWD:/workspace" -w /workspace \
  ghcr.io/astral-sh/uv:0.8.3@sha256:88baae1f9fa298996f8313e44559163c535937406d217f1c8ac9d4b86a2020fd \
  /uv pip compile --python-version 3.12 --generate-hashes \
  --output-file docker/requirements/ai.lock docker/requirements/ai.in
```

Expected: lock contains all six direct pins and at least one `--hash=sha256:`.

- [ ] **Step 5: Verify GREEN and commit**

Run:

```bash
bash tests/test_static_contract.bash
grep -q -- '--hash=sha256:' docker/requirements/ai.lock
git diff --check
git add .dockerignore .env.example .gitignore docker/versions.env \
  docker/requirements/ai.in docker/requirements/ai.lock \
  tests/helpers/assert.bash tests/test_static_contract.bash
git commit -m "build: add immutable core environment inputs"
```

Expected: `static core contract passed`; commit contains only listed files.

---

### Task 3: Consolidate the non-root core Docker targets

**Files:**
- Modify: `Dockerfile`
- Modify: `docker/nexus_env.bash`
- Modify: `tests/test_static_contract.bash`

**Interfaces:**
- Consumes: `ROS_BASE_IMAGE`, `UV_IMAGE`, `docker/requirements/ai.lock`.
- Produces: targets `ros-base`, `ros-dev`, `ros-python-dev`, `ros-ai-dev`; runtime user `developer`; `/opt/venv`.

- [ ] **Step 1: Extend the failing Docker contract**

Append to `tests/test_static_contract.bash` before its final success message:

```bash
for target in 'AS ros-base' 'AS ros-dev' 'AS ros-python-dev' 'AS ros-ai-dev'; do
  assert_contains Dockerfile "$target"
done
assert_contains Dockerfile 'USER developer'
assert_contains Dockerfile 'COPY --from=uv-bin /uv /uvx /usr/local/bin/'
assert_not_contains Dockerfile 'curl -LsSf https://astral.sh/uv/install.sh'
for vendor in DOOSAN OPENARM ISAAC_ROS; do
  assert_not_contains Dockerfile "$vendor"
done
```

- [ ] **Step 2: Run and verify RED**

Run: `bash tests/test_static_contract.bash`

Expected: FAIL at `AS ros-base`.

- [ ] **Step 3: Replace `Dockerfile` with the exact stage contract**

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
ENV VENV_DIR=/opt/venv
ENV PATH="${VENV_DIR}/bin:${PATH}"

COPY --from=uv-bin /uv /uvx /usr/local/bin/
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash-completion ca-certificates curl sudo \
    && rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    groupadd --gid "${DEVELOPER_GID}" "${DEVELOPER_NAME}"; \
    useradd --uid "${DEVELOPER_UID}" --gid "${DEVELOPER_GID}" \
      --create-home --shell /bin/bash "${DEVELOPER_NAME}"; \
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${DEVELOPER_NAME}" \
      > "/etc/sudoers.d/${DEVELOPER_NAME}"; \
    chmod 0440 "/etc/sudoers.d/${DEVELOPER_NAME}"; \
    install -d -o "${DEVELOPER_NAME}" -g "${DEVELOPER_NAME}" /workspace
COPY docker/nexus_env.bash /etc/profile.d/nexus_env.bash
RUN printf '\nsource /etc/profile.d/nexus_env.bash\n' \
      >> "/home/${DEVELOPER_NAME}/.bashrc"
WORKDIR /workspace
USER developer

FROM ros-base AS ros-dev
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential gdb git iproute2 iputils-ping jq less lsof net-tools procps \
      python3-colcon-common-extensions python3-pip python3-rosdep python3-vcstool \
      ros-jazzy-rmw-fastrtps-cpp \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
USER developer

FROM ros-dev AS ros-python-dev
USER root
RUN uv venv "${VENV_DIR}" --system-site-packages \
    && chown -R developer:developer "${VENV_DIR}"
WORKDIR /workspace
USER developer

FROM ros-python-dev AS ros-ai-dev
USER root
COPY docker/requirements/ai.lock /tmp/ai.lock
RUN uv pip sync --python "${VENV_DIR}" /tmp/ai.lock \
    && chown -R developer:developer "${VENV_DIR}"
WORKDIR /workspace
USER developer
```

- [ ] **Step 4: Make environment sourcing deterministic**

Replace `docker/nexus_env.bash` with:

```bash
#!/usr/bin/env bash
test ! -f /opt/ros/jazzy/setup.bash || source /opt/ros/jazzy/setup.bash
test ! -f /opt/venv/bin/activate || source /opt/venv/bin/activate
test ! -f /workspace/install/setup.bash || source /workspace/install/setup.bash

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-42}"
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_fastrtps_cpp}"
if [[ -f /workspace/config/fastdds.xml ]]; then
  export FASTDDS_DEFAULT_PROFILES_FILE=/workspace/config/fastdds.xml
  export FASTRTPS_DEFAULT_PROFILES_FILE=/workspace/config/fastdds.xml
fi
```

- [ ] **Step 5: Verify stages and commit**

Run:

```bash
bash -n docker/nexus_env.bash
bash tests/test_static_contract.bash
docker build --target ros-python-dev \
  --build-arg DEVELOPER_UID="$(id -u)" --build-arg DEVELOPER_GID="$(id -g)" .
docker build --target ros-ai-dev \
  --build-arg DEVELOPER_UID="$(id -u)" --build-arg DEVELOPER_GID="$(id -g)" .
git diff --check
git add Dockerfile docker/nexus_env.bash tests/test_static_contract.bash
git commit -m "build: consolidate non-root core targets"
```

Expected: both targets build, static contract passes, no vendor token appears in `Dockerfile`.

---

### Task 4: Add safe Compose overlays and profile manifests

**Files:**
- Modify: `compose.yml`
- Create: `compose/host-dds.yml`
- Create: `compose/gpu.yml`
- Create: `compose/gui.yml`
- Create: `profiles/core.conf`
- Create: `profiles/isaac-host.conf`
- Create: `tests/test_compose.bash`

**Interfaces:**
- Consumes: Docker targets, `.env.example`, `docker/versions.env`.
- Produces: services `ros2_dev`, `ai_dev`; independent host DDS/GPU/GUI overlays; manifest keys from the spec.

- [ ] **Step 1: Write a failing normalized Compose test**

Create `tests/test_compose.bash` that renders JSON with:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cp .env.example "$tmp/local.env"
base="$tmp/base.json"
docker compose --env-file docker/versions.env --env-file "$tmp/local.env" \
  -f compose.yml config --format json > "$base"
jq -e '.services.ros2_dev.build.target == "ros-python-dev"' "$base"
jq -e '.services.ros2_dev.user != "0" and .services.ros2_dev.user != "root"' "$base"
jq -e '.services.ros2_dev | has("container_name") | not' "$base"
jq -e '.services.ros2_dev | has("network_mode") | not' "$base"
jq -e '.services.ros2_dev | has("pid") | not' "$base"
jq -e '.services.ros2_dev | has("ipc") | not' "$base"
jq -e '[.services.ros2_dev.volumes[]?.target] | index("/var/run/docker.sock") | not' "$base"
! grep -Eqi 'doosan|openarm|isaac_ros' "$base"
printf 'compose core contract passed\n'
```

- [ ] **Step 2: Run and verify RED**

Run: `bash tests/test_compose.bash`

Expected: FAIL because current base has fixed name and host privileges.

- [ ] **Step 3: Implement base services and independent overrides**

Use anchors for build args and non-root service defaults. `compose.yml` must define only:

```yaml
services:
  ros2_dev:
    build: {context: ., dockerfile: Dockerfile, target: ros-python-dev}
  ai_dev:
    profiles: [ai]
    build: {context: ., dockerfile: Dockerfile, target: ros-ai-dev}
```

Both services must set `user: "${LOCAL_UID}:${LOCAL_GID}"`, `init: true`, ROS/FastDDS
environment, and only `.:/workspace:rw`. Add the same two service keys to each override:

```yaml
# compose/host-dds.yml
services:
  ros2_dev: {network_mode: host}
  ai_dev: {network_mode: host}
```

```yaml
# compose/gpu.yml
services:
  ai_dev:
    gpus: all
    environment:
      NVIDIA_VISIBLE_DEVICES: all
      NVIDIA_DRIVER_CAPABILITIES: compute,utility
```

```yaml
# compose/gui.yml
services:
  ros2_dev:
    environment: {DISPLAY: "${DISPLAY}", XAUTHORITY: /tmp/.nexus.xauth, QT_X11_NO_MITSHM: "1"}
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix:ro
      - ${NEXUS_XAUTH_FILE}:/tmp/.nexus.xauth:ro
```

Create manifests:

```text
# profiles/core.conf
PROFILE_VERSION=1
SERVICE=ros2_dev
COMPOSE_FILES=compose.yml
COMPOSE_PROFILES=
DOCTOR_COMMAND=base
CHECK_COMMAND=core
```

```text
# profiles/isaac-host.conf
PROFILE_VERSION=1
SERVICE=ros2_dev
COMPOSE_FILES=compose.yml,compose/host-dds.yml
COMPOSE_PROFILES=
DOCTOR_COMMAND=isaac-host
CHECK_COMMAND=isaac-host
```

- [ ] **Step 4: Expand tests for override scope**

Render each override combination and assert:

```bash
docker compose --env-file docker/versions.env --env-file "$tmp/local.env" \
  -f compose.yml -f compose/host-dds.yml config --format json > "$tmp/host.json"
jq -e '.services.ros2_dev.network_mode == "host"' "$tmp/host.json"
docker compose --env-file docker/versions.env --env-file "$tmp/local.env" \
  -f compose.yml -f compose/gpu.yml --profile ai config --format json > "$tmp/gpu.json"
jq -e '.services.ai_dev.gpus != null' "$tmp/gpu.json"
jq -e '.services.ros2_dev | has("gpus") | not' "$tmp/gpu.json"
```

- [ ] **Step 5: Verify GREEN and commit**

Run:

```bash
bash tests/test_compose.bash
docker compose --env-file docker/versions.env --env-file .env.example config -q
git diff --check
git add compose.yml compose profiles tests/test_compose.bash
git commit -m "build: isolate core runtime privileges"
```

Expected: `compose core contract passed`; no vendor service exists.

---

### Task 5: Implement the generic profile command interface

**Files:**
- Modify: `run.sh`
- Create: `scripts/lib/config.bash`
- Create: `scripts/lib/profile.bash`
- Create: `tests/test_init.bash`
- Create: `tests/test_profiles.bash`

**Interfaces:**
- Produces: `nexus_init_env`, `nexus_validate_env`, `nexus_load_profile`, `nexus_compose_args`; `./run.sh <profile>-<action>`.
- Consumes: `.env.example`, `docker/versions.env`, `profiles/<name>.conf`.

- [ ] **Step 1: Write failing init and profile tests**

Test these exact behaviors in temporary directories:

```text
init creates .env once and never overwrites it
invalid UID/GID/domain/project values fail
unknown profile key fails
missing profile reports E_PROFILE
core-dev resolves service ros2_dev and compose.yml
isaac-host-dev resolves compose.yml plus compose/host-dds.yml
doosan-dev on main fails E_PROFILE
profile values containing shell metacharacters are rejected
```

The test command is `bash tests/test_init.bash && bash tests/test_profiles.bash`.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because `scripts/lib/profile.bash` does not exist.

- [ ] **Step 3: Implement safe data parsing**

`scripts/lib/profile.bash` must read each non-comment `KEY=VALUE` line, accept only
`PROFILE_VERSION`, `SERVICE`, `COMPOSE_FILES`, `COMPOSE_PROFILES`, `DOCTOR_COMMAND`,
`CHECK_COMMAND`, reject values outside `[A-Za-z0-9_./,:-]*`, require version `1`, and populate
arrays without `eval` or `source`.

`scripts/lib/config.bash` must parse `.env` with the same data-only rule, validate UID/GID as
positive integers, domain `0..232`, project name `[a-z0-9][a-z0-9_-]*`, copy `.env.example`
only when `.env` is absent, and never overwrite an existing file.

- [ ] **Step 4: Replace `run.sh` with generic dispatch**

The dispatcher must support:

```text
init, doctor, build, up, shell, dev, check, status, down
<profile>-build, <profile>-up, <profile>-shell, <profile>-dev,
<profile>-check, <profile>-status, <profile>-down
```

The suffix determines the action, the remaining prefix determines `profiles/<name>.conf`, and
unprefixed lifecycle commands use `core`. Every Docker command uses both env files and every
manifest Compose file. No vendor name appears in `run.sh`.

- [ ] **Step 5: Verify GREEN and commit**

Run:

```bash
bash -n run.sh scripts/lib/config.bash scripts/lib/profile.bash
bash tests/test_init.bash
bash tests/test_profiles.bash
! grep -Eqi 'doosan|openarm|isaac_ros' run.sh
git diff --check
git add run.sh scripts/lib/config.bash scripts/lib/profile.bash \
  tests/test_init.bash tests/test_profiles.bash
git commit -m "feat: add generic environment profiles"
```

Expected: both test suites pass and vendor grep returns no match.

---

### Task 6: Add compact diagnostics and host Isaac launcher validation

**Files:**
- Create: `scripts/doctor.bash`
- Modify: `scripts/launch_isaac_sim.sh`
- Create: `tests/test_doctor.bash`

**Interfaces:**
- Produces: `./run.sh doctor [core|isaac-host]`, error codes `E_PREREQUISITE` and compact PASS/FAIL output.
- Consumes: `.env`, `ISAAC_SIM_ROOT`, Docker/Compose commands, FastDDS config.

- [ ] **Step 1: Write failing doctor scenarios**

Cover missing Docker, Compose below 2.30, invalid env, missing Isaac root, non-executable launcher,
and success. Stub commands through a temporary `PATH`; assert default output is at most six lines
and `--verbose` includes individual checks.

- [ ] **Step 2: Verify RED**

Run: `bash tests/test_doctor.bash`

Expected: FAIL because `scripts/doctor.bash` is absent.

- [ ] **Step 3: Implement doctor and launcher contracts**

`scripts/doctor.bash` must return non-zero with:

```text
FAIL E_PREREQUISITE
<missing or invalid item>
<one remediation command>
```

Core checks Docker Engine, Compose 2.30+, BuildKit availability, env validity, and repository
files. Isaac-host additionally checks `$ISAAC_SIM_ROOT/isaac-sim.sh`, host network support,
`config/fastdds.xml`, and matching ROS domain/RMW settings.

`scripts/launch_isaac_sim.sh` must derive its root only from `ISAAC_SIM_ROOT` or the documented
default, export `ROS_DOMAIN_ID`, `RMW_IMPLEMENTATION`, and both FastDDS profile variables, then
`exec "$ISAAC_SIM_ROOT/isaac-sim.sh" "$@"`. It must not install or download Isaac Sim.

- [ ] **Step 4: Verify GREEN and commit**

Run:

```bash
bash -n scripts/doctor.bash scripts/launch_isaac_sim.sh
bash tests/test_doctor.bash
git diff --check
git add scripts/doctor.bash scripts/launch_isaac_sim.sh tests/test_doctor.bash
git commit -m "feat: add core and host Isaac diagnostics"
```

Expected: doctor tests pass with compact output.

---

### Task 7: Remove vendor runtime and split the tutorial curriculum from `main`

**Files:**
- Delete: `Dockerfile.doosan`
- Delete: `Dockerfile.isaac-moveit`
- Delete: `docker/bootstrap_doosan_emulator.bash`
- Delete: `.devcontainer/doosan/compose.yml`
- Delete: `.devcontainer/doosan/devcontainer.json`
- Delete: `docs/tutorials/day-05-*` through `docs/tutorials/day-10-*`
- Modify: `README.md`
- Modify: `docs/tutorials/README.md`
- Modify: `docs/tutorials/shared/environment-setup.md`
- Modify: `docs/tutorials/shared/README.md`
- Modify: `docs/tutorials/shared/official-tutorial-map.md`
- Modify: `docs/tutorials/shared/cube-pick-v1-dataset-policy-interface.md`
- Modify: `docs/tutorials/shared/later-milestones.md`
- Modify: `docs/tutorials/shared/glossary.md`
- Modify: `scripts/check_dev_workflow.sh`
- Modify: `tests/test_static_contract.bash`

**Interfaces:**
- Consumes: preservation tag for later restoration.
- Produces: vendor-free core branch and portable Days 1-4 documentation.

- [ ] **Step 1: Add failing ownership and portability assertions**

Extend the static test to reject tracked paths matching:

```text
Dockerfile.doosan
Dockerfile.isaac-moveit
docker/*doosan*
.devcontainer/doosan/**
docs/tutorials/day-05-*/** through day-10-*/**
```

Also fail when `README.md` or `docs/tutorials/**/*.md` contains `/home/ahrism`, `doosan-dev`,
`full-dev`, `A0912`, or `Dockerfile.doosan`.

- [ ] **Step 2: Run and verify RED**

Run: `bash tests/test_static_contract.bash`

Expected: FAIL on the first tracked vendor path.

- [ ] **Step 3: Delete vendor and leaf tutorial paths with `apply_patch`**

Delete the listed files/directories only after confirming each exists in
`migration/pre-split-2026-07-14`. Do not touch the root dirty worktree; all deletions occur in the
isolated core worktree.

- [ ] **Step 4: Rewrite core documentation**

`README.md` must document clone → init → doctor → build/dev → host Isaac launch, describe only
core/isaac-host profiles, and link Days 1-4. `docs/tutorials/README.md` must list Days 1-4 and state
that Days 5-10 live on the two tutorial branches. Replace absolute repository paths with
`$REPO_ROOT` and Isaac paths with `$ISAAC_SIM_ROOT`. Rewrite `shared/README.md`,
`official-tutorial-map.md`, `environment-setup.md`, and `glossary.md` around Days 1-4 only.
Remove A0912-specific dataset and later-milestone content from the two shared files while retaining
their exact originals in the preservation tag for `doosan-tutorial` restoration.

Replace `scripts/check_dev_workflow.sh` with a wrapper:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
exec tests/run_all.bash
```

- [ ] **Step 5: Verify GREEN and commit**

Run:

```bash
bash tests/test_static_contract.bash
! git ls-files | grep -E '(^Dockerfile\.(doosan|isaac-moveit)$|doosan|day-(05|06|07|08|09|10)-)'
! rg -n '/home/ahrism|doosan-dev|full-dev|A0912' README.md docs/tutorials
git diff --check
git add -A -- README.md Dockerfile.doosan Dockerfile.isaac-moveit \
  .devcontainer/doosan docker/bootstrap_doosan_emulator.bash \
  docs/tutorials scripts/check_dev_workflow.sh tests/test_static_contract.bash
git commit -m "refactor: keep main vendor neutral"
```

Expected: ownership test passes and preservation tag still contains every deleted path.

---

### Task 8: Add the unified test entrypoint and core CI

**Files:**
- Create: `tests/run_all.bash`
- Create: `.github/workflows/core-environment.yml`
- Modify: `tests/test_static_contract.bash`

**Interfaces:**
- Produces: `tests/run_all.bash`; CI jobs `static`, `build-amd64`, `build-arm64`.
- Consumes: all Task 2-7 tests and Docker targets.

- [ ] **Step 1: Write the test runner contract**

Create `tests/run_all.bash`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
for test_file in \
  tests/test_static_contract.bash \
  tests/test_init.bash \
  tests/test_profiles.bash \
  tests/test_compose.bash \
  tests/test_doctor.bash; do
  bash "$test_file"
done
printf 'all core tests passed\n'
```

Add a static assertion that the workflow contains `linux/amd64`, `linux/arm64`, and
`tests/run_all.bash`.

- [ ] **Step 2: Verify RED**

Run: `bash tests/test_static_contract.bash`

Expected: FAIL because `.github/workflows/core-environment.yml` is missing.

- [ ] **Step 3: Add CI jobs**

The workflow must run on pull requests and pushes to `main`, install jq and Docker Buildx, run
`tests/run_all.bash`, build `ros-python-dev` for both platforms without publishing, and run an
amd64 container smoke command that verifies:

```bash
id -u
python --version
uv --version
ros2 pkg prefix demo_nodes_cpp
test "$ROS_DISTRO" = jazzy
```

No job may build vendor targets, push images, mount Docker socket into a runtime service, or run
hardware commands.

- [ ] **Step 4: Verify GREEN and commit**

Run:

```bash
bash tests/run_all.bash
git diff --check
git add tests/run_all.bash tests/test_static_contract.bash \
  .github/workflows/core-environment.yml
git commit -m "ci: verify portable core environment"
```

Expected: `all core tests passed`.

---

### Task 9: Full core acceptance and local `main` integration

**Files:**
- No new files.
- Update local branch ref through a reviewed merge only after acceptance.

**Interfaces:**
- Consumes: completed `refactor/core-branch-layout`.
- Produces: verified local `main` containing the approved design and core implementation.

- [ ] **Step 1: Run complete static and configuration verification**

Run:

```bash
bash tests/run_all.bash
docker compose --env-file docker/versions.env --env-file .env.example config -q
git diff --check main...HEAD
git status --short
```

Expected: all tests pass, Compose parses, diff check is empty, worktree is clean.

- [ ] **Step 2: Build and smoke the lightweight image**

Run:

```bash
docker build --target ros-python-dev -t nexus-ros-core:test .
docker run --rm nexus-ros-core:test bash -lc \
  'source /etc/profile.d/nexus_env.bash && test "$ROS_DISTRO" = jazzy && \
   python --version && uv --version && ros2 pkg prefix demo_nodes_cpp && test "$(id -u)" != 0'
```

Expected: exit zero, Jazzy visible, Python/uv visible, runtime UID is non-zero.

- [ ] **Step 3: Review ownership diff**

Run:

```bash
git diff --name-status main...HEAD
git log --oneline --decorate main..HEAD
git show migration/pre-split-2026-07-14:Dockerfile.doosan >/dev/null
git show migration/pre-split-2026-07-14:docs/tutorials/day-06-doosan-a0912-bringup/README.md >/dev/null
```

Expected: core files changed, vendor/tutorial files are deletions only, preservation tag restores both examples.

- [ ] **Step 4: Merge locally without push**

Create a clean `main` worktree, then run:

```bash
git merge --no-ff refactor/core-branch-layout \
  -m "merge: establish vendor-neutral ROS2 core"
git status --short --branch
bash tests/run_all.bash
```

Expected: local `main` contains a merge commit and tests still pass. Do not push.

---

## Self-Review Coverage

- Preservation and dirty worktree safety: Task 1.
- Immutable inputs and Python/uv: Tasks 2-3.
- Least-privilege, host Isaac-only Compose: Tasks 4 and 6.
- Extensible profile interface without vendor hardcoding: Task 5.
- Vendor/tutorial removal with recoverable history: Task 7.
- amd64/arm64 and core runtime verification: Tasks 8-9.
- AI Agent governance, Doosan, OpenArm, and tutorial implementations remain intentionally in their separate plans defined by the approved umbrella spec.
