#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source tests/helpers/assert.bash

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp .env.example "$tmp/local.env"

jq_assert() {
  local file="$1"
  local description="$2"
  shift 2
  jq -e "$@" "$file" >/dev/null || fail "$description ($file)"
}

env_value() {
  local file="$1"
  local key="$2"
  local -a values=()
  mapfile -t values < <(awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print}' "$file")
  ((${#values[@]} == 1)) || fail "$file must define $key exactly once"
  test -n "${values[0]}" || fail "$file defines an empty $key"
  printf '%s\n' "${values[0]}"
}

assert_compose_version() {
  local raw version major minor
  raw="$(docker compose version --short)"
  version="${raw#v}"
  version="${version%%-*}"
  [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || \
    fail "cannot parse Docker Compose semantic version: $raw"
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  if ((major < 2 || (major == 2 && minor < 30))); then
    fail "Docker Compose >=2.30.0 is required, found $raw"
  fi
}

render_model() {
  local output="$1"
  local ai="$2"
  local host="$3"
  local gpu="$4"
  local gui="$5"
  local -a args=(-f compose.yml)

  ((host)) && args+=(-f compose/host-dds.yml)
  ((gpu)) && args+=(-f compose/gpu.yml)
  ((gui)) && args+=(-f compose/gui.yml)
  ((ai)) && args+=(--profile ai)

  docker compose \
    --env-file docker/versions.env \
    --env-file "$tmp/local.env" \
    "${args[@]}" config --format json > "$output"
}

assert_service_contract() {
  local model="$1"
  local service="$2"
  local host="$3"
  local gpu="$4"
  local gui="$5"
  local target="ros-python-dev"
  local source_path
  local expected_targets='["/workspace"]'

  [[ "$service" == ai_dev ]] && target="ros-ai-dev"

  jq_assert "$model" "$service uses its core Docker target" \
    --arg service "$service" --arg target "$target" \
    '.services[$service].build.target == $target'
  jq_assert "$model" "$service builds the repository Dockerfile" \
    --arg service "$service" --arg root "$ROOT" \
    '.services[$service].build.context == $root and
     .services[$service].build.dockerfile == "Dockerfile"'
  jq_assert "$model" "$service runs as developer" \
    --arg service "$service" '.services[$service].user == "developer"'
  jq_assert "$model" "$service enables an init process" \
    --arg service "$service" '.services[$service].init == true'
  jq_assert "$model" "$service has no fixed container name" \
    --arg service "$service" '.services[$service] | has("container_name") | not'
  jq_assert "$model" "$service is not privileged" \
    --arg service "$service" '.services[$service].privileged != true'
  jq_assert "$model" "$service adds no capabilities" \
    --arg service "$service" '(.services[$service].cap_add // []) | length == 0'
  jq_assert "$model" "$service maps no raw devices" \
    --arg service "$service" '(.services[$service].devices // []) | length == 0'
  jq_assert "$model" "$service adds no device cgroup rules" \
    --arg service "$service" '(.services[$service].device_cgroup_rules // []) | length == 0'
  jq_assert "$model" "$service does not share the host PID namespace" \
    --arg service "$service" '.services[$service] | has("pid") | not'
  jq_assert "$model" "$service does not share host IPC" \
    --arg service "$service" '.services[$service] | has("ipc") | not'
  jq_assert "$model" "$service does not mount the Docker socket" \
    --arg service "$service" \
    '[.services[$service].volumes[]?.target] | index("/var/run/docker.sock") | not'

  for arg in ROS_BASE_IMAGE UV_IMAGE DEVELOPER_UID DEVELOPER_GID; do
    jq_assert "$model" "$service passes build arg $arg" \
      --arg service "$service" --arg arg "$arg" \
      '.services[$service].build.args[$arg] != null'
  done
  jq_assert "$model" "$service passes the ROS image pin" \
    --arg service "$service" --arg value "$ros_pin" \
    '.services[$service].build.args.ROS_BASE_IMAGE == $value'
  jq_assert "$model" "$service passes the uv image pin" \
    --arg service "$service" --arg value "$uv_pin" \
    '.services[$service].build.args.UV_IMAGE == $value'
  jq_assert "$model" "$service passes the default developer IDs" \
    --arg service "$service" \
    '.services[$service].build.args.DEVELOPER_UID == "1000" and
     .services[$service].build.args.DEVELOPER_GID == "1000"'

  jq_assert "$model" "$service exports the ROS/FastDDS environment" \
    --arg service "$service" \
    '.services[$service].environment.ROS_DOMAIN_ID == "42" and
     .services[$service].environment.RMW_IMPLEMENTATION == "rmw_fastrtps_cpp" and
     .services[$service].environment.FASTDDS_DEFAULT_PROFILES_FILE == "/workspace/config/fastdds.xml" and
     .services[$service].environment.FASTRTPS_DEFAULT_PROFILES_FILE == "/workspace/config/fastdds.xml"'

  jq_assert "$model" "$service binds the repository workspace once" \
    --arg service "$service" --arg root "$ROOT" \
    '[.services[$service].volumes[]? |
      select(.type == "bind" and .target == "/workspace" and .source == $root and .read_only != true)] |
      length == 1'
  jq_assert "$model" "$service forbids implicit host-path creation for every bind" \
    --arg service "$service" \
    'all(.services[$service].volumes[]?;
      .type != "bind" or .bind.create_host_path == false)'

  if ((host)); then
    jq_assert "$model" "$service gets host networking only from the selected overlay" \
      --arg service "$service" '.services[$service].network_mode == "host"'
  else
    jq_assert "$model" "$service has no host-network setting" \
      --arg service "$service" '.services[$service] | has("network_mode") | not'
  fi

  if ((gpu)) && [[ "$service" == ai_dev ]]; then
    jq_assert "$model" "GPU overlay applies only to ai_dev" \
      --arg service "$service" '(.services[$service].gpus // []) | length > 0'
    jq_assert "$model" "GPU overlay grants only requested driver capabilities" \
      --arg service "$service" \
      '.services[$service].environment.NVIDIA_VISIBLE_DEVICES == "all" and
       .services[$service].environment.NVIDIA_DRIVER_CAPABILITIES == "compute,utility"'
  else
    jq_assert "$model" "$service has no GPU request" \
      --arg service "$service" '.services[$service] | has("gpus") | not'
    jq_assert "$model" "$service has no NVIDIA grant environment" \
      --arg service "$service" \
      '(.services[$service].environment | has("NVIDIA_VISIBLE_DEVICES") | not) and
       (.services[$service].environment | has("NVIDIA_DRIVER_CAPABILITIES") | not)'
  fi

  if ((gui)); then
    expected_targets='["/tmp/.X11-unix","/tmp/.nexus.xauth","/workspace"]'
    jq_assert "$model" "$service gets only the restricted GUI environment" \
      --arg service "$service" \
      '.services[$service].environment.DISPLAY == ":0" and
       .services[$service].environment.XAUTHORITY == "/tmp/.nexus.xauth" and
       .services[$service].environment.QT_X11_NO_MITSHM == "1"'
    for target_path in /tmp/.X11-unix /tmp/.nexus.xauth; do
      source_path="$target_path"
      [[ "$target_path" == /tmp/.nexus.xauth ]] && source_path="$xauth_source"
      jq_assert "$model" "$service mounts $target_path read-only without host-path creation" \
        --arg service "$service" --arg target "$target_path" --arg source "$source_path" \
        '[.services[$service].volumes[]? |
          select(.type == "bind" and .source == $source and .target == $target and
                 .read_only == true and .bind.create_host_path == false)] |
          length == 1'
    done
  else
    jq_assert "$model" "$service has no GUI environment" \
      --arg service "$service" \
      '(.services[$service].environment | has("DISPLAY") | not) and
       (.services[$service].environment | has("XAUTHORITY") | not) and
       (.services[$service].environment | has("QT_X11_NO_MITSHM") | not)'
  fi

  jq_assert "$model" "$service mounts only the selected bind set" \
    --arg service "$service" --argjson expected "$expected_targets" \
    '([.services[$service].volumes[]?.target] | sort) == $expected'
}

assert_model() {
  local model="$1"
  local ai="$2"
  local host="$3"
  local gpu="$4"
  local gui="$5"

  if ((ai)); then
    jq_assert "$model" 'AI model contains exactly the two core services' \
      '(.services | keys | sort) == ["ai_dev", "ros2_dev"]'
  else
    jq_assert "$model" 'core model contains only ros2_dev' \
      '(.services | keys) == ["ros2_dev"]'
  fi

  assert_service_contract "$model" ros2_dev "$host" 0 "$gui"
  if ((ai)); then
    assert_service_contract "$model" ai_dev "$host" "$gpu" "$gui"
    jq_assert "$model" 'ai_dev remains opt-in through the ai profile' \
      '.services.ai_dev.profiles == ["ai"]'
  fi

  vendor_service_values="$(jq -r '[.services | to_entries[] | .key, (.value.image // "")] | join("\\n")' "$model")"
  if grep -Eqi 'doosan|openarm|isaac_ros' <<< "$vendor_service_values"; then
    fail "vendor runtime leaked into normalized core Compose services: $model"
  fi
}

assert_manifest() {
  local manifest="$1"
  shift
  test -f "$manifest" || fail "missing profile manifest: $manifest"
  diff -u <(printf '%s\n' "$@") "$manifest" || fail "unexpected profile manifest: $manifest"
}

assert_compose_version
ros_pin="$(env_value docker/versions.env ROS_BASE_IMAGE)"
uv_pin="$(env_value docker/versions.env UV_IMAGE)"
xauth_source="$(env_value "$tmp/local.env" NEXUS_XAUTH_FILE)"

# AI supports every independent host-DDS/GPU/GUI overlay combination (2^3).
model_count=0
for host in 0 1; do
  for gpu in 0 1; do
    for gui in 0 1; do
      model="$tmp/ai-${host}${gpu}${gui}.json"
      render_model "$model" 1 "$host" "$gpu" "$gui"
      assert_model "$model" 1 "$host" "$gpu" "$gui"
      ((model_count += 1))
    done
  done
done

# Core supports base/host/GUI/host+GUI without activating the AI service.
for host in 0 1; do
  for gui in 0 1; do
    model="$tmp/core-${host}${gui}.json"
    render_model "$model" 0 "$host" 0 "$gui"
    assert_model "$model" 0 "$host" 0 "$gui"
    ((model_count += 1))
  done
done
test "$model_count" -eq 12 || fail "expected 12 normalized Compose models, got $model_count"

# Both supported host-ID fixtures must reach Docker build args without changing runtime user.
for ids in '1000 1000' '12345 12345'; do
  read -r uid gid <<< "$ids"
  fixture="$tmp/ids-${uid}-${gid}.env"
  awk -v uid="$uid" -v gid="$gid" '
    /^LOCAL_UID=/ { print "LOCAL_UID=" uid; next }
    /^LOCAL_GID=/ { print "LOCAL_GID=" gid; next }
    { print }
  ' .env.example > "$fixture"
  fixture_model="$tmp/ids-${uid}-${gid}.json"
  docker compose \
    --env-file docker/versions.env \
    --env-file "$fixture" \
    -f compose.yml --profile ai config --format json > "$fixture_model"
  for service in ros2_dev ai_dev; do
    jq_assert "$fixture_model" "$service receives fixture IDs $uid:$gid" \
      --arg service "$service" --arg uid "$uid" --arg gid "$gid" \
      '.services[$service].build.args.DEVELOPER_UID == $uid and
       .services[$service].build.args.DEVELOPER_GID == $gid and
       (.services[$service].build.args.DEVELOPER_UID | tonumber) > 0 and
       (.services[$service].build.args.DEVELOPER_GID | tonumber) > 0 and
       .services[$service].user == "developer"'
  done
done

# Match direct Dev Container startup: no version env file and no pin/ID variables.
direct="$tmp/direct.json"
env -i PATH="$PATH" HOME="${HOME:-/tmp}" \
  docker compose -f compose.yml config --format json > "$direct"
jq_assert "$direct" 'direct Compose render selects the Dev Container service only' \
  '(.services | keys) == ["ros2_dev"]'
jq_assert "$direct" 'direct Compose render uses the exact versions.env pins and ID defaults' \
  --arg ros "$ros_pin" --arg uv "$uv_pin" \
  '.services.ros2_dev.build.args.ROS_BASE_IMAGE == $ros and
   .services.ros2_dev.build.args.UV_IMAGE == $uv and
   .services.ros2_dev.build.args.DEVELOPER_UID == "1000" and
   .services.ros2_dev.build.args.DEVELOPER_GID == "1000" and
   .services.ros2_dev.user == "developer"'

# The opt-in service uses the same immutable fallbacks when no env file is supplied.
direct_ai="$tmp/direct-ai.json"
env -i PATH="$PATH" HOME="${HOME:-/tmp}" \
  docker compose -f compose.yml --profile ai config --format json > "$direct_ai"
for service in ros2_dev ai_dev; do
  jq_assert "$direct_ai" "$service uses immutable direct-render fallbacks" \
    --arg service "$service" --arg ros "$ros_pin" --arg uv "$uv_pin" \
    '.services[$service].build.args.ROS_BASE_IMAGE == $ros and
     .services[$service].build.args.UV_IMAGE == $uv and
     .services[$service].build.args.DEVELOPER_UID == "1000" and
     .services[$service].build.args.DEVELOPER_GID == "1000" and
     .services[$service].user == "developer"'
done

jq_assert .devcontainer/devcontainer.json 'Dev Container agrees with the core Compose model' \
  '.dockerComposeFile == "../compose.yml" and
   .service == "ros2_dev" and
   .remoteUser == "developer" and
   .customizations.vscode.settings["python.defaultInterpreterPath"] == "/opt/venv/bin/python"'

assert_manifest profiles/core.conf \
  'PROFILE_VERSION=1' \
  'SERVICE=ros2_dev' \
  'COMPOSE_FILES=compose.yml' \
  'COMPOSE_PROFILES=' \
  'DOCTOR_COMMAND=scripts/doctor.bash,base' \
  'CHECK_COMMAND=scripts/check_dev_workflow.sh'
assert_manifest profiles/isaac-host.conf \
  'PROFILE_VERSION=1' \
  'SERVICE=ros2_dev' \
  'COMPOSE_FILES=compose.yml,compose/host-dds.yml' \
  'COMPOSE_PROFILES=' \
  'DOCTOR_COMMAND=scripts/doctor.bash,isaac-host' \
  'CHECK_COMMAND=scripts/check_dev_workflow.sh'

printf 'compose core contract passed\n'
