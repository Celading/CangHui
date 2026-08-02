#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="${TMPDIR:-/tmp}/canghui-cli-smoke"
REMOTE_FIXTURE_DIR="${TMPDIR:-/tmp}/canghui-cli-remote-smoke"
FRAMEWORK_ROOT="$(cd "${ROOT_DIR}/../.." && pwd)"

rm -rf "${FIXTURE_DIR}"
rm -rf "${REMOTE_FIXTURE_DIR}"

"${ROOT_DIR}/bin/cuic" version
"${ROOT_DIR}/bin/cuic" examples | grep -q '^notepad$'
"${ROOT_DIR}/bin/cuic" doctor macos
MACOS_DOCTOR_JSON="$("${ROOT_DIR}/bin/cuic" doctor macos --json)"
printf '%s' "${MACOS_DOCTOR_JSON}" | grep -q '"schema":"canghui.doctor.v0"'
printf '%s' "${MACOS_DOCTOR_JSON}" | grep -q '"requestedTarget":"macos"'
printf '%s' "${MACOS_DOCTOR_JSON}" | grep -q '"exitCode":0'
"${ROOT_DIR}/bin/cuic" init "${FIXTURE_DIR}" --name canghui_cli_smoke --platform macos \
    --canghui-path "${FRAMEWORK_ROOT}"
test -f "${FIXTURE_DIR}/assets/fonts/HarmonyOS_Sans_SC.ttf"
test -f "${FIXTURE_DIR}/assets/fonts/HARMONYOS_SANS_LICENSE.txt"
test -f "${FIXTURE_DIR}/assets/fonts/HARMONYOS_SANS_SOURCE.txt"
test -f "${FIXTURE_DIR}/canghui.toml"
"${ROOT_DIR}/bin/cuic" scripts list "${FIXTURE_DIR}" | grep -q '^  check:'
(
    cd "${FIXTURE_DIR}"
    "${ROOT_DIR}/bin/cuic" check
)
"${ROOT_DIR}/bin/cuic" init "${REMOTE_FIXTURE_DIR}" --name canghui_cli_remote_smoke --platform macos
grep -q 'git = "https://github.com/Celading/CangHui.git"' "${REMOTE_FIXTURE_DIR}/cjpm.toml"
grep -q 'commitId = "a15593ddc03ff3b7ec913c2ac2b3abe22ce74f02"' "${REMOTE_FIXTURE_DIR}/cjpm.toml"
grep -q -- '--set-runtime-rpath' "${REMOTE_FIXTURE_DIR}/cjpm.toml"
if grep -q '/Users/' "${REMOTE_FIXTURE_DIR}/cjpm.toml"; then
    echo "error: generated remote consumer leaked a local absolute path" >&2
    exit 1
fi
if grep -q 'cjpm.lock' "${REMOTE_FIXTURE_DIR}/.gitignore"; then
    echo "error: generated consumer unexpectedly ignores its dependency lock" >&2
    exit 1
fi
"${ROOT_DIR}/bin/cuic" probe diff component-gallery
"${ROOT_DIR}/bin/cuic" probe list component-gallery --json | grep -q 'gallery.primary-button'
"${ROOT_DIR}/bin/cuic" probe describe component-gallery gallery.primary-button --json | grep -q '"kind":"function"'
"${ROOT_DIR}/bin/cuic" probe run component-gallery gallery.primary-button \
    --events $'move-in 80 35\npress 80 35\nrelease 80 35\nassert activation primary-button.click 1' \
    --json | grep -q '"ok":true'

SYMBOL_CATALOG_JSON="$("${ROOT_DIR}/bin/cuic" symbol list --json)"
printf '%s' "${SYMBOL_CATALOG_JSON}" | grep -q '"schema":"canghui.symbol.catalog.v0"'
printf '%s' "${SYMBOL_CATALOG_JSON}" | grep -q '"id":"material"'
printf '%s' "${SYMBOL_CATALOG_JSON}" | grep -q '"id":"ant"'
printf '%s' "${SYMBOL_CATALOG_JSON}" | grep -q '"id":"arco"'

(
    cd "${FIXTURE_DIR}"
    "${ROOT_DIR}/bin/cuic" symbol generate material:plus@primary_add ant:check arco:right \
        --output generated_symbols.cj --package canghui_cli_smoke
    grep -q 'MaterialSymbolProvider(included: \["add"\])' generated_symbols.cj
    grep -q 'AntSymbolProvider(included: \["check"\])' generated_symbols.cj
    grep -q 'ArcoSymbolProvider(included: \["right"\])' generated_symbols.cj
)

if "${ROOT_DIR}/bin/cuic" symbol generate material:add material:plus \
    --output "${FIXTURE_DIR}/duplicate-symbols.cj" --package canghui_cli_smoke; then
    echo "error: alias-equivalent Symbol selections unexpectedly passed" >&2
    exit 1
fi

if "${ROOT_DIR}/bin/cuic" symbol generate material:add@action ant:plus@action \
    --output "${FIXTURE_DIR}/colliding-symbols.cj" --package canghui_cli_smoke; then
    echo "error: cross-provider Symbol export collision unexpectedly passed" >&2
    exit 1
fi

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
