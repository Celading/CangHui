#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-${PROJECT_DIR}/target/acceptance}"
CUIC_BIN="${CANGHUI_CUIC:-cuic}"
mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"

for profile in 0 1 2; do
    for theme in light dark; do
        for viewport in compact wide; do
            width=1060
            height=900
            if [[ "${viewport}" == compact ]]; then width=390; height=844; fi
            name="profile-${profile}-${viewport}-${theme}"
            "${CUIC_BIN}" prnt macos "${PROJECT_DIR}" --output "${OUTPUT_DIR}/${name}.png" -- \
                --profile "${profile}" --theme "${theme}" --width "${width}" --height "${height}" \
                > "${OUTPUT_DIR}/${name}.log" 2>&1
            echo "captured ${name}"
        done
    done
done

for frames in 12 48 120; do
    "${CUIC_BIN}" prnt macos "${PROJECT_DIR}" --output "${OUTPUT_DIR}/motion-frame-${frames}.png" \
        --frames "${frames}" -- --auto-reshape true > "${OUTPUT_DIR}/motion-frame-${frames}.log" 2>&1
    echo "captured motion-frame-${frames}"
done

for probe in editorial focused guided compact; do
    "${CUIC_BIN}" pview "${PROJECT_DIR}" "kit.${probe}" --columns 100 --rows 36 \
        > "${OUTPUT_DIR}/${probe}.ascii.txt" 2>&1
done
"${CUIC_BIN}" probe run "${PROJECT_DIR}" kit.editorial \
    --events $'focus reshape\nkey Enter\nadvance 230\nassert activation reshape 1' --json \
    > "${OUTPUT_DIR}/motion-half.json" 2> "${OUTPUT_DIR}/motion-half.log"
echo "Kit matrix complete: 12 composition frames, 3 motion frames, 4 ASCII views and one timed replay."
