#!/usr/bin/env bash

set -euo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
INSTALL_ROOT="${TMPDIR:-/tmp}/canghui-cuic-install-smoke"

rm -rf "${INSTALL_ROOT}"
"${FRAMEWORK_ROOT}/scripts/install-cuic.sh" --source "${FRAMEWORK_ROOT}" --root "${INSTALL_ROOT}"
test -x "${INSTALL_ROOT}/bin/cuic"
"${INSTALL_ROOT}/bin/cuic" version | grep -q '^cuic 0.4.0$'

echo "CangHui cuic install smoke passed"
