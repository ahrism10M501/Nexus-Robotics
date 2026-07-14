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
- Use `ROS_BASE_IMAGE=ros:jazzy-ros-base-noble@sha256:31daab66eef9139933379fb67159449944f4e2dcf2e22c2d12cc715f29873e0f`.
- Use `UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:ef11ed817e6a5385c02cd49fdcc99c23d02426088252a8eace6b6e6a2a511f36`.
- Both immutable pins are OCI indexes that expose `linux/amd64` and `linux/arm64`.
- The minimal ROS base is intentional; `ros-dev` must explicitly install `ros-jazzy-desktop`
  to preserve Days 1-4, demo-node, and RViz capabilities.
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
- `scripts/generate_ai_lock.bash`: reproducibly generate and validate the universal AI lock.
- `tests/helpers/assert.bash`: shared shell assertions.
- `tests/test_static_contract.bash`: core ownership, pin, and file contract.
- `tests/test_ai_lock.bash`: lock pins, markers, hashes, and two-platform wheel validation.
- `tests/test_image_indexes.bash`: live OCI-index amd64/arm64 contract for both exact pins.

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

### Task 1: Verify the completed preservation baseline without replaying it

**Files:**
- Verify outside repository: `/home/ahrism/workspace/ros2-dev-migration-backup-2026-07-14/user-damin.patch`
- Verify outside repository: `/home/ahrism/workspace/ros2-dev-migration-backup-2026-07-14/manifest.txt`
- Verify outside repository: `/home/ahrism/workspace/ros2-dev-migration-backup-2026-07-14/root-worktree.manifest`
- Verify outside repository: `/home/ahrism/workspace/ros2-dev-migration-backup-2026-07-14/feature-worktree.manifest`
- Verify worktree: `/home/ahrism/workspace/ros2-dev/.worktrees/core-branch-migration`

**Interfaces:**
- Consumes: the already-created preservation tag, backup, and isolated branch.
- Produces: a read-only proof that execution may continue from
  a forward descendant of `e6da3b444d501e2175517efb4c5b983b5fa5701b` without mutating either dirty worktree.

Task 1 and the original immutable-input commit have already happened. Do not recreate the tag or
worktree, amend `e6da3b4`, reset/rebase the branch, or replay the old Task 2 commit. All corrections
below are forward-only commits.

- [ ] **Step 1: Verify exact refs and the existing worktree**

Run:

```bash
test "$(git rev-parse main)" = "6bb7f14f748416f64712ce63103bea1b02997fea"
test "$(git rev-parse origin/main)" = "6bb7f14f748416f64712ce63103bea1b02997fea"
test "$(git rev-parse migration/pre-split-2026-07-14^{})" = \
  "6bb7f14f748416f64712ce63103bea1b02997fea"
test "$(git rev-parse user/damin)" = \
  "744a8a9bda98dd6b7fd50a0703bf6fefab981bc5"
git merge-base --is-ancestor e6da3b444d501e2175517efb4c5b983b5fa5701b HEAD
test "$(git branch --show-current)" = "refactor/core-branch-layout"
test -z "$(git status --short)"
```

Expected: every assertion succeeds. The final clean-HEAD assertion applies before implementing
this corrected plan; later tasks instead require only their intentional files to be dirty.

- [ ] **Step 2: Verify the backup manifest and protected dirty content**

Run:

```bash
BACKUP=/home/ahrism/workspace/ros2-dev-migration-backup-2026-07-14
ROOT=/home/ahrism/workspace/ros2-dev
FEATURE="$ROOT/.worktrees/team-shared-dev-env"
grep -Fx 'source_tip_commit=744a8a9bda98dd6b7fd50a0703bf6fefab981bc5' "$BACKUP/manifest.txt"
grep -Fx 'dirty_files_base_commit=bb0d49742fe96eba0a9492d770c92809a8b6a6ff' "$BACKUP/manifest.txt"
grep -Fx 'main_commit=6bb7f14f748416f64712ce63103bea1b02997fea' "$BACKUP/manifest.txt"
test "$(sha256sum "$BACKUP/manifest.txt" | awk '{print $1}')" = \
  39478896d14aefd7c1f40b46a3117974d45917811d90c108818ccc5cb2df92da
test "$(sha256sum "$BACKUP/user-damin.patch" | awk '{print $1}')" = \
  a44a513e33fe4a31f3eab5b1c878d4dee0169afadc52b2e77bc8306a67bb95f4

manifest_value() { sed -n "s/^$2=//p" "$1"; }
verify_worktree_manifest() {
  local manifest="$1" manifest_sha="$2" wt expected actual line record path file_sha
  test "$(sha256sum "$manifest" | awk '{print $1}')" = "$manifest_sha"
  wt="$(manifest_value "$manifest" worktree)"
  expected="$(manifest_value "$manifest" head)"
  test "$(git -C "$wt" rev-parse HEAD)" = "$expected"
  expected="$(manifest_value "$manifest" status_porcelain_v1_z_sha256)"
  actual="$(git -C "$wt" status --porcelain=v1 -z | sha256sum | awk '{print $1}')"
  test "$actual" = "$expected"
  expected="$(manifest_value "$manifest" tracked_binary_diff_sha256)"
  actual="$(git -C "$wt" diff --binary | sha256sum | awk '{print $1}')"
  test "$actual" = "$expected"
  expected="$(manifest_value "$manifest" untracked_paths_z_sha256)"
  actual="$(git -C "$wt" ls-files --others --exclude-standard -z | sha256sum | awk '{print $1}')"
  test "$actual" = "$expected"
  while IFS= read -r line; do
    case "$line" in
      tracked_sha256=*|untracked_sha256=*)
        record="${line%%  *}"
        path="${line#*  }"
        file_sha="${record#*=}"
        test -f "$wt/$path"
        test "$(sha256sum "$wt/$path" | awk '{print $1}')" = "$file_sha"
        ;;
    esac
  done < "$manifest"
}

test "$(manifest_value "$BACKUP/root-worktree.manifest" head)" = \
  744a8a9bda98dd6b7fd50a0703bf6fefab981bc5
test "$(manifest_value "$BACKUP/feature-worktree.manifest" head)" = \
  bbce9bdb91a76ed57755542586bfcd6e0af61ba9
verify_worktree_manifest "$BACKUP/root-worktree.manifest" \
  ebd801615fe1d523757048ba1f6f884f57956af7181a74f99cc3e7fc3a0e3780
verify_worktree_manifest "$BACKUP/feature-worktree.manifest" \
  09a318b77f6447e78ca9801db3f4ba7583f54c5dd0edaeaa5ea07fd3190eeb5e
test -f "$ROOT/user-ws/damin/tutorial-7.py"
git -C "$ROOT" status --short --branch
git -C "$FEATURE" status --short --branch
```

Expected: both external manifest hashes, exact HEADs, NUL-delimited status and untracked-list
hashes, full binary-diff hashes, and every recorded tracked/untracked file hash match. This includes
the PDF and `user-ws/damin/tutorial-7.py`. Do not clean, stash, reset, or checkout either worktree.

---

### Task 2: Correct the already-committed immutable core contracts forward-only

**Files:**
- Modify: `.env.example`
- Modify: `docker/versions.env`
- Modify: `docker/requirements/ai.lock`
- Create: `scripts/generate_ai_lock.bash`
- Modify: `tests/test_static_contract.bash`
- Create: `tests/test_ai_lock.bash`
- Create: `tests/test_image_indexes.bash`

**Interfaces:**
- Consumes: the initial Task 2 commit `e6da3b4` and the exact OCI-index pins in Global Constraints.
- Produces: corrected immutable inputs, `generate_ai_lock.bash`, and hashed wheel-only validation for
  both Tier 1 architectures. Do not amend or drop `e6da3b4`.

- [ ] **Step 1: Write failing correction tests**

Extend `tests/test_static_contract.bash` to require exactly:

```bash
assert_file scripts/generate_ai_lock.bash
assert_file tests/test_ai_lock.bash
test -x scripts/generate_ai_lock.bash || fail 'lock generator is not executable'
assert_contains docker/versions.env \
  'ROS_BASE_IMAGE=ros:jazzy-ros-base-noble@sha256:31daab66eef9139933379fb67159449944f4e2dcf2e22c2d12cc715f29873e0f'
assert_contains docker/versions.env \
  'UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:ef11ed817e6a5385c02cd49fdcc99c23d02426088252a8eace6b6e6a2a511f36'
assert_contains .env.example 'ISAAC_SIM_ROOT='
assert_contains .env.example 'ISAAC_SIM_COMPAT_VERSION=6.0.1'
assert_not_contains .env.example 'ISAAC_SIM_ROOT=/home/'
```

Create `tests/test_ai_lock.bash` with these exact assertions:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source tests/helpers/assert.bash
pins=(
  'torch==2.7.1' 'torchvision==0.22.1' 'diffusers==0.34.0'
  'huggingface-hub==0.33.4' 'einops==0.8.1' 'timm==1.0.17'
)
for pin in "${pins[@]}"; do
  test "$(grep -Fxc "$pin" docker/requirements/ai.in)" -eq 1 || \
    fail "direct input pin must occur exactly once: $pin"
  escaped="${pin//./\\.}"
  test "$(grep -Ec "^${escaped}([ ;\\]|$)" docker/requirements/ai.lock)" -eq 1 || \
    fail "direct lock pin must occur exactly once: $pin"
done
grep -q -- '--hash=sha256:' docker/requirements/ai.lock || fail 'lock has no hashes'
grep -Eq '^nvidia-.*platform_machine.*x86_64' docker/requirements/ai.lock || \
  fail 'NVIDIA dependencies are not x86_64-marked'
grep -Eq '^triton==.*platform_machine.*x86_64' docker/requirements/ai.lock || \
  fail 'triton is not x86_64-marked'
scripts/generate_ai_lock.bash --validate-only
printf 'AI lock contract passed\n'
```

Create `tests/test_image_indexes.bash`. Parse the two trusted data values without sourcing them and
for each exact image run:

```bash
docker buildx imagetools inspect --raw "$image" | jq -e '
  [.manifests[].platform | "\(.os)/\(.architecture)"] as $platforms |
  ($platforms | index("linux/amd64")) != null and
  ($platforms | index("linux/arm64")) != null
'
```

Expected: both exact digest references are OCI indexes and expose both Tier 1 platforms.

- [ ] **Step 2: Run the tests and verify RED against `e6da3b4`**

Run:

```bash
bash tests/test_static_contract.bash
bash tests/test_ai_lock.bash
```

Expected: the static test fails on the new ROS pin or missing generator. This is the intended
forward correction point; do not rewrite the old commit.

- [ ] **Step 3: Correct the data files**

Set `docker/versions.env` to exactly:

```dotenv
ROS_BASE_IMAGE=ros:jazzy-ros-base-noble@sha256:31daab66eef9139933379fb67159449944f4e2dcf2e22c2d12cc715f29873e0f
UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:ef11ed817e6a5385c02cd49fdcc99c23d02426088252a8eace6b6e6a2a511f36
```

Set the Isaac entries in `.env.example` to exactly:

```dotenv
ISAAC_SIM_ROOT=
ISAAC_SIM_COMPAT_VERSION=6.0.1
```

- [ ] **Step 4: Implement isolated lock generation**

`scripts/generate_ai_lock.bash` must parse `docker/versions.env` as data with `awk`; it must not
`source` the file. Require exactly one non-empty `ROS_BASE_IMAGE` and `UV_IMAGE`, reject unknown or
duplicate keys, and compare them with the two Global Constraint pins. Its execution skeleton is:

```bash
tmp="$(mktemp -d)"
uv_container=''
cleanup() {
  test -z "$uv_container" || docker rm -f "$uv_container" >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -m 0700 "$tmp/bin" "$tmp/out"
uv_container="$(docker create "$UV_IMAGE")"
docker cp "$uv_container:/uv" "$tmp/bin/uv"
docker rm "$uv_container" >/dev/null
uv_container=''
chmod 0555 "$tmp/bin/uv"
docker run --rm --read-only --user "$(id -u):$(id -g)" \
  --tmpfs /tmp:rw,nosuid,nodev,mode=1777 \
  --env HOME=/tmp --env UV_CACHE_DIR=/tmp/uv-cache \
  --mount "type=bind,src=$tmp/bin/uv,dst=/usr/local/bin/uv,readonly" \
  --mount "type=bind,src=$ROOT/docker/requirements,dst=/requirements,readonly" \
  --mount "type=bind,src=$tmp/out,dst=/out" \
  "$ROS_BASE_IMAGE" /usr/local/bin/uv pip compile \
    --universal --python-version 3.12 --generate-hashes \
    --output-file /out/ai.lock /requirements/ai.in
install -m 0644 "$tmp/out/ai.lock" "$ROOT/docker/requirements/ai.lock"
```

The real script derives `ROOT` from `BASH_SOURCE`, begins from a newly cleaned `mktemp` directory,
and supports `--validate-only` without rewriting the tracked lock. Generation and validation both
extract the native child of the exact pinned uv OCI index once and run inside the native child of
the exact pinned ROS OCI index. They never mount the repository writable, never execute the uv
scratch image as a runtime, never use QEMU/binfmt, and never use an unpinned image.

For `--validate-only`, reuse that same native pinned uv binary and native pinned ROS container and
create a writable temporary Python 3.12 venv before running the two explicit target-platform
resolutions:

```bash
/usr/local/bin/uv venv --python 3.12 /tmp/venv
/usr/local/bin/uv pip install --dry-run --require-hashes --only-binary=:all: \
  --python /tmp/venv/bin/python --python-version 3.12 \
  --python-platform x86_64-manylinux_2_39 /requirements/ai.lock
/usr/local/bin/uv pip install --dry-run --require-hashes --only-binary=:all: \
  --python /tmp/venv/bin/python --python-version 3.12 \
  --python-platform aarch64-manylinux_2_39 /requirements/ai.lock
```

Expected: both target-platform resolutions select wheels only. An sdist, missing hash, missing
arm64 wheel, duplicate/missing direct pin, or unmarked NVIDIA/triton requirement fails validation.
`tests/test_image_indexes.bash` separately proves both pinned indexes expose amd64 and arm64
children; actual arm64 container execution belongs to authoritative Task 8 CI and, only after the
native/QEMU preflight passes, Task 9 local acceptance.

- [ ] **Step 5: Regenerate, verify, and commit the forward correction**

Run:

```bash
bash -n scripts/generate_ai_lock.bash tests/test_ai_lock.bash
chmod 0755 scripts/generate_ai_lock.bash
test -x scripts/generate_ai_lock.bash
scripts/generate_ai_lock.bash
bash tests/test_static_contract.bash
bash tests/test_ai_lock.bash
bash tests/test_image_indexes.bash
git diff --check
git add .env.example docker/versions.env docker/requirements/ai.lock \
  scripts/generate_ai_lock.bash tests/test_static_contract.bash tests/test_ai_lock.bash \
  tests/test_image_indexes.bash
git diff --cached --name-only
git commit -m "build: correct portable core inputs"
```

Expected: exactly the seven listed paths are committed after `e6da3b4`; both exact pins/indexes,
all six direct pins occur exactly once in each input/lock, hashes and x86_64 NVIDIA/triton markers
pass, and both manylinux target-platform wheel-only dry-runs pass without QEMU.

---

### Task 3: Consolidate the non-root core Docker targets

**Files:**
- Modify: `Dockerfile`
- Modify: `docker/nexus_env.bash`
- Modify: `.devcontainer/devcontainer.json`
- Modify: `tests/test_static_contract.bash`
- Create: `tests/test_docker_runtime.bash`

**Interfaces:**
- Consumes: `ROS_BASE_IMAGE`, `UV_IMAGE`, `docker/requirements/ai.lock`.
- Produces: targets `ros-base`, `ros-dev`, `ros-python-dev`, `ros-ai-dev`; runtime user `developer`; `/opt/venv`.

- [ ] **Step 1: Extend the failing Docker and runtime contracts**

Append to `tests/test_static_contract.bash` before its final success message:

```bash
for target in 'AS ros-base' 'AS ros-dev' 'AS ros-python-dev' 'AS ros-ai-dev'; do
  assert_contains Dockerfile "$target"
done
assert_contains Dockerfile 'USER developer'
assert_contains Dockerfile 'COPY --from=uv-bin /uv /uvx /usr/local/bin/'
assert_contains Dockerfile 'ros-jazzy-desktop'
assert_contains Dockerfile 'uv pip sync --require-hashes'
assert_contains Dockerfile 'uv pip check'
assert_not_contains Dockerfile 'ARG DEVELOPER_NAME'
assert_not_contains Dockerfile 'curl -LsSf https://astral.sh/uv/install.sh'
for vendor in DOOSAN OPENARM ISAAC_ROS; do
  assert_not_contains Dockerfile "$vendor"
done
```

- [ ] **Step 2: Run and verify RED**

Run: `bash tests/test_static_contract.bash`

Expected: FAIL at `AS ros-base` or the explicit desktop/collision-safe account contract.

- [ ] **Step 3: Replace `Dockerfile` with the exact stage contract**

```dockerfile
# syntax=docker/dockerfile:1.7
ARG ROS_BASE_IMAGE=ros:jazzy-ros-base-noble@sha256:31daab66eef9139933379fb67159449944f4e2dcf2e22c2d12cc715f29873e0f
ARG UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:ef11ed817e6a5385c02cd49fdcc99c23d02426088252a8eace6b6e6a2a511f36
FROM ${UV_IMAGE} AS uv-bin
FROM ${ROS_BASE_IMAGE} AS ros-base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DEVELOPER_UID=1000
ARG DEVELOPER_GID=1000
ENV DEBIAN_FRONTEND=noninteractive
ENV VENV_DIR=/opt/venv
ENV PATH="${VENV_DIR}/bin:${PATH}"

COPY --from=uv-bin /uv /uvx /usr/local/bin/
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash-completion ca-certificates curl sudo \
    && rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    test "${DEVELOPER_UID}" -gt 0; \
    test "${DEVELOPER_GID}" -gt 0; \
    gid_name="$(getent group "${DEVELOPER_GID}" | cut -d: -f1 || true)"; \
    if [[ -n "${gid_name}" && "${gid_name}" != developer ]]; then \
      groupmod --new-name developer "${gid_name}"; \
    elif [[ -z "${gid_name}" ]]; then \
      groupadd --gid "${DEVELOPER_GID}" developer; \
    fi; \
    uid_name="$(getent passwd "${DEVELOPER_UID}" | cut -d: -f1 || true)"; \
    if [[ -n "${uid_name}" && "${uid_name}" != developer ]]; then \
      usermod --login developer --home /home/developer --move-home \
        --gid "${DEVELOPER_GID}" --shell /bin/bash "${uid_name}"; \
    elif [[ -z "${uid_name}" ]]; then \
      useradd --uid "${DEVELOPER_UID}" --gid "${DEVELOPER_GID}" \
        --create-home --home-dir /home/developer --shell /bin/bash developer; \
    else \
      usermod --gid "${DEVELOPER_GID}" --home /home/developer \
        --move-home --shell /bin/bash developer; \
    fi; \
    test "$(id -u developer)" = "${DEVELOPER_UID}"; \
    test "$(id -g developer)" = "${DEVELOPER_GID}"; \
    printf 'developer ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/developer; \
    chmod 0440 /etc/sudoers.d/developer; \
    touch /home/developer/.bashrc; \
    install -d -o developer -g developer /workspace /opt/venv; \
    chown developer:developer /home/developer/.bashrc /workspace /opt/venv
COPY docker/nexus_env.bash /etc/profile.d/nexus_env.bash
RUN printf '\nsource /etc/profile.d/nexus_env.bash\n' >> /home/developer/.bashrc \
    && chown developer:developer /home/developer/.bashrc
WORKDIR /workspace
USER developer

FROM ros-base AS ros-dev
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential gdb git iproute2 iputils-ping jq less lsof net-tools procps \
      python3-colcon-common-extensions python3-pip python3-rosdep python3-vcstool \
      ros-jazzy-desktop ros-jazzy-rmw-fastrtps-cpp \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
USER developer

FROM ros-dev AS ros-python-dev
USER root
RUN uv venv "${VENV_DIR}" --system-site-packages \
    && "${VENV_DIR}/bin/python" -c \
      'import sys; assert sys.version_info[:2] == (3, 12), sys.version' \
    && test "$(uv --version)" = 'uv 0.8.3' \
    && chown -R developer:developer "${VENV_DIR}"
WORKDIR /workspace
USER developer

FROM ros-python-dev AS ros-ai-dev
USER root
COPY docker/requirements/ai.lock /tmp/ai.lock
RUN uv pip sync --require-hashes --python "${VENV_DIR}/bin/python" /tmp/ai.lock \
    && uv pip check --python "${VENV_DIR}/bin/python" \
    && "${VENV_DIR}/bin/python" -c \
      'import diffusers, einops, huggingface_hub, timm, torch, torchvision' \
    && "${VENV_DIR}/bin/python" -c \
      'import sys; assert sys.version_info[:2] == (3, 12), sys.version' \
    && test "$(uv --version)" = 'uv 0.8.3' \
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

- [ ] **Step 5: Test both collision paths, exact tools, and AI imports**

Set `.devcontainer/devcontainer.json` to use `"remoteUser": "developer"` and keep the interpreter
at `/opt/venv/bin/python`; no core Dev Container may request root.

Create `tests/test_docker_runtime.bash` to build `ros-python-dev` twice, once with
`DEVELOPER_UID=1000 DEVELOPER_GID=1000` (the Noble `ubuntu:1000` collision) and once with
`12345:12345`. For each image, run as its default user and assert:

```bash
test "$(id -un)" = developer
test "$(id -u)" != 0
test "$(stat -c %U /home/developer/.bashrc)" = developer
test "$(stat -c %U /workspace)" = developer
test "$(stat -c %U /opt/venv)" = developer
python -c 'import sys; assert sys.version_info[:2] == (3, 12)'
test "$(uv --version)" = 'uv 0.8.3'
test "$ROS_DISTRO" = jazzy
ros2 pkg prefix demo_nodes_cpp
```

Also assert builds with UID 0 or GID 0 fail. Build `ros-ai-dev`, run `uv pip check`, and import
all six direct packages from `/opt/venv`. These are runtime tests, not Dockerfile greps.

- [ ] **Step 6: Verify stages and commit**

Run:

```bash
bash -n docker/nexus_env.bash
bash tests/test_static_contract.bash
bash tests/test_docker_runtime.bash
git diff --check
git add Dockerfile docker/nexus_env.bash .devcontainer/devcontainer.json \
  tests/test_static_contract.bash \
  tests/test_docker_runtime.bash
git commit -m "build: consolidate non-root core targets"
```

Expected: both account-ID cases and `ros-ai-dev` pass; UID/GID 0 fail; Python is 3.12, uv is
exactly 0.8.3, ROS desktop/demo/RViz packages are present, the hash lock is enforced, and no vendor
token appears in `Dockerfile`.

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
  -f compose.yml --profile ai config --format json > "$base"
jq -e '.services.ros2_dev.build.target == "ros-python-dev"' "$base"
for service in ros2_dev ai_dev; do
  jq -e --arg s "$service" '.services[$s].user == "developer"' "$base"
  jq -e --arg s "$service" '.services[$s] | has("container_name") | not' "$base"
  jq -e --arg s "$service" '.services[$s] | has("network_mode") | not' "$base"
  jq -e --arg s "$service" '.services[$s] | has("pid") | not' "$base"
  jq -e --arg s "$service" '.services[$s] | has("ipc") | not' "$base"
  jq -e --arg s "$service" '.services[$s].privileged != true' "$base"
  jq -e --arg s "$service" '(.services[$s].cap_add // []) | length == 0' "$base"
  jq -e --arg s "$service" '(.services[$s].devices // []) | length == 0' "$base"
  jq -e --arg s "$service" '(.services[$s].device_cgroup_rules // []) | length == 0' "$base"
  jq -e --arg s "$service" \
    '[.services[$s].volumes[]?.target] | index("/var/run/docker.sock") | not' "$base"
  for arg in ROS_BASE_IMAGE UV_IMAGE DEVELOPER_UID DEVELOPER_GID; do
    jq -e --arg s "$service" --arg a "$arg" '.services[$s].build.args[$a] != null' "$base"
  done
done
! grep -Eqi 'doosan|openarm|isaac_ros' "$base"
printf 'compose core contract passed\n'
```

- [ ] **Step 2: Run and verify RED**

Run: `bash tests/test_compose.bash`

Expected: FAIL because current base has fixed name and host privileges.

- [ ] **Step 3: Implement base services and independent overrides**

Use anchors for build args and non-root service defaults. Mirror the exact immutable literals from
`docker/versions.env` as fallback defaults so direct Dev Container Compose startup does not depend
on `--env-file docker/versions.env`. Both services must include:

```yaml
build:
  context: .
  dockerfile: Dockerfile
  args:
    ROS_BASE_IMAGE: "${ROS_BASE_IMAGE:-ros:jazzy-ros-base-noble@sha256:31daab66eef9139933379fb67159449944f4e2dcf2e22c2d12cc715f29873e0f}"
    UV_IMAGE: "${UV_IMAGE:-ghcr.io/astral-sh/uv:0.8.3@sha256:ef11ed817e6a5385c02cd49fdcc99c23d02426088252a8eace6b6e6a2a511f36}"
    DEVELOPER_UID: "${LOCAL_UID:-1000}"
    DEVELOPER_GID: "${LOCAL_GID:-1000}"
user: developer
```

`ros2_dev` selects `ros-python-dev`; `ai_dev` is in profile `ai` and selects `ros-ai-dev`. Both set
`init: true`, ROS/FastDDS environment, and only the repository workspace bind. Express that bind,
like every bind in every file, with long syntax and `bind.create_host_path: false`. Keep the approved
public profile files `core.conf` and `isaac-host.conf`; do not add a vendor-named profile.

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
x-gui: &gui
  environment: {DISPLAY: "${DISPLAY}", XAUTHORITY: /tmp/.nexus.xauth, QT_X11_NO_MITSHM: "1"}
  volumes:
    - type: bind
      source: /tmp/.X11-unix
      target: /tmp/.X11-unix
      read_only: true
      bind: {create_host_path: false}
    - type: bind
      source: "${NEXUS_XAUTH_FILE:?NEXUS_XAUTH_FILE is required}"
      target: /tmp/.nexus.xauth
      read_only: true
      bind: {create_host_path: false}
services:
  ros2_dev: *gui
  ai_dev: *gui
```

Create manifests:

```text
# profiles/core.conf
PROFILE_VERSION=1
SERVICE=ros2_dev
COMPOSE_FILES=compose.yml
COMPOSE_PROFILES=
DOCTOR_COMMAND=scripts/doctor.bash,base
CHECK_COMMAND=scripts/check_dev_workflow.sh
```

```text
# profiles/isaac-host.conf
PROFILE_VERSION=1
SERVICE=ros2_dev
COMPOSE_FILES=compose.yml,compose/host-dds.yml
COMPOSE_PROFILES=
DOCTOR_COMMAND=scripts/doctor.bash,isaac-host
CHECK_COMMAND=scripts/check_dev_workflow.sh
```

- [ ] **Step 4: Expand tests for every supported normalized combination**

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

Render the complete AI overlay power set: all eight combinations of host DDS on/off, GPU on/off,
and GUI on/off with `--profile ai`. Separately render core-only, core+host, core+GUI, and
core+host+GUI. For every normalized model, repeat the least-privilege checks for every present
service and verify only the selected overlay grants host network, GPU, or GUI.

Reject or inspect `privileged`, `cap_add`, `devices`, `device_cgroup_rules`, Docker socket, PID,
IPC, host network, GPU requests, and GUI mounts in base configuration. Inspect every bind in every
render for long syntax with `bind.create_host_path: false`; X11 and Xauthority must also be
read-only.

Render fixtures with IDs `1000:1000` and `12345:12345`; assert both build args are positive and
match the fixture while runtime `user` remains exactly `developer`. With all pin/ID variables unset,
render `compose.yml` directly exactly as `.devcontainer/devcontainer.json` does and assert defaults
are the two exact pins and `1000:1000`. Parse `docker/versions.env` as data and compare the rendered
ROS/uv default literals for exact equality. Assert Dev Container service `ros2_dev`,
`remoteUser=developer`, and `/opt/venv/bin/python` agree with this model.

Check the local Compose version semantically as `>=2.30.0`; do not require 2.30.3 locally. Task 8
pins CI to exact 2.30.3.

- [ ] **Step 5: Verify GREEN and commit**

Run:

```bash
bash tests/test_compose.bash
docker compose --env-file docker/versions.env --env-file .env.example config -q
git diff --check
git add compose.yml compose/host-dds.yml compose/gpu.yml compose/gui.yml \
  profiles/core.conf profiles/isaac-host.conf tests/test_compose.bash
test "$(git diff --cached --name-only | wc -l)" -eq 7
git commit -m "build: isolate core runtime privileges"
```

Expected: `compose core contract passed`; direct Dev Container startup renders without pin env
files, literals equal `versions.env`, both fixture IDs reach build args while user stays
`developer`, all twelve supported renders pass, every bind forbids host-path creation, both services
remain least-privilege by default, and exactly the seven Task 4 paths are committed.

---

### Task 5: Implement the generic profile command interface

**Files:**
- Modify: `run.sh`
- Modify mode only if needed: `scripts/check_dev_workflow.sh`
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
missing, empty, zero, or root UID/GID and invalid domain/project values fail
profile names outside [a-z0-9][a-z0-9-]* fail
unknown profile key fails
duplicate profile key fails
every required key missing in turn fails
empty SERVICE, COMPOSE_FILES, DOCTOR_COMMAND, or CHECK_COMMAND fails
an empty COMPOSE_PROFILES value is accepted, but leading/trailing/doubled commas fail
duplicate COMPOSE_FILES and COMPOSE_PROFILES items fail
absolute paths and any .. path component fail
profile, Compose, or check-command symlinks escaping the repository fail
unsafe SERVICE identifiers fail
unknown and duplicate .env keys fail
missing profile reports E_PROFILE
core-dev resolves service ros2_dev and compose.yml
isaac-host-dev resolves compose.yml plus compose/host-dds.yml
missing-dev on main fails E_PROFILE
SERVICE missing from normalized Compose output fails before lifecycle execution
profile values containing shell metacharacters are rejected
generic-check and generic-doctor execute the fixture through direct argv
real core and isaac-host dev/status/down emit exact NUL-delimited Docker argv
```

The test command is `bash tests/test_init.bash && bash tests/test_profiles.bash`.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because `scripts/lib/profile.bash` does not exist.

- [ ] **Step 3: Implement safe data parsing**

`scripts/lib/profile.bash` must read each non-comment `KEY=VALUE` line, accept only
`PROFILE_VERSION`, `SERVICE`, `COMPOSE_FILES`, `COMPOSE_PROFILES`, `DOCTOR_COMMAND`,
`CHECK_COMMAND`, reject values outside `[A-Za-z0-9_./,:-]*`, require version `1`, and populate
arrays without `eval` or `source`. Require every key exactly once; only `COMPOSE_PROFILES=` may be
an empty whole value. Reject duplicate list entries and empty items from leading, trailing, or
doubled commas.

Profile names must match `[a-z0-9][a-z0-9-]*`, and `SERVICE` must match the safe Compose identifier
form `[A-Za-z0-9][A-Za-z0-9_.-]*`. Resolve the profile file itself with `realpath -e` and reject it
unless it remains under `ROOT/profiles`. Every Compose file and the first argv item in each
doctor/check command must be a non-absolute repository-relative path with no `..` component.
Canonicalize them with `realpath -m` and require the result to remain under `ROOT`, thereby rejecting
profile, Compose, and command symlink escapes.

At profile-load time validate command-path syntax and canonical containment only. Defer the
doctor/check command file's existence, regular-file, and executable checks until that exact action
is dispatched; this is required because Task 5 precedes Task 6. Compose files must exist before a
lifecycle action normalizes them. Split doctor/check values on commas into arrays only after syntax
validation; remaining argv items are restricted scalar tokens, not paths or shell fragments.

`scripts/lib/config.bash` must parse `.env` with the same data-only rule, validate UID/GID as
positive integers, domain `0..232`, project name `[a-z0-9][a-z0-9_-]*`, copy `.env.example`
only when `.env` is absent, and never overwrite an existing file. UID and GID 0 are invalid; a
missing or empty runtime identity is invalid rather than defaulted. Reject unknown and duplicate
`.env` keys while allowing the explicitly empty `ISAAC_SIM_ROOT=` value.

- [ ] **Step 4: Replace `run.sh` with generic dispatch**

The dispatcher must support:

```text
init, doctor, build, up, shell, dev, check, status, down
<profile>-doctor, <profile>-build, <profile>-up, <profile>-shell, <profile>-dev,
<profile>-check, <profile>-status, <profile>-down
```

The suffix determines the action, the remaining prefix determines `profiles/<name>.conf`, and
unprefixed actions use `core`. Standard doctor entrypoints are exactly `./run.sh doctor` and
`./run.sh isaac-host-doctor`.

`init`, `doctor`, and `check` bypass Compose normalization and service lookup. `doctor` must be able
to diagnose a missing Docker executable/daemon, and `check` must be able to run static checks without
Docker. Only lifecycle actions `build`, `up`, `shell`, `dev`, `status`, and `down` construct Compose
argv, use both env files and every manifest Compose file, run normalized
`docker compose config --services`, and require an exact line equal to `SERVICE` before lifecycle
execution.

Build doctor/check commands as arrays and execute `"${doctor_argv[@]}"` or
`"${check_argv[@]}"`; lifecycle commands likewise use a Compose argv array. `run.sh` and both
libraries must contain no `eval`, profile `source`, or `bash -c`. No vendor name appears in
`run.sh`.

The profile manifests use direct repo-contained argv:

```text
# profiles/core.conf
DOCTOR_COMMAND=scripts/doctor.bash,base
CHECK_COMMAND=scripts/check_dev_workflow.sh

# profiles/isaac-host.conf
DOCTOR_COMMAND=scripts/doctor.bash,isaac-host
CHECK_COMMAND=scripts/check_dev_workflow.sh
```

In `tests/test_profiles.bash`, create and remove a temporary in-repository `generic.conf` plus
fixture executables. Record every argument NUL-delimited, invoke the real
`./run.sh generic-check` and `./run.sh generic-doctor`, and compare captured argv byte-for-byte.
With a fake Docker that also records NUL-delimited argv, exercise actual `./run.sh dev`,
`./run.sh status`, `./run.sh down`, `./run.sh isaac-host-dev`,
`./run.sh isaac-host-status`, and `./run.sh isaac-host-down`. Assert exact env-file, Compose-file,
service, and action argv, and assert normalized service validation occurs only for those lifecycle
actions. Parser-only tests do not satisfy this step.

- [ ] **Step 5: Verify GREEN and commit**

Run:

```bash
bash -n run.sh scripts/lib/config.bash scripts/lib/profile.bash
chmod 0755 run.sh scripts/check_dev_workflow.sh
test -x run.sh
test -x scripts/check_dev_workflow.sh
bash tests/test_init.bash
bash tests/test_profiles.bash
! grep -Eqi 'doosan|openarm|isaac_ros' run.sh
! rg -n '\beval\b|\bsource[[:space:]]+profiles/|bash[[:space:]]+-c' \
  run.sh scripts/lib/config.bash scripts/lib/profile.bash
git diff --check
git add run.sh scripts/check_dev_workflow.sh scripts/lib/config.bash scripts/lib/profile.bash \
  tests/test_init.bash tests/test_profiles.bash
git commit -m "feat: add generic environment profiles"
```

Expected: every negative fixture fails with `E_PROFILE`; generic doctor/check and core/Isaac
lifecycle actions match NUL-delimited argv exactly; init/doctor/check never require Compose; service
validation precedes lifecycle actions only; run/wrapper modes are 0755; and forbidden-shell/vendor
scans return no match.

---

### Task 6: Add compact diagnostics and host Isaac launcher validation

**Files:**
- Create: `scripts/doctor.bash`
- Modify: `scripts/launch_isaac_sim.sh`
- Create: `scripts/check_isaac_host.bash`
- Create: `tests/test_doctor.bash`
- Create: `tests/test_isaac_host.bash`

**Interfaces:**
- Produces: `./run.sh doctor`, `./run.sh isaac-host-doctor`, error codes `E_PREREQUISITE`,
  and compact PASS/FAIL output.
- Consumes: `.env`, `ISAAC_SIM_ROOT`, Docker/Compose commands, FastDDS config.

- [ ] **Step 1: Write failing doctor scenarios**

Cover missing Docker, Compose below 2.30, invalid env, non-x86_64, missing NVIDIA prerequisite,
missing Isaac root, non-executable launcher, incompatible `VERSION`, FastDDS/domain mismatch, and
success. Stub `uname`, `nvidia-smi`, Docker, the launcher, `${ISAAC_SIM_ROOT}/VERSION`, and ROS CLI
through temporary fixtures; assert default output is at most six lines and `--verbose` includes
individual checks.

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
files. Resolve the Isaac root exactly as:

```bash
ISAAC_SIM_ROOT="${ISAAC_SIM_ROOT:-$HOME/isaacsim}"
```

Isaac-host additionally requires host `uname -m` to be `x86_64`, a successful read-only NVIDIA
prerequisite probe, executable `$ISAAC_SIM_ROOT/isaac-sim.sh`, readable
`$ISAAC_SIM_ROOT/VERSION` beginning with the configured `6.0.1`, host network support, both FastDDS
variables resolving to the repository `config/fastdds.xml`, `rmw_fastrtps_cpp`, and the same
`ROS_DOMAIN_ID` as normalized Compose output. It must not install drivers/packages, download Isaac,
change GPU settings, or issue simulator/robot motion commands.

`scripts/launch_isaac_sim.sh` must use the same safe default, export `ROS_DOMAIN_ID`,
`RMW_IMPLEMENTATION`, and both FastDDS profile variables, then
`exec "$ISAAC_SIM_ROOT/isaac-sim.sh" "$@"`. It must not install or download Isaac Sim.

`scripts/check_isaac_host.bash` is a non-destructive bridge acceptance. It never starts Isaac and
never publishes or invokes a service. Exit 77 with `SKIP E_PREREQUISITE` only when installation or
host prerequisites are absent, such as no Isaac root/launcher, non-x86_64 host, or unavailable
NVIDIA prerequisite. An installed but unreadable/incompatible version is FAIL. Once a compatible
installation, NVIDIA, launcher, and version prerequisites exist, an absent ROS graph/topic or a
timed-out `/clock` observation is also blocking non-77 FAIL. Success exits 0.
`tests/test_isaac_host.bash` covers these PASS, allowed-SKIP, incompatible-version FAIL, missing-graph
FAIL, and missing-topic FAIL cases distinctly.

- [ ] **Step 4: Verify GREEN and commit**

Run:

```bash
bash -n scripts/doctor.bash scripts/launch_isaac_sim.sh scripts/check_isaac_host.bash
chmod 0755 scripts/doctor.bash scripts/launch_isaac_sim.sh scripts/check_isaac_host.bash
test -x scripts/doctor.bash
test -x scripts/launch_isaac_sim.sh
test -x scripts/check_isaac_host.bash
bash tests/test_doctor.bash
bash tests/test_isaac_host.bash
git diff --check
git add scripts/doctor.bash scripts/launch_isaac_sim.sh scripts/check_isaac_host.bash \
  tests/test_doctor.bash tests/test_isaac_host.bash
git commit -m "feat: add core and host Isaac diagnostics"
```

Expected: doctor tests pass with compact output; all three scripts are 0755; Isaac acceptance uses
SKIP 77 only for absent installation/host prerequisites and blocking FAIL for incompatible installed
state or absent graph/topic; no install/download/simulator-control/hardware-control command exists.

---

### Task 7: Remove vendor runtime and split the tutorial curriculum from `main`

**Files:**
- Delete: `Dockerfile.doosan`
- Delete: `Dockerfile.isaac-moveit`
- Delete: `docker/bootstrap_doosan_emulator.bash`
- Delete: `.devcontainer/doosan/compose.yml`
- Delete: `.devcontainer/doosan/devcontainer.json`
- Delete: `docs/tutorials/2-week-isaac-ros2-a0912-onboarding.md`
- Delete: `docs/tutorials/cube-pick-dataset-interface.md`
- Delete: `docs/tutorials/day-05-*` through `docs/tutorials/day-10-*`
- Modify: `README.md`
- Modify: `docs/tutorials/README.md`
- Modify: `docs/tutorials/day-01-isaac-sim-basics/hands-on.md`
- Modify: `docs/tutorials/day-02-jetbot-turtlebot-ros2-driving/hands-on.md`
- Modify: `docs/tutorials/day-03-python-scripting-minimum-loop/hands-on.md`
- Modify: `docs/tutorials/day-04-ros2-bridge-observation-pipeline/README.md`
- Modify: `docs/tutorials/day-04-ros2-bridge-observation-pipeline/hands-on.md`
- Modify: `docs/tutorials/shared/environment-setup.md`
- Modify: `docs/tutorials/shared/README.md`
- Modify: `docs/tutorials/shared/official-tutorial-map.md`
- Modify: `docs/tutorials/shared/cube-pick-v1-dataset-policy-interface.md`
- Modify: `docs/tutorials/shared/later-milestones.md`
- Modify: `docs/tutorials/shared/glossary.md`
- Modify: `docs/tutorials/shared/troubleshooting.md`
- Modify: `docs/troubleshooting/2026-07-07-isaacsim-ros2-bridge-fastdds.md`
- Create: `tests/fixtures/core-deleted-paths.txt`
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
`full-dev`, `A0912`, or `Dockerfile.doosan`. Scan active README/docs while explicitly excluding
historical governance material under `docs/superpowers/**`; permit branch-governance names such as
`doosan-tutorial`, but reject live vendor runtime paths/services/targets.

Make the 31-path fixture a permanent part of `tests/test_static_contract.bash`:

```bash
while IFS= read -r path; do
  test ! -e "$path" || fail "deleted core path still exists: $path"
  if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    fail "deleted core path remains in index: $path"
  fi
done < tests/fixtures/core-deleted-paths.txt
```

This permanently covers both top-level tutorial documents as well as all other 29 entries. Test
files are invoked with `bash`; they do not need executable mode.

- [ ] **Step 2: Run and verify RED**

Run: `bash tests/test_static_contract.bash`

Expected: FAIL on the first tracked vendor path.

- [ ] **Step 3: Record and delete the complete preservation inventory with `apply_patch`**

Create `tests/fixtures/core-deleted-paths.txt` with exactly these 31 tracked paths:

```text
.devcontainer/doosan/compose.yml
.devcontainer/doosan/devcontainer.json
Dockerfile.doosan
Dockerfile.isaac-moveit
docker/bootstrap_doosan_emulator.bash
docs/tutorials/2-week-isaac-ros2-a0912-onboarding.md
docs/tutorials/cube-pick-dataset-interface.md
docs/tutorials/day-05-manipulator-concepts-before-a0912/README.md
docs/tutorials/day-05-manipulator-concepts-before-a0912/checkpoint.md
docs/tutorials/day-05-manipulator-concepts-before-a0912/concepts.md
docs/tutorials/day-05-manipulator-concepts-before-a0912/hands-on.md
docs/tutorials/day-06-doosan-a0912-bringup/README.md
docs/tutorials/day-06-doosan-a0912-bringup/checkpoint.md
docs/tutorials/day-06-doosan-a0912-bringup/concepts.md
docs/tutorials/day-06-doosan-a0912-bringup/hands-on.md
docs/tutorials/day-07-a0912-scripted-motion/README.md
docs/tutorials/day-07-a0912-scripted-motion/checkpoint.md
docs/tutorials/day-07-a0912-scripted-motion/concepts.md
docs/tutorials/day-07-a0912-scripted-motion/hands-on.md
docs/tutorials/day-08-cube-pick-scene-v0/README.md
docs/tutorials/day-08-cube-pick-scene-v0/checkpoint.md
docs/tutorials/day-08-cube-pick-scene-v0/concepts.md
docs/tutorials/day-08-cube-pick-scene-v0/hands-on.md
docs/tutorials/day-09-dataset-collection/README.md
docs/tutorials/day-09-dataset-collection/checkpoint.md
docs/tutorials/day-09-dataset-collection/concepts.md
docs/tutorials/day-09-dataset-collection/hands-on.md
docs/tutorials/day-10-policy-connection-preparation/README.md
docs/tutorials/day-10-policy-connection-preparation/checkpoint.md
docs/tutorials/day-10-policy-connection-preparation/concepts.md
docs/tutorials/day-10-policy-connection-preparation/hands-on.md
```

Before deletion, loop over every line and run
`git cat-file -e "migration/pre-split-2026-07-14:$path"`. Delete every listed path with
`apply_patch`; then assert `test ! -e "$path"` for every line. Do not touch the root dirty worktree.

- [ ] **Step 4: Rewrite core documentation**

`README.md` must document clone → init → doctor → build/dev → host Isaac launch, describe only
core/isaac-host profiles, and link Days 1-4. `docs/tutorials/README.md` must list Days 1-4 and state
that Days 5-10 live on the two tutorial branches. Replace absolute repository paths with
`$REPO_ROOT` and Isaac paths with `$ISAAC_SIM_ROOT`. Rewrite `shared/README.md`,
`official-tutorial-map.md`, `environment-setup.md`, and `glossary.md` around Days 1-4 only.
Remove A0912-specific dataset and later-milestone content from the two shared files while retaining
their exact originals in the preservation tag for `doosan-tutorial` restoration.
Audit and rewrite `docs/tutorials/shared/troubleshooting.md` explicitly if it retains removed
runtime paths or Days 5-10-only guidance.

Explicitly remove Day 4 README's next-link to the deleted Day 5/two-week index. Replace every
`/home/ahrism` occurrence in retained Days 1-4 and shared docs. Rewrite the FastDDS troubleshooting
host value to `$REPO_ROOT/config/fastdds.xml`. Document the non-destructive Isaac acceptance command,
including PASS, exit-77 SKIP when Isaac is absent, and blocking FAIL when prerequisites exist.

Replace `scripts/check_dev_workflow.sh` with a wrapper:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
exec bash tests/test_static_contract.bash
```

This ordering is mandatory: `tests/run_all.bash` does not exist until Task 8.

- [ ] **Step 5: Verify GREEN and commit**

First verify filesystem deletion and preservation before staging; do not run the permanent static
test yet because deleted paths remain in the Git index until exact staging:

```bash
while IFS= read -r path; do
  test ! -e "$path"
  git cat-file -e "migration/pre-split-2026-07-14:$path"
done < tests/fixtures/core-deleted-paths.txt
! rg -n '/home/ahrism|doosan-dev|full-dev|A0912|Dockerfile\.doosan|IsaacSim-ros_workspaces' \
  README.md docs --glob '*.md' --glob '!docs/superpowers/**'
! rg -n 'day-05|2-week-isaac-ros2-a0912' \
  docs/tutorials/day-04-ros2-bridge-observation-pipeline/README.md
git diff --check
mapfile -t deleted_paths < tests/fixtures/core-deleted-paths.txt
git add -A -- "${deleted_paths[@]}"
git add README.md docs/tutorials/README.md \
  docs/tutorials/day-01-isaac-sim-basics/hands-on.md \
  docs/tutorials/day-02-jetbot-turtlebot-ros2-driving/hands-on.md \
  docs/tutorials/day-03-python-scripting-minimum-loop/hands-on.md \
  docs/tutorials/day-04-ros2-bridge-observation-pipeline/README.md \
  docs/tutorials/day-04-ros2-bridge-observation-pipeline/hands-on.md \
  docs/tutorials/shared/README.md docs/tutorials/shared/environment-setup.md \
  docs/tutorials/shared/official-tutorial-map.md \
  docs/tutorials/shared/cube-pick-v1-dataset-policy-interface.md \
  docs/tutorials/shared/later-milestones.md docs/tutorials/shared/glossary.md \
  docs/tutorials/shared/troubleshooting.md \
  docs/troubleshooting/2026-07-07-isaacsim-ros2-bridge-fastdds.md \
  scripts/check_dev_workflow.sh tests/test_static_contract.bash \
  tests/fixtures/core-deleted-paths.txt
bash tests/test_static_contract.bash
while IFS= read -r path; do
  ! git ls-files --error-unmatch -- "$path" >/dev/null 2>&1
done < tests/fixtures/core-deleted-paths.txt
test -x scripts/check_dev_workflow.sh
git commit -m "refactor: keep main vendor neutral"
```

Expected: the ownership/portability test passes, all 31 paths are absent from the committed core
tree, and the preservation tag contains every one of their blobs.

---

### Task 8: Add the unified test entrypoint and core CI

**Files:**
- Create: `tests/run_all.bash`
- Create: `.github/workflows/core-environment.yml`
- Modify: `tests/test_static_contract.bash`
- Modify: `scripts/check_dev_workflow.sh`

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
  tests/test_ai_lock.bash \
  tests/test_docker_runtime.bash \
  tests/test_init.bash \
  tests/test_profiles.bash \
  tests/test_compose.bash \
  tests/test_doctor.bash \
  tests/test_isaac_host.bash; do
  bash "$test_file"
done
printf 'all core tests passed\n'
```

Add a static assertion that the workflow contains `linux/amd64`, `linux/arm64`, and
`tests/run_all.bash`.

Now, and only now, change `scripts/check_dev_workflow.sh` from the Task 7 static-test wrapper to
`exec bash tests/run_all.bash`. Keep the wrapper executable; `tests/run_all.bash` and the individual
test files are invoked with Bash and do not need executable mode.

- [ ] **Step 2: Verify RED**

Run: `bash tests/test_static_contract.bash`

Expected: FAIL because `.github/workflows/core-environment.yml` is missing.

- [ ] **Step 3: Add CI jobs**

The workflow must run on pull requests and pushes to `main` with `runs-on: ubuntu-24.04`. Pin every
setup action and its execution substrate to these exact observed values:

```yaml
- uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
- uses: docker/setup-qemu-action@c7c53464625b32c7a7e944ae62b3e17d2b600130
  with:
    image: tonistiigi/binfmt@sha256:400a4873b838d1b89194d982c45e5fb3cda4593fbfd7e08a02e76b03b21166f0
    platforms: arm64
- uses: docker/setup-buildx-action@8d2750c68a42422c14e847fe6c8ac0403b4cbd6f
  with:
    version: v0.35.0
    driver-opts: image=moby/buildkit@sha256:0168606be2315b7c807a03b3d8aa79beefdb31c98740cebdffdfeebf31190c9f
- uses: docker/setup-compose-action@2fe291b7677a45ee1269ec56a42604c143505e7e
  with:
    version: v2.30.3
```

These are the controller-observed CI substrate values, not floating examples. After setup, assert
`docker compose version --short` is exactly `2.30.3`, run
`tests/test_image_indexes.bash`, and run the unified tests. Set up QEMU for arm64 and Buildx
explicitly. Build `ros-python-dev` separately for `linux/amd64` and `linux/arm64`, load each local
single-platform image without publishing, then run each image with its matching `--platform`.
Arm64 runtime must execute through QEMU or a native runner; build-only coverage is insufficient.

For both platforms verify:

```bash
test "$(id -un)" = developer
test "$(id -u)" != 0
python -c 'import sys; assert sys.version_info[:2] == (3, 12)'
test "$(uv --version)" = 'uv 0.8.3'
ros2 pkg prefix demo_nodes_cpp
test "$ROS_DISTRO" = jazzy
```

Also start `demo_nodes_cpp` listener and talker within a bounded-time container smoke and require
at least one `I heard:` line on each platform. Stop the processes afterward; no runtime Docker
socket is mounted.

No job may build vendor targets, push images, mount Docker socket into a runtime service, or run
hardware commands.

- [ ] **Step 4: Verify GREEN and commit**

Run:

```bash
bash tests/run_all.bash
test -x scripts/check_dev_workflow.sh
git diff --check
git add tests/run_all.bash tests/test_static_contract.bash \
  scripts/check_dev_workflow.sh .github/workflows/core-environment.yml
git commit -m "ci: verify portable core environment"
```

Expected: `all core tests passed`; both exact OCI indexes expose amd64+arm64, QEMU/native arm64 and
amd64 runtime smokes pass with exact Python/uv/Jazzy/non-root checks and talker/listener exchange,
and Compose is exactly 2.30.3. The workflow contains no push, vendor target, simulator install,
runtime Docker-socket mount, or hardware-control command.

---

### Task 9: Full core acceptance and local `main` integration

**Files:**
- No new files.
- Update local branch ref through a reviewed merge only after acceptance.

**Interfaces:**
- Consumes: completed `refactor/core-branch-layout`.
- Produces: verified local `main` containing the approved design and core implementation.

- [ ] **Step 1: Repeat every preservation and forward-history gate**

Run:

```bash
BACKUP=/home/ahrism/workspace/ros2-dev-migration-backup-2026-07-14
ROOT=/home/ahrism/workspace/ros2-dev
FEATURE="$ROOT/.worktrees/team-shared-dev-env"
test "$(git rev-parse migration/pre-split-2026-07-14^{})" = \
  6bb7f14f748416f64712ce63103bea1b02997fea
git merge-base --is-ancestor e6da3b444d501e2175517efb4c5b983b5fa5701b HEAD
test "$(sha256sum "$BACKUP/manifest.txt" | awk '{print $1}')" = \
  39478896d14aefd7c1f40b46a3117974d45917811d90c108818ccc5cb2df92da
test "$(sha256sum "$BACKUP/user-damin.patch" | awk '{print $1}')" = \
  a44a513e33fe4a31f3eab5b1c878d4dee0169afadc52b2e77bc8306a67bb95f4

manifest_value() { sed -n "s/^$2=//p" "$1"; }
verify_worktree_manifest() {
  local manifest="$1" manifest_sha="$2" wt expected actual line record path file_sha
  test "$(sha256sum "$manifest" | awk '{print $1}')" = "$manifest_sha"
  wt="$(manifest_value "$manifest" worktree)"
  expected="$(manifest_value "$manifest" head)"
  test "$(git -C "$wt" rev-parse HEAD)" = "$expected"
  expected="$(manifest_value "$manifest" status_porcelain_v1_z_sha256)"
  actual="$(git -C "$wt" status --porcelain=v1 -z | sha256sum | awk '{print $1}')"
  test "$actual" = "$expected"
  expected="$(manifest_value "$manifest" tracked_binary_diff_sha256)"
  actual="$(git -C "$wt" diff --binary | sha256sum | awk '{print $1}')"
  test "$actual" = "$expected"
  expected="$(manifest_value "$manifest" untracked_paths_z_sha256)"
  actual="$(git -C "$wt" ls-files --others --exclude-standard -z | sha256sum | awk '{print $1}')"
  test "$actual" = "$expected"
  while IFS= read -r line; do
    case "$line" in
      tracked_sha256=*|untracked_sha256=*)
        record="${line%%  *}"
        path="${line#*  }"
        file_sha="${record#*=}"
        test -f "$wt/$path"
        test "$(sha256sum "$wt/$path" | awk '{print $1}')" = "$file_sha"
        ;;
    esac
  done < "$manifest"
}

test "$(manifest_value "$BACKUP/root-worktree.manifest" head)" = \
  744a8a9bda98dd6b7fd50a0703bf6fefab981bc5
test "$(manifest_value "$BACKUP/feature-worktree.manifest" head)" = \
  bbce9bdb91a76ed57755542586bfcd6e0af61ba9
verify_worktree_manifest "$BACKUP/root-worktree.manifest" \
  ebd801615fe1d523757048ba1f6f884f57956af7181a74f99cc3e7fc3a0e3780
verify_worktree_manifest "$BACKUP/feature-worktree.manifest" \
  09a318b77f6447e78ca9801db3f4ba7583f54c5dd0edaeaa5ea07fd3190eeb5e
test -f "$ROOT/user-ws/damin/tutorial-7.py"
git -C "$ROOT" status --short --branch
git -C "$FEATURE" status --short --branch
while IFS= read -r path; do
  test ! -e "$path"
  git cat-file -e "migration/pre-split-2026-07-14:$path"
done < tests/fixtures/core-deleted-paths.txt
```

Expected: both external-manifest hashes, root HEAD `744a8a9b...`, feature HEAD `bbce9bdb...`, both
NUL-delimited status/untracked-list hashes, both binary-diff hashes, every per-file hash (including
the PDF and `user-ws/damin/tutorial-7.py`), and all 31 tag blobs match. Any mismatch stops
integration without cleanup/reset/stash.

- [ ] **Step 2: Repeat complete core and both-platform acceptance**

Run:

```bash
bash tests/run_all.bash
bash tests/test_image_indexes.bash
compose_version="$(docker compose version --short)"
compose_version="${compose_version#v}"
test "$(printf '%s\n' 2.30.0 "$compose_version" | sort -V | head -n1)" = 2.30.0
docker compose --env-file docker/versions.env --env-file .env.example \
  --profile ai config -q

ROS_PIN='ros:jazzy-ros-base-noble@sha256:31daab66eef9139933379fb67159449944f4e2dcf2e22c2d12cc715f29873e0f'
if test "$(uname -m)" = aarch64; then
  printf 'arm64 runtime preflight: native\n'
elif docker run --rm --platform linux/arm64 "$ROS_PIN" bash -lc true; then
  printf 'arm64 runtime preflight: existing QEMU/binfmt\n'
else
  printf '%s\n' \
    'HOLD E_PREREQUISITE: no native/QEMU arm64 execution; request explicit authority before privileged binfmt registration' >&2
  exit 1
fi

docker buildx build --platform linux/amd64 --target ros-python-dev \
  --load -t nexus-ros-core:amd64 .
docker buildx build --platform linux/arm64 --target ros-python-dev \
  --load -t nexus-ros-core:arm64 .
for arch in amd64 arm64; do
  docker run --rm --platform "linux/$arch" "nexus-ros-core:$arch" bash -lc '
    source /etc/profile.d/nexus_env.bash
    test "$(id -un)" = developer && test "$(id -u)" != 0
    python -c "import sys; assert sys.version_info[:2] == (3, 12)"
    test "$(uv --version)" = "uv 0.8.3"
    test "$ROS_DISTRO" = jazzy
    ros2 pkg prefix demo_nodes_cpp
    timeout 20s ros2 run demo_nodes_cpp listener > /tmp/listener.log 2>&1 & listener=$!
    timeout 10s ros2 run demo_nodes_cpp talker >/tmp/talker.log 2>&1 || true
    wait "$listener" || true
    grep -q "I heard:" /tmp/listener.log
  '
done
git diff --check main...HEAD
test -z "$(git status --short)"
```

Expected: both exact OCI indexes and both runtime architectures pass exact Python 3.12, uv 0.8.3,
non-root developer, Jazzy, demo package, and talker/listener checks. Local Compose is semantically
at least 2.30.0; exact 2.30.3 is a CI-only assertion. If native/QEMU arm64 execution is absent—as
on the current host—HOLD before any build/merge and request explicit authority for privileged
binfmt setup. Never auto-register binfmt; Task 8 CI remains the authoritative arm64 runtime smoke.

- [ ] **Step 3: Record host Isaac acceptance or an explicit deferred acceptance**

Run:

```bash
set +e
scripts/check_isaac_host.bash
isaac_status=$?
set -e
case "$isaac_status" in
  0) printf 'host Isaac bridge acceptance PASS\n' ;;
  77) printf '%s\n' \
    'SKIP E_PREREQUISITE: rerun scripts/check_isaac_host.bash on the x86_64 NVIDIA Isaac 6.0.1 host' ;;
  *) exit "$isaac_status" ;;
esac
```

Expected: actual topic discovery or one `/clock` observation passes when the host is available.
Absent installation/host prerequisites are recorded as SKIP with the exact rerun command and are
not reported as passed. Once compatible installation/NVIDIA/version prerequisites exist, absent
graph/topic or discovery timeout is blocking non-77 FAIL. No simulator install/start or
hardware/motion command is run.

- [ ] **Step 4: Create the exact clean `main` worktree and merge locally without push**

Run exactly from the core worktree:

```bash
CORE_WT=/home/ahrism/workspace/ros2-dev/.worktrees/core-branch-migration
MAIN_WT=/home/ahrism/workspace/ros2-dev/.worktrees/main-integration
MAIN_BASE=6bb7f14f748416f64712ce63103bea1b02997fea

test ! -e "$MAIN_WT"
! git -C "$CORE_WT" worktree list --porcelain | grep -Fx "worktree $MAIN_WT"
test "$(git -C "$CORE_WT" rev-parse main)" = "$MAIN_BASE"
test -z "$(git -C "$CORE_WT" status --porcelain)"
core_head="$(git -C "$CORE_WT" rev-parse HEAD)"

git -C "$CORE_WT" worktree add "$MAIN_WT" main
test "$(git -C "$MAIN_WT" branch --show-current)" = main
test "$(git -C "$MAIN_WT" rev-parse HEAD)" = "$MAIN_BASE"
test -z "$(git -C "$MAIN_WT" status --porcelain)"

git -C "$MAIN_WT" merge --no-ff "$core_head" \
  -m "merge: establish vendor-neutral ROS2 core"
bash "$MAIN_WT/tests/run_all.bash"
test "$(git -C "$MAIN_WT" rev-parse HEAD^1)" = "$MAIN_BASE"
test "$(git -C "$MAIN_WT" rev-parse HEAD^2)" = "$core_head"
test -z "$(git -C "$MAIN_WT" status --porcelain)"
```

Expected: local `main` contains the reviewed merge and remains clean. If the path already exists,
`main` moved, or either worktree is dirty, stop without removing/reusing/resetting anything. Repeat
Step 1's protected hashes/status checks after the merge. Do not push, delete a branch, or remove a
worktree.

---

## Self-Review Coverage

- Preservation and dirty worktree safety: Task 1.
- Immutable inputs and Python/uv: Tasks 2-3.
- Least-privilege, host Isaac-only Compose: Tasks 4 and 6.
- Extensible profile interface without vendor hardcoding: Task 5.
- Vendor/tutorial removal with recoverable history: Task 7.
- amd64/arm64 and core runtime verification: Tasks 8-9.
- AI Agent governance, Doosan, OpenArm, and tutorial implementations remain intentionally in their separate plans defined by the approved umbrella spec.
