#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

image_prefix="ros2-dev-core-runtime-test"
ai_image="${image_prefix}:ai"
docker build --target ros-ai-dev --tag "$ai_image" .
docker run --rm "$ai_image" bash -lc '
  set -euo pipefail
  test "$(id -un)" = developer
  uv pip check --python /opt/venv/bin/python
  /opt/venv/bin/python -c \
    "import diffusers, einops, huggingface_hub, timm, torch, torchvision"
'

printf 'AI runtime contract passed\n'
