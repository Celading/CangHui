#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="${TMPDIR:-/tmp}/canghui-cli-smoke"

rm -rf "${FIXTURE_DIR}"

"${ROOT_DIR}/bin/cuic" version
"${ROOT_DIR}/bin/cuic" examples | grep -q '^notepad$'
"${ROOT_DIR}/bin/cuic" doctor macos
MACOS_DOCTOR_JSON="$("${ROOT_DIR}/bin/cuic" doctor macos --json)"
printf '%s' "${MACOS_DOCTOR_JSON}" | grep -q '"schema":"canghui.doctor.v0"'
printf '%s' "${MACOS_DOCTOR_JSON}" | grep -q '"requestedTarget":"macos"'
printf '%s' "${MACOS_DOCTOR_JSON}" | grep -q '"exitCode":0'
"${ROOT_DIR}/bin/cuic" init "${FIXTURE_DIR}" --name canghui_cli_smoke --platform macos
"${ROOT_DIR}/bin/cuic" build macos "${FIXTURE_DIR}"
"${ROOT_DIR}/bin/cuic" test macos "${FIXTURE_DIR}"
"${ROOT_DIR}/bin/cuic" probe diff component-gallery
"${ROOT_DIR}/bin/cuic" probe list component-gallery --json | grep -q 'gallery.primary-button'
"${ROOT_DIR}/bin/cuic" probe describe component-gallery gallery.primary-button --json | grep -q '"kind":"function"'
"${ROOT_DIR}/bin/cuic" probe run component-gallery gallery.primary-button \
    --events $'move-in 80 35\npress 80 35\nrelease 80 35\nassert activation primary-button.click 1' \
    --json | grep -q '"ok":true'

if "${ROOT_DIR}/bin/cuic" probe diff "${ROOT_DIR}/testdata/duplicate-probe"; then
    echo "error: duplicate probe scanner unexpectedly passed" >&2
    exit 1
fi

if "${ROOT_DIR}/bin/cuic" doctor android; then
    echo "error: Android doctor unexpectedly passed" >&2
    exit 1
fi

if ANDROID_DOCTOR_JSON="$("${ROOT_DIR}/bin/cuic" doctor android --json)"; then
    echo "error: Android JSON doctor unexpectedly passed" >&2
    exit 1
fi
printf '%s' "${ANDROID_DOCTOR_JSON}" | grep -q '"status":"unsupported"'
printf '%s' "${ANDROID_DOCTOR_JSON}" | grep -q '"exitCode":1'

if "${ROOT_DIR}/bin/cuic" build linux "${FIXTURE_DIR}"; then
    echo "error: cross-host Linux build unexpectedly passed" >&2
    exit 1
fi

echo "CangHui CLI smoke passed"
