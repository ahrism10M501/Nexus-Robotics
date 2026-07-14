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
