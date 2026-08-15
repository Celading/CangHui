#!/usr/bin/env bash

set -euo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
INSTALL_ROOT="${TMPDIR:-/tmp}/canghui-cuic-install-smoke"

rm -rf "${INSTALL_ROOT}"
"${FRAMEWORK_ROOT}/scripts/install-cuic.sh" --source "${FRAMEWORK_ROOT}" --root "${INSTALL_ROOT}"
test -x "${INSTALL_ROOT}/bin/cuic"
EXPECTED_REVISION="$(git -C "${FRAMEWORK_ROOT}" rev-parse HEAD)"
if [[ -n "$(git -C "${FRAMEWORK_ROOT}" status --porcelain)" ]]; then
    EXPECTED_REVISION="${EXPECTED_REVISION}+dirty"
fi
EXPECTED_VERSION="cuic 0.4.0 (local-source@${EXPECTED_REVISION})"
[[ "$("${INSTALL_ROOT}/bin/cuic" version)" == "${EXPECTED_VERSION}" ]]
"${INSTALL_ROOT}/bin/cuic" doctor macos --json |
    grep -Fq "\"cliProvenance\":{\"channel\":\"local-source\",\"revision\":\"${EXPECTED_REVISION}\"}"

echo "CangHui cuic install smoke passed"
