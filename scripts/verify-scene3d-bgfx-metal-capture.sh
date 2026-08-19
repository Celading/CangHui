#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${BGFX4CJ_ROOT:?set BGFX4CJ_ROOT to a bgfx4cj Git checkout}"
: "${BGFX_NATIVE_ROOT:?set BGFX_NATIVE_ROOT to the directory containing libbgfx.a, libbimg.a and libbx.a}"
OUTPUT="${1:-${TMPDIR:-/tmp}/canghui-scene3d-bgfx-metal.png}"
RECEIPT="${2:-${OUTPUT%.*}.native-supply.json}"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/canghui-scene3d-bgfx-metal.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

for link_root in "$BGFX_NATIVE_ROOT" "$ROOT/sdl/.sdl3"; do
    if [[ "$link_root" == *[[:space:]]* || "$link_root" == *\"* || "$link_root" == *\\* ]]; then
        printf 'Native link roots contain unsupported characters: %s\n' "$link_root" >&2
        exit 1
    fi
done

"$ROOT/scripts/verify-scene3d-bgfx-native-supply.sh" "$RECEIPT"

mkdir -p "$STAGE/bgfx4cj" "$STAGE/scene3d-bgfx" "$STAGE/scene3d-bgfx-metal-capture"
git -C "$BGFX4CJ_ROOT" archive --format=tar HEAD -o "$STAGE/bgfx4cj.tar"
tar -xf "$STAGE/bgfx4cj.tar" -C "$STAGE/bgfx4cj"
cp -R "$ROOT/packages/scene3d-bgfx/src" "$STAGE/scene3d-bgfx/src"
cp -R "$ROOT/examples/scene3d-bgfx-metal-capture/src" "$STAGE/scene3d-bgfx-metal-capture/src"

cat >"$STAGE/bgfx4cj/cjpm.toml" <<EOF
[package]
  cjc-version = "1.1.0"
  name = "bgfx4cj"
  description = "This project encapsulates the C++ library bgfx into the Cangjie ecosystem"
  version = "1.0.0"
  output-type = "static"
  compile-option = "-Woff unused -Woff parser --diagnostic-format=noColor"
  link-option = "-L$BGFX_NATIVE_ROOT -lbgfx -lbimg -lbx -lc++ -lobjc -framework Metal -framework QuartzCore -framework Cocoa -framework Foundation -framework IOKit"

[dependencies]
EOF

cat >"$STAGE/scene3d-bgfx/cjpm.toml" <<EOF
[package]
cjc-version = "1.1.0"
name = "canghui_scene3d_bgfx"
version = "0.1.0"
output-type = "static"
description = "Optional bgfx4cj Scene3D driver for CangHui"
license = "Apache-2.0"
link-option = "-L$BGFX_NATIVE_ROOT -lbgfx -lbimg -lbx -lc++ -lobjc -L$ROOT/sdl/.sdl3 -lSDL3 -lSDL3_ttf -framework Metal -framework QuartzCore -framework Cocoa -framework Foundation -framework IOKit"

[dependencies]
cui = { path = "$ROOT" }
sdl = { path = "$ROOT/sdl" }
bgfx4cj = { path = "$STAGE/bgfx4cj" }
EOF

cat >"$STAGE/scene3d-bgfx-metal-capture/cjpm.toml" <<EOF
[package]
cjc-version = "1.1.0"
name = "canghui_scene3d_bgfx_metal_capture"
version = "0.1.0"
output-type = "executable"
description = "CangHui Scene3D bgfx Metal capture example"
license = "Apache-2.0"
link-option = "-L$BGFX_NATIVE_ROOT -lbgfx -lbimg -lbx -lc++ -lobjc -L$ROOT/sdl/.sdl3 -lSDL3 -lSDL3_ttf -framework Metal -framework QuartzCore -framework Cocoa -framework Foundation -framework IOKit"

[dependencies]
cui = { path = "$ROOT" }
canghui_scene3d_bgfx = { path = "$STAGE/scene3d-bgfx" }
EOF

(cd "$STAGE/scene3d-bgfx" && cjpm test)
(cd "$STAGE/scene3d-bgfx-metal-capture" && cjpm build)
(cd "$ROOT/tools/cuic" && cjpm build)
"$ROOT/tools/cuic/bin/cuic" prnt macos "$STAGE/scene3d-bgfx-metal-capture" --output "$OUTPUT" --frames 12
test -s "$OUTPUT"
printf 'scene3d Metal capture: %s\n' "$OUTPUT"
printf 'scene3d native supply receipt: %s\n' "$RECEIPT"
