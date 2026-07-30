#!/bin/sh

set -eu

MODE="${1:-all}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
OUTPUT_DIR="${2:-$ROOT_DIR/target/ios-host}"

: "${CANGJIE_HOME:?set CANGJIE_HOME to a Cangjie SDK with iOS targets}"
CJC="$CANGJIE_HOME/bin/cjc"

if [ ! -x "$CJC" ]; then
    echo "cjc not found at $CJC" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

build_target() {
    target="$1"
    runtime_dir="$2"
    output_name="$3"

    if [ ! -d "$CANGJIE_HOME/modules/$runtime_dir" ] || [ ! -d "$CANGJIE_HOME/lib/$runtime_dir" ]; then
        echo "Cangjie SDK target is incomplete: $runtime_dir" >&2
        exit 1
    fi

    (
        cd "$OUTPUT_DIR"
        "$CJC" \
            "$ROOT_DIR/src/host/host_capabilities.cj" \
            "$ROOT_DIR/src/host/mobile_host_contracts.cj" \
            "$ROOT_DIR/src/host/native_surface_proxy.cj" \
            "$ROOT_DIR/src/host/ios_host_bootstrap.cj" \
            --target="$target" \
            --output-type=staticlib \
            -o "$OUTPUT_DIR/$output_name"
    )
}

case "$MODE" in
    all)
        build_target aarch64-apple-ios ios_aarch64_cjnative libcanghui_host_ios.a
        build_target aarch64-apple-ios-simulator ios_simulator_aarch64_cjnative libcanghui_host_ios_simulator.a
        cp "$OUTPUT_DIR/libcanghui_host_ios.a" "$OUTPUT_DIR/libcangjiegui_host_ios.a"
        cp "$OUTPUT_DIR/libcanghui_host_ios_simulator.a" "$OUTPUT_DIR/libcangjiegui_host_ios_simulator.a"
        ;;
    device)
        build_target aarch64-apple-ios ios_aarch64_cjnative libcanghui_host_ios.a
        cp "$OUTPUT_DIR/libcanghui_host_ios.a" "$OUTPUT_DIR/libcangjiegui_host_ios.a"
        ;;
    simulator)
        build_target aarch64-apple-ios-simulator ios_simulator_aarch64_cjnative libcanghui_host_ios_simulator.a
        cp "$OUTPUT_DIR/libcanghui_host_ios_simulator.a" "$OUTPUT_DIR/libcangjiegui_host_ios_simulator.a"
        ;;
    *)
        echo "usage: $0 [all|device|simulator] [output-dir]" >&2
        exit 2
        ;;
esac

echo "CangHui iOS host static libraries: $OUTPUT_DIR"
