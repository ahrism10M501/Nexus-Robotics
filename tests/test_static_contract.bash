#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source tests/helpers/assert.bash

assert_file tests/fixtures/core-deleted-paths.txt
test "$(wc -l < tests/fixtures/core-deleted-paths.txt)" -eq 31 || \
  fail 'core deletion fixture must contain exactly 31 paths'
fixture_hash="$(sha256sum tests/fixtures/core-deleted-paths.txt | awk '{print $1}')"
test "$fixture_hash" = '59d358312370c1ec4c2ad1a5270a4e03f5a09dd2c016febd8f26bcabc1a3e73d' || \
  fail 'core deletion fixture content changed'
test "$(sort -u tests/fixtures/core-deleted-paths.txt | wc -l)" -eq 31 || \
  fail 'core deletion fixture paths must be unique'
while IFS= read -r path; do
  test ! -e "$path" || fail "deleted core path still exists: $path"
  if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    fail "deleted core path remains in index: $path"
  fi
done < tests/fixtures/core-deleted-paths.txt

day2_hands_on=docs/tutorials/day-02-jetbot-turtlebot-ros2-driving/hands-on.md
day4_hands_on=docs/tutorials/day-04-ros2-bridge-observation-pipeline/hands-on.md
fastdds_guide=docs/troubleshooting/2026-07-07-isaacsim-ros2-bridge-fastdds.md
assert_contains README.md \
  'Host bridge 실습에서는 `./run.sh dev`가 아니라 `./run.sh isaac-host-dev`를 사용합니다.'
for guide in "$day2_hands_on" "$day4_hands_on"; do
  assert_contains "$guide" './run.sh isaac-host-dev'
  assert_not_contains "$guide" './run.sh dev'
done
assert_contains "$fastdds_guide" './run.sh isaac-host-down'
assert_contains "$fastdds_guide" './run.sh isaac-host-up'
assert_not_contains "$fastdds_guide" './run.sh down'
assert_not_contains "$fastdds_guide" './run.sh up'

while IFS= read -r tracked_path; do
  case "$tracked_path" in
    Dockerfile.doosan|Dockerfile.isaac-moveit|docker/*doosan*|.devcontainer/doosan/*|\
      docs/tutorials/day-0[5-9]-*/*|docs/tutorials/day-10-*/*)
      fail "vendor-owned path remains in core: $tracked_path"
      ;;
  esac
done < <(git ls-files)

mapfile -t active_docs < <(
  git ls-files -- README.md docs |
    while IFS= read -r path; do
      case "$path" in
        README.md|docs/*.md)
          case "$path" in
            docs/superpowers/*) ;;
            *) printf '%s\n' "$path" ;;
          esac
          ;;
      esac
    done
)
live_vendor_pattern='/home/ahrism|a0912|doosan[-_](dev|build|up|shell|check)|full[-_](dev|build|up|shell|check)|bootstrap_doosan|doosanrobot|DSR_ROBOT2|isaac_moveit|IsaacSim-ros_workspaces|Dockerfile\.(doosan|isaac-moveit)|\.devcontainer/doosan'
if vendor_hits="$(grep -EinH -- "$live_vendor_pattern" "${active_docs[@]}" || true)" && \
  test -n "$vendor_hits"; then
  printf '%s\n' "$vendor_hits" >&2
  fail 'active core documentation contains vendor/runtime-specific content'
fi

mapfile -d '' -t retained_tutorial_docs < <(
  find docs/tutorials/day-0{1,2,3,4}-* docs/tutorials/shared \
    -type f -name '*.md' -print0
)
follow_on_pattern='Days? ([5-9]|10)([^0-9]|$)|day-(0[5-9]|10)([^0-9]|$)'
if follow_on_hits="$(grep -EinH -- "$follow_on_pattern" "${retained_tutorial_docs[@]}" || true)" && \
  test -n "$follow_on_hits"; then
  printf '%s\n' "$follow_on_hits" >&2
  fail 'retained core tutorial documentation references a removed follow-on lesson'
fi

for path in .dockerignore .env.example docker/versions.env \
  docker/requirements/ai.in docker/requirements/ai.lock; do
  assert_file "$path"
done
assert_file scripts/generate_ai_lock.bash
assert_file tests/test_ai_lock.bash
test -x scripts/generate_ai_lock.bash || fail 'lock generator is not executable'
assert_contains docker/versions.env \
  'ROS_BASE_IMAGE=ros:jazzy-ros-base-noble@sha256:31daab66eef9139933379fb67159449944f4e2dcf2e22c2d12cc715f29873e0f'
assert_contains docker/versions.env \
  'UV_IMAGE=ghcr.io/astral-sh/uv:0.8.3@sha256:ef11ed817e6a5385c02cd49fdcc99c23d02426088252a8eace6b6e6a2a511f36'
assert_not_contains docker/versions.env 'DOOSAN'
assert_not_contains docker/versions.env 'OPENARM'
assert_not_contains docker/versions.env 'ISAAC_ROS'
assert_contains .env.example 'ISAAC_SIM_ROOT='
assert_contains .env.example 'ISAAC_SIM_COMPAT_VERSION=6.0.1'
assert_not_contains .env.example 'ISAAC_SIM_ROOT=/home/'
assert_contains .dockerignore '.env'
assert_contains .dockerignore '.worktrees'
assert_contains .dockerignore 'data'
assert_contains .dockerignore 'checkpoints'
assert_contains .gitignore '.env'
assert_contains .gitignore '.xauth-*'
assert_contains .devcontainer/devcontainer.json '"remoteUser": "developer"'
assert_not_contains .devcontainer/devcontainer.json '"remoteUser": "root"'
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

workflow=.github/workflows/core-environment.yml
runner=tests/run_all.bash
smoke=tests/smoke_core_image.bash
ai_runtime=tests/test_ai_runtime.bash

assert_file "$workflow"
assert_file "$runner"
assert_file "$ai_runtime"
contract_tmp="$(mktemp -d)"
trap 'rm -rf "$contract_tmp"' EXIT

# The tiered entrypoint is explicit, ordered, and keeps the AI image local-only.
assert_contains "$runner" '--checks'
assert_contains "$runner" '--core'
assert_contains "$runner" '--full'
assert_contains "$runner" 'tests/test_static_contract.bash'
assert_contains "$runner" 'tests/test_init.bash'
assert_contains "$runner" 'tests/test_profiles.bash'
assert_contains "$runner" 'tests/test_doctor.bash'
assert_contains "$runner" 'tests/test_isaac_host.bash'
assert_contains "$runner" 'tests/test_compose.bash'
assert_contains "$runner" 'tests/test_image_indexes.bash'
assert_contains "$runner" 'tests/test_ai_lock.bash'
assert_contains "$runner" 'tests/test_docker_runtime.bash'
assert_contains "$runner" 'tests/test_ai_runtime.bash'
assert_contains "$runner" 'core checks passed'
assert_contains "$runner" 'all core tests passed'
assert_contains "$runner" 'full core and AI tests passed'
assert_not_contains tests/test_docker_runtime.bash 'ros-ai-dev'
assert_not_contains tests/test_docker_runtime.bash 'import diffusers'
assert_contains "$ai_runtime" 'ros-ai-dev'
assert_contains "$ai_runtime" 'uv pip check --python /opt/venv/bin/python'
assert_contains "$ai_runtime" \
  'import diffusers, einops, huggingface_hub, timm, torch, torchvision'
assert_contains scripts/check_dev_workflow.sh 'exec bash tests/run_all.bash'
assert_not_contains scripts/check_dev_workflow.sh 'test_static_contract.bash'
assert_contains README.md '`scripts/check_dev_workflow.sh`'
assert_contains README.md '`--core`'
assert_contains README.md '`bash tests/run_all.bash --full`'
assert_contains README.md '14.4 GB'
assert_contains README.md 'amd64'
assert_contains README.md 'arm64'

for check_path in \
  tests/test_static_contract.bash tests/test_init.bash tests/test_profiles.bash \
  tests/test_doctor.bash tests/test_isaac_host.bash tests/test_compose.bash \
  tests/test_image_indexes.bash tests/test_ai_lock.bash; do
  test "$(grep -Fxc "  bash $check_path" "$runner")" -eq 1 || \
    fail "checks tier must invoke $check_path exactly once"
done
test "$(grep -Fxc '    bash tests/test_docker_runtime.bash' "$runner")" -eq 2 || \
  fail 'core runtime must occur only in the core and full branches'
test "$(grep -Fxc '    bash tests/test_ai_runtime.bash' "$runner")" -eq 1 || \
  fail 'AI runtime must occur only in the full branch'

previous_line=0
for check_path in \
  tests/test_static_contract.bash tests/test_init.bash tests/test_profiles.bash \
  tests/test_doctor.bash tests/test_isaac_host.bash tests/test_compose.bash \
  tests/test_image_indexes.bash tests/test_ai_lock.bash; do
  current_line="$(grep -nFx "  bash $check_path" "$runner" | cut -d: -f1)"
  test "$current_line" -gt "$previous_line" || fail "checks tier order broke at $check_path"
  previous_line="$current_line"
done

runner_bin="$contract_tmp/runner-bin"
mkdir -p "$runner_bin"
runner_log="$contract_tmp/runner.log"
runner_output="$contract_tmp/runner.output"
cat > "$runner_bin/bash" <<'FAKE_BASH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "${FAKE_RUNNER_LOG:?}"
FAKE_BASH
chmod +x "$runner_bin/bash"

runner_status=0
invoke_runner() {
  : > "$runner_log"
  : > "$runner_output"
  set +e
  env PATH="$runner_bin:$PATH" FAKE_RUNNER_LOG="$runner_log" \
    /bin/bash "$runner" "$@" > "$runner_output" 2>&1
  runner_status=$?
  set -e
}

assert_runner_log() {
  diff -u <(printf '%s\n' "$@") "$runner_log" || fail 'runner invoked the wrong tier/order'
}

checks=(
  tests/test_static_contract.bash
  tests/test_init.bash
  tests/test_profiles.bash
  tests/test_doctor.bash
  tests/test_isaac_host.bash
  tests/test_compose.bash
  tests/test_image_indexes.bash
  tests/test_ai_lock.bash
)
invoke_runner --checks
test "$runner_status" -eq 0 || fail '--checks runner failed against successful test boundary'
assert_runner_log "${checks[@]}"
test "$(cat "$runner_output")" = 'core checks passed' || fail '--checks overreported its tier'

for core_mode in __default__ --core; do
  if [[ "$core_mode" == __default__ ]]; then
    invoke_runner
  else
    invoke_runner "$core_mode"
  fi
  test "$runner_status" -eq 0 || fail "$core_mode runner failed against successful test boundary"
  assert_runner_log "${checks[@]}" tests/test_docker_runtime.bash
  test "$(cat "$runner_output")" = 'all core tests passed' || fail "$core_mode overreported its tier"
done

invoke_runner --full
test "$runner_status" -eq 0 || fail '--full runner failed against successful test boundary'
assert_runner_log "${checks[@]}" tests/test_docker_runtime.bash tests/test_ai_runtime.bash
test "$(cat "$runner_output")" = 'full core and AI tests passed' || fail '--full misreported its tier'

for invalid_args in 'invalid' '--core extra'; do
  read -r -a invalid_argv <<< "$invalid_args"
  invoke_runner "${invalid_argv[@]}"
  test "$runner_status" -eq 2 || fail "runner invalid mode/arity must exit 2: $invalid_args"
  [[ ! -s "$runner_log" ]] || fail "invalid runner input executed a test: $invalid_args"
  test "$(wc -l < "$runner_output")" -eq 1 || fail 'runner usage must be one line'
done

# The workflow has exactly the approved topology and immutable setup actions.
expected_header=(
  'name: Core environment'
  ''
  'on:'
  '  push:'
  '    branches:'
  '      - main'
  '  pull_request:'
  '    branches:'
  '      - main'
  ''
  'permissions:'
  '  contents: read'
  ''
  'env:'
  '  DOCKER_BUILDKIT: "1"'
  ''
  'jobs:'
)
diff -u <(printf '%s\n' "${expected_header[@]}") <(sed -n '1,/^jobs:$/p' "$workflow") || \
  fail 'workflow triggers, permissions, or environment escaped their top-level scope'

mapfile -t job_ids < <(
  awk '
    /^jobs:$/ { in_jobs = 1; next }
    in_jobs && /^  [A-Za-z0-9_-]+:$/ {
      line = $0
      sub(/^  /, "", line)
      sub(/:$/, "", line)
      print line
    }
  ' "$workflow"
)
expected_jobs=(static build-amd64 build-arm64)
test "${job_ids[*]}" = "${expected_jobs[*]}" || \
  fail "unexpected workflow jobs: ${job_ids[*]}"
test "$(grep -Fxc '    runs-on: ubuntu-24.04' "$workflow")" -eq 3 || \
  fail 'every workflow job must use ubuntu-24.04'
test "$(grep -Fxc '    needs: static' "$workflow")" -eq 2 || \
  fail 'both platform jobs must need static'
test "$(grep -Fxc '      - main' "$workflow")" -eq 2 || \
  fail 'workflow must target main for exactly push and pull_request'
assert_contains "$workflow" '  pull_request:'
assert_contains "$workflow" '  push:'
assert_contains "$workflow" 'permissions:'
assert_contains "$workflow" '  contents: read'
assert_contains "$workflow" '  DOCKER_BUILDKIT: "1"'
assert_not_contains "$workflow" 'pull_request_target'

checkout='actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5'
qemu='docker/setup-qemu-action@c7c53464625b32c7a7e944ae62b3e17d2b600130'
buildx='docker/setup-buildx-action@8d2750c68a42422c14e847fe6c8ac0403b4cbd6f'
compose='docker/setup-compose-action@2fe291b7677a45ee1269ec56a42604c143505e7e'

extract_job() {
  local job="$1" output="$2"
  awk -v header="  ${job}:" '
    $0 == header { capture = 1 }
    capture && $0 != header && /^  [A-Za-z0-9_-]+:$/ { exit }
    capture { print }
  ' "$workflow" > "$output"
}

static_job="$contract_tmp/static.job"
amd64_job="$contract_tmp/amd64.job"
arm64_job="$contract_tmp/arm64.job"
extract_job static "$static_job"
extract_job build-amd64 "$amd64_job"
extract_job build-arm64 "$arm64_job"

assert_ordered() {
  local file="$1"
  shift
  local previous=0 pattern line
  for pattern in "$@"; do
    test "$(grep -Fc -- "$pattern" "$file")" -eq 1 || \
      fail "$file must contain exactly one ordered occurrence: $pattern"
    line="$(grep -nF -- "$pattern" "$file" | cut -d: -f1)"
    test "$line" -gt "$previous" || fail "$file has wrong order at: $pattern"
    previous="$line"
  done
}

extract_action() {
  local job_file="$1" action_ref="$2" output="$3"
  awk -v action="      - uses: ${action_ref}" '
    $0 == action { capture = 1 }
    capture && $0 != action && /^      - / { exit }
    capture { print }
  ' "$job_file" > "$output"
}

extract_named_step() {
  local job_file="$1" step_name="$2" output="$3"
  awk -v step="      - name: ${step_name}" '
    $0 == step { capture = 1 }
    capture && $0 != step && /^      - / { exit }
    capture { print }
  ' "$job_file" > "$output"
}

assert_action_block() {
  local job_file="$1" action_ref="$2" kind="$3"
  local actual="$contract_tmp/action.$RANDOM"
  extract_action "$job_file" "$action_ref" "$actual"
  case "$kind" in
    checkout)
      diff -u <(printf '%s\n' \
        "      - uses: $checkout" \
        '        with:' \
        '          persist-credentials: false') "$actual" || \
        fail "checkout inputs are not attached to checkout in $job_file"
      ;;
    buildx)
      diff -u <(printf '%s\n' \
        "      - uses: $buildx" \
        '        with:' \
        '          version: v0.35.0' \
        '          driver-opts: image=moby/buildkit@sha256:0168606be2315b7c807a03b3d8aa79beefdb31c98740cebdffdfeebf31190c9f' \
        '          buildkitd-flags: --debug') "$actual" || \
        fail "Buildx inputs are not attached to Buildx in $job_file"
      ;;
    qemu)
      diff -u <(printf '%s\n' \
        "      - uses: $qemu" \
        '        with:' \
        '          image: tonistiigi/binfmt@sha256:400a4873b838d1b89194d982c45e5fb3cda4593fbfd7e08a02e76b03b21166f0' \
        '          platforms: arm64') "$actual" || \
        fail "QEMU inputs are not attached to QEMU in $job_file"
      ;;
    compose)
      diff -u <(printf '%s\n' \
        "      - uses: $compose" \
        '        with:' \
        '          version: v2.30.3') "$actual" || \
        fail "Compose inputs are not attached to Compose in $job_file"
      ;;
  esac
  rm -f "$actual"
}

for job_file in "$static_job" "$amd64_job" "$arm64_job"; do
  assert_action_block "$job_file" "$checkout" checkout
  assert_action_block "$job_file" "$buildx" buildx
  test "$(grep -Fxc '    runs-on: ubuntu-24.04' "$job_file")" -eq 1 || \
    fail "$job_file must bind its job to ubuntu-24.04 exactly once"
  test "$(grep -Fxc '          docker system prune --all --force --volumes' "$job_file")" -eq 1 || \
    fail "$job_file must prune preinstalled Docker data exactly once"
  test "$(grep -Ec '^    timeout-minutes: [0-9]+$' "$job_file")" -eq 1 || \
    fail "$job_file must have exactly one job timeout"
done
test "$(grep -Fxc '    needs: static' "$static_job")" -eq 0 || \
  fail 'static job cannot depend on itself'
for job_file in "$amd64_job" "$arm64_job"; do
  test "$(grep -Fxc '    needs: static' "$job_file")" -eq 1 || \
    fail "$job_file must depend on static exactly once"
  test "$(grep -Ec '^        timeout-minutes: [0-9]+$' "$job_file")" -eq 1 || \
    fail "$job_file must bound its runtime smoke step exactly once"
done
test "$(grep -Ec '^        timeout-minutes: [0-9]+$' "$static_job")" -eq 0 || \
  fail 'static job cannot contain a runtime-smoke timeout'

amd64_smoke_step="$contract_tmp/amd64-smoke.step"
arm64_smoke_step="$contract_tmp/arm64-smoke.step"
extract_named_step "$amd64_job" 'Smoke amd64 core image' "$amd64_smoke_step"
extract_named_step "$arm64_job" 'Smoke arm64 core image' "$arm64_smoke_step"
diff -u <(printf '%s\n' \
  '      - name: Smoke amd64 core image' \
  '        timeout-minutes: 10' \
  '        run: bash tests/smoke_core_image.bash linux/amd64 nexus-core-ci:amd64 x86_64') \
  "$amd64_smoke_step" || fail 'amd64 timeout/run are not attached to the smoke step'
diff -u <(printf '%s\n' \
  '      - name: Smoke arm64 core image' \
  '        timeout-minutes: 15' \
  '        run: bash tests/smoke_core_image.bash linux/arm64 nexus-core-ci:arm64 aarch64') \
  "$arm64_smoke_step" || fail 'arm64 timeout/run are not attached to the smoke step'
assert_action_block "$static_job" "$compose" compose
assert_action_block "$arm64_job" "$qemu" qemu
assert_not_contains "$static_job" "$qemu"
assert_not_contains "$amd64_job" "$qemu"
assert_not_contains "$amd64_job" "$compose"
assert_not_contains "$arm64_job" "$compose"
assert_not_contains "$static_job" 'docker buildx build'

assert_ordered "$static_job" \
  'docker system prune --all --force --volumes' \
  "uses: $checkout" "uses: $buildx" "uses: $compose" \
  'test "$(docker compose version --short)" = '\''2.30.3'\''' \
  'bash tests/run_all.bash --checks'
assert_ordered "$amd64_job" \
  'docker system prune --all --force --volumes' \
  "uses: $checkout" "uses: $buildx" \
  'docker buildx build --pull --platform linux/amd64 --target ros-python-dev --load --tag nexus-core-ci:amd64 .' \
  'docker buildx prune --all --force' \
  'docker image inspect --format '\''{{.Os}}/{{.Architecture}}'\'' nexus-core-ci:amd64' \
  'bash tests/smoke_core_image.bash linux/amd64 nexus-core-ci:amd64 x86_64' \
  'if: failure()' 'df -h' 'docker system df'
assert_ordered "$arm64_job" \
  'docker system prune --all --force --volumes' \
  "uses: $checkout" "uses: $qemu" "uses: $buildx" \
  'docker buildx build --pull --platform linux/arm64 --target ros-python-dev --load --tag nexus-core-ci:arm64 .' \
  'docker buildx prune --all --force' \
  'docker image inspect --format '\''{{.Os}}/{{.Architecture}}'\'' nexus-core-ci:arm64' \
  'bash tests/smoke_core_image.bash linux/arm64 nexus-core-ci:arm64 aarch64' \
  'if: failure()' 'df -h' 'docker system df'

mapfile -t uses_values < <(sed -n 's/^[[:space:]]*- uses: //p' "$workflow")
test "${#uses_values[@]}" -eq 8 || fail 'workflow must have exactly eight uses entries'
test "$(printf '%s\n' "${uses_values[@]}" | grep -Fxc "$checkout")" -eq 3 || \
  fail 'checkout action count is not three'
test "$(printf '%s\n' "${uses_values[@]}" | grep -Fxc "$buildx")" -eq 3 || \
  fail 'Buildx action count is not three'
test "$(printf '%s\n' "${uses_values[@]}" | grep -Fxc "$qemu")" -eq 1 || \
  fail 'QEMU action count is not one'
test "$(printf '%s\n' "${uses_values[@]}" | grep -Fxc "$compose")" -eq 1 || \
  fail 'Compose action count is not one'
for action_ref in "${uses_values[@]}"; do
  case "$action_ref" in
    "$checkout"|"$qemu"|"$buildx"|"$compose") ;;
    *) fail "unapproved action reference: $action_ref" ;;
  esac
done
test "$(grep -Fxc '          persist-credentials: false' "$workflow")" -eq 3 || \
  fail 'every checkout must disable persisted credentials'
test "$(grep -Fxc '          version: v0.35.0' "$workflow")" -eq 3 || \
  fail 'every Buildx setup must pin v0.35.0'
test "$(grep -Fxc '          driver-opts: image=moby/buildkit@sha256:0168606be2315b7c807a03b3d8aa79beefdb31c98740cebdffdfeebf31190c9f' "$workflow")" -eq 3 || \
  fail 'every Buildx setup must pin the approved BuildKit image'
test "$(grep -Fxc '          buildkitd-flags: --debug' "$workflow")" -eq 3 || \
  fail 'every Buildx setup must reset insecure default entitlements'
assert_contains "$workflow" \
  '          image: tonistiigi/binfmt@sha256:400a4873b838d1b89194d982c45e5fb3cda4593fbfd7e08a02e76b03b21166f0'
assert_contains "$workflow" '          platforms: arm64'
assert_contains "$workflow" '          version: v2.30.3'
assert_contains "$workflow" \
  'test "$(docker compose version --short)" = '\''2.30.3'\'''

qemu_line="$(grep -nF -- "uses: $qemu" "$workflow" | cut -d: -f1)"
arm_buildx_line="$(grep -nF -- "uses: $buildx" "$workflow" | tail -n1 | cut -d: -f1)"
test "$qemu_line" -lt "$arm_buildx_line" || fail 'QEMU setup must precede arm64 Buildx setup'

assert_contains "$workflow" \
  'docker buildx build --pull --platform linux/amd64 --target ros-python-dev --load --tag nexus-core-ci:amd64 .'
assert_contains "$workflow" \
  'docker buildx build --pull --platform linux/arm64 --target ros-python-dev --load --tag nexus-core-ci:arm64 .'
test "$(grep -Fxc '          docker buildx prune --all --force' "$workflow")" -eq 2 || \
  fail 'each platform job must prune Buildx cache after loading its image'
assert_contains "$workflow" \
  'test "$(docker image inspect --format '\''{{.Os}}/{{.Architecture}}'\'' nexus-core-ci:amd64)" = '\''linux/amd64'\'''
assert_contains "$workflow" \
  'test "$(docker image inspect --format '\''{{.Os}}/{{.Architecture}}'\'' nexus-core-ci:arm64)" = '\''linux/arm64'\'''
assert_contains "$workflow" \
  'bash tests/smoke_core_image.bash linux/amd64 nexus-core-ci:amd64 x86_64'
assert_contains "$workflow" \
  'bash tests/smoke_core_image.bash linux/arm64 nexus-core-ci:arm64 aarch64'
assert_contains "$workflow" 'bash tests/run_all.bash --checks'
test "$(grep -Fxc '          docker system prune --all --force --volumes' "$workflow")" -eq 3 || \
  fail 'every ephemeral job must remove preinstalled Docker data before setup'
test "$(grep -Ec '^    timeout-minutes: [0-9]+$' "$workflow")" -eq 3 || \
  fail 'every workflow job must have a timeout'
test "$(grep -Ec '^        timeout-minutes: [0-9]+$' "$workflow")" -eq 2 || \
  fail 'every runtime smoke step must have a timeout'
test "$(grep -Fxc '          df -h' "$workflow")" -eq 2 || \
  fail 'platform failure diagnostics must include df -h'
test "$(grep -Fxc '          docker system df' "$workflow")" -eq 2 || \
  fail 'platform failure diagnostics must include docker system df'

# Match risky constructs narrowly so safe YAML terms remain usable.
if grep -Eq '\$\{\{[[:space:]]*secrets\.' "$workflow"; then
  fail 'workflow references a secret expression'
fi
for forbidden in \
  'docker/login-action' 'docker login' 'docker push' '--push' 'push: true' \
  'actions/upload-artifact' 'actions/download-artifact' 'docker.sock' '--privileged' \
  '--device' '/dev/' '--network=host' '--network host' '--net=host' \
  '--allow security.insecure' '--allow=security.insecure' \
  '--allow network.host' '--allow=network.host' \
  'ros2 topic pub' 'ros2 service call' 'ros2 action send_goal'; do
  assert_not_contains "$workflow" "$forbidden"
done
if grep -Eqi 'doosan|openarm|isaac[-_]?ros|ros-ai-dev|isaac[[:space:]_-]*sim|nvidia|x11' "$workflow"; then
  fail 'workflow contains vendor, AI-runtime, simulator, GPU, or GUI behavior'
fi

for ignored in .git .github .env; do
  test "$(grep -Fxc "$ignored" .dockerignore)" -eq 1 || \
    fail ".dockerignore must contain exact record: $ignored"
done

# Smoke implementation spelling is checked in addition to behavioral stubs below.
assert_file "$smoke"
for required in \
  'docker container inspect' 'docker image inspect' '--pull=never' '--rm' '--init' \
  '--cap-drop=ALL' '--security-opt=no-new-privileges' '--cidfile' \
  'timeout --kill-after=10s' 'timeout --kill-after=2s' 'trap' 'EXIT' 'INT' 'TERM' \
  'docker rm -f' 'I heard:' 'ros2 pkg prefix demo_nodes_cpp' \
  'uv 0.8.3' 'ROS_DISTRO' 'uname -m'; do
  assert_contains "$smoke" "$required"
done
for forbidden in '--privileged' '--device' '--network=host' '--network host' \
  '--net=host' 'docker.sock'; do
  assert_not_contains "$smoke" "$forbidden"
done
assert_contains "$smoke" 'set -eo pipefail'
source_line="$(grep -nFx 'source /etc/profile.d/nexus_env.bash' "$smoke" | cut -d: -f1)"
nounset_line="$(grep -nFx 'set -u' "$smoke" | cut -d: -f1)"
test -n "$source_line" && test -n "$nounset_line" && test "$source_line" -lt "$nounset_line" || \
  fail 'container smoke must source ROS setup before enabling nounset'

# Fake only the Docker/timeout process boundary. The helper itself and its ownership logic are real.
smoke_tmp="$contract_tmp/smoke"
mkdir -p "$smoke_tmp"
stub_bin="$smoke_tmp/bin"
mkdir -p "$stub_bin"
docker_log="$smoke_tmp/docker.log"
smoke_output="$smoke_tmp/output"
run_argv_file="$smoke_tmp/run.argv"
owned_cid='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'

cat > "$stub_bin/docker" <<'FAKE_DOCKER'
#!/usr/bin/env bash
set -euo pipefail
: "${FAKE_DOCKER_MODE:?}"
: "${FAKE_DOCKER_LOG:?}"
: "${FAKE_DOCKER_RUN_ARGV:?}"
: "${FAKE_IMAGE_PLATFORM:?}"
: "${FAKE_OWNED_CID:?}"

{
  printf 'argv'
  for arg in "$@"; do
    printf '\t%q' "$arg"
  done
  printf '\n'
} >> "$FAKE_DOCKER_LOG"

if (($# >= 3)) && [[ "$1 $2" == 'container inspect' ]]; then
  printf 'container inspect %s\n' "$3" >> "$FAKE_DOCKER_LOG"
  if [[ "$3" == nexus-core-smoke-* ]]; then
    [[ "$FAKE_DOCKER_MODE" == stale ]]
    exit
  fi
  [[ "$3" == "$FAKE_OWNED_CID" && "$FAKE_DOCKER_MODE" != success-gone ]]
  exit
fi

if (($# >= 5)) && [[ "$1 $2" == 'image inspect' ]]; then
  tag="${5:-}"
  printf 'image inspect %s\n' "$tag" >> "$FAKE_DOCKER_LOG"
  if [[ "$FAKE_DOCKER_MODE" == image-missing ]]; then
    exit 1
  fi
  if [[ "$FAKE_DOCKER_MODE" == image-mismatch ]]; then
    printf 'linux/arm64\n'
    exit 0
  fi
  printf '%s\n' "$FAKE_IMAGE_PLATFORM"
  exit 0
fi

if (($# >= 1)) && [[ "$1" == run ]]; then
  printf '%s\0' "$@" > "$FAKE_DOCKER_RUN_ARGV"
  cidfile=''
  name=''
  shift
  while (($#)); do
    case "$1" in
      --cidfile) cidfile="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -n "$name" && -n "$cidfile" ]] || exit 97
  printf 'run name=%s cidfile=%s\n' "$name" "$cidfile" >> "$FAKE_DOCKER_LOG"
  printf 'run-cid-parent-mode %s\n' "$(stat -c %a "$(dirname "$cidfile")")" >> "$FAKE_DOCKER_LOG"
  printf 'run-cidfile-path %s\n' "$cidfile" >> "$FAKE_DOCKER_LOG"
  write_owned_cid() {
    printf '%s' "$FAKE_OWNED_CID" > "$cidfile"
    printf 'cid-bytes %s\n' "$(wc -c < "$cidfile")" >> "$FAKE_DOCKER_LOG"
    printf 'cid-parent-mode %s\n' "$(stat -c %a "$(dirname "$cidfile")")" >> "$FAKE_DOCKER_LOG"
    printf 'cidfile-path %s\n' "$cidfile" >> "$FAKE_DOCKER_LOG"
  }
  case "$FAKE_DOCKER_MODE" in
    name-race) exit 125 ;;
    success-missing) exit 0 ;;
    success-malformed) printf 'not-a-container-id' > "$cidfile"; exit 0 ;;
    success-valid|success-gone|cleanup-fail|host-124|signal-130|signal-143)
      write_owned_cid
      exit 0
      ;;
    run-125)
      write_owned_cid
      exit 125
      ;;
    run-137|run-137-cleanup-fail)
      write_owned_cid
      exit 137
      ;;
    *) printf 'unexpected fake Docker mode: %s\n' "$FAKE_DOCKER_MODE" >&2; exit 99 ;;
  esac
fi

if (($# >= 3)) && [[ "$1 $2" == 'rm -f' ]]; then
  printf 'rm -f %s\n' "$3" >> "$FAKE_DOCKER_LOG"
  [[ "$FAKE_DOCKER_MODE" != cleanup-fail && \
     "$FAKE_DOCKER_MODE" != run-137-cleanup-fail ]]
  exit
fi

printf 'unexpected docker invocation: %s\n' "$*" >&2
exit 98
FAKE_DOCKER

cat > "$stub_bin/timeout" <<'FAKE_TIMEOUT'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  '--kill-after=10s 180s'|'--kill-after=2s 10s') ;;
  *) printf 'unexpected timeout bound: %s %s\n' "$1" "$2" >&2; exit 96 ;;
esac
shift 2
if [[ "$1 $2" == 'docker run' ]]; then
  case "${FAKE_DOCKER_MODE:?}" in
    host-124)
      "$@"
      exit 124
      ;;
    signal-130)
      "$@"
      kill -INT "$PPID"
      exit 0
      ;;
    signal-143)
      "$@"
      kill -TERM "$PPID"
      exit 0
      ;;
  esac
fi
exec "$@"
FAKE_TIMEOUT
chmod +x "$stub_bin/docker" "$stub_bin/timeout"

smoke_status=0
invoke_smoke() {
  local mode="$1"
  shift
  : > "$docker_log"
  : > "$smoke_output"
  : > "$run_argv_file"
  set +e
  env \
    PATH="$stub_bin:$PATH" \
    FAKE_DOCKER_MODE="$mode" \
    FAKE_DOCKER_LOG="$docker_log" \
    FAKE_DOCKER_RUN_ARGV="$run_argv_file" \
    FAKE_IMAGE_PLATFORM=linux/amd64 \
    FAKE_OWNED_CID="$owned_cid" \
    bash "$smoke" "$@" > "$smoke_output" 2>&1
  smoke_status=$?
  set -e
}

assert_no_docker() {
  [[ ! -s "$docker_log" ]] || fail "invalid input reached Docker: $(cat "$docker_log")"
}

assert_owned_removals_only() {
  local bad
  bad="$(grep '^rm -f ' "$docker_log" | grep -Fvx "rm -f $owned_cid" || true)"
  [[ -z "$bad" ]] || fail "cleanup targeted an unowned container: $bad"
  assert_not_contains "$docker_log" 'rm -f nexus-core-smoke-amd64'
}

invoke_smoke unused
test "$smoke_status" -eq 2 || fail 'zero-argument smoke invocation must exit 2'
assert_no_docker
invoke_smoke unused linux/amd64
test "$smoke_status" -eq 2 || fail 'one-argument smoke invocation must exit 2'
assert_no_docker
invoke_smoke unused linux/amd64 core:test
test "$smoke_status" -eq 2 || fail 'two-argument smoke invocation must exit 2'
assert_no_docker
invoke_smoke unused linux/amd64 core:test x86_64 extra
test "$smoke_status" -eq 2 || fail 'four-argument smoke invocation must exit 2'
assert_no_docker
invoke_smoke unused linux/ppc64le core:test ppc64le
test "$smoke_status" -eq 2 || fail 'unsupported smoke platform must exit 2'
assert_no_docker
invoke_smoke unused linux/amd64 core:test aarch64
test "$smoke_status" -eq 2 || fail 'platform/machine mismatch must exit 2'
assert_no_docker
invoke_smoke unused linux/amd64 -bad x86_64
test "$smoke_status" -eq 2 || fail 'leading-dash image tag must exit 2'
assert_no_docker
invoke_smoke unused linux/amd64 'bad tag' x86_64
test "$smoke_status" -eq 2 || fail 'whitespace image tag must exit 2'
assert_no_docker
invoke_smoke unused linux/amd64 'bad+tag' x86_64
test "$smoke_status" -eq 2 || fail 'out-of-grammar image tag must exit 2'
assert_no_docker

invoke_smoke stale linux/amd64 core:test x86_64
test "$smoke_status" -ne 0 || fail 'stale fixed-name container unexpectedly succeeded'
assert_contains "$smoke_output" 'E_STALE_CONTAINER'
assert_not_contains "$docker_log" 'run name='
assert_not_contains "$docker_log" 'rm -f '

invoke_smoke name-race linux/amd64 core:test x86_64
test "$smoke_status" -eq 125 || fail 'name-race status was not preserved'
assert_contains "$docker_log" 'run name=nexus-core-smoke-amd64 cidfile='
test "$(grep -Fxc 'run-cid-parent-mode 700' "$docker_log")" -eq 1 || \
  fail 'name-race did not receive a private cidfile parent'
test -n "$(sed -n 's/^run-cidfile-path //p' "$docker_log")" || \
  fail 'name-race did not execute docker run with a cidfile'
assert_not_contains "$docker_log" 'rm -f '

for mode_and_status in run-125:125 run-137:137 host-124:124 signal-130:130 signal-143:143; do
  mode="${mode_and_status%%:*}"
  expected_status="${mode_and_status#*:}"
  invoke_smoke "$mode" linux/amd64 core:test x86_64
  test "$smoke_status" -eq "$expected_status" || \
    fail "$mode status: expected $expected_status, got $smoke_status"
  assert_owned_removals_only
  test "$(grep -Fxc "rm -f $owned_cid" "$docker_log")" -eq 1 || \
    fail "$mode did not clean its owned CID exactly once"
done

invoke_smoke run-137-cleanup-fail linux/amd64 core:test x86_64
test "$smoke_status" -eq 137 || fail 'cleanup failure replaced nonzero run status 137'
test "$(grep -Fxc "rm -f $owned_cid" "$docker_log")" -eq 1 || \
  fail 'nonzero cleanup-failure case did not target its owned CID exactly once'
assert_owned_removals_only

invoke_smoke success-missing linux/amd64 core:test x86_64
test "$smoke_status" -ne 0 || fail 'success without a cidfile unexpectedly succeeded'
assert_contains "$smoke_output" 'E_CIDFILE'
assert_not_contains "$docker_log" 'rm -f '
invoke_smoke success-malformed linux/amd64 core:test x86_64
test "$smoke_status" -ne 0 || fail 'success with malformed cidfile unexpectedly succeeded'
assert_contains "$smoke_output" 'E_CIDFILE'
assert_not_contains "$docker_log" 'rm -f '

invoke_smoke success-gone linux/amd64 core:test x86_64
test "$smoke_status" -eq 0 || fail 'successful --rm path with an already-gone container failed'
assert_not_contains "$smoke_output" 'E_CLEANUP'
assert_not_contains "$docker_log" 'rm -f '

for image_mode in image-missing image-mismatch; do
  invoke_smoke "$image_mode" linux/amd64 core:test x86_64
  test "$smoke_status" -ne 0 || fail "$image_mode unexpectedly succeeded"
  assert_not_contains "$docker_log" 'run name='
  assert_not_contains "$docker_log" 'rm -f '
done

invoke_smoke success-valid linux/amd64 core:test x86_64
test "$smoke_status" -eq 0 || fail 'valid owned-cid smoke failed'
test "$(grep -Fxc "rm -f $owned_cid" "$docker_log")" -eq 1 || \
  fail 'valid owned CID was not cleaned exactly once'
test "$(grep -Fxc 'cid-bytes 64' "$docker_log")" -eq 1 || \
  fail 'fake Docker did not write the real 64-byte no-newline cidfile format'
test "$(grep -Fxc 'cid-parent-mode 700' "$docker_log")" -eq 1 || \
  fail 'helper cidfile parent directory is not private mode 0700'
first_cidfile="$(sed -n 's/^cidfile-path //p' "$docker_log")"
test -n "$first_cidfile" || fail 'helper did not allocate a private cidfile'
test "$(grep -Fc 'run name=' "$docker_log")" -eq 1 || \
  fail 'helper must issue exactly one docker run'
mapfile -d '' -t run_argv < "$run_argv_file"
test "${#run_argv[@]}" -eq 18 || \
  fail "docker run must have exactly 18 allow-listed arguments, got ${#run_argv[@]}"
expected_run_prefix=(
  run
  --pull=never
  --rm
  --init
  --platform
  linux/amd64
  --name
  nexus-core-smoke-amd64
  --cap-drop=ALL
  --security-opt=no-new-privileges
  --cidfile
)
for index in "${!expected_run_prefix[@]}"; do
  test "${run_argv[$index]}" = "${expected_run_prefix[$index]}" || \
    fail "unexpected docker run argv[$index]: ${run_argv[$index]}"
done
test "${run_argv[11]}" = "$first_cidfile" || fail 'docker run used the wrong cidfile'
test "${run_argv[12]}" = core:test || fail 'docker run used the wrong local tag'
test "${run_argv[13]}" = bash || fail 'docker run did not invoke Bash'
test "${run_argv[14]}" = -c || fail 'docker run did not pass a fixed Bash program'
test "$(grep -Fxc "read -r -d '' container_script <<'CONTAINER_SCRIPT' || true" "$smoke")" -eq 1 || \
  fail 'helper must define exactly one fixed container script heredoc'
test "$(grep -Fxc '  bash -c "$container_script" -- "$expected_machine"' "$smoke")" -eq 1 || \
  fail 'helper must pass that fixed script and machine as positional data exactly once'
expected_container_script_file="$contract_tmp/expected-container-script"
observed_container_script_file="$contract_tmp/observed-container-script"
awk '
  /^read -r -d '\''\'\'' container_script <<'\''CONTAINER_SCRIPT'\'' \|\| true$/ {
    capture = 1
    next
  }
  capture && /^CONTAINER_SCRIPT$/ { exit }
  capture { print }
' "$smoke" > "$expected_container_script_file"
expected_script_bytes="$(wc -c < "$expected_container_script_file")"
test "$expected_script_bytes" -gt 1 || fail 'fixed container script heredoc is empty'
# Bash read with its default IFS removes the heredoc's one terminating newline.
truncate -s "$((expected_script_bytes - 1))" "$expected_container_script_file"
printf '%s' "${run_argv[15]}" > "$observed_container_script_file"
cmp -s "$expected_container_script_file" "$observed_container_script_file" || \
  fail 'docker run did not pass the fixed in-container script as data'
test "${run_argv[16]}" = -- || fail 'docker run did not terminate Bash options'
test "${run_argv[17]}" = x86_64 || fail 'docker run did not pass expected machine as positional data'
assert_owned_removals_only

invoke_smoke success-valid linux/amd64 core:test x86_64
test "$smoke_status" -eq 0 || fail 'second valid owned-cid smoke failed'
second_cidfile="$(sed -n 's/^cidfile-path //p' "$docker_log")"
test -n "$second_cidfile" || fail 'second helper invocation did not allocate a cidfile'
test "$first_cidfile" != "$second_cidfile" || fail 'helper reused a cidfile path across invocations'

invoke_smoke cleanup-fail linux/amd64 core:test x86_64
test "$smoke_status" -eq 0 || fail 'cleanup failure replaced successful run status'
test "$(grep -Fxc "rm -f $owned_cid" "$docker_log")" -eq 1 || \
  fail 'cleanup-failure case did not target the owned CID'
assert_owned_removals_only

printf 'static core contract passed\n'
