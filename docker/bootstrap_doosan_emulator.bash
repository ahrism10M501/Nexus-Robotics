#!/usr/bin/env bash
set -euo pipefail

DOOSAN_ROBOT2_DIR="${DOOSAN_ROBOT2_DIR:-/opt/robot_ws/doosan_ws/src/doosan-robot2}"
INSTALLER="${DOOSAN_ROBOT2_DIR}/install_emulator.sh"
FORCE_INSTALL="${1:-}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI is not installed in this container." >&2
  exit 1
fi

if ! docker ps >/dev/null 2>&1; then
  echo "docker CLI cannot reach the host Docker daemon." >&2
  echo "Start the moveit_dev service with /var/run/docker.sock mounted." >&2
  exit 1
fi

if [ ! -x "${INSTALLER}" ]; then
  echo "Doosan emulator installer not found: ${INSTALLER}" >&2
  exit 1
fi

EMULATOR_IMAGE="${DOOSAN_EMULATOR_IMAGE:-}"
if [ -z "${EMULATOR_IMAGE}" ]; then
  EMULATOR_VERSION="$(awk -F\" '/^emulator_version=/{print $2; exit}' "${INSTALLER}")"
  EMULATOR_IMAGE="$(awk -F\" '/^emulator_image=/{print $2; exit}' "${INSTALLER}")"
  EMULATOR_IMAGE="${EMULATOR_IMAGE//\$emulator_version/${EMULATOR_VERSION}}"
  EMULATOR_IMAGE="${EMULATOR_IMAGE//\$\{emulator_version\}/${EMULATOR_VERSION}}"
fi

if [ -n "${EMULATOR_IMAGE}" ] && [ "${FORCE_INSTALL}" != "--force" ]; then
  if docker image inspect "${EMULATOR_IMAGE}" >/dev/null 2>&1; then
    echo "Doosan emulator image already exists: ${EMULATOR_IMAGE}"
    echo "Skipping install_emulator.sh. Use 'bootstrap_doosan_emulator --force' to re-run it."
    exit 0
  fi
fi

cd "${DOOSAN_ROBOT2_DIR}"
./install_emulator.sh
