#!/usr/bin/env bash
# CangHui local CI: prepare SDL, run root/sdl/cuic tests, build cuic, and run public-surface checks.
# Usage: bash scripts/ci.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "==> CangHui CI on $(uname -s) ($(uname -m))"

# 1. Prepare macOS SDL dylibs in sdl/.sdl3 when missing.
if [[ -f sdl/.sdl3/libSDL3.dylib && -f sdl/.sdl3/libSDL3_ttf.dylib ]]; then
  echo "==> sdl/.sdl3 dylibs present"
else
  if command -v brew >/dev/null 2>&1 && [[ -f /opt/homebrew/lib/libSDL3.dylib ]]; then
    echo "==> copying Homebrew SDL dylibs into sdl/.sdl3"
    cp /opt/homebrew/lib/libSDL3.dylib /opt/homebrew/lib/libSDL3_ttf.dylib sdl/.sdl3/
  else
    echo "==> SDL dylibs unavailable; run scripts/bootstrap-macos.sh or provide libSDL3/libSDL3_ttf dylibs" >&2
    exit 2
  fi
fi

export DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH:-/opt/homebrew/lib}"

# 2. Root framework tests.
echo "==> root cjpm test"
cjpm test

# 3. sdl package tests.
echo "==> sdl cjpm test"
(cd sdl && cjpm test)

# 4. cuic build + test.
echo "==> cuic build + test"
(cd tools/cuic && cjpm test && cjpm build)

# 5. Platform script tests.
echo "==> iOS provisioning profile decoder"
bash scripts/test-ios-provisioning-profile.sh

# 6. Public-surface checks.
echo "==> diff check"
git diff --check

echo "==> public surface audit"
python3 manual/skills/canghui-full-build/scripts/audit_public_surface.py

echo "==> CangHui CI complete"
