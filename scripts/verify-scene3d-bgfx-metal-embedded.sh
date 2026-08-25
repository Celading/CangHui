#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${BGFX4CJ_ROOT:?set BGFX4CJ_ROOT to a bgfx4cj Git checkout}"
: "${BGFX_NATIVE_ROOT:?set BGFX_NATIVE_ROOT to the directory containing libbgfx.a, libbimg.a and libbx.a}"
OUTPUT="${1:-${TMPDIR:-/tmp}/canghui-scene3d-bgfx-metal-embedded.bmp}"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/canghui-scene3d-bgfx-metal-embedded.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

fail_embedded() {
    printf 'scene3d embedded Metal proof rejected: %s\n' "$1" >&2
    exit 1
}

for link_root in "$BGFX_NATIVE_ROOT" "$ROOT/sdl/.sdl3"; do
    if [[ "$link_root" == *[[:space:]]* || "$link_root" == *\"* || "$link_root" == *\\* ]]; then
        fail_embedded "native link root contains unsupported characters: $link_root"
    fi
done
[[ "$OUTPUT" == *.bmp || "$OUTPUT" == *.BMP ]] || fail_embedded "proof output must use .bmp"

mkdir -p "$STAGE/clang-cache" "$STAGE/bgfx4cj" "$STAGE/scene3d-bgfx" "$STAGE/embedded-example"
git -C "$BGFX4CJ_ROOT" archive --format=tar HEAD -o "$STAGE/bgfx4cj.tar"
tar -xf "$STAGE/bgfx4cj.tar" -C "$STAGE/bgfx4cj"
cp -R "$ROOT/packages/scene3d-bgfx/src" "$STAGE/scene3d-bgfx/src"
cp "$ROOT/packages/scene3d-bgfx/platform/macos/macos_embedded_metal_host.cj" \
    "$STAGE/scene3d-bgfx/src/macos_embedded_metal_host.cj"
cp -R "$ROOT/examples/scene3d-bgfx-metal-embedded/src" "$STAGE/embedded-example/src"

xcrun clang -fobjc-arc -fno-objc-msgsend-selector-stubs -fmodules \
    -fmodules-cache-path="$STAGE/clang-cache" \
    -c "$ROOT/packages/scene3d-bgfx/platform/macos/macos_embedded_metal_host.m" \
    -o "$STAGE/macos_embedded_metal_host.o"
ar rcs "$STAGE/libcanghui_embedded_metal_host.a" "$STAGE/macos_embedded_metal_host.o"

cat >"$STAGE/bgfx4cj/cjpm.toml" <<EOF
[package]
cjc-version = "1.1.0"
name = "bgfx4cj"
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
link-option = "-L$STAGE -lcanghui_embedded_metal_host -L$BGFX_NATIVE_ROOT -lbgfx -lbimg -lbx -lc++ -lobjc -L$ROOT/sdl/.sdl3 -lSDL3 -lSDL3_ttf -framework Metal -framework QuartzCore -framework Cocoa -framework Foundation -framework IOKit"

[dependencies]
chui = { path = "$ROOT" }
sdl = { path = "$ROOT/sdl" }
bgfx4cj = { path = "$STAGE/bgfx4cj" }
EOF

cat >"$STAGE/embedded-example/cjpm.toml" <<EOF
[package]
cjc-version = "1.1.0"
name = "canghui_scene3d_bgfx_metal_embedded"
version = "0.1.0"
output-type = "executable"
link-option = "-L$STAGE -lcanghui_embedded_metal_host -L$BGFX_NATIVE_ROOT -lbgfx -lbimg -lbx -lc++ -lobjc -L$ROOT/sdl/.sdl3 -lSDL3 -lSDL3_ttf -framework Metal -framework QuartzCore -framework Cocoa -framework Foundation -framework IOKit"

[dependencies]
chui = { path = "$ROOT" }
canghui_scene3d_bgfx = { path = "$STAGE/scene3d-bgfx" }
EOF

LOG="$STAGE/embedded.log"
(cd "$ROOT/tools/cuic" && cjpm build)
"$ROOT/tools/cuic/target/release/bin/main" prnt macos "$STAGE/embedded-example" \
    --output "$OUTPUT" --frames 48 | tee "$LOG"

grep -Fq 'presentation=embedded-surface childAttached=true' "$LOG" || \
    fail_embedded "child NSView/CAMetalLayer attachment was not proven"
grep -Fq 'attach=accepted renderer=Metal' "$LOG" || \
    fail_embedded "Scene3DView did not attach the Metal provider"
grep -Fq 'nativeCapture=ready' "$LOG" || fail_embedded "bgfx backbuffer capture was not completed"
grep -Fq 'detach=accepted' "$LOG" || fail_embedded "embedded provider did not detach cleanly"
command -v magick >/dev/null 2>&1 || fail_embedded "ImageMagick is required"
NATIVE_CAPTURE="$OUTPUT.native.bmp"
test -s "$OUTPUT" || fail_embedded "cuic renderer capture is empty"
test -s "$NATIVE_CAPTURE" || fail_embedded "native layer capture is empty"
read -r WIDTH HEIGHT OPAQUE COLORS <<<"$(magick identify -format '%w %h %[opaque] %k' "$OUTPUT")"
[[ "$WIDTH" -ge 880 && "$HEIGHT" -ge 580 ]] || \
    fail_embedded "cuic capture is ${WIDTH}x${HEIGHT}, expected the complete renderer surface"
[[ "$OPAQUE" == "True" ]] || fail_embedded "cuic capture is not opaque"
[[ "$COLORS" -ge 16 ]] || fail_embedded "cuic capture has only $COLORS colors"

color_pixels() {
    magick "$NATIVE_CAPTURE" -alpha off -fill black +opaque "$1" -fill white -opaque "$1" \
        -format '%[fx:round(mean*w*h)]' info:
}
ROUTE_PIXELS="$(color_pixels '#FFB743')"
VEHICLE_PIXELS="$(color_pixels '#D45242')"
[[ "$ROUTE_PIXELS" -ge 500 ]] || fail_embedded "embedded route color has only $ROUTE_PIXELS pixels"
[[ "$VEHICLE_PIXELS" -ge 500 ]] || fail_embedded "embedded vehicle color has only $VEHICLE_PIXELS pixels"

printf 'scene3d embedded CangHui UI capture: %s\n' "$OUTPUT"
printf 'scene3d embedded native layer capture: %s\n' "$NATIVE_CAPTURE"
printf 'scene3d embedded proof: cuic-prnt=true presentation=embedded-surface childAttached=true renderer=Metal\n'
printf 'scene3d capture proof: ui=%sx%s opaque=%s colors=%s native-route=%s native-vehicle=%s\n' \
    "$WIDTH" "$HEIGHT" "$OPAQUE" "$COLORS" "$ROUTE_PIXELS" "$VEHICLE_PIXELS"
