#!/usr/bin/env bash
# CangHui local CI: prepare SDL and run package, CLI, security and public-surface gates.
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

# Keep ImageIO/CoreText on the system's image codecs. A broad Homebrew search
# path can replace identically named private OS libraries (including libpng).
# This CI owns only its child environment; never alter the caller's shell/profile.
if [[ -n "${DYLD_LIBRARY_PATH:-}" && "${DYLD_LIBRARY_PATH}" != "${ROOT_DIR}/sdl/.sdl3" ]]; then
  echo "==> scoping the CI dynamic-library search path to prepared SDL libraries"
fi
export DYLD_LIBRARY_PATH="${ROOT_DIR}/sdl/.sdl3"

echo "==> CI loader environment regression"
python3 scripts/test-ci-loader-env.py

# 2. Root framework build and tests.
echo "==> root cjpm build + test"
cjpm build
cjpm test

# 3. sdl package tests.
echo "==> sdl cjpm test"
(cd sdl && cjpm test)

# 4. cuic build + test.
echo "==> cuic build + test"
(cd tools/cuic && cjpm test && cjpm build)

# 5. Source-owned public packages. Native Scene3D packages record a gap unless
# an accepted native supply directory is explicitly provided.
echo "==> source-owned package matrix"
bash scripts/test-chui-matrix.sh packages

echo "==> external probe Option collision fixture"
bash scripts/verify-probe-option-disambiguation.sh

# 6. CLI and installed-distribution regression.
echo "==> cuic CLI smoke"
bash tools/cuic/scripts/test-cli.sh

echo "==> Harmony projection special-file rejection"
python3 scripts/test-harmony-file-types.py --cuic tools/cuic/target/release/bin/main

echo "==> cuic install smoke"
bash tools/cuic/scripts/test-install.sh

# 7. Platform and security script tests.
echo "==> Linux runtime metadata audit regression"
python3 scripts/test-linux-runtime-audit.py

echo "==> iOS provisioning profile decoder"
bash scripts/test-ios-provisioning-profile.sh

echo "==> source network/control audit"
bash scripts/audit-network-control-surface.sh

echo "==> privileged release exclusion"
bash scripts/verify-privileged-release-exclusion.sh

# 8. Public-surface checks.
echo "==> diff check"
git diff --check

echo "==> public surface audit"
python3 manual/skills/canghui-full-build/scripts/audit_public_surface.py

echo "==> CangHui CI complete"
