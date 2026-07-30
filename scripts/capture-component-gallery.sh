#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GALLERY_ROOT="${PROJECT_ROOT}/examples/component-gallery"
OUTPUT_DIR="${1:-${TMPDIR:-/tmp}/canghui-component-gallery}"

mkdir -p "${OUTPUT_DIR}"

cd "${GALLERY_ROOT}"
cjpm build
sleep 1

for preview in android harmony tablet desktop ios; do
  snapshot="${OUTPUT_DIR}/${preview}.bmp"
  captured=false
  for attempt in 1 2; do
    rm -f "${snapshot}"
    cjpm run --skip-build -- --preview "${preview}" --snapshot "${snapshot}"
    if [[ -s "${snapshot}" ]]; then
      captured=true
      break
    fi
    printf 'Retrying %s snapshot after the desktop host returned no artifact.\n' "${preview}" >&2
    sleep 1
  done
  if [[ "${captured}" != true ]]; then
    printf 'CUI snapshot was not produced: %s\n' "${snapshot}" >&2
    exit 1
  fi
  sleep 1
done

printf 'CangHui Component Gallery snapshots: %s\n' "${OUTPUT_DIR}"
