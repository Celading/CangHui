#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="${TMPDIR:-/tmp}/canghui-cli-smoke"

rm -rf "${FIXTURE_DIR}"

"${ROOT_DIR}/bin/cuic" version
"${ROOT_DIR}/bin/cuic" examples | grep -q '^notepad$'
"${ROOT_DIR}/bin/cuic" doctor macos
"${ROOT_DIR}/bin/cuic" init "${FIXTURE_DIR}" --name canghui_cli_smoke --platform macos
"${ROOT_DIR}/bin/cuic" build macos "${FIXTURE_DIR}"
"${ROOT_DIR}/bin/cuic" test macos "${FIXTURE_DIR}"

if "${ROOT_DIR}/bin/cuic" doctor android; then
    echo "error: Android doctor unexpectedly passed" >&2
    exit 1
fi

if "${ROOT_DIR}/bin/cuic" build linux "${FIXTURE_DIR}"; then
    echo "error: cross-host Linux build unexpectedly passed" >&2
    exit 1
fi

echo "CangHui CLI smoke passed"
