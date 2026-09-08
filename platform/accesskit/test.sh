#!/bin/bash
set -euo pipefail
if [ "$#" -ne 3 ]; then
  echo 'usage: bash platform/accesskit/test.sh <accesskit-c-source> <native-lib-dir> <fresh-output-dir>' >&2
  exit 2
fi
bridge_source="$(cd "$(dirname "$0")" && pwd)"
upstream_source="$(cd "$1" && pwd)"
native_directory="$(cd "$2" && pwd)"
test_output="$3"
expected_revision=0824c4a1e3a4d13ce5582df20e394fba49485a15
test "$(git -C "$upstream_source" rev-parse HEAD)" = "$expected_revision"
test -z "$(git -C "$upstream_source" status --porcelain --untracked-files=no)"
mkdir -p "$test_output"
test_output="$(cd "$test_output" && pwd)"
cc -std=c11 -Wall -Wextra -Werror -fPIC -shared -fvisibility=hidden \
  -I"$upstream_source/include" "$bridge_source/semantic_bridge.c" \
  -L"$native_directory" -laccesskit -o "$test_output/libchui_accesskit_bridge.so"
cc -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined -g \
  -I"$upstream_source/include" "$bridge_source/semantic_bridge_test.c" \
  -L"$native_directory" -laccesskit -Wl,-rpath,"$native_directory" \
  -o "$test_output/semantic_bridge_test"
"$test_output/semantic_bridge_test"
